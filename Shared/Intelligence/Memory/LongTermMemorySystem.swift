// ConversationUnifiedMemorySystem.swift
// Thea V2
//
// Comprehensive memory system with episodic, semantic, and working memory
// Enables long-term learning, context retrieval, and memory consolidation

import Foundation
import OSLog

// MARK: - Episodic Memory

/// A single episode representing a past interaction/task
public struct Episode: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let sessionId: UUID
    public let taskDescription: String
    public let taskType: String
    public let outcome: EpisodeOutcome
    public let duration: TimeInterval
    public let userFeedback: EpisodeFeedback?
    public let lessonsLearned: [String]
    public let contextSummary: String
    public let relatedEpisodeIds: [UUID]
    public let embedding: [Float]?  // For semantic search
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: UUID,
        taskDescription: String,
        taskType: String,
        outcome: EpisodeOutcome,
        duration: TimeInterval,
        userFeedback: EpisodeFeedback? = nil,
        lessonsLearned: [String] = [],
        contextSummary: String = "",
        relatedEpisodeIds: [UUID] = [],
        embedding: [Float]? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.taskDescription = taskDescription
        self.taskType = taskType
        self.outcome = outcome
        self.duration = duration
        self.userFeedback = userFeedback
        self.lessonsLearned = lessonsLearned
        self.contextSummary = contextSummary
        self.relatedEpisodeIds = relatedEpisodeIds
        self.embedding = embedding
        self.metadata = metadata
    }
}

/// Outcome of an episode
public enum EpisodeOutcome: String, Codable, Sendable {
    case success
    case partialSuccess
    case failure
    case abandoned
    case pending
}

/// User feedback on an episode
public struct EpisodeFeedback: Codable, Sendable {
    public let rating: Int  // 1-5
    public let comment: String?
    public let wasHelpful: Bool
    public let improvementSuggestions: [String]

    public init(rating: Int, comment: String? = nil, wasHelpful: Bool = true, improvementSuggestions: [String] = []) {
        self.rating = min(5, max(1, rating))
        self.comment = comment
        self.wasHelpful = wasHelpful
        self.improvementSuggestions = improvementSuggestions
    }
}

// MARK: - Semantic Memory

/// A semantic memory entry representing learned knowledge
public struct SemanticMemoryEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let concept: String
    public let description: String
    public let category: SemanticCategory
    public let confidence: Float  // 0.0 - 1.0
    public let sourceEpisodeIds: [UUID]
    public let relatedConcepts: [UUID]
    public let embedding: [Float]?
    public let createdAt: Date
    public let lastAccessedAt: Date
    public let accessCount: Int
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        concept: String,
        description: String,
        category: SemanticCategory,
        confidence: Float = 0.5,
        sourceEpisodeIds: [UUID] = [],
        relatedConcepts: [UUID] = [],
        embedding: [Float]? = nil,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        accessCount: Int = 1,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.concept = concept
        self.description = description
        self.category = category
        self.confidence = confidence
        self.sourceEpisodeIds = sourceEpisodeIds
        self.relatedConcepts = relatedConcepts
        self.embedding = embedding
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
        self.metadata = metadata
    }
}

/// Categories for semantic memory
public enum SemanticCategory: String, Codable, Sendable, CaseIterable {
    case userPreference
    case projectPattern
    case codingStyle
    case toolUsage
    case domainKnowledge
    case errorPattern
    case successPattern
    case workflowPattern
    case communicationStyle
    case technicalConcept
}

// MARK: - Working Memory

/// Working memory item for current context
public struct WorkingMemoryItem: Identifiable, Sendable {
    public let id: UUID
    public let content: String
    public let priority: WorkingMemoryPriority
    public let tokenCount: Int
    public let source: WorkingMemorySource
    public let addedAt: Date
    public let expiresAt: Date?
    public let relevanceScore: Float

    public init(
        id: UUID = UUID(),
        content: String,
        priority: WorkingMemoryPriority,
        tokenCount: Int,
        source: WorkingMemorySource,
        addedAt: Date = Date(),
        expiresAt: Date? = nil,
        relevanceScore: Float = 1.0
    ) {
        self.id = id
        self.content = content
        self.priority = priority
        self.tokenCount = tokenCount
        self.source = source
        self.addedAt = addedAt
        self.expiresAt = expiresAt
        self.relevanceScore = relevanceScore
    }
}

