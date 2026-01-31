// CollaborativeMemorySystem.swift
// Advanced memory system for multi-context, cross-session learning
// Implements collaborative memory patterns for human-AI interaction
//
// References:
// - Contextual Memory Intelligence (CMI) framework
// - Model Context Protocol (MCP) for context sharing
// - Multi-Agent memory sharing patterns

import Foundation

// MARK: - Collaborative Memory System

/// Advanced memory system that learns across sessions and contexts
/// Implements collaborative memory for enhanced human-AI interaction
@MainActor
@Observable
final class CollaborativeMemorySystem {
    static let shared = CollaborativeMemorySystem()

    // MARK: - State

    private(set) var shortTermMemory: [MemoryFragment] = []
    private(set) var longTermMemory: [ConsolidatedMemory] = []
    private(set) var contextualMemory: [ContextMemory] = []
    private(set) var semanticIndex = SemanticIndex()
    private(set) var memoryHealth = MemoryHealth()
    private(set) var activeContexts: [ContextIdentifier] = []

    // Configuration
    private(set) var configuration = Configuration()

    struct Configuration: Codable, Sendable {
        var shortTermCapacity: Int = 100
        var longTermCapacity: Int = 10000
        var consolidationThreshold: Int = 10 // Memories repeated N times get consolidated
        var decayRate: Double = 0.05 // How quickly unused memories fade
        var enableSemanticIndexing = true
        var enableCrossContextLearning = true
        var enableMemoryConsolidation = true
        var privacyLevel: PrivacyLevel = .standard
        var enableSharedMemory = false // For multi-agent scenarios
        var maxContextDepth: Int = 5

        enum PrivacyLevel: String, Codable, Sendable, CaseIterable {
            case minimal = "Minimal (Session only)"
            case standard = "Standard (Persistent, local)"
            case enhanced = "Enhanced (Encrypted persistent)"
        }
    }

    // MARK: - Memory Types

    struct MemoryFragment: Identifiable, Codable, Sendable {
        let id: UUID
        let content: String
        let embedding: [Float]?
        let timestamp: Date
        let context: ContextIdentifier
        let source: MemorySource
        let associations: [UUID]
        var accessCount: Int
        var lastAccessed: Date
        var importance: Double
        var decayScore: Double

        init(
            content: String,
            embedding: [Float]? = nil,
            context: ContextIdentifier,
            source: MemorySource,
            importance: Double = 0.5
        ) {
            self.id = UUID()
            self.content = content
            self.embedding = embedding
            self.timestamp = Date()
            self.context = context
            self.source = source
            self.associations = []
            self.accessCount = 1
            self.lastAccessed = Date()
            self.importance = importance
            self.decayScore = 1.0
        }
    }

    struct ConsolidatedMemory: Identifiable, Codable, Sendable {
        let id: UUID
        let pattern: String
        let variants: [String]
        let embedding: [Float]
        let firstSeen: Date
        var lastSeen: Date
        var frequency: Int
        var reliability: Double
        var contexts: [ContextIdentifier]
        var relatedConcepts: [String]
        var userCorrections: Int

        init(from fragments: [MemoryFragment]) {
            self.id = UUID()
            self.pattern = fragments.first?.content ?? ""
            self.variants = fragments.map { $0.content }
            self.embedding = fragments.first?.embedding ?? []
            self.firstSeen = fragments.map { $0.timestamp }.min() ?? Date()
            self.lastSeen = fragments.map { $0.timestamp }.max() ?? Date()
            self.frequency = fragments.count
            self.reliability = Double(fragments.count) / 10.0
            self.contexts = Array(Set(fragments.map { $0.context }))
            self.relatedConcepts = []
            self.userCorrections = 0
        }
    }

    struct ContextMemory: Identifiable, Codable, Sendable {
        let id: UUID
        let context: ContextIdentifier
        var memories: [UUID] // References to MemoryFragments
        var sessionStart: Date
        var lastActivity: Date
        var activityCount: Int
        var dominantIntent: String?
        var userMood: String?
        var topicProgression: [String]

