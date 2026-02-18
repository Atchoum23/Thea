// SmartModelRouter.swift
// Thea V2
//
// Intelligent model routing with cost optimization and capability matching
// Implements Plan-and-Execute pattern, cascade fallback, and batch optimization

import Foundation
import OSLog

// MARK: - Model Capability

/// Capabilities of an AI model
public struct RouterModelCapability: Sendable {
    public let modelId: String
    public let provider: String
    public let contextWindow: Int
    public let maxOutputTokens: Int
    public let capabilities: Set<Capability>
    public let costPerInputToken: Double   // USD per 1M tokens
    public let costPerOutputToken: Double  // USD per 1M tokens
    public let averageLatency: TimeInterval // seconds
    public let qualityScore: Float          // 0.0 - 1.0
    public let isLocalModel: Bool

    public init(
        modelId: String,
        provider: String,
        contextWindow: Int,
        maxOutputTokens: Int,
        capabilities: Set<Capability>,
        costPerInputToken: Double,
        costPerOutputToken: Double,
        averageLatency: TimeInterval,
        qualityScore: Float,
        isLocalModel: Bool = false
    ) {
        self.modelId = modelId
        self.provider = provider
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.capabilities = capabilities
        self.costPerInputToken = costPerInputToken
        self.costPerOutputToken = costPerOutputToken
        self.averageLatency = averageLatency
        self.qualityScore = qualityScore
        self.isLocalModel = isLocalModel
    }

    public enum Capability: String, Sendable {
        case textGeneration
        case codeGeneration
        case reasoning
        case analysis
        case creative
        case vision
        case audio
        case functionCalling
        case structuredOutput
        case streaming
        case longContext
        case fastResponse
        case lowCost
        case highQuality
    }
}

// MARK: - Routing Decision

/// A model routing decision
public struct SmartRoutingDecision: Sendable {
    public let taskId: UUID
    public let taskType: TaskComplexity
    public let selectedModel: RouterModelCapability
    public let alternativeModels: [RouterModelCapability]
    public let estimatedCost: Double
    public let estimatedLatency: TimeInterval
    public let confidence: Float
    public let reasoning: String
    public let strategy: RoutingStrategy

    public init(
        taskId: UUID = UUID(),
        taskType: TaskComplexity,
        selectedModel: RouterModelCapability,
        alternativeModels: [RouterModelCapability] = [],
        estimatedCost: Double,
        estimatedLatency: TimeInterval,
        confidence: Float,
        reasoning: String,
        strategy: RoutingStrategy
    ) {
        self.taskId = taskId
        self.taskType = taskType
        self.selectedModel = selectedModel
        self.alternativeModels = alternativeModels
        self.estimatedCost = estimatedCost
        self.estimatedLatency = estimatedLatency
        self.confidence = confidence
        self.reasoning = reasoning
        self.strategy = strategy
    }
}

public enum TaskComplexity: String, Codable, Sendable {
    case trivial     // Simple lookup, formatting
    case simple      // Basic Q&A, short generation
    case moderate    // Standard coding, analysis
    case complex     // Multi-step reasoning, architecture
    case expert      // Novel problems, deep research
}

public enum RoutingStrategy: String, Sendable {
    case costOptimized      // Minimize cost
    case qualityOptimized   // Maximize quality
    case speedOptimized     // Minimize latency
    case balanced           // Balance all factors
    case cascadeFallback    // Try cheap first, escalate
    case planAndExecute     // Expensive plans, cheap executes
    case localFirst         // Prefer local models
}

// MARK: - Plan and Execute

/// Plan-and-Execute pattern configuration
public struct PlanExecuteConfig: Sendable {
    public let planningModel: RouterModelCapability
    public let executionModel: RouterModelCapability
    public let verificationModel: RouterModelCapability?
    public let maxExecutionSteps: Int

    public init(
        planningModel: RouterModelCapability,
        executionModel: RouterModelCapability,
        verificationModel: RouterModelCapability? = nil,
        maxExecutionSteps: Int = 10
    ) {
        self.planningModel = planningModel
        self.executionModel = executionModel
        self.verificationModel = verificationModel
        self.maxExecutionSteps = maxExecutionSteps
    }
}

// MARK: - Cascade Config

/// Cascade fallback configuration
public struct CascadeConfig: Sendable {
    public let models: [RouterModelCapability]  // Ordered from cheapest to most expensive
    public let confidenceThreshold: Float  // Confidence needed to accept result
    public let maxAttempts: Int

    public init(
        models: [RouterModelCapability],
        confidenceThreshold: Float = 0.7,
        maxAttempts: Int = 3
    ) {
        self.models = models
        self.confidenceThreshold = confidenceThreshold
        self.maxAttempts = maxAttempts
    }
}

// MARK: - Batch Request

/// A batch of requests for batch optimization
public struct BatchRequest: Identifiable, Sendable {
    public let id: UUID
    public let requests: [SingleRequest]
    public let priority: BatchPriority
    public let deadline: Date?

    public init(
        id: UUID = UUID(),
        requests: [SingleRequest],
        priority: BatchPriority = .normal,
        deadline: Date? = nil
    ) {
        self.id = id
        self.requests = requests
        self.priority = priority
        self.deadline = deadline
    }

    public struct SingleRequest: Identifiable, Sendable {
        public let id: UUID
        public let prompt: String
        public let taskType: String
        public let maxTokens: Int

        public init(
            id: UUID = UUID(),
            prompt: String,
            taskType: String,
            maxTokens: Int = 1000
        ) {
            self.id = id
            self.prompt = prompt
            self.taskType = taskType
            self.maxTokens = maxTokens
        }
    }

    public enum BatchPriority: Int, Sendable {
        case low = 0
        case normal = 50
        case high = 100
    }
}

// MARK: - Usage Tracking

/// Track model usage for cost monitoring
public struct ModelUsage: Codable, Sendable {
    public var totalInputTokens: Int
    public var totalOutputTokens: Int
    public var totalCost: Double
    public var requestCount: Int
    public var totalLatency: TimeInterval
    public var successCount: Int
    public var failureCount: Int

    public init() {
        self.totalInputTokens = 0
        self.totalOutputTokens = 0
        self.totalCost = 0
        self.requestCount = 0
        self.totalLatency = 0
        self.successCount = 0
        self.failureCount = 0
    }

    public var averageLatency: TimeInterval {
        guard requestCount > 0 else { return 0 }
        return totalLatency / Double(requestCount)
    }

    public var successRate: Float {
        guard requestCount > 0 else { return 0 }
        return Float(successCount) / Float(requestCount)
    }

    public mutating func record(
        inputTokens: Int,
        outputTokens: Int,
        cost: Double,
        latency: TimeInterval,
        success: Bool
    ) {
        totalInputTokens += inputTokens
        totalOutputTokens += outputTokens
        totalCost += cost
        requestCount += 1
        totalLatency += latency
        if success {
            successCount += 1
        } else {
            failureCount += 1
        }
    }
}