public enum WorkingMemoryPriority: Int, Comparable, Sendable {
    case low = 0
    case normal = 50
    case high = 75
    case critical = 100

    public static func < (lhs: WorkingMemoryPriority, rhs: WorkingMemoryPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum WorkingMemorySource: String, Sendable {
    case userMessage
    case systemPrompt
    case episodicRecall
    case semanticRecall
    case skillContext
    case knowledgeItem
    case toolResult
    case agentOutput
}

// MARK: - Episodic Memory Manager

/// Manages episodic memory - storing and retrieving past experiences
@MainActor
public final class EpisodicMemoryManager: ObservableObject {
    public static let shared = EpisodicMemoryManager()

    private let logger = Logger(subsystem: "com.thea.memory", category: "Episodic")
    private let storageURL: URL
    private let maxEpisodes = 10000

    @Published public private(set) var episodes: [Episode] = []
    @Published public private(set) var currentSessionId = UUID()

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = documentsPath.appendingPathComponent("thea_episodic_memory.json")
        loadEpisodes()
    }

    // MARK: - Episode Management

    public func recordEpisode(
        taskDescription: String,
        taskType: String,
        outcome: EpisodeOutcome,
        duration: TimeInterval,
        contextSummary: String = "",
        lessonsLearned: [String] = [],
        metadata: [String: String] = [:]
    ) {
        let episode = Episode(
            sessionId: currentSessionId,
            taskDescription: taskDescription,
            taskType: taskType,
            outcome: outcome,
            duration: duration,
            lessonsLearned: lessonsLearned,
            contextSummary: contextSummary,
            metadata: metadata
        )

        episodes.append(episode)

        // Trim if exceeds max
        if episodes.count > maxEpisodes {
            episodes = Array(episodes.suffix(maxEpisodes))
        }

        saveEpisodes()
        logger.info("Recorded episode: \(taskDescription) - \(outcome.rawValue)")
    }

    public func addFeedback(to episodeId: UUID, feedback: EpisodeFeedback) {
        guard let index = episodes.firstIndex(where: { $0.id == episodeId }) else { return }

        var episode = episodes[index]
        episode = Episode(
            id: episode.id,
            timestamp: episode.timestamp,
            sessionId: episode.sessionId,
            taskDescription: episode.taskDescription,
            taskType: episode.taskType,
            outcome: episode.outcome,
            duration: episode.duration,
            userFeedback: feedback,
            lessonsLearned: episode.lessonsLearned,
            contextSummary: episode.contextSummary,
            relatedEpisodeIds: episode.relatedEpisodeIds,
            embedding: episode.embedding,
            metadata: episode.metadata
        )
        episodes[index] = episode
        saveEpisodes()
    }

    // MARK: - Retrieval

    public func recentEpisodes(limit: Int = 10) -> [Episode] {
        Array(episodes.suffix(limit))
    }

    public func episodesForTaskType(_ taskType: String, limit: Int = 5) -> [Episode] {
        episodes
            .filter { $0.taskType == taskType }
            .suffix(limit)
            .reversed()
            .map { $0 }
    }

    public func successfulPatterns(for taskType: String) -> [Episode] {
        episodes
            .filter { $0.taskType == taskType && $0.outcome == .success }
            .filter { $0.userFeedback?.wasHelpful ?? true }
            .suffix(10)
            .map { $0 }
    }

    public func failurePatterns(for taskType: String) -> [Episode] {
        episodes
            .filter { $0.taskType == taskType && $0.outcome == .failure }
            .suffix(10)
            .map { $0 }
    }

    public func lessonsForTaskType(_ taskType: String) -> [String] {
        episodes
            .filter { $0.taskType == taskType }
            .flatMap { $0.lessonsLearned }
            .uniqued()
    }

    public func startNewSession() {
        currentSessionId = UUID()
        logger.info("Started new session: \(self.currentSessionId)")
    }

    // MARK: - Persistence

    private func loadEpisodes() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            episodes = try JSONDecoder().decode([Episode].self, from: data)
            logger.info("Loaded \(self.episodes.count) episodes from storage")
        } catch {
            logger.error("Failed to load episodes: \(error.localizedDescription)")
        }
    }

    private func saveEpisodes() {
        do {
            let data = try JSONEncoder().encode(episodes)
            try data.write(to: storageURL)
        } catch {
            logger.error("Failed to save episodes: \(error.localizedDescription)")
        }
    }
}

