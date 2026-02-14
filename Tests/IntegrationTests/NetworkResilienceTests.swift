@testable import TheaCore
import XCTest

/// Tests for Network Resilience: ResilientAIFallbackChain, TierHealthStatus, OfflineQueueService types
@MainActor
final class NetworkResilienceTests: XCTestCase {

    // MARK: - FallbackTier Tests

    func testFallbackTierCaseIterableCount() {
        XCTAssertEqual(FallbackTier.allCases.count, 4)
    }

    func testFallbackTierOrder() {
        let tiers = FallbackTier.allCases
        XCTAssertEqual(tiers[0], .cloud)
        XCTAssertEqual(tiers[1], .localMLX)
        XCTAssertEqual(tiers[2], .coreML)
        XCTAssertEqual(tiers[3], .ruleBased)
    }

    func testFallbackTierDisplayNames() {
        XCTAssertEqual(FallbackTier.cloud.displayName, "Cloud AI")
        XCTAssertEqual(FallbackTier.localMLX.displayName, "Local MLX")
        XCTAssertEqual(FallbackTier.coreML.displayName, "CoreML")
        XCTAssertEqual(FallbackTier.ruleBased.displayName, "Offline Rules")
    }

    func testFallbackTierRawValues() {
        XCTAssertEqual(FallbackTier.cloud.rawValue, "cloud")
        XCTAssertEqual(FallbackTier.localMLX.rawValue, "localMLX")
        XCTAssertEqual(FallbackTier.coreML.rawValue, "coreML")
        XCTAssertEqual(FallbackTier.ruleBased.rawValue, "ruleBased")
    }

    // MARK: - TierHealthStatus Tests

    func testTierHealthStatusDefaults() {
        let health = TierHealthStatus()
        XCTAssertEqual(health.consecutiveFailures, 0)
        XCTAssertEqual(health.totalSuccesses, 0)
        XCTAssertEqual(health.totalFailures, 0)
        XCTAssertNil(health.lastFailureDate)
        XCTAssertEqual(health.averageLatencyMs, 0)
    }

    func testTierHealthStatusRecordSuccess() {
        var health = TierHealthStatus()
        health.recordSuccess(latencyMs: 100)
        XCTAssertEqual(health.consecutiveFailures, 0)
        XCTAssertEqual(health.totalSuccesses, 1)
        XCTAssertEqual(health.averageLatencyMs, 100)
    }

    func testTierHealthStatusRecordMultipleSuccesses() {
        var health = TierHealthStatus()
        health.recordSuccess(latencyMs: 100)
        health.recordSuccess(latencyMs: 200)
        XCTAssertEqual(health.totalSuccesses, 2)
        // Average of 100 and 200 = 150
        XCTAssertEqual(health.averageLatencyMs, 150)
    }

    func testTierHealthStatusRecordFailure() {
        var health = TierHealthStatus()
        health.recordFailure()
        XCTAssertEqual(health.consecutiveFailures, 1)
        XCTAssertEqual(health.totalFailures, 1)
        XCTAssertNotNil(health.lastFailureDate)
    }

    func testTierHealthStatusConsecutiveFailures() {
        var health = TierHealthStatus()
        health.recordFailure()
        health.recordFailure()
        health.recordFailure()
        XCTAssertEqual(health.consecutiveFailures, 3)
        XCTAssertEqual(health.totalFailures, 3)
    }

    func testTierHealthStatusSuccessResetsConsecutiveFailures() {
        var health = TierHealthStatus()
        health.recordFailure()
        health.recordFailure()
        XCTAssertEqual(health.consecutiveFailures, 2)
        health.recordSuccess(latencyMs: 50)
        XCTAssertEqual(health.consecutiveFailures, 0)
        XCTAssertEqual(health.totalFailures, 2) // Total failures preserved
    }

