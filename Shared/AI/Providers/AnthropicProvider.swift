import Foundation
import OSLog

final class AnthropicProvider: AIProvider, Sendable {
    private let logger = Logger(subsystem: "ai.thea.app", category: "AnthropicProvider")

    let metadata = ProviderMetadata(
        name: "anthropic",
        displayName: "Anthropic (Claude)",
        logoURL: URL(string: "https://anthropic.com/favicon.ico"),
        // swiftlint:disable:next force_unwrapping
        websiteURL: URL(string: "https://anthropic.com")!,
        // swiftlint:disable:next force_unwrapping
        documentationURL: URL(string: "https://docs.anthropic.com")!
    )

    // periphery:ignore - Reserved: capabilities property — reserved for future feature activation
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        supportsVision: true,
        supportsFunctionCalling: true,
        supportsWebSearch: true,  // Web search now supported via server tools
        maxContextTokens: 200_000,
        maxOutputTokens: 32_000,  // Claude 4.5 supports up to 32K output
        supportedModalities: [.text, .image]
    )

    private let apiKey: String

    // periphery:ignore - Reserved: capabilities property reserved for future feature activation
    // Store configuration values at init time for Sendable compliance
    private let baseURL: String
    private let apiVersion: String
    private let maxTokens: Int
    private let requestTimeout: TimeInterval

    @MainActor
    init(apiKey: String) {
        self.apiKey = apiKey
        // Capture configuration values from AppConfiguration at init time for Sendable compliance
        let config = AppConfiguration.shared.providerConfig
        baseURL = config.anthropicBaseURL
        apiVersion = config.anthropicAPIVersion
        maxTokens = config.defaultMaxTokens
        requestTimeout = config.requestTimeoutSeconds
    }

    // MARK: - Validation

    // periphery:ignore - Reserved: validateAPIKey(_:) instance method — reserved for future feature activation
    func validateAPIKey(_ key: String) async throws -> ValidationResult {
        guard let url = URL(string: "\(baseURL)/messages") else {
            return .failure("Invalid API URL configuration")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = requestTimeout

        // periphery:ignore - Reserved: validateAPIKey(_:) instance method reserved for future feature activation
        // Test with minimal request
        let testModel = await MainActor.run { AppConfiguration.shared.apiValidationConfig.anthropicTestModel }
        let testBody: [String: Any] = [
            "model": testModel,
            "max_tokens": 1,
            "messages": [
                ["role": "user", "content": "Hi"]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: testBody)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return .success()
                } else if httpResponse.statusCode == 401 {
                    return .failure("Invalid API key")
                } else {
                    return .failure("Unexpected status code: \(httpResponse.statusCode)")
                }
            }
            return .failure("Invalid response")
        } catch {
            return .failure("Network error: \(error.localizedDescription)")
        }
    }

    // MARK: - Chat

    func chat(
        messages: [AIMessage],
        model: String,
        stream: Bool
    ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        let anthropicMessages = messages.map { msg in
            [
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content.textValue
            ]
        }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": anthropicMessages,
            "stream": stream
        ]

        guard let url = URL(string: "\(baseURL)/messages") else {
            throw AnthropicError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = requestTimeout
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        if stream {
            let requestCopy = request
            return AsyncThrowingStream { continuation in
                Task { @Sendable in
                    do {
                        let (asyncBytes, response) = try await URLSession.shared.bytes(for: requestCopy)

                        guard let httpResponse = response as? HTTPURLResponse,
                              httpResponse.statusCode == 200
                        else {
                            throw AnthropicError.invalidResponse
                        }

                        var accumulatedText = ""

                        for try await line in asyncBytes.lines {
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6))
                                guard let data = jsonString.data(using: .utf8) else { continue }
                                let json: [String: Any]
                                do {
                                    guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                                    json = parsed
                                } catch {
                                    logger.debug("Skipping malformed SSE line: \(error)")
                                    continue
                                }

                                if let type = json["type"] as? String {
                                    if type == "content_block_delta",
                                       let delta = json["delta"] as? [String: Any],
                                       let text = delta["text"] as? String
                                    {
                                        accumulatedText += text
                                        continuation.yield(.delta(text))
                                    } else if type == "message_stop" {
                                        let finalMessage = AIMessage(
                                            id: UUID(),
                                            conversationID: messages.first?.conversationID ?? UUID(),
                                            role: .assistant,
                                            content: .text(accumulatedText),
                                            timestamp: Date(),
                                            model: model
                                        )
                                        continuation.yield(.complete(finalMessage))
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
        } else {
            // Non-streaming
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else {
                throw AnthropicError.invalidResponse
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String
            else {
                throw AnthropicError.noResponse
            }

            let finalMessage = AIMessage(
                id: UUID(),
                conversationID: messages.first?.conversationID ?? UUID(),
                role: .assistant,
                content: .text(text),
                timestamp: Date(),
                model: model
            )

            return AsyncThrowingStream { continuation in
                continuation.yield(.complete(finalMessage))
                continuation.finish()
            }
        }
    }

    // MARK: - Models

    func listModels() async throws -> [ProviderAIModel] {
        [
            // Claude 4.6 models (Feb 2026 — latest generation)
            ProviderAIModel(
                id: "claude-opus-4-6",
                name: "Claude Opus 4.6",
                description: "Best agent/planning model (Feb 2026). 72.5% OSWorld. Highest injection resistance.",
                contextWindow: 200_000,
                maxOutputTokens: 64_000,
                inputPricePerMillion: 15.00,
                outputPricePerMillion: 75.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            ProviderAIModel(
                id: "claude-sonnet-4-6",
                name: "Claude Sonnet 4.6",
                description: "Near-flagship intelligence at Sonnet pricing (Feb 2026). Adaptive reasoning.",
                contextWindow: 200_000,
                maxOutputTokens: 64_000,
                inputPricePerMillion: 3.00,
                outputPricePerMillion: 15.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            // Claude 4.5 models
            ProviderAIModel(
                id: "claude-opus-4-5-20251101",
                name: "Claude Opus 4.5",
                description: "Most capable Claude model with effort control",
                contextWindow: 200_000,
                maxOutputTokens: 32_000,
                inputPricePerMillion: 15.00,
                outputPricePerMillion: 75.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            ProviderAIModel(
                id: "claude-sonnet-4-5-20250929",
                name: "Claude Sonnet 4.5",
                description: "Balanced intelligence and speed",
                contextWindow: 200_000,
                maxOutputTokens: 32_000,
                inputPricePerMillion: 3.00,
                outputPricePerMillion: 15.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            ProviderAIModel(
                id: "claude-haiku-4-5-20251001",
                name: "Claude Haiku 4.5",
                description: "Fast and cost-effective",
                contextWindow: 200_000,
                maxOutputTokens: 32_000,
                inputPricePerMillion: 1.00,
                outputPricePerMillion: 5.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            // Claude 4 models
            ProviderAIModel(
                id: "claude-opus-4-20250514",
                name: "Claude Opus 4",
                description: "Previous generation flagship model",
                contextWindow: 200_000,
                maxOutputTokens: 8192,
                inputPricePerMillion: 15.00,
                outputPricePerMillion: 75.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            ProviderAIModel(
                id: "claude-sonnet-4-20250514",
                name: "Claude Sonnet 4",
                description: "Previous generation balanced model",
                contextWindow: 200_000,
                maxOutputTokens: 8192,
                inputPricePerMillion: 3.00,
                outputPricePerMillion: 15.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            // Claude 3.5 models (legacy)
            ProviderAIModel(
                id: "claude-3-5-sonnet-20241022",
                name: "Claude 3.5 Sonnet",
                description: "Legacy balanced model",
                contextWindow: 200_000,
                maxOutputTokens: 8192,
                inputPricePerMillion: 3.00,
                outputPricePerMillion: 15.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            ProviderAIModel(
                id: "claude-3-5-haiku-20241022",
                name: "Claude 3.5 Haiku",
                description: "Legacy fast model",
                contextWindow: 200_000,
                maxOutputTokens: 8192,
                inputPricePerMillion: 1.00,
                outputPricePerMillion: 5.00,
                supportsVision: true,
                supportsFunctionCalling: true
            )
        ]
    }

    // MARK: - Advanced Chat (with Claude API 2026 features)

    /// Advanced chat with support for all Claude API features
    /// - Parameters:
    ///   - messages: The messages to send
    ///   - model: The model ID to use
    ///   - options: Advanced options including effort, context management, server tools
    /// - Returns: Streaming response
    // periphery:ignore - Reserved: chatAdvanced(messages:model:options:) instance method — reserved for future feature activation
    func chatAdvanced(
        messages: [AIMessage],
        model: String,
        options: AnthropicChatOptions
    ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        let requestBody = buildAdvancedRequestBody(messages: messages, model: model, options: options)
        let request = try buildAdvancedRequest(body: requestBody, model: model, options: options)

        if options.stream {
            return streamAdvancedResponse(request: request, model: model, messages: messages)
        // periphery:ignore - Reserved: chatAdvanced(messages:model:options:) instance method reserved for future feature activation
        } else {
            return try await nonStreamAdvancedResponse(request: request, messages: messages, model: model)
        }
    }

    // MARK: - Advanced Chat Helpers

    // periphery:ignore - Reserved: buildAdvancedRequestBody(messages:model:options:) instance method — reserved for future feature activation
    private func buildAdvancedRequestBody(
        messages: [AIMessage],
        model: String,
        options: AnthropicChatOptions
    ) -> [String: Any] {
        // For assistant messages that have stored thinking blocks, the Anthropic API
        // requires the exact original content block array to be sent back — not plain text.
        // Sending plain text for a message that originally contained thinking blocks
        // causes API Error 400: "thinking blocks cannot be modified".
        // periphery:ignore - Reserved: buildAdvancedRequestBody(messages:model:options:) instance method reserved for future feature activation
        let anthropicMessages: [[String: Any]] = messages.map { msg in
            let role = msg.role == .user ? "user" : "assistant"
            if msg.role == .assistant,
               let blocksData = msg.metadata?.rawContentBlocksData,
               let blocks = try? JSONSerialization.jsonObject(with: blocksData) as? [[String: Any]],
               !blocks.isEmpty {
                return ["role": role, "content": blocks]
            }
            return ["role": role, "content": msg.content.textValue]
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": options.maxTokens ?? maxTokens,
            "messages": anthropicMessages,
            "stream": options.stream
        ]

        if let systemPrompt = options.systemPrompt {
            if let cacheControl = options.cacheControl {
                body["system"] = [
                    [
                        "type": "text",
                        "text": systemPrompt,
                        "cache_control": ["type": "ephemeral", "ttl": cacheControl.ttl]
                    ]
                ]
            } else {
                body["system"] = systemPrompt
            }
        }

        if let effort = options.effort, model.contains("opus-4-5") {
            body["output_config"] = ["effort": effort.rawValue]
        }

        if let thinking = options.thinking, thinking.enabled {
            body["thinking"] = ["type": "enabled", "budget_tokens": thinking.budgetTokens]
        }

        if let contextMgmt = options.contextManagement {
            var edits: [[String: Any]] = []
            for edit in contextMgmt.edits {
                var editDict: [String: Any] = [
                    "type": edit.type.rawValue,
                    "trigger": ["input_tokens": edit.trigger.inputTokens]
                ]
                if let keep = edit.keep { editDict["keep"] = keep }
                if let clearAtLeast = edit.clearAtLeast { editDict["clear_at_least"] = clearAtLeast }
                if let excludeTools = edit.excludeTools { editDict["exclude_tools"] = excludeTools }
                edits.append(editDict)
            }
            body["context_management"] = ["edits": edits]
        }

        if let serverTools = options.serverTools {
            body["tools"] = serverTools.map { $0.toolDefinition }
        }

        if let toolChoice = options.toolChoice {
            body["tool_choice"] = toolChoice.toDictionary
        }

        return body
    }

    // periphery:ignore - Reserved: buildAdvancedRequest(body:model:options:) instance method — reserved for future feature activation
    private func buildAdvancedRequest(
        body: [String: Any],
        model _: String,
        options: AnthropicChatOptions
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw AnthropicError.invalidResponse
        }

// periphery:ignore - Reserved: buildAdvancedRequest(body:model:options:) instance method reserved for future feature activation

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = requestTimeout

        var betaHeaders: [String] = []
        if options.effort != nil { betaHeaders.append("effort-2025-11-24") }
        if options.contextManagement != nil { betaHeaders.append("context-management-2025-06-27") }
        if options.thinking?.enabled == true { betaHeaders.append("interleaved-thinking-2025-05-14") }
        if options.serverTools?.contains(where: { if case .webFetch = $0 { return true }; return false }) == true {
            betaHeaders.append("web-fetch-2025-09-10")
        }
        if let limit = options.extendedContextLimit, limit > 200_000 {
            betaHeaders.append("max-tokens-1m-2025-01-01")
        }
        if !betaHeaders.isEmpty {
            request.setValue(betaHeaders.joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // periphery:ignore - Reserved: streamAdvancedResponse(request:model:messages:) instance method — reserved for future feature activation
    private func streamAdvancedResponse(
        request: URLRequest,
        model: String,
        messages: [AIMessage]
    ) -> AsyncThrowingStream<ChatResponse, Error> {
        let requestCopy = request
        return AsyncThrowingStream { continuation in
            // periphery:ignore - Reserved: streamAdvancedResponse(request:model:messages:) instance method reserved for future feature activation
            Task { @Sendable [model, messages] in
                do {
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: requestCopy)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        if let httpResponse = response as? HTTPURLResponse {
                            throw AnthropicError.serverError(status: httpResponse.statusCode, message: "Advanced chat request failed")
                        }
                        throw AnthropicError.invalidResponse
                    }

                    var accumulatedText = ""
                    // Track content blocks so thinking/redacted_thinking are preserved for multi-turn
                    var contentBlocks: [[String: Any]] = []
                    var currentBlockType = ""
                    var currentThinking = ""

                    for try await line in asyncBytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        guard let data = jsonString.data(using: .utf8) else { continue }
                        let json: [String: Any]
                        do {
                            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                            json = parsed
                        } catch {
                            logger.debug("Skipping malformed SSE line: \(error)")
                            continue
                        }
                        guard let type = json["type"] as? String else { continue }

                        switch type {
                        case "content_block_start":
                            // redacted_thinking: full encrypted data is in the start event, not in deltas
                            if let block = json["content_block"] as? [String: Any],
                               let blockType = block["type"] as? String {
                                currentBlockType = blockType
                                currentThinking = ""
                                if blockType == "redacted_thinking", let encData = block["data"] as? String {
                                    contentBlocks.append(["type": "redacted_thinking", "data": encData])
                                    currentBlockType = "" // already captured
                                }
                            }
                        case "content_block_delta":
                            if let delta = json["delta"] as? [String: Any] {
                                let deltaType = delta["type"] as? String ?? ""
                                if deltaType == "text_delta" || deltaType == "text",
                                   let text = delta["text"] as? String {
                                    accumulatedText += text
                                    continuation.yield(.delta(text))
                                } else if deltaType == "thinking_delta",
                                          let thinking = delta["thinking"] as? String {
                                    currentThinking += thinking
                                }
                            }
                        case "content_block_stop":
                            // Seal the current block into our blocks array
                            if currentBlockType == "thinking" {
                                contentBlocks.append(["type": "thinking", "thinking": currentThinking])
                            } else if currentBlockType == "text", !accumulatedText.isEmpty {
                                contentBlocks.append(["type": "text", "text": accumulatedText])
                            }
                            currentBlockType = ""
                        case "message_stop":
                            // Only store rawContentBlocksData when thinking blocks are present;
                            // plain-text conversations don't need it.
                            let hasThinking = contentBlocks.contains { ($0["type"] as? String) == "thinking" || ($0["type"] as? String) == "redacted_thinking" }
                            let metadata: MessageMetadata? = hasThinking
                                ? MessageMetadata(rawContentBlocksData: try? JSONSerialization.data(withJSONObject: contentBlocks))
                                : nil
                            let finalMessage = AIMessage(
                                id: UUID(), conversationID: messages.first?.conversationID ?? UUID(),
                                role: .assistant, content: .text(accumulatedText),
                                timestamp: Date(), model: model, metadata: metadata
                            )
                            continuation.yield(.complete(finalMessage))
                        default: break
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

    // periphery:ignore - Reserved: nonStreamAdvancedResponse(request:messages:model:) instance method — reserved for future feature activation
    private func nonStreamAdvancedResponse(
        request: URLRequest,
        messages: [AIMessage],
        model: String
    ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        let (data, response) = try await URLSession.shared.data(for: request)
        // periphery:ignore - Reserved: nonStreamAdvancedResponse(request:messages:model:) instance method reserved for future feature activation
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                throw AnthropicError.serverError(status: httpResponse.statusCode, message: "Advanced chat request failed")
            }
            throw AnthropicError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]]
        else {
            throw AnthropicError.noResponse
        }

        // Extract the text content from whichever block carries it
        let text = contentBlocks.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw AnthropicError.noResponse }

        // Preserve content blocks for multi-turn thinking support
        let hasThinking = contentBlocks.contains { ($0["type"] as? String) == "thinking" || ($0["type"] as? String) == "redacted_thinking" }
        let metadata: MessageMetadata? = hasThinking
            ? MessageMetadata(rawContentBlocksData: try? JSONSerialization.data(withJSONObject: contentBlocks))
            : nil

        let finalMessage = AIMessage(
            id: UUID(), conversationID: messages.first?.conversationID ?? UUID(),
            role: .assistant, content: .text(text), timestamp: Date(), model: model, metadata: metadata
        )
        return AsyncThrowingStream { continuation in
            continuation.yield(.complete(finalMessage))
            continuation.finish()
        }
    }
}

// MARK: - Anthropic Chat Options

/// Advanced chat options for Claude API (2026 features)
struct AnthropicChatOptions: Sendable {
    let maxTokens: Int?
    let stream: Bool
    let systemPrompt: String?
    let cacheControl: CacheControl?
    let effort: EffortLevel?              // Opus 4.5 only
    let thinking: ThinkingConfig?
    // periphery:ignore - Reserved: stream property reserved for future feature activation
    let contextManagement: ContextManagement?
    let serverTools: [ServerTool]?
    let toolChoice: AnthropicToolChoice?  // Controls tool selection behavior
    // periphery:ignore - Reserved: compaction property — reserved for future feature activation
    let compaction: CompactionConfig?     // Context compaction for long sessions
    let extendedContextLimit: Int?        // For 1M token beta (nil = default 200K)

    // periphery:ignore - Reserved: toolChoice property reserved for future feature activation
    // periphery:ignore - Reserved: compaction property reserved for future feature activation
    // periphery:ignore - Reserved: extendedContextLimit property reserved for future feature activation
    init(
        // periphery:ignore - Reserved: init(maxTokens:stream:systemPrompt:cacheControl:effort:thinking:contextManagement:serverTools:toolChoice:compaction:extendedContextLimit:) initializer reserved for future feature activation
        maxTokens: Int? = nil,
        stream: Bool = true,
        systemPrompt: String? = nil,
        cacheControl: CacheControl? = nil,
        effort: EffortLevel? = nil,
        thinking: ThinkingConfig? = nil,
        contextManagement: ContextManagement? = nil,
        serverTools: [ServerTool]? = nil,
        toolChoice: AnthropicToolChoice? = nil,
        compaction: CompactionConfig? = nil,
        extendedContextLimit: Int? = nil
    ) {
        self.maxTokens = maxTokens
        self.stream = stream
        self.systemPrompt = systemPrompt
        self.cacheControl = cacheControl
        self.effort = effort
        self.thinking = thinking
        self.contextManagement = contextManagement
        self.serverTools = serverTools
        self.toolChoice = toolChoice
        self.compaction = compaction
        self.extendedContextLimit = extendedContextLimit
    }

    // periphery:ignore - Reserved: default static property reserved for future feature activation
    static let `default` = AnthropicChatOptions()
}

// MARK: - Errors

enum AnthropicError: Error, LocalizedError {
    case invalidResponse
    case invalidResponseDetails(String)
    case noResponse
    case serverError(status: Int, message: String?)
    case fileTooLarge(bytes: Int, maxBytes: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from Anthropic"
        case let .invalidResponseDetails(details):
            "Invalid response from Anthropic: \(details)"
        case .noResponse:
            "No response from Anthropic"
        case let .serverError(status, message):
            "Anthropic server error \(status)\(message.map { ": \($0)" } ?? "")"
        case let .fileTooLarge(bytes, maxBytes):
            "File too large: \(bytes) bytes exceeds \(maxBytes) byte limit"
        }
    }
}
