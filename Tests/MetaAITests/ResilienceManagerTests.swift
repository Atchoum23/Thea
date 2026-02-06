// ResilienceManagerTests.swift
// Tests for the Resilience Manager - circuit breakers, retries, and fallback chains

@testable import TheaCore
import XCTest

// MARK: - ResilienceManager Tests

@MainActor
final class ResilienceManagerTests: XCTestCase {
    // MARK: - Singleton Tests

    func testSingletonExists() {
        let manager = ResilienceManager.shared
        XCTAssertNotNil(manager)
    }

    func testSingletonIsSameInstance() {
        let manager1 = ResilienceManager.shared
        let manager2 = ResilienceManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        let manager = ResilienceManager.shared
        let config = manager.config

        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.baseRetryDelay, 1.0, accuracy: 0.001)
        XCTAssertEqual(config.maxRetryDelay, 30.0, accuracy: 0.001)
        XCTAssertEqual(config.requestTimeout, 60.0, accuracy: 0.001)
        XCTAssertEqual(config.circuitBreakerFailureThreshold, 5)
        XCTAssertEqual(config.circuitBreakerResetTimeout, 60.0, accuracy: 0.001)
        XCTAssertEqual(config.circuitBreakerHalfOpenRequests, 3)
    }

    func testConfigurationModifiable() {
        let manager = ResilienceManager.shared
        let originalMaxRetries = manager.config.maxRetries

        manager.config.maxRetries = 5
        XCTAssertEqual(manager.config.maxRetries, 5)

        // Reset to original
        manager.config.maxRetries = originalMaxRetries
    }

    // MARK: - Statistics Tests

    func testInitialStatistics() {
        let manager = ResilienceManager.shared
        manager.resetStats()
        let stats = manager.stats

        XCTAssertEqual(stats.successfulRequests, 0)
        XCTAssertEqual(stats.failedRequests, 0)
        XCTAssertEqual(stats.retryAttempts, 0)
        XCTAssertEqual(stats.circuitBreakerTrips, 0)
        XCTAssertEqual(stats.totalFallbackExhausted, 0)
    }

    func testSuccessRateCalculation() {
        // Test with no requests
        let emptyStats = ResilienceStats()
        XCTAssertEqual(emptyStats.successRate, 1.0, accuracy: 0.001)

        // Test with only successes
        var successStats = ResilienceStats()
        successStats.successfulRequests = 10
        XCTAssertEqual(successStats.successRate, 1.0, accuracy: 0.001)

        // Test with mixed results
        var mixedStats = ResilienceStats()
        mixedStats.successfulRequests = 7
        mixedStats.failedRequests = 3
        XCTAssertEqual(mixedStats.successRate, 0.7, accuracy: 0.001)
    }

    // MARK: - Health Score Tests

    func testHealthScoreDefaultValue() {
        let manager = ResilienceManager.shared
        manager.resetHealthScores()

        // Unknown provider should return 1.0 (healthy)
        let score = manager.getHealthScore(for: "unknown-provider")
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func testGetAllHealthScores() {
        let manager = ResilienceManager.shared
        manager.resetHealthScores()

        let scores = manager.getAllHealthScores()
        XCTAssertNotNil(scores)
    }

    func testGetProvidersByHealth() {
        let manager = ResilienceManager.shared
        manager.resetHealthScores()

        let providers = manager.getProvidersByHealth()
        XCTAssertNotNil(providers)
    }

    // MARK: - Reset Tests

    func testResetCircuitBreakers() {
        let manager = ResilienceManager.shared

        // Should not throw
        manager.resetCircuitBreakers()
    }

    func testResetHealthScores() {
        let manager = ResilienceManager.shared

        // Should not throw
        manager.resetHealthScores()
    }

    func testResetStats() {
        let manager = ResilienceManager.shared

        // Modify stats
        manager.resetStats()

        // Verify reset
        XCTAssertEqual(manager.stats.successfulRequests, 0)
        XCTAssertEqual(manager.stats.failedRequests, 0)
    }

    // MARK: - Fallback Chain Tests

    func testBuildFallbackChainForSimpleTask() {
        let manager = ResilienceManager.shared
        manager.resetCircuitBreakers()

        let chain = manager.buildFallbackChain(
            for: .simpleQA,
            preference: .cloudFirst
        )

        XCTAssertNotNil(chain)
    }

    func testBuildFallbackChainForComplexTask() {
        let manager = ResilienceManager.shared
        manager.resetCircuitBreakers()

        let chain = manager.buildFallbackChain(
            for: .complexReasoning,
            preference: .balanced
        )

        XCTAssertNotNil(chain)
    }

    func testBuildFallbackChainLocalPreference() {
        let manager = ResilienceManager.shared
        manager.resetCircuitBreakers()

        let chain = manager.buildFallbackChain(
            for: .factual,
            preference: .always
        )

        // With .always preference, only local models should be in chain
        XCTAssertNotNil(chain)
    }
}

