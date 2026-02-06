// ParallelQueryExecutor.swift
// Implements parallel sub-query execution with proper coordination and aggregation
import Foundation
import OSLog

/// Executes sub-queries in parallel with intelligent coordination and result aggregation.
///
/// Based on 2025-2026 best practices:
/// - Parallel execution for independent sub-queries
/// - Dependency-aware sequential execution when needed
/// - Sum fusion for aggregating retrieval results
/// - Configurable concurrency limits
@MainActor
@Observable
public final class ParallelQueryExecutor {
    public static let shared = ParallelQueryExecutor()

    private let logger = Logger(subsystem: "com.thea.metaai", category: "ParallelQueryExecutor")

    /// Configuration for parallel execution
    public var config = ParallelExecutionConfig()

    private let decomposer = QueryDecomposer.shared
    private let router = ModelRouter.shared
    private let providerRegistry = ProviderRegistry.shared

    private init() {}

    // MARK: - Parallel Execution

    /// Execute a complex query by decomposing and running sub-queries in parallel
    public func execute(
        query: String,
        progressHandler: @escaping @Sendable (ParallelExecutionProgress) -> Void
    ) async throws -> ParallelExecutionResult {
        let startTime = Date()

        // Step 1: Decompose the query
        progressHandler(ParallelExecutionProgress(
            phase: .decomposition,
            progress: 0.1,
            message: "Decomposing query into sub-tasks..."
        ))

        let decomposition = try await decomposer.decompose(query)

        logger.info("Decomposed into \(decomposition.subQueries.count) sub-queries with plan: \(decomposition.executionPlan.rawValue)")

        // Step 2: Execute based on the execution plan
        let results: [SubQueryResult]
        switch decomposition.executionPlan {
        case .parallel:
            results = try await executeParallel(
                subQueries: decomposition.subQueries,
                progressHandler: progressHandler
            )
        case .sequential:
            results = try await executeSequential(
                subQueries: decomposition.subQueries,
                progressHandler: progressHandler
            )
        case .mixed:
            results = try await executeMixed(
                subQueries: decomposition.subQueries,
                progressHandler: progressHandler
            )
        }

        // Step 3: Aggregate results
        progressHandler(ParallelExecutionProgress(
            phase: .aggregation,
            progress: 0.9,
            message: "Aggregating results..."
        ))

        let aggregatedResponse = try await decomposer.aggregate(results, originalQuery: query)

        progressHandler(ParallelExecutionProgress(
            phase: .complete,
            progress: 1.0,
            message: "Execution complete"
        ))

        return ParallelExecutionResult(
            originalQuery: query,
            subQueryResults: results,
            aggregatedResponse: aggregatedResponse,
            duration: Date().timeIntervalSince(startTime),
            executionPlan: decomposition.executionPlan
        )
    }

    // MARK: - Parallel Execution

    private func executeParallel(
        subQueries: [SubQuery],
        progressHandler: @escaping @Sendable (ParallelExecutionProgress) -> Void
    ) async throws -> [SubQueryResult] {
        logger.info("Executing \(subQueries.count) sub-queries in parallel")

        progressHandler(ParallelExecutionProgress(
            phase: .execution,
            progress: 0.2,
            message: "Executing \(subQueries.count) sub-queries in parallel..."
        ))

        // Use error-tolerant parallel execution with timeout
        // Based on 2025 best practice: "serve partial results rather than no results"
        let operations: [@Sendable () async throws -> SubQueryResult] = subQueries.map { query in
            { [self] in
                try await self.executeSingleQueryWithTimeout(query)
            }
        }

        // Execute with timeout and continue on individual errors
        let parallelResults = try await withParallelTimeout(
            operations: operations,
            timeout: config.queryTimeout,
            continueOnError: config.continueOnError
        )

        // Convert parallel results to SubQueryResults
        var results: [SubQueryResult] = []
        var failedCount = 0

        for (index, parallelResult) in parallelResults.enumerated() {
            if let value = parallelResult.value {
                results.append(value)
            } else if let error = parallelResult.error {
                failedCount += 1
                logger.warning("Sub-query \(index) failed: \(error.localizedDescription)")

                // Create failure result if we're continuing on error
                if config.continueOnError {
                    let failedResult = SubQueryResult(
                        subQuery: subQueries[index],
                        response: "Query failed: \(error.localizedDescription)",
                        success: false,
                        executionTime: 0,
                        modelUsed: "none"
                    )
                    results.append(failedResult)
                }
            }

            let progress = 0.2 + (0.6 * Float(results.count) / Float(subQueries.count))
            progressHandler(ParallelExecutionProgress(
                phase: .execution,
                progress: progress,
                message: "Completed \(results.count)/\(subQueries.count) sub-queries (\(failedCount) failed)"
            ))
        }

        // Check if we have enough successful results
        let successfulResults = results.filter(\.success)
        if successfulResults.isEmpty {
            throw ParallelExecutionError.allQueriesFailed
        }

        // Sort results to match original order
        return results.sorted { result1, result2 in
            guard let idx1 = subQueries.firstIndex(where: { $0.id == result1.subQuery.id }),
                  let idx2 = subQueries.firstIndex(where: { $0.id == result2.subQuery.id })
            else {
                return false
            }
            return idx1 < idx2
        }
    }

    /// Execute a single sub-query with timeout enforcement
    private func executeSingleQueryWithTimeout(_ subQuery: SubQuery) async throws -> SubQueryResult {
        try await withTimeout(
            seconds: config.queryTimeout,
            operation: "sub-query: \(subQuery.query.prefix(50))..."
        ) { [self] in
            try await self.executeSingleQuery(subQuery)
        }
    }

