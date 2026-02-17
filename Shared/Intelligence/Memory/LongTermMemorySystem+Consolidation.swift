// LongTermMemorySystem+Consolidation.swift
// Thea
//
// Working memory, memory consolidation, and unified memory system.

import Foundation
import os.log

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
        let semanticManager = SemanticMemoryManager.shared
        let entries = semanticManager.entries
        var merged: Set<UUID> = []

        // Group entries by normalized concept for exact-match merging
        var groupsByNormalized: [String: [SemanticMemoryEntry]] = [:]
        for entry in entries {
            let normalized = entry.concept.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            groupsByNormalized[normalized, default: []].append(entry)
        }

        // Merge exact duplicates: keep highest confidence, remove rest
        for (_, group) in groupsByNormalized where group.count > 1 {
            let sorted = group.sorted { $0.confidence > $1.confidence }
            for entry in sorted.dropFirst() {
                merged.insert(entry.id)
            }
        }

        // Fuzzy similarity merging: merge entries with high string similarity
        let allNormalized = Array(groupsByNormalized.keys)
        for i in 0..<allNormalized.count {
            for j in (i + 1)..<allNormalized.count {
                let a = allNormalized[i]
                let b = allNormalized[j]
                if stringSimilarity(a, b) > 0.85 {
                    // Merge the lower-confidence group into the higher
                    let groupA = groupsByNormalized[a] ?? []
                    let groupB = groupsByNormalized[b] ?? []
                    let maxConfA = groupA.max { $0.confidence < $1.confidence }?.confidence ?? 0
                    let maxConfB = groupB.max { $0.confidence < $1.confidence }?.confidence ?? 0
                    let toRemove = maxConfA >= maxConfB ? groupB : groupA
                    for entry in toRemove {
                        merged.insert(entry.id)
                    }
                }
            }
        }

        if !merged.isEmpty {
            for id in merged {
                semanticManager.removeConcept(id: id)
            }
            logger.info("Merged \(merged.count) similar/duplicate concepts")
        }
    }

    /// Bigram-based string similarity (Sørensen-Dice coefficient)
    private func stringSimilarity(_ a: String, _ b: String) -> Double {
        guard a.count > 1, b.count > 1 else { return a == b ? 1.0 : 0.0 }
        let bigramsA = Set(zip(a, a.dropFirst()).map { "\($0)\($1)" })
        let bigramsB = Set(zip(b, b.dropFirst()).map { "\($0)\($1)" })
        let intersection = bigramsA.intersection(bigramsB).count
        return 2.0 * Double(intersection) / Double(bigramsA.count + bigramsB.count)
    }

    private func archiveOldEpisodes() async {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let episodicManager = EpisodicMemoryManager.shared
        let oldEpisodes = episodicManager.episodes.filter { $0.timestamp < thirtyDaysAgo }

        guard !oldEpisodes.isEmpty else { return }

        // Summarize old episodes into semantic memory entries
        let successCount = oldEpisodes.filter { $0.outcome == .success }.count
        let failCount = oldEpisodes.filter { $0.outcome == .failure }.count
        let taskTypes = Set(oldEpisodes.map(\.taskType))

        let summary = "Archived \(oldEpisodes.count) episodes (\(successCount) success, \(failCount) failure) across task types: \(taskTypes.joined(separator: ", "))"

        let semanticManager = SemanticMemoryManager.shared
        semanticManager.learnConcept(
            concept: "Episode archive: \(DateFormatter.localizedString(from: thirtyDaysAgo, dateStyle: .short, timeStyle: .none))",
            description: summary,
            category: .successPattern,
            confidence: 0.8
        )

        // Extract lessons from archived episodes
        for episode in oldEpisodes {
            for lesson in episode.lessonsLearned {
                semanticManager.learnConcept(
                    concept: "Archived lesson: \(lesson)",
                    description: "From \(episode.taskType) task on \(DateFormatter.localizedString(from: episode.timestamp, dateStyle: .short, timeStyle: .none))",
                    category: .successPattern,
                    confidence: 0.5
                )
            }
        }

        // Remove archived episodes
        for episode in oldEpisodes {
            episodicManager.removeEpisode(id: episode.id)
        }

        logger.info("Archived \(oldEpisodes.count) episodes older than 30 days, extracted lessons into semantic memory")
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

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
