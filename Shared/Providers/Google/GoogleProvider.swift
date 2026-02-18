// GoogleProvider.swift
// Thea V2
//
// Google Gemini API provider

import Foundation
import OSLog

// MARK: - Google Provider

// @unchecked Sendable: all mutable state (apiKey, baseURL) is set once at init; network requests
// use URLSession which manages its own thread safety; callbacks dispatched via async/await
public final class GoogleProvider: AIProvider, @unchecked Sendable {
    public let id = "google"
    public let name = "Google AI"

    private let logger = Logger(subsystem: "com.thea.v2", category: "GoogleProvider")
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
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
        AIModel.googleModels
    }

    public var capabilities: Set<ProviderCapability> {
        [.chat, .streaming, .vision, .functionCalling, .multimodal, .reasoning]
    }

    // MARK: - Chat

    public func chat(
        messages: [ChatMessage],
        model: String,
        options: ChatOptions
    ) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        // Convert to Gemini format
        var geminiContents: [[String: Any]] = []
        var systemInstruction: String?

        for msg in messages {
            if msg.role == "system" {
                systemInstruction = msg.content.textValue
            } else {
                let role = msg.role == "assistant" ? "model" : "user"
                geminiContents.append([
                    "role": role,
                    "parts": [["text": msg.content.textValue]]
                ])
            }
        }

        var requestBody: [String: Any] = [
            "contents": geminiContents
        ]

        if let system = systemInstruction ?? options.systemPrompt {
            requestBody["systemInstruction"] = ["parts": [["text": system]]]
        }

        var generationConfig: [String: Any] = [:]
        if let temp = options.temperature {
            generationConfig["temperature"] = temp
        }
        if let maxTokens = options.maxTokens {
            generationConfig["maxOutputTokens"] = maxTokens
        }

        // Gemini 3 thinking_level support
        // For Gemini 3 models: use thinking_level (low, medium, high, minimal)
        // For Gemini 2.5 models: use thinking_budget
        if let thinkingLevel = options.geminiThinkingLevel {
            if model.contains("gemini-3") {
                generationConfig["thinking_level"] = thinkingLevel.rawValue
            } else if model.contains("gemini-2.5") {
                // Gemini 2.5 uses thinking_budget instead
                generationConfig["thinking_budget"] = thinkingLevel.approximateBudget
            }
        }

        if !generationConfig.isEmpty {
            requestBody["generationConfig"] = generationConfig
        }

        let streamSuffix = options.stream ? ":streamGenerateContent" : ":generateContent"
        guard let url = URL(string: "\(baseURL)/models/\(model)\(streamSuffix)?key=\(apiKey)") else {
            throw ProviderError.invalidResponse(details: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
                            message: "Google AI API error"
                        )
                    }

                    for try await line in asyncBytes.lines {
                        // Gemini streams JSON objects, need to parse chunks
                        if line.contains("\"text\"") {
                            guard let data = line.data(using: .utf8) else { continue }

                            // Try to extract text from partial JSON
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let candidates = json["candidates"] as? [[String: Any]],
                               let content = candidates.first?["content"] as? [String: Any],
                               let parts = content["parts"] as? [[String: Any]],
                               let text = parts.first?["text"] as? String {
                                continuation.yield(.content(text))
                            }
                        }
                    }

                    continuation.yield(.done(finishReason: "stop", usage: nil))
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
                message: "Google AI API error"
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else {
            throw ProviderError.invalidResponse(details: "Could not parse response")
        }

        // Parse usage
        var usage: TokenUsage?
        if let usageMetadata = json["usageMetadata"] as? [String: Any],
           let promptTokenCount = usageMetadata["promptTokenCount"] as? Int,
           let candidatesTokenCount = usageMetadata["candidatesTokenCount"] as? Int {
            usage = TokenUsage(
                promptTokens: promptTokenCount,
                completionTokens: candidatesTokenCount
            )
        }

        let finishReason = (candidates.first?["finishReason"] as? String) ?? "STOP"

        return AsyncThrowingStream { continuation in
            continuation.yield(.content(text))
            continuation.yield(.done(finishReason: finishReason.lowercased(), usage: usage))
            continuation.finish()
        }
    }

    // MARK: - Health Check

    public func checkHealth() async -> ProviderHealth {
        guard isConfigured else {
            return .unhealthy("API key not configured")
        }

        guard let url = URL(string: "\(baseURL)/models?key=\(apiKey)") else {
            return .unhealthy("Invalid URL")
        }

        var request = URLRequest(url: url)
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
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return .unhealthy("Invalid API key")
            } else {
                return .unhealthy("Status code: \(httpResponse.statusCode)")
            }
        } catch {
            return .unhealthy("Network error: \(error.localizedDescription)")
        }
    }
}
