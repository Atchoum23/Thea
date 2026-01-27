import Foundation
@preconcurrency import SwiftData

// MARK: - Memory System

// Advanced multi-tier memory architecture with consolidation, retrieval, and decay

@MainActor
@Observable
final class MemorySystem {
    static let shared = MemorySystem()

    // Memory stores
    private(set) var shortTermMemory: [Memory] = []
    private(set) var longTermMemory: [Memory] = []
    private(set) var episodicMemory: [EpisodicMemory] = []
    private(set) var semanticMemory: [SemanticMemory] = []
    private(set) var proceduralMemory: [ProceduralMemory] = []

    // Configuration accessor
    private var config: MemoryConfiguration {
        AppConfiguration.shared.memoryConfig
    }

    private var providerConfig: ProviderConfiguration {
        AppConfiguration.shared.providerConfig
    }

    private init() {
        Task {
            await startConsolidationTimer()
        }
    }

    // MARK: - Memory Creation

    func addShortTermMemory(content: String, type: MemoryType, metadata: [String: String] = [:]) async throws -> Memory {
        let embedding = try await generateEmbedding(for: content)

        let memory = Memory(
            id: UUID(),
            content: content,
            type: type,
            tier: .shortTerm,
            importance: calculateImportance(content: content, type: type),
            embedding: embedding,
            metadata: metadata,
            createdAt: Date(),
            lastAccessed: Date(),
            accessCount: 0
        )

        shortTermMemory.append(memory)

        // Prune if exceeding capacity
        if shortTermMemory.count > config.shortTermCapacity {
            try await consolidateOldestMemories()
        }

        return memory
    }

    func addEpisodicMemory(event: String, context: String, participants: [String] = [], metadata: [String: String] = [:]) async throws -> EpisodicMemory {
        let embedding = try await generateEmbedding(for: event)

        let episodic = EpisodicMemory(
            id: UUID(),
            event: event,
            context: context,
            participants: participants,
            embedding: embedding,
            metadata: metadata,
            timestamp: Date(),
            lastAccessed: Date(),
            importance: calculateImportance(content: event, type: .episodic)
        )

        episodicMemory.append(episodic)
        return episodic
    }

    func addSemanticMemory(concept: String, definition: String, relatedConcepts: [String] = [], metadata: [String: String] = [:]) async throws -> SemanticMemory {
        let embedding = try await generateEmbedding(for: "\(concept): \(definition)")

        let semantic = SemanticMemory(
            id: UUID(),
            concept: concept,
            definition: definition,
            relatedConcepts: relatedConcepts,
            embedding: embedding,
            metadata: metadata,
            createdAt: Date(),
            lastAccessed: Date(),
            importance: calculateImportance(content: definition, type: .semantic)
        )

        semanticMemory.append(semantic)
        return semantic
    }

    func addProceduralMemory(skill: String, steps: [String], conditions: [String] = [], metadata: [String: String] = [:]) async throws -> ProceduralMemory {
        let embedding = try await generateEmbedding(for: "\(skill): \(steps.joined(separator: " "))")

        let procedural = ProceduralMemory(
            id: UUID(),
            skill: skill,
            steps: steps,
            conditions: conditions,
            embedding: embedding,
            metadata: metadata,
            createdAt: Date(),
            lastAccessed: Date(),
            successRate: 0.0,
            importance: calculateImportance(content: skill, type: .procedural)
        )

        proceduralMemory.append(procedural)
        return procedural
    }

    // MARK: - Memory Retrieval

    func retrieveRelevantMemories(for query: String, limit: Int? = nil, threshold: Float? = nil) async throws -> [Memory] {
        let queryEmbedding = try await generateEmbedding(for: query)
        let actualLimit = limit ?? config.defaultRetrievalLimit
        let actualThreshold = threshold ?? config.defaultSimilarityThreshold

        // Search all memory tiers
        var allMemories: [Memory] = []
        allMemories.append(contentsOf: shortTermMemory)
        allMemories.append(contentsOf: longTermMemory)

        // Score by relevance
        let scored = allMemories.map { memory in
            let similarity = cosineSimilarity(queryEmbedding, memory.embedding)
            let importanceBoost = memory.importance * config.importanceBoostFactor
            let recencyBoost = calculateRecencyBoost(memory.lastAccessed)
            let accessBoost = Float(memory.accessCount) * config.accessBoostFactor

            let finalScore = similarity + importanceBoost + recencyBoost + accessBoost

            return (memory, finalScore)
        }.filter { $0.1 >= actualThreshold }

        // Sort and limit
        let sorted = scored.sorted { $0.1 > $1.1 }
        let top = sorted.prefix(actualLimit).map(\.0)

        // Update access statistics
        for memory in top {
            updateMemoryAccess(memory)
        }

        return top
    }

