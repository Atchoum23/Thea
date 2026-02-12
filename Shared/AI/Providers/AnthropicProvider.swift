import Foundation

final class AnthropicProvider: AIProvider, Sendable {
    let metadata = ProviderMetadata(
        name: "anthropic",
        displayName: "Anthropic (Claude)",
        logoURL: URL(string: "https://anthropic.com/favicon.ico"),
        // swiftlint:disable:next force_unwrapping
        websiteURL: URL(string: "https://anthropic.com")!,
        // swiftlint:disable:next force_unwrapping
        documentationURL: URL(string: "https://docs.anthropic.com")!
    )

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
                                guard let data = jsonString.data(using: .utf8),
                                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                                else {
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
            // Claude 4.5 models (latest generation)
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
    func chatAdvanced(
        messages: [AIMessage],
        model: String,
        options: AnthropicChatOptions
    ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        let anthropicMessages = messages.map { msg in
            [
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content.textValue
            ]
        }

        var requestBody: [String: Any] = [
            "model": model,
            "max_tokens": options.maxTokens ?? maxTokens,
            "messages": anthropicMessages,
            "stream": options.stream
        ]

        // Add system prompt with optional cache control
        if let systemPrompt = options.systemPrompt {
            if let cacheControl = options.cacheControl {
                requestBody["system"] = [
                    [
                        "type": "text",
                        "text": systemPrompt,
                        "cache_control": [
                            "type": "ephemeral",
                            "ttl": cacheControl.ttl
                        ]
                    ]
                ]
            } else {
                requestBody["system"] = systemPrompt
            }
        }

        // Add effort parameter for Opus 4.5 (beta)
        if let effort = options.effort, model.contains("opus-4-5") {
            requestBody["output_config"] = ["effort": effort.rawValue]
        }

        // Add thinking config (interleaved thinking beta)
        if let thinking = options.thinking, thinking.enabled {
            requestBody["thinking"] = [
                "type": "enabled",
                "budget_tokens": thinking.budgetTokens
            ]
        }

        // Add context management (beta)
        if let contextMgmt = options.contextManagement {
            var edits: [[String: Any]] = []
            for edit in contextMgmt.edits {
                var editDict: [String: Any] = [
                    "type": edit.type.rawValue,
                    "trigger": ["input_tokens": edit.trigger.inputTokens]
                ]
                if let keep = edit.keep {
                    editDict["keep"] = keep
                }
                if let clearAtLeast = edit.clearAtLeast {
                    editDict["clear_at_least"] = clearAtLeast
                }
                if let excludeTools = edit.excludeTools {
                    editDict["exclude_tools"] = excludeTools
                }
                edits.append(editDict)
            }
            requestBody["context_management"] = ["edits": edits]
        }

        // Add server tools (web search, web fetch, tool search)
        if let serverTools = options.serverTools {
            var tools: [[String: Any]] = []
            for tool in serverTools {
                tools.append(tool.toolDefinition)
            }
            requestBody["tools"] = tools
        }

        // Add tool choice
        if let toolChoice = options.toolChoice {
            requestBody["tool_choice"] = toolChoice.toDictionary
        }

        guard let url = URL(string: "\(baseURL)/messages") else {
            throw AnthropicError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = requestTimeout

        // Add beta headers based on features used
        var betaHeaders: [String] = []
        if options.effort != nil {
            betaHeaders.append("effort-2025-11-24")
        }
        if options.contextManagement != nil {
            betaHeaders.append("context-management-2025-06-27")
        }
        if options.thinking?.enabled == true {
            betaHeaders.append("interleaved-thinking-2025-05-14")
        }
        if options.serverTools?.contains(where: { if case .webFetch = $0 { return true }; return false }) == true {
            betaHeaders.append("web-fetch-2025-09-10")
        }
        // 1M token context beta
        if let limit = options.extendedContextLimit, limit > 200_000 {
            betaHeaders.append("max-tokens-1m-2025-01-01")
        }
        if !betaHeaders.isEmpty {
            request.setValue(betaHeaders.joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Use the same streaming logic as the base chat method
        return try await chat(messages: messages, model: model, stream: options.stream)
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
    let contextManagement: ContextManagement?
    let serverTools: [ServerTool]?
    let toolChoice: AnthropicToolChoice?  // Controls tool selection behavior
    let compaction: CompactionConfig?     // Context compaction for long sessions
    let extendedContextLimit: Int?        // For 1M token beta (nil = default 200K)

    init(
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