        init(context: ContextIdentifier) {
            self.id = UUID()
            self.context = context
            self.memories = []
            self.sessionStart = Date()
            self.lastActivity = Date()
            self.activityCount = 0
            self.dominantIntent = nil
            self.userMood = nil
            self.topicProgression = []
        }
    }

    struct ContextIdentifier: Hashable, Codable, Sendable {
        let sessionId: String
        let projectId: String?
        let topicId: String?

        static var current: ContextIdentifier {
            ContextIdentifier(
                sessionId: UUID().uuidString,
                projectId: nil,
                topicId: nil
            )
        }
    }

    enum MemorySource: String, Codable, Sendable {
        case userInput = "User Input"
        case aiResponse = "AI Response"
        case interaction = "Interaction"
        case feedback = "User Feedback"
        case inference = "Inferred"
        case external = "External Source"
    }

    struct MemoryHealth: Codable, Sendable {
        var shortTermUtilization: Double = 0
        var longTermUtilization: Double = 0
        var indexHealth: Double = 1.0
        var lastConsolidation: Date?
        var lastCleanup: Date?
        var fragmentationScore: Double = 0
        var retrievalAccuracy: Double = 1.0
    }

    // MARK: - Initialization

    private init() {
        loadMemory()
        loadConfiguration()
        scheduleMaintenanceTasks()
    }

    // MARK: - Memory Operations

    /// Store a new memory fragment
    func store(_ content: String, source: MemorySource, importance: Double = 0.5) async {
        let context = activeContexts.last ?? .current

        // Generate semantic embedding (simplified - would use ML model in production)
        let embedding = await generateEmbedding(for: content)

        let fragment = MemoryFragment(
            content: content,
            embedding: embedding,
            context: context,
            source: source,
            importance: importance
        )

        // Check for similar memories (future: use for associations)
        _ = await findSimilar(to: content, limit: 5)

        shortTermMemory.append(fragment)

        // Update context memory
        updateContextMemory(with: fragment)

        // Check if short-term memory needs consolidation
        if shortTermMemory.count > configuration.shortTermCapacity {
            await consolidateMemories()
        }

        // Update semantic index
        if configuration.enableSemanticIndexing {
            semanticIndex.index(fragment)
        }

        updateMemoryHealth()
        saveMemory()
    }

    /// Retrieve relevant memories for a query
    func retrieve(for query: String, limit: Int = 10) async -> [MemoryFragment] {
        var results: [MemoryFragment] = []

        // Search semantic index first
        if configuration.enableSemanticIndexing {
            let embedding = await generateEmbedding(for: query)
            results = semanticIndex.search(embedding: embedding, limit: limit)
        }

        // Fall back to keyword matching
        if results.isEmpty {
            results = shortTermMemory.filter { memory in
                memory.content.lowercased().contains(query.lowercased())
            }
        }

        // Include consolidated memories
        let consolidatedResults = longTermMemory.filter { memory in
            memory.pattern.lowercased().contains(query.lowercased()) ||
            memory.variants.contains { $0.lowercased().contains(query.lowercased()) }
        }.flatMap { consolidated -> [MemoryFragment] in
            // Convert consolidated memory back to fragments for consistent interface
            [MemoryFragment(
                content: consolidated.pattern,
                embedding: consolidated.embedding,
                context: consolidated.contexts.first ?? .current,
                source: .inference,
                importance: consolidated.reliability
            )]
        }

        results.append(contentsOf: consolidatedResults)

        // Update access counts
        for i in results.indices {
            var updated = results[i]
            updated.accessCount += 1
            updated.lastAccessed = Date()
            results[i] = updated
        }

        // Sort by relevance (access count * importance / decay)
        results.sort { (Double($0.accessCount) * $0.importance) > (Double($1.accessCount) * $1.importance) }

        return Array(results.prefix(limit))
    }

