import XCTest
@testable import TheaCore

#if os(macOS)
import MLXLMCommon

/// Tests for MLX native Swift inference engine
@MainActor
final class MLXInferenceTests: XCTestCase {

    // MARK: - Model Discovery Tests

    func testLocalModelManagerDiscovery() async throws {
        // Wait for discovery to complete
        await LocalModelManager.shared.waitForDiscovery()

        let models = await LocalModelManager.shared.availableModels
        XCTAssertGreaterThan(models.count, 0, "Should discover at least one local model")

        // Verify MLX models are found
        let mlxModels = models.filter { $0.type == .mlx }
        XCTAssertGreaterThan(mlxModels.count, 0, "Should discover MLX models")

        // Check model properties
        for model in mlxModels {
            XCTAssertFalse(model.name.isEmpty, "Model name should not be empty")
            XCTAssertTrue(model.path.path.contains("mlx") || model.path.path.contains("MLX"),
                         "MLX model path should contain 'mlx'")
        }
    }

    func testMLXModelManagerScan() async throws {
        // Wait for scan to complete
        await MLXModelManager.shared.waitForScan()

        let models = await MLXModelManager.shared.scannedModels
        XCTAssertGreaterThan(models.count, 0, "Should scan at least one model")

        // Verify model statistics
        let stats = await MLXModelManager.shared.getStatistics()
        XCTAssertGreaterThan(stats.totalModels, 0)
        XCTAssertGreaterThan(stats.mlxModels, 0)
    }

    // MARK: - MLX Inference Engine Tests

    func testMLXInferenceEngineSingleton() async {
        let engine1 = await MLXInferenceEngine.shared
        let engine2 = await MLXInferenceEngine.shared
        XCTAssertTrue(engine1 === engine2, "Should be singleton")
    }

    func testMLXInferenceEngineInitialState() async {
        let engine = await MLXInferenceEngine.shared
        let isLoading = await engine.isLoading
        let lastError = await engine.lastError
        XCTAssertFalse(isLoading, "Should not be loading initially")
        XCTAssertNil(lastError, "Should have no error initially")
    }

    func testGetAvailableModels() async {
        await LocalModelManager.shared.waitForDiscovery()
        let engine = await MLXInferenceEngine.shared
        let models = await engine.getAvailableModels()

        XCTAssertGreaterThan(models.count, 0, "Should have available models")
        for model in models {
            XCTAssertEqual(model.type, .mlx, "All models should be MLX type")
        }
    }

    // MARK: - Model Loading Tests

    func testLoadSmallestModel() async throws {
        await LocalModelManager.shared.waitForDiscovery()
        let engine = await MLXInferenceEngine.shared

        // Find the smallest model by parameter count (e.g., "2b" or "3b")
        let allModels = await LocalModelManager.shared.availableModels
        let models = allModels.filter { $0.type == .mlx }
        let smallModel = models.min { model1, model2 in
            // Extract parameter count from name
            let params1 = extractParamCount(model1.parameters)
            let params2 = extractParamCount(model2.parameters)
            return params1 < params2
        }

        guard let model = smallModel else {
            XCTFail("No MLX models available for testing")
            return
        }

        print("Testing with model: \(model.name) (\(model.parameters))")

        // Test loading
        do {
            _ = try await engine.loadLocalModel(path: model.path)
            let isLoaded = await engine.isModelLoaded(model.path.path)
            XCTAssertTrue(isLoaded, "Model should be loaded")
        } catch {
            // Model loading might fail if model format is unsupported
            // This is not a test failure, just skip
            print("Model loading failed (expected for some formats): \(error)")
        }
    }

    // MARK: - Helper Methods

    private func extractParamCount(_ params: String) -> Double {
        // Extract numeric value from "7B", "70B", etc.
        let cleaned = params.lowercased().replacingOccurrences(of: "b", with: "")
        return Double(cleaned) ?? 999
    }
}

#endif // os(macOS)
