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
    /// Default sync implementation that collects streaming chunks into a single response.
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

/// Describes a discrete capability that an AI provider may support.
public enum ProviderCapability: String, Codable, Sendable, CaseIterable {
    /// Basic chat completion
    case chat
    /// Streaming token-by-token responses
    case streaming
    /// Image and visual content understanding
    case vision
    /// Tool use / function calling
    case functionCalling
    /// Text embedding generation
    case embedding
    /// Integrated web search
    case webSearch
    /// Server-side code execution
    case codeExecution
    /// Extended chain-of-thought reasoning
    case reasoning
    /// Support for multiple input/output modalities
    case multimodal
}

// MARK: - Chat Types

/// A single message in a chat conversation, with a role and content.
public struct ChatMessage: Codable, Sendable {
    /// Role of the message sender (e.g. "user", "assistant", "system").
    public let role: String
    /// Content of the message, either plain text or multipart.
    public let content: ChatContent

    /// Creates a message with structured content.
    /// - Parameters:
    ///   - role: The sender role.
    ///   - content: The structured chat content.
    public init(role: String, content: ChatContent) {
        self.role = role
        self.content = content
    }

    /// Creates a message with plain text content.
    /// - Parameters:
    ///   - role: The sender role.
    ///   - text: The text content of the message.
    public init(role: String, text: String) {
        self.role = role
        self.content = .text(text)
    }
}

/// Content of a chat message, either plain text or multipart (text + images).
public enum ChatContent: Codable, Sendable {
    /// Plain text content.
    case text(String)
    /// Multipart content containing text and/or images.
    case multipart([ChatContentPart])

    /// Extracts the text value, joining multipart text segments with newlines.
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

/// A single part of multipart chat content.
public enum ChatContentPart: Codable, Sendable {
    /// Text content segment.
    case text(String)
    /// Inline image data with MIME type (e.g. "image/png").
    case image(Data, mimeType: String)
    /// Reference to an image at a URL.
    case imageURL(URL)
}

/// Options controlling AI chat completion behavior.
public struct ChatOptions: Sendable {
    /// Sampling temperature (0.0 = deterministic, 2.0 = very random).
    public let temperature: Double?
    /// Maximum tokens to generate in the response.
    public let maxTokens: Int?
    /// Nucleus sampling probability threshold.
    public let topP: Double?
    /// Whether to stream the response token by token.
    public let stream: Bool
    /// Tool definitions available for function calling.
    public let tools: [ToolDefinition]?
    /// System prompt prepended to the conversation.
    public let systemPrompt: String?
    /// Anthropic prompt caching configuration.
    public let cacheControl: CacheControl?
    /// Extended thinking / chain-of-thought configuration.
    public let thinking: ThinkingConfig?
    /// Structured output format (JSON, JSON schema).
    public let outputFormat: OutputFormat?
    /// Quality/cost tradeoff level (Opus 4.5 only).
    public let effort: EffortLevel?
    /// Automatic context management to clear old tool results.
    public let contextManagement: ContextManagement?
    /// Anthropic server-side tools (web search, web fetch).
    public let serverTools: [ServerTool]?
    /// Thinking level for Gemini 3 models.
    public let geminiThinkingLevel: GeminiThinkingLevel?
    /// Thinking mode for DeepSeek models.
    public let deepseekThinking: DeepSeekThinkingConfig?

    /// Creates chat options with the specified parameters.
    /// - Parameters:
    ///   - temperature: Sampling temperature.
    ///   - maxTokens: Maximum tokens to generate.
    ///   - topP: Nucleus sampling threshold.
    ///   - stream: Whether to stream the response.
    ///   - tools: Tool definitions for function calling.
    ///   - systemPrompt: System prompt text.
    ///   - cacheControl: Anthropic cache control setting.
    ///   - thinking: Extended thinking configuration.
    ///   - outputFormat: Structured output format.
    ///   - effort: Quality/cost tradeoff level.
    ///   - contextManagement: Context management rules.
    ///   - serverTools: Server-side tool configurations.
    ///   - geminiThinkingLevel: Gemini thinking level.
    ///   - deepseekThinking: DeepSeek thinking configuration.
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

    /// Default options: streaming enabled, all other parameters nil.
    public static let `default` = ChatOptions()
}

// MARK: - Cache Control (Anthropic)

/// Anthropic prompt caching TTL configuration.
public enum CacheControl: Sendable {
    /// 5-minute TTL (default ephemeral cache).
    case ephemeral
    /// 1-hour TTL (GA as of August 2025).
    case longLived

