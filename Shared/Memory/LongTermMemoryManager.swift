//
//  LongTermMemoryManager.swift
//  Thea
//
//  Persistent fact storage with time-based decay and reinforcement.
//  Builds on MemoryService with spaced repetition-inspired algorithms.
//
//  FEATURES:
//  - Store facts with initial strength
//  - Time-based decay (forgetting curve)
//  - Reinforcement on recall (strengthening)
//  - Automatic pruning of weak memories
//  - Category-based organization
//
//  CREATED: February 6, 2026
//

import Foundation
import OSLog

// MARK: - Long-Term Memory Manager

/// Manages persistent facts with time-based decay and reinforcement,
/// inspired by spaced repetition algorithms. Facts weaken over time
/// unless reinforced by recall, and are automatically pruned when
/// their strength drops below a configurable threshold.
public actor LongTermMemoryManager {
    /// Shared singleton instance.
    public static let shared = LongTermMemoryManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "LongTermMemory")

    // MARK: - Configuration

    /// Parameters controlling memory decay, reinforcement, and pruning behavior.
    public struct Configuration: Sendable {
        /// Base decay rate per day (0-1). Higher values cause faster forgetting.
        public var baseDecayRate: Double = 0.1

        /// Minimum strength before a memory is eligible for pruning.
        public var minimumStrength: Double = 0.1

        /// Strength boost factor applied when a memory is recalled.
        public var reinforcementFactor: Double = 0.2

        /// Maximum single-recall reinforcement boost.
        public var maxReinforcement: Double = 0.5

        /// Interval between automatic decay passes, in seconds.
        public var decayInterval: TimeInterval = 3600  // 1 hour

        /// Maximum number of memories to store before eviction.
        public var maxMemories: Int = 5000

        /// Whether to automatically prune memories below minimum strength.
        public var autoPruneEnabled: Bool = true

        /// Creates a default configuration.
        public init() {}
    }

    /// Current decay and pruning configuration.
    public var configuration = Configuration()

    // MARK: - State

    /// All stored long-term memories, keyed by ID.
    private var memories: [UUID: LongTermMemory] = [:]

    /// Index mapping category names to memory IDs for fast category lookups.
    private var categoryIndex: [String: Set<UUID>] = [:]

    /// Index mapping lowercased keywords to memory IDs for fast search.
    private var keywordIndex: [String: Set<UUID>] = [:]

    /// Background task running the periodic decay loop.
    private var decayTask: Task<Void, Never>?

    /// When the last decay pass was run.
    private var lastDecayTime: Date?

    // MARK: - Persistence

    /// UserDefaults key for persisted memory data.
    private let storageKey = "LongTermMemoryManager.memories"

    // MARK: - Initialization

    private init() {
        Task {
            await self.loadFromStorage()
            await self.startDecayLoop()
        }
    }

    // MARK: - Public API

    /// Stores a fact as a long-term memory with initial strength.
    /// - Parameters:
    ///   - fact: The content of the fact to store.
    ///   - category: Category for organization and retrieval.
    ///   - initialStrength: Starting strength (clamped to 0.0-1.0, default 0.8).
    ///   - keywords: Keywords for search indexing.
    ///   - source: Where this fact originated from.
    /// - Returns: The UUID of the newly created memory.
    @discardableResult
    public func storeFact(
        _ fact: String,
        category: String,
        initialStrength: Double = 0.8,
        keywords: [String] = [],
        source: LongTermMemorySource = .conversation
    ) async -> UUID {
        let memory = LongTermMemory(
            content: fact,
            category: category,
            strength: min(1.0, max(0.0, initialStrength)),
            keywords: keywords,
            source: source
        )

        memories[memory.id] = memory

        // Update category index
        categoryIndex[category, default: []].insert(memory.id)

        // Update keyword index
        for keyword in keywords {
            keywordIndex[keyword.lowercased(), default: []].insert(memory.id)
        }

        // Enforce memory limit
        await enforceMemoryLimit()

        // Persist
        await saveToStorage()

        logger.info("Stored long-term memory: \(memory.id) in category '\(category)'")

        return memory.id
    }

    /// Reinforces a memory when it is recalled or used, boosting its strength.
    /// The boost is proportional to how much room there is to grow (diminishing returns near 1.0).
    /// - Parameter factId: ID of the memory to reinforce.
    public func reinforceFact(_ factId: UUID) async {
        guard var memory = memories[factId] else {
            logger.warning("Attempted to reinforce non-existent memory: \(factId)")
            return
        }

        let boost = min(configuration.maxReinforcement,
                        configuration.reinforcementFactor * (1.0 - memory.strength))
        memory.strength = min(1.0, memory.strength + boost)
        memory.lastReinforcedAt = Date()
        memory.reinforcementCount += 1

        memories[factId] = memory

        logger.debug("Reinforced memory \(factId): new strength \(String(format: "%.2f", memory.strength))")

        await saveToStorage()
    }

    /// Retrieves active memories above a minimum strength threshold.
    /// - Parameters:
    ///   - minStrength: Minimum strength to include (default 0.3).
    ///   - category: Optional category filter.
    ///   - limit: Maximum number of memories to return.
    /// - Returns: Memories sorted by strength (strongest first).
    public func getActiveMemories(
        minStrength: Double = 0.3,
        category: String? = nil,
        limit: Int? = nil
    ) -> [LongTermMemory] {
        var result = memories.values.filter { $0.strength >= minStrength }

        if let category = category {
            result = result.filter { $0.category == category }
        }

        // Sort by strength (strongest first)
        result.sort { $0.strength > $1.strength }

        if let limit = limit {
            return Array(result.prefix(limit))
        }

        return result
    }

    /// Searches memories by keyword, matching against both the keyword index and content.
    /// - Parameters:
    ///   - keywords: Keywords to search for.
    ///   - minStrength: Minimum strength to include (default 0.2).
    ///   - limit: Maximum results to return (default 20).
    /// - Returns: Matching memories sorted by strength (strongest first).
    public func search(
        keywords: [String],
        minStrength: Double = 0.2,
        limit: Int = 20
    ) -> [LongTermMemory] {
        var matchingIds: Set<UUID> = []

        for keyword in keywords {
            if let ids = keywordIndex[keyword.lowercased()] {
                matchingIds.formUnion(ids)
            }
        }

        // Also check content for keyword matches
        for (id, memory) in memories {
            let content = memory.content.lowercased()
            for keyword in keywords {
                if content.contains(keyword.lowercased()) {
                    matchingIds.insert(id)
                }
            }
        }

        return matchingIds.compactMap { memories[$0] }
            .filter { $0.strength >= minStrength }
            .sorted { $0.strength > $1.strength }
            .prefix(limit)
            .map { $0 }
    }

    /// Retrieves a single memory by ID.
    /// - Parameter id: Memory identifier.
    /// - Returns: The memory if it exists, or nil.
    public func getMemory(_ id: UUID) -> LongTermMemory? {
        memories[id]
    }

    /// Returns all categories with their memory counts and average strengths.
    /// - Returns: Array of tuples sorted by count (most memories first).
    public func getCategories() -> [(category: String, count: Int, avgStrength: Double)] {
        categoryIndex.map { category, ids in
            let categoryMemories = ids.compactMap { memories[$0] }
            let avgStrength = categoryMemories.isEmpty ? 0 :
                categoryMemories.map(\.strength).reduce(0, +) / Double(categoryMemories.count)
            return (category, ids.count, avgStrength)
        }
        .sorted { $0.count > $1.count }
    }

    /// Manually reduces a memory's strength by a specified amount.
    /// If the memory drops below minimum strength and auto-prune is enabled, it is removed.
    /// - Parameters:
    ///   - id: Memory identifier.
    ///   - amount: Amount to subtract from strength.
    public func decayMemory(_ id: UUID, by amount: Double) async {
        guard var memory = memories[id] else { return }

        memory.strength = max(0.0, memory.strength - amount)
        memories[id] = memory

        if memory.strength < configuration.minimumStrength && configuration.autoPruneEnabled {
            await pruneMemory(id)
        }

        await saveToStorage()
    }

    /// Permanently deletes a memory.
    /// - Parameter id: Memory identifier to delete.
    public func deleteMemory(_ id: UUID) async {
        await pruneMemory(id)
        await saveToStorage()
    }

    /// Runs the decay algorithm on all memories, applying time-based strength reduction.
    /// Memories that fall below the minimum strength threshold are pruned if auto-prune is enabled.
    public func decayUnusedFacts() async {
        let now = Date()
        var prunedCount = 0

        for (id, var memory) in memories {
            // Calculate decay based on time since last reinforcement
            let lastActivity = memory.lastReinforcedAt ?? memory.createdAt
            let daysSinceActivity = now.timeIntervalSince(lastActivity) / 86400

            // Apply exponential decay
            let decayAmount = configuration.baseDecayRate * daysSinceActivity * (1.0 - memory.strength)
            memory.strength = max(0.0, memory.strength - decayAmount)

            memories[id] = memory

            // Prune if below threshold
            if memory.strength < configuration.minimumStrength && configuration.autoPruneEnabled {
                await pruneMemory(id)
                prunedCount += 1
            }
        }

        lastDecayTime = now
        await saveToStorage()

        logger.info("Decay complete. Pruned \(prunedCount) memories below threshold")
    }

    /// Returns aggregate statistics about the long-term memory store.
    /// - Returns: Statistics including counts, average strength, and last decay time.
    public func getStatistics() -> LongTermMemoryStats {
        let allMemories = Array(memories.values)
        let strengths = allMemories.map(\.strength)

        return LongTermMemoryStats(
            totalMemories: allMemories.count,
            categories: categoryIndex.count,
            averageStrength: strengths.isEmpty ? 0 : strengths.reduce(0, +) / Double(strengths.count),
            strongMemories: allMemories.filter { $0.strength >= 0.7 }.count,
            weakMemories: allMemories.filter { $0.strength < 0.3 }.count,
            lastDecayTime: lastDecayTime
        )
    }

    // MARK: - Private Implementation

    /// Starts the background periodic decay loop.
    private func startDecayLoop() {
        decayTask?.cancel()
        decayTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.decayUnusedFacts()

                do {
                    try await Task.sleep(for: .seconds(self?.configuration.decayInterval ?? 3600))
                } catch {
                    break
                }
            }
        }
    }

    /// Removes a memory from all indexes and the main store.
    /// - Parameter id: Memory identifier to prune.
    private func pruneMemory(_ id: UUID) async {
        guard let memory = memories[id] else { return }

        // Remove from category index
        categoryIndex[memory.category]?.remove(id)
        if categoryIndex[memory.category]?.isEmpty == true {
            categoryIndex.removeValue(forKey: memory.category)
        }

        // Remove from keyword index
        for keyword in memory.keywords {
            keywordIndex[keyword.lowercased()]?.remove(id)
            if keywordIndex[keyword.lowercased()]?.isEmpty == true {
                keywordIndex.removeValue(forKey: keyword.lowercased())
            }
        }

        // Remove from main storage
        memories.removeValue(forKey: id)

        logger.debug("Pruned memory: \(id)")
    }

    /// Evicts the weakest memories when the store exceeds the maximum capacity.
    private func enforceMemoryLimit() async {
        guard memories.count > configuration.maxMemories else { return }

        // Remove weakest memories first
        let sorted = memories.values.sorted { $0.strength < $1.strength }
        let toRemove = sorted.prefix(memories.count - configuration.maxMemories)

        for memory in toRemove {
            await pruneMemory(memory.id)
        }

        logger.info("Enforced memory limit: removed \(toRemove.count) weakest memories")
    }

    // MARK: - Persistence

    /// Loads memories from UserDefaults.
    private func loadFromStorage() async {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(LongTermMemoryStorage.self, from: data) else {
            logger.debug("No existing long-term memory data found")
            return
        }

        memories = decoded.memories
        categoryIndex = decoded.categoryIndex
        keywordIndex = decoded.keywordIndex
        lastDecayTime = decoded.lastDecayTime

        logger.info("Loaded \(self.memories.count) long-term memories from storage")
    }

    /// Persists current memories to UserDefaults.
    private func saveToStorage() async {
        let storage = LongTermMemoryStorage(
            memories: memories,
            categoryIndex: categoryIndex,
            keywordIndex: keywordIndex,
            lastDecayTime: lastDecayTime
        )

        if let data = try? JSONEncoder().encode(storage) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Supporting Types

/// A single long-term memory with content, strength, and metadata.
public struct LongTermMemory: Identifiable, Codable, Sendable {
    /// Unique memory identifier.
    public let id: UUID
    /// Textual content of the stored fact.
    public let content: String
    /// Category for organization (e.g. "user_preferences", "project_facts").
    public let category: String
    /// Current strength (0.0 = forgotten, 1.0 = maximally retained).
    public var strength: Double
    /// Keywords for search indexing.
    public let keywords: [String]
    /// Where this memory originated from.
    public let source: LongTermMemorySource
    /// When this memory was first created.
    public let createdAt: Date
    /// When this memory was last reinforced by recall.
    public var lastReinforcedAt: Date?
    /// How many times this memory has been reinforced.
    public var reinforcementCount: Int

    /// Creates a long-term memory.
    /// - Parameters:
    ///   - id: Memory identifier.
    ///   - content: Fact content.
    ///   - category: Organization category.
    ///   - strength: Initial strength (0.0-1.0).
    ///   - keywords: Search keywords.
    ///   - source: Memory origin.
    ///   - createdAt: Creation time.
    ///   - lastReinforcedAt: Last reinforcement time.
    ///   - reinforcementCount: Reinforcement count.
    public init(
        id: UUID = UUID(),
        content: String,
        category: String,
        strength: Double = 0.8,
        keywords: [String] = [],
        source: LongTermMemorySource = .conversation,
        createdAt: Date = Date(),
        lastReinforcedAt: Date? = nil,
        reinforcementCount: Int = 0
    ) {
        self.id = id
        self.content = content
        self.category = category
        self.strength = strength
        self.keywords = keywords
        self.source = source
        self.createdAt = createdAt
        self.lastReinforcedAt = lastReinforcedAt
        self.reinforcementCount = reinforcementCount
    }

    /// Whether this memory is considered strong (strength >= 0.7).
    public var isStrong: Bool {
        strength >= 0.7
    }

    /// Whether this memory is at risk of being pruned (strength < 0.3).
    public var isWeak: Bool {
        strength < 0.3
    }

    /// Number of days since last activity (reinforcement or creation).
    public var daysSinceActivity: Double {
        let lastActivity = lastReinforcedAt ?? createdAt
        return Date().timeIntervalSince(lastActivity) / 86400
    }
}

/// Origin of a long-term memory.
public enum LongTermMemorySource: String, Codable, Sendable {
    /// Extracted from an AI conversation.
    case conversation
    /// Explicitly provided by the user.
    case userInput
    /// Inferred from behavioral context.
    case inference
    /// Imported from an external source.
    case external
    /// Generated by a system process.
    case system
}

/// Aggregate statistics about the long-term memory store.
public struct LongTermMemoryStats: Sendable {
    /// Total number of stored memories.
    public let totalMemories: Int
    /// Number of distinct categories.
    public let categories: Int
    /// Mean strength across all memories.
    public let averageStrength: Double
    /// Number of memories with strength >= 0.7.
    public let strongMemories: Int
    /// Number of memories with strength < 0.3.
    public let weakMemories: Int
    /// When the last decay pass was run.
    public let lastDecayTime: Date?

    /// Overall health score combining strong ratio and average strength.
    public var healthScore: Double {
        guard totalMemories > 0 else { return 0 }
        let strongRatio = Double(strongMemories) / Double(totalMemories)
        let weakRatio = Double(weakMemories) / Double(totalMemories)
        return (strongRatio * 1.0) + ((1.0 - weakRatio) * averageStrength)
    }
}

/// Internal persistence structure for serializing the entire memory store.
private struct LongTermMemoryStorage: Codable {
    /// All memories keyed by ID.
    let memories: [UUID: LongTermMemory]
    /// Category-to-IDs index.
    let categoryIndex: [String: Set<UUID>]
    /// Keyword-to-IDs index.
    let keywordIndex: [String: Set<UUID>]
    /// Last decay pass timestamp.
    let lastDecayTime: Date?
}

// MARK: - Integration with MemoryManager

extension LongTermMemoryManager {
    /// Imports high-importance semantic memories from MemoryManager into long-term storage.
    /// Up to 100 memories are imported with an initial strength of 0.7.
    public func importFromMemoryManager() async {
        let semanticMemories = await MemoryManager.shared.getMemoriesByImportance(type: .semantic, limit: 100)

        for record in semanticMemories {
            await storeFact(
                "\(record.key): \(record.value)",
                category: "imported",
                initialStrength: 0.7,
                keywords: [],
                source: .system
            )
        }

        logger.info("Imported \(semanticMemories.count) memories from MemoryManager")
    }

    /// Exports strong memories (strength >= 0.7) to MemoryManager's semantic store.
    public func exportToMemoryManager() async {
        let strongMemories = getActiveMemories(minStrength: 0.7)

        for memory in strongMemories {
            await MemoryManager.shared.storeSemanticMemory(
                category: .contextAssociation,
                key: memory.category,
                value: memory.content,
                confidence: memory.strength,
                source: .system
            )
        }

        logger.info("Exported \(strongMemories.count) strong memories to MemoryManager")
    }
}
