// MemoryManager.swift
// Thea V2 - Omni-AI Memory System
//
// Persistent memory system enabling long-term learning and context retention.
// Implements four memory types: Semantic, Episodic, Procedural, and Prospective.
// Uses file-based persistence to avoid SwiftData naming conflicts.
//
// Intelligence Upgrade (2026):
// - Importance scoring for memory prioritization
// - Time-decay for natural forgetting
// - Semantic search using embedding similarity
// - Spaced repetition for memory strengthening

import Accelerate
import Foundation
import os.log

// MARK: - Memory Manager

/// THEA's persistent memory system - enables learning and context retention across sessions
/// Features: importance scoring, time-decay, semantic search, spaced repetition
@MainActor
public final class MemoryManager: ObservableObject {
    public static let shared = MemoryManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "Memory")

    // MARK: - Published State

    @Published public private(set) var isInitialized = false
    @Published public private(set) var memoryStats = OmniMemoryStats()

    // MARK: - Memory Store (File-based)

    private let memoryFileURL: URL
    private var memories: [OmniMemoryRecord] = []

    /// In-memory cache for fast access (LRU eviction)
    private var memoryCache: [String: OmniMemoryRecord] = [:]
    private let maxCacheSize = 500

    /// Last access times for LRU eviction
    private var accessTimes: [String: Date] = [:]

    // Stub for SwiftData context compatibility (not used)
    private var modelContext: Any?

    // MARK: - Intelligence Configuration

    /// Enable time-based decay of memory confidence
    public var enableTimeDecay: Bool = true

    /// Half-life for memory decay in days (after this time, unused memories lose half their confidence)
    public var decayHalfLifeDays: Double = 30.0

    /// Minimum confidence before a memory is eligible for pruning
    public var minimumConfidenceForRetention: Double = 0.15

    /// Enable semantic search using embeddings
    public var enableSemanticSearch: Bool = true

    /// Embedding dimension for semantic search
    private let embeddingDimension = 384

    /// Memory embeddings for semantic search
    private var memoryEmbeddings: [UUID: [Float]] = [:]

    /// Importance weights for different memory characteristics
    private let importanceWeights = MemoryImportanceWeights()

    private init() {
        // Store in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let theaDir = appSupport.appendingPathComponent("ai.thea.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        memoryFileURL = theaDir.appendingPathComponent("memories.json")

        loadMemories()
        generateMemoryEmbeddings()

        // Start periodic decay application
        scheduleDecayApplication()

        logger.info("MemoryManager initialized with \(self.memories.count) memories")
    }

    // MARK: - Setup (SwiftData compatibility stub)

    public func setModelContext(_ context: Any) {
        modelContext = context
        isInitialized = true
    }
}

// MARK: - Importance Scoring

extension MemoryManager {
    /// Calculate importance score for a memory record
    public func calculateImportance(for record: OmniMemoryRecord) -> Double {
        var score = 0.0

        // 1. Recency (more recent = more important)
        let daysSinceAccess = Date().timeIntervalSince(record.lastAccessed) / 86400
        let recencyScore = exp(-daysSinceAccess / 30.0)
        score += recencyScore * importanceWeights.recency

        // 2. Frequency (more accesses = more important)
        let frequencyScore = min(1.0, Double(record.accessCount) / 20.0)
        score += frequencyScore * importanceWeights.frequency

        // 3. Confidence (higher confidence = more important)
        score += record.confidence * importanceWeights.confidence

        // 4. Source credibility (explicit > inferred > system)
        let sourceScore: Double = switch record.source {
        case .explicit: 1.0
        case .inferred: 0.7
        case .system: 0.5
        }
        score += sourceScore * importanceWeights.source

        // 5. Type-specific bonuses
        let typeBonus: Double = switch record.type {
        case .procedural: 0.2
        case .prospective: 0.3
        case .semantic: 0.1
        case .episodic: 0.0
        }
        score += typeBonus

        return min(1.0, score)
    }

    /// Get memories sorted by importance
    public func getMemoriesByImportance(type: OmniMemoryType? = nil, limit: Int = 20) -> [OmniMemoryRecord] {
        var filtered = memories
        if let type = type {
            filtered = filtered.filter { $0.type == type }
        }

        return filtered
            .map { (record: $0, importance: calculateImportance(for: $0)) }
            .sorted { $0.importance > $1.importance }
            .prefix(limit)
            .map { $0.record }
    }
}

// MARK: - Time Decay & Spaced Repetition