    /// Human-readable TTL string.
    public var ttl: String {
        switch self {
        case .ephemeral: return "5m"
        case .longLived: return "1h"
        }
    }
}

// MARK: - Extended Thinking (Anthropic)

/// Configuration for Anthropic extended thinking (chain-of-thought reasoning).
public struct ThinkingConfig: Sendable {
    /// Whether extended thinking is enabled.
    public let enabled: Bool
    /// Token budget for thinking (clamped to 1,024 - 128,000).
    public let budgetTokens: Int

    /// Creates a thinking configuration.
    /// - Parameters:
    ///   - enabled: Whether to enable extended thinking.
    ///   - budgetTokens: Token budget, clamped to [1024, 128000].
    public init(enabled: Bool = true, budgetTokens: Int = 10_000) {
        self.enabled = enabled
        self.budgetTokens = min(max(budgetTokens, 1024), 128_000)
    }

    /// Default configuration: enabled with 10,000 token budget.
    public static let `default` = ThinkingConfig()
}

// MARK: - Gemini Thinking Level

/// Thinking level for Gemini 3 models.
/// Controls how much the model thinks before responding.
public enum GeminiThinkingLevel: String, Sendable {
    /// Flash only - minimal thinking.
    case minimal
    /// Quick reasoning pass.
    case low
    /// Balanced reasoning (default for Flash).
    case medium
    /// Deep reasoning (default for Pro).
    case high

    /// Approximate thinking budget in tokens for Gemini 2.5 compatibility.
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

/// Thinking mode configuration for DeepSeek models.
public struct DeepSeekThinkingConfig: Sendable {
    /// Whether thinking mode is enabled.
    public let enabled: Bool

    /// Creates a DeepSeek thinking configuration.
    /// - Parameter enabled: Whether to enable thinking mode.
    public init(enabled: Bool = true) {
        self.enabled = enabled
    }

    /// Default configuration: thinking enabled.
    public static let `default` = DeepSeekThinkingConfig()
}

// MARK: - Structured Outputs (Anthropic)

/// Output format specification for structured AI responses.
public enum OutputFormat: Sendable {
    /// Basic JSON output without schema validation.
    case json
    /// JSON output validated against a JSON Schema (stored as serialized Data).
    case jsonSchema(Data)

    /// Creates a JSON schema output format from a dictionary.
    /// - Parameter schema: JSON Schema dictionary.
    /// - Returns: An output format with the serialized schema.
    public static func schema(_ schema: [String: Any]) -> OutputFormat {
        let data = (try? JSONSerialization.data(withJSONObject: schema)) ?? Data()
        return .jsonSchema(data)
    }
}

/// Definition of a tool available for AI function calling.
public struct ToolDefinition: Codable, Sendable {
    /// Tool name used in function call references.
    public let name: String
    /// Human-readable description of what the tool does.
    public let description: String
    /// JSON-serialized parameter schema for Sendable compliance.
    public let parametersJSON: Data

    /// Deserialized parameter schema dictionary.
    public var parameters: [String: Any] {
        (try? JSONSerialization.jsonObject(with: parametersJSON) as? [String: Any]) ?? [:]
    }

    /// Creates a tool definition.
    /// - Parameters:
    ///   - name: Tool name.
    ///   - description: What the tool does.
    ///   - parameters: JSON Schema describing the tool's parameters.
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

/// A chunk emitted during streaming AI response generation.
public enum StreamChunk: Sendable {
    /// A fragment of generated text content.
    case content(String)
    /// Stream completed with optional finish reason and token usage.
    case done(finishReason: String?, usage: TokenUsage?)
    /// An error occurred during streaming.
    case error(Error)
}

/// Token usage statistics for a single AI request.
public struct TokenUsage: Codable, Sendable {
    /// Number of tokens in the input prompt.
    public let promptTokens: Int
    /// Number of tokens generated in the response.
    public let completionTokens: Int
    /// Total tokens consumed (prompt + completion).
    public let totalTokens: Int
    /// Number of cached tokens (Anthropic prompt caching).
    public let cachedTokens: Int?

