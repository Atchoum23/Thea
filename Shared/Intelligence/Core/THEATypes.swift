// THEATypes.swift
// Thea
//
// Portable THEA types used across UI and Intelligence layers.
// Originally defined in MetaAI/THEAOrchestrator.swift, extracted
// here so they can be used without the MetaAI dependency.

import Foundation

// MARK: - THEA Decision

/// A model-routing decision made by the THEA orchestrator, including which model and strategy to use.
public struct THEADecision: Identifiable, Sendable {
    public let id: UUID
    public let reasoning: THEAReasoning
    public let selectedModel: String
    public let selectedProvider: String
    public let strategy: THEAExecutionStrategy
    public let confidenceScore: Double
    public let contextFactors: [ContextFactor]
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        reasoning: THEAReasoning,
        selectedModel: String,
        selectedProvider: String,
        strategy: THEAExecutionStrategy,
        confidenceScore: Double,
        contextFactors: [ContextFactor],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.reasoning = reasoning
        self.selectedModel = selectedModel
        self.selectedProvider = selectedProvider
        self.strategy = strategy
        self.confidenceScore = confidenceScore
        self.contextFactors = contextFactors
        self.timestamp = timestamp
    }
}

// MARK: - THEA Reasoning

/// Explanation of why a particular model and strategy were selected for a task.
public struct THEAReasoning: Sendable {
    public let taskType: TaskType
    public let taskTypeDescription: String
    public let taskConfidence: Double
    public let whyThisModel: String
    public let whyThisStrategy: String
    public let alternativesConsidered: [(model: String, reason: String)]
    public let classificationMethod: ClassificationMethodType

    public init(
        taskType: TaskType,
        taskTypeDescription: String,
        taskConfidence: Double,
        whyThisModel: String,
        whyThisStrategy: String,
        alternativesConsidered: [(model: String, reason: String)],
        classificationMethod: ClassificationMethodType
    ) {
        self.taskType = taskType
        self.taskTypeDescription = taskTypeDescription
        self.taskConfidence = taskConfidence
        self.whyThisModel = whyThisModel
        self.whyThisStrategy = whyThisStrategy
        self.alternativesConsidered = alternativesConsidered
        self.classificationMethod = classificationMethod
    }
}

// MARK: - Execution Strategy

/// Strategy used by the orchestrator when executing a task.
public enum THEAExecutionStrategy: String, Sendable {
    case direct
    case decomposed
    case multiModel
    case localFallback
    case planMode
}

// MARK: - Context Factor

/// A single contextual signal that influenced a routing decision.
public struct ContextFactor: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let value: String
    public let influence: InfluenceLevel
    public let description: String

    /// How strongly this factor influenced the routing decision.
    public enum InfluenceLevel: String, Sendable {
        case critical
        case high
        case medium
        case low
    }

    public init(
        id: UUID = UUID(),
        name: String,
        value: String,
        influence: InfluenceLevel,
        description: String
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.influence = influence
        self.description = description
    }
}

// MARK: - THEA Suggestion

/// A follow-up action or informational suggestion surfaced after a THEA response.
public struct THEASuggestion: Identifiable, Sendable {
    public let id: UUID
    public let type: SuggestionType
    public let title: String
    public let description: String
    public let action: String

    /// Category of the suggestion.
    public enum SuggestionType: String, Sendable {
        case action
        case followUp
        case info
    }

    public init(
        id: UUID = UUID(),
        type: SuggestionType,
        title: String,
        description: String,
        action: String
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.action = action
    }
}

// MARK: - Response Metadata

/// Timing and token metrics for a single THEA response.
public struct THEAResponseMetadata: Sendable {
    public let startTime: Date
    public let endTime: Date
    public let tokenCount: Int
    public let modelUsed: String
    public let providerUsed: String

    public var latency: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public init(
        startTime: Date,
        endTime: Date,
        tokenCount: Int,
        modelUsed: String,
        providerUsed: String
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.tokenCount = tokenCount
        self.modelUsed = modelUsed
        self.providerUsed = providerUsed
    }
}

// MARK: - THEA Response

/// A complete response from the THEA orchestrator, including content, routing decision, and suggestions.
public struct THEAResponse: Identifiable, Sendable {
    public let id: UUID
    public let content: String
    public let decision: THEADecision
    public let metadata: THEAResponseMetadata
    public let suggestions: [THEASuggestion]

    public init(
        id: UUID = UUID(),
        content: String,
        decision: THEADecision,
        metadata: THEAResponseMetadata,
        suggestions: [THEASuggestion]
    ) {
        self.id = id
        self.content = content
        self.decision = decision
        self.metadata = metadata
        self.suggestions = suggestions
    }
}

// MARK: - THEA Learning

/// A learning signal captured from system behavior for future routing optimization.
public struct THEALearning: Identifiable, Sendable {
    public let id: UUID
    public let type: LearningType
    public let description: String
    public let confidence: Double

    /// The category of observed learning signal.
    public enum LearningType: String, Sendable {
        case taskPattern
        case modelPerformance
        case userPreference
        case contextPattern
    }

    public init(
        id: UUID = UUID(),
        type: LearningType,
        description: String,
        confidence: Double
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.confidence = confidence
    }
}
