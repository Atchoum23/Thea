// AIProvider.swift
// Thea V2
//
// Core provider protocol with capability declaration.
// This file defines the V2 API types used throughout the codebase.
//
// KEY V2 TYPES:
//   - ChatMessage: Simple message with role and content
//   - ChatOptions: Immutable options struct (temperature, maxTokens, stream, etc.)
//   - StreamChunk: Async stream output (.content, .done, .error)
//   - AIProvider: Protocol all providers implement
//
// V2 MIGRATION NOTES (February 2, 2026):
//   - ChatMessage replaces the old AIMessage type
//   - ChatOptions replaces the old `stream: Bool` parameter
//   - StreamChunk cases changed from .delta/.complete to .content/.done
//   - Provider.name replaces provider.metadata.name
//
// SEE ALSO: .claude/V2_MIGRATION_COMPLETE.md for full migration details

import Foundation

// MARK: - AI Provider Protocol

/// Protocol for all AI providers
public protocol AIProvider: Sendable {
    /// Unique provider identifier
    var id: String { get }

    /// Human-readable provider name
    var name: String { get }

    /// Whether the provider is properly configured (API key set, etc.)
    var isConfigured: Bool { get }

    /// Models available from this provider
    var supportedModels: [AIModel] { get }

    /// Capabilities this provider supports
    var capabilities: Set<ProviderCapability> { get }

    /// Send a chat completion request
    func chat(
        messages: [ChatMessage],
        model: String,
        options: ChatOptions
    ) async throws -> AsyncThrowingStream<StreamChunk, Error>

    /// Send a non-streaming chat completion request
    func chatSync(
        messages: [ChatMessage],
        model: String,
        options: ChatOptions
    ) async throws -> ChatResponse

    /// Check if provider is available (connectivity, API key valid, etc.)
    func checkHealth() async -> ProviderHealth
}

// MARK: - Default Implementation

public extension AIProvider {
    /// Default sync implementation using streaming
    func chatSync(
        messages: [ChatMessage],
        model: String,
        options: ChatOptions
    ) async throws -> ChatResponse {
        var fullContent = ""
        var finishReason: String?
        var usage: TokenUsage?

        for try await chunk in try await chat(messages: messages, model: model, options: options) {
            switch chunk {
            case let .content(text):
                fullContent += text
            case let .done(reason, tokenUsage):
                finishReason = reason
                usage = tokenUsage
            case .error:
                break
            }
        }

        return ChatResponse(
            content: fullContent,
            finishReason: finishReason ?? "stop",
            usage: usage
        )
    }
}

// MARK: - Provider Capability

public enum ProviderCapability: String, Codable, Sendable, CaseIterable {
    case chat           // Basic chat completion
    case streaming      // Streaming responses
    case vision         // Image understanding
    case functionCalling // Tool use
    case embedding      // Text embeddings
    case webSearch      // Integrated web search
    case codeExecution  // Code execution
    case reasoning      // Extended reasoning
    case multimodal     // Multiple modalities
}

// MARK: - Chat Types

public struct ChatMessage: Codable, Sendable {
    public let role: String
    public let content: ChatContent

    public init(role: String, content: ChatContent) {
        self.role = role
        self.content = content
    }

    public init(role: String, text: String) {
        self.role = role
        self.content = .text(text)
    }
}

public enum ChatContent: Codable, Sendable {
    case text(String)
    case multipart([ChatContentPart])

    public var textValue: String {
        switch self {
        case let .text(string):
            return string
        case let .multipart(parts):
            return parts.compactMap { part in
                if case let .text(text) = part {
                    return text
                }
                return nil
            }.joined(separator: "\n")
        }
    }
}

public enum ChatContentPart: Codable, Sendable {
    case text(String)
    case image(Data, mimeType: String)
    case imageURL(URL)
}

public struct ChatOptions: Sendable {
    public let temperature: Double?
    public let maxTokens: Int?
    public let topP: Double?
    public let stream: Bool
    public let tools: [ToolDefinition]?
    public let systemPrompt: String?
    public let cacheControl: CacheControl?
    public let thinking: ThinkingConfig?
    public let outputFormat: OutputFormat?
    public let effort: EffortLevel?                    // P0: Opus 4.5 only
    public let contextManagement: ContextManagement?   // P1: Auto-clear old tool results
    public let serverTools: [ServerTool]?              // P2: Web search, web fetch, etc.
    public let geminiThinkingLevel: GeminiThinkingLevel?  // Gemini 3 thinking level
    public let deepseekThinking: DeepSeekThinkingConfig?  // DeepSeek thinking mode

