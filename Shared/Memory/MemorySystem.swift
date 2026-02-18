//
//  MemorySystem.swift
//  Thea
//
//  Canonical memory system actor providing multi-tier memory management.
//  Replaces the excluded MetaAI/MemorySystem with a clean implementation
//  that integrates with MemoryManager and LongTermMemoryManager.
//
//  Types are prefixed with "Retrieval" to avoid conflicts with
//  Intelligence/Memory/LongTermMemorySystem.swift types.
//
//  CREATED: February 8, 2026
//

import Foundation
import OSLog

// MARK: - Memory System

/// Multi-tier memory system that bridges MemoryManager (semantic/episodic/procedural)
/// with LongTermMemoryManager (fact storage with decay). Used by ActiveMemoryRetrieval
/// and MemoryAugmentedChat for context injection.
public actor MemorySystem {
    public static let shared = MemorySystem()

    private let logger = Logger(subsystem: "ai.thea.app", category: "MemorySystem")

    // MARK: - Short-Term Memory Store

    /// In-memory short-term buffer (cleared on restart)
    private var shortTermMemories: [RetrievalMemoryEntry] = []
    private let maxShortTermMemories = 200

    private init() {}

    // MARK: - Short-Term Memory

    /// Add a short-term memory entry (contextual, working memory)
    @discardableResult
    public func addShortTermMemory(
        content: String,
        type: RetrievalMemoryEntryType = .contextual,
        metadata: [String: String] = [:]
    ) throws -> UUID {
        let entry = RetrievalMemoryEntry(
            content: content,
            tier: .shortTerm,
            type: type,
            importance: 0.5,
            metadata: metadata
        )

        shortTermMemories.append(entry)

        // Enforce limit
        if shortTermMemories.count > maxShortTermMemories {
            shortTermMemories.removeFirst(shortTermMemories.count - maxShortTermMemories)
        }

        logger.debug("Added short-term memory: \(entry.id)")
        return entry.id
    }

    // MARK: - Retrieval API (used by ActiveMemoryRetrieval)

    /// Retrieve memories relevant to a query across all tiers
    public func retrieveRelevantMemories(
        for query: String,
        limit: Int = 10,
        threshold: Double = 0.3
    ) async throws -> [RetrievalMemoryEntry] {
        var results: [RetrievalMemoryEntry] = []

        // 1. Search short-term memories by keyword overlap
        let queryWords = Set(query.lowercased().components(separatedBy: .alphanumerics.inverted).filter { $0.count > 2 })

        let shortTermMatches = shortTermMemories.filter { entry in
            let contentWords = Set(entry.content.lowercased().components(separatedBy: .alphanumerics.inverted).filter { $0.count > 2 })
            let overlap = queryWords.intersection(contentWords)
            return !overlap.isEmpty
        }
        results.append(contentsOf: shortTermMatches)

        // 2. Search MemoryManager (semantic search or keyword)
        let managerResults = await MemoryManager.shared.semanticSearch(query: query, limit: limit)
        for record in managerResults {
            results.append(RetrievalMemoryEntry(
                content: "\(record.key): \(record.value)",
                tier: record.type == .semantic ? .longTerm : .shortTerm,
                type: .contextual,
                importance: record.confidence,
                metadata: ["category": record.category],
                lastAccessed: record.lastAccessed
            ))
        }

        // 3. Search LongTermMemoryManager
        let longTermResults = await LongTermMemoryManager.shared.search(
            keywords: Array(queryWords),
            minStrength: threshold,
            limit: limit
        )
        for memory in longTermResults {
            results.append(RetrievalMemoryEntry(
                content: memory.content,
                tier: .longTerm,
                type: .factual,
                importance: memory.strength,
                metadata: ["category": memory.category],
                lastAccessed: memory.lastReinforcedAt ?? memory.createdAt
            ))
        }

        // Sort by importance, deduplicate by content prefix
        results.sort { $0.importance > $1.importance }

        var seen: Set<String> = []
        results = results.filter { entry in
            let key = String(entry.content.prefix(80)).lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }

        return Array(results.prefix(limit))
    }

    /// Retrieve episodic memories relevant to a query
    public func retrieveEpisodicMemories(
        for query: String,
        limit: Int = 5
    ) async throws -> [RetrievalEpisodicEntry] {
        let records = await MemoryManager.shared.retrieveEpisodicMemories(
            from: Calendar.current.date(byAdding: .day, value: -90, to: Date()),
            limit: limit * 2
        )

        // Filter by relevance to query
        let queryLower = query.lowercased()
        let filtered = records.filter { record in
            record.key.lowercased().contains(queryLower) ||
            record.value.lowercased().contains(queryLower) ||
            queryLower.split(separator: " ").contains { word in
                record.key.lowercased().contains(word) || record.value.lowercased().contains(word)
            }
        }

        return filtered.prefix(limit).map { record in
            RetrievalEpisodicEntry(
                event: record.key,
                context: record.value,
                importance: Float(record.confidence),
                timestamp: record.timestamp,
                metadata: ["category": record.category],
                lastAccessed: record.lastAccessed
            )
        }
    }

    /// Retrieve semantic memories (knowledge base) relevant to a query
    public func retrieveSemanticMemories(
        for query: String,
        limit: Int = 5
    ) async throws -> [RetrievalSemanticEntry] {
        let records = await MemoryManager.shared.semanticSearch(query: query, limit: limit)

        return records.map { record in
            RetrievalSemanticEntry(
                concept: record.key,
                definition: record.value,
                importance: Float(record.confidence),
                metadata: ["category": record.category],
                lastAccessed: record.lastAccessed
            )
        }
    }

    /// Retrieve procedural memories (how-to knowledge) relevant to a query
    public func retrieveProceduralMemories(
        for query: String,
        limit: Int = 3
    ) async throws -> [RetrievalProceduralEntry] {
        // Search MemoryManager procedural records
        let keywords = query.lowercased().components(separatedBy: .alphanumerics.inverted).filter { $0.count > 2 }

        var results: [RetrievalProceduralEntry] = []

        for keyword in keywords {
            if let procedure = await MemoryManager.shared.retrieveBestProcedure(for: keyword) {
                if let metadata = OmniProceduralMetadata.decode(procedure.metadata) {
                    results.append(RetrievalProceduralEntry(
                        skill: procedure.key,
                        steps: [procedure.value],
                        successRate: Float(metadata.successRate),
                        importance: Float(procedure.confidence),
                        metadata: ["category": procedure.category],
                        lastAccessed: procedure.lastAccessed
                    ))
                }
            }
        }

        return Array(results.prefix(limit))
    }

    // MARK: - Statistics

    public func getStatistics() -> MemorySystemStats {
        MemorySystemStats(
            shortTermCount: shortTermMemories.count,
            maxShortTerm: maxShortTermMemories
        )
    }

    /// Clear short-term memories
    public func clearShortTermMemory() {
        shortTermMemories.removeAll()
        logger.info("Cleared short-term memory")
    }
}

