// ActiveMemoryRetrieval.swift
// Thea
//
// AI-powered active memory retrieval system
// Dynamically injects relevant context from all memory tiers into conversations

import Foundation
import OSLog

// MARK: - Active Memory Retrieval System

/// AI-powered system for proactively retrieving and injecting relevant memory into conversations
@MainActor
public final class ActiveMemoryRetrieval {
    public static let shared = ActiveMemoryRetrieval()

    private let logger = Logger(subsystem: "com.thea.ai", category: "ActiveMemoryRetrieval")

    // Configuration
    public var config = RetrievalConfig()

    // Statistics
    private var retrievalStats = RetrievalStatistics()

    private init() {}

    // MARK: - Public API

    /// Retrieve all relevant context for a query using AI-powered semantic search
    public func retrieveContext(
        for query: String,
        conversationId: UUID? = nil,
        projectId: UUID? = nil,
        taskType: TaskType? = nil
    ) async -> ActiveRetrievalResult {
        logger.info("Retrieving active context for query")

        let startTime = Date()
        var sources: [RetrievalSource] = []
        var totalConfidence: Double = 0.0

        // 1. Retrieve from multi-tier memory system
        if config.enableMemorySystemRetrieval {
            let memoryResult = await retrieveFromMemorySystem(query: query)
            sources.append(contentsOf: memoryResult.sources)
            totalConfidence += memoryResult.averageConfidence * config.memorySystemWeight
        }

        // 2. Retrieve from conversation memory
        if config.enableConversationMemory {
            let conversationResult = await retrieveFromConversationMemory(
                query: query,
                projectId: projectId
            )
            sources.append(contentsOf: conversationResult.sources)
            totalConfidence += conversationResult.averageConfidence * config.conversationWeight
        }

        // 3. Retrieve from knowledge graph
        if config.enableKnowledgeGraph {
            let knowledgeResult = await retrieveFromKnowledgeGraph(query: query)
            sources.append(contentsOf: knowledgeResult.sources)
            totalConfidence += knowledgeResult.averageConfidence * config.knowledgeGraphWeight
        }

        // 4. Retrieve from event history (recent actions/errors)
        if config.enableEventHistory {
            let eventResult = await retrieveFromEventHistory(
                query: query,
                conversationId: conversationId
            )
            sources.append(contentsOf: eventResult.sources)
            totalConfidence += eventResult.averageConfidence * config.eventHistoryWeight
        }

        // 5. AI-powered relevance ranking
        let rankedSources = await rankSourcesByRelevance(
            sources: sources,
            query: query,
            taskType: taskType
        )

        // 6. Deduplicate and limit
        let finalSources = deduplicateAndLimit(rankedSources)

        // Calculate final confidence
        let totalWeight = config.memorySystemWeight + config.conversationWeight +
                         config.knowledgeGraphWeight + config.eventHistoryWeight
        let normalizedConfidence = totalWeight > 0 ? totalConfidence / totalWeight : 0.0

        // Update statistics
        let duration = Date().timeIntervalSince(startTime)
        retrievalStats.totalRetrievals += 1
        retrievalStats.averageLatency = (retrievalStats.averageLatency * Double(retrievalStats.totalRetrievals - 1) + duration) / Double(retrievalStats.totalRetrievals)

        let result = ActiveRetrievalResult(
            sources: finalSources,
            contextPrompt: buildContextPrompt(from: finalSources),
            confidence: normalizedConfidence,
            retrievalTime: duration,
            queryEmbedding: nil // Will be populated if semantic search is used
        )

        logger.info("Retrieved \(finalSources.count) sources in \(String(format: "%.2f", duration))s")

        return result
    }

    /// Build an enhanced prompt with retrieved context
    public func enhancePromptWithContext(
        originalPrompt: String,
        conversationId: UUID? = nil,
        projectId: UUID? = nil,
        taskType: TaskType? = nil
    ) async -> EnhancedPrompt {
        let retrieval = await retrieveContext(
            for: originalPrompt,
            conversationId: conversationId,
            projectId: projectId,
            taskType: taskType
        )

        var enhancedPrompt = ""

        // Add context if available and relevant
        if !retrieval.sources.isEmpty && retrieval.confidence > config.minConfidenceToInject {
            enhancedPrompt += """
            <context>
            The following context from memory may be relevant to this conversation:

            \(retrieval.contextPrompt)
            </context>

            """
        }

        enhancedPrompt += originalPrompt

        return EnhancedPrompt(
            prompt: enhancedPrompt,
            hasInjectedContext: !retrieval.sources.isEmpty,
            injectedSources: retrieval.sources,
            confidence: retrieval.confidence
        )
    }

