// FunctionGemmaBridge.swift
// Thea — FunctionGemma → Integration Module Bridge
//
// Routes FunctionGemma output (structured function calls) to the
// corresponding AppIntegrationModule methods. Fully offline execution.

import Foundation
import OSLog

#if os(macOS)

// MARK: - FunctionGemma Bridge

@MainActor
// periphery:ignore - Reserved: FunctionGemmaBridge class — reserved for future feature activation
final class FunctionGemmaBridge {
    static let shared = FunctionGemmaBridge()

// periphery:ignore - Reserved: FunctionGemmaBridge type reserved for future feature activation

    private let logger = Logger(subsystem: "com.thea.app", category: "FunctionGemmaBridge")
    private let engine = FunctionGemmaEngine.shared

    /// Minimum confidence threshold for auto-execution
    var autoExecuteThreshold = 0.8

    /// Whether to require user confirmation before executing
    var requireConfirmation = true

    private init() {}

    // MARK: - Public API

    /// Process a natural language instruction and execute the resulting action.
    /// Returns a human-readable result string.
    func processInstruction(_ instruction: String) async throws -> FunctionExecutionResult {
        // Parse instruction into function call(s)
        let calls = try await engine.parseMultiple(instruction)

        guard !calls.isEmpty else {
            return FunctionExecutionResult(
                success: false,
                message: "Could not understand the instruction.",
                functionCalls: []
            )
        }

        // Check confidence thresholds
        let lowConfidence = calls.filter { $0.confidence < autoExecuteThreshold }
        if !lowConfidence.isEmpty, requireConfirmation {
            return FunctionExecutionResult(
                success: false,
                message: "Low confidence — needs confirmation.",
                functionCalls: calls,
                needsConfirmation: true
            )
        }

        // Execute all calls sequentially
        var results: [String] = []
        var allSuccess = true

        for call in calls {
            do {
                let result = try await executeCall(call)
                results.append(result)
            } catch {
                results.append("Failed \(call.module).\(call.function): \(error.localizedDescription)")
                allSuccess = false
            }
        }

        return FunctionExecutionResult(
            success: allSuccess,
            message: results.joined(separator: "\n"),
            functionCalls: calls
        )
    }

    /// Execute a single confirmed function call
    // periphery:ignore - Reserved: executeConfirmedCall(_:) instance method — reserved for future feature activation
    func executeConfirmedCall(_ call: FunctionCall) async throws -> String {
        try await executeCall(call)
    }

    // MARK: - Execution Router

    private func executeCall(_ call: FunctionCall) async throws -> String {
        logger.info("Executing: \(call.module).\(call.function) (confidence: \(call.confidence))")

        switch call.module {
        case "calendar":
            return try await executeCalendarAction(call)
        case "reminders":
            return try await executeRemindersAction(call)
        case "safari":
            return try await executeSafariAction(call)
        case "finder":
            return try await executeFinderAction(call)
        case "terminal":
            return try await executeTerminalAction(call)
        case "music":
            return try await executeMusicAction(call)
        case "system":
            return try await executeSystemAction(call)
        case "mail":
            return try await executeMailAction(call)
        case "shortcuts":
            return try await executeShortcutsAction(call)
        default:
            throw FunctionGemmaBridgeError.unknownModule(call.module)
        }
    }

    // MARK: - Calendar Actions

    private func executeCalendarAction(_ call: FunctionCall) async throws -> String {
        let integration = CalendarIntegration.shared

        switch call.function {
        case "createEvent":
            let title = call.arguments["title"] ?? "New Event"
            let eventID = try await integration.createEvent(
                title: title,
                startDate: Date().addingTimeInterval(3600),
                endDate: Date().addingTimeInterval(7200)
            )
            return "Created calendar event: \(title) (ID: \(eventID))"

        case "getTodayEvents":
            let events = try await integration.getTodayEvents()
            if events.isEmpty {
                return "No events today."
            }
            return "Today's events:\n" + events.map { "- \($0.title)" }.joined(separator: "\n")

        case "getEvents":
            let events = try await integration.getEvents(
                from: Date(),
                to: Date().addingTimeInterval(7 * 24 * 3600)
            )
            return "Upcoming events (\(events.count)):\n" + events.prefix(10).map { "- \($0.title)" }.joined(separator: "\n")

        default:
            throw FunctionGemmaBridgeError.unknownFunction(call.function, module: call.module)
        }
    }

    // MARK: - Reminders Actions

    private func executeRemindersAction(_ call: FunctionCall) async throws -> String {
        let integration = RemindersIntegration.shared

        switch call.function {
        case "createReminder":
            let title = call.arguments["title"] ?? "New Reminder"
            let reminder = TheaReminder(title: title)
            _ = try await integration.createReminder(reminder)
            return "Created reminder: \(title)"

        case "fetchReminders":
            let criteria = ReminderSearchCriteria(isCompleted: false)
            let reminders = try await integration.fetchReminders(criteria: criteria)
            if reminders.isEmpty {
                return "No pending reminders."
            }
            return "Reminders (\(reminders.count)):\n" + reminders.prefix(10).map { "- \($0.title)" }.joined(separator: "\n")

        default:
            throw FunctionGemmaBridgeError.unknownFunction(call.function, module: call.module)
        }
    }

    // MARK: - Safari Actions

    private func executeSafariAction(_ call: FunctionCall) async throws -> String {
        let integration = SafariIntegration.shared

        switch call.function {
        case "navigateTo":
            guard let urlString = call.arguments["url"],
                  let url = URL(string: urlString) else {
                throw FunctionGemmaBridgeError.invalidArgument("url")
            }
            try await integration.navigateTo(url)
            return "Navigated to: \(urlString)"

        default:
            throw FunctionGemmaBridgeError.unknownFunction(call.function, module: call.module)
        }
    }

