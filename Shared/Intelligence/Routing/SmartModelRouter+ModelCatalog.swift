// SmartModelRouter+ModelCatalog.swift
// Thea V4 — Default model catalog registration
//
// Extracted from SmartModelRouter.swift for file size compliance.
// Contains all hardcoded model registrations organized by provider.

import Foundation

extension SmartModelRouter {

    func setupDefaultModels() {
        registerAnthropicModels()
        registerOpenAIModels()
        registerGoogleModels()
        registerDeepSeekModels()
        registerGroqModels()
        registerPerplexityModels()
        registerLocalModels()
    }

    // MARK: - Anthropic

    private func registerAnthropicModels() {
        // Claude 4.5 (Latest)
        registerModel(RouterModelCapability(
            modelId: "claude-opus-4-5-20251101",
            provider: "anthropic",
            contextWindow: 200_000,
            maxOutputTokens: 64_000,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .creative, .vision, .functionCalling, .structuredOutput, .streaming, .longContext, .highQuality],
            costPerInputToken: 15.0,
            costPerOutputToken: 75.0,
            averageLatency: 3.0,
            qualityScore: 0.97
        ))

        registerModel(RouterModelCapability(
            modelId: "claude-sonnet-4-5-20250929",
            provider: "anthropic",
            contextWindow: 200_000,
            maxOutputTokens: 64_000,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .creative, .vision, .functionCalling, .structuredOutput, .streaming, .longContext],
            costPerInputToken: 3.0,
            costPerOutputToken: 15.0,
            averageLatency: 1.5,
            qualityScore: 0.88
        ))

        registerModel(RouterModelCapability(
            modelId: "claude-haiku-4-5-20251001",
            provider: "anthropic",
            contextWindow: 200_000,
            maxOutputTokens: 64_000,
            capabilities: [.textGeneration, .codeGeneration, .analysis, .vision, .functionCalling, .streaming, .longContext, .fastResponse, .lowCost],
            costPerInputToken: 1.0,
            costPerOutputToken: 5.0,
            averageLatency: 0.5,
            qualityScore: 0.75
        ))

        // Claude 4 (Legacy)
        registerModel(RouterModelCapability(
            modelId: "claude-opus-4-20250514",
            provider: "anthropic",
            contextWindow: 200_000,
            maxOutputTokens: 32_000,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .creative, .vision, .functionCalling, .structuredOutput, .streaming, .longContext, .highQuality],
            costPerInputToken: 15.0,
            costPerOutputToken: 75.0,
            averageLatency: 3.0,
            qualityScore: 0.95
        ))

        registerModel(RouterModelCapability(
            modelId: "claude-sonnet-4-20250514",
            provider: "anthropic",
            contextWindow: 200_000,
            maxOutputTokens: 16_000,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .creative, .vision, .functionCalling, .structuredOutput, .streaming, .longContext],
            costPerInputToken: 3.0,
            costPerOutputToken: 15.0,
            averageLatency: 1.5,
            qualityScore: 0.85
        ))

        registerModel(RouterModelCapability(
            modelId: "claude-3-5-haiku-20241022",
            provider: "anthropic",
            contextWindow: 200_000,
            maxOutputTokens: 8192,
            capabilities: [.textGeneration, .codeGeneration, .analysis, .vision, .functionCalling, .streaming, .longContext, .fastResponse, .lowCost],
            costPerInputToken: 1.0,
            costPerOutputToken: 5.0,
            averageLatency: 0.4,
            qualityScore: 0.70
        ))
    }

    // MARK: - OpenAI

    private func registerOpenAIModels() {
        registerModel(RouterModelCapability(
            modelId: "gpt-4o",
            provider: "openai",
            contextWindow: 128_000,
            maxOutputTokens: 16_384,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .creative, .vision, .audio, .functionCalling, .structuredOutput, .streaming],
            costPerInputToken: 5.0,
            costPerOutputToken: 15.0,
            averageLatency: 1.2,
            qualityScore: 0.88
        ))

        registerModel(RouterModelCapability(
            modelId: "gpt-4o-mini",
            provider: "openai",
            contextWindow: 128_000,
            maxOutputTokens: 16_384,
            capabilities: [.textGeneration, .codeGeneration, .analysis, .vision, .functionCalling, .streaming, .fastResponse, .lowCost],
            costPerInputToken: 0.15,
            costPerOutputToken: 0.60,
            averageLatency: 0.4,
            qualityScore: 0.72
        ))

        registerModel(RouterModelCapability(
            modelId: "o1",
            provider: "openai",
            contextWindow: 200_000,
            maxOutputTokens: 100_000,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .highQuality],
            costPerInputToken: 15.0,
            costPerOutputToken: 60.0,
            averageLatency: 8.0,
            qualityScore: 0.93
        ))
    }

    // MARK: - Google Gemini

    private func registerGoogleModels() {
        registerModel(RouterModelCapability(
            modelId: "gemini-3-pro-preview",
            provider: "google",
            contextWindow: 1_000_000,
            maxOutputTokens: 65_536,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .creative, .vision, .functionCalling, .structuredOutput, .streaming, .longContext, .highQuality],
            costPerInputToken: 2.0,
            costPerOutputToken: 12.0,
            averageLatency: 2.0,
            qualityScore: 0.90
        ))

        registerModel(RouterModelCapability(
            modelId: "gemini-3-flash-preview",
            provider: "google",
            contextWindow: 1_000_000,
            maxOutputTokens: 65_536,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .vision, .functionCalling, .streaming, .longContext, .fastResponse, .lowCost],
            costPerInputToken: 0.5,
            costPerOutputToken: 3.0,
            averageLatency: 0.5,
            qualityScore: 0.80
        ))

        registerModel(RouterModelCapability(
            modelId: "gemini-2.5-pro",
            provider: "google",
            contextWindow: 1_000_000,
            maxOutputTokens: 65_536,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .vision, .functionCalling, .structuredOutput, .streaming, .longContext],
            costPerInputToken: 1.25,
            costPerOutputToken: 5.0,
            averageLatency: 1.5,
            qualityScore: 0.87
        ))

        registerModel(RouterModelCapability(
            modelId: "gemini-2.0-flash",
            provider: "google",
            contextWindow: 1_000_000,
            maxOutputTokens: 8192,
            capabilities: [.textGeneration, .codeGeneration, .analysis, .vision, .audio, .functionCalling, .streaming, .longContext, .fastResponse, .lowCost],
            costPerInputToken: 0.1,
            costPerOutputToken: 0.4,
            averageLatency: 0.3,
            qualityScore: 0.75
        ))
    }

    // MARK: - DeepSeek

    private func registerDeepSeekModels() {
        registerModel(RouterModelCapability(
            modelId: "deepseek-chat",
            provider: "deepseek",
            contextWindow: 128_000,
            maxOutputTokens: 8192,
            capabilities: [.textGeneration, .codeGeneration, .functionCalling, .streaming, .lowCost],
            costPerInputToken: 0.28,
            costPerOutputToken: 0.42,
            averageLatency: 1.0,
            qualityScore: 0.78
        ))

        registerModel(RouterModelCapability(
            modelId: "deepseek-reasoner",
            provider: "deepseek",
            contextWindow: 128_000,
            maxOutputTokens: 65_536,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .functionCalling, .streaming, .lowCost],
            costPerInputToken: 0.28,
            costPerOutputToken: 0.42,
            averageLatency: 5.0,
            qualityScore: 0.83
        ))
    }

    // MARK: - Groq

    private func registerGroqModels() {
        registerModel(RouterModelCapability(
            modelId: "llama-3.3-70b-versatile",
            provider: "groq",
            contextWindow: 32_768,
            maxOutputTokens: 8192,
            capabilities: [.textGeneration, .codeGeneration, .functionCalling, .streaming, .fastResponse, .lowCost],
            costPerInputToken: 0.59,
            costPerOutputToken: 0.79,
            averageLatency: 0.2,
            qualityScore: 0.73
        ))

        registerModel(RouterModelCapability(
            modelId: "llama-3.1-8b-instant",
            provider: "groq",
            contextWindow: 32_768,
            maxOutputTokens: 8192,
            capabilities: [.textGeneration, .codeGeneration, .functionCalling, .streaming, .fastResponse, .lowCost],
            costPerInputToken: 0.05,
            costPerOutputToken: 0.08,
            averageLatency: 0.1,
            qualityScore: 0.60
        ))
    }

    // MARK: - Perplexity

    private func registerPerplexityModels() {
        registerModel(RouterModelCapability(
            modelId: "sonar-pro",
            provider: "perplexity",
            contextWindow: 200_000,
            maxOutputTokens: 8192,
            capabilities: [.textGeneration, .analysis, .streaming],
            costPerInputToken: 3.0,
            costPerOutputToken: 15.0,
            averageLatency: 2.0,
            qualityScore: 0.80
        ))

        registerModel(RouterModelCapability(
            modelId: "sonar",
            provider: "perplexity",
            contextWindow: 127_072,
            maxOutputTokens: 8192,
            capabilities: [.textGeneration, .analysis, .streaming, .fastResponse, .lowCost],
            costPerInputToken: 1.0,
            costPerOutputToken: 1.0,
            averageLatency: 1.0,
            qualityScore: 0.72
        ))

        registerModel(RouterModelCapability(
            modelId: "sonar-reasoning",
            provider: "perplexity",
            contextWindow: 127_072,
            maxOutputTokens: 8192,
            capabilities: [.textGeneration, .reasoning, .analysis, .streaming],
            costPerInputToken: 1.0,
            costPerOutputToken: 5.0,
            averageLatency: 3.0,
            qualityScore: 0.78
        ))
    }

    // MARK: - Local Models

    private func registerLocalModels() {
        registerModel(RouterModelCapability(
            modelId: "local-llama",
            provider: "local",
            contextWindow: 8192,
            maxOutputTokens: 4096,
            capabilities: [.textGeneration, .codeGeneration, .analysis, .streaming],
            costPerInputToken: 0,
            costPerOutputToken: 0,
            averageLatency: 2.0,
            qualityScore: 0.60,
            isLocalModel: true
        ))

        // GPT-OSS (OpenAI open-weight, Apache 2.0)
        registerModel(RouterModelCapability(
            modelId: "gpt-oss-20b",
            provider: "local",
            contextWindow: 128_000,
            maxOutputTokens: 16_384,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .functionCalling, .streaming, .analysis],
            costPerInputToken: 0,
            costPerOutputToken: 0,
            averageLatency: 1.5,
            qualityScore: 0.78,
            isLocalModel: true
        ))

        registerModel(RouterModelCapability(
            modelId: "gpt-oss-120b",
            provider: "local",
            contextWindow: 128_000,
            maxOutputTokens: 16_384,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .functionCalling, .streaming, .analysis, .highQuality],
            costPerInputToken: 0,
            costPerOutputToken: 0,
            averageLatency: 4.0,
            qualityScore: 0.88,
            isLocalModel: true
        ))
    }
}
