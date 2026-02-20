// IntegrationToolHandler.swift
// Thea
//
// T3: Execution layer for Anthropic tool calls → Thea integration backends.
// Maps tool names from AnthropicToolCatalog to live integration calls.
// Called by the AI response pipeline when a tool_use block is received.

import Foundation
import OSLog

// MARK: - Integration Tool Handler

/// Routes Anthropic tool_use calls to Thea's integration backends.
/// All 7 integration categories supported: Calendar, Reminders, Shortcuts,
/// Safari (macOS), Finder (macOS), Mail (macOS), Notes (macOS).
// periphery:ignore - Reserved: AD3 audit — wired in future integration
final actor IntegrationToolHandler {
    static let shared = IntegrationToolHandler()

    private let logger = Logger(subsystem: "app.thea", category: "IntegrationToolHandler")
    private let iso = ISO8601DateFormatter()

    private init() {}

    // MARK: - Public Entry Point

    /// Execute a tool call and return the result as a human-readable string.
    /// - Parameters:
    ///   - toolName: The tool identifier from AnthropicToolCatalog (e.g. "calendar_list_events")
    ///   - parameters: Parameters dictionary extracted from the AI tool_use block
    /// - Returns: Result string to send back to the AI as a tool_result
    func execute(toolName: String, parameters: [String: Any]) async -> String {
        logger.info("Tool call: \(toolName)")
        do {
            return try await route(toolName: toolName, parameters: parameters)
        } catch {
            logger.error("Tool \(toolName) failed: \(error.localizedDescription)")
            return "Error executing \(toolName): \(error.localizedDescription)"
        }
    }

    // MARK: - Router

    private func route(toolName: String, parameters: [String: Any]) async throws -> String {
        switch toolName {

        // MARK: Calendar (all platforms — EventKit)
        case "calendar_list_events":   return try await handleCalendarListEvents(parameters)
        case "calendar_create_event":  return try await handleCalendarCreateEvent(parameters)

        // MARK: Reminders (all platforms — EventKit)
        case "reminders_list":         return try await handleRemindersList(parameters)
        case "reminders_create":       return try await handleRemindersCreate(parameters)

        // MARK: Shortcuts (all platforms — platform-guarded inside)
        case "shortcuts_run":          return try await handleShortcutsRun(parameters)
        case "shortcuts_list":         return try await handleShortcutsList()

        // MARK: macOS-only tools
        #if os(macOS)
        case "safari_open_url":        return try await handleSafariOpenURL(parameters)
        case "safari_get_current_url": return try await handleSafariGetCurrentURL()
        case "finder_reveal":          return try await handleFinderReveal(parameters)
        case "finder_search":          return try await handleFinderSearch(parameters)
        case "mail_compose":           return try await handleMailCompose(parameters)
        case "mail_check_unread":      return try await handleMailCheckUnread()
        case "notes_create":           return try await handleNotesCreate(parameters)
        case "notes_search":           return try await handleNotesSearch(parameters)
        #endif

        default:
            return "Unknown tool '\(toolName)'. Available tools are listed in the tool catalog."
        }
    }

    // MARK: - Calendar Handlers

    private func handleCalendarListEvents(_ params: [String: Any]) async throws -> String {
        guard let startStr = params["start_date"] as? String,
              let endStr = params["end_date"] as? String,
              let start = iso.date(from: startStr),
              let end = iso.date(from: endStr) else {
            return "Error: start_date and end_date required (ISO 8601 format)"
        }
        let cal = CalendarIntegration.shared
        try await cal.connect()
        let events = try await cal.getEvents(from: start, to: end)
        guard !events.isEmpty else { return "No calendar events found in the specified date range." }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return events.map { "• \($0.title) — \(formatter.string(from: $0.startDate))" }
            .joined(separator: "\n")
    }

    private func handleCalendarCreateEvent(_ params: [String: Any]) async throws -> String {
        guard let title = params["title"] as? String,
              let startStr = params["start_date"] as? String,
              let endStr = params["end_date"] as? String,
              let start = iso.date(from: startStr),
              let end = iso.date(from: endStr) else {
            return "Error: title, start_date, and end_date are required"
        }
        let notes = params["notes"] as? String
        let cal = CalendarIntegration.shared
        try await cal.connect()
        let eventId = try await cal.createEvent(
            title: title,
            startDate: start,
            endDate: end,
            calendar: nil,
            notes: notes
        )
        return "Created calendar event '\(title)' (id: \(eventId))"
    }

    // MARK: - Reminders Handlers

    private func handleRemindersList(_ params: [String: Any]) async throws -> String {
        let rem = RemindersIntegration.shared
        guard await rem.requestAccess() else {
            return "Reminders access denied. Please grant permission in System Settings → Privacy → Reminders."
        }
        let includeCompleted = params["include_completed"] as? Bool ?? false
        var criteria = ReminderSearchCriteria()
        criteria.isCompleted = includeCompleted ? nil : false
        let reminders = try await rem.fetchReminders(criteria: criteria)
        guard !reminders.isEmpty else { return "No reminders found." }
        return reminders
            .map { "[\($0.isCompleted ? "✓" : "○")] \($0.title)" }
            .joined(separator: "\n")
    }

    private func handleRemindersCreate(_ params: [String: Any]) async throws -> String {
        guard let title = params["title"] as? String, !title.isEmpty else {
            return "Error: title is required"
        }
        let rem = RemindersIntegration.shared
        guard await rem.requestAccess() else {
            return "Reminders access denied. Please grant permission in System Settings → Privacy → Reminders."
        }
        var reminder = TheaReminder(title: title)
        if let dueDateStr = params["due_date"] as? String {
            reminder.dueDate = iso.date(from: dueDateStr)
        }
        if let priorityInt = params["priority"] as? Int,
           let priority = ReminderPriority(rawValue: priorityInt) {
            reminder.priority = priority
        }
        let created = try await rem.createReminder(reminder)
        return "Created reminder '\(created.title)'"
    }

    // MARK: - Shortcuts Handlers

    private func handleShortcutsRun(_ params: [String: Any]) async throws -> String {
        guard let name = params["shortcut_name"] as? String, !name.isEmpty else {
            return "Error: shortcut_name is required"
        }
        let input = params["input"] as? String
        let result = try await ShortcutsIntegration.shared.runShortcut(name, input: input)
        return result ?? "Shortcut '\(name)' completed successfully."
    }

    private func handleShortcutsList() async throws -> String {
        let shortcuts = try await ShortcutsIntegration.shared.getAllShortcuts()
        guard !shortcuts.isEmpty else { return "No shortcuts found." }
        return "Available shortcuts:\n" + shortcuts.map { "• \($0.name)" }.joined(separator: "\n")
    }

    // MARK: - macOS-only Handlers

    #if os(macOS)

    private func handleSafariOpenURL(_ params: [String: Any]) async throws -> String {
        guard let urlStr = params["url"] as? String,
              let url = URL(string: urlStr) else {
            return "Error: a valid url is required"
        }
        try await SafariIntegration.shared.navigateTo(url)
        return "Navigated Safari to \(urlStr)"
    }

    private func handleSafariGetCurrentURL() async throws -> String {
        let url = try await SafariIntegration.shared.getCurrentURL()
        return url?.absoluteString ?? "No active Safari tab found."
    }

    private func handleFinderReveal(_ params: [String: Any]) async throws -> String {
        guard let path = params["path"] as? String else { return "Error: path is required" }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        try await FinderIntegration.shared.revealFile(url)
        return "Revealed '\(path)' in Finder"
    }

    private func handleFinderSearch(_ params: [String: Any]) async throws -> String {
        guard let query = params["query"] as? String, !query.isEmpty else {
            return "Error: query is required"
        }
        let directory = params["directory"] as? String
        let searchURL = directory.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? URL(fileURLWithPath: NSHomeDirectory())
        let contents = try await FinderIntegration.shared.getFolderContents(searchURL)
        let matches = contents.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(query) }
        guard !matches.isEmpty else { return "No files matching '\(query)' found in \(searchURL.path)." }
        return matches.prefix(20).map { $0.path }.joined(separator: "\n")
    }

    private func handleMailCompose(_ params: [String: Any]) async throws -> String {
        guard let to = params["to"] as? String,
              let subject = params["subject"] as? String,
              let body = params["body"] as? String else {
            return "Error: to, subject, and body are required"
        }
        try await MailIntegration.shared.composeEmail(to: [to], subject: subject, body: body)
        return "Email draft composed to \(to) with subject '\(subject)'"
    }

    private func handleMailCheckUnread() async throws -> String {
        let count = try await MailIntegration.shared.getUnreadCount()
        return "You have \(count) unread email\(count == 1 ? "" : "s")."
    }

    private func handleNotesCreate(_ params: [String: Any]) async throws -> String {
        guard let title = params["title"] as? String,
              let body = params["body"] as? String else {
            return "Error: title and body are required"
        }
        let folder = params["folder"] as? String
        let note = try await NotesIntegration.shared.createNote(
            title: title,
            body: body,
            folderName: folder
        )
        return "Created note '\(note.title)'" + (folder.map { " in folder '\($0)'" } ?? "")
    }

    private func handleNotesSearch(_ params: [String: Any]) async throws -> String {
        guard let query = params["query"] as? String, !query.isEmpty else {
            return "Error: query is required"
        }
        let notes = try await NotesIntegration.shared.searchNotes(text: query)
        guard !notes.isEmpty else { return "No notes found matching '\(query)'." }
        return notes.prefix(10).map { "• '\($0.title)' — \($0.snippet)" }.joined(separator: "\n")
    }

    #endif
}
