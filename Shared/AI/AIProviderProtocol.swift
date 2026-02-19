import Foundation
import OSLog

// MARK: - AI Provider Protocol

protocol AIProvider: Sendable {
    var metadata: ProviderMetadata { get }
    var capabilities: ProviderCapabilities { get }

    func validateAPIKey(_ key: String) async throws -> ValidationResult
    func chat(messages: [AIMessage], model: String, stream: Bool) async throws -> AsyncThrowingStream<ChatResponse, Error>
    func listModels() async throws -> [ProviderAIModel]
}

// MARK: - Provider Metadata

struct ProviderMetadata: Codable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let logoURL: URL?
    let websiteURL: URL
    let documentationURL: URL

    init(
        id: UUID = UUID(),
        name: String,
        displayName: String,
        logoURL: URL? = nil,
        websiteURL: URL,
        documentationURL: URL
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.logoURL = logoURL
        self.websiteURL = websiteURL
        self.documentationURL = documentationURL
    }
}

// MARK: - Provider Capabilities

struct ProviderCapabilities: Codable, Sendable {
    let supportsStreaming: Bool
    let supportsVision: Bool
    let supportsFunctionCalling: Bool
    let supportsWebSearch: Bool
    let maxContextTokens: Int
    let maxOutputTokens: Int
    let supportedModalities: [Modality]

    enum Modality: String, Codable, Sendable {
        case text
        case image
        case audio
        case video
    }

    init(
        supportsStreaming: Bool = true,
        supportsVision: Bool = false,
        supportsFunctionCalling: Bool = false,
        supportsWebSearch: Bool = false,
        maxContextTokens: Int = 128_000,
        maxOutputTokens: Int = 4096,
        supportedModalities: [Modality] = [.text]
    ) {
        self.supportsStreaming = supportsStreaming
        self.supportsVision = supportsVision
        self.supportsFunctionCalling = supportsFunctionCalling
        self.supportsWebSearch = supportsWebSearch
        self.maxContextTokens = maxContextTokens
        self.maxOutputTokens = maxOutputTokens
        self.supportedModalities = supportedModalities
    }
}

// MARK: - Validation Result

struct ValidationResult: Sendable {
    let isValid: Bool
    let error: String?

    static func success() -> ValidationResult {
        ValidationResult(isValid: true, error: nil)
    }

    static func failure(_ error: String) -> ValidationResult {
        ValidationResult(isValid: false, error: error)
    }
}

// MARK: - Chat Response

struct ChatResponse: Sendable {
    enum ResponseType: Sendable {
        case delta(String) // Streaming chunk
        case complete(AIMessage) // Final message
        case error(Error)
    }

    let type: ResponseType

    static func delta(_ text: String) -> ChatResponse {
        ChatResponse(type: .delta(text))
    }

    static func complete(_ message: AIMessage) -> ChatResponse {
        ChatResponse(type: .complete(message))
    }

    static func error(_ error: Error) -> ChatResponse {
        ChatResponse(type: .error(error))
    }
}

// MARK: - Provider AI Model Info
// Note: The main AIModel type is in Shared/Core/Models/AIModel.swift
// This is a simpler provider-specific version for API responses

struct ProviderAIModel: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let contextWindow: Int
    let maxOutputTokens: Int
    let inputPricePerMillion: Decimal
    let outputPricePerMillion: Decimal
    let supportsVision: Bool
    let supportsFunctionCalling: Bool

    init(
        id: String,
        name: String,
        description: String? = nil,
        contextWindow: Int,
        maxOutputTokens: Int,
        inputPricePerMillion: Decimal,
        outputPricePerMillion: Decimal,
        supportsVision: Bool = false,
        supportsFunctionCalling: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.inputPricePerMillion = inputPricePerMillion
        self.outputPricePerMillion = outputPricePerMillion
        self.supportsVision = supportsVision
        self.supportsFunctionCalling = supportsFunctionCalling
    }
}

// MARK: - Claude API Types (2026-02 Audit)

// MARK: - Cache Control (Anthropic)

/// Cache control for Anthropic prompt caching
/// GA as of August 2025 - 1-hour TTL now available
enum CacheControl: Sendable {
    case ephemeral      // 5-minute TTL (default)
    case longLived      // 1-hour TTL (GA as of Aug 2025)

    var ttl: String {
        switch self {
        case .ephemeral: return "5m"
        case .longLived: return "1h"
        }
    }
}

// MARK: - Extended Thinking (Anthropic)

/// Configuration for Claude's extended thinking mode
struct ThinkingConfig: Sendable {
    let enabled: Bool
    let budgetTokens: Int  // 1,024 to 128,000

    init(enabled: Bool = true, budgetTokens: Int = 10_000) {
        self.enabled = enabled
        self.budgetTokens = min(max(budgetTokens, 1024), 128_000)
    }

    static let `default` = ThinkingConfig()
}

// MARK: - Effort Level (P0 - Opus 4.5 Only)

/// Controls quality/cost tradeoff for Claude Opus 4.5
/// Beta header: effort-2025-11-24
enum EffortLevel: String, Sendable {
    case high      // Maximum quality, higher token usage
    case medium    // Balanced (default)
    case low       // Faster, lower token usage
}

// MARK: - Context Management (P1)

/// Auto-clear old tool results when approaching context limits
/// Beta header: context-management-2025-06-27
struct ContextManagement: Sendable {
    let edits: [ContextEdit]