    /// Learn from a conversation exchange (store to memory)
    public func learnFromExchange(
        userMessage: String,
        assistantResponse: String,
        conversationId: UUID,
        wasHelpful: Bool? = nil
    ) async {
        logger.debug("Learning from exchange")

        // Extract key information using AI
        let extractedInfo = await extractInformation(
            userMessage: userMessage,
            assistantResponse: assistantResponse
        )

        // Store facts
        for fact in extractedInfo.facts {
            ConversationMemory.shared.learnFact(
                category: mapToFactCategory(fact.category),
                fact: fact.content,
                source: "conversation"
            )
        }

        // Store to memory system for semantic search
        if !extractedInfo.facts.isEmpty || extractedInfo.importance > 0.5 {
            do {
                _ = try await MemorySystem.shared.addShortTermMemory(
                    content: userMessage,
                    type: .contextual,
                    metadata: [
                        "conversationId": conversationId.uuidString,
                        "importance": String(extractedInfo.importance)
                    ]
                )
            } catch {
                logger.warning("Failed to store to memory system: \(error.localizedDescription)")
            }
        }

        // Log learning event
        EventBus.shared.logLearning(
            type: .patternDetected,
            data: [
                "factsExtracted": String(extractedInfo.facts.count),
                "importance": String(format: "%.2f", extractedInfo.importance)
            ]
        )
    }

    // MARK: - Memory System Retrieval

    private func retrieveFromMemorySystem(query: String) async -> PartialRetrievalResult {
        var sources: [RetrievalSource] = []

        do {
            // Retrieve from all memory tiers
            let memories = try await MemorySystem.shared.retrieveRelevantMemories(
                for: query,
                limit: config.maxMemorySystemResults,
                threshold: Double(config.minSimilarityThreshold)
            )

            for memory in memories {
                sources.append(RetrievalSource(
                    type: .memorySystem,
                    tier: memory.tier == RetrievalMemoryTier.shortTerm ? .working : .longTerm,
                    content: memory.content,
                    relevanceScore: Double(memory.importance),
                    timestamp: memory.lastAccessed,
                    metadata: memory.metadata
                ))
            }

            // Also retrieve episodic memories
            let episodic = try await MemorySystem.shared.retrieveEpisodicMemories(
                for: query,
                limit: config.maxEpisodicResults
            )

            for memory in episodic {
                sources.append(RetrievalSource(
                    type: .episodic,
                    tier: .episodic,
                    content: "\(memory.event): \(memory.context)",
                    relevanceScore: Double(memory.importance),
                    timestamp: memory.timestamp,
                    metadata: memory.metadata
                ))
            }

            // Retrieve semantic memories
            let semantic = try await MemorySystem.shared.retrieveSemanticMemories(
                for: query,
                limit: config.maxSemanticResults
            )

            for memory in semantic {
                sources.append(RetrievalSource(
                    type: .semantic,
                    tier: .semantic,
                    content: "\(memory.concept): \(memory.definition)",
                    relevanceScore: Double(memory.importance),
                    timestamp: memory.lastAccessed,
                    metadata: memory.metadata
                ))
            }

            // Retrieve procedural memories for task-related queries
            let procedural = try await MemorySystem.shared.retrieveProceduralMemories(
                for: query,
                limit: config.maxProceduralResults
            )

            for memory in procedural {
                sources.append(RetrievalSource(
                    type: .procedural,
                    tier: .procedural,
                    content: "\(memory.skill): \(memory.steps.joined(separator: " → "))",
                    relevanceScore: Double(memory.successRate * memory.importance),
                    timestamp: memory.lastAccessed,
                    metadata: memory.metadata
                ))
            }

        } catch {
            logger.warning("Memory system retrieval failed: \(error.localizedDescription)")
        }

        let avgConfidence = sources.isEmpty ? 0.0 : sources.map(\.relevanceScore).reduce(0, +) / Double(sources.count)
        return PartialRetrievalResult(sources: sources, averageConfidence: avgConfidence)
    }

    // MARK: - Conversation Memory Retrieval

