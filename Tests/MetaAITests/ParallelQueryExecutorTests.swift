// ParallelQueryExecutorTests.swift
// Tests for the Parallel Query Executor

@testable import TheaCore
import XCTest

// MARK: - ParallelQueryExecutor Tests

@MainActor
final class ParallelQueryExecutorTests: XCTestCase {
    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        let config = ParallelExecutionConfig()

        XCTAssertEqual(config.maxConcurrentQueries, 5)
        XCTAssertEqual(config.queryTimeout, 60.0, accuracy: 0.001)
        XCTAssertTrue(config.continueOnError)
        XCTAssertEqual(config.minimumConfidence, 0.3, accuracy: 0.001)
    }

    func testConfigurationIsSendable() {
        let config = ParallelExecutionConfig()
        // This test passes if it compiles - ParallelExecutionConfig must be Sendable
        let _: Sendable = config
    }

    func testCustomConfiguration() {
        var config = ParallelExecutionConfig()
        config.maxConcurrentQueries = 8
        config.queryTimeout = 120.0
        config.continueOnError = false
        config.minimumConfidence = 0.5

        XCTAssertEqual(config.maxConcurrentQueries, 8)
        XCTAssertEqual(config.queryTimeout, 120.0, accuracy: 0.001)
        XCTAssertFalse(config.continueOnError)
        XCTAssertEqual(config.minimumConfidence, 0.5, accuracy: 0.001)
    }

    // MARK: - ExecutionStrategy Tests

    func testExecutionStrategyValues() {
        XCTAssertNotNil(SubQueryExecutionStrategy.parallel)
        XCTAssertNotNil(SubQueryExecutionStrategy.sequential)
        XCTAssertNotNil(SubQueryExecutionStrategy.mixed)
    }

    func testExecutionStrategyRawValues() {
        XCTAssertEqual(SubQueryExecutionStrategy.parallel.rawValue, "parallel")
        XCTAssertEqual(SubQueryExecutionStrategy.sequential.rawValue, "sequential")
        XCTAssertEqual(SubQueryExecutionStrategy.mixed.rawValue, "mixed")
    }

    // MARK: - SubQuery Tests

    func testSubQueryCreation() {
        let subQuery = SubQuery(
            query: "What is Swift?",
            taskType: .factual,
            dependencies: [],
            priority: 1
        )

        XCTAssertNotNil(subQuery.id)
        XCTAssertEqual(subQuery.query, "What is Swift?")
        XCTAssertEqual(subQuery.taskType, .factual)
        XCTAssertTrue(subQuery.dependencies.isEmpty)
        XCTAssertEqual(subQuery.priority, 1)
    }

    func testSubQueryWithDependencies() {
        let dep1 = UUID()
        let dep2 = UUID()
        let subQuery = SubQuery(
            query: "Combine results",
            taskType: .analysis,
            dependencies: [dep1, dep2],
            priority: 3
        )

        XCTAssertEqual(subQuery.dependencies.count, 2)
        XCTAssertTrue(subQuery.dependencies.contains(dep1))
        XCTAssertTrue(subQuery.dependencies.contains(dep2))
    }

    func testSubQueryIsSendable() {
        let subQuery = SubQuery(
            query: "test",
            taskType: .simpleQA,
            dependencies: [],
            priority: 1
        )
        // This test passes if it compiles - SubQuery must be Sendable
        let _: Sendable = subQuery
    }

    // MARK: - SubQueryResult Tests

    func testSubQueryResultSuccess() {
        let subQuery = SubQuery(
            query: "What is Swift?",
            taskType: .factual,
            dependencies: [],
            priority: 1
        )
        let result = SubQueryResult(
            subQuery: subQuery,
            response: "Swift is a programming language",
            success: true,
            executionTime: 0.5,
            modelUsed: "gpt-4"
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.subQuery.query, "What is Swift?")
        XCTAssertEqual(result.response, "Swift is a programming language")
        XCTAssertEqual(result.modelUsed, "gpt-4")
        XCTAssertEqual(result.executionTime, 0.5, accuracy: 0.001)
    }

    func testSubQueryResultFailure() {
        let subQuery = SubQuery(
            query: "Complex query",
            taskType: .complexReasoning,
            dependencies: [],
            priority: 2
        )
        let result = SubQueryResult(
            subQuery: subQuery,
            response: "Query failed: Request timeout",
            success: false,
            executionTime: 30.0,
            modelUsed: "claude-3"
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.response.contains("failed"))
    }

    func testSubQueryResultIsSendable() {
        let subQuery = SubQuery(
            query: "test",
            taskType: .simpleQA,
            dependencies: [],
            priority: 1
        )
        let result = SubQueryResult(
            subQuery: subQuery,
            response: "test",
            success: true,
            executionTime: 0,
            modelUsed: "test"
        )
        // This test passes if it compiles - SubQueryResult must be Sendable
        let _: Sendable = result
    }

    // MARK: - ParallelExecutionProgress Tests

    func testParallelExecutionProgressCreation() {
        let progress = ParallelExecutionProgress(
            phase: .execution,
            progress: 0.5,
            message: "Executing sub-queries..."
        )

        XCTAssertEqual(progress.phase, .execution)
        XCTAssertEqual(progress.progress, 0.5, accuracy: 0.001)
        XCTAssertEqual(progress.message, "Executing sub-queries...")
    }

    func testParallelExecutionPhases() {
        XCTAssertNotNil(ParallelExecutionProgress.ExecutionPhase.decomposition)
        XCTAssertNotNil(ParallelExecutionProgress.ExecutionPhase.execution)
        XCTAssertNotNil(ParallelExecutionProgress.ExecutionPhase.aggregation)
        XCTAssertNotNil(ParallelExecutionProgress.ExecutionPhase.complete)
    }

    func testParallelExecutionProgressIsSendable() {
        let progress = ParallelExecutionProgress(
            phase: .decomposition,
            progress: 0.1,
            message: "test"
        )
        // This test passes if it compiles - ParallelExecutionProgress must be Sendable
        let _: Sendable = progress
    }

    // MARK: - ParallelExecutionResult Tests

    func testParallelExecutionResultCreation() {
        let subQuery1 = SubQuery(query: "Q1", taskType: .factual, dependencies: [], priority: 1)
        let subQuery2 = SubQuery(query: "Q2", taskType: .factual, dependencies: [], priority: 1)
        let subResults = [
            SubQueryResult(subQuery: subQuery1, response: "R1", success: true, executionTime: 1.0, modelUsed: "gpt-4"),
            SubQueryResult(subQuery: subQuery2, response: "R2", success: true, executionTime: 1.5, modelUsed: "gpt-4")
        ]

        let result = ParallelExecutionResult(
            originalQuery: "Complex question",
            subQueryResults: subResults,
            aggregatedResponse: "Combined answer",
            duration: 3.0,
            executionPlan: .parallel
        )

        XCTAssertEqual(result.originalQuery, "Complex question")
        XCTAssertEqual(result.subQueryResults.count, 2)
        XCTAssertEqual(result.aggregatedResponse, "Combined answer")
        XCTAssertEqual(result.duration, 3.0, accuracy: 0.001)
        XCTAssertEqual(result.executionPlan, .parallel)
    }

    func testParallelExecutionResultSuccessRate() {
        let subQuery1 = SubQuery(query: "Q1", taskType: .factual, dependencies: [], priority: 1)
        let subQuery2 = SubQuery(query: "Q2", taskType: .factual, dependencies: [], priority: 1)
        let subQuery3 = SubQuery(query: "Q3", taskType: .factual, dependencies: [], priority: 1)
        let subResults = [
            SubQueryResult(subQuery: subQuery1, response: "R1", success: true, executionTime: 1.0, modelUsed: "gpt-4"),
            SubQueryResult(subQuery: subQuery2, response: "R2", success: false, executionTime: 1.5, modelUsed: "gpt-4"),
            SubQueryResult(subQuery: subQuery3, response: "R3", success: true, executionTime: 2.0, modelUsed: "gpt-4")
        ]

        let result = ParallelExecutionResult(
            originalQuery: "Test",
            subQueryResults: subResults,
            aggregatedResponse: "Test",
            duration: 5.0,
            executionPlan: .parallel
        )

        // 2 out of 3 = 66.7%
        XCTAssertEqual(result.successRate, 2.0 / 3.0, accuracy: 0.001)
    }

    func testParallelExecutionResultEmptySuccessRate() {
        let result = ParallelExecutionResult(
            originalQuery: "Test",
            subQueryResults: [],
            aggregatedResponse: "Test",
            duration: 0,
            executionPlan: .parallel
        )

        // Empty results should return 0
        XCTAssertEqual(result.successRate, 0, accuracy: 0.001)
    }

    func testParallelExecutionResultIsSendable() {
        let result = ParallelExecutionResult(
            originalQuery: "test",
            subQueryResults: [],
            aggregatedResponse: "test",
            duration: 0,
            executionPlan: .parallel
        )
        // This test passes if it compiles - ParallelExecutionResult must be Sendable
        let _: Sendable = result
    }

    // MARK: - Executor Singleton Tests

    func testExecutorSingletonExists() {
        let executor = ParallelQueryExecutor.shared
        XCTAssertNotNil(executor)
    }

    func testExecutorSingletonIsSameInstance() {
        let executor1 = ParallelQueryExecutor.shared
        let executor2 = ParallelQueryExecutor.shared
        XCTAssertTrue(executor1 === executor2)
    }

    func testExecutorConfigAccessible() {
        let executor = ParallelQueryExecutor.shared
        XCTAssertNotNil(executor.config)
    }
}

// MARK: - ParallelExecutionError Tests

@MainActor
final class ParallelExecutionErrorTests: XCTestCase {
    func testDecompositionFailedError() {
        let error = ParallelExecutionError.decompositionFailed("Invalid query structure")
        XCTAssertTrue(error.errorDescription?.contains("Invalid query structure") ?? false)
    }

    func testProviderNotAvailableError() {
        let error = ParallelExecutionError.providerNotAvailable("openai")
        XCTAssertTrue(error.errorDescription?.contains("openai") ?? false)
    }

    func testAllQueriesFailedError() {
        let error = ParallelExecutionError.allQueriesFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("failed") ?? false)
    }

    func testTimeoutError() {
        let error = ParallelExecutionError.timeout
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("timed out") ?? false)
    }
}
