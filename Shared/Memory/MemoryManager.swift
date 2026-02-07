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

    // MARK: - Importance Scoring

    /// Calculate importance score for a memory record
    public func calculateImportance(for record: OmniMemoryRecord) -> Double {
        var score = 0.0

        // 1. Recency (more recent = more important)
        let daysSinceAccess = Date().timeIntervalSince(record.lastAccessed) / 86400
        let recencyScore = exp(-daysSinceAccess / 30.0) // Exponential decay over 30 days
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
        case .procedural: 0.2  // Procedural knowledge is valuable
        case .prospective: 0.3 // Future intentions are important
        case .semantic: 0.1    // Knowledge base entries
        case .episodic: 0.0    // Episodes are context-dependent
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

    // MARK: - Time Decay

    /// Apply time-based decay to all memories
    public func applyTimeDecay() {
        guard enableTimeDecay else { return }

        let now = Date()
        var modified = false

        for i in 0..<memories.count {
            let daysSinceAccess = now.timeIntervalSince(memories[i].lastAccessed) / 86400

            // Apply exponential decay based on half-life
            let decayFactor = pow(0.5, daysSinceAccess / decayHalfLifeDays)
            let originalConfidence = memories[i].confidence

            // Don't decay below minimum or recently accessed memories
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
    private func scheduleDecayApplication() {
        // Apply decay every hour
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 3600_000_000_000) // 1 hour
                applyTimeDecay()
            }
        }
    }

    /// Strengthen a memory (spaced repetition)
    public func strengthenMemory(id: UUID) async {
        guard let index = memories.firstIndex(where: { $0.id == id }) else { return }

        // Increase confidence based on spaced repetition
        let currentConfidence = memories[index].confidence
        let accessCount = memories[index].accessCount

        // Diminishing returns on strengthening
        let strengthenAmount = 0.1 * pow(0.9, Double(accessCount))
        let newConfidence = min(1.0, currentConfidence + strengthenAmount)

        memories[index].confidence = newConfidence
        memories[index].accessCount += 1
        memories[index].lastAccessed = Date()

        // Update cache
        memoryCache[memories[index].key] = memories[index]

        saveMemories()
        logger.debug("Strengthened memory \(id) to confidence \(newConfidence)")
    }

    // MARK: - Semantic Search

    /// Search memories using semantic similarity
    public func semanticSearch(query: String, limit: Int = 10) async -> [OmniMemoryRecord] {
        guard enableSemanticSearch else {
            // Fallback to keyword search
            return keywordSearch(query: query, limit: limit)
        }

        let queryEmbedding = generateEmbedding(for: query)

        // Calculate similarity for all memories with embeddings
        var similarities: [(UUID, Double)] = []

        for (id, embedding) in memoryEmbeddings {
            let similarity = cosineSimilarity(queryEmbedding, embedding)
            similarities.append((id, similarity))
        }

        // Sort by similarity and return top matches
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
            // Generate embedding on the fly
            let newEmbedding = generateEmbedding(for: "\(record.key) \(record.value)")
            return findMemoriesBySimilarity(embedding: newEmbedding, excluding: record.id, limit: limit)
        }

        return findMemoriesBySimilarity(embedding: embedding, excluding: record.id, limit: limit)
    }

    /// Find memories by embedding similarity
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

    /// Generate embedding for text using simple hash-based approach
    private func generateEmbedding(for text: String) -> [Float] {
        var embedding = [Float](repeating: 0, count: embeddingDimension)

        let normalized = text.lowercased()
        let words = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        // Word-level features
        for word in words {
            let hash = abs(word.hashValue)
            let dim1 = hash % embeddingDimension
            let dim2 = (hash / embeddingDimension) % embeddingDimension
            embedding[dim1] += 1.0
            embedding[dim2] += 0.5
        }

        // Character trigram features
        for i in 0..<max(0, normalized.count - 2) {
            let startIdx = normalized.index(normalized.startIndex, offsetBy: i)
            let endIdx = normalized.index(startIdx, offsetBy: 3)
            let trigram = String(normalized[startIdx..<endIdx])
            let hash = abs(trigram.hashValue) % embeddingDimension
            embedding[hash] += 0.3
        }

        return normalizeVector(embedding)
    }

    /// Generate embeddings for all memories
    private func generateMemoryEmbeddings() {
        for memory in memories {
            let text = "\(memory.key) \(memory.value)"
            memoryEmbeddings[memory.id] = generateEmbedding(for: text)
        }
        logger.debug("Generated embeddings for \(self.memories.count) memories")
    }

    /// Cosine similarity between two vectors
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

    /// Normalize a vector to unit length
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

    // MARK: - Setup (SwiftData compatibility stub)

    public func setModelContext(_ context: Any) {
        modelContext = context
        isInitialized = true
    }

    // MARK: - Semantic Memory (Learned Knowledge)

    /// Store a learned pattern or preference
    public func storeSemanticMemory(
        category: OmniSemanticCategory,
        key: String,
        value: String,
        confidence: Double = 1.0,
        source: OmniMemorySource = .inferred
    ) async {
        let record = OmniMemoryRecord(
            type: .semantic,
            category: category.rawValue,
            key: key,
            value: value,
            confidence: confidence,
            source: source
        )

        await store(record)
        logger.debug("Stored semantic memory: \(key) = \(value.prefix(50))...")
    }

    /// Retrieve semantic memories by category
    public func retrieveSemanticMemories(
        category: OmniSemanticCategory,
        limit: Int = 10
    ) async -> [OmniMemoryRecord] {
        await retrieve(
            type: .semantic,
            category: category.rawValue,
            limit: limit
        )
    }

    // MARK: - Episodic Memory (Experiences)

    /// Store an episodic memory (a specific interaction/event)
    public func storeEpisodicMemory(
        event: String,
        context: String,
        outcome: String? = nil,
        emotionalValence: Double = 0.0  // -1 to 1 (negative to positive)
    ) async {
        let metadata = OmniEpisodicMetadata(
            outcome: outcome,
            emotionalValence: emotionalValence
        )

        let record = OmniMemoryRecord(
            type: .episodic,
            category: "event",
            key: event,
            value: context,
            metadata: metadata.encoded()
        )

        await store(record)
        logger.debug("Stored episodic memory: \(event.prefix(50))...")
    }

    /// Retrieve episodic memories within a time range
    public func retrieveEpisodicMemories(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        limit: Int = 20
    ) async -> [OmniMemoryRecord] {
        await retrieve(
            type: .episodic,
            startDate: startDate,
            endDate: endDate,
            limit: limit
        )
    }

    // MARK: - Procedural Memory (How to do things)

    /// Store a learned workflow or procedure
    public func storeProceduralMemory(
        taskType: String,
        procedure: String,
        successRate: Double,
        averageDuration: TimeInterval
    ) async {
        let metadata = OmniProceduralMetadata(
            successRate: successRate,
            averageDuration: averageDuration,
            executionCount: 1
        )

        let record = OmniMemoryRecord(
            type: .procedural,
            category: taskType,
            key: "procedure_\(taskType)",
            value: procedure,
            confidence: successRate,
            metadata: metadata.encoded()
        )

        await store(record)
        logger.debug("Stored procedural memory: \(taskType)")
    }

    /// Retrieve best procedure for a task type
    public func retrieveBestProcedure(for taskType: String) async -> OmniMemoryRecord? {
        let procedures = await retrieve(
            type: .procedural,
            category: taskType,
            limit: 5
        )

        // Return highest confidence procedure
        return procedures.max { $0.confidence < $1.confidence }
    }

    // MARK: - Prospective Memory (Future intentions)

    /// Store a future intention or reminder
    public func storeProspectiveMemory(
        intention: String,
        triggerCondition: MemoryTriggerCondition,
        priority: OmniMemoryPriority = .normal
    ) async {
        let metadata = OmniProspectiveMetadata(
            triggerCondition: triggerCondition,
            isTriggered: false
        )

        let record = OmniMemoryRecord(
            type: .prospective,
            category: priority.rawValue,
            key: intention,
            value: triggerCondition.description,
            metadata: metadata.encoded()
        )

        await store(record)
        logger.debug("Stored prospective memory: \(intention.prefix(50))...")
    }

    /// Check for triggered prospective memories
    public func checkProspectiveMemories(
        currentContext: MemoryContextSnapshot
    ) async -> [OmniMemoryRecord] {
        let prospective = await retrieve(type: .prospective, limit: 100)

        return prospective.filter { record in
            guard let metadata = OmniProspectiveMetadata.decode(record.metadata),
                  !metadata.isTriggered else {
                return false
            }

            return metadata.triggerCondition.isSatisfied(by: currentContext)
        }
    }

    // MARK: - User Preference Learning

    /// Learn a user preference from interaction
    public func learnPreference(
        category: OmniPreferenceCategory,
        preference: String,
        strength: Double = 0.5  // 0-1, increases with repeated observation
    ) async {
        // Check if preference already exists
        let key = "\(category.rawValue):\(preference)"
        if let existing = memoryCache[key] {
            // Strengthen existing preference
            let newStrength = min(1.0, existing.confidence + (strength * 0.2))
            await updateConfidence(recordId: existing.id, newConfidence: newStrength)
            logger.debug("Strengthened preference: \(preference) -> \(newStrength)")
        } else {
            // Store new preference
            await storeSemanticMemory(
                category: .userPreference,
                key: key,
                value: preference,
                confidence: strength,
                source: .inferred
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
                let preference = memory.value
                preferences[preference] = memory.confidence
            }
        }

        return preferences
    }

    // MARK: - Pattern Detection

    /// Analyze episodic memories for patterns
    public func detectPatterns(
        windowDays: Int = 30,
        minOccurrences: Int = 3
    ) async -> [MemoryDetectedPattern] {
        let startDate = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date())
        let episodes = await retrieveEpisodicMemories(from: startDate, limit: 500)

        // Group by hour of day and day of week
        var timePatterns: [String: [OmniMemoryRecord]] = [:]

        for episode in episodes {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: episode.timestamp)
            let weekday = calendar.component(.weekday, from: episode.timestamp)
            let key = "hour:\(hour):weekday:\(weekday)"

            timePatterns[key, default: []].append(episode)
        }

        // Find patterns with enough occurrences
        var patterns: [MemoryDetectedPattern] = []

        for (timeKey, entries) in timePatterns where entries.count >= minOccurrences {
            // Group similar events
            let eventGroups = Dictionary(grouping: entries) { $0.key }

            for (event, occurrences) in eventGroups where occurrences.count >= minOccurrences {
                let components = timeKey.split(separator: ":")
                if components.count >= 4,
                   let hour = Int(components[1]),
                   let weekday = Int(components[3]) {
                    patterns.append(MemoryDetectedPattern(
                        event: event,
                        frequency: occurrences.count,
                        hourOfDay: hour,
                        dayOfWeek: weekday,
                        confidence: Double(occurrences.count) / Double(entries.count)
                    ))
                }
            }
        }

        return patterns.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Memory Health

    /// Generate a health report for the memory system
    public func generateHealthReport() async -> MemoryHealthReport {
        let memoriesByType = Dictionary(grouping: memories) { $0.type }
            .mapValues { $0.count }

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
            totalMemories: memories.count,
            memoriesByType: memoriesByType,
            averageConfidence: avgConfidence,
            memoriesAtRisk: memoriesAtRisk,
            oldestMemoryAge: oldestAge,
            mostAccessedCategory: mostAccessed,
            suggestedActions: suggestions
        )
    }

    // MARK: - Memory Consolidation

    /// Consolidate and prune old memories (run periodically)
    public func consolidateMemories() async {
        logger.info("Starting memory consolidation...")

        // 1. Prune low-confidence semantic memories older than 30 days
        await pruneOldMemories(type: .semantic, maxAge: 30, minConfidence: 0.3)

        // 2. Archive episodic memories older than 90 days
        await archiveOldMemories(type: .episodic, maxAge: 90)

        // 3. Remove triggered prospective memories
        await removeTriggeredProspective()

        // 4. Evict least-recently-used cache entries
        evictCacheIfNeeded()

        // 5. Save to disk
        saveMemories()

        await loadMemoryStats()
        logger.info("Memory consolidation complete. Stats: \(self.memoryStats)")
    }

    // MARK: - Private Storage Methods

    private func store(_ record: OmniMemoryRecord) async {
        // Store in cache
        memoryCache[record.key] = record
        accessTimes[record.key] = Date()

        // Store in memory array
        memories.append(record)

        // Generate embedding for semantic search
        if enableSemanticSearch {
            let text = "\(record.key) \(record.value)"
            memoryEmbeddings[record.id] = generateEmbedding(for: text)
        }

        evictCacheIfNeeded()
        saveMemories()
    }

    private func retrieve(
        type: OmniMemoryType,
        category: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 20
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

    private func updateConfidence(recordId: UUID, newConfidence: Double) async {
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
            record.type == type &&
            record.timestamp < cutoffDate &&
            record.confidence < minConfidence
        }

        let removed = beforeCount - memories.count
        logger.debug("Pruned \(removed) old \(type.rawValue) memories")
    }

    private func archiveOldMemories(type: OmniMemoryType, maxAge: Int) async {
        // For now, just log - could export to file or compress
        logger.debug("Archiving old \(type.rawValue) memories (>= \(maxAge) days)")
    }

    private func removeTriggeredProspective() async {
        let beforeCount = memories.count
        memories.removeAll { record in
            guard record.type == .prospective,
                  let metadata = OmniProspectiveMetadata.decode(record.metadata) else {
                return false
            }
            return metadata.isTriggered
        }

        let removed = beforeCount - memories.count
        logger.debug("Removed \(removed) triggered prospective memories")
    }

    private func evictCacheIfNeeded() {
        guard memoryCache.count > maxCacheSize else { return }

        // Sort by last access time, remove oldest
        let sorted = accessTimes.sorted { $0.value < $1.value }
        let toRemove = sorted.prefix(memoryCache.count - maxCacheSize)

        for (key, _) in toRemove {
            memoryCache.removeValue(forKey: key)
            accessTimes.removeValue(forKey: key)
        }
    }

    private func loadMemoryStats() async {
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

    // MARK: - File Persistence

    private func loadMemories() {
        guard FileManager.default.fileExists(atPath: memoryFileURL.path) else {
            memories = []
            return
        }

        do {
            let data = try Data(contentsOf: memoryFileURL)
            memories = try JSONDecoder().decode([OmniMemoryRecord].self, from: data)

            // Rebuild cache from recent entries
            for memory in memories.suffix(maxCacheSize) {
                memoryCache[memory.key] = memory
                accessTimes[memory.key] = memory.lastAccessed
            }
        } catch {
            logger.error("Failed to load memories: \(error.localizedDescription)")
            memories = []
        }
    }

    private func saveMemories() {
        do {
            let data = try JSONEncoder().encode(memories)
            try data.write(to: memoryFileURL, options: .atomic)
        } catch {
            logger.error("Failed to save memories: \(error.localizedDescription)")
        }
    }
}

