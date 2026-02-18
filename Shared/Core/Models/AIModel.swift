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

// Known model definitions are in AIModelCatalog.swift

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