    func testTierHealthStatusResetFailures() {
        var health = TierHealthStatus()
        health.recordFailure()
        health.recordFailure()
        health.resetFailures()
        XCTAssertEqual(health.consecutiveFailures, 0)
        XCTAssertNil(health.lastFailureDate)
        XCTAssertEqual(health.totalFailures, 2) // Total preserved
    }

    // MARK: - FallbackChatResult Tests

    func testFallbackChatResultProperties() {
        let result = FallbackChatResult(
            response: "Hello world",
            tier: .cloud,
            latencyMs: 250,
            wasFallback: false
        )
        XCTAssertEqual(result.response, "Hello world")
        XCTAssertEqual(result.tier, .cloud)
        XCTAssertEqual(result.latencyMs, 250)
        XCTAssertFalse(result.wasFallback)
    }

    func testFallbackChatResultWithFallback() {
        let result = FallbackChatResult(
            response: "Offline response",
            tier: .ruleBased,
            latencyMs: 1,
            wasFallback: true
        )
        XCTAssertTrue(result.wasFallback)
        XCTAssertEqual(result.tier, .ruleBased)
    }

    // MARK: - FallbackChainError Tests

    func testFallbackChainErrorDescriptions() {
        XCTAssertNotNil(FallbackChainError.allTiersExhausted.errorDescription)
        XCTAssertNotNil(FallbackChainError.emptyResponse.errorDescription)
        XCTAssertNotNil(FallbackChainError.tierUnavailable(.cloud).errorDescription)
    }

    func testFallbackChainErrorTierUnavailableIncludesTierName() {
        let error = FallbackChainError.tierUnavailable(.localMLX)
        XCTAssertTrue(error.errorDescription?.contains("Local MLX") ?? false)
    }

    // MARK: - FallbackFailure Tests

    func testFallbackFailureCreation() {
        let failure = FallbackFailure(
            tier: .cloud,
            error: "Network timeout",
            timestamp: Date()
        )
        XCTAssertEqual(failure.tier, .cloud)
        XCTAssertEqual(failure.error, "Network timeout")
        XCTAssertNotNil(failure.id) // Identifiable
    }

    // MARK: - ResilientAIFallbackChain Singleton Tests

    func testFallbackChainSingleton() {
        let chain = ResilientAIFallbackChain.shared
        XCTAssertNotNil(chain)
        XCTAssertTrue(chain === ResilientAIFallbackChain.shared)
    }

    func testFallbackChainDefaultConfig() {
        let chain = ResilientAIFallbackChain.shared
        XCTAssertEqual(chain.maxConsecutiveFailures, 3)
        XCTAssertEqual(chain.failureCooldownSeconds, 300) // 5 minutes
        XCTAssertEqual(chain.latencyThresholdMs, 5000)
    }

    func testFallbackChainTierStatus() {
        let chain = ResilientAIFallbackChain.shared
        let status = chain.tierStatus()
        XCTAssertEqual(status.count, 4) // All 4 tiers tracked
        for tier in FallbackTier.allCases {
            XCTAssertNotNil(status[tier])
        }
    }

    func testFallbackChainResetAllTiers() {
        let chain = ResilientAIFallbackChain.shared
        chain.resetAllTiers()
        let status = chain.tierStatus()
        for tier in FallbackTier.allCases {
            XCTAssertEqual(status[tier]?.consecutiveFailures, 0)
        }
        XCTAssertTrue(chain.failureLog.isEmpty)
    }

    // MARK: - OfflineQueueError Tests

    func testOfflineQueueErrorCases() {
        let errors: [OfflineQueueError] = [
            .requestQueued(UUID()),
            .providerNotAvailable,
            .requestExpired,
            .queueFull
        ]
        for error in errors {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - OfflineQueueConfig Tests

    func testOfflineQueueConfigDefaults() {
        let config = OfflineQueueConfig()
        XCTAssertEqual(config.maxQueueSize, 100)
        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.requestExpirationTime, 86400) // 24 hours
        XCTAssertTrue(config.autoProcessOnConnect)
    }
}
