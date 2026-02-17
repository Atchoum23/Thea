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

    let logger = Logger(subsystem: "com.thea.ai", category: "ActiveMemoryRetrieval")

    // Configuration
    public var config = RetrievalConfig()

    // Statistics
    var retrievalStats = RetrievalStatistics()

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

    // MARK: - Statistics

    /// Returns the current retrieval performance statistics, including total retrieval count and average latency.
    public func getStatistics() -> RetrievalStatistics {
        retrievalStats
    }

    /// Resets all retrieval statistics to their default zero values.
    public func resetStatistics() {
        retrievalStats = RetrievalStatistics()
    }
}

// Supporting types are in ActiveMemoryRetrievalTypes.swift
// Retrieval methods are in ActiveMemoryRetrieval+Retrieval.swift
// Ranking & extraction methods are in ActiveMemoryRetrieval+Ranking.swift
// Helper methods are in ActiveMemoryRetrieval+Helpers.swift
