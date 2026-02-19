//
//  AIModelCatalogTests.swift
//  TheaTests
//
//  Tests for AIModelCatalog: static model definitions, provider lists, and catalog integrity.
//

@testable import TheaModels
import XCTest

// MARK: - Catalog Integrity Tests

final class AIModelCatalogIntegrityTests: XCTestCase {

    func testAllKnownModelsNonEmpty() {
        XCTAssertFalse(AIModel.allKnownModels.isEmpty)
    }

    func testAllKnownModelsCountMatchesSubgroups() {
        let expected = AIModel.anthropicModels.count
            + AIModel.openaiModels.count
            + AIModel.googleModels.count
            + AIModel.deepseekModels.count
            + AIModel.groqModels.count
            + AIModel.perplexityModels.count
            + AIModel.openRouterModels.count
            + AIModel.localModels.count
        XCTAssertEqual(AIModel.allKnownModels.count, expected)
    }

    func testAllModelIdsUnique() {
        let ids = AIModel.allKnownModels.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate model IDs detected")
    }

    func testAllModelIdsNonEmpty() {
        for model in AIModel.allKnownModels {
            XCTAssertFalse(model.id.isEmpty, "\(model.name) has empty ID")
        }
    }

    func testAllModelNamesNonEmpty() {
        for model in AIModel.allKnownModels {
            XCTAssertFalse(model.name.isEmpty, "Model \(model.id) has empty name")
        }
    }

    func testAllModelsHaveProvider() {
        for model in AIModel.allKnownModels {
            XCTAssertFalse(model.provider.isEmpty, "Model \(model.id) has empty provider")
        }
    }

    func testAllModelsHavePositiveContextWindow() {
        for model in AIModel.allKnownModels {
            XCTAssertGreaterThan(model.contextWindow, 0, "\(model.id) has zero/negative context window")
        }
    }

    func testAllModelsHavePositiveMaxOutput() {
        for model in AIModel.allKnownModels {
            XCTAssertGreaterThan(model.maxOutputTokens, 0, "\(model.id) has zero/negative max output")
        }
    }

    func testMaxOutputNeverExceedsContextWindow() {
        for model in AIModel.allKnownModels {
            XCTAssertLessThanOrEqual(
                model.maxOutputTokens,
                model.contextWindow,
                "\(model.id) maxOutput (\(model.maxOutputTokens)) > context (\(model.contextWindow))"
            )
        }
    }

    func testAllModelsHaveCapabilities() {
        for model in AIModel.allKnownModels {
            XCTAssertFalse(model.capabilities.isEmpty, "\(model.id) has no capabilities")
        }
    }

    func testAllModelsHaveChatCapability() {
        for model in AIModel.allKnownModels {
            XCTAssertTrue(
                model.capabilities.contains(.chat),
                "\(model.id) is missing .chat capability"
            )
        }
    }
}

// MARK: - Provider Group Tests

final class AIModelCatalogProviderTests: XCTestCase {

    func testAnthropicModelsCount() {
        // Updated for Phase P: Claude 4.6 family + Agent Teams models added to catalog
        XCTAssertEqual(AIModel.anthropicModels.count, 8)
    }

    func testAnthropicModelsAllHaveCorrectProvider() {
        for model in AIModel.anthropicModels {
            XCTAssertEqual(model.provider, "anthropic", "\(model.id) has wrong provider")
        }
    }

    func testAnthropicModelsAllSupportVision() {
        for model in AIModel.anthropicModels {
            XCTAssertTrue(model.supportsVision, "\(model.id) should support vision")
        }
    }

    func testAnthropicModelsAllSupportFunctionCalling() {
        for model in AIModel.anthropicModels {
            XCTAssertTrue(model.supportsFunctionCalling, "\(model.id) should support function calling")
        }
    }

    func testAnthropicContext200K() {
        for model in AIModel.anthropicModels {
            XCTAssertEqual(model.contextWindow, 200_000, "\(model.id) should have 200K context")
        }
    }

    func testOpenAIModelsCount() {
        XCTAssertEqual(AIModel.openaiModels.count, 4)
    }

    func testOpenAIModelsAllHaveCorrectProvider() {
        for model in AIModel.openaiModels {
            XCTAssertEqual(model.provider, "openai", "\(model.id) has wrong provider")
        }
    }

    func testGoogleModelsCount() {
        XCTAssertEqual(AIModel.googleModels.count, 6)
    }

    func testGoogleModelsAllHaveCorrectProvider() {
        for model in AIModel.googleModels {
            XCTAssertEqual(model.provider, "google", "\(model.id) has wrong provider")
        }
    }

    func testGoogleModelsHaveLargeContext() {
        for model in AIModel.googleModels {
            XCTAssertGreaterThanOrEqual(model.contextWindow, 1_000_000, "\(model.id) should have >= 1M context")
        }
    }

    func testDeepSeekModelsCount() {
        XCTAssertEqual(AIModel.deepseekModels.count, 2)
    }

