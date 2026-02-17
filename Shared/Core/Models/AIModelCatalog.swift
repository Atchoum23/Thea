// AIModelCatalog.swift
// Thea V2
//
// Known model definitions and model lists extracted from AIModel.swift
// for file_length compliance.

import Foundation

// MARK: - Known Models

public extension AIModel {
    // MARK: - Anthropic Models (Claude 4.6 - Latest)

    static let claude46Opus = AIModel(
        id: "claude-opus-4-6",
        name: "Claude Opus 4.6",
        provider: "anthropic",
        description: "Most capable model — adaptive thinking, 1M context, interleaved tool use",
        contextWindow: 1_000_000,
        maxOutputTokens: 32_000,
        capabilities: [.chat, .vision, .codeGeneration, .reasoning, .functionCalling],
        inputCostPer1K: Decimal(string: "0.015"),
        outputCostPer1K: Decimal(string: "0.075"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    // MARK: - Anthropic Models (Claude 4.5)

    static let claude45Opus = AIModel(
        id: "claude-opus-4-5-20251101",
        name: "Claude Opus 4.5",
        provider: "anthropic",
        description: "Most intelligent model for coding, agents, and complex tasks",
        contextWindow: 200_000,
        maxOutputTokens: 64_000,
        capabilities: [.chat, .vision, .codeGeneration, .reasoning, .functionCalling],
        inputCostPer1K: Decimal(string: "0.015"),
        outputCostPer1K: Decimal(string: "0.075"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let claude45Sonnet = AIModel(
        id: "claude-sonnet-4-5-20250929",
        name: "Claude Sonnet 4.5",
        provider: "anthropic",
        description: "Balanced performance for coding and agents",
        contextWindow: 200_000,
        maxOutputTokens: 64_000,
        capabilities: [.chat, .vision, .codeGeneration, .reasoning, .functionCalling],
        inputCostPer1K: Decimal(string: "0.003"),
        outputCostPer1K: Decimal(string: "0.015"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let claude45Haiku = AIModel(
        id: "claude-haiku-4-5-20251001",
        name: "Claude Haiku 4.5",
        provider: "anthropic",
        description: "Fastest model with near-frontier intelligence",
        contextWindow: 200_000,
        maxOutputTokens: 64_000,
        capabilities: [.chat, .vision, .codeGeneration, .functionCalling],
        inputCostPer1K: Decimal(string: "0.001"),
        outputCostPer1K: Decimal(string: "0.005"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    // MARK: - Anthropic Models (Claude 4 - Legacy)

    static let claude4Opus = AIModel(
        id: "claude-opus-4-20250514",
        name: "Claude Opus 4",
        provider: "anthropic",
        description: "Most capable Claude 4 model for complex tasks",
        contextWindow: 200_000,
        maxOutputTokens: 32_000,
        capabilities: [.chat, .vision, .codeGeneration, .reasoning, .functionCalling],
        inputCostPer1K: Decimal(string: "0.015"),
        outputCostPer1K: Decimal(string: "0.075"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let claude4Sonnet = AIModel(
        id: "claude-sonnet-4-20250514",
        name: "Claude Sonnet 4",
        provider: "anthropic",
        description: "Balanced capability and speed",
        contextWindow: 200_000,
        maxOutputTokens: 16_000,
        capabilities: [.chat, .vision, .codeGeneration, .reasoning, .functionCalling],
        inputCostPer1K: Decimal(string: "0.003"),
        outputCostPer1K: Decimal(string: "0.015"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let claude35Haiku = AIModel(
        id: "claude-3-5-haiku-20241022",
        name: "Claude 3.5 Haiku",
        provider: "anthropic",
        description: "Fast Claude 3.5 model",
        contextWindow: 200_000,
        maxOutputTokens: 8192,
        capabilities: [.chat, .vision, .codeGeneration, .functionCalling],
        inputCostPer1K: Decimal(string: "0.001"),
        outputCostPer1K: Decimal(string: "0.005"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    // MARK: - OpenAI Models

    static let gpt4o = AIModel(
        id: "gpt-4o",
        name: "GPT-4o",
        provider: "openai",
        description: "OpenAI's flagship multimodal model",
        contextWindow: 128_000,
        maxOutputTokens: 16_384,
        capabilities: [.chat, .vision, .codeGeneration, .functionCalling, .multimodal],
        inputCostPer1K: Decimal(string: "0.005"),
        outputCostPer1K: Decimal(string: "0.015"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let gpt4oMini = AIModel(
        id: "gpt-4o-mini",
        name: "GPT-4o Mini",
        provider: "openai",
        description: "Fast and affordable GPT model",
        contextWindow: 128_000,
        maxOutputTokens: 16_384,
        capabilities: [.chat, .vision, .codeGeneration, .functionCalling],
        inputCostPer1K: Decimal(string: "0.00015"),
        outputCostPer1K: Decimal(string: "0.0006"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let o1 = AIModel(
        id: "o1",
        name: "o1",
        provider: "openai",
        description: "OpenAI reasoning model",
        contextWindow: 200_000,
        maxOutputTokens: 100_000,
        capabilities: [.chat, .reasoning, .codeGeneration],
        inputCostPer1K: Decimal(string: "0.015"),
        outputCostPer1K: Decimal(string: "0.060"),
        supportsStreaming: false
    )

    static let o1Mini = AIModel(
        id: "o1-mini",
        name: "o1-mini",
        provider: "openai",
        description: "Fast reasoning model",
        contextWindow: 128_000,
        maxOutputTokens: 65_536,
        capabilities: [.chat, .reasoning, .codeGeneration],
        inputCostPer1K: Decimal(string: "0.003"),
        outputCostPer1K: Decimal(string: "0.012"),
        supportsStreaming: false
    )

    // MARK: - Google Models (Gemini 3 - Latest)

    static let gemini3Pro = AIModel(
        id: "gemini-3-pro-preview",
        name: "Gemini 3 Pro",
        provider: "google",
        description: "Google's most capable Gemini 3 model with thinking",
        contextWindow: 1_000_000,
        maxOutputTokens: 65_536,
        capabilities: [.chat, .vision, .codeGeneration, .functionCalling, .multimodal, .reasoning],
        inputCostPer1K: Decimal(string: "0.002"),
        outputCostPer1K: Decimal(string: "0.012"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let gemini3Flash = AIModel(
        id: "gemini-3-flash-preview",
        name: "Gemini 3 Flash",
        provider: "google",
        description: "Fast Gemini 3 model with thinking support",
        contextWindow: 1_000_000,
        maxOutputTokens: 65_536,
        capabilities: [.chat, .vision, .codeGeneration, .functionCalling, .multimodal, .reasoning],
        inputCostPer1K: Decimal(string: "0.0005"),
        outputCostPer1K: Decimal(string: "0.003"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    // MARK: - Google Models (Gemini 2.5)

    static let gemini25Pro = AIModel(
        id: "gemini-2.5-pro",
        name: "Gemini 2.5 Pro",
        provider: "google",
        description: "Google's thinking model with budget tokens",
        contextWindow: 1_000_000,
        maxOutputTokens: 65_536,
        capabilities: [.chat, .vision, .codeGeneration, .functionCalling, .multimodal, .reasoning],
        inputCostPer1K: Decimal(string: "0.00125"),
        outputCostPer1K: Decimal(string: "0.005"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let gemini25Flash = AIModel(
        id: "gemini-2.5-flash",
        name: "Gemini 2.5 Flash",
        provider: "google",
        description: "Fast Gemini 2.5 model",
        contextWindow: 1_000_000,
        maxOutputTokens: 65_536,
        capabilities: [.chat, .vision, .codeGeneration, .functionCalling, .multimodal],
        inputCostPer1K: Decimal(string: "0.0001"),
        outputCostPer1K: Decimal(string: "0.0004"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    // MARK: - Google Models (Legacy)

    static let gemini2Flash = AIModel(
        id: "gemini-2.0-flash",
        name: "Gemini 2.0 Flash",
        provider: "google",
        description: "Google's fast multimodal model",
        contextWindow: 1_000_000,
        maxOutputTokens: 8192,
        capabilities: [.chat, .vision, .codeGeneration, .functionCalling, .multimodal],
        inputCostPer1K: Decimal(string: "0.0001"),
        outputCostPer1K: Decimal(string: "0.0004"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let gemini15Pro = AIModel(
        id: "gemini-1.5-pro",
        name: "Gemini 1.5 Pro",
        provider: "google",
        description: "Google's most capable model",
        contextWindow: 2_000_000,
        maxOutputTokens: 8192,
        capabilities: [.chat, .vision, .codeGeneration, .functionCalling, .multimodal, .reasoning],
        inputCostPer1K: Decimal(string: "0.00125"),
        outputCostPer1K: Decimal(string: "0.005"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    // MARK: - DeepSeek Models

    static let deepseekChat = AIModel(
        id: "deepseek-chat",
        name: "DeepSeek V3.2",
        provider: "deepseek",
        description: "DeepSeek's non-thinking chat model",
        contextWindow: 128_000,
        maxOutputTokens: 8192,
        capabilities: [.chat, .codeGeneration, .functionCalling],
        inputCostPer1K: Decimal(string: "0.00028"),
        outputCostPer1K: Decimal(string: "0.00042"),
        supportsFunctionCalling: true
    )

    static let deepseekReasoner = AIModel(
        id: "deepseek-reasoner",
        name: "DeepSeek Reasoner",
        provider: "deepseek",
        description: "DeepSeek's thinking/reasoning model",
        contextWindow: 128_000,
        maxOutputTokens: 65_536,
        capabilities: [.chat, .codeGeneration, .reasoning, .functionCalling],
        inputCostPer1K: Decimal(string: "0.00028"),
        outputCostPer1K: Decimal(string: "0.00042"),
        supportsFunctionCalling: true
    )

    // MARK: - Groq Models

    static let llama370b = AIModel(
        id: "llama-3.3-70b-versatile",
        name: "Llama 3.3 70B",
        provider: "groq",
        description: "Meta's capable open model via Groq",
        contextWindow: 32_768,
        maxOutputTokens: 8192,
        capabilities: [.chat, .codeGeneration, .functionCalling],
        inputCostPer1K: Decimal(string: "0.00059"),
        outputCostPer1K: Decimal(string: "0.00079"),
        supportsFunctionCalling: true
    )

    static let llama318b = AIModel(
        id: "llama-3.1-8b-instant",
        name: "Llama 3.1 8B Instant",
        provider: "groq",
        description: "Ultra-fast Llama model via Groq",
        contextWindow: 32_768,
        maxOutputTokens: 8192,
        capabilities: [.chat, .codeGeneration, .functionCalling],
        inputCostPer1K: Decimal(string: "0.00005"),
        outputCostPer1K: Decimal(string: "0.00008"),
        supportsFunctionCalling: true
    )

    static let mixtral8x7b = AIModel(
        id: "mixtral-8x7b-32768",
        name: "Mixtral 8x7B",
        provider: "groq",
        description: "Mistral's MoE model via Groq",
        contextWindow: 32_768,
        maxOutputTokens: 8192,
        capabilities: [.chat, .codeGeneration, .functionCalling],
        inputCostPer1K: Decimal(string: "0.00024"),
        outputCostPer1K: Decimal(string: "0.00024"),
        supportsFunctionCalling: true
    )

    // MARK: - Perplexity Models

    static let sonarPro = AIModel(
        id: "sonar-pro",
        name: "Sonar Pro",
        provider: "perplexity",
        description: "Perplexity's advanced search-enhanced model",
        contextWindow: 200_000,
        maxOutputTokens: 8192,
        capabilities: [.chat, .search],
        inputCostPer1K: Decimal(string: "0.003"),
        outputCostPer1K: Decimal(string: "0.015")
    )

    static let sonar = AIModel(
        id: "sonar",
        name: "Sonar",
        provider: "perplexity",
        description: "Fast search-enhanced model",
        contextWindow: 127_072,
        maxOutputTokens: 8192,
        capabilities: [.chat, .search],
        inputCostPer1K: Decimal(string: "0.001"),
        outputCostPer1K: Decimal(string: "0.001")
    )

    static let sonarReasoning = AIModel(
        id: "sonar-reasoning",
        name: "Sonar Reasoning",
        provider: "perplexity",
        description: "Reasoning with search capabilities",
        contextWindow: 127_072,
        maxOutputTokens: 8192,
        capabilities: [.chat, .search, .reasoning],
        inputCostPer1K: Decimal(string: "0.001"),
        outputCostPer1K: Decimal(string: "0.005")
    )

    // MARK: - OpenRouter Models

    static let orClaude46Opus = AIModel(
        id: "anthropic/claude-opus-4-6",
        name: "Claude Opus 4.6 (OpenRouter)",
        provider: "openrouter",
        description: "Claude Opus 4.6 via OpenRouter — adaptive thinking, 1M context",
        contextWindow: 1_000_000,
        maxOutputTokens: 32_000,
        capabilities: [.chat, .vision, .codeGeneration, .reasoning, .functionCalling],
        inputCostPer1K: Decimal(string: "0.015"),
        outputCostPer1K: Decimal(string: "0.075"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let orClaude45Sonnet = AIModel(
        id: "anthropic/claude-sonnet-4-5-20250929",
        name: "Claude Sonnet 4.5 (OpenRouter)",
        provider: "openrouter",
        description: "Claude Sonnet 4.5 via OpenRouter",
        contextWindow: 200_000,
        maxOutputTokens: 64_000,
        capabilities: [.chat, .vision, .codeGeneration, .reasoning, .functionCalling],
        inputCostPer1K: Decimal(string: "0.003"),
        outputCostPer1K: Decimal(string: "0.015"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let orGpt4o = AIModel(
        id: "openai/gpt-4o",
        name: "GPT-4o (OpenRouter)",
        provider: "openrouter",
        description: "GPT-4o via OpenRouter",
        contextWindow: 128_000,
        maxOutputTokens: 16_384,
        capabilities: [.chat, .vision, .codeGeneration, .functionCalling, .multimodal],
        inputCostPer1K: Decimal(string: "0.005"),
        outputCostPer1K: Decimal(string: "0.015"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let orGemini25Pro = AIModel(
        id: "google/gemini-2.5-pro-preview",
        name: "Gemini 2.5 Pro (OpenRouter)",
        provider: "openrouter",
        description: "Gemini 2.5 Pro via OpenRouter",
        contextWindow: 1_000_000,
        maxOutputTokens: 65_536,
        capabilities: [.chat, .vision, .codeGeneration, .reasoning, .functionCalling, .multimodal],
        inputCostPer1K: Decimal(string: "0.00125"),
        outputCostPer1K: Decimal(string: "0.005"),
        supportsVision: true,
        supportsFunctionCalling: true
    )

    static let orDeepseekChat = AIModel(
        id: "deepseek/deepseek-chat",
        name: "DeepSeek V3.2 (OpenRouter)",
        provider: "openrouter",
        description: "DeepSeek V3.2 via OpenRouter",
        contextWindow: 128_000,
        maxOutputTokens: 8192,
        capabilities: [.chat, .codeGeneration, .functionCalling],
        inputCostPer1K: Decimal(string: "0.00028"),
        outputCostPer1K: Decimal(string: "0.00042"),
        supportsFunctionCalling: true
    )

    static let orLlama370b = AIModel(
        id: "meta-llama/llama-3.3-70b-instruct",
        name: "Llama 3.3 70B (OpenRouter)",
        provider: "openrouter",
        description: "Llama 3.3 70B via OpenRouter",
        contextWindow: 128_000,
        maxOutputTokens: 32_768,
        capabilities: [.chat, .codeGeneration],
        inputCostPer1K: Decimal(string: "0.00039"),
        outputCostPer1K: Decimal(string: "0.00039")
    )

    // MARK: - Local Open-Weight Models

    static let gptOSS20B = AIModel(
        id: "gpt-oss-20b",
        name: "GPT-OSS 20B",
        provider: "local",
        description: "OpenAI's open-weight 20B reasoning model (Apache 2.0). Runs in 16GB RAM.",
        contextWindow: 128_000,
        maxOutputTokens: 16_384,
        capabilities: [.chat, .codeGeneration, .reasoning, .functionCalling],
        isLocal: true,
        supportsFunctionCalling: true
    )

    static let gptOSS120B = AIModel(
        id: "gpt-oss-120b",
        name: "GPT-OSS 120B",
        provider: "local",
        description: "OpenAI's open-weight 120B reasoning model (Apache 2.0). Requires 80GB+ RAM.",
        contextWindow: 128_000,
        maxOutputTokens: 16_384,
        capabilities: [.chat, .codeGeneration, .reasoning, .functionCalling, .analysis],
        isLocal: true,
        supportsFunctionCalling: true
    )

    static let qwen3VL8B = AIModel(
        id: "qwen3-vl-8b",
        name: "Qwen3-VL 8B",
        provider: "local",
        description: "Alibaba's 8B vision-language model for local image understanding.",
        contextWindow: 32_768,
        maxOutputTokens: 8192,
        capabilities: [.chat, .vision, .multimodal, .reasoning],
        isLocal: true,
        supportsVision: true
    )

    static let gemma3_1B = AIModel(
        id: "gemma-3-1b-it",
        name: "Gemma 3 1B",
        provider: "local",
        description: "Google's lightweight 1B model for iOS on-device inference via CoreML.",
        contextWindow: 32_768,
        maxOutputTokens: 4096,
        capabilities: [.chat, .reasoning],
        isLocal: true
    )

    static let gemma3_4B = AIModel(
        id: "gemma-3-4b-it",
        name: "Gemma 3 4B",
        provider: "local",
        description: "Google's 4B multimodal model for on-device inference via CoreML.",
        contextWindow: 128_000,
        maxOutputTokens: 8192,
        capabilities: [.chat, .reasoning, .vision, .multimodal],
        isLocal: true,
        supportsVision: true
    )

    // MARK: - Common Model Lists

    static var anthropicModels: [AIModel] {
        [claude46Opus, claude45Opus, claude45Sonnet, claude45Haiku, claude4Opus, claude4Sonnet, claude35Haiku]
    }

    static var openaiModels: [AIModel] {
        [gpt4o, gpt4oMini, o1, o1Mini]
    }

    static var googleModels: [AIModel] {
        [gemini3Pro, gemini3Flash, gemini25Pro, gemini25Flash, gemini2Flash, gemini15Pro]
    }

    static var deepseekModels: [AIModel] {
        [deepseekChat, deepseekReasoner]
    }

    static var groqModels: [AIModel] {
        [llama370b, llama318b, mixtral8x7b]
    }

    static var perplexityModels: [AIModel] {
        [sonarPro, sonar, sonarReasoning]
    }

    static var openRouterModels: [AIModel] {
        [orClaude46Opus, orClaude45Sonnet, orGpt4o, orGemini25Pro, orDeepseekChat, orLlama370b]
    }

    static var localModels: [AIModel] {
        [gptOSS20B, gptOSS120B, qwen3VL8B, gemma3_1B, gemma3_4B]
    }

    static var allKnownModels: [AIModel] {
        anthropicModels + openaiModels + googleModels + deepseekModels + groqModels + perplexityModels + openRouterModels + localModels
    }
}
