// DeepSeekProvider.swift
// Thea V2
//
// DeepSeek API provider (OpenAI-compatible format)
// Models: deepseek-chat (V3.2 non-thinking), deepseek-reasoner (V3.2 thinking)
// Features: Context caching (automatic), thinking mode via extra_body

import Foundation
import OSLog

// MARK: - DeepSeek Provider

// @unchecked Sendable: all mutable state (apiKey, baseURL) is set once at init; network requests
// use URLSession which manages its own thread safety; callbacks dispatched via async/await
public final class DeepSeekProvider: AIProvider, @unchecked Sendable {
    public let id = "deepseek"
    public let name = "DeepSeek"

    private let logger = Logger(subsystem: "com.thea.v2", category: "DeepSeekProvider")
    private let baseURL = "https://api.deepseek.com"
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
        AIModel.deepseekModels
    }

    public var capabilities: Set<ProviderCapability> {
        [.chat, .streaming, .functionCalling, .reasoning]
    }

    // MARK: - Chat

    public func chat(
        messages: [ChatMessage],
        model: String,
        options: ChatOptions
    ) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        // DeepSeek uses OpenAI-compatible format
        let deepseekMessages = messages.map { msg -> [String: Any] in
            ["role": msg.role, "content": msg.content.textValue]
        }

        var requestBody: [String: Any] = [
            "model": model,
            "messages": deepseekMessages,
            "stream": options.stream
        ]

        // Temperature not supported in thinking mode
        if model != "deepseek-reasoner" {
            if let temp = options.temperature {
                requestBody["temperature"] = temp
            }
        }

        if let maxTokens = options.maxTokens {
            requestBody["max_tokens"] = maxTokens
        }

        // Enable thinking mode for deepseek-chat if requested
        // Note: deepseek-reasoner has thinking enabled by default
        if model == "deepseek-chat", let thinkingConfig = options.deepseekThinking, thinkingConfig.enabled {
            requestBody["thinking"] = ["type": "enabled"]
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
                            message: "DeepSeek API error"
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
                                  let delta = choices.first?["delta"] as? [String: Any]
                            else {
                                continue
                            }

                            // Handle regular content
                            if let content = delta["content"] as? String {
                                continuation.yield(.content(content))
                            }

                            // Handle reasoning_content (thinking output)
                            // Note: reasoning_content is at same level as content in DeepSeek's response
                            if let reasoningContent = delta["reasoning_content"] as? String {
                                // Log thinking content for debugging
                                self.logger.debug("Thinking: \(reasoningContent)")
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

    private func nonStreamChat(request: URLRequest) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse(details: "Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ProviderError.serverError(status: httpResponse.statusCode, message: message)
            }
            throw ProviderError.serverError(
                status: httpResponse.statusCode,
                message: "DeepSeek API error"
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw ProviderError.invalidResponse(details: "Could not parse response")
        }

        // Parse usage (DeepSeek supports cache hit reporting)
        var usage: TokenUsage?
        if let usageJson = json["usage"] as? [String: Any],
           let promptTokens = usageJson["prompt_tokens"] as? Int,
           let completionTokens = usageJson["completion_tokens"] as? Int {
            let cachedTokens = usageJson["prompt_cache_hit_tokens"] as? Int
            usage = TokenUsage(
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                cachedTokens: cachedTokens
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

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            return .unhealthy("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        // Minimal request to check connectivity
        let body: [String: Any] = [
            "model": "deepseek-chat",
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