    // MARK: - Sequential Execution

    private func executeSequential(
        subQueries: [SubQuery],
        progressHandler: @escaping @Sendable (ParallelExecutionProgress) -> Void
    ) async throws -> [SubQueryResult] {
        logger.info("Executing \(subQueries.count) sub-queries sequentially")

        var results: [SubQueryResult] = []

        for (index, query) in subQueries.enumerated() {
            let progress = 0.2 + (0.6 * Float(index) / Float(subQueries.count))
            progressHandler(ParallelExecutionProgress(
                phase: .execution,
                progress: progress,
                message: "Executing sub-query \(index + 1)/\(subQueries.count)..."
            ))

            let result = try await executeSingleQuery(query)
            results.append(result)
        }

        return results
    }

    // MARK: - Mixed Execution (Dependency-Aware)

    private func executeMixed(
        subQueries: [SubQuery],
        progressHandler: @escaping @Sendable (ParallelExecutionProgress) -> Void
    ) async throws -> [SubQueryResult] {
        logger.info("Executing \(subQueries.count) sub-queries with mixed strategy")

        var results: [SubQueryResult] = []
        var completed: Set<UUID> = []

        // Group queries by dependency level
        var remaining = subQueries
        var batchNumber = 0

        while !remaining.isEmpty {
            batchNumber += 1

            // Find all queries that can be executed (dependencies met)
            let executable = remaining.filter { $0.canExecute(completed: completed) }

            if executable.isEmpty {
                // No executable queries - this shouldn't happen with valid decomposition
                logger.warning("No executable queries found, forcing sequential execution")
                break
            }

            remaining.removeAll { query in executable.contains { $0.id == query.id } }

            let progress = 0.2 + (0.6 * Float(subQueries.count - remaining.count) / Float(subQueries.count))
            progressHandler(ParallelExecutionProgress(
                phase: .execution,
                progress: progress,
                message: "Executing batch \(batchNumber) (\(executable.count) queries)..."
            ))

            // Execute this batch in parallel
            let batchResults = try await withThrowingTaskGroup(of: SubQueryResult.self) { group in
                for query in executable.prefix(config.maxConcurrentQueries) {
                    group.addTask { [self] in
                        try await self.executeSingleQuery(query)
                    }
                }

                var batchResults: [SubQueryResult] = []
                for try await result in group {
                    batchResults.append(result)
                    completed.insert(result.subQuery.id)
                }
                return batchResults
            }

            results.append(contentsOf: batchResults)
        }

        // Handle any remaining queries sequentially (in case of circular deps)
        for query in remaining {
            let result = try await executeSingleQuery(query)
            results.append(result)
        }

        return results
    }

    // MARK: - Single Query Execution

    private func executeSingleQuery(_ subQuery: SubQuery) async throws -> SubQueryResult {
        let startTime = Date()

        // Route to appropriate model
        let classification = TaskClassification(
            primaryType: subQuery.taskType,
            secondaryTypes: [],
            confidence: 0.9,
            reasoning: "From decomposition"
        )

        let modelSelection = try await router.selectModel(for: classification)

        guard let provider = providerRegistry.getProvider(id: modelSelection.providerID) else {
            throw ParallelExecutionError.providerNotAvailable(modelSelection.providerID)
        }

        // Execute the query
        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(subQuery.query),
            timestamp: Date(),
            model: modelSelection.modelID
        )

        var response = ""
        let stream = try await provider.chat(
            messages: [message],
            model: modelSelection.modelID,
            stream: false
        )

        for try await chunk in stream {
            if case .delta(let text) = chunk.type {
                response += text
            }
        }

        return SubQueryResult(
            subQuery: subQuery,
            response: response,
            success: true,
            executionTime: Date().timeIntervalSince(startTime),
            modelUsed: modelSelection.modelID
        )
    }
}

// MARK: - Configuration

/// Configuration for parallel execution
public struct ParallelExecutionConfig: Sendable {
    /// Maximum number of concurrent sub-query executions
    public var maxConcurrentQueries: Int = 5

    /// Timeout for individual sub-queries in seconds
    public var queryTimeout: TimeInterval = 60

    /// Whether to continue on individual query failures
    public var continueOnError: Bool = true

    /// Minimum confidence threshold for including results
    public var minimumConfidence: Float = 0.3

    public init() {}
}

// MARK: - Progress & Results

/// Progress update for parallel execution
public struct ParallelExecutionProgress: Sendable {
    public let phase: ExecutionPhase
    public let progress: Float
    public let message: String

    public enum ExecutionPhase: Sendable {
        case decomposition
        case execution
        case aggregation
        case complete
    }
}

/// Result of parallel execution
public struct ParallelExecutionResult: Sendable {
    public let originalQuery: String
    public let subQueryResults: [SubQueryResult]
    public let aggregatedResponse: String
    public let duration: TimeInterval
    public let executionPlan: SubQueryExecutionStrategy

    /// Success rate of sub-queries
    public var successRate: Float {
        guard !subQueryResults.isEmpty else { return 0 }
        let successCount = subQueryResults.filter(\.success).count
        return Float(successCount) / Float(subQueryResults.count)
    }
}

/// Errors in parallel execution
public enum ParallelExecutionError: LocalizedError {
    case decompositionFailed(String)
    case providerNotAvailable(String)
    case allQueriesFailed
    case timeout

    public var errorDescription: String? {
        switch self {
        case let .decompositionFailed(reason):
            "Query decomposition failed: \(reason)"
        case let .providerNotAvailable(id):
            "Provider not available: \(id)"
        case .allQueriesFailed:
            "All sub-queries failed"
        case .timeout:
            "Parallel execution timed out"
        }
    }
}
