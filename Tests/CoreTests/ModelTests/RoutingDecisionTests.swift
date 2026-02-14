// RoutingDecisionTests.swift
// Tests for ModelTaskPerformance from ModelRouter routing types.
// RoutingContext, LearnedModelPreference, ContextualRoutingPattern, and
// RoutingInsights tests are in RoutingDecisionContextTests.swift.

import Foundation
import XCTest

// MARK: - Mirrored Types

private enum TaskType: String, Codable, Sendable, CaseIterable {
    case codeGeneration, codeAnalysis, debugging, factual, creative
    case analysis, research, conversation, system, math
    case translation, summarization, planning, unknown
}

private struct ModelTaskPerformance: Codable, Sendable {
    let modelId: String
    let taskType: TaskType

    var successCount: Int = 0
    var failureCount: Int = 0
    var totalTokens: Int = 0
    var totalCost: Decimal = 0
    var totalLatency: TimeInterval = 0
    var qualitySum: Double = 0
    var qualityCount: Int = 0

    var successRate: Double {
        let total = successCount + failureCount
        guard total > 0 else { return 0.5 }
        return Double(successCount) / Double(total)
    }

    var averageLatency: TimeInterval {
        let total = successCount + failureCount
        guard total > 0 else { return 0 }
        return totalLatency / Double(total)
    }

    var averageQuality: Double? {
        guard qualityCount > 0 else { return nil }
        return qualitySum / Double(qualityCount)
    }

    init(modelId: String, taskType: TaskType) {
        self.modelId = modelId
        self.taskType = taskType
    }