// MARK: - Memory Record (File-based, not SwiftData)

public struct OmniMemoryRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public var type: OmniMemoryType
    public var category: String
    public var key: String
    public var value: String
    public var confidence: Double
    public var source: OmniMemorySource
    public var timestamp: Date
    public var lastAccessed: Date
    public var accessCount: Int
    public var metadata: Data?

    public init(
        id: UUID = UUID(),
        type: OmniMemoryType,
        category: String,
        key: String,
        value: String,
        confidence: Double = 1.0,
        source: OmniMemorySource = .explicit,
        metadata: Data? = nil
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.key = key
        self.value = value
        self.confidence = confidence
        self.source = source
        self.timestamp = Date()
        self.lastAccessed = Date()
        self.accessCount = 0
        self.metadata = metadata
    }
}

// MARK: - Supporting Types (Prefixed with Omni to avoid conflicts)

public enum OmniMemoryType: String, Codable, Sendable {
    case semantic    // Learned facts and patterns
    case episodic    // Specific experiences
    case procedural  // How to do things
    case prospective // Future intentions
}

public enum OmniMemorySource: String, Codable, Sendable {
    case explicit    // User explicitly stated
    case inferred    // THEA inferred from behavior
    case system      // System-generated
}

public enum OmniMemoryPriority: String, Codable {
    case low
    case normal
    case high
    case critical
}

