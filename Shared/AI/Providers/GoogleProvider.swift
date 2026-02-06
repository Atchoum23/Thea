import Foundation

final class GoogleProvider: AIProvider, Sendable {
    let metadata = ProviderMetadata(
        name: "google",
        displayName: "Google (Gemini)",
        logoURL: URL(string: "https://ai.google.dev/static/site-assets/images/marketing/gemini.svg"),
        websiteURL: URL(string: "https://ai.google.dev")!,
        documentationURL: URL(string: "https://ai.google.dev/docs")!
    )

    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        supportsVision: true,
        supportsFunctionCalling: true,
        supportsWebSearch: false,
        maxContextTokens: 1_000_000, // Gemini 1.5 Pro
        maxOutputTokens: 8192,
        supportedModalities: [.text, .image, .video, .audio]
    )

    private let apiKey: String
    private let baseURL: String

    init(apiKey: String) {
        self.apiKey = apiKey
        // Capture configuration at init time for Sendable compliance
        let config = ProviderConfiguration()
        baseURL = config.googleBaseURL
    }

    // MARK: - Validation

    func validateAPIKey(_ key: String) async throws -> ValidationResult {
        guard let url = URL(string: "\(baseURL)/models?key=\(key)") else {
            return .failure("Invalid API URL configuration")
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return .success()
                } else if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
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
        let contents = messages.map { msg in
            [
                "role": msg.role == .user ? "user" : "model",
                "parts": [["text": msg.content.textValue]]
            ]
        }

        let requestBody: [String: Any] = [
            "contents": contents
        ]

        let endpoint = stream ? "streamGenerateContent" : "generateContent"
        guard let url = URL(string: "\(baseURL)/models/\(model):\(endpoint)?key=\(apiKey)") else {
            throw GoogleError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
                            throw GoogleError.invalidResponse
                        }

                        var accumulatedText = ""

                        for try await line in asyncBytes.lines {
                            guard let data = line.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let candidates = json["candidates"] as? [[String: Any]],
                                  let content = candidates.first?["content"] as? [String: Any],
                                  let parts = content["parts"] as? [[String: Any]],
                                  let text = parts.first?["text"] as? String
                            else {
                                continue
                            }

                            accumulatedText += text
                            continuation.yield(.delta(text))
                        }

                        let finalMessage = AIMessage(
                            id: UUID(),
                            conversationID: messages.first?.conversationID ?? UUID(),
                            role: .assistant,
                            content: .text(accumulatedText),
                            timestamp: Date(),
                            model: model
                        )
                        continuation.yield(.complete(finalMessage))
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
                throw GoogleError.invalidResponse
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String
            else {
                throw GoogleError.noResponse
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
            ProviderAIModel(
                id: "gemini-2.0-flash-exp",
                name: "Gemini 2.0 Flash",
                description: "Experimental next-gen model",
                contextWindow: 1_000_000,
                maxOutputTokens: 8192,
                inputPricePerMillion: 0.00, // Free during preview
                outputPricePerMillion: 0.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            ProviderAIModel(
                id: "gemini-1.5-pro",
                name: "Gemini 1.5 Pro",
                description: "Most capable Gemini model",
                contextWindow: 1_000_000,
                maxOutputTokens: 8192,
                inputPricePerMillion: 1.25,
                outputPricePerMillion: 5.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            ProviderAIModel(
                id: "gemini-1.5-flash",
                name: "Gemini 1.5 Flash",
                description: "Fast and cost-effective",
                contextWindow: 1_000_000,
                maxOutputTokens: 8192,
                inputPricePerMillion: 0.075,
                outputPricePerMillion: 0.30,
                supportsVision: true,
                supportsFunctionCalling: true
            )
        ]
    }
}

// MARK: - Errors

enum GoogleError: Error, LocalizedError {
    case invalidResponse
    case noResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from Google"
        case .noResponse:
            "No response from Google"
        }
    }
}
