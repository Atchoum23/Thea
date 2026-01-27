// ContextManager.swift
import Foundation
import OSLog

/// Manages conversation context window and history.
/// Ensures Meta-AI operations have maximum context available.
public actor ContextManager {
    public static let shared = ContextManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "ContextManager")
    private var config = ConversationConfiguration.load()

    // MARK: - Types

    public struct ContextWindow: Sendable {
        public let totalTokens: Int
        public let usedTokens: Int
        public let availableTokens: Int
        public let messagesIncluded: Int
        public let strategy: ConversationConfiguration.ContextStrategy
    }

    public struct TokenizedMessage: Sendable {
        public let id: UUID
        public let role: String
        public let content: String
        public let tokenCount: Int
        public let timestamp: Date
    }

    // MARK: - Public API

    /// Reload configuration
    public func reloadConfiguration() {
        config = ConversationConfiguration.load()
        logger.info("Context configuration reloaded")
    }

    /// Count tokens in text
    public func countTokens(_ text: String) -> Int {
        switch config.tokenCountingMethod {
        case .estimate:
            // Fast estimation: ~4 chars per token average
            Int(Double(text.count) * ConversationConfiguration.TokenCountingMethod.tokensPerChar)
        case .accurate:
            // More accurate: use tiktoken-style counting
            accurateTokenCount(text)
        }
    }

    /// Get context window for a conversation
    public func getContextWindow(
        messages: [TokenizedMessage],
        provider: String,
        forMetaAI: Bool = false
    ) -> ContextWindow {
        let totalTokens = config.getEffectiveContextSize(for: provider)

        // Calculate reserved space
        let reservedForResponse = 4096 // Space for model's response
        let reservedForMetaAI = forMetaAI ? config.metaAIReservedTokens : 0
        let availableForMessages = totalTokens - reservedForResponse - reservedForMetaAI

        // Select messages based on strategy
        let (selectedMessages, usedTokens) = selectMessages(
            from: messages,
            maxTokens: availableForMessages
        )

        return ContextWindow(
            totalTokens: totalTokens,
            usedTokens: usedTokens,
            availableTokens: availableForMessages - usedTokens,
            messagesIncluded: selectedMessages.count,
            strategy: config.contextStrategy
        )
    }

    /// Prepare messages for API call, respecting context limits
    public func prepareMessagesForAPI(
        messages: [TokenizedMessage],
        provider: String,
        forMetaAI: Bool = false
    ) async -> [TokenizedMessage] {
        let totalTokens = config.getEffectiveContextSize(for: provider)
        let reservedForResponse = 4096
        let reservedForMetaAI = forMetaAI ? config.metaAIReservedTokens : 0
        let availableForMessages = totalTokens - reservedForResponse - reservedForMetaAI

        switch config.contextStrategy {
        case .unlimited:
            // Return all messages, let provider handle truncation
            return messages

        case .sliding:
            // Keep most recent messages that fit
            return selectRecentMessages(from: messages, maxTokens: availableForMessages)

        case .summarize:
            // Summarize old messages, keep recent ones
            return await summarizeAndPrepare(messages: messages, maxTokens: availableForMessages)

        case .hybrid:
            // Summary of old + recent verbatim
            return await hybridPrepare(messages: messages, maxTokens: availableForMessages)
        }
    }

    /// Check if adding a message would exceed context
    public func wouldExceedContext(
        currentTokens: Int,
        newMessageTokens: Int,
        provider: String
    ) -> Bool {
        guard config.contextStrategy != .unlimited else { return false }

        let maxTokens = config.getEffectiveContextSize(for: provider)
        let reservedForResponse = 4096
        return (currentTokens + newMessageTokens) > (maxTokens - reservedForResponse)
    }

    // MARK: - Private Implementation

    private func accurateTokenCount(_ text: String) -> Int {
        // More accurate estimation using word/subword boundaries
        // This is still an approximation without a real tokenizer
        var count = 0
        let words = text.components(separatedBy: .whitespacesAndNewlines)

        for word in words where !word.isEmpty {
            // Average: 1 token per 4 characters, with minimum 1 token per word
            let wordTokens = max(1, (word.count + 3) / 4)
            count += wordTokens
        }

        // Add tokens for whitespace/newlines (roughly 1 per newline)
        count += text.components(separatedBy: .newlines).count - 1

        return count
    }

    private func selectMessages(
        from messages: [TokenizedMessage],
        maxTokens: Int
    ) -> ([TokenizedMessage], Int) {
        guard config.contextStrategy != .unlimited else {
            let total = messages.reduce(0) { $0 + $1.tokenCount }
            return (messages, total)
        }

        var selected: [TokenizedMessage] = []
        var totalTokens = 0

        // Always include system message if present
        if let systemMsg = messages.first(where: { $0.role == "system" }) {
            selected.append(systemMsg)
            totalTokens += systemMsg.tokenCount
        }

        // Add messages from most recent, going backwards
        for message in messages.reversed() where message.role != "system" {
            if totalTokens + message.tokenCount <= maxTokens {
                selected.insert(message, at: !selected.isEmpty && selected[0].role == "system" ? 1 : 0)
                totalTokens += message.tokenCount
            } else {
                break
            }
        }

        return (selected, totalTokens)
    }

    private func selectRecentMessages(
        from messages: [TokenizedMessage],
        maxTokens: Int
    ) -> [TokenizedMessage] {
        let (selected, _) = selectMessages(from: messages, maxTokens: maxTokens)
        return selected
    }

    private func summarizeAndPrepare(
        messages: [TokenizedMessage],
        maxTokens: Int
    ) async -> [TokenizedMessage] {
        // For now, fall back to sliding window
        // TODO: Implement actual summarization using AI
        logger.info("Summarization requested but using sliding window fallback")
        return selectRecentMessages(from: messages, maxTokens: maxTokens)
    }

    private func hybridPrepare(
        messages: [TokenizedMessage],
        maxTokens: Int
    ) async -> [TokenizedMessage] {
        // Reserve 30% for summary, 70% for recent messages
        let recentTokens = Int(Double(maxTokens) * 0.7)

        // Get recent messages
        let recentMessages = selectRecentMessages(from: messages, maxTokens: recentTokens)

        // TODO: Generate summary of older messages and prepend
        logger.info("Hybrid mode using recent messages (summary TODO)")

        return recentMessages
    }
}
