// MacOSToolHandler.swift
// Thea
//
// Tool handler for macOS-specific integration tools (B3)
// Calendar, Reminders, Mail, Finder, Safari, Music, Shortcuts, Notes
// All operations use macOS system AppleScript or EventKit/AppKit APIs

#if os(macOS)
import AppKit
import EventKit
import Foundation
import os.log

private let logger = Logger(subsystem: "ai.thea.app", category: "MacOSToolHandler")

@MainActor
enum MacOSToolHandler {

    // nonisolated(unsafe): EKEventStore is not Sendable; access is serialized via async calendar callbacks
    nonisolated(unsafe) private static let eventStore = EKEventStore()

    // MARK: - Calendar

    static func calendarListEvents(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let startStr = input["start_date"] as? String ?? ""
        let endStr = input["end_date"] as? String ?? ""
        return await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                guard granted, error == nil else {
                    continuation.resume(returning: AnthropicToolResult(
                        toolUseId: id,
                        content: "Calendar access denied: \(error?.localizedDescription ?? "unknown")",
                        isError: true
                    ))
                    return
                }
                let fmt = ISO8601DateFormatter()
                let start = fmt.date(from: startStr) ?? Date()
                let end = fmt.date(from: endStr) ?? Date().addingTimeInterval(7 * 86400)

                let calendars = eventStore.calendars(for: .event)
                let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
                let events = eventStore.events(matching: predicate)
                    .sorted { $0.startDate < $1.startDate }
                    .prefix(20)

                if events.isEmpty {
                    continuation.resume(returning: AnthropicToolResult(toolUseId: id, content: "No events found."))
                    return
                }
                let df = DateFormatter()
                df.dateStyle = .short
                df.timeStyle = .short
                let text = events.map { ev in
                    "\(df.string(from: ev.startDate)) — \(ev.title ?? "Untitled")"
                }.joined(separator: "\n")
                continuation.resume(returning: AnthropicToolResult(toolUseId: id, content: text))
            }
        }
    }

    static func calendarCreateEvent(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let title = input["title"] as? String ?? "New Event"
        let fmt = ISO8601DateFormatter()
        let start = fmt.date(from: input["start_date"] as? String ?? "") ?? Date()
        let end = fmt.date(from: input["end_date"] as? String ?? "") ?? start.addingTimeInterval(3600)
        let notes = input["notes"] as? String
        let location = input["location"] as? String

        return await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                guard granted, error == nil else {
                    continuation.resume(returning: AnthropicToolResult(
                        toolUseId: id, content: "Calendar access denied.", isError: true
                    ))
                    return
                }
                let event = EKEvent(eventStore: self.eventStore)
                event.title = title
                event.startDate = start
                event.endDate = end
                event.notes = notes
                event.location = location
                event.calendar = self.eventStore.defaultCalendarForNewEvents
                do {
                    try self.eventStore.save(event, span: .thisEvent)
                    continuation.resume(returning: AnthropicToolResult(toolUseId: id, content: "Event created: \(title)"))
                } catch {
                    continuation.resume(returning: AnthropicToolResult(
                        toolUseId: id, content: "Failed to create event: \(error.localizedDescription)", isError: true
                    ))
                }
            }
        }
    }

    // MARK: - Reminders

    static func remindersList(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let includeCompleted = input["include_completed"] as? Bool ?? false
        return await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToReminders { granted, error in
                guard granted, error == nil else {
                    continuation.resume(returning: AnthropicToolResult(
                        toolUseId: id, content: "Reminders access denied.", isError: true
                    ))
                    return
                }
                let lists = self.eventStore.calendars(for: .reminder)
                let predicate = self.eventStore.predicateForReminders(in: lists)
                self.eventStore.fetchReminders(matching: predicate) { reminders in
                    let filtered = (reminders ?? [])
                        .filter { includeCompleted || !$0.isCompleted }
                        .prefix(20)
                    if filtered.isEmpty {
                        continuation.resume(returning: AnthropicToolResult(toolUseId: id, content: "No reminders found."))
                        return
                    }
                    let text = filtered.map { r in
                        let status = r.isCompleted ? "✓" : "○"
                        return "\(status) \(r.title ?? "Untitled")"
                    }.joined(separator: "\n")
                    continuation.resume(returning: AnthropicToolResult(toolUseId: id, content: text))
                }
            }
        }
    }

    static func remindersCreate(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let title = input["title"] as? String ?? ""
        let dueDateStr = input["due_date"] as? String
        guard !title.isEmpty else {
            return AnthropicToolResult(toolUseId: id, content: "No title provided.", isError: true)
        }
        return await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToReminders { granted, _ in
                guard granted else {
                    continuation.resume(returning: AnthropicToolResult(
                        toolUseId: id, content: "Reminders access denied.", isError: true
                    ))
                    return
                }
                let reminder = EKReminder(eventStore: self.eventStore)
                reminder.title = title
                reminder.calendar = self.eventStore.defaultCalendarForNewReminders()
                if let dueDateStr,
                   let dueDate = ISO8601DateFormatter().date(from: dueDateStr) {
                    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
                    reminder.dueDateComponents = comps
                }
                do {
                    try self.eventStore.save(reminder, commit: true)
                    continuation.resume(returning: AnthropicToolResult(toolUseId: id, content: "Reminder created: \(title)"))
                } catch {
                    continuation.resume(returning: AnthropicToolResult(
                        toolUseId: id, content: "Failed: \(error.localizedDescription)", isError: true
                    ))
                }
            }
        }
    }

    // MARK: - Finder

    @MainActor
    static func finderReveal(_ input: [String: Any]) -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let path = input["path"] as? String ?? ""
        guard !path.isEmpty else {
            return AnthropicToolResult(toolUseId: id, content: "No path provided.", isError: true)
        }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return AnthropicToolResult(toolUseId: id, content: "Revealed in Finder: \(path)")
    }

    @MainActor
    static func finderSearch(_ input: [String: Any]) -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let query = input["query"] as? String ?? ""
        let dir = input["directory"] as? String ?? FileManager.default.homeDirectoryForCurrentUser.path
        guard !query.isEmpty else {
            return AnthropicToolResult(toolUseId: id, content: "No query provided.", isError: true)
        }
        return FileToolHandler.searchFiles(["_tool_use_id": id, "query": query, "directory": dir])
    }

    // MARK: - Safari

    @MainActor
    static func safariOpenURL(_ input: [String: Any]) -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let urlStr = input["url"] as? String ?? ""
        guard !urlStr.isEmpty, let url = URL(string: urlStr) else {
            return AnthropicToolResult(toolUseId: id, content: "Invalid URL: '\(urlStr)'", isError: true)
        }
        let opened = NSWorkspace.shared.open(url)
        return AnthropicToolResult(
            toolUseId: id,
            content: opened ? "Opened in Safari: \(urlStr)" : "Failed to open URL",
            isError: !opened
        )
    }

    static func safariGetCurrentURL(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let script = """
        tell application "Safari"
            if (count of windows) > 0 then
                return URL of current tab of front window
            end if
            return ""
        end tell
        """
        let result = await runAppleScript(script)
        return AnthropicToolResult(toolUseId: id, content: result.isEmpty ? "Safari has no active tab." : result)
    }

    // MARK: - Music

    static func musicPlay(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let action = input["action"] as? String ?? "play"
        let search = input["search"] as? String ?? ""

        let script: String
        if !search.isEmpty {
            script = "tell application \"Music\" to play track \"\(search)\" of library playlist 1"
        } else {
            switch action {
            case "pause": script = "tell application \"Music\" to pause"
            case "next": script = "tell application \"Music\" to next track"
            case "previous": script = "tell application \"Music\" to previous track"
            default: script = "tell application \"Music\" to play"
            }
        }
        _ = await runAppleScript(script)
        return AnthropicToolResult(toolUseId: id, content: "Music: \(action)\(search.isEmpty ? "" : " '\(search)'")")
    }

    // MARK: - Shortcuts

    static func shortcutsRun(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let name = input["shortcut_name"] as? String ?? ""
        guard !name.isEmpty else {
            return AnthropicToolResult(toolUseId: id, content: "No shortcut name provided.", isError: true)
        }
        let inputParam = input["input"] as? String ?? ""
        let withInput = inputParam.isEmpty ? "" : " with input \"\(inputParam)\""
        let script = "tell application \"Shortcuts Events\" to run shortcut \"\(name)\"\(withInput)"
        let result = await runAppleScript(script)
        return AnthropicToolResult(toolUseId: id, content: "Ran shortcut '\(name)'\(result.isEmpty ? "" : ": \(result)")")
    }

    static func shortcutsList(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let script = "tell application \"Shortcuts Events\" to return name of every shortcut"
        let result = await runAppleScript(script)
        return AnthropicToolResult(toolUseId: id, content: result.isEmpty ? "No shortcuts found or Shortcuts not available." : result)
    }

    // MARK: - Notes

    static func notesCreate(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let title = input["title"] as? String ?? "New Note"
        let body = input["body"] as? String ?? ""
        let folder = input["folder"] as? String ?? ""
        let inFolder = folder.isEmpty ? "" : " in folder \"\(folder)\""
        let script = """
        tell application "Notes"
            make new note\(inFolder) with properties {name:"\(title)", body:"\(body)"}
        end tell
        """
        _ = await runAppleScript(script)
        return AnthropicToolResult(toolUseId: id, content: "Created note: \(title)")
    }

    static func notesSearch(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let query = input["query"] as? String ?? ""
        guard !query.isEmpty else {
            return AnthropicToolResult(toolUseId: id, content: "No query provided.", isError: true)
        }
        let script = """
        tell application "Notes"
            set matchedNotes to every note whose name contains "\(query)" or body contains "\(query)"
            set result to ""
            repeat with n in items 1 thru (count of matchedNotes) of matchedNotes
                set result to result & name of n & "\n"
            end repeat
            return result
        end tell
        """
        let result = await runAppleScript(script)
        return AnthropicToolResult(
            toolUseId: id,
            content: result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "No notes found matching '\(query)'"
                : result
        )
    }

    // MARK: - Mail

    static func mailCompose(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let to = input["to"] as? String ?? ""
        let subject = input["subject"] as? String ?? ""
        let body = input["body"] as? String ?? ""
        guard !to.isEmpty && !subject.isEmpty else {
            return AnthropicToolResult(toolUseId: id, content: "Missing 'to' or 'subject'.", isError: true)
        }
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:"\(subject)", content:"\(escapedBody)"}
            tell newMessage to make new to recipient with properties {address:"\(to)"}
            send newMessage
        end tell
        """
        _ = await runAppleScript(script)
        return AnthropicToolResult(toolUseId: id, content: "Email sent to \(to): \(subject)")
    }

    static func mailCheckUnread(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let script = "tell application \"Mail\" to return count of (messages of inbox whose read status is false)"
        let result = await runAppleScript(script)
        return AnthropicToolResult(toolUseId: id, content: "Unread emails in inbox: \(result.isEmpty ? "unknown" : result)")
    }

    // MARK: - AppleScript Helper

    private static func runAppleScript(_ script: String) async -> String {
        await Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            let result = appleScript?.executeAndReturnError(&error)
            if let err = error {
                logger.warning("AppleScript error: \(err)")
                return ""
            }
            return result?.stringValue ?? ""
        }.value
    }
}
#endif