    func testDeepSeekModelsAllHaveCorrectProvider() {
        for model in AIModel.deepseekModels {
            XCTAssertEqual(model.provider, "deepseek", "\(model.id) has wrong provider")
        }
    }

    func testGroqModelsCount() {
        XCTAssertEqual(AIModel.groqModels.count, 3)
    }

    func testGroqModelsAllHaveCorrectProvider() {
        for model in AIModel.groqModels {
            XCTAssertEqual(model.provider, "groq", "\(model.id) has wrong provider")
        }
    }

    func testPerplexityModelsCount() {
        XCTAssertEqual(AIModel.perplexityModels.count, 3)
    }

    func testPerplexityModelsAllHaveCorrectProvider() {
        for model in AIModel.perplexityModels {
            XCTAssertEqual(model.provider, "perplexity", "\(model.id) has wrong provider")
        }
    }

    func testPerplexityModelsHaveSearchCapability() {
        for model in AIModel.perplexityModels {
            XCTAssertTrue(
                model.capabilities.contains(.search),
                "\(model.id) should have .search capability"
            )
        }
    }

    func testOpenRouterModelsCount() {
        // Updated for Phase P: additional OpenRouter models added to catalog
        XCTAssertEqual(AIModel.openRouterModels.count, 7)
    }

    func testOpenRouterModelsAllHaveCorrectProvider() {
        for model in AIModel.openRouterModels {
            XCTAssertEqual(model.provider, "openrouter", "\(model.id) has wrong provider")
        }
    }

    func testOpenRouterIdsContainSlash() {
        for model in AIModel.openRouterModels {
            XCTAssertTrue(model.id.contains("/"), "OpenRouter ID \(model.id) should contain provider prefix")
        }
    }

    func testLocalModelsCount() {
        XCTAssertEqual(AIModel.localModels.count, 5)
    }

    func testLocalModelsAllHaveCorrectProvider() {
        for model in AIModel.localModels {
            XCTAssertEqual(model.provider, "local", "\(model.id) has wrong provider")
        }
    }

    func testLocalModelsMarkedAsLocal() {
        for model in AIModel.localModels {
            XCTAssertTrue(model.isLocal, "\(model.id) should be marked isLocal")
        }
    }

    func testNonLocalModelsNotMarkedAsLocal() {
        let nonLocal = AIModel.anthropicModels + AIModel.openaiModels + AIModel.googleModels
            + AIModel.deepseekModels + AIModel.groqModels + AIModel.perplexityModels
        for model in nonLocal {
            XCTAssertFalse(model.isLocal, "\(model.id) should NOT be marked isLocal")
        }
    }
}

// MARK: - Specific Model Tests

final class AIModelCatalogSpecificModelsTests: XCTestCase {

    // MARK: - Claude 4.5 Family

    func testClaude45OpusProperties() {
        let model = AIModel.claude45Opus
        XCTAssertEqual(model.id, "claude-opus-4-5-20251101")
        XCTAssertEqual(model.name, "Claude Opus 4.5")
        XCTAssertEqual(model.contextWindow, 200_000)
        XCTAssertEqual(model.maxOutputTokens, 64_000)
        XCTAssertTrue(model.capabilities.contains(.reasoning))
    }

    func testClaude45SonnetProperties() {
        let model = AIModel.claude45Sonnet
        XCTAssertEqual(model.id, "claude-sonnet-4-5-20250929")
        XCTAssertEqual(model.maxOutputTokens, 64_000)
    }

    func testClaude45HaikuProperties() {
        let model = AIModel.claude45Haiku
        XCTAssertEqual(model.id, "claude-haiku-4-5-20251001")
        XCTAssertEqual(model.maxOutputTokens, 64_000)
        // Haiku does NOT have .reasoning capability
        XCTAssertFalse(model.capabilities.contains(.reasoning))
    }

    // MARK: - Claude 4 Family (Legacy)

    func testClaude4OpusProperties() {
        let model = AIModel.claude4Opus
        XCTAssertEqual(model.id, "claude-opus-4-20250514")
        XCTAssertEqual(model.maxOutputTokens, 32_000)
    }

    func testClaude4SonnetProperties() {
        let model = AIModel.claude4Sonnet
        XCTAssertEqual(model.id, "claude-sonnet-4-20250514")
        XCTAssertEqual(model.maxOutputTokens, 16_000)
    }

    // MARK: - OpenAI

    func testGPT4oProperties() {
        let model = AIModel.gpt4o
        XCTAssertEqual(model.id, "gpt-4o")
        XCTAssertEqual(model.contextWindow, 128_000)
        XCTAssertTrue(model.capabilities.contains(.multimodal))
    }

    func testO1Properties() {
        let model = AIModel.o1
        XCTAssertEqual(model.id, "o1")
        XCTAssertEqual(model.contextWindow, 200_000)
        XCTAssertTrue(model.capabilities.contains(.reasoning))
        XCTAssertFalse(model.supportsStreaming)
    }

