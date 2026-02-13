@testable import TheaModels
import XCTest

final class ModelPerformanceTests: XCTestCase {

    // MARK: - Initialization

    func testModelPerformanceDefaults() {
        let perf = ModelPerformance(modelId: "test-model")
        XCTAssertEqual(perf.modelId, "test-model")
        XCTAssertEqual(perf.successCount, 0)
        XCTAssertEqual(perf.failureCount, 0)
        XCTAssertEqual(perf.totalTokens, 0)
        XCTAssertEqual(perf.totalCost, 0)
        XCTAssertEqual(perf.averageLatency, 0)
    }

    // MARK: - Success Rate

    func testSuccessRateNoRequests() {
        let perf = ModelPerformance(modelId: "m")
        XCTAssertEqual(perf.successRate, 0)
    }

    func testSuccessRateAllSuccessful() {
        let perf = ModelPerformance(modelId: "m", successCount: 10, failureCount: 0)
        XCTAssertEqual(perf.successRate, 1.0)
    }

    func testSuccessRateAllFailed() {
        let perf = ModelPerformance(modelId: "m", successCount: 0, failureCount: 10)
        XCTAssertEqual(perf.successRate, 0.0)
    }

    func testSuccessRateMixed() {
        let perf = ModelPerformance(modelId: "m", successCount: 3, failureCount: 7)
        XCTAssertEqual(perf.successRate, 0.3, accuracy: 0.001)
    }

    // MARK: - Record Success

    func testRecordSuccessIncrementsCount() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 100, cost: Decimal(string: "0.01")!, latency: 0.5)
        XCTAssertEqual(perf.successCount, 1)
        XCTAssertEqual(perf.totalTokens, 100)
        XCTAssertEqual(perf.totalCost, Decimal(string: "0.01"))
    }

    func testRecordSuccessAccumulatesTokensAndCost() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 100, cost: Decimal(string: "0.01")!, latency: 0.5)
        perf.recordSuccess(tokens: 200, cost: Decimal(string: "0.02")!, latency: 1.0)
        XCTAssertEqual(perf.successCount, 2)
        XCTAssertEqual(perf.totalTokens, 300)
        XCTAssertEqual(perf.totalCost, Decimal(string: "0.03"))
    }

    func testRecordSuccessUpdatesAverageLatency() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 10, cost: 0, latency: 1.0)
        XCTAssertEqual(perf.averageLatency, 1.0, accuracy: 0.001)

        perf.recordSuccess(tokens: 10, cost: 0, latency: 3.0)
        XCTAssertEqual(perf.averageLatency, 2.0, accuracy: 0.001)
    }

    // MARK: - Record Failure

    func testRecordFailureIncrementsCount() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordFailure()
        XCTAssertEqual(perf.failureCount, 1)
        XCTAssertEqual(perf.successCount, 0)
    }

    func testRecordFailureDoesNotAffectTokensOrCost() {
        var perf = ModelPerformance(modelId: "m")
        perf.recordSuccess(tokens: 100, cost: Decimal(string: "0.01")!, latency: 0.5)
        perf.recordFailure()
        XCTAssertEqual(perf.totalTokens, 100)
        XCTAssertEqual(perf.totalCost, Decimal(string: "0.01"))
    }

    // MARK: - Codable

    func testModelPerformanceCodableRoundtrip() throws {
        var perf = ModelPerformance(modelId: "claude-4")
        perf.recordSuccess(tokens: 500, cost: Decimal(string: "0.05")!, latency: 1.2)
        perf.recordFailure()

        let data = try JSONEncoder().encode(perf)
        let decoded = try JSONDecoder().decode(ModelPerformance.self, from: data)

        XCTAssertEqual(decoded.modelId, "claude-4")
        XCTAssertEqual(decoded.successCount, 1)
        XCTAssertEqual(decoded.failureCount, 1)
        XCTAssertEqual(decoded.totalTokens, 500)
    }

    // MARK: - ModelCapability

    func testModelCapabilityAllCases() {
        let cases = ModelCapability.allCases
        XCTAssertEqual(cases.count, 10)
        XCTAssertTrue(cases.contains(.chat))
        XCTAssertTrue(cases.contains(.vision))
        XCTAssertTrue(cases.contains(.embedding))
        XCTAssertTrue(cases.contains(.functionCalling))
    }

    func testModelCapabilityCodableRoundtrip() throws {
        for capability in ModelCapability.allCases {
            let data = try JSONEncoder().encode(capability)
            let decoded = try JSONDecoder().decode(ModelCapability.self, from: data)
            XCTAssertEqual(decoded, capability)
        }
    }

    // MARK: - ModelCategory

    func testModelCategoryAllCases() {
        let cases = ModelCategory.allCases
        XCTAssertEqual(cases.count, 6)
        XCTAssertTrue(cases.contains(.flagship))
        XCTAssertTrue(cases.contains(.local))
        XCTAssertTrue(cases.contains(.embedding))
    }

    func testModelCategoryCodableRoundtrip() throws {
        for category in ModelCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(ModelCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }

    // MARK: - AIModel Codable

    func testAIModelCodableRoundtrip() throws {
        let model = AIModel(
            id: "test-model",
            name: "Test Model",
            provider: "test",
            description: "A test model",
            contextWindow: 32_000,
            maxOutputTokens: 4096,
            capabilities: [.chat, .vision],
            inputCostPer1K: Decimal(string: "0.001"),
            outputCostPer1K: Decimal(string: "0.002"),
            isLocal: true,
            supportsStreaming: true,
            supportsVision: true,
            supportsFunctionCalling: false
        )
        let data = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(AIModel.self, from: data)

        XCTAssertEqual(decoded.id, "test-model")
        XCTAssertEqual(decoded.name, "Test Model")
        XCTAssertEqual(decoded.provider, "test")
        XCTAssertEqual(decoded.description, "A test model")
        XCTAssertEqual(decoded.contextWindow, 32_000)
        XCTAssertTrue(decoded.isLocal)
        XCTAssertTrue(decoded.supportsVision)
        XCTAssertFalse(decoded.supportsFunctionCalling)
        XCTAssertEqual(decoded.capabilities.count, 2)
    }

    func testAIModelCodableNilDescription() throws {
        let model = AIModel(
            id: "m",
            name: "M",
            provider: "p"
        )
        let data = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(AIModel.self, from: data)
        XCTAssertNil(decoded.description)
        XCTAssertNil(decoded.inputCostPer1K)
        XCTAssertNil(decoded.outputCostPer1K)
    }

    // MARK: - AIModel Equality

    func testAIModelEqualityById() {
        let model1 = AIModel(id: "same", name: "Model A", provider: "p1")
        let model2 = AIModel(id: "same", name: "Model B", provider: "p2")
        XCTAssertEqual(model1, model2, "Models with same ID should be equal")
    }

    func testAIModelInequalityByDifferentId() {
        let model1 = AIModel(id: "id-1", name: "Same Name", provider: "p")
        let model2 = AIModel(id: "id-2", name: "Same Name", provider: "p")
        XCTAssertNotEqual(model1, model2)
    }

    // MARK: - AIModel Hashable

    func testAIModelHashableInSet() {
        let model1 = AIModel(id: "a", name: "A", provider: "p")
        let model2 = AIModel(id: "a", name: "B", provider: "p")
        let model3 = AIModel(id: "b", name: "C", provider: "p")

        let set: Set<AIModel> = [model1, model2, model3]
        XCTAssertEqual(set.count, 2, "Same ID models should deduplicate in Set")
    }
}