    func retrieveEpisodicMemories(for query: String, limit: Int? = nil, threshold: Float? = nil) async throws -> [EpisodicMemory] {
        let queryEmbedding = try await generateEmbedding(for: query)
        let actualLimit = limit ?? config.episodicRetrievalLimit
        let actualThreshold = threshold ?? config.defaultSimilarityThreshold

        let scored = episodicMemory.map { memory in
            let similarity = cosineSimilarity(queryEmbedding, memory.embedding)
            let recencyBoost = calculateRecencyBoost(memory.lastAccessed)
            let importanceBoost = memory.importance * config.importanceBoostFactor

            return (memory, similarity + recencyBoost + importanceBoost)
        }.filter { $0.1 >= actualThreshold }

        let sorted = scored.sorted { $0.1 > $1.1 }
        let top = sorted.prefix(actualLimit).map(\.0)

        // Update access
        for memory in top {
            updateEpisodicAccess(memory)
        }

        return top
    }

    func retrieveSemanticMemories(for concept: String, limit: Int? = nil, threshold: Float? = nil) async throws -> [SemanticMemory] {
        let queryEmbedding = try await generateEmbedding(for: concept)
        let actualLimit = limit ?? config.semanticRetrievalLimit
        let actualThreshold = threshold ?? config.defaultSimilarityThreshold

        let scored = semanticMemory.map { memory in
            let similarity = cosineSimilarity(queryEmbedding, memory.embedding)
            let importanceBoost = memory.importance * config.importanceBoostFactor

            return (memory, similarity + importanceBoost)
        }.filter { $0.1 >= actualThreshold }

        let sorted = scored.sorted { $0.1 > $1.1 }
        let top = sorted.prefix(actualLimit).map(\.0)

        // Update access
        for memory in top {
            updateSemanticAccess(memory)
        }

        return top
    }

    func retrieveProceduralMemories(for task: String, limit: Int? = nil, threshold: Float? = nil) async throws -> [ProceduralMemory] {
        let queryEmbedding = try await generateEmbedding(for: task)
        let actualLimit = limit ?? config.proceduralRetrievalLimit
        let actualThreshold = threshold ?? config.defaultSimilarityThreshold

        let scored = proceduralMemory.map { memory in
            let similarity = cosineSimilarity(queryEmbedding, memory.embedding)
            let successBoost = memory.successRate * 0.3
            let importanceBoost = memory.importance * config.importanceBoostFactor

            return (memory, similarity + successBoost + importanceBoost)
        }.filter { $0.1 >= actualThreshold }

        let sorted = scored.sorted { $0.1 > $1.1 }
        let top = sorted.prefix(actualLimit).map(\.0)

        // Update access
        for memory in top {
            updateProceduralAccess(memory)
        }

        return top
    }

    // MARK: - Memory Consolidation

    func consolidateOldestMemories() async throws {
        let now = Date()

        // Find memories older than threshold
        let toConsolidate = shortTermMemory.filter { memory in
            now.timeIntervalSince(memory.createdAt) > config.consolidationThresholdSeconds
        }

        for memory in toConsolidate {
            // Move to long-term with importance-based filtering
            if memory.importance > config.consolidationMinImportance {
                var consolidated = memory
                consolidated.tier = .longTerm
                longTermMemory.append(consolidated)
            }

            // Remove from short-term
            shortTermMemory.removeAll { $0.id == memory.id }
        }
    }

    func consolidateAllShortTerm() async throws {
        for memory in shortTermMemory {
            if memory.importance > config.consolidationMinImportance {
                var consolidated = memory
                consolidated.tier = .longTerm
                longTermMemory.append(consolidated)
            }
        }

        shortTermMemory.removeAll()
    }

    // MARK: - Memory Decay

    func applyMemoryDecay() async {
        let now = Date()

        // Decay long-term memories based on last access
        for i in 0 ..< longTermMemory.count {
            let daysSinceAccess = now.timeIntervalSince(longTermMemory[i].lastAccessed) / 86400
            let decayFactor = pow(config.generalDecayRate, Float(daysSinceAccess))

            longTermMemory[i].importance *= decayFactor

            // Remove if importance drops too low
            if longTermMemory[i].importance < config.minImportanceThreshold {
                longTermMemory.remove(at: i)
            }
        }

        // Decay episodic memories
        for i in 0 ..< episodicMemory.count {
            let daysSinceAccess = now.timeIntervalSince(episodicMemory[i].lastAccessed) / 86400
            let decayFactor = pow(config.generalDecayRate, Float(daysSinceAccess))

            episodicMemory[i].importance *= decayFactor

            if episodicMemory[i].importance < config.minImportanceThreshold {
                episodicMemory.remove(at: i)
            }
        }

        // Semantic memories decay more slowly
        for i in 0 ..< semanticMemory.count {
            let daysSinceAccess = now.timeIntervalSince(semanticMemory[i].lastAccessed) / 86400
            let decayFactor = pow(config.semanticDecayRate, Float(daysSinceAccess))

            semanticMemory[i].importance *= decayFactor

            if semanticMemory[i].importance < config.minImportanceThreshold {
                semanticMemory.remove(at: i)
            }
        }
    }

