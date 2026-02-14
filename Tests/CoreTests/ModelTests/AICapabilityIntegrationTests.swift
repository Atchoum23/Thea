@testable import TheaModels
import XCTest

/// Integration tests for AI capability upgrade model catalog.
/// Validates that all new AI models (GPT-OSS, Qwen3-VL, Gemma 3) are properly
/// defined in the model catalog with correct capabilities and metadata.
final class AICapabilityIntegrationTests: XCTestCase {

    // MARK: - Phase 1: GPT-OSS Models

    func testGPTOSS20BExists() {
        let model = AIModel.gptOSS20B
        XCTAssertEqual(model.id, "gpt-oss-20b")
        XCTAssertEqual(model.name, "GPT-OSS 20B")
        XCTAssertEqual(model.provider, "local")
        XCTAssertTrue(model.isLocal)
    }

    func testGPTOSS20BCapabilities() {
        let model = AIModel.gptOSS20B
        XCTAssertEqual(model.contextWindow, 128_000)
        XCTAssertTrue(model.supportsFunctionCalling)
        XCTAssertTrue(model.capabilities.contains(.chat))
        XCTAssertTrue(model.capabilities.contains(.codeGeneration))
        XCTAssertTrue(model.capabilities.contains(.reasoning))
        XCTAssertTrue(model.capabilities.contains(.functionCalling))
    }

    func testGPTOSS120BExists() {
        let model = AIModel.gptOSS120B
        XCTAssertEqual(model.id, "gpt-oss-120b")
        XCTAssertEqual(model.name, "GPT-OSS 120B")
        XCTAssertEqual(model.provider, "local")
        XCTAssertTrue(model.isLocal)
    }

    func testGPTOSS120BHasAnalysisCapability() {
        let model = AIModel.gptOSS120B
        XCTAssertTrue(model.capabilities.contains(.analysis),
            "120B model should have analysis capability beyond 20B")
        XCTAssertTrue(model.supportsFunctionCalling)
    }

    func testGPTOSSModelsInLocalModels() {
        let localIDs = AIModel.localModels.map(\.id)
        XCTAssertTrue(localIDs.contains("gpt-oss-20b"), "localModels should include GPT-OSS 20B")
        XCTAssertTrue(localIDs.contains("gpt-oss-120b"), "localModels should include GPT-OSS 120B")
    }

    // MARK: - Phase 2: Qwen3-VL 8B

    func testQwen3VL8BExists() {
        let model = AIModel.qwen3VL8B
        XCTAssertEqual(model.id, "qwen3-vl-8b")
        XCTAssertEqual(model.name, "Qwen3-VL 8B")
        XCTAssertEqual(model.provider, "local")
        XCTAssertTrue(model.isLocal)
    }

    func testQwen3VL8BSupportsVision() {
        let model = AIModel.qwen3VL8B
        XCTAssertTrue(model.supportsVision, "Qwen3-VL should support vision")
        XCTAssertTrue(model.capabilities.contains(.vision))
        XCTAssertTrue(model.capabilities.contains(.multimodal))
    }

    func testQwen3VL8BContextWindow() {
        let model = AIModel.qwen3VL8B
        XCTAssertEqual(model.contextWindow, 32_768)
        XCTAssertEqual(model.maxOutputTokens, 8192)
    }

    func testQwen3VL8BInLocalModels() {
        let localIDs = AIModel.localModels.map(\.id)
        XCTAssertTrue(localIDs.contains("qwen3-vl-8b"), "localModels should include Qwen3-VL")
    }

    // MARK: - Phase 5: Gemma 3 CoreML

    func testGemma3_1BExists() {
        let model = AIModel.gemma3_1B
        XCTAssertEqual(model.id, "gemma-3-1b-it")
        XCTAssertEqual(model.name, "Gemma 3 1B")
        XCTAssertEqual(model.provider, "local")
        XCTAssertTrue(model.isLocal)
    }

