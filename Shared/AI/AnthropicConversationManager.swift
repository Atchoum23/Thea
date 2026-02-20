// AnthropicConversationManager.swift
// Thea — AR3: Anthropic Conversation State Manager
//
// Enforces the 6 Anthropic API invariants for tool-use conversations:
//   Rule 1: tool_use blocks only in assistant turns
//   Rule 2: tool_result blocks only in user turns
//   Rule 3: Every tool_use has exactly one matching tool_result (by id)
//   Rule 4: No tool_result without a preceding tool_use (no orphans)
//   Rule 5: Truncation removes tool_use/tool_result PAIRS atomically
//   Rule 6: HTTP 400 → recoverFromToolMismatch() → retry once max
//
// AnthropicProvider.chatAdvanced() creates one per call, calls validate()
// before every API send. On HTTP 400, calls recoverFromToolMismatch() and
// retries exactly once via canRetry() / markRetried().
//
// Works with the raw Anthropic API message format ([[String: Any]]) that
// buildAdvancedRequestBody() produces — no dependency on AIMessage.

import Foundation
import OSLog

// MARK: - AnthropicConversationManager

actor AnthropicConversationManager {

    // MARK: - Types

    enum ConversationError: Error, LocalizedError {
        case orphanedToolResult(toolUseID: String)
        case unmatchedToolUse(toolUseID: String)
        case wrongOrder(String)
        case emptyConversation

        var errorDescription: String? {
            switch self {
            case .orphanedToolResult(let id):
                "Orphaned tool_result: no preceding tool_use with id '\(id)'"
            case .unmatchedToolUse(let id):
                "Unmatched tool_use: no tool_result for id '\(id)'"
            case .wrongOrder(let desc):
                "Conversation ordering violation: \(desc)"
            case .emptyConversation:
                "Cannot validate an empty conversation"
            }
        }
    }

    // MARK: - State

    private(set) var messages: [[String: Any]]
    private var retryCount = 0
    private let logger = Logger(subsystem: "ai.thea.app", category: "AnthropicConversationManager")

    static let maxRetries = 1

    // MARK: - Init

    init(messages: [[String: Any]] = []) {
        self.messages = messages
    }

    // MARK: - Mutation

    /// Append a plain (non-tool) message.
    func append(_ message: [String: Any]) {
        messages.append(message)
    }

    /// Append an atomic tool round: assistant message (with tool_use blocks)
    /// followed immediately by a user message (with matching tool_result blocks).
    /// Validates the pair before appending — throws if IDs don't match.
    func appendToolRound(
        assistantMsg: [String: Any],
        toolResults: [String: Any]
    ) throws {
        let toolUseIDs = toolUseIDs(in: assistantMsg)
        guard !toolUseIDs.isEmpty else {
            throw ConversationError.wrongOrder("assistantMsg contains no tool_use blocks")
        }

        let resultIDs = Set(toolResultIDs(in: toolResults))
        let useIDs = Set(toolUseIDs)

        // Every tool_use must have a matching tool_result
        for id in useIDs {
            guard resultIDs.contains(id) else {
                throw ConversationError.unmatchedToolUse(toolUseID: id)
            }
        }

        // No extra tool_results without a preceding tool_use
        for id in resultIDs {
            guard useIDs.contains(id) else {
                throw ConversationError.orphanedToolResult(toolUseID: id)
            }
        }

        // Atomic append — both or neither
        messages.append(assistantMsg)
        messages.append(toolResults)
        logger.debug("AnthropicConversationManager: tool round appended — \(useIDs.count) tool(s)")
    }

    // MARK: - Validate

    /// Pre-send validation. Throws ConversationError on first rule violation.
    /// AnthropicProvider calls this before every API request.
    func validate() throws {
        guard !messages.isEmpty else {
            throw ConversationError.emptyConversation
        }

        // Track tool_use IDs that have been issued but not yet matched
        var pendingToolUseIDs: [String] = []

        for (index, message) in messages.enumerated() {
            let role = message["role"] as? String ?? ""
            let blocks = contentBlocks(in: message)

            let useIDsHere = blocks.compactMap { block -> String? in
                guard (block["type"] as? String) == "tool_use" else { return nil }
                return block["id"] as? String
            }
            let resultIDsHere = blocks.compactMap { block -> String? in
                guard (block["type"] as? String) == "tool_result" else { return nil }
                return block["tool_use_id"] as? String
            }

            // Rule 1: tool_use only in assistant turns
            if !useIDsHere.isEmpty, role != "assistant" {
                throw ConversationError.wrongOrder(
                    "tool_use in '\(role)' turn at index \(index) (must be assistant)"
                )
            }

            // Rule 2: tool_result only in user turns
            if !resultIDsHere.isEmpty, role != "user" {
                throw ConversationError.wrongOrder(
                    "tool_result in '\(role)' turn at index \(index) (must be user)"
                )
            }

            // Rule 4: Every tool_result must reference a pending tool_use
            for id in resultIDsHere {
                guard pendingToolUseIDs.contains(id) else {
                    throw ConversationError.orphanedToolResult(toolUseID: id)
                }
                pendingToolUseIDs.removeAll { $0 == id }
            }

            pendingToolUseIDs.append(contentsOf: useIDsHere)
        }

        // Rule 3: All issued tool_use IDs must be matched
        if let unmatched = pendingToolUseIDs.first {
            throw ConversationError.unmatchedToolUse(toolUseID: unmatched)
        }

        logger.debug("AnthropicConversationManager: validate() OK — \(self.messages.count) messages")
    }

    // MARK: - Truncation

    /// Remove oldest message pairs until estimated token count ≤ maxTokens.
    /// Tool rounds (assistant tool_use + user tool_result) are removed as a unit —
    /// never orphaning a tool_result. Plain user/assistant pairs are also removed together.
    func truncateToFit(maxTokens: Int) {
        // Determine start index: skip any leading system message
        let start = (messages.first?["role"] as? String) == "system" ? 1 : 0

        while estimatedTokens() > maxTokens, messages.count > start + 1 {
            let firstMsg = messages[start]
            let useIDs = toolUseIDs(in: firstMsg)

            // Remove 2 messages (one pair) from the front
            messages.remove(at: start)
            if start < messages.count {
                messages.remove(at: start)
            }

            if !useIDs.isEmpty {
                logger.debug("AnthropicConversationManager: truncated 1 tool round")
            } else {
                logger.debug("AnthropicConversationManager: truncated 1 plain pair")
            }
        }

        logger.info("AnthropicConversationManager: truncated to ~\(self.estimatedTokens()) tokens (\(self.messages.count) messages)")
    }

    // MARK: - Recovery

    /// Scan to the last clean boundary (no pending tool_use without a matching tool_result)
    /// and truncate everything after it. Called before a single retry on HTTP 400.
    func recoverFromToolMismatch() {
        var lastCleanIndex = -1
        var pendingToolUseIDs: [String] = []

        for (index, message) in messages.enumerated() {
            let blocks = contentBlocks(in: message)

            let resultIDsHere = blocks.compactMap { block -> String? in
                guard (block["type"] as? String) == "tool_result" else { return nil }
                return block["tool_use_id"] as? String
            }
            let useIDsHere = blocks.compactMap { block -> String? in
                guard (block["type"] as? String) == "tool_use" else { return nil }
                return block["id"] as? String
            }

            for id in resultIDsHere { pendingToolUseIDs.removeAll { $0 == id } }
            pendingToolUseIDs.append(contentsOf: useIDsHere)

            if pendingToolUseIDs.isEmpty {
                lastCleanIndex = index
            }
        }

        guard lastCleanIndex < messages.count - 1 else {
            logger.debug("AnthropicConversationManager: recover — conversation already clean")
            return
        }

        let removed = messages.count - lastCleanIndex - 1
        messages = Array(messages.prefix(lastCleanIndex + 1))
        logger.warning("AnthropicConversationManager: recover — removed \(removed) messages to last clean boundary")
    }

    // MARK: - Retry Gate

    /// True if another retry is allowed (max 1 retry per manager instance).
    func canRetry() -> Bool { retryCount < Self.maxRetries }

    /// Record that a retry was consumed.
    func markRetried() { retryCount += 1 }

    // MARK: - Token Estimation

    /// Approximate token count: sum all string content lengths, divide by 4.
    func estimatedTokens() -> Int {
        let chars = messages.reduce(0) { sum, msg in
            sum + stringLength(of: msg["content"])
        }
        return max(1, chars / 4)
    }

    // MARK: - Private Helpers

    private func contentBlocks(in message: [String: Any]) -> [[String: Any]] {
        message["content"] as? [[String: Any]] ?? []
    }

    private func toolUseIDs(in message: [String: Any]) -> [String] {
        contentBlocks(in: message).compactMap { block -> String? in
            guard (block["type"] as? String) == "tool_use" else { return nil }
            return block["id"] as? String
        }
    }

    private func toolResultIDs(in message: [String: Any]) -> [String] {
        contentBlocks(in: message).compactMap { block -> String? in
            guard (block["type"] as? String) == "tool_result" else { return nil }
            return block["tool_use_id"] as? String
        }
    }

    private func stringLength(of value: Any?) -> Int {
        guard let value else { return 0 }
        if let str = value as? String { return str.count }
        if let blocks = value as? [[String: Any]] {
            return blocks.reduce(0) { $0 + stringLength(of: $1["text"]) + stringLength(of: $1["content"]) }
        }
        return 0
    }
}