    public init(
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        stream: Bool = true,
        tools: [ToolDefinition]? = nil,
        systemPrompt: String? = nil,
        cacheControl: CacheControl? = nil,
        thinking: ThinkingConfig? = nil,
        outputFormat: OutputFormat? = nil,
        effort: EffortLevel? = nil,
        contextManagement: ContextManagement? = nil,
        serverTools: [ServerTool]? = nil,
        geminiThinkingLevel: GeminiThinkingLevel? = nil,
        deepseekThinking: DeepSeekThinkingConfig? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.stream = stream
        self.tools = tools
        self.systemPrompt = systemPrompt
        self.cacheControl = cacheControl
        self.thinking = thinking
        self.outputFormat = outputFormat
        self.effort = effort
        self.contextManagement = contextManagement
        self.serverTools = serverTools
        self.geminiThinkingLevel = geminiThinkingLevel
        self.deepseekThinking = deepseekThinking
    }

    public static let `default` = ChatOptions()
}

// MARK: - Cache Control (Anthropic)

public enum CacheControl: Sendable {
    case ephemeral      // 5-minute TTL (default)
    case longLived      // 1-hour TTL (GA as of Aug 2025)

    public var ttl: String {
        switch self {
        case .ephemeral: return "5m"
        case .longLived: return "1h"
        }
    }
}

// MARK: - Extended Thinking (Anthropic)

public struct ThinkingConfig: Sendable {
    public let enabled: Bool
    public let budgetTokens: Int  // 1,024 to 128,000

    public init(enabled: Bool = true, budgetTokens: Int = 10_000) {
        self.enabled = enabled
        self.budgetTokens = min(max(budgetTokens, 1024), 128_000)
    }

    public static let `default` = ThinkingConfig()
}

// MARK: - Gemini Thinking Level

/// Thinking level for Gemini 3 models
/// Controls how much the model thinks before responding
public enum GeminiThinkingLevel: String, Sendable {
    case minimal  // Flash only - minimal thinking
    case low      // Quick reasoning
    case medium   // Balanced (default for Flash)
    case high     // Deep reasoning (default for Pro)

    /// Approximate thinking budget in tokens for Gemini 2.5 compatibility
    public var approximateBudget: Int {
        switch self {
        case .minimal: return 1_024
        case .low: return 1_024
        case .medium: return 8_192
        case .high: return 24_576
        }
    }
}

// MARK: - DeepSeek Thinking Mode

/// Thinking mode configuration for DeepSeek models
public struct DeepSeekThinkingConfig: Sendable {
    public let enabled: Bool

    public init(enabled: Bool = true) {
        self.enabled = enabled
    }

    public static let `default` = DeepSeekThinkingConfig()
}

// MARK: - Structured Outputs (Anthropic)

public enum OutputFormat: Sendable {
    case json                           // Basic JSON output
    case jsonSchema(Data)               // JSON with schema validation (Data for Sendable)

    /// Create JSON schema output format
    public static func schema(_ schema: [String: Any]) -> OutputFormat {
        let data = (try? JSONSerialization.data(withJSONObject: schema)) ?? Data()
        return .jsonSchema(data)
    }
}

public struct ToolDefinition: Codable, Sendable {
    public let name: String
    public let description: String
    public let parametersJSON: Data  // Store as JSON Data for Sendable compliance

    public var parameters: [String: Any] {
        (try? JSONSerialization.jsonObject(with: parametersJSON) as? [String: Any]) ?? [:]
    }

    public init(name: String, description: String, parameters: [String: Any] = [:]) {
        self.name = name
        self.description = description
        self.parametersJSON = (try? JSONSerialization.data(withJSONObject: parameters)) ?? Data()
    }

    enum CodingKeys: String, CodingKey {
        case name, description, parametersJSON
    }
}

// MARK: - Stream Types