extension MemoryManager {
    /// Apply time-based decay to all memories
    public func applyTimeDecay() {
        guard enableTimeDecay else { return }

        let now = Date()
        var modified = false

        for i in 0..<memories.count {
            let daysSinceAccess = now.timeIntervalSince(memories[i].lastAccessed) / 86400
            let decayFactor = pow(0.5, daysSinceAccess / decayHalfLifeDays)
            let originalConfidence = memories[i].confidence

            if daysSinceAccess > 1 && originalConfidence > minimumConfidenceForRetention {
                let newConfidence = max(minimumConfidenceForRetention, originalConfidence * decayFactor)
                if abs(newConfidence - originalConfidence) > 0.01 {
                    memories[i].confidence = newConfidence
                    modified = true
                }
            }
        }

        if modified {
            saveMemories()
            logger.debug("Applied time decay to memories")
        }
    }

    /// Schedule periodic decay application
    func scheduleDecayApplication() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 3600_000_000_000)
                applyTimeDecay()
            }
        }
    }

    /// Strengthen a memory (spaced repetition)
    public func strengthenMemory(id: UUID) async {
        guard let index = memories.firstIndex(where: { $0.id == id }) else { return }

        let currentConfidence = memories[index].confidence
        let accessCount = memories[index].accessCount

        let strengthenAmount = 0.1 * pow(0.9, Double(accessCount))
        let newConfidence = min(1.0, currentConfidence + strengthenAmount)

        memories[index].confidence = newConfidence
        memories[index].accessCount += 1
        memories[index].lastAccessed = Date()

        memoryCache[memories[index].key] = memories[index]

        saveMemories()
        logger.debug("Strengthened memory \(id) to confidence \(newConfidence)")
    }
}

// MARK: - Semantic Search

extension MemoryManager {
    /// Search memories using semantic similarity
    public func semanticSearch(query: String, limit: Int = 10) async -> [OmniMemoryRecord] {
        guard enableSemanticSearch else {
            return keywordSearch(query: query, limit: limit)
        }

        let queryEmbedding = generateEmbedding(for: query)
        var similarities: [(UUID, Double)] = []

        for (id, embedding) in memoryEmbeddings {
            let similarity = cosineSimilarity(queryEmbedding, embedding)
            similarities.append((id, similarity))
        }

        let topIds = similarities
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }

        return memories.filter { topIds.contains($0.id) }
            .sorted { mem1, mem2 in
                let sim1 = similarities.first { $0.0 == mem1.id }?.1 ?? 0
                let sim2 = similarities.first { $0.0 == mem2.id }?.1 ?? 0
                return sim1 > sim2
            }
    }

    /// Keyword-based search (fallback)
    public func keywordSearch(query: String, limit: Int = 10) -> [OmniMemoryRecord] {
        let keywords = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }

        return memories
            .filter { record in
                let content = "\(record.key) \(record.value)".lowercased()
                return keywords.contains { content.contains($0) }
            }
            .sorted { calculateImportance(for: $0) > calculateImportance(for: $1) }
            .prefix(limit)
            .map { $0 }
    }

    /// Find similar memories to a given memory
    public func findSimilarMemories(to record: OmniMemoryRecord, limit: Int = 5) async -> [OmniMemoryRecord] {
        guard let embedding = memoryEmbeddings[record.id] else {
            let newEmbedding = generateEmbedding(for: "\(record.key) \(record.value)")
            return findMemoriesBySimilarity(embedding: newEmbedding, excluding: record.id, limit: limit)
        }

        return findMemoriesBySimilarity(embedding: embedding, excluding: record.id, limit: limit)
    }

    private func findMemoriesBySimilarity(embedding: [Float], excluding: UUID? = nil, limit: Int) -> [OmniMemoryRecord] {
        var similarities: [(UUID, Double)] = []

        for (id, memEmbedding) in memoryEmbeddings {
            if id == excluding { continue }
            let similarity = cosineSimilarity(embedding, memEmbedding)
            similarities.append((id, similarity))
        }

        let topIds = similarities
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }

        return memories.filter { topIds.contains($0.id) }
    }

    func generateEmbedding(for text: String) -> [Float] {
        var embedding = [Float](repeating: 0, count: embeddingDimension)

        let normalized = text.lowercased()
        let words = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        for word in words {
            let hash = abs(word.hashValue)
            let dim1 = hash % embeddingDimension
            let dim2 = (hash / embeddingDimension) % embeddingDimension
            embedding[dim1] += 1.0
            embedding[dim2] += 0.5
        }

        for i in 0..<max(0, normalized.count - 2) {
            let startIdx = normalized.index(normalized.startIndex, offsetBy: i)
            let endIdx = normalized.index(startIdx, offsetBy: 3)
            let trigram = String(normalized[startIdx..<endIdx])
            let hash = abs(trigram.hashValue) % embeddingDimension
            embedding[hash] += 0.3
        }

        return normalizeVector(embedding)
    }

    func generateMemoryEmbeddings() {
        for memory in memories {
            let text = "\(memory.key) \(memory.value)"
            memoryEmbeddings[memory.id] = generateEmbedding(for: text)
        }
        logger.debug("Generated embeddings for \(self.memories.count) memories")
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))

        var sumA: Float = 0
        var sumB: Float = 0
        vDSP_svesq(a, 1, &sumA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &sumB, vDSP_Length(b.count))

        let normA = sqrt(sumA)
        let normB = sqrt(sumB)

        guard normA > 0 && normB > 0 else { return 0 }

        return Double(dotProduct / (normA * normB))
    }

    private func normalizeVector(_ v: [Float]) -> [Float] {
        var sumSquares: Float = 0
        vDSP_svesq(v, 1, &sumSquares, vDSP_Length(v.count))
        let norm = sqrt(sumSquares)

        guard norm > 0 else { return v }

        var result = [Float](repeating: 0, count: v.count)
        var divisor = norm
        vDSP_vsdiv(v, 1, &divisor, &result, 1, vDSP_Length(v.count))

        return result
    }
}

