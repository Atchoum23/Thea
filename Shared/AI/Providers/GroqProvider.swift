import Foundation
import OSLog

final class GroqProvider: AIProvider, Sendable {
    private let logger = Logger(subsystem: "ai.thea.app", category: "GroqProvider")

    let metadata = ProviderMetadata(
        name: "groq",
        displayName: "Groq",
        logoURL: URL(string: "https://groq.com/wp-content/uploads/2024/03/PBG-mark1-color01-p-500.png"),
        // swiftlint:disable:next force_unwrapping
        websiteURL: URL(string: "https://groq.com")!,
        // swiftlint:disable:next force_unwrapping
        documentationURL: URL(string: "https://console.groq.com/docs")!
    )

    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        supportsVision: false,
        supportsFunctionCalling: true,
        supportsWebSearch: false,
        maxContextTokens: 32768,
        maxOutputTokens: 8192,
        supportedModalities: [.text]
    )

    private let apiKey: String
    private let baseURL: String
    private let maxTokens: Int
    private let temperature: Double
    private let requestTimeout: TimeInterval

    @MainActor
    init(apiKey: String) {
        self.apiKey = apiKey
        // Capture configuration from AppConfiguration at init time for Sendable compliance
        let config = AppConfiguration.shared.providerConfig
        baseURL = config.groqBaseURL
        maxTokens = config.defaultMaxTokens
        temperature = config.defaultTemperature
        requestTimeout = config.requestTimeoutSeconds
    }

    // MARK: - Validation

    func validateAPIKey(_ key: String) async throws -> ValidationResult {
        guard let url = URL(string: "\(baseURL)/models") else {
            return .failure("Invalid API URL configuration")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = requestTimeout

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
        let groqMessages = messages.map { msg in
            [
                "role": convertRole(msg.role),
                "content": msg.content.textValue
            ]
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": groqMessages,
            "stream": stream,
            "temperature": temperature,
            "max_tokens": maxTokens
        ]

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw GroqError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
                            throw GroqError.invalidResponse
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
                throw GroqError.invalidResponse
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String
            else {
                throw GroqError.noResponse
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
        [
            ProviderAIModel(
                id: "llama-3.3-70b-versatile",
                name: "Llama 3.3 70B",
                description: "Most capable Llama model on Groq",
                contextWindow: 32768,
                maxOutputTokens: 8192,
                inputPricePerMillion: 0.59,
                outputPricePerMillion: 0.79,
                supportsVision: false,
                supportsFunctionCalling: true
            ),
            ProviderAIModel(
                id: "llama-3.1-8b-instant",
                name: "Llama 3.1 8B",
                description: "Ultra-fast Llama model",
                contextWindow: 32768,
                maxOutputTokens: 8192,
                inputPricePerMillion: 0.05,
                outputPricePerMillion: 0.08,
                supportsVision: false,
                supportsFunctionCalling: true
            ),
            ProviderAIModel(
                id: "mixtral-8x7b-32768",
                name: "Mixtral 8x7B",
                description: "Fast mixture of experts model",
                contextWindow: 32768,
                maxOutputTokens: 8192,
                inputPricePerMillion: 0.24,
                outputPricePerMillion: 0.24,
                supportsVision: false,
                supportsFunctionCalling: true
            )
        ]
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

enum GroqError: Error, LocalizedError {
    case invalidResponse
    case noResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from Groq"
        case .noResponse:
            "No response from Groq"
        }
    }
}
