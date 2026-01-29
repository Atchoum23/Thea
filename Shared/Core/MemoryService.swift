//
//  MemoryService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import CloudKit
import Foundation

// MARK: - Memory Service

/// Persistent memory service equivalent to Claude Memory
/// Stores user preferences, facts, and context across sessions with iCloud sync
public actor MemoryService {
    public static let shared = MemoryService()

    // MARK: - CloudKit

    private let container = CKContainer(identifier: "iCloud.app.theathe")
    private lazy var privateDatabase = container.privateCloudDatabase

    // MARK: - State

    private var memories: [TheaMemory] = []
    private var memoryIndex: [String: Set<UUID>] = [:] // Keyword -> Memory IDs
    private var isLoaded = false

    // MARK: - Constants

    private let recordType = "Memory"
    private let maxMemories = 10000
    private let localStorageKey = "MemoryService.memories"

    // MARK: - Initialization

    private init() {}

    // MARK: - Load/Save

    /// Load memories from local storage and sync with iCloud
    public func load() async throws {
        guard !isLoaded else { return }

        // Load from local storage first (fast)
        await loadFromLocalStorage()

        // Then sync with iCloud (background)
        Task {
            try? await syncWithCloud()
        }

        isLoaded = true
    }

    private func loadFromLocalStorage() async {
        if let data = UserDefaults.standard.data(forKey: localStorageKey),
           let decoded = try? JSONDecoder().decode([TheaMemory].self, from: data)
        {
            memories = decoded
            rebuildIndex()
        }
    }

    private func saveToLocalStorage() {
        if let data = try? JSONEncoder().encode(memories) {
            UserDefaults.standard.set(data, forKey: localStorageKey)
        }
    }

    private func rebuildIndex() {
        memoryIndex.removeAll()
        for memory in memories {
            for keyword in memory.keywords {
                memoryIndex[keyword.lowercased(), default: []].insert(memory.id)
            }
        }
    }

    // MARK: - Cloud Sync

    private func syncWithCloud() async throws {
        let status = try await container.accountStatus()
        guard status == .available else { return }

        // Fetch all cloud memories
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]

        let results = try await privateDatabase.records(matching: query)

        var cloudMemories: [TheaMemory] = []
        for (_, result) in results.matchResults {
            if case let .success(record) = result,
               let memory = TheaMemory(from: record)
            {
                cloudMemories.append(memory)
            }
        }

        // Merge with local memories
        await mergeMemories(cloudMemories)
    }

    private func mergeMemories(_ cloudMemories: [TheaMemory]) async {
        var existingIds = Set(memories.map(\.id))

        for cloudMemory in cloudMemories {
            if existingIds.contains(cloudMemory.id) {
                // Update if cloud version is newer
                if let index = memories.firstIndex(where: { $0.id == cloudMemory.id }),
                   cloudMemory.modifiedAt > memories[index].modifiedAt
                {
                    memories[index] = cloudMemory
                }
            } else {
                // Add new memory
                memories.append(cloudMemory)
                existingIds.insert(cloudMemory.id)
            }
        }

        rebuildIndex()
        saveToLocalStorage()
    }

    // MARK: - Add Memory

    /// Add a new memory
    public func remember(
        _ content: String,
        type: TheaMemoryType = .fact,
        category: String? = nil,
        keywords: [String] = [],
        source: MemorySource = .manual,
        confidence: Double = 1.0
    ) async throws -> TheaMemory {
        // Extract keywords if not provided
        let extractedKeywords = keywords.isEmpty ? extractKeywords(from: content) : keywords

        let memory = TheaMemory(
            content: content,
            type: type,
            category: category,
            keywords: extractedKeywords,
            source: source,
            confidence: confidence
        )

        memories.append(memory)

        // Update index
        for keyword in memory.keywords {
            memoryIndex[keyword.lowercased(), default: []].insert(memory.id)
        }

        // Prune if needed
        if memories.count > maxMemories {
            await pruneOldMemories()
        }

        saveToLocalStorage()

        // Sync to cloud
        Task {
            try? await saveToCloud(memory)
        }

        return memory
    }

    /// Add a preference memory
    public func rememberPreference(
        key: String,
        value: String,
        category: String? = nil
    ) async throws -> TheaMemory {
        // Remove existing preference with same key
        memories.removeAll { $0.type == .preference && $0.keywords.contains(key) }

        return try await remember(
            "\(key): \(value)",
            type: .preference,
            category: category,
            keywords: [key],
            source: .inferred
        )
    }

    /// Add a user fact
    public func rememberFact(
        _ fact: String,
        category: String? = nil,
        keywords: [String] = []
    ) async throws -> TheaMemory {
        try await remember(
            fact,
            type: .fact,
            category: category,
            keywords: keywords,
            source: .userProvided
        )
    }

    /// Add context from conversation
    public func rememberFromConversation(
        _ content: String,
        conversationId: String
    ) async throws -> TheaMemory {
        try await remember(
            content,
            type: .context,
            category: "conversation",
            keywords: [conversationId],
            source: .conversation,
            confidence: 0.8
        )
    }

    // MARK: - Recall

    /// Recall memories matching a query
    public func recall(
        query: String,
        limit: Int = 10,
        types: [TheaMemoryType]? = nil,
        minConfidence: Double = 0.0
    ) async -> [TheaMemory] {
        let queryKeywords = extractKeywords(from: query)
        var scoredMemories: [(TheaMemory, Double)] = []

        for memory in memories {
            // SAFETY: Use optional chaining instead of force unwrap
            guard types?.contains(memory.type) ?? true else { continue }
            guard memory.confidence >= minConfidence else { continue }

            let score = calculateRelevanceScore(memory: memory, queryKeywords: queryKeywords)
            if score > 0 {
                scoredMemories.append((memory, score))
            }
        }

        // Sort by score descending
        scoredMemories.sort { $0.1 > $1.1 }

        // Update access times for recalled memories
        let recalledIds = Set(scoredMemories.prefix(limit).map(\.0.id))
        for i in memories.indices {
            if recalledIds.contains(memories[i].id) {
                memories[i].accessCount += 1
                memories[i].lastAccessedAt = Date()
            }
        }

        return Array(scoredMemories.prefix(limit).map(\.0))
    }

    /// Recall memories by category
    public func recall(category: String, limit: Int = 20) async -> [TheaMemory] {
        memories
            .filter { $0.category == category }
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(limit)
            .map(\.self)
    }

    /// Recall preference by key
    public func recallPreference(key: String) async -> String? {
        memories
            .first { $0.type == .preference && $0.keywords.contains(key) }
            .flatMap { content in
                if let colonIndex = content.content.firstIndex(of: ":") {
                    return String(content.content[content.content.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
                return content.content
            }
    }

    /// Get all memories for context injection
    public func getContextMemories(forQuery query: String, maxTokens: Int = 2000) async -> String {
        let relevantMemories = await recall(query: query, limit: 20)

        var context = "Relevant memories:\n"
        var currentTokens = 0
        let tokensPerChar = 0.25 // Rough estimate

        for memory in relevantMemories {
            let memoryText = "- [\(memory.type.rawValue)] \(memory.content)\n"
            let estimatedTokens = Int(Double(memoryText.count) * tokensPerChar)

            if currentTokens + estimatedTokens > maxTokens {
                break
            }

            context += memoryText
            currentTokens += estimatedTokens
        }

        return context
    }

    // MARK: - Update/Delete

    /// Update a memory
    public func update(_ memory: TheaMemory, content: String? = nil, keywords: [String]? = nil) async throws {
        guard let index = memories.firstIndex(where: { $0.id == memory.id }) else {
            throw TheaMemoryError.memoryNotFound
        }

        if let content {
            memories[index].content = content
        }

        if let keywords {
            // Update index
            for oldKeyword in memories[index].keywords {
                memoryIndex[oldKeyword.lowercased()]?.remove(memory.id)
            }
            memories[index].keywords = keywords
            for newKeyword in keywords {
                memoryIndex[newKeyword.lowercased(), default: []].insert(memory.id)
            }
        }

        memories[index].modifiedAt = Date()
        saveToLocalStorage()

        Task {
            try? await saveToCloud(memories[index])
        }
    }

    /// Forget a specific memory
    public func forget(_ memory: TheaMemory) async {
        memories.removeAll { $0.id == memory.id }

        for keyword in memory.keywords {
            memoryIndex[keyword.lowercased()]?.remove(memory.id)
        }

        saveToLocalStorage()

        Task {
            try? await deleteFromCloud(memory)
        }
    }

    /// Forget all memories of a type
    public func forget(type: TheaMemoryType) async {
        let toRemove = memories.filter { $0.type == type }
        memories.removeAll { $0.type == type }

        for memory in toRemove {
            for keyword in memory.keywords {
                memoryIndex[keyword.lowercased()]?.remove(memory.id)
            }
        }

        saveToLocalStorage()
    }

    /// Forget all memories
    public func forgetAll() async {
        memories.removeAll()
        memoryIndex.removeAll()
        saveToLocalStorage()

        // Delete all from cloud
        Task {
            try? await deleteAllFromCloud()
        }
    }

    // MARK: - Cloud Operations

    private func saveToCloud(_ memory: TheaMemory) async throws {
        let record = memory.toCKRecord()
        _ = try await privateDatabase.save(record)
    }

    private func deleteFromCloud(_ memory: TheaMemory) async throws {
        let recordID = CKRecord.ID(recordName: memory.id.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    private func deleteAllFromCloud() async throws {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)

        for (id, _) in results.matchResults {
            _ = try? await privateDatabase.deleteRecord(withID: id)
        }
    }

    // MARK: - Maintenance

    private func pruneOldMemories() async {
        // Sort by importance (combination of confidence, access count, recency)
        let sortedMemories = memories.sorted { m1, m2 in
            let score1 = calculateImportanceScore(m1)
            let score2 = calculateImportanceScore(m2)
            return score1 > score2
        }

        memories = Array(sortedMemories.prefix(maxMemories))
        rebuildIndex()
    }

    private func calculateImportanceScore(_ memory: TheaMemory) -> Double {
        let recencyDays = Date().timeIntervalSince(memory.lastAccessedAt) / 86400
        let recencyScore = max(0, 1.0 - (recencyDays / 365))
        let accessScore = min(1.0, Double(memory.accessCount) / 100)

        return (memory.confidence * 0.3) + (recencyScore * 0.4) + (accessScore * 0.3)
    }

    private func calculateRelevanceScore(memory: TheaMemory, queryKeywords: [String]) -> Double {
        var score = 0.0

        for keyword in queryKeywords {
            if memory.keywords.contains(where: { $0.lowercased() == keyword.lowercased() }) {
                score += 1.0
            } else if memory.content.lowercased().contains(keyword.lowercased()) {
                score += 0.5
            }
        }

        // Boost by confidence
        score *= memory.confidence

        // Boost by recency
        let daysSinceModified = Date().timeIntervalSince(memory.modifiedAt) / 86400
        let recencyBoost = max(0.5, 1.0 - (daysSinceModified / 365))
        score *= recencyBoost

        return score
    }

    private func extractKeywords(from text: String) -> [String] {
        // Simple keyword extraction - could be enhanced with NLP
        let stopWords = Set(["the", "a", "an", "is", "are", "was", "were", "be", "been",
                             "being", "have", "has", "had", "do", "does", "did", "will",
                             "would", "could", "should", "may", "might", "must", "shall",
                             "can", "need", "dare", "ought", "used", "to", "of", "in",
                             "for", "on", "with", "at", "by", "from", "as", "into",
                             "through", "during", "before", "after", "above", "below",
                             "between", "under", "again", "further", "then", "once"])

        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 && !stopWords.contains($0) }

        // Return unique words
        return Array(Set(words))
    }

    // MARK: - Statistics

    /// Get memory statistics
    public func getStatistics() async -> MemoryStatistics {
        let typeDistribution = Dictionary(grouping: memories, by: \.type)
            .mapValues { $0.count }

        let categoryDistribution = Dictionary(grouping: memories.compactMap(\.category)) { $0 }
            .mapValues { $0.count }

        return MemoryStatistics(
            totalMemories: memories.count,
            typeDistribution: typeDistribution,
            categoryDistribution: categoryDistribution,
            oldestMemory: memories.min { $0.createdAt < $1.createdAt }?.createdAt,
            newestMemory: memories.max { $0.createdAt < $1.createdAt }?.createdAt,
            averageConfidence: memories.isEmpty ? 0 : memories.map(\.confidence).reduce(0, +) / Double(memories.count)
        )
    }
}

// MARK: - Memory Model

public struct TheaMemory: Identifiable, Codable, Sendable {
    public let id: UUID
    public var content: String
    public let type: TheaMemoryType
    public var category: String?
    public var keywords: [String]
    public let source: MemorySource
    public var confidence: Double
    public let createdAt: Date
    public var modifiedAt: Date
    public var lastAccessedAt: Date
    public var accessCount: Int

    public init(
        id: UUID = UUID(),
        content: String,
        type: TheaMemoryType = .fact,
        category: String? = nil,
        keywords: [String] = [],
        source: MemorySource = .manual,
        confidence: Double = 1.0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        accessCount: Int = 0
    ) {
        self.id = id
        self.content = content
        self.type = type
        self.category = category
        self.keywords = keywords
        self.source = source
        self.confidence = confidence
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
    }

    init?(from record: CKRecord) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let content = record["content"] as? String,
              let typeString = record["type"] as? String,
              let type = TheaMemoryType(rawValue: typeString)
        else {
            return nil
        }

        self.id = id
        self.content = content
        self.type = type
        category = record["category"] as? String
        keywords = record["keywords"] as? [String] ?? []
        source = MemorySource(rawValue: record["source"] as? String ?? "manual") ?? .manual
        confidence = record["confidence"] as? Double ?? 1.0
        createdAt = record["createdAt"] as? Date ?? Date()
        modifiedAt = record["modifiedAt"] as? Date ?? Date()
        lastAccessedAt = record["lastAccessedAt"] as? Date ?? Date()
        accessCount = record["accessCount"] as? Int ?? 0
    }

    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: "Memory", recordID: recordID)

        record["id"] = id.uuidString
        record["content"] = content
        record["type"] = type.rawValue
        record["category"] = category
        record["keywords"] = keywords
        record["source"] = source.rawValue
        record["confidence"] = confidence
        record["createdAt"] = createdAt
        record["modifiedAt"] = modifiedAt
        record["lastAccessedAt"] = lastAccessedAt
        record["accessCount"] = accessCount

        return record
    }
}

// MARK: - Memory Types

public enum TheaMemoryType: String, Codable, Sendable, CaseIterable {
    case fact // User facts (name, location, etc.)
    case preference // User preferences (coding style, etc.)
    case context // Conversation context
    case instruction // Custom instructions
    case pattern // Learned patterns
}

public enum MemorySource: String, Codable, Sendable {
    case manual // Explicitly added by user
    case userProvided // User mentioned in conversation
    case inferred // Inferred from behavior
    case conversation // Extracted from conversation
    case imported // Imported from external source
}

// MARK: - Memory Statistics

public struct MemoryStatistics: Sendable {
    public let totalMemories: Int
    public let typeDistribution: [TheaMemoryType: Int]
    public let categoryDistribution: [String: Int]
    public let oldestMemory: Date?
    public let newestMemory: Date?
    public let averageConfidence: Double
}

// MARK: - Memory Error

public enum TheaMemoryError: Error, LocalizedError, Sendable {
    case memoryNotFound
    case syncFailed(String)
    case storageFull

    public var errorDescription: String? {
        switch self {
        case .memoryNotFound:
            "Memory not found"
        case let .syncFailed(reason):
            "Memory sync failed: \(reason)"
        case .storageFull:
            "Memory storage is full"
        }
    }
}