    private func retrieveFromConversationMemory(
        query: String,
        projectId: UUID?
    ) async -> PartialRetrievalResult {
        var sources: [RetrievalSource] = []

        let context = ConversationMemory.shared.retrieveContext(for: query, projectId: projectId)

        // Convert facts to sources
        for fact in context.facts {
            sources.append(RetrievalSource(
                type: .conversationFact,
                tier: .longTerm,
                content: fact.fact,
                relevanceScore: fact.confidence,
                timestamp: fact.lastReferencedAt ?? fact.timestamp,
                metadata: [
                    "category": fact.category.rawValue,
                    "source": fact.source
                ]
            ))
        }

        // Convert summaries to sources
        for summary in context.summaries {
            sources.append(RetrievalSource(
                type: .conversationSummary,
                tier: .episodic,
                content: summary.summary,
                relevanceScore: summary.importanceScore,
                timestamp: summary.timestamp,
                metadata: [
                    "topics": summary.keyTopics.joined(separator: ", "),
                    "messageCount": String(summary.messageCount)
                ]
            ))
        }

        // Add user preferences
        for (key, value) in context.userPreferences {
            sources.append(RetrievalSource(
                type: .userPreference,
                tier: .semantic,
                content: "\(key): \(value)",
                relevanceScore: 0.9, // High relevance for explicit preferences
                timestamp: Date(),
                metadata: ["type": "preference"]
            ))
        }

        let avgConfidence = sources.isEmpty ? 0.0 : sources.map(\.relevanceScore).reduce(0, +) / Double(sources.count)
        return PartialRetrievalResult(sources: sources, averageConfidence: avgConfidence)
    }

    // MARK: - Knowledge Graph Retrieval

    private func retrieveFromKnowledgeGraph(query: String) async -> PartialRetrievalResult {
        // KnowledgeGraph is not yet available in the canonical build
        // Placeholder: returns empty results until KnowledgeGraph is implemented
        _ = query
        return PartialRetrievalResult(sources: [], averageConfidence: 0.0)
    }

    // MARK: - Event History Retrieval

    private func retrieveFromEventHistory(
        query: String,
        conversationId: UUID?
    ) async -> PartialRetrievalResult {
        var sources: [RetrievalSource] = []

        // Get recent error events (useful for debugging context)
        let errorEvents = EventBus.shared.getEvents(
            category: .error,
            since: Date().addingTimeInterval(-3600), // Last hour
            limit: config.maxEventResults
        )

        for event in errorEvents {
            if let errorEvent = event as? ErrorEvent {
                sources.append(RetrievalSource(
                    type: .recentError,
                    tier: .working,
                    content: "Error [\(errorEvent.errorType)]: \(errorEvent.message)",
                    relevanceScore: errorEvent.recoverable ? 0.5 : 0.8,
                    timestamp: errorEvent.timestamp,
                    metadata: [
                        "type": errorEvent.errorType,
                        "recoverable": String(errorEvent.recoverable)
                    ]
                ))
            }
        }

        // Get recent learning events
        let learningEvents = EventBus.shared.getEvents(
            category: .learning,
            since: Date().addingTimeInterval(-86400), // Last 24 hours
            limit: config.maxEventResults
        )

        for event in learningEvents {
            if let learningEvent = event as? LearningEvent {
                sources.append(RetrievalSource(
                    type: .learningEvent,
                    tier: .working,
                    content: "Learning [\(learningEvent.learningType.rawValue)]: \(learningEvent.data.values.joined(separator: ", "))",
                    relevanceScore: 0.4,
                    timestamp: learningEvent.timestamp,
                    metadata: learningEvent.data
                ))
            }
        }

        let avgConfidence = sources.isEmpty ? 0.0 : sources.map(\.relevanceScore).reduce(0, +) / Double(sources.count)
        return PartialRetrievalResult(sources: sources, averageConfidence: avgConfidence)
    }

    // MARK: - AI-Powered Ranking

