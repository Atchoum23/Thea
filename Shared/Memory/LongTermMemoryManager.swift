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

/// Manages persistent facts with time-based decay and reinforcement
public actor LongTermMemoryManager {
    public static let shared = LongTermMemoryManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "LongTermMemory")

    // MARK: - Configuration

    /// Memory decay configuration
    public struct Configuration: Sendable {
        /// Base decay rate per day (0-1, higher = faster decay)
        public var baseDecayRate: Double = 0.1

        /// Minimum strength before memory is considered for pruning
        public var minimumStrength: Double = 0.1

        /// Reinforcement factor when memory is recalled
        public var reinforcementFactor: Double = 0.2

        /// Maximum reinforcement boost
        public var maxReinforcement: Double = 0.5

        /// How often to run decay (seconds)
        public var decayInterval: TimeInterval = 3600  // 1 hour

        /// Maximum number of memories to store
        public var maxMemories: Int = 5000

        /// Auto-prune memories below minimum strength
        public var autoPruneEnabled: Bool = true

        public init() {}
    }

    public var configuration = Configuration()

    // MARK: - State

    /// All stored long-term memories
    private var memories: [UUID: LongTermMemory] = [:]

    /// Index by category for faster lookups
    private var categoryIndex: [String: Set<UUID>] = [:]

    /// Index by keyword for faster search
    private var keywordIndex: [String: Set<UUID>] = [:]

    /// Decay task
    private var decayTask: Task<Void, Never>?

    /// Last decay run time
    private var lastDecayTime: Date?

    // MARK: - Persistence

    private let storageKey = "LongTermMemoryManager.memories"

    // MARK: - Initialization

    private init() {
        Task {
            await self.loadFromStorage()
            await self.startDecayLoop()
        }
    }

    // MARK: - Public API

    /// Store a fact with initial strength
    /// - Parameters:
    ///   - fact: The content of the fact
    ///   - category: Category for organization
    ///   - initialStrength: Starting strength (0-1, default 0.8)
    ///   - keywords: Keywords for search indexing
    ///   - source: Where this fact came from
    /// - Returns: The created memory ID
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

    /// Reinforce a memory (called when it's recalled/used)
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

    /// Get active memories above minimum strength threshold
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

    /// Search memories by keyword
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

    /// Get memory by ID
    public func getMemory(_ id: UUID) -> LongTermMemory? {
        memories[id]
    }

    /// Get all categories with memory counts
    public func getCategories() -> [(category: String, count: Int, avgStrength: Double)] {
        categoryIndex.map { category, ids in
            let categoryMemories = ids.compactMap { memories[$0] }
            let avgStrength = categoryMemories.isEmpty ? 0 :
                categoryMemories.map(\.strength).reduce(0, +) / Double(categoryMemories.count)
            return (category, ids.count, avgStrength)
        }
        .sorted { $0.count > $1.count }
    }

    /// Manually decay a specific memory
    public func decayMemory(_ id: UUID, by amount: Double) async {
        guard var memory = memories[id] else { return }

        memory.strength = max(0.0, memory.strength - amount)
        memories[id] = memory

        if memory.strength < configuration.minimumStrength && configuration.autoPruneEnabled {
            await pruneMemory(id)
        }

        await saveToStorage()
    }

    /// Delete a memory
    public func deleteMemory(_ id: UUID) async {
        await pruneMemory(id)
        await saveToStorage()
    }

    /// Run decay on all memories
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

    /// Get statistics about long-term memory
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

    /// Start the decay loop
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

    /// Prune a memory from all indexes
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

    /// Enforce maximum memory limit
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

    private func loadFromStorage() async {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            logger.debug("No existing long-term memory data found")
            return
        }

        do {
            let decoded = try JSONDecoder().decode(LongTermMemoryStorage.self, from: data)
            memories = decoded.memories
            categoryIndex = decoded.categoryIndex
            keywordIndex = decoded.keywordIndex
            lastDecayTime = decoded.lastDecayTime
            logger.info("Loaded \(self.memories.count) long-term memories from storage")
        } catch {
            logger.error("Failed to decode long-term memory storage: \(error.localizedDescription)")
        }
    }

    private func saveToStorage() async {
        let storage = LongTermMemoryStorage(
            memories: memories,
            categoryIndex: categoryIndex,
            keywordIndex: keywordIndex,
            lastDecayTime: lastDecayTime
        )

        do {
            let data = try JSONEncoder().encode(storage)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            logger.error("Failed to encode long-term memory storage: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

/// A long-term memory with strength and metadata
public struct LongTermMemory: Identifiable, Codable, Sendable {
    public let id: UUID
    public let content: String
    public let category: String
    public var strength: Double
    public let keywords: [String]
    public let source: LongTermMemorySource
    public let createdAt: Date
    public var lastReinforcedAt: Date?
    public var reinforcementCount: Int

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

    /// Whether this memory is considered strong
    public var isStrong: Bool {
        strength >= 0.7
    }

    /// Whether this memory is at risk of being forgotten
    public var isWeak: Bool {
        strength < 0.3
    }

    /// Days since last activity
    public var daysSinceActivity: Double {
        let lastActivity = lastReinforcedAt ?? createdAt
        return Date().timeIntervalSince(lastActivity) / 86400
    }
}

/// Source of a memory
public enum LongTermMemorySource: String, Codable, Sendable {
    case conversation   // From AI conversation
    case userInput      // Explicitly provided by user
    case inference      // Inferred from context
    case external       // From external source
    case system         // System-generated
}

/// Statistics about long-term memory
public struct LongTermMemoryStats: Sendable {
    public let totalMemories: Int
    public let categories: Int
    public let averageStrength: Double
    public let strongMemories: Int
    public let weakMemories: Int
    public let lastDecayTime: Date?

    public var healthScore: Double {
        guard totalMemories > 0 else { return 0 }
        let strongRatio = Double(strongMemories) / Double(totalMemories)
        let weakRatio = Double(weakMemories) / Double(totalMemories)
        return (strongRatio * 1.0) + ((1.0 - weakRatio) * averageStrength)
    }
}

/// Storage structure for persistence
private struct LongTermMemoryStorage: Codable {
    let memories: [UUID: LongTermMemory]
    let categoryIndex: [String: Set<UUID>]
    let keywordIndex: [String: Set<UUID>]
    let lastDecayTime: Date?
}

// MARK: - Integration with MemoryManager

extension LongTermMemoryManager {
    /// Import memories from MemoryManager via semantic search
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

    /// Export strong memories to MemoryManager
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