public enum OmniSemanticCategory: String, Codable {
    case userPreference
    case taskPattern
    case modelPerformance
    case workflowOptimization
    case contextAssociation
    case personality
}

public enum OmniPreferenceCategory: String, Codable {
    case responseStyle    // verbose, concise, technical
    case modelSelection   // preferred models by task
    case timing           // when user prefers certain activities
    case communication    // tone, formality
    case privacy          // what to share/not share
}

// MARK: - Memory Trigger Conditions

/// Trigger condition for prospective memory evaluation
public enum MemoryTriggerCondition: Codable, CustomStringConvertible {
    case time(Date)
    case location(String)
    case activity(String)
    case appLaunch(String)
    case keyword(String)
    case contextMatch(String)

    public var description: String {
        switch self {
        case .time(let date): return "At \(date)"
        case .location(let loc): return "At location: \(loc)"
        case .activity(let act): return "During activity: \(act)"
        case .appLaunch(let app): return "When \(app) opens"
        case .keyword(let kw): return "When mentioned: \(kw)"
        case .contextMatch(let ctx): return "When context matches: \(ctx)"
        }
    }

    public func isSatisfied(by context: MemoryContextSnapshot) -> Bool {
        switch self {
        case .time(let date):
            return Date() >= date
        case .activity(let activity):
            return context.userActivity?.lowercased().contains(activity.lowercased()) ?? false
        case .keyword(let keyword):
            return context.currentQuery?.lowercased().contains(keyword.lowercased()) ?? false
        default:
            return false
        }
    }
}