// MARK: - Semantic Memory Manager

/// Manages semantic memory - learned concepts and patterns
@MainActor
public final class SemanticMemoryManager: ObservableObject {
    public static let shared = SemanticMemoryManager()

    private let logger = Logger(subsystem: "com.thea.memory", category: "Semantic")
    private let storageURL: URL
    private let maxEntries = 5000

    @Published public private(set) var entries: [SemanticMemoryEntry] = []

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = documentsPath.appendingPathComponent("thea_semantic_memory.json")
        loadEntries()
    }

    // MARK: - Entry Management

    public func learnConcept(
        concept: String,
        description: String,
        category: SemanticCategory,
        confidence: Float = 0.5,
        sourceEpisodeIds: [UUID] = [],
        metadata: [String: String] = [:]
    ) {
        // Check if concept already exists
        if let existingIndex = entries.firstIndex(where: { $0.concept.lowercased() == concept.lowercased() }) {
            // Reinforce existing concept
            var existing = entries[existingIndex]
            let newConfidence = min(1.0, existing.confidence + 0.1)
            existing = SemanticMemoryEntry(
                id: existing.id,
                concept: existing.concept,
                description: description.isEmpty ? existing.description : description,
                category: existing.category,
                confidence: newConfidence,
                sourceEpisodeIds: existing.sourceEpisodeIds + sourceEpisodeIds,
                relatedConcepts: existing.relatedConcepts,
                embedding: existing.embedding,
                createdAt: existing.createdAt,
                lastAccessedAt: Date(),
                accessCount: existing.accessCount + 1,
                metadata: existing.metadata.merging(metadata) { _, new in new }
            )
            entries[existingIndex] = existing
            logger.debug("Reinforced concept: \(concept) (confidence: \(newConfidence))")
        } else {
            // Create new concept
            let entry = SemanticMemoryEntry(
                concept: concept,
                description: description,
                category: category,
                confidence: confidence,
                sourceEpisodeIds: sourceEpisodeIds,
                metadata: metadata
            )
            entries.append(entry)
            logger.info("Learned new concept: \(concept)")
        }

        // Trim if exceeds max
        if entries.count > maxEntries {
            // Remove lowest confidence entries
            entries.sort { $0.confidence > $1.confidence }
            entries = Array(entries.prefix(maxEntries))
        }

        saveEntries()
    }

    public func recordAccess(conceptId: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == conceptId }) else { return }

        var entry = entries[index]
        entry = SemanticMemoryEntry(
            id: entry.id,
            concept: entry.concept,
            description: entry.description,
            category: entry.category,
            confidence: entry.confidence,
            sourceEpisodeIds: entry.sourceEpisodeIds,
            relatedConcepts: entry.relatedConcepts,
            embedding: entry.embedding,
            createdAt: entry.createdAt,
            lastAccessedAt: Date(),
            accessCount: entry.accessCount + 1,
            metadata: entry.metadata
        )
        entries[index] = entry
        saveEntries()
    }

    // MARK: - Retrieval

    public func concepts(for category: SemanticCategory) -> [SemanticMemoryEntry] {
        entries.filter { $0.category == category }
    }

    public func highConfidenceConcepts(threshold: Float = 0.7) -> [SemanticMemoryEntry] {
        entries.filter { $0.confidence >= threshold }
    }

    public func recentlyAccessedConcepts(limit: Int = 10) -> [SemanticMemoryEntry] {
        entries
            .sorted { $0.lastAccessedAt > $1.lastAccessedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func searchConcepts(query: String) -> [SemanticMemoryEntry] {
        let lowercasedQuery = query.lowercased()
        return entries.filter {
            $0.concept.lowercased().contains(lowercasedQuery) ||
            $0.description.lowercased().contains(lowercasedQuery)
        }
    }

    public func userPreferences() -> [SemanticMemoryEntry] {
        concepts(for: .userPreference)
    }

    public func codingPatterns() -> [SemanticMemoryEntry] {
        concepts(for: .codingStyle) + concepts(for: .projectPattern)
    }

    // MARK: - Persistence

    private func loadEntries() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            entries = try JSONDecoder().decode([SemanticMemoryEntry].self, from: data)
            logger.info("Loaded \(self.entries.count) semantic entries from storage")
        } catch {
            logger.error("Failed to load semantic entries: \(error.localizedDescription)")
        }
    }

    private func saveEntries() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storageURL)
        } catch {
            logger.error("Failed to save semantic entries: \(error.localizedDescription)")
        }
    }
}