public enum StreamChunk: Sendable {
    case content(String)
    case done(finishReason: String?, usage: TokenUsage?)
    case error(Error)
}

public struct TokenUsage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    public let cachedTokens: Int?

    public init(
        promptTokens: Int,
        completionTokens: Int,
        totalTokens: Int? = nil,
        cachedTokens: Int? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens ?? (promptTokens + completionTokens)
        self.cachedTokens = cachedTokens
    }
}

public struct ChatResponse: Sendable {
    public let content: String
    public let finishReason: String
    public let usage: TokenUsage?

    public init(content: String, finishReason: String, usage: TokenUsage? = nil) {
        self.content = content
        self.finishReason = finishReason
        self.usage = usage
    }
}

// MARK: - Provider Health

public struct ProviderHealth: Sendable {
    public let isHealthy: Bool
    public let latency: TimeInterval?
    public let errorMessage: String?
    public let checkedAt: Date

    public init(
        isHealthy: Bool,
        latency: TimeInterval? = nil,
        errorMessage: String? = nil,
        checkedAt: Date = Date()
    ) {
        self.isHealthy = isHealthy
        self.latency = latency
        self.errorMessage = errorMessage
        self.checkedAt = checkedAt
    }

    public static let healthy = ProviderHealth(isHealthy: true)

    public static func unhealthy(_ message: String) -> ProviderHealth {
        ProviderHealth(isHealthy: false, errorMessage: message)
    }
}

// MARK: - Provider Error

public enum ProviderError: Error, LocalizedError {
    case notConfigured(provider: String)
    case invalidAPIKey
    case rateLimited(retryAfter: TimeInterval?)
    case modelNotFound(model: String)
    case contextTooLong(tokens: Int, max: Int)
    case contextWindowExceeded        // New: model_context_window_exceeded stop reason
    case safetyRefusal                // New: refusal stop reason
    case networkError(underlying: Error)
    case invalidResponse(details: String)
    case serverError(status: Int, message: String?)
    case timeout
    case cancelled

    public var errorDescription: String? {
        switch self {
        case let .notConfigured(provider):
            return "\(provider) is not configured. Please add your API key in Settings."
        case .invalidAPIKey:
            return "Invalid API key. Please check your credentials."
        case let .rateLimited(retryAfter):
            if let retry = retryAfter {
                return "Rate limited. Please wait \(Int(retry)) seconds before trying again."
            }
            return "Rate limited. Please wait before trying again."
        case let .modelNotFound(model):
            return "Model '\(model)' not found or not available."
        case let .contextTooLong(tokens, max):
            return "Context too long (\(tokens) tokens). Maximum is \(max) tokens."
        case .contextWindowExceeded:
            return "Model context window exceeded. The conversation is too long."
        case .safetyRefusal:
            return "The model declined to respond due to safety guidelines."
        case let .networkError(underlying):
            return "Network error: \(underlying.localizedDescription)"
        case let .invalidResponse(details):
            return "Invalid response from provider: \(details)"
        case let .serverError(status, message):
            return "Server error (\(status)): \(message ?? "Unknown error")"
        case .timeout:
            return "Request timed out."
        case .cancelled:
            return "Request was cancelled."
        }
    }
}

// MARK: - Effort Level (P0 - Opus 4.5 Only)

/// Controls quality/cost tradeoff for Claude Opus 4.5
/// Beta header: effort-2025-11-24
public enum EffortLevel: String, Sendable {
    case high      // Maximum quality, higher token usage
    case medium    // Balanced (default)
    case low       // Faster, lower token usage
}

// MARK: - Context Management (P1)

/// Auto-clear old tool results when approaching context limits
/// Beta header: context-management-2025-06-27
public struct ContextManagement: Sendable {
    public let edits: [ContextEdit]

    public init(edits: [ContextEdit]) {
        self.edits = edits
    }

    /// Convenience: clear tool uses when reaching token threshold
    public static func clearToolUses(
        atTokens threshold: Int,
        keepLast: Int = 3,
        excludeTools: [String]? = nil
    ) -> ContextManagement {
        ContextManagement(edits: [
            ContextEdit(
                type: .clearToolUses,
                trigger: ContextTrigger(inputTokens: threshold),
                keep: keepLast,
                excludeTools: excludeTools
            )
        ])
    }