    /// Creates token usage statistics.
    /// - Parameters:
    ///   - promptTokens: Input prompt token count.
    ///   - completionTokens: Generated response token count.
    ///   - totalTokens: Total tokens (defaults to prompt + completion if nil).
    ///   - cachedTokens: Cached token count from prompt caching.
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

/// Complete response from a non-streaming AI chat request.
public struct ChatResponse: Sendable {
    /// Generated text content.
    public let content: String
    /// Reason the model stopped generating (e.g. "stop", "max_tokens").
    public let finishReason: String
    /// Token usage statistics, if available.
    public let usage: TokenUsage?

    /// Creates a chat response.
    /// - Parameters:
    ///   - content: Generated text.
    ///   - finishReason: Stop reason.
    ///   - usage: Token usage statistics.
    public init(content: String, finishReason: String, usage: TokenUsage? = nil) {
        self.content = content
        self.finishReason = finishReason
        self.usage = usage
    }
}

// MARK: - Provider Health

/// Health check result for an AI provider.
public struct ProviderHealth: Sendable {
    /// Whether the provider is reachable and functioning.
    public let isHealthy: Bool
    /// Round-trip latency of the health check, if measured.
    public let latency: TimeInterval?
    /// Error message if the provider is unhealthy.
    public let errorMessage: String?
    /// Timestamp when the health check was performed.
    public let checkedAt: Date

    /// Creates a provider health result.
    /// - Parameters:
    ///   - isHealthy: Whether the provider is healthy.
    ///   - latency: Measured latency.
    ///   - errorMessage: Error details if unhealthy.
    ///   - checkedAt: When the check was performed.
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

    /// Convenience: a healthy provider result.
    public static let healthy = ProviderHealth(isHealthy: true)

    /// Convenience: an unhealthy provider result with an error message.
    /// - Parameter message: Description of the health issue.
    /// - Returns: An unhealthy `ProviderHealth` value.
    public static func unhealthy(_ message: String) -> ProviderHealth {
        ProviderHealth(isHealthy: false, errorMessage: message)
    }
}

// MARK: - Provider Error

/// Errors that can occur during AI provider operations.
public enum ProviderError: Error, LocalizedError {
    /// Provider is not configured (missing API key or setup).
    case notConfigured(provider: String)
    /// API key is invalid or expired.
    case invalidAPIKey
    /// Request was rate-limited; retry after the specified interval.
    case rateLimited(retryAfter: TimeInterval?)
    /// Requested model does not exist or is unavailable.
    case modelNotFound(model: String)
    /// Input exceeds the model's context window.
    case contextTooLong(tokens: Int, max: Int)
    /// Model context window exceeded (stop reason from API).
    case contextWindowExceeded
    /// Model refused to respond due to safety guidelines.
    case safetyRefusal
    /// Network-level error (DNS, TLS, connection reset, etc.).
    case networkError(underlying: Error)
    /// Provider returned an unparseable or unexpected response.
    case invalidResponse(details: String)
    /// Server returned an HTTP error status code.
    case serverError(status: Int, message: String?)
    /// Request exceeded the configured timeout.
    case timeout
    /// Request was cancelled by the caller.
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

/// Controls quality/cost tradeoff for Claude Opus 4.5.
/// Uses beta header: effort-2025-11-24.
public enum EffortLevel: String, Sendable {
    /// Maximum quality, higher token usage.
    case high
    /// Balanced quality and cost (default).
    case medium
    /// Faster responses, lower token usage.
    case low
}

// MARK: - Context Management (P1)

/// Configures automatic context window management to clear old tool results
/// when approaching token limits. Uses beta header: context-management-2025-06-27.
public struct ContextManagement: Sendable {
    /// Edit rules to apply when context grows too large.
    public let edits: [ContextEdit]

    /// Creates a context management configuration.
    /// - Parameter edits: The edit rules to apply.
    public init(edits: [ContextEdit]) {
        self.edits = edits
    }

    /// Clears old tool use results when the token count exceeds a threshold.
    /// - Parameters:
    ///   - threshold: Input token count that triggers clearing.
    ///   - keepLast: Number of most recent tool uses to preserve.
    ///   - excludeTools: Tool names to never clear.
    /// - Returns: A configured `ContextManagement` instance.
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