    private func rankSourcesByRelevance(
        sources: [RetrievalSource],
        query: String,
        taskType: TaskType?
    ) async -> [RetrievalSource] {
        guard !sources.isEmpty else { return [] }

        // If AI ranking is disabled or no provider available, use simple scoring
        guard config.enableAIRanking,
              let provider = ProviderRegistry.shared.getProvider(id: "openrouter")
                          ?? ProviderRegistry.shared.getProvider(id: "openai") else {
            return sources.sorted { $0.relevanceScore > $1.relevanceScore }
        }

        // Use AI to rank relevance
        let sourceSummaries = sources.enumerated().map { index, source in
            "[\(index)] \(source.type.rawValue): \(source.content.prefix(200))"
        }.joined(separator: "\n")

        let prompt = """
        Rank these memory sources by relevance to the query.
        Query: "\(query)"
        Task type: \(taskType?.rawValue ?? "general")

        Sources:
        \(sourceSummaries)

        Respond with JSON array of indices in order of relevance (most relevant first):
        [0, 2, 1, ...]
        """

        do {
            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(prompt),
                timestamp: Date(),
                model: "openai/gpt-4o-mini"
            )

            var responseText = ""
            let stream = try await provider.chat(
                messages: [message],
                model: "openai/gpt-4o-mini",
                stream: false
            )

            for try await chunk in stream {
                if case .delta(let text) = chunk.type {
                    responseText += text
                } else if case .complete(let msg) = chunk.type {
                    responseText = msg.content.textValue
                }
            }

            // Parse ranking
            if let jsonStart = responseText.firstIndex(of: "["),
               let jsonEnd = responseText.lastIndex(of: "]") {
                let jsonStr = String(responseText[jsonStart...jsonEnd])
                if let data = jsonStr.data(using: .utf8),
                   let indices = try? JSONDecoder().decode([Int].self, from: data) {
                    var rankedSources: [RetrievalSource] = []
                    for index in indices where index < sources.count {
                        var source = sources[index]
                        // Boost relevance based on AI ranking position
                        source.relevanceScore *= (1.0 - Double(rankedSources.count) * 0.1)
                        rankedSources.append(source)
                    }
                    // Add any sources not ranked by AI
                    let rankedIndices = Set(indices)
                    for (index, source) in sources.enumerated() where !rankedIndices.contains(index) {
                        rankedSources.append(source)
                    }
                    return rankedSources
                }
            }

        } catch {
            logger.warning("AI ranking failed: \(error.localizedDescription)")
        }

        // Fallback to score-based ranking
        return sources.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    // MARK: - Information Extraction

    private func extractInformation(
        userMessage: String,
        assistantResponse: String
    ) async -> ExtractedInformation {
        guard let provider = ProviderRegistry.shared.getProvider(id: "openrouter")
                        ?? ProviderRegistry.shared.getProvider(id: "openai") else {
            return ExtractedInformation(facts: [], importance: 0.3)
        }

        let prompt = """
        Extract key learnable facts from this conversation exchange.
        Focus on: user preferences, technical context, project details, personal info.

        User: \(userMessage.prefix(1000))
        Assistant: \(assistantResponse.prefix(1000))

        Respond with JSON:
        {
            "facts": [
                {"category": "preference|info|technical|project", "content": "fact text"}
            ],
            "importance": 0.0-1.0
        }
        """

        do {
            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(prompt),
                timestamp: Date(),
                model: "openai/gpt-4o-mini"
            )

            var responseText = ""
            let stream = try await provider.chat(
                messages: [message],
                model: "openai/gpt-4o-mini",
                stream: false
            )

            for try await chunk in stream {
                if case .delta(let text) = chunk.type {
                    responseText += text
                } else if case .complete(let msg) = chunk.type {
                    responseText = msg.content.textValue
                }
            }

            // Parse extraction
            if let jsonStart = responseText.firstIndex(of: "{"),
               let jsonEnd = responseText.lastIndex(of: "}") {
                let jsonStr = String(responseText[jsonStart...jsonEnd])
                if let data = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    var facts: [ExtractedFact] = []
                    if let factsArray = json["facts"] as? [[String: String]] {
                        for factDict in factsArray {
                            if let category = factDict["category"],
                               let content = factDict["content"] {
                                facts.append(ExtractedFact(category: category, content: content))
                            }
                        }
                    }

                    let importance = json["importance"] as? Double ?? 0.3
                    return ExtractedInformation(facts: facts, importance: importance)
                }
            }

        } catch {
            logger.warning("Information extraction failed: \(error.localizedDescription)")
        }

        return ExtractedInformation(facts: [], importance: 0.3)
    }

    // MARK: - Helper Methods

    private func deduplicateAndLimit(_ sources: [RetrievalSource]) -> [RetrievalSource] {
        var seen = Set<String>()
        var unique: [RetrievalSource] = []

        for source in sources {
            let key = source.content.prefix(100).lowercased()
            if !seen.contains(String(key)) {
                seen.insert(String(key))
                unique.append(source)

                if unique.count >= config.maxTotalResults {
                    break
                }
            }
        }

        return unique
    }

    private func buildContextPrompt(from sources: [RetrievalSource]) -> String {
        guard !sources.isEmpty else { return "" }

        var sections: [String: [String]] = [:]

        for source in sources {
            let sectionName = source.tier.displayName
            if sections[sectionName] == nil {
                sections[sectionName] = []
            }
            sections[sectionName]?.append("• \(source.content)")
        }

        var prompt = ""
        for (section, items) in sections.sorted(by: { $0.key < $1.key }) {
            prompt += "**\(section):**\n"
            prompt += items.joined(separator: "\n")
            prompt += "\n\n"
        }

        return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mapToFactCategory(_ category: String) -> ConversationMemory.FactCategory {
        switch category.lowercased() {
        case "preference": return .userPreference
        case "info": return .userInfo
        case "technical": return .technicalContext
        case "project": return .projectDetails
        default: return .domainKnowledge
        }
    }

    // MARK: - Statistics

    public func getStatistics() -> RetrievalStatistics {
        retrievalStats
    }

    public func resetStatistics() {
        retrievalStats = RetrievalStatistics()
    }
}

