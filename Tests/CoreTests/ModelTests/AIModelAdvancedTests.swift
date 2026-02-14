@testable import TheaModels
import XCTest

/// Advanced tests for AIModel: model catalog integrity, provider grouping,
/// cost calculations, capability filtering, and Codable edge cases.
final class AIModelAdvancedTests: XCTestCase {

    // MARK: - Provider Model Lists Integrity

    func testAnthropicModelsAllFromAnthropic() {
        for model in AIModel.anthropicModels {
            XCTAssertEqual(model.provider, "anthropic",
                "Anthropic model \(model.id) has wrong provider: \(model.provider)")
        }
    }

    func testOpenAIModelsAllFromOpenAI() {
        for model in AIModel.openaiModels {
            XCTAssertEqual(model.provider, "openai",
                "OpenAI model \(model.id) has wrong provider: \(model.provider)")
        }
    }

    func testGoogleModelsAllFromGoogle() {
        for model in AIModel.googleModels {
            XCTAssertEqual(model.provider, "google",
                "Google model \(model.id) has wrong provider: \(model.provider)")
        }
    }

    func testDeepSeekModelsAllFromDeepSeek() {
        for model in AIModel.deepseekModels {
            XCTAssertEqual(model.provider, "deepseek",
                "DeepSeek model \(model.id) has wrong provider: \(model.provider)")
        }
    }

    func testGroqModelsAllFromGroq() {
        for model in AIModel.groqModels {
            XCTAssertEqual(model.provider, "groq",
                "Groq model \(model.id) has wrong provider: \(model.provider)")
        }
    }

    func testPerplexityModelsAllFromPerplexity() {
        for model in AIModel.perplexityModels {
            XCTAssertEqual(model.provider, "perplexity",
                "Perplexity model \(model.id) has wrong provider: \(model.provider)")
        }
    }

    func testOpenRouterModelsAllFromOpenRouter() {
        for model in AIModel.openRouterModels {
            XCTAssertEqual(model.provider, "openrouter",
                "OpenRouter model \(model.id) has wrong provider: \(model.provider)")
        }
    }

    func testLocalModelsAllLocal() {
        for model in AIModel.localModels {
            XCTAssertTrue(model.isLocal,
                "Local model \(model.id) should have isLocal=true")
        }
    }

    // MARK: - All Known Models Completeness

    func testAllKnownModelsContainsAllProviderGroups() {
        let all = Set(AIModel.allKnownModels.map(\.id))
        for model in AIModel.anthropicModels {
            XCTAssertTrue(all.contains(model.id), "allKnownModels missing anthropic: \(model.id)")
        }
        for model in AIModel.openaiModels {
            XCTAssertTrue(all.contains(model.id), "allKnownModels missing openai: \(model.id)")
        }
        for model in AIModel.googleModels {
            XCTAssertTrue(all.contains(model.id), "allKnownModels missing google: \(model.id)")
        }
        for model in AIModel.deepseekModels {
            XCTAssertTrue(all.contains(model.id), "allKnownModels missing deepseek: \(model.id)")
        }
        for model in AIModel.groqModels {
            XCTAssertTrue(all.contains(model.id), "allKnownModels missing groq: \(model.id)")
        }
        for model in AIModel.perplexityModels {
            XCTAssertTrue(all.contains(model.id), "allKnownModels missing perplexity: \(model.id)")
        }
        for model in AIModel.openRouterModels {
            XCTAssertTrue(all.contains(model.id), "allKnownModels missing openrouter: \(model.id)")
        }
        for model in AIModel.localModels {
            XCTAssertTrue(all.contains(model.id), "allKnownModels missing local: \(model.id)")
        }
    }

    func testAllKnownModelsCountMatchesSumOfGroups() {
        let sumOfGroups = AIModel.anthropicModels.count +
            AIModel.openaiModels.count +
            AIModel.googleModels.count +
            AIModel.deepseekModels.count +
            AIModel.groqModels.count +
            AIModel.perplexityModels.count +
            AIModel.openRouterModels.count +
            AIModel.localModels.count
        XCTAssertEqual(AIModel.allKnownModels.count, sumOfGroups,
            "allKnownModels count should match sum of all provider groups")
    }