    mutating func recordOutcome(
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

// MARK: - ModelTaskPerformance Tests

final class ModelTaskPerformanceTests: XCTestCase {

    func testInitialDefaults() {
        let perf = ModelTaskPerformance(
            modelId: "gpt-4", taskType: .codeGeneration
        )
        XCTAssertEqual(perf.modelId, "gpt-4")
        XCTAssertEqual(perf.taskType, .codeGeneration)
        XCTAssertEqual(perf.successCount, 0)
        XCTAssertEqual(perf.failureCount, 0)
        XCTAssertEqual(perf.totalTokens, 0)
        XCTAssertEqual(perf.totalCost, 0)
        XCTAssertEqual(perf.totalLatency, 0)
        XCTAssertEqual(perf.qualitySum, 0)
        XCTAssertEqual(perf.qualityCount, 0)
    }

    func testSuccessRateNoSamples() {
        let perf = ModelTaskPerformance(
            modelId: "claude", taskType: .factual
        )
        XCTAssertEqual(perf.successRate, 0.5, "Default should be 50%")
    }

    func testSuccessRateAllSuccess() {
        var perf = ModelTaskPerformance(
            modelId: "claude", taskType: .analysis
        )
        for _ in 0..<10 {
            perf.recordOutcome(
                success: true, quality: nil,
                latency: 0.5, tokens: 100, cost: 0.01
            )
        }
        XCTAssertEqual(perf.successRate, 1.0)
    }

    func testSuccessRateAllFailure() {
        var perf = ModelTaskPerformance(
            modelId: "model-x", taskType: .debugging
        )
        for _ in 0..<5 {
            perf.recordOutcome(
                success: false, quality: nil,
                latency: 1.0, tokens: 50, cost: 0.005
            )
        }
        XCTAssertEqual(perf.successRate, 0.0)
    }

    func testSuccessRateMixed() {
        var perf = ModelTaskPerformance(
            modelId: "model-y", taskType: .creative
        )
        perf.recordOutcome(
            success: true, quality: nil,
            latency: 1.0, tokens: 100, cost: 0.01
        )
        perf.recordOutcome(
            success: false, quality: nil,
            latency: 2.0, tokens: 50, cost: 0.005
        )
        perf.recordOutcome(
            success: true, quality: nil,
            latency: 0.5, tokens: 75, cost: 0.008
        )
        XCTAssertEqual(
            perf.successRate, 2.0 / 3.0, accuracy: 0.001
        )
    }

    func testAverageLatencyNoSamples() {
        let perf = ModelTaskPerformance(
            modelId: "test", taskType: .math
        )
        XCTAssertEqual(perf.averageLatency, 0)
    }

    func testAverageLatencyWithSamples() {
        var perf = ModelTaskPerformance(
            modelId: "test", taskType: .translation
        )
        perf.recordOutcome(
            success: true, quality: nil,
            latency: 1.0, tokens: 100, cost: 0.01
        )
        perf.recordOutcome(
            success: true, quality: nil,
            latency: 3.0, tokens: 200, cost: 0.02
        )
        XCTAssertEqual(perf.averageLatency, 2.0, accuracy: 0.001)
    }

    func testAverageLatencyIncludesFailures() {
        var perf = ModelTaskPerformance(
            modelId: "test", taskType: .system
        )
        perf.recordOutcome(
            success: true, quality: nil,
            latency: 1.0, tokens: 100, cost: 0.01
        )
        perf.recordOutcome(
            success: false, quality: nil,
            latency: 5.0, tokens: 50, cost: 0.005
        )
        // Average includes both success and failure
        XCTAssertEqual(perf.averageLatency, 3.0, accuracy: 0.001)
    }

    func testAverageQualityNoSamples() {
        let perf = ModelTaskPerformance(
            modelId: "test", taskType: .research
        )
        XCTAssertNil(perf.averageQuality)
    }

    func testAverageQualityWithSamples() {
        var perf = ModelTaskPerformance(
            modelId: "test", taskType: .summarization
        )
        perf.recordOutcome(
            success: true, quality: 0.8,
            latency: 1.0, tokens: 100, cost: 0.01
        )
        perf.recordOutcome(
            success: true, quality: 0.6,
            latency: 1.0, tokens: 100, cost: 0.01
        )
        XCTAssertEqual(perf.averageQuality!, 0.7, accuracy: 0.001)
    }

    func testAverageQualitySkipsNilQuality() {
        var perf = ModelTaskPerformance(
            modelId: "test", taskType: .planning
        )
        perf.recordOutcome(
            success: true, quality: 0.9,
            latency: 1.0, tokens: 100, cost: 0.01
        )
        perf.recordOutcome(
            success: true, quality: nil,
            latency: 1.0, tokens: 100, cost: 0.01
        )
        // Only the one with quality counts
        XCTAssertEqual(perf.averageQuality!, 0.9, accuracy: 0.001)
        XCTAssertEqual(perf.qualityCount, 1)
    }

    func testRecordOutcomeAccumulatesTokens() {
        var perf = ModelTaskPerformance(
            modelId: "test", taskType: .conversation
        )
        perf.recordOutcome(
            success: true, quality: nil,
            latency: 0.5, tokens: 100, cost: 0.01
        )
        perf.recordOutcome(
            success: true, quality: nil,
            latency: 0.5, tokens: 250, cost: 0.02
        )
        XCTAssertEqual(perf.totalTokens, 350)
    }

    func testRecordOutcomeAccumulatesCost() {
        var perf = ModelTaskPerformance(
            modelId: "test", taskType: .factual
        )
        perf.recordOutcome(
            success: true, quality: nil,
            latency: 0.5, tokens: 100, cost: Decimal(string: "0.015")!
        )
        perf.recordOutcome(
            success: true, quality: nil,
            latency: 0.5, tokens: 100, cost: Decimal(string: "0.025")!
        )
        XCTAssertEqual(perf.totalCost, Decimal(string: "0.040")!)
    }

    func testCodableRoundTrip() throws {
        var perf = ModelTaskPerformance(
            modelId: "claude-3-opus", taskType: .codeAnalysis
        )
        perf.recordOutcome(
            success: true, quality: 0.95,
            latency: 2.5, tokens: 500, cost: 0.05
        )
        let data = try JSONEncoder().encode(perf)
        let decoded = try JSONDecoder().decode(
            ModelTaskPerformance.self, from: data
        )
        XCTAssertEqual(decoded.modelId, "claude-3-opus")
        XCTAssertEqual(decoded.taskType, .codeAnalysis)
        XCTAssertEqual(decoded.successCount, 1)
        XCTAssertEqual(decoded.failureCount, 0)
        XCTAssertEqual(decoded.totalTokens, 500)
        XCTAssertEqual(decoded.qualitySum, 0.95, accuracy: 0.001)
        XCTAssertEqual(decoded.qualityCount, 1)
    }
}
