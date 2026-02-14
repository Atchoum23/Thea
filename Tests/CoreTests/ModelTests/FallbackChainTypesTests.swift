// FallbackChainTypesTests.swift
// Tests for ResilientAIFallbackChain pure logic: tier health tracking,
// cooldown filtering, availability logic, and error types.

import Foundation
import XCTest

// MARK: - Mirrored Types

private enum FallbackTier: String, CaseIterable, Codable, Sendable {
    case cloud
    case localMLX
    case coreML
    case ruleBased

    var displayName: String {
        switch self {
        case .cloud: "Cloud API"
        case .localMLX: "Local MLX"
        case .coreML: "CoreML"
        case .ruleBased: "Rule-Based"
        }
    }
}

private struct TierHealthStatus: Sendable {
    var consecutiveFailures: Int = 0
    var totalSuccesses: Int = 0
    var totalFailures: Int = 0
    var lastFailureDate: Date?
    var averageLatencyMs: Int = 0

    mutating func recordSuccess(latencyMs: Int) {
        consecutiveFailures = 0
        totalSuccesses += 1
        let total = totalSuccesses + totalFailures
        averageLatencyMs = ((averageLatencyMs * (total - 1)) + latencyMs) / total
    }

    mutating func recordFailure() {
        consecutiveFailures += 1
        totalFailures += 1
        lastFailureDate = Date()
    }

    mutating func resetFailures() {
        consecutiveFailures = 0
        lastFailureDate = nil
    }

    var successRate: Double {
        let total = totalSuccesses + totalFailures
        guard total > 0 else { return 1.0 }
        return Double(totalSuccesses) / Double(total)
    }

    var isHealthy: Bool {
        consecutiveFailures < 3
    }
}

private enum FallbackChainError: Error, LocalizedError {
    case allTiersExhausted
    case tierUnavailable(FallbackTier)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .allTiersExhausted:
            "All AI provider tiers exhausted"
        case .tierUnavailable(let tier):
            "\(tier.displayName) is currently unavailable"
        case .emptyResponse:
            "Received empty response from provider"
        }
    }
}

private func availableTiers(
    health: [FallbackTier: TierHealthStatus],
    maxConsecutiveFailures: Int = 3,
    cooldownSeconds: TimeInterval = 60
) -> [FallbackTier] {
    FallbackTier.allCases.filter { tier in
        guard let tierHealth = health[tier] else { return true }
        if tierHealth.consecutiveFailures >= maxConsecutiveFailures {
            if let lastFailure = tierHealth.lastFailureDate {
                let elapsed = Date().timeIntervalSince(lastFailure)
                if elapsed < cooldownSeconds {
                    return false
                }
            }
        }
        return true
    }
}

// MARK: - FallbackTier Tests

final class FallbackTierTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(FallbackTier.allCases.count, 4)
    }

    func testCascadeOrder() {
        let tiers = FallbackTier.allCases
        XCTAssertEqual(tiers[0], .cloud)
        XCTAssertEqual(tiers[1], .localMLX)
        XCTAssertEqual(tiers[2], .coreML)
        XCTAssertEqual(tiers[3], .ruleBased)
    }

    func testDisplayNames() {
        XCTAssertEqual(FallbackTier.cloud.displayName, "Cloud API")
        XCTAssertEqual(FallbackTier.localMLX.displayName, "Local MLX")
        XCTAssertEqual(FallbackTier.coreML.displayName, "CoreML")
        XCTAssertEqual(FallbackTier.ruleBased.displayName, "Rule-Based")
    }

    func testUniqueRawValues() {
        let rawValues = FallbackTier.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    func testCodableRoundTrip() throws {
        for tier in FallbackTier.allCases {
            let data = try JSONEncoder().encode(tier)
            let decoded = try JSONDecoder().decode(FallbackTier.self, from: data)
            XCTAssertEqual(decoded, tier)
        }
    }
}

// MARK: - TierHealthStatus Tests

final class TierHealthStatusTests: XCTestCase {
    func testDefaultValues() {
        let health = TierHealthStatus()
        XCTAssertEqual(health.consecutiveFailures, 0)
        XCTAssertEqual(health.totalSuccesses, 0)
        XCTAssertEqual(health.totalFailures, 0)
        XCTAssertNil(health.lastFailureDate)
        XCTAssertEqual(health.averageLatencyMs, 0)
        XCTAssertTrue(health.isHealthy)
    }