// MARK: - Memory Context Snapshot (for trigger evaluation)

/// Lightweight context snapshot for memory trigger evaluation
public struct MemoryContextSnapshot: Sendable {
    public var userActivity: String?
    public var currentQuery: String?
    public var location: String?
    public var timeOfDay: Int  // Hour 0-23
    public var dayOfWeek: Int  // 1-7
    public var batteryLevel: Int?
    public var isPluggedIn: Bool?

    public init(
        userActivity: String? = nil,
        currentQuery: String? = nil,
        location: String? = nil,
        timeOfDay: Int = Calendar.current.component(.hour, from: Date()),
        dayOfWeek: Int = Calendar.current.component(.weekday, from: Date()),
        batteryLevel: Int? = nil,
        isPluggedIn: Bool? = nil
    ) {
        self.userActivity = userActivity
        self.currentQuery = currentQuery
        self.location = location
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.batteryLevel = batteryLevel
        self.isPluggedIn = isPluggedIn
    }
}

// MARK: - Memory Detected Pattern

/// Pattern detected from memory analysis
public struct MemoryDetectedPattern: Sendable {
    public let event: String
    public let frequency: Int
    public let hourOfDay: Int
    public let dayOfWeek: Int
    public let confidence: Double

    public var description: String {
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dayName = dayOfWeek >= 1 && dayOfWeek <= 7 ? dayNames[dayOfWeek] : "?"
        return "\(event) typically occurs at \(hourOfDay):00 on \(dayName)s (\(Int(confidence * 100))% confidence)"
    }
}

