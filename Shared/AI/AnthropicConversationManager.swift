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
// Uses NSLock for thread safety (@unchecked Sendable). All access within
// chatAdvanced() is sequential — no concurrent access in practice.
// The lock guards against future multi-task usage without requiring `actor`
// (which would make [[String: Any]] — a non-Sendable type — impossible to
// return across the actor isolation boundary).

import Foundation
import OSLog

// MARK: - AnthropicConversationManager

final class AnthropicConversationManager: @unchecked Sendable {

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

    private let lock = NSLock()
    private var _messages: [[String: Any]]
    private var retryCount = 0
    private let logger = Logger(subsystem: "ai.thea.app", category: "AnthropicConversationManager")

    static let maxRetries = 1

    var messages: [[String: Any]] { lock.withLock { _messages } }

    // MARK: - Init

    init(messages: [[String: Any]] = []) {
        _messages = messages
    }

    // MARK: - Mutation

    /// Append a plain (non-tool) message.
    func append(_ message: [String: Any]) {
        lock.withLock { _messages.append(message) }
    }

    /// Append an atomic tool round: assistant message (with tool_use blocks)
    /// followed immediately by a user message (with matching tool_result blocks).
    /// Validates the pair before appending — throws if IDs don't match.
    func appendToolRound(
        assistantMsg: [String: Any],
        toolResults: [String: Any]
    ) throws {
        let toolUseIDs = toolUseIDsIn(assistantMsg)
        guard !toolUseIDs.isEmpty else {
            throw ConversationError.wrongOrder("assistantMsg contains no tool_use blocks")
        }

        let resultIDs = Set(toolResultIDsIn(toolResults))
        let useIDs = Set(toolUseIDs)

        for id in useIDs {
            guard resultIDs.contains(id) else {
                throw ConversationError.unmatchedToolUse(toolUseID: id)
            }
        }
        for id in resultIDs {
            guard useIDs.contains(id) else {
                throw ConversationError.orphanedToolResult(toolUseID: id)
            }
        }

        lock.withLock {
            _messages.append(assistantMsg)
            _messages.append(toolResults)
        }
        logger.debug("AnthropicConversationManager: tool round appended — \(useIDs.count) tool(s)")
    }

    // MARK: - Validate

    /// Pre-send validation. Throws ConversationError on first rule violation.
    /// AnthropicProvider calls this before every API request.
    func validate() throws {
        let snapshot = lock.withLock { _messages }
        guard !snapshot.isEmpty else {
            throw ConversationError.emptyConversation
        }

        var pendingToolUseIDs: [String] = []

        for (index, message) in snapshot.enumerated() {
            let role = message["role"] as? String ?? ""
            let blocks = contentBlocksIn(message)

            let useIDsHere = blocks.compactMap { block -> String? in
                guard (block["type"] as? String) == "tool_use" else { return nil }
                return block["id"] as? String
            }
            let resultIDsHere = blocks.compactMap { block -> String? in
                guard (block["type"] as? String) == "tool_result" else { return nil }
                return block["tool_use_id"] as? String
            }

            if !useIDsHere.isEmpty, role != "assistant" {
                throw ConversationError.wrongOrder(
                    "tool_use in '\(role)' turn at index \(index) (must be assistant)"
                )
            }
            if !resultIDsHere.isEmpty, role != "user" {
                throw ConversationError.wrongOrder(
                    "tool_result in '\(role)' turn at index \(index) (must be user)"
                )
            }

            for id in resultIDsHere {
                guard pendingToolUseIDs.contains(id) else {
                    throw ConversationError.orphanedToolResult(toolUseID: id)
                }
                pendingToolUseIDs.removeAll { $0 == id }
            }
            pendingToolUseIDs.append(contentsOf: useIDsHere)
        }

        if let unmatched = pendingToolUseIDs.first {
            throw ConversationError.unmatchedToolUse(toolUseID: unmatched)
        }

        logger.debug("AnthropicConversationManager: validate() OK — \(snapshot.count) messages")
    }

    // MARK: - Truncation

    /// Remove oldest message pairs until estimated token count ≤ maxTokens.
    /// Tool rounds removed as a unit — never orphans a tool_result.
    func truncateToFit(maxTokens: Int) {
        let start = (lock.withLock { _messages.first })?["role"] as? String == "system" ? 1 : 0

        while estimatedTokens() > maxTokens {
            let count = lock.withLock { _messages.count }
            guard count > start + 1 else { break }

            lock.withLock {
                guard _messages.count > start else { return }
                _messages.remove(at: start)
                if start < _messages.count { _messages.remove(at: start) }
            }
        }

        let remaining = lock.withLock { _messages.count }
        logger.info("AnthropicConversationManager: truncated to ~\(self.estimatedTokens()) tokens (\(remaining) messages)")
    }

    // MARK: - Recovery

    /// Scan to the last clean boundary and truncate everything after it.
    /// Called before a single retry on HTTP 400.
    func recoverFromToolMismatch() {
        let snapshot = lock.withLock { _messages }
        var lastCleanIndex = -1
        var pendingToolUseIDs: [String] = []

        for (index, message) in snapshot.enumerated() {
            let blocks = contentBlocksIn(message)

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

            if pendingToolUseIDs.isEmpty { lastCleanIndex = index }
        }

        guard lastCleanIndex < snapshot.count - 1 else {
            logger.debug("AnthropicConversationManager: recover — conversation already clean")
            return
        }

        let removed = snapshot.count - lastCleanIndex - 1
        lock.withLock { _messages = Array(snapshot.prefix(lastCleanIndex + 1)) }
        logger.warning("AnthropicConversationManager: recover — removed \(removed) messages to last clean boundary")
    }

    // MARK: - Retry Gate

    func canRetry() -> Bool { retryCount < Self.maxRetries }
    func markRetried() { retryCount += 1 }

    // MARK: - Token Estimation

    func estimatedTokens() -> Int {
        let chars = lock.withLock { _messages }.reduce(0) { sum, msg in
            sum + stringLength(of: msg["content"])
        }
        return max(1, chars / 4)
    }

    // MARK: - Private Helpers

    private func contentBlocksIn(_ message: [String: Any]) -> [[String: Any]] {
        message["content"] as? [[String: Any]] ?? []
    }

    private func toolUseIDsIn(_ message: [String: Any]) -> [String] {
        contentBlocksIn(message).compactMap { block -> String? in
            guard (block["type"] as? String) == "tool_use" else { return nil }
            return block["id"] as? String
        }
    }

    private func toolResultIDsIn(_ message: [String: Any]) -> [String] {
        contentBlocksIn(message).compactMap { block -> String? in
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
