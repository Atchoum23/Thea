//
//  KeyboardAIService.swift
//  TheaKeyboardExtension
//
//  Lightweight AI service for the keyboard extension. Makes direct HTTP
//  requests to the user's configured AI provider, reading the API key
//  from the shared App Group UserDefaults.
//

import Foundation

/// Standalone AI service for the keyboard extension.
/// Cannot import main app modules, so uses raw URLSession + shared UserDefaults.
final class KeyboardAIService: Sendable {
    static let shared = KeyboardAIService()

    private let appGroupID = "group.app.theathe"

    private init() {}

    // MARK: - Public API

    /// Perform an AI action on the given text context.
    /// Returns the AI-generated result string, or nil on failure.
    func performAction(context: String, action: String) async -> String? {
        guard let config = loadProviderConfig() else { return nil }

        let systemPrompt = buildSystemPrompt(for: action)
        let userPrompt = buildUserPrompt(context: context, action: action)

        return await callProvider(config: config, system: systemPrompt, user: userPrompt)
    }

    // MARK: - Provider Config

    private struct ProviderConfig {
        let apiKey: String
        let provider: String // "anthropic", "openai", "openrouter"
        let model: String
    }

    private func loadProviderConfig() -> ProviderConfig? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }

        // Try providers in order of preference
        if let key = defaults.string(forKey: "anthropic_api_key"), !key.isEmpty {
            return ProviderConfig(
                apiKey: key,
                provider: "anthropic",
                model: defaults.string(forKey: "keyboard_model") ?? "claude-sonnet-4-5-20250929"
            )
        }

        if let key = defaults.string(forKey: "openrouter_api_key"), !key.isEmpty {
            return ProviderConfig(
                apiKey: key,
                provider: "openrouter",
                model: defaults.string(forKey: "keyboard_model") ?? "anthropic/claude-sonnet-4-5-20250929"
            )
        }

        if let key = defaults.string(forKey: "openai_api_key"), !key.isEmpty {
            return ProviderConfig(
                apiKey: key,
                provider: "openai",
                model: defaults.string(forKey: "keyboard_model") ?? "gpt-4o-mini"
            )
        }

        return nil
    }

    // MARK: - Prompt Building

    private func buildSystemPrompt(for action: String) -> String {
        switch action {
        case "complete":
            return "You are a text completion assistant. Complete the user's sentence naturally. Reply ONLY with the completion text, no explanations."
        case "grammar":
            return "You are a grammar correction assistant. Fix grammar and spelling errors in the text. Reply ONLY with the corrected text, no explanations."
        case "professional":
            return "You are a writing assistant. Rewrite the text in a professional, formal tone. Reply ONLY with the rewritten text, no explanations."
        case "casual":
            return "You are a writing assistant. Rewrite the text in a casual, friendly tone. Reply ONLY with the rewritten text, no explanations."
        case "translate":
            return "You are a translator. Detect the language and translate to the other language (English↔French). Reply ONLY with the translation, no explanations."
        default:
            return "You are a helpful text assistant. Reply ONLY with the result, no explanations."
        }
    }

    private func buildUserPrompt(context: String, action: String) -> String {
        switch action {
        case "complete":
            return "Complete this text: \(context)"
        case "grammar":
            return "Fix grammar: \(context)"
        case "professional":
            return "Make professional: \(context)"
        case "casual":
            return "Make casual: \(context)"
        case "translate":
            return context
        default:
            return context
        }
    }

    // MARK: - API Calls

    private func callProvider(config: ProviderConfig, system: String, user: String) async -> String? {
        switch config.provider {
        case "anthropic":
            return await callAnthropic(apiKey: config.apiKey, model: config.model, system: system, user: user)
        case "openrouter":
            return await callOpenAICompatible(
                apiKey: config.apiKey,
                model: config.model,
                system: system,
                user: user,
                endpoint: "https://openrouter.ai/api/v1/chat/completions"
            )
        case "openai":
            return await callOpenAICompatible(
                apiKey: config.apiKey,
                model: config.model,
                system: system,
                user: user,
                endpoint: "https://api.openai.com/v1/chat/completions"
            )
        default:
            return nil
        }
    }

    private func callAnthropic(apiKey: String, model: String, system: String, user: String) async -> String? {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 256,
            "system": system,
            "messages": [
                ["role": "user", "content": user]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = httpBody

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String
            {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            // Network error — silently fail for keyboard extension UX
        }

        return nil
    }

    private func callOpenAICompatible(apiKey: String, model: String, system: String, user: String, endpoint: String) async -> String? {
        guard let url = URL(string: endpoint) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 256,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = httpBody

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let text = message["content"] as? String
            {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            // Network error — silently fail for keyboard extension UX
        }

        return nil
    }
}