    /// Convenience: clear tool uses when reaching token threshold
    static func clearToolUses(
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
    static func clearThinking(atTokens threshold: Int) -> ContextManagement {
        ContextManagement(edits: [
            ContextEdit(
                type: .clearThinking,
                trigger: ContextTrigger(inputTokens: threshold)
            )
        ])
    }
}

struct ContextEdit: Sendable {
    enum EditType: String, Sendable {
        case clearToolUses = "clear_tool_uses_20250919"
        case clearThinking = "clear_thinking_20251015"
    }

    let type: EditType
    let trigger: ContextTrigger
    let keep: Int?           // Number of tool uses to keep
    let clearAtLeast: Int?   // Minimum to clear
    let excludeTools: [String]?

    init(
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

struct ContextTrigger: Sendable {
    let inputTokens: Int
}

// MARK: - Server Tools (P2)

/// Anthropic server-side tools (web search, web fetch, tool search, etc.)
enum ServerTool: Sendable {
    case webSearch(WebSearchConfig)
    case webFetch(WebFetchConfig)
    case toolSearch(ToolSearchConfig)

    var toolDefinition: [String: Any] {
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

        case let .toolSearch(config):
            var tool: [String: Any] = [
                "type": "tool_search",
                "name": "tool_search"
            ]
            if let maxResults = config.maxResults {
                tool["max_results"] = maxResults
            }
            // Include tool definitions for Claude to search through
            tool["tools"] = config.tools.map { toolDef -> [String: Any] in
                var def: [String: Any] = [
                    "name": toolDef.name,
                    "description": toolDef.description
                ]
                if !toolDef.parameters.isEmpty {
                    def["input_schema"] = toolDef.parameters
                }
                return def
            }
            return tool
        }
    }
}

/// Tool search configuration — lets Claude search thousands of tools without consuming context
struct ToolSearchConfig: Sendable {
    let tools: [ToolDefinition]
    let maxResults: Int?

    init(tools: [ToolDefinition], maxResults: Int? = 20) {
        self.tools = tools
        self.maxResults = maxResults
    }
}

/// Tool choice — controls how Claude selects tools
struct AnthropicToolChoice: Sendable {
    enum ChoiceType: String, Sendable {
        case auto        // Claude decides
        case any         // Must use a tool
        case tool        // Must use specific tool
        case none        // No tool use
    }

    let type: ChoiceType
    let toolName: String?
    let disableParallelToolUse: Bool?

    init(type: ChoiceType, toolName: String? = nil, disableParallelToolUse: Bool? = nil) {
        self.type = type
        self.toolName = toolName
        self.disableParallelToolUse = disableParallelToolUse
    }

    var toDictionary: [String: Any] {
        var dict: [String: Any] = ["type": type.rawValue]
        if let name = toolName, type == .tool {
            dict["name"] = name
        }
        if let disable = disableParallelToolUse {
            dict["disable_parallel_tool_use"] = disable
        }
        return dict
    }
}

/// Context compaction — Claude summarizes its own context for long sessions
struct CompactionConfig: Sendable {
    let enabled: Bool
    let triggerThreshold: Int
    let targetSize: Int

    init(enabled: Bool = true, triggerThreshold: Int = 150_000, targetSize: Int = 80_000) {
        self.enabled = enabled
        self.triggerThreshold = triggerThreshold
        self.targetSize = targetSize
    }
}

/// Web search tool configuration
/// Pricing: $10 per 1,000 searches
struct WebSearchConfig: Sendable {
    let maxUses: Int?
    let allowedDomains: [String]?
    let blockedDomains: [String]?
    let userLocation: UserLocation?

    init(
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

    static let `default` = WebSearchConfig()
}

/// Web fetch tool configuration
/// Pricing: FREE (only standard token costs)
struct WebFetchConfig: Sendable {
    let maxUses: Int?
    let allowedDomains: [String]?
    let blockedDomains: [String]?
    let maxContentTokens: Int?
    let citationsEnabled: Bool

    init(
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

    static let `default` = WebFetchConfig()
}

/// User location for localized search results
struct UserLocation: Sendable {
    let city: String?
    let region: String?
    let country: String?
    let timezone: String?

    init(
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

// MARK: - Token Usage

struct TokenUsage: Codable, Sendable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let cachedTokens: Int?

    init(
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

// MARK: - Tool Definition

private let toolDefinitionLogger = Logger(subsystem: "ai.thea.app", category: "ToolDefinition")

struct ToolDefinition: Codable, Sendable {
    let name: String
    let description: String
    let parametersJSON: Data  // Store as JSON Data for Sendable compliance

    var parameters: [String: Any] {
        do {
            return (try JSONSerialization.jsonObject(with: parametersJSON) as? [String: Any]) ?? [:]
        } catch {
            toolDefinitionLogger.error("Failed to deserialize tool parameters: \(error.localizedDescription)")
            return [:]
        }
    }

    init(name: String, description: String, parameters: [String: Any] = [:]) {
        self.name = name
        self.description = description
        do {
            self.parametersJSON = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            toolDefinitionLogger.error("Failed to serialize tool parameters: \(error.localizedDescription)")
            self.parametersJSON = Data()
        }
    }

    enum CodingKeys: String, CodingKey {
        case name, description, parametersJSON
    }
}
