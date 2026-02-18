// GroqProvider.swift
// Thea V2
//
// Groq provider for ultra-fast inference

import Foundation
import OSLog

// MARK: - Groq Provider

public final class GroqProvider: AIProvider, @unchecked Sendable {
    public let id = "groq"
    public let name = "Groq"

    private let logger = Logger(subsystem: "com.thea.v2", category: "GroqProvider")
    private let baseURL = "https://api.groq.com/openai/v1"
    private let apiKey: String

    // MARK: - Initialization

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - AIProvider Protocol

    public var isConfigured: Bool {
        !apiKey.isEmpty
    }

    public var supportedModels: [AIModel] {
        [
            AIModel(
                id: "llama-3.3-70b-versatile",
                name: "Llama 3.3 70B",
                provider: "groq",
                description: "Most capable Llama model on Groq",
                contextWindow: 32768,
                maxOutputTokens: 8192,
                capabilities: [ModelCapability.chat, ModelCapability.functionCalling],
                inputCostPer1K: Decimal(string: "0.00059"),
                outputCostPer1K: Decimal(string: "0.00079"),
                supportsFunctionCalling: true
            ),
            AIModel(
                id: "llama-3.1-8b-instant",
                name: "Llama 3.1 8B Instant",
                provider: "groq",
                description: "Ultra-fast Llama model",
                contextWindow: 32768,
                maxOutputTokens: 8192,
                capabilities: [ModelCapability.chat, ModelCapability.functionCalling],
                inputCostPer1K: Decimal(string: "0.00005"),
                outputCostPer1K: Decimal(string: "0.00008"),
                supportsFunctionCalling: true
            ),
            AIModel(
                id: "mixtral-8x7b-32768",
                name: "Mixtral 8x7B",
                provider: "groq",
                description: "Fast mixture of experts model",
                contextWindow: 32768,
                maxOutputTokens: 8192,
                capabilities: [ModelCapability.chat, ModelCapability.functionCalling],
                inputCostPer1K: Decimal(string: "0.00024"),
                outputCostPer1K: Decimal(string: "0.00024"),
                supportsFunctionCalling: true
            )
        ]
    }

    public var capabilities: Set<ProviderCapability> {
        [.chat, .streaming, .functionCalling]
    }

    // MARK: - Chat

    public func chat(
        messages: [ChatMessage],
        model: String,
        options: ChatOptions
    ) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        let groqMessages = messages.map { msg in
            [
                "role": msg.role,
                "content": msg.content.textValue
            ]
        }

        var requestBody: [String: Any] = [
            "model": model,
            "messages": groqMessages,
            "stream": options.stream
        ]

        if let temp = options.temperature {
            requestBody["temperature"] = temp
        }
        if let maxTokens = options.maxTokens {
            requestBody["max_tokens"] = maxTokens
        }

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw ProviderError.invalidResponse(details: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        if options.stream {
            return try await streamChat(request: request)
        } else {
            return try await nonStreamChat(request: request)
        }
    }

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
                            message: "Groq API error"
                        )
                    }

                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))

                            if jsonString == "[DONE]" {
                                continuation.yield(.done(finishReason: "stop", usage: nil))
                                break
                            }

                            guard let data = jsonString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let choices = json["choices"] as? [[String: Any]],
                                  let delta = choices.first?["delta"] as? [String: Any],
                                  let content = delta["content"] as? String
                            else {
                                continue
                            }

                            continuation.yield(.content(content))
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

    private func nonStreamChat(request: URLRequest) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse(details: "Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 {
            throw ProviderError.serverError(
                status: httpResponse.statusCode,
                message: "Groq API error"
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw ProviderError.invalidResponse(details: "Could not parse response")
        }

        // Parse usage if available
        var usage: TokenUsage?
        if let usageJson = json["usage"] as? [String: Any],
           let promptTokens = usageJson["prompt_tokens"] as? Int,
           let completionTokens = usageJson["completion_tokens"] as? Int {
            usage = TokenUsage(
                promptTokens: promptTokens,
                completionTokens: completionTokens
            )
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(.content(content))
            continuation.yield(.done(finishReason: "stop", usage: usage))
            continuation.finish()
        }
    }

    // MARK: - Health Check

    public func checkHealth() async -> ProviderHealth {
        guard isConfigured else {
            return .unhealthy("API key not configured")
        }

        guard let url = URL(string: "\(baseURL)/models") else {
            return .unhealthy("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

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
