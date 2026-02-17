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
        maxContextTokens: 1_000_000,  // Claude 4.6 supports up to 1M context
        maxOutputTokens: 32_000,  // Claude 4.5+ supports up to 32K output
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
        let anthropicMessages = buildMessages(from: messages)

        var requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": anthropicMessages,
            "stream": stream
        ]

        // Opus 4.6: use adaptive thinking (recommended over budget_tokens)
        if model.contains("opus-4-6") {
            requestBody["thinking"] = ["type": "adaptive"]
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
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        if stream {
            let requestCopy = request
            return AsyncThrowingStream { continuation in
                Task { @Sendable [model, messages] in
                    do {
                        let (asyncBytes, response) = try await URLSession.shared.bytes(for: requestCopy)

                        guard let httpResponse = response as? HTTPURLResponse,
                              httpResponse.statusCode == 200
                        else {
                            throw AnthropicError.invalidResponse
                        }

                        var accumulatedText = ""
                        var accumulatedThinking = ""
                        for try await line in asyncBytes.lines {
                            guard line.hasPrefix("data: ") else { continue }
                            let jsonString = String(line.dropFirst(6))
                            guard let data = jsonString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let type = json["type"] as? String
                            else { continue }

                            switch type {
                            case "content_block_start":
                                break

                            case "content_block_delta":
                                if let delta = json["delta"] as? [String: Any] {
                                    let deltaType = delta["type"] as? String ?? ""

                                    if deltaType == "thinking_delta",
                                       let thinking = delta["thinking"] as? String
                                    {
                                        accumulatedThinking += thinking
                                        continuation.yield(.thinkingDelta(thinking))
                                    } else if deltaType == "text_delta",
                                              let text = delta["text"] as? String
                                    {
                                        accumulatedText += text
                                        continuation.yield(.delta(text))
                                    }
                                }

                            case "message_stop":
                                let finalMessage = AIMessage(
                                    id: UUID(),
                                    conversationID: messages.first?.conversationID ?? UUID(),
                                    role: .assistant,
                                    content: .text(accumulatedText),
                                    timestamp: Date(),
                                    model: model,
                                    thinkingTrace: accumulatedThinking.isEmpty ? nil : accumulatedThinking
                                )
                                continuation.yield(.complete(finalMessage))

                            default:
                                break
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
                  let content = json["content"] as? [[String: Any]]
            else {
                throw AnthropicError.noResponse
            }

            // Parse thinking blocks and text blocks from response
            var text = ""
            var thinking = ""
            for block in content {
                let blockType = block["type"] as? String ?? ""
                if blockType == "thinking", let t = block["thinking"] as? String {
                    thinking += t
                } else if blockType == "text", let t = block["text"] as? String {
                    text += t
                }
            }

            guard !text.isEmpty else { throw AnthropicError.noResponse }

            let finalMessage = AIMessage(
                id: UUID(),
                conversationID: messages.first?.conversationID ?? UUID(),
                role: .assistant,
                content: .text(text),
                timestamp: Date(),
                model: model,
                thinkingTrace: thinking.isEmpty ? nil : thinking
            )

            return AsyncThrowingStream { continuation in
                continuation.yield(.complete(finalMessage))
                continuation.finish()
            }
        }
    }

    /// Build Anthropic API messages, filtering system messages into the system field
    private func buildMessages(from messages: [AIMessage]) -> [[String: Any]] {
        messages.compactMap { msg -> [String: Any]? in
            guard msg.role != .system else { return nil }
            return [
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content.textValue
            ]
        }
    }

    // MARK: - Models

    func listModels() async throws -> [ProviderAIModel] {
        // Delegate to AIModelCatalog to eliminate duplication.
        // Convert per-1K costs to per-million for ProviderAIModel (×1000).
        AIModel.anthropicModels.map { model in
            let inputPPM: Decimal
            let outputPPM: Decimal
            if let inputPer1K = model.inputCostPer1K {
                inputPPM = inputPer1K * 1000
            } else {
                inputPPM = .zero
            }
            if let outputPer1K = model.outputCostPer1K {
                outputPPM = outputPer1K * 1000
            } else {
                outputPPM = .zero
            }
            return ProviderAIModel(
                id: model.id,
                name: model.name,
                description: model.description,
                contextWindow: model.contextWindow,
                maxOutputTokens: model.maxOutputTokens,
                inputPricePerMillion: inputPPM,
                outputPricePerMillion: outputPPM,
                supportsVision: model.supportsVision,
                supportsFunctionCalling: model.supportsFunctionCalling
            )
        }
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
        let requestBody = buildAdvancedRequestBody(messages: messages, model: model, options: options)
        let request = try buildAdvancedRequest(body: requestBody, model: model, options: options)

        if options.stream {
            return streamAdvancedResponse(request: request, model: model, messages: messages)
        } else {
            return try await nonStreamAdvancedResponse(request: request, messages: messages, model: model)
        }
    }

    // MARK: - Advanced Chat Helpers

    private func buildAdvancedRequestBody(
        messages: [AIMessage],
        model: String,
        options: AnthropicChatOptions
    ) -> [String: Any] {
        let anthropicMessages = messages.map { msg in
            [
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content.textValue
            ]
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

    private func buildAdvancedRequest(
        body: [String: Any],
        model _: String,
        options: AnthropicChatOptions
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw AnthropicError.invalidResponse
        }

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

    private func streamAdvancedResponse(
        request: URLRequest,
        model: String,
        messages: [AIMessage]
    ) -> AsyncThrowingStream<ChatResponse, Error> {
        let requestCopy = request
        return AsyncThrowingStream { continuation in
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
                    var accumulatedThinking = ""
                    for try await line in asyncBytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        guard let data = jsonString.data(using: .utf8),
                              // try? OK: SSE line may be malformed; skip and continue
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = json["type"] as? String
                        else { continue }

                        switch type {
                        case "content_block_start":
                            break // Block type tracking handled by delta type
                        case "content_block_delta":
                            if let delta = json["delta"] as? [String: Any] {
                                let deltaType = delta["type"] as? String ?? ""
                                if deltaType == "thinking_delta", let thinking = delta["thinking"] as? String {
                                    accumulatedThinking += thinking
                                    continuation.yield(.thinkingDelta(thinking))
                                } else if let text = delta["text"] as? String {
                                    accumulatedText += text
                                    continuation.yield(.delta(text))
                                }
                            }
                        case "message_stop":
                            let finalMessage = AIMessage(
                                id: UUID(), conversationID: messages.first?.conversationID ?? UUID(),
                                role: .assistant, content: .text(accumulatedText), timestamp: Date(), model: model,
                                thinkingTrace: accumulatedThinking.isEmpty ? nil : accumulatedThinking
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

    private func nonStreamAdvancedResponse(
        request: URLRequest,
        messages: [AIMessage],
        model: String
    ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                throw AnthropicError.serverError(status: httpResponse.statusCode, message: "Advanced chat request failed")
            }
            throw AnthropicError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]]
        else {
            throw AnthropicError.noResponse
        }

        // Parse thinking blocks and text blocks from response
        var text = ""
        var thinking = ""
        for block in content {
            let blockType = block["type"] as? String ?? ""
            if blockType == "thinking", let t = block["thinking"] as? String {
                thinking += t
            } else if blockType == "text", let t = block["text"] as? String {
                text += t
            }
        }

        guard !text.isEmpty else { throw AnthropicError.noResponse }

        let finalMessage = AIMessage(
            id: UUID(), conversationID: messages.first?.conversationID ?? UUID(),
            role: .assistant, content: .text(text), timestamp: Date(), model: model,
            thinkingTrace: thinking.isEmpty ? nil : thinking
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
