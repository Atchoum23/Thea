//
//  InferenceRelayProtocol.swift
//  Thea
//
//  Wire protocol types for inference relay between tvOS clients and macOS server.
//  Pure Foundation + Codable — zero dependencies on SwiftData/AppKit/UIKit.
//  Included in both macOS and tvOS targets.
//
//  CREATED: February 8, 2026
//

import Foundation

// MARK: - Inference Relay Message

/// Top-level message envelope for inference relay communication.
/// Separate from RemoteMessage to keep the relay protocol self-contained.
public enum InferenceRelayMessage: Codable, Sendable {
    // Client → Server
    case inferenceRequest(InferenceRequest)
    case listModelsRequest
    case capabilitiesRequest

    // Server → Client
    case streamDelta(InferenceStreamDelta)
    case streamComplete(InferenceStreamComplete)
    case streamError(InferenceStreamError)
    case listModelsResponse(InferenceModelList)
    case capabilitiesResponse(InferenceServerCapabilities)
}

// MARK: - Request Types

/// A chat inference request from a tvOS client.
public struct InferenceRequest: Codable, Sendable {
    /// Unique ID for correlating response stream chunks
    public let requestId: String
    /// Conversation messages (simplified role+content)
    public let messages: [InferenceMessage]
    /// Optional model preference; nil = let server orchestrator decide
    public let preferredModel: String?
    /// Always true for streaming responses
    public let stream: Bool

    public init(
        requestId: String = UUID().uuidString,
        messages: [InferenceMessage],
        preferredModel: String? = nil,
        stream: Bool = true
    ) {
        self.requestId = requestId
        self.messages = messages
        self.preferredModel = preferredModel
        self.stream = stream
    }
}

/// A single message in a conversation (simplified for wire protocol).
public struct InferenceMessage: Codable, Sendable {
    /// "user", "assistant", or "system"
    public let role: String
    /// Text content only (V1)
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - Response Types

/// A streaming text delta from the server.
public struct InferenceStreamDelta: Codable, Sendable {
    /// Correlates to the original request
    public let requestId: String
    /// Text chunk
    public let delta: String
    /// Sequential chunk index (0-based)
    public let index: Int

    public init(requestId: String, delta: String, index: Int) {
        self.requestId = requestId
        self.delta = delta
        self.index = index
    }
}

/// Final completion message with metadata.
public struct InferenceStreamComplete: Codable, Sendable {
    /// Correlates to the original request
    public let requestId: String
    /// Full accumulated response text
    public let fullText: String
    /// Which model actually responded (e.g. "claude-sonnet-4-20250514")
    public let model: String
    /// Which provider was used (e.g. "Anthropic")
    public let provider: String
    /// Token count if available
    public let tokenCount: Int?

    public init(
        requestId: String,
        fullText: String,
        model: String,
        provider: String,
        tokenCount: Int? = nil
    ) {
        self.requestId = requestId
        self.fullText = fullText
        self.model = model
        self.provider = provider
        self.tokenCount = tokenCount
    }
}

/// Error during inference stream.
public struct InferenceStreamError: Codable, Sendable {
    /// Correlates to the original request
    public let requestId: String
    /// Human-readable error description
    public let errorDescription: String

    public init(requestId: String, errorDescription: String) {
        self.requestId = requestId
        self.errorDescription = errorDescription
    }
}

// MARK: - Model Discovery

/// List of available models on the server.
public struct InferenceModelList: Codable, Sendable {
    public let models: [InferenceModelInfo]

    public init(models: [InferenceModelInfo]) {
        self.models = models
    }
}

/// Information about a single available model.
public struct InferenceModelInfo: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let provider: String
    public let isDefault: Bool

    public init(id: String, name: String, provider: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.provider = provider
        self.isDefault = isDefault
    }
}

// MARK: - Server Capabilities

/// Advertised capabilities of the macOS inference server.
public struct InferenceServerCapabilities: Codable, Sendable {
    public let serverName: String
    public let supportsStreaming: Bool
    public let supportsOrchestrator: Bool
    public let availableProviderCount: Int
    public let deviceName: String

    public init(
        serverName: String,
        supportsStreaming: Bool = true,
        supportsOrchestrator: Bool = true,
        availableProviderCount: Int,
        deviceName: String
    ) {
        self.serverName = serverName
        self.supportsStreaming = supportsStreaming
        self.supportsOrchestrator = supportsOrchestrator
        self.availableProviderCount = availableProviderCount
        self.deviceName = deviceName
    }
}