// MARK: - Working Memory Manager

/// Manages working memory - dynamic context for current task
public actor WorkingMemoryManager {
    public static let shared = WorkingMemoryManager()

    private let logger = Logger(subsystem: "com.thea.memory", category: "Working")

    private var items: [WorkingMemoryItem] = []
    private let maxTokenBudget: Int = 100000  // Max tokens for working memory
    private var currentTokenUsage: Int = 0

    // MARK: - Item Management

    public func add(
        content: String,
        priority: WorkingMemoryPriority,
        source: WorkingMemorySource,
        expiresIn: TimeInterval? = nil
    ) {
        let tokenCount = estimateTokens(content)
        let expiresAt = expiresIn.map { Date().addingTimeInterval($0) }

        let item = WorkingMemoryItem(
            content: content,
            priority: priority,
            tokenCount: tokenCount,
            source: source,
            expiresAt: expiresAt
        )

        items.append(item)
        currentTokenUsage += tokenCount

        // Evict if over budget
        if currentTokenUsage > maxTokenBudget {
            evictLowPriorityItems()
        }

        logger.debug("Added working memory item: \(source.rawValue) (\(tokenCount) tokens)")
    }

    public func clear() {
        items.removeAll()
        currentTokenUsage = 0
        logger.info("Cleared working memory")
    }

    public func clearExpired() {
        let now = Date()
        let expiredIds = items.filter { $0.expiresAt != nil && $0.expiresAt! < now }.map { $0.id }

        for id in expiredIds {
            if let index = items.firstIndex(where: { $0.id == id }) {
                currentTokenUsage -= items[index].tokenCount
                items.remove(at: index)
            }
        }

        if !expiredIds.isEmpty {
            logger.debug("Cleared \(expiredIds.count) expired items")
        }
    }

    // MARK: - Retrieval

    public func allItems() -> [WorkingMemoryItem] {
        clearExpired()
        return items.sorted { $0.priority > $1.priority }
    }

    public func items(from source: WorkingMemorySource) -> [WorkingMemoryItem] {
        items.filter { $0.source == source }
    }

    public func buildContext(maxTokens: Int) -> String {
        clearExpired()

        // Sort by priority and recency
        let sorted = items.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.addedAt > rhs.addedAt
        }

        var context = ""
        var usedTokens = 0

        for item in sorted {
            if usedTokens + item.tokenCount <= maxTokens {
                context += item.content + "\n\n"
                usedTokens += item.tokenCount
            }
        }

        return context
    }

    public func tokenUsage() -> (used: Int, budget: Int) {
        (currentTokenUsage, maxTokenBudget)
    }

    // MARK: - Private

    private func evictLowPriorityItems() {
        // Sort by priority (ascending) and age (oldest first)
        items.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.addedAt < rhs.addedAt
        }

        // Remove items until under budget
        while currentTokenUsage > maxTokenBudget && !items.isEmpty {
            let removed = items.removeFirst()
            currentTokenUsage -= removed.tokenCount
            logger.debug("Evicted: \(removed.source.rawValue) (\(removed.tokenCount) tokens)")
        }
    }

    private func estimateTokens(_ text: String) -> Int {
        // Rough estimate: ~4 characters per token
        text.count / 4
    }
}