// MARK: - Retrieval Memory Entry (canonical type for cross-tier results)

/// A memory entry returned from retrieval queries
public struct RetrievalMemoryEntry: Identifiable, Sendable {
    public let id: UUID
    public let content: String
    public let tier: RetrievalMemoryTier
    public let type: RetrievalMemoryEntryType
    public let importance: Double
    public let metadata: [String: String]
    public let createdAt: Date
    public var lastAccessed: Date

    public init(
        id: UUID = UUID(),
        content: String,
        tier: RetrievalMemoryTier = .shortTerm,
        type: RetrievalMemoryEntryType = .contextual,
        importance: Double = 0.5,
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        lastAccessed: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.tier = tier
        self.type = type
        self.importance = importance
        self.metadata = metadata
        self.createdAt = createdAt
        self.lastAccessed = lastAccessed
    }
}

// MARK: - Retrieval Memory Tier

/// Memory tier classification for retrieval results
public enum RetrievalMemoryTier: String, Codable, Sendable {
    case shortTerm   // Working memory, volatile
    case longTerm    // Persistent, decays over time
    case episodic    // Event-based memories
    case semantic    // Knowledge/fact-based
    case procedural  // How-to knowledge
}

// MARK: - Retrieval Memory Entry Type

/// Type of memory entry for classification
public enum RetrievalMemoryEntryType: String, Codable, Sendable {
    case contextual    // Context from conversation
    case factual       // Learned fact
    case preference    // User preference
    case procedural    // How-to knowledge
    case temporal      // Time-based memory
}

// MARK: - Retrieval Episodic Entry

/// Episodic memory result (specific events/experiences)
public struct RetrievalEpisodicEntry: Sendable {
    public let event: String
    public let context: String
    public let importance: Float
    public let timestamp: Date
    public let metadata: [String: String]
    public var lastAccessed: Date

    public init(
        event: String,
        context: String,
        importance: Float = 0.5,
        timestamp: Date = Date(),
        metadata: [String: String] = [:],
        lastAccessed: Date = Date()
    ) {
        self.event = event
        self.context = context
        self.importance = importance
        self.timestamp = timestamp
        self.metadata = metadata
        self.lastAccessed = lastAccessed
    }
}

// MARK: - Retrieval Semantic Entry

/// Semantic memory result (concepts and definitions)
public struct RetrievalSemanticEntry: Sendable {
    public let concept: String
    public let definition: String
    public let importance: Float
    public let metadata: [String: String]
    public var lastAccessed: Date

    public init(
        concept: String,
        definition: String,
        importance: Float = 0.5,
        metadata: [String: String] = [:],
        lastAccessed: Date = Date()
    ) {
        self.concept = concept
        self.definition = definition
        self.importance = importance
        self.metadata = metadata
        self.lastAccessed = lastAccessed
    }
}

// MARK: - Retrieval Procedural Entry

/// Procedural memory result (skills and how-to knowledge)
public struct RetrievalProceduralEntry: Sendable {
    public let skill: String
    public let steps: [String]
    public let successRate: Float
    public let importance: Float
    public let metadata: [String: String]
    public var lastAccessed: Date

    public init(
        skill: String,
        steps: [String] = [],
        successRate: Float = 0.5,
        importance: Float = 0.5,
        metadata: [String: String] = [:],
        lastAccessed: Date = Date()
    ) {
        self.skill = skill
        self.steps = steps
        self.successRate = successRate
        self.importance = importance
        self.metadata = metadata
        self.lastAccessed = lastAccessed
    }
}

// MARK: - Memory System Stats

/// Statistics about the current state of the multi-tier memory system.
public struct MemorySystemStats: Sendable {
    public let shortTermCount: Int
    public let maxShortTerm: Int
}
