// ToolTypes.swift
// Thea
//
// Shared types for Anthropic tool use execution pipeline (B3)
// These are client-side tool invocations — not server-side tools.

import Foundation

// MARK: - Anthropic Tool Call

/// Represents a tool_use block returned by the Anthropic API
struct AnthropicToolCall: @unchecked Sendable {
    let id: String           // Anthropic tool_use id (needed for tool_result)
    let name: String
    let input: [String: Any] // Parsed JSON input from Claude

    // Sendable conformance: [String: Any] is not Sendable — bridge via JSON round-trip
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func inputJSON() -> Data? {
        try? JSONSerialization.data(withJSONObject: input)
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func inputString(_ key: String) -> String {
        input[key] as? String ?? ""
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func inputBool(_ key: String, default value: Bool = false) -> Bool {
        input[key] as? Bool ?? value
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func inputInt(_ key: String, default value: Int = 0) -> Int {
        input[key] as? Int ?? value
    }
}

// MARK: - Tool Use Step (base struct in Shared/Core/Models/ToolModels.swift)

// ToolUseStep is defined in Shared/Core/Models/ToolModels.swift so SPM tests compile.
// Extension adds AnthropicToolCall-dependent initializer + summarize helper.
extension ToolUseStep {
    init(call: AnthropicToolCall) {
        self.id = call.id
        self.toolName = call.name
        self.inputSummary = ToolUseStep.summarize(name: call.name, input: call.input)
        self.result = nil
        self.isRunning = true
        self.errorMessage = nil
    }

    static func summarize(name: String, input: [String: Any]) -> String {
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
            return input.values.compactMap { $0 as? String }.first ?? name
        }
    }
}

// MARK: - Tool Result

struct AnthropicToolResult: Sendable {
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    let toolUseId: String
    let content: String
    let isError: Bool

    init(toolUseId: String, content: String, isError: Bool = false) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}