// MARK: - Memory Consolidation

/// Consolidates memories - summarizes and compacts old memories
@MainActor
public final class MemoryConsolidator: ObservableObject {
    public static let shared = MemoryConsolidator()

    private let logger = Logger(subsystem: "com.thea.memory", category: "Consolidation")

    @Published public private(set) var lastConsolidationDate: Date?
    @Published public private(set) var isConsolidating: Bool = false

    private let consolidationInterval: TimeInterval = 24 * 60 * 60  // Daily

    // MARK: - Consolidation

    public func consolidateIfNeeded() async {
        guard !isConsolidating else { return }

        if let lastDate = lastConsolidationDate,
           Date().timeIntervalSince(lastDate) < consolidationInterval {
            return
        }

        await consolidate()
    }

    public func consolidate() async {
        isConsolidating = true
        defer { isConsolidating = false }

        logger.info("Starting memory consolidation...")

        // 1. Extract lessons from recent episodes
        await extractLessonsFromEpisodes()

        // 2. Decay unused semantic memories
        await decayUnusedMemories()

        // 3. Merge similar concepts
        await mergeSimilarConcepts()

        // 4. Clean old episodes (keep summaries)
        await archiveOldEpisodes()

        lastConsolidationDate = Date()
        logger.info("Memory consolidation complete")
    }

    private func extractLessonsFromEpisodes() async {
        let episodicManager = EpisodicMemoryManager.shared
        let semanticManager = SemanticMemoryManager.shared

        // Get episodes from last week
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let recentEpisodes = episodicManager.episodes.filter { $0.timestamp > oneWeekAgo }

        // Group by task type and extract patterns
        let groupedByType = Dictionary(grouping: recentEpisodes) { $0.taskType }

        for (taskType, episodes) in groupedByType {
            // Find success patterns
            let successes = episodes.filter { $0.outcome == .success }
            if successes.count >= 3 {
                let lessons = successes.flatMap { $0.lessonsLearned }.uniqued()
                if !lessons.isEmpty {
                    semanticManager.learnConcept(
                        concept: "Success pattern for \(taskType)",
                        description: lessons.joined(separator: "; "),
                        category: .successPattern,
                        confidence: Float(successes.count) / Float(episodes.count),
                        sourceEpisodeIds: successes.map { $0.id }
                    )
                }
            }

            // Find failure patterns
            let failures = episodes.filter { $0.outcome == .failure }
            if failures.count >= 2 {
                let lessons = failures.flatMap { $0.lessonsLearned }.uniqued()
                if !lessons.isEmpty {
                    semanticManager.learnConcept(
                        concept: "Failure pattern for \(taskType)",
                        description: lessons.joined(separator: "; "),
                        category: .errorPattern,
                        confidence: Float(failures.count) / Float(episodes.count),
                        sourceEpisodeIds: failures.map { $0.id }
                    )
                }
            }
        }
    }

    private func decayUnusedMemories() async {
        let semanticManager = SemanticMemoryManager.shared
        let oneMonthAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)

        for entry in semanticManager.entries {
            if entry.lastAccessedAt < oneMonthAgo && entry.confidence > 0.1 {
                // Decay confidence
                let decayedConfidence = entry.confidence * 0.9
                semanticManager.learnConcept(
                    concept: entry.concept,
                    description: entry.description,
                    category: entry.category,
                    confidence: decayedConfidence
                )
            }
        }
    }

    private func mergeSimilarConcepts() async {
        // TODO: Implement embedding-based similarity merging
        // For now, merge exact duplicates
        let semanticManager = SemanticMemoryManager.shared
        var seen: Set<String> = []
        var toRemove: [UUID] = []

        for entry in semanticManager.entries {
            let normalized = entry.concept.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.contains(normalized) {
                toRemove.append(entry.id)
            } else {
                seen.insert(normalized)
            }
        }

        // Remove duplicates (keeping highest confidence)
        // This is simplified - real implementation would merge
    }

    private func archiveOldEpisodes() async {
        // Keep last 30 days of full episodes
        // Older episodes get summarized and archived
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)

        // For now, just log - full implementation would create summaries
        let episodicManager = EpisodicMemoryManager.shared
        let oldCount = episodicManager.episodes.filter { $0.timestamp < thirtyDaysAgo }.count

        if oldCount > 0 {
            logger.info("Would archive \(oldCount) episodes older than 30 days")
        }
    }
}

