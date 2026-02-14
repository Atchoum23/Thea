@testable import TheaModels
import XCTest

/// Tests for AI capability model definitions across all phases.
/// Verifies that local models (GPT-OSS, Qwen3-VL, Gemma 3) are
/// properly registered with correct capabilities.
final class AICapabilityTests: XCTestCase {

    // MARK: - Phase 1: GPT-OSS 20B

    func testGPTOSS20BExists() {
        let model = AIModel.localModels.first { $0.id == "gpt-oss-20b" }
        XCTAssertNotNil(model, "GPT-OSS 20B should be in localModels")
    }

    func testGPTOSS20BProperties() {
        let model = AIModel.gptOSS20B
        XCTAssertEqual(model.name, "GPT-OSS 20B")
        XCTAssertTrue(model.isLocal)
        XCTAssertEqual(model.contextWindow, 128_000)
        XCTAssertTrue(model.supportsFunctionCalling)
        XCTAssertEqual(model.provider, "local")
    }

    func testGPTOSS120BExists() {
        let model = AIModel.localModels.first { $0.id == "gpt-oss-120b" }
        XCTAssertNotNil(model, "GPT-OSS 120B should be in localModels")
    }

    func testGPTOSS120BProperties() {
        let model = AIModel.gptOSS120B
        XCTAssertEqual(model.name, "GPT-OSS 120B")
        XCTAssertTrue(model.isLocal)
        XCTAssertEqual(model.contextWindow, 128_000)
        XCTAssertTrue(model.supportsFunctionCalling)
    }

    // MARK: - Phase 2: Qwen3-VL 8B

    func testQwen3VL8BExists() {
        let model = AIModel.localModels.first { $0.id == "qwen3-vl-8b" }
        XCTAssertNotNil(model, "Qwen3-VL 8B should be in localModels")
    }

    func testQwen3VL8BProperties() {
        let model = AIModel.qwen3VL8B
        XCTAssertEqual(model.name, "Qwen3-VL 8B")
        XCTAssertTrue(model.isLocal)
        XCTAssertTrue(model.supportsVision)
        XCTAssertEqual(model.contextWindow, 32_768)
    }

    // MARK: - Phase 5: Gemma 3

    func testGemma3_1BExists() {
        let model = AIModel.localModels.first { $0.id == "gemma-3-1b-it" }
        XCTAssertNotNil(model, "Gemma 3 1B should be in localModels")
    }

    func testGemma3_1BProperties() {
        let model = AIModel.gemma3_1B
        XCTAssertEqual(model.name, "Gemma 3 1B")
        XCTAssertTrue(model.isLocal)
        XCTAssertFalse(model.supportsVision, "1B is text-only")
        XCTAssertEqual(model.contextWindow, 32_768)
    }

    func testGemma3_4BExists() {
        let model = AIModel.localModels.first { $0.id == "gemma-3-4b-it" }
        XCTAssertNotNil(model, "Gemma 3 4B should be in localModels")
    }

    func testGemma3_4BProperties() {
        let model = AIModel.gemma3_4B
        XCTAssertEqual(model.name, "Gemma 3 4B")
        XCTAssertTrue(model.isLocal)
        XCTAssertTrue(model.supportsVision, "4B supports vision")
        XCTAssertEqual(model.contextWindow, 128_000)
    }

    // MARK: - Local Models Collection

    func testLocalModelsContainsAllExpected() {
        let localIDs = AIModel.localModels.map(\.id)
        XCTAssertTrue(localIDs.contains("gpt-oss-20b"), "Should contain GPT-OSS 20B")
        XCTAssertTrue(localIDs.contains("gpt-oss-120b"), "Should contain GPT-OSS 120B")
        XCTAssertTrue(localIDs.contains("qwen3-vl-8b"), "Should contain Qwen3-VL 8B")
        XCTAssertTrue(localIDs.contains("gemma-3-1b-it"), "Should contain Gemma 3 1B")
        XCTAssertTrue(localIDs.contains("gemma-3-4b-it"), "Should contain Gemma 3 4B")
    }

    func testLocalModelsInAllKnownModels() {
        let allIDs = Set(AIModel.allKnownModels.map(\.id))
        for model in AIModel.localModels {
            XCTAssertTrue(allIDs.contains(model.id), "\(model.id) should be in allKnownModels")
        }
    }

    func testAllLocalModelsAreLocal() {
        for model in AIModel.localModels {
            XCTAssertTrue(model.isLocal, "\(model.id) should have isLocal=true")
            XCTAssertEqual(model.provider, "local", "\(model.id) should have provider='local'")
        }
    }

    func testLocalModelsHavePositiveContextWindows() {
        for model in AIModel.localModels {
            XCTAssertGreaterThan(model.contextWindow, 0, "\(model.id) should have positive context window")
        }
    }

    func testLocalModelsHavePositiveMaxOutputTokens() {
        for model in AIModel.localModels {
            XCTAssertGreaterThan(model.maxOutputTokens, 0, "\(model.id) should have positive max output tokens")
        }
    }

    // MARK: - Vision Model Detection

    func testVisionModelsIdentifiable() {
        let visionModels = AIModel.localModels.filter(\.supportsVision)
        XCTAssertGreaterThanOrEqual(visionModels.count, 2, "Should have at least 2 vision-capable local models")

        let visionIDs = visionModels.map(\.id)
        XCTAssertTrue(visionIDs.contains("qwen3-vl-8b"))
        XCTAssertTrue(visionIDs.contains("gemma-3-4b-it"))
    }

    func testFunctionCallingModelsIdentifiable() {
        let fcModels = AIModel.localModels.filter(\.supportsFunctionCalling)
        XCTAssertGreaterThanOrEqual(fcModels.count, 2, "Should have at least 2 function-calling local models")

        let fcIDs = fcModels.map(\.id)
        XCTAssertTrue(fcIDs.contains("gpt-oss-20b"))
        XCTAssertTrue(fcIDs.contains("gpt-oss-120b"))
    }

    // MARK: - Model Performance Tracking

    func testModelPerformanceInit() {
        let perf = ModelPerformance(modelId: "test-model")
        XCTAssertEqual(perf.modelId, "test-model")
        XCTAssertEqual(perf.successCount, 0)
        XCTAssertEqual(perf.failureCount, 0)
        XCTAssertEqual(perf.successRate, 0)
    }

    func testModelPerformanceRecordSuccess() {
        var perf = ModelPerformance(modelId: "test")
        perf.recordSuccess(tokens: 100, cost: 0.01, latency: 0.5)
        XCTAssertEqual(perf.successCount, 1)
        XCTAssertEqual(perf.totalTokens, 100)
        XCTAssertEqual(perf.successRate, 1.0)
    }

    func testModelPerformanceRecordFailure() {
        var perf = ModelPerformance(modelId: "test")
        perf.recordSuccess(tokens: 100, cost: 0.01, latency: 0.5)
        perf.recordFailure()
        XCTAssertEqual(perf.successCount, 1)
        XCTAssertEqual(perf.failureCount, 1)
        XCTAssertEqual(perf.successRate, 0.5)
    }

    func testModelPerformanceMultipleRecords() {
        var perf = ModelPerformance(modelId: "test")
        for _ in 0..<8 { perf.recordSuccess(tokens: 50, cost: 0.005, latency: 0.3) }
        for _ in 0..<2 { perf.recordFailure() }

        XCTAssertEqual(perf.successCount, 8)
        XCTAssertEqual(perf.failureCount, 2)
        XCTAssertEqual(perf.totalTokens, 400)
        XCTAssertEqual(perf.successRate, 0.8, accuracy: 0.001)
    }
}