    func testGemma3_1BLightweight() {
        let model = AIModel.gemma3_1B
        // 1B is text-only — no vision
        XCTAssertFalse(model.supportsVision, "Gemma 3 1B is text-only")
        XCTAssertTrue(model.capabilities.contains(.chat))
        XCTAssertTrue(model.capabilities.contains(.reasoning))
    }

    func testGemma3_4BExists() {
        let model = AIModel.gemma3_4B
        XCTAssertEqual(model.id, "gemma-3-4b-it")
        XCTAssertEqual(model.name, "Gemma 3 4B")
        XCTAssertEqual(model.provider, "local")
        XCTAssertTrue(model.isLocal)
    }

    func testGemma3_4BMultimodal() {
        let model = AIModel.gemma3_4B
        // 4B supports multimodal
        XCTAssertTrue(model.supportsVision, "Gemma 3 4B should support vision")
        XCTAssertTrue(model.capabilities.contains(.vision))
        XCTAssertTrue(model.capabilities.contains(.multimodal))
        XCTAssertEqual(model.contextWindow, 128_000)
    }

    func testGemma3ModelsInLocalModels() {
        let localIDs = AIModel.localModels.map(\.id)
        XCTAssertTrue(localIDs.contains("gemma-3-1b-it"), "localModels should include Gemma 3 1B")
        XCTAssertTrue(localIDs.contains("gemma-3-4b-it"), "localModels should include Gemma 3 4B")
    }

    // MARK: - Cross-Phase: Model Catalog Integrity

    func testAllLocalModelsInAllKnownModels() {
        let allIDs = Set(AIModel.allKnownModels.map(\.id))
        for local in AIModel.localModels {
            XCTAssertTrue(allIDs.contains(local.id),
                "Local model \(local.id) should be in allKnownModels")
        }
    }

    func testLocalModelCount() {
        XCTAssertEqual(AIModel.localModels.count, 5,
            "Should have exactly 5 local models: GPT-OSS 20B/120B, Qwen3-VL 8B, Gemma 3 1B/4B")
    }

    func testAllLocalModelsAreLocal() {
        for model in AIModel.localModels {
            XCTAssertTrue(model.isLocal, "Model \(model.id) in localModels should be local")
            XCTAssertEqual(model.provider, "local", "Model \(model.id) should have provider=local")
        }
    }

    func testNoLocalModelHasPricing() {
        for model in AIModel.localModels {
            // Local models should not have cloud pricing
            XCTAssertNil(model.inputCostPer1K,
                "Local model \(model.id) should not have inputCostPer1K")
            XCTAssertNil(model.outputCostPer1K,
                "Local model \(model.id) should not have outputCostPer1K")
        }
    }

    func testAllLocalModelsHaveDescriptions() {
        for model in AIModel.localModels {
            XCTAssertNotNil(model.description,
                "Local model \(model.id) should have a description")
            XCTAssertFalse(model.description?.isEmpty ?? true,
                "Local model \(model.id) description should not be empty")
        }
    }

    func testVisionModelsCorrectlyMarked() {
        // Qwen3-VL and Gemma 3 4B should support vision; others should not
        let visionModels = AIModel.localModels.filter(\.supportsVision)
        let visionIDs = Set(visionModels.map(\.id))
        XCTAssertTrue(visionIDs.contains("qwen3-vl-8b"))
        XCTAssertTrue(visionIDs.contains("gemma-3-4b-it"))
        XCTAssertFalse(visionIDs.contains("gpt-oss-20b"))
        XCTAssertFalse(visionIDs.contains("gpt-oss-120b"))
        XCTAssertFalse(visionIDs.contains("gemma-3-1b-it"))
    }

    func testFunctionCallingModelsCorrectlyMarked() {
        let fcModels = AIModel.localModels.filter(\.supportsFunctionCalling)
        let fcIDs = Set(fcModels.map(\.id))
        // GPT-OSS supports function calling
        XCTAssertTrue(fcIDs.contains("gpt-oss-20b"))
        XCTAssertTrue(fcIDs.contains("gpt-oss-120b"))
    }
}
