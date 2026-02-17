// ModelRouter+Types.swift
// Thea
//
// Supporting types for ModelRouter.

import Foundation

// MARK: - Supporting Types

public struct RoutingDecision: Identifiable, Sendable {
    public let id: UUID
    public let model: AIModel
    public let provider: String
    public let taskType: TaskType
    public let confidence: Double
    public let reason: String
    public let alternatives: [AIModel]
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        model: AIModel,
        provider: String,
        taskType: TaskType,
        confidence: Double,
        reason: String,
        alternatives: [AIModel],
        timestamp: Date
    ) {
        self.id = id
        self.model = model
        self.provider = provider
        self.taskType = taskType
        self.confidence = confidence
        self.reason = reason
        self.alternatives = alternatives
        self.timestamp = timestamp
    }
}

public struct RoutingContext: Sendable {
    public let urgency: Urgency
    public let budgetConstraint: Decimal?
    public let estimatedInputTokens: Int?
    public let estimatedOutputTokens: Int?
    public let requiresStreaming: Bool
    public let requiresVision: Bool
    public let requiresFunctions: Bool

    public init(
        urgency: Urgency = .normal,
        budgetConstraint: Decimal? = nil,
        estimatedInputTokens: Int? = nil,
        estimatedOutputTokens: Int? = nil,
        requiresStreaming: Bool = true,
        requiresVision: Bool = false,
        requiresFunctions: Bool = false
    ) {
        self.urgency = urgency
        self.budgetConstraint = budgetConstraint
        self.estimatedInputTokens = estimatedInputTokens
        self.estimatedOutputTokens = estimatedOutputTokens
        self.requiresStreaming = requiresStreaming
        self.requiresVision = requiresVision
        self.requiresFunctions = requiresFunctions
    }

    public enum Urgency: String, Sendable {
        case low       // Quality matters more
        case normal    // Balanced
        case high      // Speed matters more
    }
}

public struct ModelTaskPerformance: Codable, Sendable {
    public let modelId: String
    public let taskType: TaskType

    public var successCount: Int = 0
    public var failureCount: Int = 0
    public var totalTokens: Int = 0
    public var totalCost: Decimal = 0
    public var totalLatency: TimeInterval = 0
    public var qualitySum: Double = 0
    public var qualityCount: Int = 0

    public var successRate: Double {
        let total = successCount + failureCount
        guard total > 0 else { return 0.5 }
        return Double(successCount) / Double(total)
    }

    public var averageLatency: TimeInterval {
        let total = successCount + failureCount
        guard total > 0 else { return 0 }
        return totalLatency / Double(total)
    }

    public var averageCost: Decimal {
        let total = successCount + failureCount
        guard total > 0 else { return 0 }
        return totalCost / Decimal(total)
    }

    public var averageQuality: Double? {
        guard qualityCount > 0 else { return nil }
        return qualitySum / Double(qualityCount)
    }

    public init(modelId: String, taskType: TaskType) {
        self.modelId = modelId
        self.taskType = taskType
    }

    public mutating func recordOutcome(
        success: Bool,
        quality: Double?,
        latency: TimeInterval,
        tokens: Int,
        cost: Decimal
    ) {
        if success {
            successCount += 1
        } else {
            failureCount += 1
        }

        totalTokens += tokens
        totalCost += cost
        totalLatency += latency

        if let q = quality {
            qualitySum += q
            qualityCount += 1
        }
    }
}

// MARK: - Learned Preference Types

/// A learned preference for a model on a specific task type
public struct LearnedModelPreference: Identifiable, Codable, Sendable {
    public let id: UUID
    public let modelId: String
    public let taskType: TaskType
    public var preferenceScore: Double
    public var sampleCount: Int
    public var lastUpdated: Date

    public init(
        id: UUID = UUID(),
        modelId: String,
        taskType: TaskType,
        preferenceScore: Double,
        sampleCount: Int,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.modelId = modelId
        self.taskType = taskType
        self.preferenceScore = preferenceScore
        self.sampleCount = sampleCount
        self.lastUpdated = lastUpdated
    }
}

/// A contextual pattern detected in routing behavior
public struct ContextualRoutingPattern: Identifiable, Codable, Sendable {
    public let id: UUID
    public let patternType: PatternType
    public let description: String
    public let modelId: String
    public var context: [String: String]
    public var confidence: Double
    public var sampleCount: Int
    public var lastSeen: Date

    public enum PatternType: String, Codable, Sendable {
        case taskSequence = "task_sequence"
        case timeOfDay = "time_of_day"
        case userPreference = "user_preference"
        case performanceTrend = "performance_trend"
        case costOptimization = "cost_optimization"
    }

    public init(
        id: UUID = UUID(),
        patternType: PatternType,
        description: String,
        modelId: String,
        context: [String: String] = [:],
        confidence: Double = 0.5,
        sampleCount: Int = 1,
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.patternType = patternType
        self.description = description
        self.modelId = modelId
        self.context = context
        self.confidence = confidence
        self.sampleCount = sampleCount
        self.lastSeen = lastSeen
    }
}

/// Insights from routing learning
public struct RoutingInsights: Sendable {
    public let topPerformingModels: [String]
    public let recentPatterns: [ContextualRoutingPattern]
    public let totalRoutingDecisions: Int
    public let totalLearningSamples: Int
    public let explorationRate: Double
    public let adaptiveRoutingEnabled: Bool

    public var summary: String {
        """
        Routing Insights:
        - \(totalRoutingDecisions) routing decisions made
        - \(totalLearningSamples) learning samples collected
        - Top models: \(topPerformingModels.prefix(3).joined(separator: ", "))
        - \(recentPatterns.count) contextual patterns detected
        - Exploration rate: \(String(format: "%.0f%%", explorationRate * 100))
        """
    }
}

// MARK: - V1 Compatibility

// ModelSelection is defined in OrchestrationTypes.swift

// V1 compatibility extension
public extension ModelRouter {
    /// V1 compatibility method - uses TaskClassification (typealias for ClassificationResult)
    func selectModel(for classification: TaskClassification) async throws -> ModelSelection {
        let decision = route(classification: classification)

        return ModelSelection(
            modelID: decision.model.id,
            providerID: decision.provider,
            reasoning: decision.reason
        )
    }
}