    /// Find memories similar to given content
    func findSimilar(to content: String, limit: Int = 5) async -> [MemoryFragment] {
        let embedding = await generateEmbedding(for: content)

        if configuration.enableSemanticIndexing {
            return semanticIndex.search(embedding: embedding, limit: limit)
        }

        // Fallback: simple keyword overlap
        let words = Set(content.lowercased().split(separator: " ").map { String($0) })

        return shortTermMemory.filter { memory in
            let memoryWords = Set(memory.content.lowercased().split(separator: " ").map { String($0) })
            let overlap = words.intersection(memoryWords)
            return overlap.count > 1
        }.prefix(limit).map { $0 }
    }

    /// Get context for current session
    func getCurrentContext() -> ContextMemory? {
        guard let contextId = activeContexts.last else { return nil }
        return contextualMemory.first { $0.context == contextId }
    }

    /// Start a new context/session
    func startContext(projectId: String? = nil, topicId: String? = nil) {
        let context = ContextIdentifier(
            sessionId: UUID().uuidString,
            projectId: projectId,
            topicId: topicId
        )

        activeContexts.append(context)

        let contextMemory = ContextMemory(context: context)
        self.contextualMemory.append(contextMemory)

        if activeContexts.count > configuration.maxContextDepth {
            activeContexts.removeFirst()
        }
    }

    /// End current context
    func endContext() {
        guard !activeContexts.isEmpty else { return }
        activeContexts.removeLast()
    }

    // MARK: - Memory Consolidation

    /// Consolidate short-term memories into long-term patterns
    private func consolidateMemories() async {
        guard configuration.enableMemoryConsolidation else { return }

        // Group similar memories
        var clusters: [[MemoryFragment]] = []
        var processed = Set<UUID>()

        for memory in shortTermMemory where !processed.contains(memory.id) {
            var cluster = [memory]
            processed.insert(memory.id)

            let similar = await findSimilar(to: memory.content, limit: 10)
            for sim in similar where !processed.contains(sim.id) {
                cluster.append(sim)
                processed.insert(sim.id)
            }

            if cluster.count >= configuration.consolidationThreshold {
                clusters.append(cluster)
            }
        }

        // Create consolidated memories from clusters
        for cluster in clusters {
            let consolidated = ConsolidatedMemory(from: cluster)
            longTermMemory.append(consolidated)

            // Remove consolidated fragments from short-term memory
            shortTermMemory.removeAll { fragment in
                cluster.contains { $0.id == fragment.id }
            }
        }

        // Trim long-term memory if needed
        if longTermMemory.count > configuration.longTermCapacity {
            // Remove least reliable and oldest memories
            longTermMemory.sort { $0.reliability * Double($0.frequency) > $1.reliability * Double($1.frequency) }
            longTermMemory = Array(longTermMemory.prefix(configuration.longTermCapacity))
        }

        memoryHealth.lastConsolidation = Date()
        updateMemoryHealth()
        saveMemory()
    }

    // MARK: - Memory Decay

    /// Apply decay to memories based on usage
    private func applyDecay() {
        let now = Date()

        for i in shortTermMemory.indices {
            let timeSinceAccess = now.timeIntervalSince(shortTermMemory[i].lastAccessed)
            let decayFactor = exp(-configuration.decayRate * timeSinceAccess / 3600) // Hourly decay
            shortTermMemory[i].decayScore *= decayFactor
        }

        // Remove fully decayed memories
        shortTermMemory.removeAll { $0.decayScore < 0.1 }

        memoryHealth.lastCleanup = Date()
        updateMemoryHealth()
    }

    // MARK: - Semantic Operations

    /// Generate semantic embedding for content
    private func generateEmbedding(for content: String) async -> [Float] {
        // Simplified embedding generation
        // In production, use a sentence transformer model

        let words = content.lowercased().split(separator: " ")
        var embedding = [Float](repeating: 0, count: 128)

        for (index, word) in words.enumerated() {
            let hash = word.hashValue
            let position = abs(hash) % 128
            embedding[position] += Float(1.0 / Double(index + 1))
        }

        // Normalize
        let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if norm > 0 {
            embedding = embedding.map { $0 / norm }
        }

        return embedding
    }

    // MARK: - Context Management

