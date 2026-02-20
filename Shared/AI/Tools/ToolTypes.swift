// ToolTypes.swift
// Thea
//
// Shared types for Anthropic tool use execution pipeline (B3)
// These are client-side tool invocations — not server-side tools.

import Foundation

// MARK: - Anthropic Tool Call

/// Represents a tool_use block returned by the Anthropic API
struct AnthropicToolCall: Sendable {
    let id: String           // Anthropic tool_use id (needed for tool_result)
    let name: String
    let input: [String: Any] // Parsed JSON input from Claude

    // Sendable conformance: [String: Any] is not Sendable — bridge via JSON round-trip
    func inputJSON() -> Data? {
        try? JSONSerialization.data(withJSONObject: input)
    }

    func inputString(_ key: String) -> String {
        input[key] as? String ?? ""
    }

    func inputBool(_ key: String, default value: Bool = false) -> Bool {
        input[key] as? Bool ?? value
    }

    func inputInt(_ key: String, default value: Int = 0) -> Int {
        input[key] as? Int ?? value
    }
}

// MARK: - Tool Use Step (stored in MessageMetadata)

/// A single tool invocation step, visible in ChatView
struct ToolUseStep: Codable, Sendable, Identifiable {
    let id: String           // Matches AnthropicToolCall.id
    let toolName: String
    let inputSummary: String  // Human-readable description of what was sent
    var result: String?       // Truncated result (≤300 chars)
    var isRunning: Bool       // True while executing
    var errorMessage: String? // Set on failure

    init(call: AnthropicToolCall) {
        self.id = call.id
        self.toolName = call.name
        self.inputSummary = ToolUseStep.summarize(name: call.name, input: call.input)
        self.result = nil
        self.isRunning = true
        self.errorMessage = nil
    }

    private static func summarize(name: String, input: [String: Any]) -> String {
        switch name {
        case "search_memory", "web_search", "notes_search", "finder_search":
            return input["query"] as? String ?? "(no query)"
        case "read_file", "finder_reveal":
            return input["path"] as? String ?? "(no path)"
        case "write_file":
            let path = input["path"] as? String ?? ""
            let bytes = (input["content"] as? String)?.count ?? 0
            return "\(path) (\(bytes) bytes)"
        case "run_command", "terminal_execute":
            return input["command"] as? String ?? "(no command)"
        case "safari_open_url":
            return input["url"] as? String ?? "(no url)"
        case "calendar_create_event", "reminders_create":
            return input["title"] as? String ?? "(no title)"
        case "system_notification":
            return input["title"] as? String ?? "(notification)"
        case "music_play":
            let action = input["action"] as? String ?? "play"
            let search = input["search"] as? String ?? ""
            return search.isEmpty ? action : "\(action): \(search)"
        case "shortcuts_run":
            return input["shortcut_name"] as? String ?? "(no shortcut)"
        default:
            // Show first string value from input as summary
            return input.values.compactMap { $0 as? String }.first ?? name
        }
    }
}

// MARK: - Tool Result

struct ToolResult: Sendable {
    let toolUseId: String
    let content: String
    let isError: Bool

    init(toolUseId: String, content: String, isError: Bool = false) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}