    func testO1MiniProperties() {
        let model = AIModel.o1Mini
        XCTAssertFalse(model.supportsStreaming)
        XCTAssertTrue(model.capabilities.contains(.reasoning))
    }

    // MARK: - Google

    func testGemini3ProProperties() {
        let model = AIModel.gemini3Pro
        XCTAssertEqual(model.id, "gemini-3-pro-preview")
        XCTAssertEqual(model.contextWindow, 1_000_000)
        XCTAssertTrue(model.capabilities.contains(.reasoning))
    }

    func testGemini25ProProperties() {
        let model = AIModel.gemini25Pro
        XCTAssertEqual(model.contextWindow, 1_000_000)
    }

    func testGemini15ProMaxContext() {
        let model = AIModel.gemini15Pro
        XCTAssertEqual(model.contextWindow, 2_000_000, "Gemini 1.5 Pro should have 2M context")
    }

    // MARK: - DeepSeek

    func testDeepseekReasonerHasReasoning() {
        let model = AIModel.deepseekReasoner
        XCTAssertTrue(model.capabilities.contains(.reasoning))
    }

    func testDeepseekChatDoesNotHaveReasoning() {
        let model = AIModel.deepseekChat
        XCTAssertFalse(model.capabilities.contains(.reasoning))
    }

    // MARK: - Local Models

    func testGptOSS20BProperties() {
        let model = AIModel.gptOSS20B
        XCTAssertEqual(model.id, "gpt-oss-20b")
        XCTAssertTrue(model.isLocal)
        XCTAssertTrue(model.capabilities.contains(.reasoning))
    }

    func testGptOSS120BProperties() {
        let model = AIModel.gptOSS120B
        XCTAssertEqual(model.id, "gpt-oss-120b")
        XCTAssertTrue(model.isLocal)
        XCTAssertTrue(model.capabilities.contains(.analysis))
    }

    func testQwen3VLSupportsVision() {
        let model = AIModel.qwen3VL8B
        XCTAssertTrue(model.supportsVision)
        XCTAssertTrue(model.capabilities.contains(.vision))
        XCTAssertTrue(model.capabilities.contains(.multimodal))
    }

    func testGemma3_1BIsMinimal() {
        let model = AIModel.gemma3_1B
        XCTAssertFalse(model.supportsVision)
        XCTAssertFalse(model.supportsFunctionCalling)
    }

    func testGemma3_4BSupportsVision() {
        let model = AIModel.gemma3_4B
        XCTAssertTrue(model.supportsVision)
        XCTAssertTrue(model.capabilities.contains(.multimodal))
    }
}

// MARK: - Cost Tests

final class AIModelCatalogCostTests: XCTestCase {

    func testCloudModelsHaveCostData() {
        let cloudModels = AIModel.anthropicModels + AIModel.openaiModels + AIModel.googleModels
            + AIModel.deepseekModels + AIModel.groqModels + AIModel.perplexityModels
        for model in cloudModels {
            // At least one cost field should be non-nil
            let hasCost = model.inputCostPer1K != nil || model.outputCostPer1K != nil
            XCTAssertTrue(hasCost, "\(model.id) should have cost data")
        }
    }

    func testLocalModelsHaveNoCostData() {
        for model in AIModel.localModels {
            XCTAssertNil(model.inputCostPer1K, "\(model.id) local model should have no input cost")
            XCTAssertNil(model.outputCostPer1K, "\(model.id) local model should have no output cost")
        }
    }

    func testCostValuesArePositive() {
        for model in AIModel.allKnownModels {
            if let inputCost = model.inputCostPer1K {
                XCTAssertGreaterThan(inputCost, 0, "\(model.id) input cost should be positive")
            }
            if let outputCost = model.outputCostPer1K {
                XCTAssertGreaterThan(outputCost, 0, "\(model.id) output cost should be positive")
            }
        }
    }

    func testOutputCostGreaterThanOrEqualToInputCost() {
        for model in AIModel.allKnownModels {
            if let inputCost = model.inputCostPer1K, let outputCost = model.outputCostPer1K {
                XCTAssertGreaterThanOrEqual(
                    outputCost, inputCost,
                    "\(model.id) output cost should be >= input cost"
                )
            }
        }
    }

    func testHaikuIsCheaperThanOpus() {
        guard let haikuInput = AIModel.claude45Haiku.inputCostPer1K,
              let opusInput = AIModel.claude45Opus.inputCostPer1K
        else {
            XCTFail("Cost data missing")
            return
        }
        XCTAssertLessThan(haikuInput, opusInput)
    }

    func testMiniIsCheaperThanFull() {
        guard let miniInput = AIModel.gpt4oMini.inputCostPer1K,
              let fullInput = AIModel.gpt4o.inputCostPer1K
        else {
            XCTFail("Cost data missing")
            return
        }
        XCTAssertLessThan(miniInput, fullInput)
    }
}
