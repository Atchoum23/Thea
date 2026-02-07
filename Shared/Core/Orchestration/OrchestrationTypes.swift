// OrchestrationTypes.swift
// Thea
//
// CANONICAL TYPE DEFINITIONS for the AI Orchestration System
// This file contains shared types used by both AI/MetaAI and Intelligence systems.
//
// NOTE: TaskType is defined in Intelligence/Classification/TaskType.swift
// All orchestration components should import that definition.

import Foundation

// MARK: - Query Complexity

/// Complexity level of a query for decomposition decisions
public enum QueryComplexity: String, Codable, Sendable {
    case simple     // Single-step, straightforward
    case moderate   // May benefit from decomposition
    case complex    // Definitely needs decomposition
}

// MARK: - Model Selection

/// Result of model routing decision
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
}

// MARK: - Query Decomposition

/// Result of decomposing a complex query into sub-queries
public struct QueryDecomposition: Sendable {
    public let originalQuery: String
    public let complexity: QueryComplexity
    public let subQueries: [SubQuery]
    public let executionPlan: ExecutionPlan

    public init(
        originalQuery: String,
        complexity: QueryComplexity,
        subQueries: [SubQuery],
        executionPlan: ExecutionPlan
    ) {
        self.originalQuery = originalQuery
        self.complexity = complexity
        self.subQueries = subQueries
        self.executionPlan = executionPlan
    }
}

/// A sub-query within a decomposed query
public struct SubQuery: Identifiable, Sendable {
    public let id: UUID
    public let query: String
    public let taskType: TaskType
    public let dependencies: [UUID]
    public let priority: Int

    public init(
        id: UUID = UUID(),
        query: String,
        taskType: TaskType,
        dependencies: [UUID] = [],
        priority: Int = 1
    ) {
        self.id = id
        self.query = query
        self.taskType = taskType
        self.dependencies = dependencies
        self.priority = priority
    }
}

/// How to execute sub-queries
public enum ExecutionPlan: String, Codable, Sendable {
    case sequential   // Execute one at a time in order
    case parallel     // Execute all simultaneously
    case mixed        // Some parallel, some sequential based on dependencies
}

// MARK: - Sub-Query Result

/// Result of executing a sub-query
public struct SubQueryResult: Sendable {
    public let subQuery: SubQuery
    public let response: String
    public let success: Bool
    public let executionTime: TimeInterval
    public let modelUsed: String

    public init(
        subQuery: SubQuery,
        response: String,
        success: Bool,
        executionTime: TimeInterval,
        modelUsed: String
    ) {
        self.subQuery = subQuery
        self.response = response
        self.success = success
        self.executionTime = executionTime
        self.modelUsed = modelUsed
    }
}

// MARK: - Execution Strategy

/// Strategy for executing sub-queries
public enum SubQueryExecutionStrategy: String, Codable, Sendable {
    case fastest      // Prioritize speed
    case cheapest     // Prioritize cost
    case bestQuality  // Prioritize output quality
    case balanced     // Balance all factors
}

// MARK: - Errors

/// Errors that can occur during query decomposition
public enum QueryDecompositionError: Error, LocalizedError {
    case decompositionFailed(String)
    case noResultsToAggregate
    case providerNotAvailable

    public var errorDescription: String? {
        switch self {
        case .decompositionFailed(let reason):
            return "Query decomposition failed: \(reason)"
        case .noResultsToAggregate:
            return "No results available to aggregate"
        case .providerNotAvailable:
            return "No AI provider available for decomposition"
        }
    }
}

/// Errors that can occur during model routing
public enum ModelRoutingError: Error, LocalizedError {
    case noModelsAvailable(taskType: TaskType)
    case routingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noModelsAvailable(let taskType):
            return "No models available for task type: \(taskType.displayName)"
        case .routingFailed(let reason):
            return "Model routing failed: \(reason)"
        }
    }
}
