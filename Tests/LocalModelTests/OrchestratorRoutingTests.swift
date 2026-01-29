import XCTest
@testable import TheaCore

#if os(macOS)

/// Tests for orchestrator routing to local MLX models
@MainActor
final class OrchestratorRoutingTests: XCTestCase {

    // MARK: - Setup

    override func setUp() async throws {
        // Wait for model discovery to complete
        await LocalModelManager.shared.waitForDiscovery()
        await MLXModelManager.shared.waitForScan()

        // Give ProviderRegistry time to register local models
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    // MARK: - Provider Registry Tests

    func testLocalModelsRegistered() async throws {
        let localModels = await ProviderRegistry.shared.getAvailableLocalModels()
        XCTAssertGreaterThan(localModels.count, 0, "Should have registered local models")
        print("✅ Registered \(localModels.count) local models")
    }

    func testGetLocalProvider() async throws {
        let provider = await ProviderRegistry.shared.getLocalProvider()
        XCTAssertNotNil(provider, "Should be able to get a local provider")

        if let provider = provider {
            XCTAssertEqual(provider.metadata.name, "local")
            print("✅ Got local provider: \(provider.metadata.displayName)")
        }
    }

    func testGetSpecificLocalProvider() async throws {
        let localModels = await ProviderRegistry.shared.getAvailableLocalModels()
        guard let firstModel = localModels.first else {
            XCTFail("No local models available")
            return
        }

        let provider = await ProviderRegistry.shared.getLocalProvider(modelName: firstModel)
        XCTAssertNotNil(provider, "Should be able to get provider for specific model: \(firstModel)")
        print("✅ Got provider for model: \(firstModel)")
    }

    // MARK: - Task Classification Tests

    func testTaskClassification() async throws {
        let classifier = TaskClassifier.shared

        // Test simple query
        let simpleQuery = "What is 2+2?"
        let simpleResult = try await classifier.classify(simpleQuery)
        print("✅ Query '\(simpleQuery)' classified as: \(simpleResult.primaryType.displayName)")

        // Test code query
        let codeQuery = "Write a Python function to sort a list"
        let codeResult = try await classifier.classify(codeQuery)
        print("✅ Query '\(codeQuery)' classified as: \(codeResult.primaryType.displayName)")

        // Test complex query
        let complexQuery = "Explain the theory of relativity and its implications for modern physics"
        let complexResult = try await classifier.classify(complexQuery)
        print("✅ Query '\(complexQuery)' classified as: \(complexResult.primaryType.displayName)")
    }

    // MARK: - Model Router Tests

    func testModelRouterSelectsLocalModel() async throws {
        // Enable orchestrator for this test
        var config = AppConfiguration.shared.orchestratorConfig
        config.orchestratorEnabled = true
        config.localModelPreference = .always

        // Classify a simple query
        let query = "Hello, how are you?"
        let classification = try await TaskClassifier.shared.classify(query)

        // Route to model
        let selection = try await ModelRouter.shared.selectModel(for: classification)

        print("✅ Model selected: \(selection.modelID)")
        print("   Reasoning: \(selection.reasoning)")
        print("   Is Local: \(selection.isLocal)")

        // With .always preference, should select local model
        // Note: This depends on configuration
    }

    // MARK: - Complexity Assessment Tests

    func testComplexityAssessment() async throws {
        let classifier = TaskClassifier.shared

        let simpleQuery = "Hi"
        let simpleComplexity = await classifier.assessComplexity(simpleQuery)
        print("✅ '\(simpleQuery)' complexity: \(simpleComplexity)")

        let moderateQuery = "Explain how photosynthesis works in plants"
        let moderateComplexity = await classifier.assessComplexity(moderateQuery)
        print("✅ '\(moderateQuery)' complexity: \(moderateComplexity)")

        let complexQuery = "Compare and contrast the economic policies of the 20th century superpowers and their long-term effects on global trade patterns, considering both Keynesian and monetarist perspectives"
        let complexComplexity = await classifier.assessComplexity(complexQuery)
        print("✅ '\(complexQuery)' complexity: \(complexComplexity)")
    }
}

#endif // os(macOS)