    func testRecordSingleSuccess() {
        var health = TierHealthStatus()
        health.recordSuccess(latencyMs: 100)
        XCTAssertEqual(health.totalSuccesses, 1)
        XCTAssertEqual(health.consecutiveFailures, 0)
        XCTAssertEqual(health.averageLatencyMs, 100)
    }

    func testRecordMultipleSuccesses() {
        var health = TierHealthStatus()
        health.recordSuccess(latencyMs: 100)
        health.recordSuccess(latencyMs: 200)
        XCTAssertEqual(health.totalSuccesses, 2)
        XCTAssertEqual(health.averageLatencyMs, 150)
    }

    func testRecordSuccessResetsConsecutiveFailures() {
        var health = TierHealthStatus()
        health.recordFailure()
        health.recordFailure()
        XCTAssertEqual(health.consecutiveFailures, 2)
        health.recordSuccess(latencyMs: 50)
        XCTAssertEqual(health.consecutiveFailures, 0)
    }

    func testRecordFailure() {
        var health = TierHealthStatus()
        health.recordFailure()
        XCTAssertEqual(health.consecutiveFailures, 1)
        XCTAssertEqual(health.totalFailures, 1)
        XCTAssertNotNil(health.lastFailureDate)
    }

    func testMultipleConsecutiveFailures() {
        var health = TierHealthStatus()
        health.recordFailure()
        health.recordFailure()
        health.recordFailure()
        XCTAssertEqual(health.consecutiveFailures, 3)
        XCTAssertEqual(health.totalFailures, 3)
        XCTAssertFalse(health.isHealthy)
    }

    func testResetFailures() {
        var health = TierHealthStatus()
        health.recordFailure()
        health.recordFailure()
        health.resetFailures()
        XCTAssertEqual(health.consecutiveFailures, 0)
        XCTAssertNil(health.lastFailureDate)
        XCTAssertEqual(health.totalFailures, 2) // Total preserved
    }

    func testSuccessRateAllSuccesses() {
        var health = TierHealthStatus()
        health.recordSuccess(latencyMs: 100)
        health.recordSuccess(latencyMs: 100)
        health.recordSuccess(latencyMs: 100)
        XCTAssertEqual(health.successRate, 1.0, accuracy: 0.001)
    }

    func testSuccessRateAllFailures() {
        var health = TierHealthStatus()
        health.recordFailure()
        health.recordFailure()
        XCTAssertEqual(health.successRate, 0.0, accuracy: 0.001)
    }

    func testSuccessRateMixed() {
        var health = TierHealthStatus()
        health.recordSuccess(latencyMs: 100)
        health.recordFailure()
        XCTAssertEqual(health.successRate, 0.5, accuracy: 0.001)
    }

    func testSuccessRateEmpty() {
        let health = TierHealthStatus()
        XCTAssertEqual(health.successRate, 1.0, accuracy: 0.001)
    }

    func testAverageLatencyIncremental() {
        var health = TierHealthStatus()
        health.recordSuccess(latencyMs: 100)
        health.recordSuccess(latencyMs: 300)
        health.recordSuccess(latencyMs: 200)
        // Average of 100, 300, 200 = 200 (integer division)
        XCTAssertEqual(health.averageLatencyMs, 200)
    }

    func testIsHealthyThreshold() {
        var health = TierHealthStatus()
        XCTAssertTrue(health.isHealthy) // 0 failures
        health.recordFailure()
        XCTAssertTrue(health.isHealthy) // 1 failure
        health.recordFailure()
        XCTAssertTrue(health.isHealthy) // 2 failures
        health.recordFailure()
        XCTAssertFalse(health.isHealthy) // 3 failures = unhealthy
    }
}

// MARK: - Tier Availability Tests

final class TierAvailabilityTests: XCTestCase {
    func testAllTiersAvailableWhenHealthy() {
        let health: [FallbackTier: TierHealthStatus] = [
            .cloud: TierHealthStatus(),
            .localMLX: TierHealthStatus(),
            .coreML: TierHealthStatus(),
            .ruleBased: TierHealthStatus()
        ]
        let available = availableTiers(health: health)
        XCTAssertEqual(available.count, 4)
    }