    /// Clears thinking blocks when the token count exceeds a threshold.
    /// - Parameter threshold: Input token count that triggers clearing.
    /// - Returns: A configured `ContextManagement` instance.
    public static func clearThinking(atTokens threshold: Int) -> ContextManagement {
        ContextManagement(edits: [
            ContextEdit(
                type: .clearThinking,
                trigger: ContextTrigger(inputTokens: threshold)
            )
        ])
    }
}

/// A single context edit rule specifying what to clear and when.
public struct ContextEdit: Sendable {
    /// Type of content to clear from context.
    public enum EditType: String, Sendable {
        /// Clear old tool use result blocks.
        case clearToolUses = "clear_tool_uses_20250919"
        /// Clear thinking/reasoning blocks.
        case clearThinking = "clear_thinking_20251015"
    }

    /// What type of content to clear.
    public let type: EditType
    /// Condition that triggers this edit.
    public let trigger: ContextTrigger
    /// Number of recent items to keep (tool uses only).
    public let keep: Int?
    /// Minimum number of items to clear.
    public let clearAtLeast: Int?
    /// Tool names excluded from clearing.
    public let excludeTools: [String]?

    /// Creates a context edit rule.
    /// - Parameters:
    ///   - type: The type of content to clear.
    ///   - trigger: When to trigger the edit.
    ///   - keep: Number of recent items to preserve.
    ///   - clearAtLeast: Minimum items to clear.
    ///   - excludeTools: Tools to exclude from clearing.
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

/// Token threshold that triggers a context edit operation.
public struct ContextTrigger: Sendable {
    /// Input token count at which to trigger the context edit.
    public let inputTokens: Int

    /// Creates a context trigger.
    /// - Parameter inputTokens: Token count threshold.
    public init(inputTokens: Int) {
        self.inputTokens = inputTokens
    }
}

// MARK: - Server Tools (P2)

/// Anthropic server-side tools (web search, web fetch, etc.).
public enum ServerTool: Sendable {
    /// Server-side web search tool.
    case webSearch(WebSearchConfig)
    /// Server-side web page fetch tool.
    case webFetch(WebFetchConfig)

    /// Serializes the tool configuration to a dictionary for the API request body.
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

/// Configuration for the Anthropic web search server tool.
/// Pricing: $10 per 1,000 searches.
public struct WebSearchConfig: Sendable {
    /// Maximum number of searches allowed per request.
    public let maxUses: Int?
    /// Domains to restrict search results to.
    public let allowedDomains: [String]?
    /// Domains to exclude from search results.
    public let blockedDomains: [String]?
    /// User location for localized search results.
    public let userLocation: UserLocation?

    /// Creates a web search configuration.
    /// - Parameters:
    ///   - maxUses: Maximum search invocations.
    ///   - allowedDomains: Allowed domain whitelist.
    ///   - blockedDomains: Blocked domain blacklist.
    ///   - userLocation: User's approximate location.
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

    /// Default configuration with no restrictions.
    public static let `default` = WebSearchConfig()
}

/// Configuration for the Anthropic web fetch server tool.
/// Pricing: FREE (only standard token costs).
public struct WebFetchConfig: Sendable {
    /// Maximum number of fetch operations allowed per request.
    public let maxUses: Int?
    /// Domains to restrict fetching to.
    public let allowedDomains: [String]?
    /// Domains to block from fetching.
    public let blockedDomains: [String]?
    /// Maximum content tokens to extract from fetched pages.
    public let maxContentTokens: Int?
    /// Whether to enable citation annotations in the response.
    public let citationsEnabled: Bool

    /// Creates a web fetch configuration.
    /// - Parameters:
    ///   - maxUses: Maximum fetch invocations.
    ///   - allowedDomains: Allowed domain whitelist.
    ///   - blockedDomains: Blocked domain blacklist.
    ///   - maxContentTokens: Token limit for fetched content.
    ///   - citationsEnabled: Whether to annotate citations.
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

    /// Default configuration with no restrictions and citations disabled.
    public static let `default` = WebFetchConfig()
}

/// Approximate user location for localized search results.
public struct UserLocation: Sendable {
    /// City name.
    public let city: String?
    /// State or region name.
    public let region: String?
    /// ISO country code.
    public let country: String?
    /// IANA timezone identifier (e.g. "America/New_York").
    public let timezone: String?

    /// Creates a user location.
    /// - Parameters:
    ///   - city: City name.
    ///   - region: State or region.
    ///   - country: Country code.
    ///   - timezone: IANA timezone.
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

    /// Serializes the location to a dictionary for the API request body.
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": "approximate"]
        if let city { dict["city"] = city }
        if let region { dict["region"] = region }
        if let country { dict["country"] = country }
        if let timezone { dict["timezone"] = timezone }
        return dict
    }
}
