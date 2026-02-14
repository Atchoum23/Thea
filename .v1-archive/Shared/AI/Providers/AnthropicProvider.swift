import Foundation

final class AnthropicProvider: AIProvider, Sendable {
    let metadata = ProviderMetadata(
        name: "anthropic",
        displayName: "Anthropic (Claude)",
        logoURL: URL(string: "https://anthropic.com/favicon.ico"),
        websiteURL: URL(string: "https://anthropic.com")!,
        documentationURL: URL(string: "https://docs.anthropic.com")!
    )

    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        supportsVision: true,
        supportsFunctionCalling: true,
        supportsWebSearch: false,
        maxContextTokens: 200_000,
        maxOutputTokens: 8192,
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

    func listModels() async throws -> [AIModel] {
        [
            AIModel(
                id: "claude-opus-4-20250514",
                name: "Claude Opus 4",
                description: "Most capable Claude model",
                contextWindow: 200_000,
                maxOutputTokens: 8192,
                inputPricePerMillion: 15.00,
                outputPricePerMillion: 75.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            AIModel(
                id: "claude-sonnet-4-20250514",
                name: "Claude Sonnet 4",
                description: "Balanced intelligence and speed",
                contextWindow: 200_000,
                maxOutputTokens: 8192,
                inputPricePerMillion: 3.00,
                outputPricePerMillion: 15.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            AIModel(
                id: "claude-3-5-sonnet-20241022",
                name: "Claude 3.5 Sonnet",
                description: "Previous generation balanced model",
                contextWindow: 200_000,
                maxOutputTokens: 8192,
                inputPricePerMillion: 3.00,
                outputPricePerMillion: 15.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            AIModel(
                id: "claude-3-5-haiku-20241022",
                name: "Claude 3.5 Haiku",
                description: "Fast and cost-effective",
                contextWindow: 200_000,
                maxOutputTokens: 8192,
                inputPricePerMillion: 1.00,
                outputPricePerMillion: 5.00,
                supportsVision: true,
                supportsFunctionCalling: true
            )
        ]
    }
}

// MARK: - Errors

enum AnthropicError: Error, LocalizedError {
    case invalidResponse
    case noResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from Anthropic"
        case .noResponse:
            "No response from Anthropic"
        }
    }
}