// MARK: - Memory Stats

public struct OmniMemoryStats: Sendable, CustomStringConvertible {
    public var semanticCount: Int = 0
    public var episodicCount: Int = 0
    public var proceduralCount: Int = 0
    public var prospectiveCount: Int = 0
    public var cacheSize: Int = 0
    public var lastConsolidation: Date?

    public var totalCount: Int {
        semanticCount + episodicCount + proceduralCount + prospectiveCount
    }

    public var description: String {
        "OmniMemoryStats(total: \(totalCount), semantic: \(semanticCount), episodic: \(episodicCount), procedural: \(proceduralCount), prospective: \(prospectiveCount), cache: \(cacheSize))"
    }
}

// MARK: - Metadata Types

struct OmniEpisodicMetadata: Codable {
    let outcome: String?
    let emotionalValence: Double

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(_ data: Data?) -> OmniEpisodicMetadata? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(OmniEpisodicMetadata.self, from: data)
    }
}

struct OmniProceduralMetadata: Codable {
    var successRate: Double
    var averageDuration: TimeInterval
    var executionCount: Int

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(_ data: Data?) -> OmniProceduralMetadata? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(OmniProceduralMetadata.self, from: data)
    }
}

struct OmniProspectiveMetadata: Codable {
    let triggerCondition: MemoryTriggerCondition
    var isTriggered: Bool

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(_ data: Data?) -> OmniProspectiveMetadata? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(OmniProspectiveMetadata.self, from: data)
    }
}

// MARK: - Memory Importance Weights

/// Weights for calculating memory importance
struct MemoryImportanceWeights {
    /// Weight for recency (how recently the memory was accessed)
    var recency: Double = 0.25

    /// Weight for frequency (how often the memory was accessed)
    var frequency: Double = 0.20

    /// Weight for confidence (how confident we are in the memory)
    var confidence: Double = 0.30

    /// Weight for source credibility
    var source: Double = 0.15

    /// Weight for user feedback (explicit corrections)
    var feedback: Double = 0.10
}

// MARK: - Memory Health Report

/// Report on memory system health
public struct MemoryHealthReport: Sendable {
    public let totalMemories: Int
    public let memoriesByType: [OmniMemoryType: Int]
    public let averageConfidence: Double
    public let memoriesAtRisk: Int // Below minimum retention threshold
    public let oldestMemoryAge: TimeInterval
    public let mostAccessedCategory: String?
    public let suggestedActions: [String]

    public var healthScore: Double {
        // Calculate overall health (0-1)
        var score = 0.0

        // Memory count factor (having memories is good, but not too many)
        let countScore = min(1.0, Double(totalMemories) / 1000.0) * 0.3
        score += countScore

        // Confidence factor
        score += averageConfidence * 0.4

        // Low risk factor
        let riskRatio = Double(memoriesAtRisk) / max(1, Double(totalMemories))
        score += (1.0 - riskRatio) * 0.3

        return score
    }
}

// MARK: - Memory Search Result

/// Result from semantic or keyword search
public struct MemorySearchResult: Identifiable, Sendable {
    public let id: UUID
    public let memory: OmniMemoryRecord
    public let relevanceScore: Double
    public let matchType: MemoryMatchType

    public enum MemoryMatchType: String, Sendable {
        case semantic    // Found via embedding similarity
        case keyword     // Found via keyword matching
        case exact       // Exact key match
    }
}
