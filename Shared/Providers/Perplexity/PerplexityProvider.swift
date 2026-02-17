// PerplexityProvider.swift
// Thea V2
//
// Perplexity AI provider - search-enhanced AI models

import Foundation
import OSLog

// MARK: - Perplexity Provider

// @unchecked Sendable: stateless provider — all stored properties are immutable configuration
public final class PerplexityProvider: AIProvider, @unchecked Sendable {
    public let id = "perplexity"
    public let name = "Perplexity"

    private let logger = Logger(subsystem: "com.thea.v2", category: "PerplexityProvider")
    private let baseURL = "https://api.perplexity.ai"
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
                id: "sonar-pro",
                name: "Sonar Pro",
                provider: "perplexity",
                description: "Advanced search-enhanced model",
                contextWindow: 200_000,
                maxOutputTokens: 8192,
                capabilities: [.chat, .search],
                inputCostPer1K: Decimal(string: "0.003"),
                outputCostPer1K: Decimal(string: "0.015")
            ),
            AIModel(
                id: "sonar",
                name: "Sonar",
                provider: "perplexity",
                description: "Fast search-enhanced model",
                contextWindow: 127_072,
                maxOutputTokens: 8192,
                capabilities: [.chat, .search],
                inputCostPer1K: Decimal(string: "0.001"),
                outputCostPer1K: Decimal(string: "0.001")
            ),
            AIModel(
                id: "sonar-reasoning",
                name: "Sonar Reasoning",
                provider: "perplexity",
                description: "Reasoning with search",
                contextWindow: 127_072,
                maxOutputTokens: 8192,
                capabilities: [.chat, .search, .reasoning],
                inputCostPer1K: Decimal(string: "0.001"),
                outputCostPer1K: Decimal(string: "0.005")
            )
        ]
    }

    public var capabilities: Set<ProviderCapability> {
        [.chat, .streaming, .webSearch]
    }

    // MARK: - Chat

    public func chat(
        messages: [ChatMessage],
        model: String,
        options: ChatOptions
    ) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        let perplexityMessages = messages.map { msg -> [String: Any] in
            ["role": msg.role, "content": msg.content.textValue]
        }

        var requestBody: [String: Any] = [
            "model": model,
            "messages": perplexityMessages,
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
                            message: "Perplexity API error"
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
                message: "Perplexity API error"
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw ProviderError.invalidResponse(details: "Could not parse response")
        }

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

        // Perplexity uses OpenAI-compatible API
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            return .unhealthy("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        // Minimal request
        let body: [String: Any] = [
            "model": "sonar",
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