// MARK: - Memory Types (Semantic, Episodic, Procedural, Prospective)

extension MemoryManager {
    /// Store a learned pattern or preference
    public func storeSemanticMemory(
        category: OmniSemanticCategory,
        key: String,
        value: String,
        confidence: Double = 1.0,
        source: OmniMemorySource = .inferred
    ) async {
        let record = OmniMemoryRecord(
            type: .semantic, category: category.rawValue,
            key: key, value: value, confidence: confidence, source: source
        )
        await store(record)
        logger.debug("Stored semantic memory: \(key) = \(value.prefix(50))...")
    }

    /// Retrieve semantic memories by category
    public func retrieveSemanticMemories(
        category: OmniSemanticCategory, limit: Int = 10
    ) async -> [OmniMemoryRecord] {
        await retrieve(type: .semantic, category: category.rawValue, limit: limit)
    }

    /// Store an episodic memory (a specific interaction/event)
    public func storeEpisodicMemory(
        event: String, context: String,
        outcome: String? = nil, emotionalValence: Double = 0.0
    ) async {
        let metadata = OmniEpisodicMetadata(outcome: outcome, emotionalValence: emotionalValence)
        let record = OmniMemoryRecord(
            type: .episodic, category: "event",
            key: event, value: context, metadata: metadata.encoded()
        )
        await store(record)
        logger.debug("Stored episodic memory: \(event.prefix(50))...")
    }

    /// Retrieve episodic memories within a time range
    public func retrieveEpisodicMemories(
        from startDate: Date? = nil, to endDate: Date? = nil, limit: Int = 20
    ) async -> [OmniMemoryRecord] {
        await retrieve(type: .episodic, startDate: startDate, endDate: endDate, limit: limit)
    }

    /// Store a learned workflow or procedure
    public func storeProceduralMemory(
        taskType: String, procedure: String,
        successRate: Double, averageDuration: TimeInterval
    ) async {
        let metadata = OmniProceduralMetadata(
            successRate: successRate, averageDuration: averageDuration, executionCount: 1
        )
        let record = OmniMemoryRecord(
            type: .procedural, category: taskType,
            key: "procedure_\(taskType)", value: procedure,
            confidence: successRate, metadata: metadata.encoded()
        )
        await store(record)
        logger.debug("Stored procedural memory: \(taskType)")
    }

    /// Retrieve best procedure for a task type
    public func retrieveBestProcedure(for taskType: String) async -> OmniMemoryRecord? {
        let procedures = await retrieve(type: .procedural, category: taskType, limit: 5)
        return procedures.max { $0.confidence < $1.confidence }
    }

    /// Store a future intention or reminder
    public func storeProspectiveMemory(
        intention: String, triggerCondition: MemoryTriggerCondition,
        priority: OmniMemoryPriority = .normal
    ) async {
        let metadata = OmniProspectiveMetadata(triggerCondition: triggerCondition, isTriggered: false)
        let record = OmniMemoryRecord(
            type: .prospective, category: priority.rawValue,
            key: intention, value: triggerCondition.description, metadata: metadata.encoded()
        )
        await store(record)
        logger.debug("Stored prospective memory: \(intention.prefix(50))...")
    }

