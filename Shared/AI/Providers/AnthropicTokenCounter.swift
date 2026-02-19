// AnthropicTokenCounter.swift
// Thea
//
// Token Counting API for Anthropic Claude
// Endpoint: POST /v1/messages/count_tokens
// Pricing: FREE (no additional charges)
//
// Use this to pre-validate prompts before sending to avoid context overflow.

import Foundation
import OSLog

// MARK: - Anthropic Token Counter

/// Token counting API for Anthropic Claude
/// Endpoint: POST /v1/messages/count_tokens
/// Pricing: FREE
struct AnthropicTokenCounter: Sendable {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages/count_tokens"
    private let apiVersion = "2023-06-01"
    private let logger = Logger(subsystem: "com.thea.v2", category: "AnthropicTokenCounter")

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Token Counting

    /// Count tokens in a message before sending
    /// - Parameters:
    ///   - messages: The messages to count
    ///   - model: The model to use for counting
    ///   - systemPrompt: Optional system prompt
    ///   - tools: Optional tool definitions
    /// - Returns: Token count result
    func countTokens(
        messages: [AIMessage],
        model: String,
        systemPrompt: String? = nil,
        tools: [ToolDefinition]? = nil
    ) async throws -> TokenCountResult {
        guard let url = URL(string: baseURL) else {
            throw AnthropicError.invalidResponseDetails("Invalid URL")
        }

        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages.map { msg in
                [
                    "role": msg.role == .user ? "user" : "assistant",
                    "content": msg.content.textValue
                ]
            }
        ]

        if let system = systemPrompt {
            requestBody["system"] = system
        }

        if let tools = tools {
            requestBody["tools"] = tools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": tool.parameters
                ]
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponseDetails("Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 {
            var errorMessage: String? = nil
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = message
                }
            } catch {
                logger.debug("Could not parse error response body: \(error.localizedDescription)")
            }
            throw AnthropicError.serverError(status: httpResponse.statusCode, message: errorMessage)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inputTokens = json["input_tokens"] as? Int
        else {
            throw AnthropicError.invalidResponseDetails("Could not parse token count response")
        }

        logger.debug("Token count: \(inputTokens) for model \(model)")

        return TokenCountResult(inputTokens: inputTokens)
    }

    // periphery:ignore - Reserved: checkFits(messages:model:maxTokens:contextLimit:) instance method — reserved for future feature activation
    /// Check if a message will fit within a model's context window
    func checkFits(
        // periphery:ignore - Reserved: checkFits(messages:model:maxTokens:contextLimit:) instance method reserved for future feature activation
        messages: [AIMessage],
        model: String,
        maxTokens: Int,
        contextLimit: Int
    ) async throws -> ContextFitResult {
        let count = try await countTokens(messages: messages, model: model)
        let totalRequired = count.inputTokens + maxTokens
        let fits = totalRequired <= contextLimit
        let remaining = contextLimit - count.inputTokens

        return ContextFitResult(
            fits: fits,
            inputTokens: count.inputTokens,
            maxOutputTokens: maxTokens,
            remainingCapacity: remaining,
            contextLimit: contextLimit
        )
    }
}

// MARK: - Token Count Result

struct TokenCountResult: Sendable {
    let inputTokens: Int
}

// MARK: - Context Fit Result

// periphery:ignore - Reserved: ContextFitResult type reserved for future feature activation
struct ContextFitResult: Sendable {
    let fits: Bool
    let inputTokens: Int
    let maxOutputTokens: Int
    let remainingCapacity: Int
    let contextLimit: Int
}
