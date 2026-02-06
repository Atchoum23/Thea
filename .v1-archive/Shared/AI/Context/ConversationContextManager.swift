// ConversationContextManager.swift
// Centralized conversation context management for the Meta-AI system
// Handles context windows, memory management, and relevance-based retrieval
// Note: Named ConversationContextManager to avoid conflict with Core/Configuration/ContextManager

import Foundation

// MARK: - Context Types

/// A block of context with metadata
struct ContextBlock: Identifiable, Codable, Sendable {
    let id: UUID
    let content: String
    let source: ContextSource
    let timestamp: Date
    let relevanceScore: Double
    let tokenCount: Int
    var isActive: Bool

    init(
        id: UUID = UUID(),
        content: String,
        source: ContextSource,
        timestamp: Date = Date(),
        relevanceScore: Double = 1.0,
        tokenCount: Int? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.content = content
        self.source = source
        self.timestamp = timestamp
        self.relevanceScore = relevanceScore
        self.tokenCount = tokenCount ?? Self.estimateTokenCount(content)
        self.isActive = isActive
    }

    private static func estimateTokenCount(_ text: String) -> Int {
        // Rough estimate: ~4 characters per token for English
        // Adjust for different languages/scripts
        max(1, text.count / 4)
    }
}

/// Source of context information
enum ContextSource: String, Codable, Sendable {
    case userMessage = "user"
    case assistantMessage = "assistant"
    case systemPrompt = "system"
    case document = "document"
    case codeFile = "code"
    case webSearch = "web"
    case memory = "memory"
    case tool = "tool"
}

/// Managed conversation context container for the context manager
struct ManagedConversationContext: Codable, Sendable {
    var conversationId: UUID
    var blocks: [ContextBlock]
    var totalTokens: Int
    var createdAt: Date
    var lastUpdated: Date
    var metadata: ManagedContextMetadata

    struct ManagedContextMetadata: Codable, Sendable {
        var title: String?
        var tags: [String]
        var priority: Int
        var isArchived: Bool

        init(title: String? = nil, tags: [String] = [], priority: Int = 0, isArchived: Bool = false) {
            self.title = title
            self.tags = tags
            self.priority = priority
            self.isArchived = isArchived
        }
    }

    init(conversationId: UUID = UUID()) {
        self.conversationId = conversationId
        self.blocks = []
        self.totalTokens = 0
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.metadata = ManagedContextMetadata()
    }

    mutating func addBlock(_ block: ContextBlock) {
        blocks.append(block)
        totalTokens += block.tokenCount
        lastUpdated = Date()
    }

    mutating func removeBlock(id: UUID) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            totalTokens -= blocks[index].tokenCount
            blocks.remove(at: index)
            lastUpdated = Date()
        }
    }
}

// MARK: - Conversation Context Manager