    /// Check for triggered prospective memories
    public func checkProspectiveMemories(currentContext: MemoryContextSnapshot) async -> [OmniMemoryRecord] {
        let prospective = await retrieve(type: .prospective, limit: 100)
        return prospective.filter { record in
            guard let metadata = OmniProspectiveMetadata.decode(record.metadata),
                  !metadata.isTriggered else { return false }
            return metadata.triggerCondition.isSatisfied(by: currentContext)
        }
    }
}

// MARK: - User Preference Learning

extension MemoryManager {
    /// Learn a user preference from interaction
    public func learnPreference(
        category: OmniPreferenceCategory, preference: String, strength: Double = 0.5
    ) async {
        let key = "\(category.rawValue):\(preference)"
        if let existing = memoryCache[key] {
            let newStrength = min(1.0, existing.confidence + (strength * 0.2))
            await updateConfidence(recordId: existing.id, newConfidence: newStrength)
            logger.debug("Strengthened preference: \(preference) -> \(newStrength)")
        } else {
            await storeSemanticMemory(
                category: .userPreference, key: key, value: preference,
                confidence: strength, source: .inferred
            )
            logger.debug("Learned new preference: \(preference)")
        }
    }

    /// Get learned preferences for a category
    public func getPreferences(category: OmniPreferenceCategory) async -> [String: Double] {
        let memories = await retrieveSemanticMemories(category: .userPreference, limit: 50)
        var preferences: [String: Double] = [:]
        for memory in memories {
            if memory.key.hasPrefix("\(category.rawValue):") {
                preferences[memory.value] = memory.confidence
            }
        }
        return preferences
    }
}

// MARK: - Pattern Detection

extension MemoryManager {
    /// Analyze episodic memories for patterns
    public func detectPatterns(windowDays: Int = 30, minOccurrences: Int = 3) async -> [MemoryDetectedPattern] {
        let startDate = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date())
        let episodes = await retrieveEpisodicMemories(from: startDate, limit: 500)

        var timePatterns: [String: [OmniMemoryRecord]] = [:]
        for episode in episodes {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: episode.timestamp)
            let weekday = calendar.component(.weekday, from: episode.timestamp)
            let key = "hour:\(hour):weekday:\(weekday)"
            timePatterns[key, default: []].append(episode)
        }

        var patterns: [MemoryDetectedPattern] = []
        for (timeKey, entries) in timePatterns where entries.count >= minOccurrences {
            let eventGroups = Dictionary(grouping: entries) { $0.key }
            for (event, occurrences) in eventGroups where occurrences.count >= minOccurrences {
                let components = timeKey.split(separator: ":")
                if components.count >= 4,
                   let hour = Int(components[1]),
                   let weekday = Int(components[3]) {
                    patterns.append(MemoryDetectedPattern(
                        event: event, frequency: occurrences.count,
                        hourOfDay: hour, dayOfWeek: weekday,
                        confidence: Double(occurrences.count) / Double(entries.count)
                    ))
                }
            }
        }
        return patterns.sorted { $0.confidence > $1.confidence }
    }
}

// MARK: - Memory Health & Consolidation

extension MemoryManager {
    /// Generate a health report for the memory system
    public func generateHealthReport() async -> MemoryHealthReport {
        let memoriesByType = Dictionary(grouping: memories) { $0.type }.mapValues { $0.count }
        let avgConfidence = memories.isEmpty ? 0.0 :
            memories.map(\.confidence).reduce(0, +) / Double(memories.count)
        let memoriesAtRisk = memories.filter { $0.confidence < minimumConfidenceForRetention + 0.1 }.count
        let oldestAge = memories.map { Date().timeIntervalSince($0.timestamp) }.max() ?? 0
        let categoryGroups = Dictionary(grouping: memories) { $0.category }
        let mostAccessed = categoryGroups
            .mapValues { $0.map(\.accessCount).reduce(0, +) }
            .max { $0.value < $1.value }?.key

        var suggestions: [String] = []
        if avgConfidence < 0.5 {
            suggestions.append("Many memories have low confidence. Consider reviewing and strengthening important ones.")
        }
        if memoriesAtRisk > memories.count / 4 {
            suggestions.append("25%+ of memories are at risk of pruning. Review and strengthen important ones.")
        }
        if memories.count > 5000 {
            suggestions.append("Memory store is large. Consider running consolidation.")
        }

        return MemoryHealthReport(
            totalMemories: memories.count, memoriesByType: memoriesByType,
            averageConfidence: avgConfidence, memoriesAtRisk: memoriesAtRisk,
            oldestMemoryAge: oldestAge, mostAccessedCategory: mostAccessed,
            suggestedActions: suggestions
        )
    }

