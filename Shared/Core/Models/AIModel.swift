// AIModel.swift
// Thea V2
//
// AI model representation with capabilities and metadata

import Foundation

// MARK: - AI Model

/// Represents an AI model available for use
public struct AIModel: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let provider: String
    public let description: String?

    public let contextWindow: Int
    public let maxOutputTokens: Int
    public let capabilities: [ModelCapability]

    public let inputCostPer1K: Decimal?
    public let outputCostPer1K: Decimal?

    public let isLocal: Bool
    public let supportsStreaming: Bool
    public let supportsVision: Bool
    public let supportsFunctionCalling: Bool

    public init(
        id: String,
        name: String,
        provider: String,
        description: String? = nil,
        contextWindow: Int = 128_000,
        maxOutputTokens: Int = 4096,
        capabilities: [ModelCapability] = [.chat],
        inputCostPer1K: Decimal? = nil,
        outputCostPer1K: Decimal? = nil,
        isLocal: Bool = false,
        supportsStreaming: Bool = true,
        supportsVision: Bool = false,
        supportsFunctionCalling: Bool = false
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.description = description
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.capabilities = capabilities
        self.inputCostPer1K = inputCostPer1K
        self.outputCostPer1K = outputCostPer1K
        self.isLocal = isLocal
        self.supportsStreaming = supportsStreaming
        self.supportsVision = supportsVision
        self.supportsFunctionCalling = supportsFunctionCalling
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: AIModel, rhs: AIModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Codable

extension AIModel: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, provider, description, contextWindow, maxOutputTokens
        case capabilities, inputCostPer1K, outputCostPer1K, isLocal
        case supportsStreaming, supportsVision, supportsFunctionCalling
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        provider = try container.decode(String.self, forKey: .provider)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        contextWindow = try container.decode(Int.self, forKey: .contextWindow)
        maxOutputTokens = try container.decode(Int.self, forKey: .maxOutputTokens)
        capabilities = try container.decode([ModelCapability].self, forKey: .capabilities)
        inputCostPer1K = try container.decodeIfPresent(Decimal.self, forKey: .inputCostPer1K)
        outputCostPer1K = try container.decodeIfPresent(Decimal.self, forKey: .outputCostPer1K)
        isLocal = try container.decode(Bool.self, forKey: .isLocal)
        supportsStreaming = try container.decode(Bool.self, forKey: .supportsStreaming)
        supportsVision = try container.decode(Bool.self, forKey: .supportsVision)
        supportsFunctionCalling = try container.decode(Bool.self, forKey: .supportsFunctionCalling)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(provider, forKey: .provider)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(contextWindow, forKey: .contextWindow)
        try container.encode(maxOutputTokens, forKey: .maxOutputTokens)
        try container.encode(capabilities, forKey: .capabilities)
        try container.encodeIfPresent(inputCostPer1K, forKey: .inputCostPer1K)
        try container.encodeIfPresent(outputCostPer1K, forKey: .outputCostPer1K)
        try container.encode(isLocal, forKey: .isLocal)
        try container.encode(supportsStreaming, forKey: .supportsStreaming)
        try container.encode(supportsVision, forKey: .supportsVision)
        try container.encode(supportsFunctionCalling, forKey: .supportsFunctionCalling)
    }
}

// MARK: - Model Capability

public enum ModelCapability: String, Codable, Sendable, CaseIterable {
    case chat           // Basic chat completion
    case completion     // Text completion
    case vision         // Image understanding
    case codeGeneration // Code-specific training
    case reasoning      // Extended reasoning
    case search         // Web search integration
    case embedding      // Text embeddings
    case functionCalling // Tool use
    case multimodal     // Multiple modalities
    case analysis       // Data analysis
}

// MARK: - Model Category

public enum ModelCategory: String, Codable, Sendable, CaseIterable {
    case flagship       // Most capable
    case standard       // General purpose
    case fast           // Speed optimized
    case specialized    // Domain-specific
    case local          // Local/on-device
    case embedding      // Embedding models
}

// MARK: - Known Models

public extension AIModel {
    // MARK: - Anthropic Models (Claude 4.5 - Latest)

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
    // Popular models accessible via OpenRouter (uses vendor/model ID format)

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

    // MARK: - Common Model Lists

    static var anthropicModels: [AIModel] {
        [claude45Opus, claude45Sonnet, claude45Haiku, claude4Opus, claude4Sonnet, claude35Haiku]
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
        [orClaude45Sonnet, orGpt4o, orGemini25Pro, orDeepseekChat, orLlama370b]
    }

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

    static var localModels: [AIModel] {
        [gptOSS20B, gptOSS120B, qwen3VL8B, gemma3_1B, gemma3_4B]
    }

    static var allKnownModels: [AIModel] {
        anthropicModels + openaiModels + googleModels + deepseekModels + groqModels + perplexityModels + openRouterModels + localModels
    }
}

// MARK: - Model Performance

/// Tracks model performance for routing decisions
public struct ModelPerformance: Codable, Sendable {
    public let modelId: String
    public var successCount: Int
    public var failureCount: Int
    public var totalTokens: Int
    public var totalCost: Decimal
    public var averageLatency: TimeInterval
    public var lastUsed: Date

    public var successRate: Double {
        let total = successCount + failureCount
        guard total > 0 else { return 0 }
        return Double(successCount) / Double(total)
    }

    public init(
        modelId: String,
        successCount: Int = 0,
        failureCount: Int = 0,
        totalTokens: Int = 0,
        totalCost: Decimal = 0,
        averageLatency: TimeInterval = 0,
        lastUsed: Date = Date()
    ) {
        self.modelId = modelId
        self.successCount = successCount
        self.failureCount = failureCount
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.averageLatency = averageLatency
        self.lastUsed = lastUsed
    }

    public mutating func recordSuccess(tokens: Int, cost: Decimal, latency: TimeInterval) {
        successCount += 1
        totalTokens += tokens
        totalCost += cost

        // Update running average latency
        let totalCalls = Double(successCount + failureCount)
        averageLatency = ((averageLatency * (totalCalls - 1)) + latency) / totalCalls
        lastUsed = Date()
    }

    public mutating func recordFailure() {
        failureCount += 1
        lastUsed = Date()
    }
}
