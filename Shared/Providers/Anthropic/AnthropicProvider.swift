// AnthropicProvider.swift
// Thea V2
//
// Anthropic Claude API provider

import Foundation
import OSLog

// MARK: - Anthropic Provider

// @unchecked Sendable: all mutable state (apiKey, session) is set once at init; network requests
// use URLSession which manages its own thread safety; callbacks dispatched via async/await
public final class AnthropicProvider: AIProvider, @unchecked Sendable {
    public let id = "anthropic"
    public let name = "Anthropic"

    let logger = Logger(subsystem: "com.thea.v2", category: "AnthropicProvider")
    let baseURL = "https://api.anthropic.com/v1"
    private let apiKey: String
    private let apiVersion = "2023-06-01"

    // MARK: - Initialization

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - AIProvider Protocol

    public var isConfigured: Bool {
        !apiKey.isEmpty
    }

    public var supportedModels: [AIModel] {
        AIModel.anthropicModels
    }

    public var capabilities: Set<ProviderCapability> {
        [.chat, .streaming, .vision, .functionCalling, .reasoning]
    }

    // MARK: - Chat

    public func chat(
        messages: [ChatMessage],
        model: String,
        options: ChatOptions
    ) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        let requestBody = buildRequestBody(messages: messages, model: model, options: options)

        let request = try buildRequest(body: requestBody, options: options)

