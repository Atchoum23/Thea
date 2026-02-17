// AIModel.swift
// Thea V2
//
// AI model representation with capabilities and metadata

import Foundation

// MARK: - AI Model

/// Represents an AI model available for use, with its capabilities, pricing, and constraints.
public struct AIModel: Identifiable, Sendable, Hashable {
    /// Unique model identifier (e.g. "claude-opus-4-20250514").
    public let id: String
    /// Human-readable model name (e.g. "Claude Opus 4").
    public let name: String
    /// Provider that hosts this model (e.g. "anthropic", "openai").
    public let provider: String
    /// Optional description of the model's strengths and use cases.
    public let description: String?

    /// Maximum input context window in tokens.
    public let contextWindow: Int
    /// Maximum output tokens the model can generate.
    public let maxOutputTokens: Int
    /// Capabilities this model supports (chat, vision, reasoning, etc.).
    public let capabilities: [ModelCapability]

    /// Cost per 1,000 input tokens in USD, if applicable.
    public let inputCostPer1K: Decimal?
    /// Cost per 1,000 output tokens in USD, if applicable.
    public let outputCostPer1K: Decimal?

    /// Whether this model runs locally on-device (MLX, CoreML, etc.).
    public let isLocal: Bool
    /// Whether the model supports streaming responses.
    public let supportsStreaming: Bool
    /// Whether the model supports image/vision input.
    public let supportsVision: Bool
    /// Whether the model supports tool use / function calling.
    public let supportsFunctionCalling: Bool

    /// Creates an AI model definition.
    /// - Parameters:
    ///   - id: Unique model identifier.
    ///   - name: Display name.
    ///   - provider: Hosting provider name.
    ///   - description: Optional model description.
    ///   - contextWindow: Maximum input context in tokens.
    ///   - maxOutputTokens: Maximum output tokens.
    ///   - capabilities: Supported capabilities.
    ///   - inputCostPer1K: Input cost per 1K tokens.
    ///   - outputCostPer1K: Output cost per 1K tokens.
    ///   - isLocal: Whether model runs on-device.
    ///   - supportsStreaming: Whether streaming is supported.
    ///   - supportsVision: Whether vision input is supported.
    ///   - supportsFunctionCalling: Whether function calling is supported.
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

    /// Hashes by model ID only, since IDs are unique.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Models are equal if their IDs match.
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

/// A discrete capability that an AI model may support.
public enum ModelCapability: String, Codable, Sendable, CaseIterable {
    /// Basic chat completion.
    case chat
    /// Text completion (non-chat).
    case completion
    /// Image and visual content understanding.
    case vision
    /// Code-specific training and generation.
    case codeGeneration
    /// Extended chain-of-thought reasoning.
    case reasoning
    /// Web search integration.
    case search
    /// Text embedding generation.
    case embedding
    /// Tool use / function calling.
    case functionCalling
    /// Support for multiple input/output modalities.
    case multimodal
    /// Data analysis and interpretation.
    case analysis
}

// MARK: - Model Category

/// Broad category for grouping AI models by their primary use case.
public enum ModelCategory: String, Codable, Sendable, CaseIterable {
    /// Most capable flagship model.
    case flagship
    /// General-purpose balanced model.
    case standard
    /// Speed-optimized model with lower latency.
    case fast
    /// Domain-specific model (code, math, etc.).
    case specialized
    /// Local on-device model (MLX, CoreML).
    case local
    /// Embedding-only model for vector search.
    case embedding
}

// Known model definitions are in AIModelCatalog.swift

// MARK: - Model Performance

/// Tracks cumulative performance metrics for a model, used for routing decisions.
public struct ModelPerformance: Codable, Sendable {
    /// Identifier of the tracked model.
    public let modelId: String
    /// Number of successful completions.
    public var successCount: Int
    /// Number of failed completions.
    public var failureCount: Int
    /// Cumulative tokens consumed across all requests.
    public var totalTokens: Int
    /// Cumulative cost in USD across all requests.
    public var totalCost: Decimal
    /// Running average response latency in seconds.
    public var averageLatency: TimeInterval
    /// When this model was last used.
    public var lastUsed: Date

    /// Success rate as a fraction (0.0 - 1.0).
    public var successRate: Double {
        let total = successCount + failureCount
        guard total > 0 else { return 0 }
        return Double(successCount) / Double(total)
    }

    /// Creates a model performance tracker.
    /// - Parameters:
    ///   - modelId: Model identifier to track.
    ///   - successCount: Initial success count.
    ///   - failureCount: Initial failure count.
    ///   - totalTokens: Initial cumulative tokens.
    ///   - totalCost: Initial cumulative cost.
    ///   - averageLatency: Initial average latency.
    ///   - lastUsed: Initial last-used timestamp.
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

    /// Records a successful completion and updates running averages.
    /// - Parameters:
    ///   - tokens: Tokens consumed in this request.
    ///   - cost: Cost of this request in USD.
    ///   - latency: Response latency in seconds.
    public mutating func recordSuccess(tokens: Int, cost: Decimal, latency: TimeInterval) {
        successCount += 1
        totalTokens += tokens
        totalCost += cost

        // Update running average latency
        let totalCalls = Double(successCount + failureCount)
        averageLatency = ((averageLatency * (totalCalls - 1)) + latency) / totalCalls
        lastUsed = Date()
    }

    /// Records a failed completion attempt.
    public mutating func recordFailure() {
        failureCount += 1
        lastUsed = Date()
    }
}