// MARK: - ResilienceConfig Tests

@MainActor
final class ResilienceConfigTests: XCTestCase {
    func testDefaultInitialization() {
        let config = ResilienceConfig()

        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.baseRetryDelay, 1.0, accuracy: 0.001)
        XCTAssertEqual(config.maxRetryDelay, 30.0, accuracy: 0.001)
        XCTAssertEqual(config.requestTimeout, 60.0, accuracy: 0.001)
        XCTAssertEqual(config.circuitBreakerFailureThreshold, 5)
        XCTAssertEqual(config.circuitBreakerResetTimeout, 60.0, accuracy: 0.001)
        XCTAssertEqual(config.circuitBreakerHalfOpenRequests, 3)
    }

    func testConfigIsSendable() {
        let config = ResilienceConfig()
        // This test passes if it compiles - ResilienceConfig must be Sendable
        let _: Sendable = config
    }
}

// MARK: - ResilienceStats Tests

@MainActor
final class ResilienceStatsTests: XCTestCase {
    func testDefaultInitialization() {
        let stats = ResilienceStats()

        XCTAssertEqual(stats.successfulRequests, 0)
        XCTAssertEqual(stats.failedRequests, 0)
        XCTAssertEqual(stats.retryAttempts, 0)
        XCTAssertEqual(stats.circuitBreakerTrips, 0)
        XCTAssertEqual(stats.totalFallbackExhausted, 0)
    }

    func testSuccessRateWithNoRequests() {
        let stats = ResilienceStats()
        XCTAssertEqual(stats.successRate, 1.0, accuracy: 0.001)
    }

    func testSuccessRateCalculation() {
        var stats = ResilienceStats()
        stats.successfulRequests = 8
        stats.failedRequests = 2

        XCTAssertEqual(stats.successRate, 0.8, accuracy: 0.001)
    }

    func testSuccessRateAllSuccesses() {
        var stats = ResilienceStats()
        stats.successfulRequests = 100
        stats.failedRequests = 0

        XCTAssertEqual(stats.successRate, 1.0, accuracy: 0.001)
    }

    func testSuccessRateAllFailures() {
        var stats = ResilienceStats()
        stats.successfulRequests = 0
        stats.failedRequests = 100

        XCTAssertEqual(stats.successRate, 0.0, accuracy: 0.001)
    }

    func testStatsIsSendable() {
        let stats = ResilienceStats()
        // This test passes if it compiles - ResilienceStats must be Sendable
        let _: Sendable = stats
    }
}

// MARK: - ResilienceError Tests

@MainActor
final class ResilienceErrorTests: XCTestCase {
    func testProviderNotAvailableError() {
        let error = ResilienceError.providerNotAvailable("test-provider")
        XCTAssertEqual(error.errorDescription, "Provider not available: test-provider")
    }

    func testTimeoutError() {
        let error = ResilienceError.timeout
        XCTAssertEqual(error.errorDescription, "Request timed out")
    }

    func testMaxRetriesExceededError() {
        let error = ResilienceError.maxRetriesExceeded
        XCTAssertEqual(error.errorDescription, "Maximum retry attempts exceeded")
    }

    func testAllProvidersFailedErrorWithLastError() {
        let underlyingError = NSError(domain: "test", code: 123, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        let error = ResilienceError.allProvidersFailed(lastError: underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
    }

    func testAllProvidersFailedErrorWithoutLastError() {
        let error = ResilienceError.allProvidersFailed(lastError: nil)
        XCTAssertTrue(error.errorDescription?.contains("unknown") ?? false)
    }

    func testCircuitBreakerOpenError() {
        let error = ResilienceError.circuitBreakerOpen("openai")
        XCTAssertEqual(error.errorDescription, "Circuit breaker open for provider: openai")
    }
}

// MARK: - TaskType Extension Tests

@MainActor
final class TaskTypeResilienceTests: XCTestCase {
    func testSimpleTaskTypes() {
        XCTAssertTrue(TaskType.simpleQA.isSimple)
        XCTAssertTrue(TaskType.factual.isSimple)
        XCTAssertTrue(TaskType.summarization.isSimple)
    }

    func testComplexTaskTypes() {
        XCTAssertFalse(TaskType.codeGeneration.isSimple)
        XCTAssertFalse(TaskType.complexReasoning.isSimple)
        XCTAssertFalse(TaskType.creativeWriting.isSimple)
        XCTAssertFalse(TaskType.mathLogic.isSimple)
        XCTAssertFalse(TaskType.analysis.isSimple)
        XCTAssertFalse(TaskType.planning.isSimple)
        XCTAssertFalse(TaskType.debugging.isSimple)
    }
}
