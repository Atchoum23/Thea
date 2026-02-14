// ActiveMemoryRetrieval+Retrieval.swift
// Thea
//
// Memory retrieval methods for ActiveMemoryRetrieval
// Retrieves from memory system, conversation memory, knowledge graph, and event history

import Foundation

// MARK: - Memory Tier Retrieval Methods

extension ActiveMemoryRetrieval {

    // MARK: - Memory System Retrieval

    func retrieveFromMemorySystem(query: String) async -> PartialRetrievalResult {
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

    func retrieveFromConversationMemory(
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

    func retrieveFromKnowledgeGraph(query: String) async -> PartialRetrievalResult {
        // KnowledgeGraph is not yet available in the canonical build
        // Placeholder: returns empty results until KnowledgeGraph is implemented
        _ = query
        return PartialRetrievalResult(sources: [], averageConfidence: 0.0)
    }

    // MARK: - Event History Retrieval

    func retrieveFromEventHistory(
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
}