    // MARK: - Cost Properties

    func testCloudModelsHaveCosts() {
        let cloudModels = AIModel.allKnownModels.filter { !$0.isLocal }
        for model in cloudModels {
            XCTAssertNotNil(model.inputCostPer1K,
                "Cloud model \(model.id) should have inputCostPer1K")
            XCTAssertNotNil(model.outputCostPer1K,
                "Cloud model \(model.id) should have outputCostPer1K")
        }
    }

    func testLocalModelsHaveNoCost() {
        for model in AIModel.localModels {
            XCTAssertNil(model.inputCostPer1K,
                "Local model \(model.id) should have nil inputCostPer1K")
            XCTAssertNil(model.outputCostPer1K,
                "Local model \(model.id) should have nil outputCostPer1K")
        }
    }

    func testCostsArePositive() {
        for model in AIModel.allKnownModels {
            if let inputCost = model.inputCostPer1K {
                XCTAssertGreaterThan(inputCost, 0,
                    "Model \(model.id) inputCostPer1K should be positive")
            }
            if let outputCost = model.outputCostPer1K {
                XCTAssertGreaterThan(outputCost, 0,
                    "Model \(model.id) outputCostPer1K should be positive")
            }
        }
    }

    // MARK: - Capability Consistency

    func testVisionModelsHaveVisionCapability() {
        for model in AIModel.allKnownModels where model.supportsVision {
            XCTAssertTrue(model.capabilities.contains(.vision),
                "Model \(model.id) has supportsVision=true but missing .vision capability")
        }
    }

    func testFunctionCallingModelsHaveCapability() {
        for model in AIModel.allKnownModels where model.supportsFunctionCalling {
            XCTAssertTrue(model.capabilities.contains(.functionCalling),
                "Model \(model.id) has supportsFunctionCalling=true but missing .functionCalling capability")
        }
    }

    func testAllModelsHaveAtLeastOneCapability() {
        for model in AIModel.allKnownModels {
            XCTAssertFalse(model.capabilities.isEmpty,
                "Model \(model.id) should have at least one capability")
        }
    }

    func testAllModelsHaveChatCapability() {
        for model in AIModel.allKnownModels {
            XCTAssertTrue(model.capabilities.contains(.chat),
                "Model \(model.id) should have .chat capability")
        }
    }

    // MARK: - Specific Model Properties

    func testClaude45OpusProperties() {
        let model = AIModel.claude45Opus
        XCTAssertEqual(model.contextWindow, 200_000)
        XCTAssertEqual(model.maxOutputTokens, 64_000)
        XCTAssertTrue(model.supportsVision)
        XCTAssertTrue(model.supportsFunctionCalling)
        XCTAssertTrue(model.supportsStreaming)
        XCTAssertFalse(model.isLocal)
    }

    func testO1DoesNotSupportStreaming() {
        XCTAssertFalse(AIModel.o1.supportsStreaming,
            "o1 reasoning model should not support streaming")
    }

    func testO1MiniDoesNotSupportStreaming() {
        XCTAssertFalse(AIModel.o1Mini.supportsStreaming,
            "o1-mini should not support streaming")
    }

    func testGeminiModelsHaveMillionTokenContext() {
        let millionContextModels = [AIModel.gemini3Pro, .gemini3Flash, .gemini25Pro, .gemini25Flash, .gemini2Flash]
        for model in millionContextModels {
            XCTAssertGreaterThanOrEqual(model.contextWindow, 1_000_000,
                "Gemini model \(model.id) should have >= 1M context window")
        }
    }

    // MARK: - Capability Filtering

    func testFilterModelsByCapability() {
        let visionModels = AIModel.allKnownModels.filter { $0.capabilities.contains(.vision) }
        XCTAssertGreaterThan(visionModels.count, 0)
        for model in visionModels {
            XCTAssertTrue(model.capabilities.contains(.vision))
        }
    }