    // MARK: - Memory Linking

    func linkMemories(memory1: UUID, memory2: UUID, linkType: MemoryLinkType) {
        // Create bidirectional link
        if let index1 = longTermMemory.firstIndex(where: { $0.id == memory1 }) {
            longTermMemory[index1].links.append(MemoryLink(targetID: memory2, type: linkType))
        }

        if let index2 = longTermMemory.firstIndex(where: { $0.id == memory2 }) {
            longTermMemory[index2].links.append(MemoryLink(targetID: memory1, type: linkType))
        }
    }

    func findLinkedMemories(for memoryID: UUID) -> [Memory] {
        guard let memory = longTermMemory.first(where: { $0.id == memoryID }) else {
            return []
        }

        let linkedIDs = memory.links.map(\.targetID)
        return longTermMemory.filter { linkedIDs.contains($0.id) }
    }

    // MARK: - Memory Summarization

    func summarizeMemories(memories: [Memory]) async throws -> String {
        let contents = memories.map(\.content).joined(separator: "\n")

        // Use AI to generate summary
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw MemoryError.providerNotAvailable
        }

        let summaryPrompt = """
        Summarize the following memories into a concise overview:

        \(contents)

        Provide a coherent summary highlighting the key themes and insights.
        """

        let summarizationModel = providerConfig.defaultSummarizationModel

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(summaryPrompt),
            timestamp: Date(),
            model: summarizationModel
        )

        var summary = ""
        let stream = try await provider.chat(messages: [message], model: summarizationModel, stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text):
                summary += text
            case .complete:
                break
            case let .error(error):
                throw error
            }
        }

        return summary
    }

    func compressMemories(threshold: Float? = nil) async throws {
        let actualThreshold = threshold ?? config.compressionSimilarityThreshold

        // Find similar memories and merge them
        var toRemove: Set<UUID> = []

        for i in 0 ..< longTermMemory.count {
            if toRemove.contains(longTermMemory[i].id) { continue }

            for j in (i + 1) ..< longTermMemory.count {
                if toRemove.contains(longTermMemory[j].id) { continue }

                let similarity = cosineSimilarity(longTermMemory[i].embedding, longTermMemory[j].embedding)

                if similarity > actualThreshold {
                    // Merge memories
                    let merged = """
                    \(longTermMemory[i].content)

                    Related: \(longTermMemory[j].content)
                    """

                    let mergedImportance = max(longTermMemory[i].importance, longTermMemory[j].importance)

                    longTermMemory[i].content = merged
                    longTermMemory[i].importance = mergedImportance

                    toRemove.insert(longTermMemory[j].id)
                }
            }
        }

        // Remove merged memories
        longTermMemory.removeAll { toRemove.contains($0.id) }
    }

    // MARK: - Helper Methods

    private func calculateImportance(content: String, type: MemoryType) -> Float {
        var importance: Float = 0.5

        // Type-based baseline
        switch type {
        case .episodic:
            importance = 0.7
        case .semantic:
            importance = 0.8
        case .procedural:
            importance = 0.9
        case .factual:
            importance = 0.6
        case .contextual:
            importance = 0.5
        }

        // Boost for length (more detailed = more important)
        let wordCount = content.split(separator: " ").count
        if wordCount > 50 {
            importance += 0.1
        }

        // Boost for specific keywords from configuration
        for keyword in config.importantKeywords {
            if content.lowercased().contains(keyword) {
                importance += 0.05
            }
        }

        return min(importance, 1.0)
    }

    private func calculateRecencyBoost(_ lastAccessed: Date) -> Float {
        let hoursSinceAccess = Date().timeIntervalSince(lastAccessed) / 3600

        // Exponential decay
        let boost = Float(exp(-hoursSinceAccess / 24))
        return boost * config.recencyBoostMax
    }

    private func updateMemoryAccess(_ memory: Memory) {
        if let index = shortTermMemory.firstIndex(where: { $0.id == memory.id }) {
            shortTermMemory[index].lastAccessed = Date()
            shortTermMemory[index].accessCount += 1
        } else if let index = longTermMemory.firstIndex(where: { $0.id == memory.id }) {
            longTermMemory[index].lastAccessed = Date()
            longTermMemory[index].accessCount += 1

            // Boost importance on access
            longTermMemory[index].importance = min(longTermMemory[index].importance * config.accessImportanceBoost, 1.0)
        }
    }

    private func updateEpisodicAccess(_ memory: EpisodicMemory) {
        if let index = episodicMemory.firstIndex(where: { $0.id == memory.id }) {
            episodicMemory[index].lastAccessed = Date()
            episodicMemory[index].importance = min(episodicMemory[index].importance * config.accessImportanceBoost, 1.0)
        }
    }

    private func updateSemanticAccess(_ memory: SemanticMemory) {
        if let index = semanticMemory.firstIndex(where: { $0.id == memory.id }) {
            semanticMemory[index].lastAccessed = Date()
            semanticMemory[index].importance = min(semanticMemory[index].importance * config.accessImportanceBoost, 1.0)
        }
    }

    private func updateProceduralAccess(_ memory: ProceduralMemory) {
        if let index = proceduralMemory.firstIndex(where: { $0.id == memory.id }) {
            proceduralMemory[index].lastAccessed = Date()
            proceduralMemory[index].importance = min(proceduralMemory[index].importance * config.accessImportanceBoost, 1.0)
        }
    }

    private func generateEmbedding(for text: String) async throws -> [Float] {
        // Use OpenAI embeddings API
        guard let apiKey = SettingsManager.shared.getAPIKey(for: "openai") else {
            throw MemoryError.apiKeyMissing
        }

        let embeddingURL = "\(providerConfig.openAIBaseURL)/embeddings"
        guard let url = URL(string: embeddingURL) else {
            throw MemoryError.embeddingGenerationFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": providerConfig.defaultEmbeddingModel,
            "input": text
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(EmbeddingResponse.self, from: data)

        return response.data.first?.embedding ?? []
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0, magnitudeB > 0 else { return 0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }

    private func startConsolidationTimer() async {
        let consolidationInterval = UInt64(AppConfiguration.shared.agentConfig.consolidationIntervalSeconds * 1_000_000_000)

        while true {
            try? await Task.sleep(nanoseconds: consolidationInterval)

            try? await consolidateOldestMemories()

            // Apply decay every hour
            let hour = Calendar.current.component(.hour, from: Date())
            if hour == 0 { // Midnight
                await applyMemoryDecay()
            }
        }
    }
}

// MARK: - Memory Models

struct Memory: Identifiable, Codable, Sendable {
    let id: UUID
    var content: String
    let type: MemoryType
    var tier: MemoryTier
    var importance: Float
    let embedding: [Float]
    var metadata: [String: String]
    let createdAt: Date
    var lastAccessed: Date
    var accessCount: Int
    var links: [MemoryLink] = []
}

struct EpisodicMemory: Identifiable, Codable, Sendable {
    let id: UUID
    let event: String
    let context: String
    let participants: [String]
    let embedding: [Float]
    var metadata: [String: String]
    let timestamp: Date
    var lastAccessed: Date
    var importance: Float
}

struct SemanticMemory: Identifiable, Codable, Sendable {
    let id: UUID
    let concept: String
    let definition: String
    let relatedConcepts: [String]
    let embedding: [Float]
    var metadata: [String: String]
    let createdAt: Date
    var lastAccessed: Date
    var importance: Float
}

struct ProceduralMemory: Identifiable, Codable, Sendable {
    let id: UUID
    let skill: String
    let steps: [String]
    let conditions: [String]
    let embedding: [Float]
    var metadata: [String: String]
    let createdAt: Date
    var lastAccessed: Date
    var successRate: Float
    var importance: Float
}

struct MemoryLink: Codable, Sendable {
    let targetID: UUID
    let type: MemoryLinkType
}

enum MemoryType: String, Codable, Sendable {
    case episodic = "Episodic"
    case semantic = "Semantic"
    case procedural = "Procedural"
    case factual = "Factual"
    case contextual = "Contextual"
}

enum MemoryTier: String, Codable, Sendable {
    case shortTerm = "Short-Term"
    case longTerm = "Long-Term"
}

enum MemoryLinkType: String, Codable, Sendable {
    case relatedTo = "Related To"
    case causedBy = "Caused By"
    case leads = "Leads To"
    case contradicts = "Contradicts"
    case supports = "Supports"
}

enum MemoryError: LocalizedError {
    case apiKeyMissing
    case providerNotAvailable
    case embeddingGenerationFailed

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            "API key is missing for embedding generation"
        case .providerNotAvailable:
            "AI provider is not available"
        case .embeddingGenerationFailed:
            "Failed to generate embedding"
        }
    }
}

// MARK: - Embedding Response

private struct EmbeddingResponse: Codable {
    let data: [EmbeddingData]
}

private struct EmbeddingData: Codable {
    let embedding: [Float]
}