    func testTierUnavailableWhenExceedsConsecutiveFailures() {
        var cloudHealth = TierHealthStatus()
        cloudHealth.recordFailure()
        cloudHealth.recordFailure()
        cloudHealth.recordFailure()
        let health: [FallbackTier: TierHealthStatus] = [
            .cloud: cloudHealth,
            .localMLX: TierHealthStatus()
        ]
        let available = availableTiers(health: health)
        XCTAssertFalse(available.contains(.cloud))
        XCTAssertTrue(available.contains(.localMLX))
    }

    func testTierAvailableAfterCooldown() {
        var cloudHealth = TierHealthStatus()
        cloudHealth.consecutiveFailures = 5
        // Set last failure to 120 seconds ago (past 60s cooldown)
        cloudHealth.lastFailureDate = Date().addingTimeInterval(-120)
        let health: [FallbackTier: TierHealthStatus] = [
            .cloud: cloudHealth
        ]
        let available = availableTiers(health: health, cooldownSeconds: 60)
        XCTAssertTrue(available.contains(.cloud))
    }

    func testTierUnavailableDuringCooldown() {
        var cloudHealth = TierHealthStatus()
        cloudHealth.consecutiveFailures = 5
        // Set last failure to 10 seconds ago (within 60s cooldown)
        cloudHealth.lastFailureDate = Date().addingTimeInterval(-10)
        let health: [FallbackTier: TierHealthStatus] = [
            .cloud: cloudHealth
        ]
        let available = availableTiers(health: health, cooldownSeconds: 60)
        XCTAssertFalse(available.contains(.cloud))
    }

    func testTierAvailableWithNoHealthData() {
        let health: [FallbackTier: TierHealthStatus] = [:]
        let available = availableTiers(health: health)
        XCTAssertEqual(available.count, 4) // All available when no data
    }

    func testMultipleUnhealthyTiers() {
        var cloudHealth = TierHealthStatus()
        cloudHealth.consecutiveFailures = 3
        cloudHealth.lastFailureDate = Date()
        var mlxHealth = TierHealthStatus()
        mlxHealth.consecutiveFailures = 3
        mlxHealth.lastFailureDate = Date()
        let health: [FallbackTier: TierHealthStatus] = [
            .cloud: cloudHealth,
            .localMLX: mlxHealth,
            .coreML: TierHealthStatus(),
            .ruleBased: TierHealthStatus()
        ]
        let available = availableTiers(health: health)
        XCTAssertEqual(available.count, 2)
        XCTAssertTrue(available.contains(.coreML))
        XCTAssertTrue(available.contains(.ruleBased))
    }

    func testCustomMaxFailuresThreshold() {
        var cloudHealth = TierHealthStatus()
        cloudHealth.consecutiveFailures = 5
        cloudHealth.lastFailureDate = Date()
        let health: [FallbackTier: TierHealthStatus] = [
            .cloud: cloudHealth
        ]
        // With threshold of 10, 5 failures is still OK
        let available = availableTiers(health: health, maxConsecutiveFailures: 10)
        XCTAssertTrue(available.contains(.cloud))
    }
}

// MARK: - FallbackChainError Tests

final class FallbackChainErrorTests: XCTestCase {
    func testAllTiersExhaustedDescription() {
        let error = FallbackChainError.allTiersExhausted
        XCTAssertEqual(error.errorDescription, "All AI provider tiers exhausted")
    }

    func testTierUnavailableDescription() {
        let error = FallbackChainError.tierUnavailable(.cloud)
        XCTAssertEqual(error.errorDescription, "Cloud API is currently unavailable")
    }

    func testTierUnavailableLocalMLX() {
        let error = FallbackChainError.tierUnavailable(.localMLX)
        XCTAssertEqual(error.errorDescription, "Local MLX is currently unavailable")
    }

    func testEmptyResponseDescription() {
        let error = FallbackChainError.emptyResponse
        XCTAssertEqual(error.errorDescription, "Received empty response from provider")
    }

    func testConformsToLocalizedError() {
        let error: any Error = FallbackChainError.allTiersExhausted
        XCTAssertNotNil(error.localizedDescription)
    }
}
