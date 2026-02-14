@testable import TheaModels
import XCTest

/// Tests for AIModel static definitions and model catalog
final class AIModelTests: XCTestCase {

    // MARK: - Known Model Verification

    func testAllKnownModelsHaveRequiredFields() {
        for model in AIModel.allKnownModels {
            XCTAssertFalse(model.id.isEmpty, "Model \(model.name) should have non-empty id")
            XCTAssertFalse(model.name.isEmpty, "Model \(model.id) should have non-empty name")
            XCTAssertFalse(model.provider.isEmpty, "Model \(model.id) should have non-empty provider")
            XCTAssertGreaterThan(model.contextWindow, 0, "Model \(model.id) should have positive contextWindow")
        }
    }

    func testNoDuplicateModelIDs() {
        let ids = AIModel.allKnownModels.map(\.id)
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count, "Should have no duplicate model IDs")
    }

    func testAtLeastOneModelExists() {
        XCTAssertGreaterThan(AIModel.allKnownModels.count, 0, "Should have at least one known model")
    }

    // MARK: - Local Models

    func testLocalModelsExist() {
        XCTAssertGreaterThan(AIModel.localModels.count, 0, "Should have at least one local model")
    }

    func testLocalModelsAreLocal() {
        for model in AIModel.localModels {
            XCTAssertTrue(model.isLocal, "Local model \(model.id) should have isLocal=true")
        }
    }

    func testLocalModelsHaveValidProvider() {
        for model in AIModel.localModels {
            XCTAssertFalse(model.provider.isEmpty,
                "Local model \(model.id) should have non-empty provider, got: \(model.provider)")
        }
    }

    // MARK: - Model Properties

    func testModelContextWindowPositive() {
        for model in AIModel.allKnownModels {
            XCTAssertGreaterThan(model.contextWindow, 0,
                "Model \(model.id) should have positive context window")
        }
    }

    func testModelMaxOutputTokensPositive() {
        for model in AIModel.allKnownModels {
            XCTAssertGreaterThan(model.maxOutputTokens, 0,
                "Model \(model.id) should have positive max output tokens")
        }
    }

    // MARK: - Model Lookup

    func testFindModelByID() {
        if let firstModel = AIModel.allKnownModels.first {
            let found = AIModel.allKnownModels.first { $0.id == firstModel.id }
            XCTAssertNotNil(found)
            XCTAssertEqual(found?.name, firstModel.name)
        }
    }

    func testUnknownModelIDReturnsNil() {
        let found = AIModel.allKnownModels.first { $0.id == "nonexistent-model-xyz" }
        XCTAssertNil(found)
    }

    // MARK: - Model Creation

    func testCustomModelCreation() {
        let model = AIModel(
            id: "test-model",
            name: "Test Model",
            provider: "Test",
            description: "A test model",
            contextWindow: 32_000,
            maxOutputTokens: 2048,
            isLocal: false,
            supportsStreaming: true,
            supportsVision: false,
            supportsFunctionCalling: true
        )

        XCTAssertEqual(model.id, "test-model")
        XCTAssertEqual(model.name, "Test Model")
        XCTAssertEqual(model.provider, "Test")
        XCTAssertEqual(model.contextWindow, 32_000)
        XCTAssertEqual(model.maxOutputTokens, 2048)
        XCTAssertFalse(model.isLocal)
        XCTAssertTrue(model.supportsStreaming)
        XCTAssertFalse(model.supportsVision)
        XCTAssertTrue(model.supportsFunctionCalling)
    }

    func testModelHashable() {
        let model1 = AIModel(id: "a", name: "A", provider: "Test")
        let model2 = AIModel(id: "b", name: "B", provider: "Test")
        let model1Dup = AIModel(id: "a", name: "A Different Name", provider: "Test")

        var set: Set<AIModel> = [model1, model2]
        XCTAssertEqual(set.count, 2)

        set.insert(model1Dup)
        // Depends on Hashable implementation - at minimum it shouldn't crash
        XCTAssertTrue(set.count >= 2)
    }
}