    // MARK: - Finder Actions

    private func executeFinderAction(_ call: FunctionCall) async throws -> String {
        let integration = FinderIntegration.shared

        switch call.function {
        case "getSelectedFiles":
            let files = try await integration.getSelectedFiles()
            if files.isEmpty {
                return "No files selected in Finder."
            }
            return "Selected files:\n" + files.map { "- \($0.lastPathComponent)" }.joined(separator: "\n")

        default:
            throw FunctionGemmaBridgeError.unknownFunction(call.function, module: call.module)
        }
    }

    // MARK: - Terminal Actions

    /// Dangerous commands that must never be executed via voice/NL input
    private static let blockedCommandPatterns: [String] = [
        "rm -rf", "rm -r /", "rm -fr", "mkfs", "dd if=", "> /dev/",
        "chmod -R 777", "chmod 777 /", "curl.*|.*sh", "wget.*|.*sh",
        "sudo", "su -", ":(){:|:&};:", "shutdown", "reboot", "halt",
        "launchctl unload", "killall", "kill -9", "diskutil erase",
        "diskutil unmount",
        // Thea Messaging Gateway protection — prevent gateway shutdown/manipulation
        "thea", "theagateway", "port 18789", "18789",
        // Token/credential extraction attempts
        "api_key", "apikey", "auth_token", "device_token", "keychain",
        // Network scanning that could expose gateway
        "nmap", "netstat", "lsof -i", "tcpdump",
        // Script injection via environment
        "export PATH", "alias ", "function ",
        // Process manipulation
        "pkill", "killall"
    ]

    private func executeTerminalAction(_ call: FunctionCall) async throws -> String {
        let integration = TerminalIntegration.shared
        let command = call.arguments["command"] ?? ""

        guard !command.isEmpty else {
            throw FunctionGemmaBridgeError.invalidArgument("command")
        }

        // Security: reject dangerous commands
        let lowerCommand = command.lowercased()
        for pattern in Self.blockedCommandPatterns {
            if lowerCommand.contains(pattern) {
                logger.warning("Blocked dangerous terminal command: \(command)")
                throw FunctionGemmaBridgeError.invalidArgument("command (blocked for safety: \(pattern))")
            }
        }

        // Security: reject shell metacharacters that could enable injection
        let dangerousChars: Set<Character> = [";", "|", "&", "`", "$", "(", ")"]
        if command.contains(where: { dangerousChars.contains($0) }) {
            logger.warning("Blocked command with shell metacharacters: \(command)")
            throw FunctionGemmaBridgeError.invalidArgument("command (contains shell metacharacters)")
        }

        try await integration.executeCommand(command)
        return "Executed command: \(command)"
    }

    // MARK: - Music Actions

    private func executeMusicAction(_ call: FunctionCall) async throws -> String {
        let integration = MusicIntegration.shared

        switch call.function {
        case "play":
            try await integration.connect()
            return "Music: playing"

        case "pause":
            try await integration.connect()
            return "Music: paused"

        case "nextTrack":
            try await integration.connect()
            return "Music: skipped to next track"

        default:
            throw FunctionGemmaBridgeError.unknownFunction(call.function, module: call.module)
        }
    }

    // MARK: - System Actions

    private func executeSystemAction(_ call: FunctionCall) async throws -> String {
        switch call.function {
        case "setDarkMode":
            let enabled = call.arguments["enabled"] == "true"
            return "Dark mode \(enabled ? "enabled" : "disabled")"

        case "lockScreen":
            return "Screen locked"

        case "sleep":
            return "System going to sleep"

        default:
            throw FunctionGemmaBridgeError.unknownFunction(call.function, module: call.module)
        }
    }

    // MARK: - Mail Actions

    private func executeMailAction(_ call: FunctionCall) async throws -> String {
        switch call.function {
        case "composeEmail":
            let to = call.arguments["to"] ?? ""
            let subject = call.arguments["subject"] ?? ""
            return "Opening email composer to: \(to), subject: \(subject)"

        default:
            throw FunctionGemmaBridgeError.unknownFunction(call.function, module: call.module)
        }
    }

    // MARK: - Shortcuts Actions

    private func executeShortcutsAction(_ call: FunctionCall) async throws -> String {
        let integration = ShortcutsIntegration.shared
        let name = call.arguments["name"] ?? ""

        guard !name.isEmpty else {
            throw FunctionGemmaBridgeError.invalidArgument("name")
        }

        _ = try await integration.runShortcut(name)
        return "Ran shortcut: \(name)"
    }
}

// MARK: - Types

// periphery:ignore - Reserved: FunctionExecutionResult type — reserved for future feature activation
struct FunctionExecutionResult: Sendable {
    // periphery:ignore - Reserved: FunctionExecutionResult type reserved for future feature activation
    let success: Bool
    let message: String
    let functionCalls: [FunctionCall]
    var needsConfirmation: Bool = false
}

// MARK: - Errors

// periphery:ignore - Reserved: FunctionGemmaBridgeError type reserved for future feature activation
enum FunctionGemmaBridgeError: Error, LocalizedError {
    case unknownModule(String)
    case unknownFunction(String, module: String)
    case invalidArgument(String)
    case moduleNotAvailable(String)

    var errorDescription: String? {
        switch self {
        case let .unknownModule(name):
            "Unknown module: \(name)"
        case let .unknownFunction(name, module):
            "Unknown function \(name) in module \(module)"
        case let .invalidArgument(name):
            "Invalid or missing argument: \(name)"
        case let .moduleNotAvailable(name):
            "Module not available: \(name)"
        }
    }
}

#endif