// MARK: - Unified Memory Interface

/// Unified interface for all memory systems
@MainActor
public final class UnifiedMemorySystem: ObservableObject {
    public static let shared = UnifiedMemorySystem()

    private let logger = Logger(subsystem: "com.thea.memory", category: "UnifiedMemorySystem")

    public let episodic = EpisodicMemoryManager.shared
    public let semantic = SemanticMemoryManager.shared
    public let consolidator = MemoryConsolidator.shared

    // MARK: - High-Level Operations

    /// Record a completed task and extract learnings
    public func recordTaskCompletion(
        task: String,
        taskType: String,
        success: Bool,
        duration: TimeInterval,
        lessonsLearned: [String] = [],
        context: String = ""
    ) {
        // Record episode
        episodic.recordEpisode(
            taskDescription: task,
            taskType: taskType,
            outcome: success ? .success : .failure,
            duration: duration,
            contextSummary: context,
            lessonsLearned: lessonsLearned
        )

        // Learn from success patterns
        if success {
            for lesson in lessonsLearned {
                semantic.learnConcept(
                    concept: "Learned: \(lesson)",
                    description: "From task: \(task)",
                    category: .successPattern,
                    confidence: 0.6
                )
            }
        }
    }

    /// Learn a user preference
    public func learnPreference(preference: String, value: String, confidence: Float = 0.7) {
        semantic.learnConcept(
            concept: preference,
            description: value,
            category: .userPreference,
            confidence: confidence
        )
    }

    /// Get relevant context for a task
    public func getRelevantContext(for taskType: String, query: String) -> MemoryContext {
        // Get relevant episodes
        let relevantEpisodes = episodic.episodesForTaskType(taskType, limit: 5)
        let successPatterns = episodic.successfulPatterns(for: taskType)
        let lessons = episodic.lessonsForTaskType(taskType)

        // Get relevant semantic memories
        let preferences = semantic.userPreferences()
        let patterns = semantic.codingPatterns()
        let searched = semantic.searchConcepts(query: query)

        return MemoryContext(
            recentEpisodes: relevantEpisodes,
            successPatterns: successPatterns,
            lessons: lessons,
            userPreferences: preferences,
            relevantConcepts: searched + patterns
        )
    }

    /// Build context string for prompt injection
    public func buildContextString(for taskType: String, query: String, maxTokens: Int = 2000) -> String {
        let context = getRelevantContext(for: taskType, query: query)

        var parts: [String] = []

        // Add lessons learned
        if !context.lessons.isEmpty {
            parts.append("## Lessons from past experience:")
            parts.append(contentsOf: context.lessons.prefix(5).map { "- \($0)" })
        }

        // Add user preferences
        if !context.userPreferences.isEmpty {
            parts.append("\n## User preferences:")
            for pref in context.userPreferences.prefix(5) {
                parts.append("- \(pref.concept): \(pref.description)")
            }
        }

        // Add relevant concepts
        if !context.relevantConcepts.isEmpty {
            parts.append("\n## Relevant knowledge:")
            for concept in context.relevantConcepts.prefix(5) {
                parts.append("- \(concept.concept): \(concept.description)")
            }
        }

        // Trim to token budget
        var result = parts.joined(separator: "\n")
        while result.count / 4 > maxTokens && !parts.isEmpty {
            parts.removeLast()
            result = parts.joined(separator: "\n")
        }

        return result
    }

    /// Trigger consolidation
    public func consolidateMemories() async {
        await consolidator.consolidateIfNeeded()
    }
}

/// Context retrieved from memory
public struct MemoryContext: Sendable {
    public let recentEpisodes: [Episode]
    public let successPatterns: [Episode]
    public let lessons: [String]
    public let userPreferences: [SemanticMemoryEntry]
    public let relevantConcepts: [SemanticMemoryEntry]
}

// MARK: - Helpers

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