    func testFilterReasoningModels() {
        let reasoningModels = AIModel.allKnownModels.filter { $0.capabilities.contains(.reasoning) }
        XCTAssertGreaterThan(reasoningModels.count, 0)
        // OpenAI o1 and o1-mini should be in reasoning
        let ids = Set(reasoningModels.map(\.id))
        XCTAssertTrue(ids.contains("o1"), "o1 should be a reasoning model")
    }

    func testFilterSearchModels() {
        let searchModels = AIModel.allKnownModels.filter { $0.capabilities.contains(.search) }
        XCTAssertGreaterThan(searchModels.count, 0)
        // All search models should be from Perplexity
        for model in searchModels {
            XCTAssertEqual(model.provider, "perplexity",
                "Search model \(model.id) should be from perplexity")
        }
    }

    // MARK: - Default Values

    func testDefaultContextWindow() {
        let model = AIModel(id: "test", name: "Test", provider: "test")
        XCTAssertEqual(model.contextWindow, 128_000)
    }

    func testDefaultMaxOutputTokens() {
        let model = AIModel(id: "test", name: "Test", provider: "test")
        XCTAssertEqual(model.maxOutputTokens, 4096)
    }

    func testDefaultCapabilities() {
        let model = AIModel(id: "test", name: "Test", provider: "test")
        XCTAssertEqual(model.capabilities, [.chat])
    }

    func testDefaultBooleans() {
        let model = AIModel(id: "test", name: "Test", provider: "test")
        XCTAssertFalse(model.isLocal)
        XCTAssertTrue(model.supportsStreaming)
        XCTAssertFalse(model.supportsVision)
        XCTAssertFalse(model.supportsFunctionCalling)
    }

    // MARK: - Codable Edge Cases

    func testCodableModelWithAllFieldsPopulated() throws {
        let model = AIModel(
            id: "full-model",
            name: "Full Model",
            provider: "test",
            description: "Fully populated model",
            contextWindow: 500_000,
            maxOutputTokens: 32_000,
            capabilities: [.chat, .vision, .reasoning, .functionCalling, .codeGeneration],
            inputCostPer1K: Decimal(string: "0.00123"),
            outputCostPer1K: Decimal(string: "0.00456"),
            isLocal: true,
            supportsStreaming: false,
            supportsVision: true,
            supportsFunctionCalling: true
        )
        let data = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(AIModel.self, from: data)

        XCTAssertEqual(decoded.id, model.id)
        XCTAssertEqual(decoded.name, model.name)
        XCTAssertEqual(decoded.description, model.description)
        XCTAssertEqual(decoded.contextWindow, model.contextWindow)
        XCTAssertEqual(decoded.maxOutputTokens, model.maxOutputTokens)
        XCTAssertEqual(decoded.capabilities.count, model.capabilities.count)
        XCTAssertEqual(decoded.inputCostPer1K, model.inputCostPer1K)
        XCTAssertEqual(decoded.outputCostPer1K, model.outputCostPer1K)
        XCTAssertEqual(decoded.isLocal, model.isLocal)
        XCTAssertEqual(decoded.supportsStreaming, model.supportsStreaming)
        XCTAssertEqual(decoded.supportsVision, model.supportsVision)
        XCTAssertEqual(decoded.supportsFunctionCalling, model.supportsFunctionCalling)
    }

    func testCodableAllKnownModelsRoundtrip() throws {
        for model in AIModel.allKnownModels {
            let data = try JSONEncoder().encode(model)
            let decoded = try JSONDecoder().decode(AIModel.self, from: data)
            XCTAssertEqual(decoded.id, model.id, "Round-trip failed for \(model.id)")
            XCTAssertEqual(decoded.name, model.name, "Name mismatch for \(model.id)")
            XCTAssertEqual(decoded.provider, model.provider, "Provider mismatch for \(model.id)")
        }
    }
}
