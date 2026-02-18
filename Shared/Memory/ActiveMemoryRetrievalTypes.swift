//
//  ActiveMemoryRetrievalTypes.swift
//  Thea
//
//  Supporting types for ActiveMemoryRetrieval
//

import Foundation

// MARK: - Supporting Types

/// Configuration controlling which memory sources are searched and how results are weighted.
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

/// The combined output of an active memory retrieval query, including context-ready text and source metadata.
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

/// A single source contributing memories to a retrieval result.
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

/// Which memory tier a retrieved entry came from.
public enum MemoryTierType: String, Sendable {
    case working = "Working Memory"
    case longTerm = "Long-Term Memory"
    case episodic = "Episodic Memory"
    case semantic = "Semantic Memory"
    case procedural = "Procedural Memory"

    public var displayName: String { rawValue }
}

/// A prompt augmented with relevant memories for context injection into an AI request.
public struct EnhancedPrompt: Sendable {
    public let prompt: String
    public let hasInjectedContext: Bool
    public let injectedSources: [RetrievalSource]
    public let confidence: Double
}

/// Performance and coverage statistics from a single memory retrieval operation.
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