        if options.stream {
            return try await streamChat(request: request)
        } else {
            return try await nonStreamChat(request: request)
        }
    }

    // MARK: - Request Body Construction

    private func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        options: ChatOptions
    ) -> [String: Any] {
        var systemPrompt: String?
        var anthropicMessages: [[String: Any]] = []

        for msg in messages {
            if msg.role == "system" {
                systemPrompt = msg.content.textValue
            } else {
                anthropicMessages.append([
                    "role": msg.role,
                    "content": msg.content.textValue
                ])
            }
        }

        var requestBody: [String: Any] = [
            "model": model,
            "messages": anthropicMessages,
            "max_tokens": options.maxTokens ?? 4096,
            "stream": options.stream
        ]

        applySystemPrompt(to: &requestBody, systemPrompt: systemPrompt, options: options)
        applyModelParameters(to: &requestBody, options: options)
        applyOutputConfig(to: &requestBody, options: options)
        applyContextManagement(to: &requestBody, options: options)
        applyServerTools(to: &requestBody, options: options)

        return requestBody
    }

    private func applySystemPrompt(
        to requestBody: inout [String: Any],
        systemPrompt: String?,
        options: ChatOptions
    ) {
        guard let system = systemPrompt ?? options.systemPrompt else { return }

        if let cacheControl = options.cacheControl {
            // Use content block format with cache_control for prompt caching
            // Supports both 5-minute (ephemeral) and 1-hour (longLived) TTL
            requestBody["system"] = [
                [
                    "type": "text",
                    "text": system,
                    "cache_control": [
                        "type": "ephemeral",
                        "ttl": cacheControl.ttl
                    ]
                ]
            ]
        } else {
            requestBody["system"] = system
        }
    }

    private func applyModelParameters(to requestBody: inout [String: Any], options: ChatOptions) {
        // Claude 4.5 does NOT allow both temperature AND top_p in the same request
        // Temperature takes precedence; only use top_p if temperature is not set
        if let temp = options.temperature {
            requestBody["temperature"] = temp
        } else if let topP = options.topP {
            requestBody["top_p"] = topP
        }

        // Extended thinking support
        if let thinking = options.thinking, thinking.enabled {
            requestBody["thinking"] = [
                "type": "enabled",
                "budget_tokens": thinking.budgetTokens
            ]
        }
    }

    private func applyOutputConfig(to requestBody: inout [String: Any], options: ChatOptions) {
        // Structured outputs support (GA as of Jan 2026)
        var outputConfig: [String: Any] = [:]
        if let outputFormat = options.outputFormat {
            switch outputFormat {
            case .json:
                outputConfig["format"] = ["type": "json"]
            case let .jsonSchema(schemaData):
                if let schema = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] {
                    outputConfig["format"] = [
                        "type": "json_schema",
                        "schema": schema
                    ]
                }
            }
        }

        // Effort parameter (P0 - Opus 4.5 only)
        // Beta header: effort-2025-11-24
        if let effort = options.effort {
            outputConfig["effort"] = effort.rawValue
        }

        if !outputConfig.isEmpty {
            requestBody["output_config"] = outputConfig
        }
    }

    private func applyContextManagement(to requestBody: inout [String: Any], options: ChatOptions) {
        // Context management (P1) - auto-clear old tool results
        // Beta header: context-management-2025-06-27
        guard let contextMgmt = options.contextManagement else { return }

        requestBody["context_management"] = [
            "edits": contextMgmt.edits.map { edit -> [String: Any] in
                var editDict: [String: Any] = [
                    "type": edit.type.rawValue,
                    "trigger": ["input_tokens": edit.trigger.inputTokens]
                ]
                if let keep = edit.keep {
                    editDict["keep"] = ["tool_uses": keep]
                }
                if let clearAtLeast = edit.clearAtLeast {
                    editDict["clear_at_least"] = clearAtLeast
                }
                if let excludeTools = edit.excludeTools {
                    editDict["exclude_tools"] = excludeTools
                }
                return editDict
            }
        ]
    }

    private func applyServerTools(to requestBody: inout [String: Any], options: ChatOptions) {
        // Server tools (P2) - web search, web fetch
        guard let serverTools = options.serverTools else { return }

        var tools = requestBody["tools"] as? [[String: Any]] ?? []
        for serverTool in serverTools {
            tools.append(serverTool.toolDefinition)
        }
        requestBody["tools"] = tools
    }

    // MARK: - HTTP Request Construction

    private func buildRequest(body: [String: Any], options: ChatOptions) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw ProviderError.invalidResponse(details: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        // Build beta headers based on features used
        let betaHeaders = buildBetaHeaders(options: options)
        if !betaHeaders.isEmpty {
            request.setValue(betaHeaders.joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func buildBetaHeaders(options: ChatOptions) -> [String] {
        var betaHeaders: [String] = []

        // Effort parameter requires beta header (Opus 4.5 only)
        if options.effort != nil {
            betaHeaders.append("effort-2025-11-24")
        }

        // Context management requires beta header
        if options.contextManagement != nil {
            betaHeaders.append("context-management-2025-06-27")
        }

        // Interleaved thinking (think between tool calls)
        if options.thinking?.enabled == true {
            betaHeaders.append("interleaved-thinking-2025-05-14")
        }

        // Web fetch requires beta header
        if options.serverTools?.contains(where: { if case .webFetch = $0 { return true }; return false }) == true {
            betaHeaders.append("web-fetch-2025-09-10")
        }

        return betaHeaders
    }

    // MARK: - Stream Chat

    private func streamChat(request: URLRequest) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ProviderError.invalidResponse(details: "Invalid HTTP response")
                    }

                    if httpResponse.statusCode != 200 {
                        throw ProviderError.serverError(
                            status: httpResponse.statusCode,
                            message: "Anthropic API error"
                        )
                    }

                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))

                            guard let data = jsonString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                            else {
                                continue
                            }

                            // Handle different event types
                            if let eventType = json["type"] as? String {
                                switch eventType {
                                case "content_block_delta":
                                    if let delta = json["delta"] as? [String: Any] {
                                        // Handle regular text delta
                                        if let text = delta["text"] as? String {
                                            continuation.yield(.content(text))
                                        }
                                        // Handle thinking delta (extended thinking feature)
                                        // Note: thinking content is internal, we only stream the final response
                                        if let thinking = delta["thinking"] as? String {
                                            // Optionally log thinking for debugging
                                            self.logger.debug("Thinking: \(thinking)")
                                        }
                                    }
                                case "message_stop":
                                    continuation.yield(.done(finishReason: "stop", usage: nil))
                                case "message_delta":
                                    if let delta = json["delta"] as? [String: Any],
                                       let stopReason = delta["stop_reason"] as? String {
                                        // Parse usage if available (including cache tokens)
                                        let usage = self.parseUsage(from: json)
                                        continuation.yield(.done(finishReason: stopReason, usage: usage))
                                    }
                                // Handle server tool use (web search, web fetch)
                                case "server_tool_use":
                                    // Server tools are handled automatically by the API
                                    // We just log them for debugging
                                    if let toolName = json["name"] as? String {
                                        self.logger.debug("Server tool invoked: \(toolName)")
                                    }
                                // Handle server tool results
                                case "web_search_tool_result", "web_fetch_tool_result":
                                    // Results are automatically processed by the API
                                    self.logger.debug("Server tool result received")
                                default:
                                    break
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Non-Stream Chat

    private func nonStreamChat(request: URLRequest) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse(details: "Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 {
            // Try to parse error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ProviderError.serverError(status: httpResponse.statusCode, message: message)
            }
            throw ProviderError.serverError(
                status: httpResponse.statusCode,
                message: "Anthropic API error"
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String
        else {
            throw ProviderError.invalidResponse(details: "Could not parse response")
        }

        // Parse usage (including cache tokens for prompt caching)
        let usage = parseUsage(from: json)
        let stopReason = json["stop_reason"] as? String ?? "stop"

        return AsyncThrowingStream { continuation in
            continuation.yield(.content(text))
            continuation.yield(.done(finishReason: stopReason, usage: usage))
            continuation.finish()
        }
    }

    // MARK: - Usage Parsing

    private func parseUsage(from json: [String: Any]) -> TokenUsage? {
        guard let usageJson = json["usage"] as? [String: Any],
              let outputTokens = usageJson["output_tokens"] as? Int
        else {
            return nil
        }

        let inputTokens = usageJson["input_tokens"] as? Int ?? 0
        let cachedTokens = usageJson["cache_read_input_tokens"] as? Int
        return TokenUsage(
            promptTokens: inputTokens,
            completionTokens: outputTokens,
            cachedTokens: cachedTokens
        )
    }

    // MARK: - Health Check

    public func checkHealth() async -> ProviderHealth {
        guard isConfigured else {
            return .unhealthy("API key not configured")
        }

        // Anthropic doesn't have a dedicated health endpoint
        // We'll make a minimal request to check connectivity
        guard let url = URL(string: "\(baseURL)/messages") else {
            return .unhealthy("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        // Minimal request using fastest model
        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let start = Date()

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .unhealthy("Invalid response")
            }

            let latency = Date().timeIntervalSince(start)

            if httpResponse.statusCode == 200 {
                return ProviderHealth(isHealthy: true, latency: latency)
            } else if httpResponse.statusCode == 401 {
                return .unhealthy("Invalid API key")
            } else {
                return .unhealthy("Status code: \(httpResponse.statusCode)")
            }
        } catch {
            return .unhealthy("Network error: \(error.localizedDescription)")
        }
    }
}
