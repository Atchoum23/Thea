// ToolModels.swift
// Thea
//
// Core models for AI tool use steps — kept in Shared/Core/Models so SPM tests
// can compile MessageMetadata (which stores [ToolUseStep]).
// The AnthropicToolCall-dependent init lives in Shared/AI/Tools/ToolTypes.swift.

import Foundation

// MARK: - Tool Use Step

/// A single tool invocation step visible in the chat UI
struct ToolUseStep: Codable, Sendable, Identifiable {
    let id: String            // Matches AnthropicToolCall.id
    let toolName: String
    let inputSummary: String  // Human-readable description of what was sent
    var result: String?       // Truncated result (≤300 chars)
    var isRunning: Bool       // True while executing
    var errorMessage: String? // Set on failure
}
