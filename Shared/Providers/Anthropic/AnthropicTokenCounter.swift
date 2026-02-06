// AnthropicTokenCounter.swift
// Thea V2
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
public struct AnthropicTokenCounter: Sendable {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages/count_tokens"
    private let apiVersion = "2023-06-01"
    private let logger = Logger(subsystem: "com.thea.v2", category: "AnthropicTokenCounter")

    public init(apiKey: String) {
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
    public func countTokens(
        messages: [ChatMessage],
        model: String,
        systemPrompt: String? = nil,
        tools: [ToolDefinition]? = nil
    ) async throws -> TokenCountResult {
        guard let url = URL(string: baseURL) else {
            throw ProviderError.invalidResponse(details: "Invalid URL")
        }

        // Build request body (same structure as messages API)
        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages.map { msg in
                [
                    "role": msg.role,
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
            throw ProviderError.invalidResponse(details: "Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ProviderError.serverError(status: httpResponse.statusCode, message: message)
            }
            throw ProviderError.serverError(status: httpResponse.statusCode, message: nil)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inputTokens = json["input_tokens"] as? Int
        else {
            throw ProviderError.invalidResponse(details: "Could not parse token count response")
        }

        logger.debug("Token count: \(inputTokens) for model \(model)")

        return TokenCountResult(inputTokens: inputTokens)
    }

    /// Check if a message will fit within a model's context window
    /// - Parameters:
    ///   - messages: The messages to check
    ///   - model: The model to use
    ///   - maxTokens: Maximum output tokens requested
    ///   - contextLimit: The model's context limit
    /// - Returns: Whether the message fits and remaining capacity
    public func checkFits(
        messages: [ChatMessage],
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

public struct TokenCountResult: Sendable {
    public let inputTokens: Int

    public init(inputTokens: Int) {
        self.inputTokens = inputTokens
    }
}

// MARK: - Context Fit Result

public struct ContextFitResult: Sendable {
    public let fits: Bool
    public let inputTokens: Int
    public let maxOutputTokens: Int
    public let remainingCapacity: Int
    public let contextLimit: Int

    public init(
        fits: Bool,
        inputTokens: Int,
        maxOutputTokens: Int,
        remainingCapacity: Int,
        contextLimit: Int
    ) {
        self.fits = fits
        self.inputTokens = inputTokens
        self.maxOutputTokens = maxOutputTokens
        self.remainingCapacity = remainingCapacity
        self.contextLimit = contextLimit
    }
}