// MARK: - Supporting Types

public struct RetrievalConfig: Sendable {
    // Enable/disable sources
    public var enableMemorySystemRetrieval: Bool = true
    public var enableConversationMemory: Bool = true
    public var enableKnowledgeGraph: Bool = true
    public var enableEventHistory: Bool = true
    public var enableAIRanking: Bool = true

    // Weights for each source
    public var memorySystemWeight: Double = 0.35
    public var conversationWeight: Double = 0.30
    public var knowledgeGraphWeight: Double = 0.20
    public var eventHistoryWeight: Double = 0.15

    // Limits
    public var maxMemorySystemResults: Int = 10
    public var maxEpisodicResults: Int = 5
    public var maxSemanticResults: Int = 5
    public var maxProceduralResults: Int = 3
    public var maxKnowledgeGraphResults: Int = 5
    public var maxEventResults: Int = 5
    public var maxTotalResults: Int = 15

    // Thresholds
    public var minSimilarityThreshold: Float = 0.3
    public var minConfidenceToInject: Double = 0.4
}

public struct ActiveRetrievalResult: Sendable {
    public let sources: [RetrievalSource]
    public let contextPrompt: String
    public let confidence: Double
    public let retrievalTime: TimeInterval
    public let queryEmbedding: [Float]?

    public var isEmpty: Bool {
        sources.isEmpty
    }
}

public struct RetrievalSource: Sendable {
    public let type: SourceType
    public let tier: MemoryTierType
    public var content: String
    public var relevanceScore: Double
    public let timestamp: Date
    public let metadata: [String: String]

    public enum SourceType: String, Sendable {
        case memorySystem = "Memory"
        case episodic = "Episodic"
        case semantic = "Semantic"
        case procedural = "Procedural"
        case conversationFact = "Fact"
        case conversationSummary = "Summary"
        case userPreference = "Preference"
        case knowledgeNode = "Knowledge"
        case recentError = "Error"
        case learningEvent = "Learning"
    }
}

public enum MemoryTierType: String, Sendable {
    case working = "Working Memory"
    case longTerm = "Long-Term Memory"
    case episodic = "Episodic Memory"
    case semantic = "Semantic Memory"
    case procedural = "Procedural Memory"

    public var displayName: String { rawValue }
}

public struct EnhancedPrompt: Sendable {
    public let prompt: String
    public let hasInjectedContext: Bool
    public let injectedSources: [RetrievalSource]
    public let confidence: Double
}

public struct RetrievalStatistics: Sendable {
    public var totalRetrievals: Int = 0
    public var averageLatency: TimeInterval = 0.0
    public var sourcesRetrieved: Int = 0
    public var cacheHits: Int = 0
}

struct PartialRetrievalResult {
    let sources: [RetrievalSource]
    let averageConfidence: Double
}

struct ExtractedInformation {
    let facts: [ExtractedFact]
    let importance: Double
}

struct ExtractedFact {
    let category: String
    let content: String
}