    /// Convenience: clear thinking blocks when reaching token threshold
    public static func clearThinking(atTokens threshold: Int) -> ContextManagement {
        ContextManagement(edits: [
            ContextEdit(
                type: .clearThinking,
                trigger: ContextTrigger(inputTokens: threshold)
            )
        ])
    }
}

public struct ContextEdit: Sendable {
    public enum EditType: String, Sendable {
        case clearToolUses = "clear_tool_uses_20250919"
        case clearThinking = "clear_thinking_20251015"
    }

    public let type: EditType
    public let trigger: ContextTrigger
    public let keep: Int?           // Number of tool uses to keep
    public let clearAtLeast: Int?   // Minimum to clear
    public let excludeTools: [String]?

    public init(
        type: EditType,
        trigger: ContextTrigger,
        keep: Int? = nil,
        clearAtLeast: Int? = nil,
        excludeTools: [String]? = nil
    ) {
        self.type = type
        self.trigger = trigger
        self.keep = keep
        self.clearAtLeast = clearAtLeast
        self.excludeTools = excludeTools
    }
}

public struct ContextTrigger: Sendable {
    public let inputTokens: Int

    public init(inputTokens: Int) {
        self.inputTokens = inputTokens
    }
}

// MARK: - Server Tools (P2)

/// Anthropic server-side tools (web search, web fetch, etc.)
public enum ServerTool: Sendable {
    case webSearch(WebSearchConfig)
    case webFetch(WebFetchConfig)

    public var toolDefinition: [String: Any] {
        switch self {
        case let .webSearch(config):
            var tool: [String: Any] = [
                "type": "web_search_20250305",
                "name": "web_search"
            ]
            if let maxUses = config.maxUses {
                tool["max_uses"] = maxUses
            }
            if let allowed = config.allowedDomains {
                tool["allowed_domains"] = allowed
            }
            if let blocked = config.blockedDomains {
                tool["blocked_domains"] = blocked
            }
            if let location = config.userLocation {
                tool["user_location"] = location.toDictionary()
            }
            return tool

        case let .webFetch(config):
            var tool: [String: Any] = [
                "type": "web_fetch_20250910",
                "name": "web_fetch"
            ]
            if let maxUses = config.maxUses {
                tool["max_uses"] = maxUses
            }
            if let allowed = config.allowedDomains {
                tool["allowed_domains"] = allowed
            }
            if let blocked = config.blockedDomains {
                tool["blocked_domains"] = blocked
            }
            if let maxTokens = config.maxContentTokens {
                tool["max_content_tokens"] = maxTokens
            }
            if config.citationsEnabled {
                tool["citations"] = ["enabled": true]
            }
            return tool
        }
    }
}

/// Web search tool configuration
/// Pricing: $10 per 1,000 searches
public struct WebSearchConfig: Sendable {
    public let maxUses: Int?
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let userLocation: UserLocation?

    public init(
        maxUses: Int? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        userLocation: UserLocation? = nil
    ) {
        self.maxUses = maxUses
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.userLocation = userLocation
    }

    public static let `default` = WebSearchConfig()
}

/// Web fetch tool configuration
/// Pricing: FREE (only standard token costs)
public struct WebFetchConfig: Sendable {
    public let maxUses: Int?
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let maxContentTokens: Int?
    public let citationsEnabled: Bool

    public init(
        maxUses: Int? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        maxContentTokens: Int? = nil,
        citationsEnabled: Bool = false
    ) {
        self.maxUses = maxUses
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.maxContentTokens = maxContentTokens
        self.citationsEnabled = citationsEnabled
    }

    public static let `default` = WebFetchConfig()
}

/// User location for localized search results
public struct UserLocation: Sendable {
    public let city: String?
    public let region: String?
    public let country: String?
    public let timezone: String?

    public init(
        city: String? = nil,
        region: String? = nil,
        country: String? = nil,
        timezone: String? = nil
    ) {
        self.city = city
        self.region = region
        self.country = country
        self.timezone = timezone
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": "approximate"]
        if let city { dict["city"] = city }
        if let region { dict["region"] = region }
        if let country { dict["country"] = country }
        if let timezone { dict["timezone"] = timezone }
        return dict
    }
}