/// Actor-based conversation context manager for thread-safe operations
/// Manages conversation-specific context with relevance scoring and pruning
actor ConversationContextManager {
    static let shared = ConversationContextManager()

    // Storage
    private var contexts: [UUID: ManagedConversationContext] = [:]
    private var activeConversationId: UUID?

    // Configuration
    private var maxContextTokens: Int = 128_000  // Default 128K
    private var pruneThreshold: Double = 0.9     // Prune when 90% full
    private var relevanceDecayRate: Double = 0.1 // Relevance decay per hour

    private init() {
        // Defer loading to first access since we can't call actor-isolated methods from init
    }

    /// Initialize and load any persisted contexts
    func initialize() async {
        loadPersistedContexts()
    }

    // MARK: - Dynamic Token Limit

    /// Set max tokens based on available resources
    func setMaxContextTokens(_ tokens: Int) {
        maxContextTokens = tokens
    }

    /// Get current max tokens
    func getMaxContextTokens() -> Int {
        maxContextTokens
    }

    // MARK: - Context Creation

    /// Create a new conversation context
    func createContext() -> UUID {
        let context = ManagedConversationContext()
        contexts[context.conversationId] = context
        activeConversationId = context.conversationId
        return context.conversationId
    }

    /// Get or create context for a conversation
    func getOrCreateContext(for conversationId: UUID) -> ManagedConversationContext {
        if let existing = contexts[conversationId] {
            return existing
        }
        let newContext = ManagedConversationContext(conversationId: conversationId)
        contexts[conversationId] = newContext
        return newContext
    }

    // MARK: - Adding Context

    /// Add content to a conversation's context
    func addContext(
        _ content: String,
        source: ContextSource,
        for conversationId: UUID,
        relevanceScore: Double = 1.0
    ) {
        var context = getOrCreateContext(for: conversationId)

        let block = ContextBlock(
            content: content,
            source: source,
            relevanceScore: relevanceScore
        )

        context.addBlock(block)
        contexts[conversationId] = context

        // Check if pruning is needed
        if Double(context.totalTokens) > Double(maxContextTokens) * pruneThreshold {
            pruneContext(for: conversationId)
        }
    }

    /// Add a user message to context
    func addUserMessage(_ message: String, for conversationId: UUID) {
        addContext(message, source: .userMessage, for: conversationId, relevanceScore: 1.0)
    }

    /// Add an assistant response to context
    func addAssistantMessage(_ message: String, for conversationId: UUID) {
        addContext(message, source: .assistantMessage, for: conversationId, relevanceScore: 0.9)
    }

    /// Add system prompt to context
    func addSystemPrompt(_ prompt: String, for conversationId: UUID) {
        addContext(prompt, source: .systemPrompt, for: conversationId, relevanceScore: 1.0)
    }

    // MARK: - Retrieving Context

    /// Get all context for a conversation
    func getContext(for conversationId: UUID) -> ManagedConversationContext? {
        contexts[conversationId]
    }

    /// Get relevant context blocks for a query
    func getRelevantContext(
        for query: String,
        conversationId: UUID,
        maxTokens: Int? = nil
    ) -> [ContextBlock] {
        guard var context = contexts[conversationId] else { return [] }

        let limit = maxTokens ?? maxContextTokens

        // Update relevance scores based on query similarity and time decay
        let now = Date()
        for i in context.blocks.indices {
            var block = context.blocks[i]

            // Apply time decay
            let hoursSinceCreation = now.timeIntervalSince(block.timestamp) / 3600
            let timeDecay = exp(-relevanceDecayRate * hoursSinceCreation)

            // Calculate query similarity (simple keyword matching)
            let querySimilarity = calculateSimilarity(query: query, content: block.content)

            // Combined relevance
            block = ContextBlock(
                id: block.id,
                content: block.content,
                source: block.source,
                timestamp: block.timestamp,
                relevanceScore: block.relevanceScore * timeDecay * (0.5 + 0.5 * querySimilarity),
                tokenCount: block.tokenCount,
                isActive: block.isActive
            )
            context.blocks[i] = block
        }

        contexts[conversationId] = context

        // Sort by relevance and select up to token limit
        let sorted = context.blocks
            .filter { $0.isActive }
            .sorted { $0.relevanceScore > $1.relevanceScore }

        var selected: [ContextBlock] = []
        var tokenCount = 0

        for block in sorted {
            if tokenCount + block.tokenCount <= limit {
                selected.append(block)
                tokenCount += block.tokenCount
            } else {
                break
            }
        }

        // Re-sort by timestamp for chronological order
        return selected.sorted { $0.timestamp < $1.timestamp }
    }

    /// Get context as formatted messages
    func getFormattedContext(for conversationId: UUID, maxTokens: Int? = nil) -> [ContextMessage] {
        let blocks = getRelevantContext(for: "", conversationId: conversationId, maxTokens: maxTokens)

        return blocks.map { block in
            let role: ContextMessage.Role = switch block.source {
            case .userMessage: .user
            case .assistantMessage: .assistant
            case .systemPrompt: .system
            default: .system
            }

            return ContextMessage(role: role, content: block.content)
        }
    }

    // MARK: - Context Management

    /// Prune context to stay within limits
    func pruneContext(for conversationId: UUID, keeping targetTokens: Int? = nil) {
        guard var context = contexts[conversationId] else { return }

        let target = targetTokens ?? Int(Double(maxContextTokens) * 0.7)

        // Sort by relevance (lowest first) and remove until under limit
        let sortedIndices = context.blocks.indices.sorted {
            context.blocks[$0].relevanceScore < context.blocks[$1].relevanceScore
        }

        var indicesToRemove: [Int] = []
        var currentTokens = context.totalTokens

        for index in sortedIndices {
            if currentTokens <= target { break }

            // Don't remove system prompts
            if context.blocks[index].source == .systemPrompt { continue }

            indicesToRemove.append(index)
            currentTokens -= context.blocks[index].tokenCount
        }

        // Remove in reverse order to maintain indices
        for index in indicesToRemove.sorted().reversed() {
            context.blocks.remove(at: index)
        }

        context.totalTokens = currentTokens
        context.lastUpdated = Date()
        contexts[conversationId] = context
    }

    /// Clear all context for a conversation
    func clearContext(for conversationId: UUID) {
        contexts[conversationId] = nil
    }

    /// Archive a conversation context
    func archiveContext(for conversationId: UUID) {
        guard var context = contexts[conversationId] else { return }
        context.metadata.isArchived = true
        contexts[conversationId] = context
        persistContexts()
    }

    // MARK: - Similarity Calculation

    private func calculateSimilarity(query: String, content: String) -> Double {
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
        let contentWords = Set(content.lowercased().split(separator: " ").map(String.init))

        guard !queryWords.isEmpty else { return 0.5 }

        let intersection = queryWords.intersection(contentWords)
        return Double(intersection.count) / Double(queryWords.count)
    }

    // MARK: - Persistence

    private func loadPersistedContexts() {
        // Load from UserDefaults or file storage
        // Implementation depends on persistence strategy
    }

    private func persistContexts() {
        // Save to UserDefaults or file storage
        // Implementation depends on persistence strategy
    }

    // MARK: - Statistics

    /// Get context statistics
    func getStatistics(for conversationId: UUID) -> ContextStatistics? {
        guard let context = contexts[conversationId] else { return nil }

        return ContextStatistics(
            totalBlocks: context.blocks.count,
            totalTokens: context.totalTokens,
            maxTokens: maxContextTokens,
            utilizationPercent: Double(context.totalTokens) / Double(maxContextTokens) * 100,
            oldestBlockAge: context.blocks.map(\.timestamp).min().map { Date().timeIntervalSince($0) } ?? 0,
            sourceBreakdown: Dictionary(grouping: context.blocks, by: \.source).mapValues(\.count)
        )
    }

    struct ContextStatistics {
        let totalBlocks: Int
        let totalTokens: Int
        let maxTokens: Int
        let utilizationPercent: Double
        let oldestBlockAge: TimeInterval
        let sourceBreakdown: [ContextSource: Int]
    }
}

// MARK: - Context Message Type

/// Lightweight message DTO for context formatting
struct ContextMessage: Codable, Sendable {
    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    let role: Role
    let content: String
}
