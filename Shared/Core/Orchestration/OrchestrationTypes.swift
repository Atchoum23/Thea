// OrchestrationTypes.swift
// Thea
//
// Shared types for the AI Orchestration System.
//
// NOTE: TaskType is defined in Intelligence/Classification/TaskType.swift
// NOTE: Query decomposition types are defined in AI/MetaAI/QueryDecomposer.swift
// This file contains only supplementary shared types.

import Foundation

// MARK: - Query Complexity

/// Complexity level of a query for decomposition decisions
public enum QueryComplexity: String, Codable, Sendable {
    case simple     // Single-step, straightforward
    case moderate   // May benefit from decomposition
    case complex    // Definitely needs decomposition

    public var description: String {
        switch self {
        case .simple: "Single-task, straightforward query"
        case .moderate: "Multi-step or requires decomposition"
        case .complex: "Complex reasoning, verification needed"
        }
    }
}

// MARK: - Model Selection

/// Result of model routing decision
/// Used by both Intelligence/Routing and AI/MetaAI routing systems
public struct ModelSelection: Sendable {
    public let modelID: String
    public let providerID: String
    public let reasoning: String
    public let isLocal: Bool
    public let estimatedCost: Double?

    public init(
        modelID: String,
        providerID: String,
        reasoning: String,
        isLocal: Bool = false,
        estimatedCost: Double? = nil
    ) {
        self.modelID = modelID
        self.providerID = providerID
        self.reasoning = reasoning
        self.isLocal = isLocal
        self.estimatedCost = estimatedCost
    }

    /// Display name for UI
    public var displayName: String {
        if isLocal {
            return modelID.replacingOccurrences(of: "local-", with: "Local: ")
        }
        return modelID
    }
}

// MARK: - Execution Strategy

/// Strategy for executing sub-queries (what to optimize for)
public enum ExecutionStrategy: String, Codable, Sendable {
    case fastest      // Prioritize speed
    case cheapest     // Prioritize cost
    case bestQuality  // Prioritize output quality
    case balanced     // Balance all factors
}

// MARK: - Errors

/// Errors that can occur during model routing
public enum ModelRoutingError: Error, LocalizedError {
    case noModelsAvailable(taskType: TaskType)
    case routingFailed(String)
    case localModelRequired

    public var errorDescription: String? {
        switch self {
        case .noModelsAvailable(let taskType):
            return "No models available for task type: \(taskType.displayName)"
        case .routingFailed(let reason):
            return "Model routing failed: \(reason)"
        case .localModelRequired:
            return "Local model required but none available"
        }
    }
}
