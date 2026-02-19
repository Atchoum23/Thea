import Foundation
import OSLog

final class OpenRouterProvider: AIProvider, Sendable {
    private let logger = Logger(subsystem: "ai.thea.app", category: "OpenRouterProvider")

    let metadata = ProviderMetadata(
        name: "openrouter",
        displayName: "OpenRouter",
        logoURL: URL(string: "https://openrouter.ai/favicon.ico"),
        // swiftlint:disable:next force_unwrapping
        websiteURL: URL(string: "https://openrouter.ai")!,
        // swiftlint:disable:next force_unwrapping
        documentationURL: URL(string: "https://openrouter.ai/docs")!
    )

    // periphery:ignore - Reserved: capabilities property — reserved for future feature activation
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        // periphery:ignore - Reserved: capabilities property reserved for future feature activation
        supportsVision: true,
        supportsFunctionCalling: true,
        supportsWebSearch: false,
        maxContextTokens: 200_000, // Depends on model
        maxOutputTokens: 16384,
        supportedModalities: [.text, .image]
    )

    private let apiKey: String
    private let baseURL = "https://openrouter.ai/api/v1"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Validation

    // periphery:ignore - Reserved: validateAPIKey(_:) instance method — reserved for future feature activation
    func validateAPIKey(_ key: String) async throws -> ValidationResult {
        // periphery:ignore - Reserved: validateAPIKey(_:) instance method reserved for future feature activation
        guard let url = URL(string: "\(baseURL)/models") else {
            return .failure("Invalid API URL configuration")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

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
        try await chatWithOptions(messages: messages, model: model, stream: stream)
    }

    // periphery:ignore - Reserved: chatAdvanced(messages:model:options:) instance method reserved for future feature activation
    /// Advanced chat with Anthropic-specific features forwarded through OpenRouter.
    /// When routing to a Claude model, forwards: system prompts, cache control, thinking, effort.
    func chatAdvanced(
        messages: [AIMessage],
        model: String,
        options: AnthropicChatOptions
    ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        try await chatWithOptions(messages: messages, model: model, stream: options.stream, anthropicOptions: options)
    }

    private func chatWithOptions(
        messages: [AIMessage],
        model: String,
        stream: Bool,
        anthropicOptions: AnthropicChatOptions? = nil
    ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        let isClaudeModel = model.contains("claude") || model.contains("anthropic")

        // Build messages — extract system messages separately for Claude
        var systemMessages: [AIMessage] = []
        var chatMessages: [AIMessage] = []
        for msg in messages {
            if msg.role == .system {
                systemMessages.append(msg)
            } else {
                chatMessages.append(msg)
            }
        }

        let openRouterMessages: [[String: Any]] = chatMessages.map { msg in
            [
                "role": convertRole(msg.role),
                "content": msg.content.textValue
            ]
        }

        var requestBody: [String: Any] = [
            "model": model,
            "messages": openRouterMessages,
            "stream": stream
        ]

        // Forward Anthropic-specific features for Claude models
        if isClaudeModel {
            // System prompt: combine system messages + options system prompt
            var systemParts: [String] = systemMessages.map(\.content.textValue)
            if let optionSystem = anthropicOptions?.systemPrompt {
                systemParts.append(optionSystem)
            }

            if !systemParts.isEmpty {
                let systemText = systemParts.joined(separator: "\n\n")

                // Apply cache control if specified
                if let cacheControl = anthropicOptions?.cacheControl {
                    requestBody["system"] = [[
                        "type": "text",
                        "text": systemText,
                        "cache_control": [
                            "type": "ephemeral",
                            "ttl": cacheControl.ttl
                        ]
                    ]]
                } else {
                    requestBody["system"] = systemText
                }
            }

            // Thinking configuration
            if let thinking = anthropicOptions?.thinking, thinking.enabled {
                requestBody["thinking"] = [
                    "type": "enabled",
                    "budget_tokens": thinking.budgetTokens
                ]
            }

            // Effort level (Opus 4.5)
            if let effort = anthropicOptions?.effort {
                requestBody["output_config"] = [
                    "effort": effort.rawValue
                ]
            }

            // Max tokens
            if let maxTokens = anthropicOptions?.maxTokens {
                requestBody["max_tokens"] = maxTokens
            }

            // Context management (auto-clear old tool results)
            if let contextMgmt = anthropicOptions?.contextManagement {
                var edits: [[String: Any]] = []
                for edit in contextMgmt.edits {
                    var editDict: [String: Any] = [
                        "type": edit.type.rawValue,
                        "trigger": ["input_tokens": edit.trigger.inputTokens]
                    ]
                    if let keep = edit.keep {
                        editDict["keep"] = keep
                    }
                    if let exclude = edit.excludeTools {
                        editDict["exclude_tools"] = exclude
                    }
                    edits.append(editDict)
                }
                requestBody["context_management"] = ["edits": edits]
            }

            // Server tools (web search, web fetch)
            if let serverTools = anthropicOptions?.serverTools {
                var tools: [[String: Any]] = []
                for tool in serverTools {
                    tools.append(tool.toolDefinition)
                }
                requestBody["tools"] = tools
            }

            // Provider-specific routing preferences
            requestBody["provider"] = [
                "order": ["Anthropic"],
                "allow_fallbacks": false
            ]
        } else {
            // Non-Claude: include system messages inline
            if !systemMessages.isEmpty {
                let allMessages = systemMessages + chatMessages
                requestBody["messages"] = allMessages.map { msg in
                    [
                        "role": convertRole(msg.role),
                        "content": msg.content.textValue
                    ] as [String: Any]
                }
            }
        }

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw OpenRouterError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://theathe.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Thea", forHTTPHeaderField: "X-Title")
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
                            throw OpenRouterError.invalidResponse
                        }

                        var accumulatedText = ""

                        for try await line in asyncBytes.lines {
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6))

                                if jsonString == "[DONE]" {
                                    let finalMessage = AIMessage(
                                        id: UUID(),
                                        conversationID: messages.first?.conversationID ?? UUID(),
                                        role: .assistant,
                                        content: .text(accumulatedText),
                                        timestamp: Date(),
                                        model: model
                                    )
                                    continuation.yield(.complete(finalMessage))
                                    break
                                }

                                guard let data = jsonString.data(using: .utf8) else { continue }
                                let json: [String: Any]
                                do {
                                    guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                                    json = parsed
                                } catch {
                                    logger.debug("Skipped malformed SSE line: \(error.localizedDescription)")
                                    continue
                                }
                                guard let choices = json["choices"] as? [[String: Any]],
                                      let delta = choices.first?["delta"] as? [String: Any],
                                      let content = delta["content"] as? String
                                else {
                                    continue
                                }

                                accumulatedText += content
                                continuation.yield(.delta(content))
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
                throw OpenRouterError.invalidResponse
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String
            else {
                throw OpenRouterError.noResponse
            }

            let finalMessage = AIMessage(
                id: UUID(),
                conversationID: messages.first?.conversationID ?? UUID(),
                role: .assistant,
                content: .text(content),
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
        guard let url = URL(string: "\(baseURL)/models") else {
            throw OpenRouterError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]]
        else {
            throw OpenRouterError.noModels
        }

        return modelsData.compactMap { modelData in
            guard let id = modelData["id"] as? String,
                  let name = modelData["name"] as? String
            else {
                return nil
            }

            let contextWindow = modelData["context_length"] as? Int ?? 128_000
            let pricing = modelData["pricing"] as? [String: Any]
            let inputPrice = (pricing?["prompt"] as? String).flatMap { Double($0) }.map { Decimal($0) * 1_000_000 } ?? 0
            let outputPrice = (pricing?["completion"] as? String).flatMap { Double($0) }.map { Decimal($0) * 1_000_000 } ?? 0

            return ProviderAIModel(
                id: id,
                name: name,
                description: modelData["description"] as? String,
                contextWindow: contextWindow,
                maxOutputTokens: 16384,
                inputPricePerMillion: inputPrice,
                outputPricePerMillion: outputPrice,
                supportsVision: id.contains("vision") || id.contains("gpt-4o") || id.contains("claude"),
                supportsFunctionCalling: true
            )
        }
    }

    // MARK: - Helpers

    private func convertRole(_ role: MessageRole) -> String {
        switch role {
        case .user: "user"
        case .assistant: "assistant"
        case .system: "system"
        }
    }
}

// MARK: - Errors

enum OpenRouterError: Error, LocalizedError {
    case invalidResponse
    case noResponse
    case noModels

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from OpenRouter"
        case .noResponse:
            "No response from OpenRouter"
        case .noModels:
            "No models available from OpenRouter"
        }
    }
}
