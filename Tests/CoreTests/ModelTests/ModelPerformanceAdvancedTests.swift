@testable import TheaModels
import XCTest

/// Advanced tests for ModelPerformance: latency averaging, cost accumulation,
/// mixed success/failure sequences, edge cases, and Codable precision.
final class ModelPerformanceAdvancedTests: XCTestCase {

    // MARK: - Latency Running Average

    func testLatencyAverageSingleCall() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 100, cost: 0, latency: 2.5)
        XCTAssertEqual(perf.averageLatency, 2.5, accuracy: 0.001)
    }

    func testLatencyAverageThreeCalls() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 10, cost: 0, latency: 1.0)
        perf.recordSuccess(tokens: 10, cost: 0, latency: 2.0)
        perf.recordSuccess(tokens: 10, cost: 0, latency: 3.0)
        // Average of 1.0, 2.0, 3.0 = 2.0
        XCTAssertEqual(perf.averageLatency, 2.0, accuracy: 0.001)
    }

    func testLatencyAverageAfterFailure() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 10, cost: 0, latency: 1.0)
        perf.recordFailure() // failureCount=1, affects totalCalls denominator
        perf.recordSuccess(tokens: 10, cost: 0, latency: 5.0)
        // totalCalls after second success = successCount(2) + failureCount(1) = 3
        // averageLatency = ((prev_avg * 2) + 5.0) / 3
        // After first success: avg = 1.0, totalCalls was 1
        // After failure: avg unchanged = 1.0
        // After second success: totalCalls = 3, avg = (1.0 * 2 + 5.0) / 3 = 7/3 ≈ 2.333
        XCTAssertEqual(perf.averageLatency, 7.0 / 3.0, accuracy: 0.01)
    }

    func testLatencyAverageZeroLatency() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 10, cost: 0, latency: 0.0)
        XCTAssertEqual(perf.averageLatency, 0.0)
    }

    func testLatencyAverageVeryHighLatency() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 10, cost: 0, latency: 120.0) // 2 minutes
        XCTAssertEqual(perf.averageLatency, 120.0, accuracy: 0.001)
    }

    // MARK: - Cost Accumulation

    func testCostAccumulationPrecision() {
        var perf = ModelPerformance(modelId: "m")
        let cost = Decimal(string: "0.001")!
        for _ in 0..<1000 {
            perf.recordSuccess(tokens: 10, cost: cost, latency: 0.1)
        }
        // 0.001 * 1000 = 1.0
        XCTAssertEqual(perf.totalCost, Decimal(1))
    }

    func testCostAccumulationSmallAmounts() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 10, cost: Decimal(string: "0.00001")!, latency: 0.1)
        perf.recordSuccess(tokens: 10, cost: Decimal(string: "0.00002")!, latency: 0.1)
        XCTAssertEqual(perf.totalCost, Decimal(string: "0.00003"))
    }

    func testZeroCostAccumulation() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 100, cost: 0, latency: 0.5)
        perf.recordSuccess(tokens: 200, cost: 0, latency: 0.5)
        XCTAssertEqual(perf.totalCost, 0)
    }

    // MARK: - Token Accumulation

    func testTokenAccumulationLargeValues() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 100_000, cost: 0, latency: 0.5)
        perf.recordSuccess(tokens: 200_000, cost: 0, latency: 0.5)
        XCTAssertEqual(perf.totalTokens, 300_000)
    }

    func testTokenAccumulationZeroTokens() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 0, cost: 0, latency: 0.5)
        XCTAssertEqual(perf.totalTokens, 0)
        XCTAssertEqual(perf.successCount, 1)
    }

    // MARK: - Success Rate Edge Cases

    func testSuccessRateOneSuccess() {
        let perf = ModelPerformance(modelId: "m", successCount: 1, failureCount: 0)
        XCTAssertEqual(perf.successRate, 1.0)
    }

    func testSuccessRateOneFailure() {
        let perf = ModelPerformance(modelId: "m", successCount: 0, failureCount: 1)
        XCTAssertEqual(perf.successRate, 0.0)
    }

    func testSuccessRateEqualSuccessAndFailure() {
        let perf = ModelPerformance(modelId: "m", successCount: 50, failureCount: 50)
        XCTAssertEqual(perf.successRate, 0.5, accuracy: 0.001)
    }

    func testSuccessRateHighVolume() {
        let perf = ModelPerformance(modelId: "m", successCount: 999, failureCount: 1)
        XCTAssertEqual(perf.successRate, 0.999, accuracy: 0.0001)
    }

    func testSuccessRateAfterMixedRecording() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 10, cost: 0, latency: 0.1)
        perf.recordSuccess(tokens: 10, cost: 0, latency: 0.1)
        perf.recordFailure()
        // 2 success, 1 failure = 2/3
        XCTAssertEqual(perf.successRate, 2.0 / 3.0, accuracy: 0.001)
    }

    // MARK: - lastUsed Updates

    func testLastUsedUpdatesOnSuccess() {
        let oldDate = Date(timeIntervalSince1970: 0)
        var perf = ModelPerformance(modelId: "m", lastUsed: oldDate)
        let before = Date()
        perf.recordSuccess(tokens: 10, cost: 0, latency: 0.1)
        XCTAssertGreaterThanOrEqual(perf.lastUsed, before)
    }

    func testLastUsedUpdatesOnFailure() {
        let oldDate = Date(timeIntervalSince1970: 0)
        var perf = ModelPerformance(modelId: "m", lastUsed: oldDate)
        let before = Date()
        perf.recordFailure()
        XCTAssertGreaterThanOrEqual(perf.lastUsed, before)
    }

    // MARK: - Codable Precision

    func testCodablePreservesDecimalPrecision() throws {
        var perf = ModelPerformance(modelId: "claude-test")
        perf.recordSuccess(
            tokens: 1500,
            cost: Decimal(string: "0.123456789")!,
            latency: 1.234
        )
        let data = try JSONEncoder().encode(perf)
        let decoded = try JSONDecoder().decode(ModelPerformance.self, from: data)
        XCTAssertEqual(decoded.totalCost, Decimal(string: "0.123456789"))
    }

    func testCodablePreservesAllFields() throws {
        var perf = ModelPerformance(
            modelId: "test-model-123",
            successCount: 42,
            failureCount: 3,
            totalTokens: 50_000,
            totalCost: Decimal(string: "1.5")!,
            averageLatency: 2.345
        )
        perf.recordSuccess(tokens: 100, cost: Decimal(string: "0.01")!, latency: 1.0)

        let data = try JSONEncoder().encode(perf)
        let decoded = try JSONDecoder().decode(ModelPerformance.self, from: data)

        XCTAssertEqual(decoded.modelId, perf.modelId)
        XCTAssertEqual(decoded.successCount, perf.successCount)
        XCTAssertEqual(decoded.failureCount, perf.failureCount)
        XCTAssertEqual(decoded.totalTokens, perf.totalTokens)
        XCTAssertEqual(decoded.totalCost, perf.totalCost)
        XCTAssertEqual(decoded.averageLatency, perf.averageLatency, accuracy: 0.001)
    }

    // MARK: - Failure Does Not Affect Tokens/Cost

    func testMultipleFailuresDoNotAffectCost() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 100, cost: Decimal(string: "0.05")!, latency: 1.0)
        for _ in 0..<10 {
            perf.recordFailure()
        }
        XCTAssertEqual(perf.totalTokens, 100)
        XCTAssertEqual(perf.totalCost, Decimal(string: "0.05"))
        XCTAssertEqual(perf.failureCount, 10)
    }
}
