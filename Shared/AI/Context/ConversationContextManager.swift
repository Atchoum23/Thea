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

    // MARK: - Context Carryover (Stalled Conversation Detection)

    /// Stalled conversation threshold (seconds of inactivity)
    private var stalledThreshold: TimeInterval = 300 // 5 minutes

    /// Configure stalled threshold
    func setStalledThreshold(_ seconds: TimeInterval) {
        stalledThreshold = seconds
    }

    /// Detect if a conversation is stalled (inactive)
    func detectStalledConversation(for conversationId: UUID) -> Bool {
        guard let context = contexts[conversationId] else { return false }

        let timeSinceUpdate = Date().timeIntervalSince(context.lastUpdated)
        return timeSinceUpdate > stalledThreshold
    }

    /// Get how long a conversation has been stalled
    func getStalledConversationAge(for conversationId: UUID) -> TimeInterval? {
        guard let context = contexts[conversationId] else { return nil }

        let timeSinceUpdate = Date().timeIntervalSince(context.lastUpdated)
        if timeSinceUpdate > stalledThreshold {
            return timeSinceUpdate
        }
        return nil
    }

    /// Suggest related topics for a stalled conversation
    func suggestRelatedTopics(for conversationId: UUID, using memoryService: @escaping () async -> [String]) async -> [String] {
        guard let context = contexts[conversationId] else { return [] }

        // Extract key topics from recent messages
        let recentBlocks = context.blocks.suffix(10)
        let recentContent = recentBlocks.map { $0.content }.joined(separator: " ")

        // Extract keywords
        let keywords = extractKeywords(from: recentContent)

        // Query memory service for related content
        var suggestions: [String] = []

        // Try to get related memories
        let memories = await memoryService()
        for memory in memories.prefix(5) {
            if !suggestions.contains(memory) {
                suggestions.append(memory)
            }
        }

        // Generate topic-based suggestions
        for keyword in keywords.prefix(3) {
            let suggestion = "Would you like to continue discussing \(keyword)?"
            if !suggestions.contains(suggestion) {
                suggestions.append(suggestion)
            }
        }

        return Array(suggestions.prefix(5))
    }

    /// Suggest follow-up questions based on conversation context
    func suggestFollowUpQuestions(for conversationId: UUID) -> [String] {
        guard let context = contexts[conversationId] else { return [] }

        var suggestions: [String] = []

        // Analyze the last assistant message for potential follow-ups
        let assistantBlocks = context.blocks.filter { $0.source == .assistantMessage }
        guard let lastAssistant = assistantBlocks.last else { return [] }

        let content = lastAssistant.content.lowercased()

        // Pattern-based suggestions
        if content.contains("example") {
            suggestions.append("Can you provide another example?")
        }
        if content.contains("steps") || content.contains("first") {
            suggestions.append("What's the next step?")
        }
        if content.contains("however") || content.contains("but") || content.contains("alternatively") {
            suggestions.append("Can you explain the alternative approach?")
        }
        if content.contains("important") || content.contains("key") {
            suggestions.append("Why is this important?")
        }
        if content.contains("code") || content.contains("function") {
            suggestions.append("Can you explain how this code works?")
        }
        if content.contains("error") || content.contains("issue") {
            suggestions.append("How can I prevent this error?")
        }

        // Generic follow-ups if no patterns matched
        if suggestions.isEmpty {
            suggestions = [
                "Can you elaborate on that?",
                "What are the key takeaways?",
                "Are there any common mistakes to avoid?"
            ]
        }

        return Array(suggestions.prefix(3))
    }

    /// Check if conversation needs context refresh
    func needsContextRefresh(for conversationId: UUID) -> Bool {
        guard let context = contexts[conversationId] else { return false }

        // Check if context is too old
        let oldestBlock = context.blocks.min { $0.timestamp < $1.timestamp }
        if let oldest = oldestBlock {
            let ageInHours = Date().timeIntervalSince(oldest.timestamp) / 3600
            if ageInHours > 24 {
                return true
            }
        }

        // Check if context utilization is high
        let utilization = Double(context.totalTokens) / Double(maxContextTokens)
        if utilization > 0.8 {
            return true
        }

        return false
    }

    /// Get a summary of the conversation for context refresh
    func getConversationSummary(for conversationId: UUID) -> String? {
        guard let context = contexts[conversationId] else { return nil }

        let userMessages = context.blocks.filter { $0.source == .userMessage }
        let topics = userMessages.flatMap { extractKeywords(from: $0.content) }
        let uniqueTopics = Array(Set(topics)).prefix(5)

        if uniqueTopics.isEmpty {
            return nil
        }

        return "Previous discussion covered: \(uniqueTopics.joined(separator: ", "))"
    }

    // MARK: - Private Helpers

    private func extractKeywords(from text: String) -> [String] {
        // Simple keyword extraction - remove common words
        let stopWords = Set(["the", "a", "an", "is", "are", "was", "were", "be", "been",
                            "being", "have", "has", "had", "do", "does", "did", "will",
                            "would", "could", "should", "may", "might", "must", "shall",
                            "can", "to", "of", "in", "for", "on", "with", "at", "by",
                            "from", "or", "and", "but", "if", "then", "else", "when",
                            "there", "here", "this", "that", "these", "those", "it",
                            "its", "i", "you", "we", "they", "he", "she", "what", "how",
                            "why", "where", "which", "who", "whom", "whose"])

        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !stopWords.contains($0) }

        // Count frequency
        var frequency: [String: Int] = [:]
        for word in words {
            frequency[word, default: 0] += 1
        }

        // Return top keywords by frequency
        return frequency
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
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