    /// Consolidate and prune old memories (run periodically)
    public func consolidateMemories() async {
        logger.info("Starting memory consolidation...")
        await pruneOldMemories(type: .semantic, maxAge: 30, minConfidence: 0.3)
        await archiveOldMemories(type: .episodic, maxAge: 90)
        await removeTriggeredProspective()
        evictCacheIfNeeded()
        saveMemories()
        await loadMemoryStats()
        logger.info("Memory consolidation complete. Stats: \(self.memoryStats)")
    }
}

// MARK: - Private Storage Methods

extension MemoryManager {
    func store(_ record: OmniMemoryRecord) async {
        memoryCache[record.key] = record
        accessTimes[record.key] = Date()
        memories.append(record)

        if enableSemanticSearch {
            let text = "\(record.key) \(record.value)"
            memoryEmbeddings[record.id] = generateEmbedding(for: text)
        }

        evictCacheIfNeeded()
        saveMemories()
    }

    func retrieve(
        type: OmniMemoryType, category: String? = nil,
        startDate: Date? = nil, endDate: Date? = nil, limit: Int = 20
    ) async -> [OmniMemoryRecord] {
        let filtered = memories.filter { record in
            guard record.type == type else { return false }
            if let category, record.category != category { return false }
            if let startDate, record.timestamp < startDate { return false }
            if let endDate, record.timestamp > endDate { return false }
            return true
        }
        return Array(filtered.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }

    func updateConfidence(recordId: UUID, newConfidence: Double) async {
        if let index = memories.firstIndex(where: { $0.id == recordId }) {
            memories[index].confidence = newConfidence
            memories[index].lastAccessed = Date()
            saveMemories()
        }
    }

    private func pruneOldMemories(type: OmniMemoryType, maxAge: Int, minConfidence: Double) async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxAge, to: Date()) ?? Date()
        let beforeCount = memories.count
        memories.removeAll { record in
            record.type == type && record.timestamp < cutoffDate && record.confidence < minConfidence
        }
        let removed = beforeCount - memories.count
        logger.debug("Pruned \(removed) old \(type.rawValue) memories")
    }

    private func archiveOldMemories(type: OmniMemoryType, maxAge: Int) async {
        logger.debug("Archiving old \(type.rawValue) memories (>= \(maxAge) days)")
    }

    private func removeTriggeredProspective() async {
        let beforeCount = memories.count
        memories.removeAll { record in
            guard record.type == .prospective,
                  let metadata = OmniProspectiveMetadata.decode(record.metadata) else { return false }
            return metadata.isTriggered
        }
        let removed = beforeCount - memories.count
        logger.debug("Removed \(removed) triggered prospective memories")
    }

    func evictCacheIfNeeded() {
        guard memoryCache.count > maxCacheSize else { return }
        let sorted = accessTimes.sorted { $0.value < $1.value }
        let toRemove = sorted.prefix(memoryCache.count - maxCacheSize)
        for (key, _) in toRemove {
            memoryCache.removeValue(forKey: key)
            accessTimes.removeValue(forKey: key)
        }
    }

    func loadMemoryStats() async {
        let grouped = Dictionary(grouping: memories) { $0.type }
        memoryStats = OmniMemoryStats(
            semanticCount: grouped[.semantic]?.count ?? 0,
            episodicCount: grouped[.episodic]?.count ?? 0,
            proceduralCount: grouped[.procedural]?.count ?? 0,
            prospectiveCount: grouped[.prospective]?.count ?? 0,
            cacheSize: memoryCache.count,
            lastConsolidation: Date()
        )
    }
}

// MARK: - File Persistence

extension MemoryManager {
    func loadMemories() {
        guard FileManager.default.fileExists(atPath: memoryFileURL.path) else {
            memories = []
            return
        }

        do {
            let data = try Data(contentsOf: memoryFileURL)
            memories = try JSONDecoder().decode([OmniMemoryRecord].self, from: data)
            for memory in memories.suffix(maxCacheSize) {
                memoryCache[memory.key] = memory
                accessTimes[memory.key] = memory.lastAccessed
            }
        } catch {
            logger.error("Failed to load memories: \(error.localizedDescription)")
            memories = []
        }
    }

    func saveMemories() {
        do {
            let data = try JSONEncoder().encode(memories)
            try data.write(to: memoryFileURL, options: .atomic)
        } catch {
            logger.error("Failed to save memories: \(error.localizedDescription)")
        }
    }
}
