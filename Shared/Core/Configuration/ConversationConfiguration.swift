// ConversationConfiguration.swift
import Foundation
import SwiftUI

/// Configuration for conversation context and history management.
/// Enables unlimited conversations with maximum context window utilization.
public struct ConversationConfiguration: Codable, Sendable, Equatable {
    // MARK: - Context Window Settings

    /// Maximum context window size (tokens)
    /// Set to nil for unlimited (uses provider's maximum)
    public var maxContextTokens: Int?

    /// Context sizes by provider (for reference)
    public static let providerContextSizes: [String: Int] = [
        "anthropic/claude-sonnet-4": 200_000,
        "anthropic/claude-opus-4": 200_000,
        "openai/gpt-4o": 128_000,
        "openai/gpt-4-turbo": 128_000,
        "google/gemini-2.0-flash": 1_000_000,
        "google/gemini-1.5-pro": 2_000_000,
        "deepseek/deepseek-chat": 128_000,
        "meta-llama/llama-3.1-405b": 128_000
    ]

    // MARK: - Conversation History Settings

    /// Maximum conversation history length (messages)
    /// Set to nil for unlimited
    public var maxConversationLength: Int?

    /// Maximum age of messages to keep (days)
    /// Set to nil for unlimited retention
    public var maxMessageAgeDays: Int?

    /// Whether to persist full conversation history to disk
    public var persistFullHistory: Bool = true

    // MARK: - Context Management Strategy

    /// How to handle context window limits
    public var contextStrategy: ContextStrategy = .unlimited

    public enum ContextStrategy: String, Codable, CaseIterable, Sendable {
        case unlimited = "Unlimited"
        case sliding = "Sliding Window"
        case summarize = "Smart Summarization"
        case hybrid = "Hybrid (Summarize + Recent)"

        public var description: String {
            switch self {
            case .unlimited:
                "Keep all messages, use provider's full context window"
            case .sliding:
                "Keep most recent messages, drop oldest when limit reached"
            case .summarize:
                "Summarize old messages to preserve context efficiently"
            case .hybrid:
                "Keep recent messages verbatim + summary of older context"
            }
        }
    }

    // MARK: - Meta-AI Context Settings

    /// Enable Meta-AI to request larger context windows
    public var allowMetaAIContextExpansion: Bool = true

    /// Preferred context size for Meta-AI operations (tokens)
    /// Recommended: 200k for Claude, 128k for GPT-4o, 1M for Gemini
    public var metaAIPreferredContext: Int = 200_000

    /// Reserve context tokens for Meta-AI reasoning
    /// Meta-AI needs space for chain-of-thought, planning, etc.
    public var metaAIReservedTokens: Int = 50000

    /// Priority allocation for Meta-AI vs regular chat
    public var metaAIContextPriority: MetaAIPriority = .high

    public enum MetaAIPriority: String, Codable, CaseIterable, Sendable {
        case normal = "Normal"
        case high = "High"
        case maximum = "Maximum"

        public var allocationPercentage: Double {
            switch self {
            case .normal: 0.5 // 50% for Meta-AI
            case .high: 0.7 // 70% for Meta-AI
            case .maximum: 0.9 // 90% for Meta-AI
            }
        }
    }

    // MARK: - Token Counting

    /// Method for counting tokens
    public var tokenCountingMethod: TokenCountingMethod = .accurate

    public enum TokenCountingMethod: String, Codable, Sendable {
        case estimate = "Estimate (Fast)"
        case accurate = "Accurate (Slower)"

        /// Approximate tokens per character for estimation
        public static let tokensPerChar: Double = 0.25
    }

    // MARK: - Streaming Settings

    /// Enable streaming responses
    public var enableStreaming: Bool = true

    /// Buffer size for streaming (characters)
    public var streamingBufferSize: Int = 100

    // MARK: - Persistence

    private static let storageKey = "com.thea.conversation.configuration"

    public static func load() -> ConversationConfiguration {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(ConversationConfiguration.self, from: data)
        else {
            return ConversationConfiguration()
        }
        return config
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Convenience Methods

    /// Get effective context size for a provider
    public func getEffectiveContextSize(for provider: String) -> Int {
        if let custom = maxContextTokens {
            return custom
        }
        return Self.providerContextSizes[provider] ?? 128_000
    }

    /// Get available context for conversation after Meta-AI reservation
    public func getAvailableContextForChat(provider: String) -> Int {
        let total = getEffectiveContextSize(for: provider)
        let reserved = allowMetaAIContextExpansion ? metaAIReservedTokens : 0
        return total - reserved
    }

    /// Check if context strategy allows unlimited history
    public var isUnlimited: Bool {
        contextStrategy == .unlimited &&
            maxConversationLength == nil &&
            maxContextTokens == nil
    }
}