    private func updateContextMemory(with fragment: MemoryFragment) {
        guard let index = contextualMemory.firstIndex(where: { $0.context == fragment.context }) else {
            return
        }

        contextualMemory[index].memories.append(fragment.id)
        contextualMemory[index].lastActivity = Date()
        contextualMemory[index].activityCount += 1

        // Extract topic from content (simplified)
        let words = fragment.content.split(separator: " ").prefix(3).map { String($0) }
        if let topic = words.first, !contextualMemory[index].topicProgression.contains(topic) {
            contextualMemory[index].topicProgression.append(topic)
        }
    }

    // MARK: - Maintenance

    private func scheduleMaintenanceTasks() {
        // Schedule periodic consolidation
        Task {
            while true {
                try? await Task.sleep(for: .seconds(1800)) // 30 minutes
                await consolidateMemories()
                applyDecay()
            }
        }
    }

    private func updateMemoryHealth() {
        memoryHealth.shortTermUtilization = Double(shortTermMemory.count) / Double(configuration.shortTermCapacity)
        memoryHealth.longTermUtilization = Double(longTermMemory.count) / Double(configuration.longTermCapacity)

        // Calculate fragmentation
        let uniqueContexts = Set(shortTermMemory.map { $0.context })
        memoryHealth.fragmentationScore = Double(uniqueContexts.count) / Double(max(1, shortTermMemory.count))
    }

    // MARK: - Configuration

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        saveConfiguration()
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "CollaborativeMemory.config"),
           let config = try? JSONDecoder().decode(Configuration.self, from: data) {
            configuration = config
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "CollaborativeMemory.config")
        }
    }

    // MARK: - Persistence

    private func loadMemory() {
        if let data = UserDefaults.standard.data(forKey: "CollaborativeMemory.shortTerm"),
           let memories = try? JSONDecoder().decode([MemoryFragment].self, from: data) {
            shortTermMemory = memories
        }

        if let data = UserDefaults.standard.data(forKey: "CollaborativeMemory.longTerm"),
           let memories = try? JSONDecoder().decode([ConsolidatedMemory].self, from: data) {
            longTermMemory = memories
        }

        if let data = UserDefaults.standard.data(forKey: "CollaborativeMemory.context"),
           let memories = try? JSONDecoder().decode([ContextMemory].self, from: data) {
            contextualMemory = memories
        }

        // Rebuild semantic index
        if configuration.enableSemanticIndexing {
            for memory in shortTermMemory {
                semanticIndex.index(memory)
            }
        }
    }

    private func saveMemory() {
        if let data = try? JSONEncoder().encode(shortTermMemory) {
            UserDefaults.standard.set(data, forKey: "CollaborativeMemory.shortTerm")
        }

        if let data = try? JSONEncoder().encode(longTermMemory) {
            UserDefaults.standard.set(data, forKey: "CollaborativeMemory.longTerm")
        }

        if let data = try? JSONEncoder().encode(contextualMemory) {
            UserDefaults.standard.set(data, forKey: "CollaborativeMemory.context")
        }
    }
}

// MARK: - Semantic Index

/// Simple semantic index for memory retrieval
struct SemanticIndex: Codable, Sendable {
    private var entries: [UUID: [Float]] = [:]
    private var memoryCache: [UUID: CollaborativeMemorySystem.MemoryFragment] = [:]

    mutating func index(_ memory: CollaborativeMemorySystem.MemoryFragment) {
        guard let embedding = memory.embedding else { return }
        entries[memory.id] = embedding
        memoryCache[memory.id] = memory
    }

    func search(embedding: [Float], limit: Int) -> [CollaborativeMemorySystem.MemoryFragment] {
        var scores: [(UUID, Double)] = []

        for (id, storedEmbedding) in entries {
            let similarity = cosineSimilarity(embedding, storedEmbedding)
            scores.append((id, similarity))
        }

        scores.sort { $0.1 > $1.1 }

        return scores.prefix(limit).compactMap { memoryCache[$0.0] }
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? Double(dot / denominator) : 0
    }
}
