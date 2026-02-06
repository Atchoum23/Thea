// AIProviderHelpers.swift
// Thea V2
//
// Centralized utility functions for AI provider operations.
// Eliminates code duplication and ensures consistent patterns across the codebase.
//
// CREATED: February 2, 2026 during V2 migration optimization
// PURPOSE: Replace duplicate streamProviderResponse implementations across:
//          - ToolFramework.swift
//          - ReflectionEngine.swift
//          - SubAgentOrchestrator.swift
//          - KnowledgeGraph.swift
//
// USAGE:
//   // Simple case - stream to string
//   let response = try await AIProviderHelpers.streamToString(
//       provider: provider, prompt: prompt, model: model
//   )
//
//   // With AIProvider extension
//   let response = try await provider.simpleChat(prompt: prompt, model: model)
//
//   // Non-streaming (more efficient for short responses)
//   let response = try await provider.quickChat(prompt: prompt, model: model)
//
// SEE ALSO: .claude/V2_MIGRATION_COMPLETE.md for full V2 API documentation

import Foundation

// MARK: - Provider Response Streaming

/// Centralized helper for streaming provider responses into a complete string.
/// Use this instead of duplicating the stream-to-string pattern in each file.
public enum AIProviderHelpers {

    /// Stream a chat response and collect into a single string.
    /// - Parameters:
    ///   - provider: The AI provider to use
    ///   - prompt: The user prompt to send
    ///   - model: The model identifier to use
    ///   - systemPrompt: Optional system prompt to prepend
    ///   - temperature: Optional temperature setting (default: nil uses provider default)
    ///   - maxTokens: Optional max tokens limit
    /// - Returns: The complete response text
    /// - Throws: Any errors from the provider or stream
    public static func streamToString(
        provider: any AIProvider,
        prompt: String,
        model: String,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> String {
        var messages: [ChatMessage] = []

        if let system = systemPrompt {
            messages.append(ChatMessage(role: "system", text: system))
        }
        messages.append(ChatMessage(role: "user", text: prompt))

        let options = ChatOptions(
            temperature: temperature,
            maxTokens: maxTokens,
            stream: true,
            systemPrompt: systemPrompt
        )

        var result = ""
        let stream = try await provider.chat(messages: messages, model: model, options: options)

        for try await chunk in stream {
            switch chunk {
            case let .content(text):
                result += text
            case .done:
                break
            case let .error(error):
                throw error
            }
        }

        return result
    }

    /// Stream a chat response without streaming (single response).
    /// More efficient for short responses where streaming isn't needed.
    public static func singleResponse(
        provider: any AIProvider,
        prompt: String,
        model: String,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> String {
        var messages: [ChatMessage] = []

        if let system = systemPrompt {
            messages.append(ChatMessage(role: "system", text: system))
        }
        messages.append(ChatMessage(role: "user", text: prompt))

        let options = ChatOptions(
            temperature: temperature,
            maxTokens: maxTokens,
            stream: false,
            systemPrompt: systemPrompt
        )

        var result = ""
        let stream = try await provider.chat(messages: messages, model: model, options: options)

        for try await chunk in stream {
            switch chunk {
            case let .content(text):
                result += text
            case .done, .error:
                break
            }
        }

        return result
    }

    /// Stream a multi-turn conversation and get the final response.
    public static func conversationResponse(
        provider: any AIProvider,
        messages: [ChatMessage],
        model: String,
        stream: Bool = true,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> String {
        let options = ChatOptions(
            temperature: temperature,
            maxTokens: maxTokens,
            stream: stream
        )

        var result = ""
        let responseStream = try await provider.chat(messages: messages, model: model, options: options)

        for try await chunk in responseStream {
            switch chunk {
            case let .content(text):
                result += text
            case .done:
                break
            case let .error(error):
                throw error
            }
        }

        return result
    }
}

// MARK: - AIProvider Extension for Convenience

public extension AIProvider {

    /// Convenience method to get a simple string response.
    func simpleChat(prompt: String, model: String) async throws -> String {
        try await AIProviderHelpers.streamToString(
            provider: self,
            prompt: prompt,
            model: model
        )
    }

    /// Convenience method for non-streaming response.
    func quickChat(prompt: String, model: String) async throws -> String {
        try await AIProviderHelpers.singleResponse(
            provider: self,
            prompt: prompt,
            model: model
        )
    }
}

// MARK: - Provider Selection Helpers

public extension ProviderRegistry {

    /// Get the best available provider, preferring the default.
    var bestAvailableProvider: (any AIProvider)? {
        defaultProvider ?? configuredProviders.first
    }

    /// Get a provider suitable for a specific task type.
    /// Returns the default provider if no specific routing is configured.
    func provider(for taskType: TaskType) -> (any AIProvider)? {
        // Future: Could implement task-based routing here
        // For now, return the default or first configured
        bestAvailableProvider
    }

    /// Get all providers that support a specific capability.
    func providers(supporting capability: ModelCapability) -> [any AIProvider] {
        configuredProviders.filter { provider in
            provider.supportedModels.contains { model in
                model.capabilities.contains(capability)
            }
        }
    }
}
