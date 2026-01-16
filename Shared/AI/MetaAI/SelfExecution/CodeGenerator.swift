// CodeGenerator.swift
import Foundation
import OSLog

public actor CodeGenerator {
    public static let shared = CodeGenerator()

    private let logger = Logger(subsystem: "com.thea.app", category: "CodeGenerator")
    private let basePath = "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"

    public struct GenerationResult: Sendable {
        public let success: Bool
        public let code: String
        public let tokensUsed: Int
        public let provider: String
        public let error: String?
    }

    public enum GenerationError: Error, LocalizedError, Sendable {
        case noProvidersConfigured
        case allProvidersFailed(errors: [String])
        case invalidRequirement
        case contextTooLarge

        public var errorDescription: String? {
            switch self {
            case .noProvidersConfigured:
                return "No AI providers configured. Please add API keys in Settings → Providers."
            case .allProvidersFailed(let errors):
                return "All providers failed: \(errors.joined(separator: "; "))"
            case .invalidRequirement:
                return "Invalid file requirement - missing path or description."
            case .contextTooLarge:
                return "Context too large for code generation."
            }
        }
    }

    // MARK: - Public API

    public func generateCode(for file: FileRequirement, architectureRules: [String]) async throws -> GenerationResult {
        logger.info("Generating code for: \(file.path)")

        // Build the prompt
        let prompt = buildPrompt(for: file, rules: architectureRules)

        // Try providers in priority order
        let providers = await getConfiguredProviders()

        if providers.isEmpty {
            throw GenerationError.noProvidersConfigured
        }

        var errors: [String] = []

        for provider in providers {
            do {
                let result = try await callProvider(provider, prompt: prompt)
                if result.success {
                    logger.info("Code generated successfully using \(provider)")
                    return result
                }
            } catch {
                errors.append("\(provider): \(error.localizedDescription)")
                logger.warning("Provider \(provider) failed: \(error.localizedDescription)")
            }
        }

        throw GenerationError.allProvidersFailed(errors: errors)
    }

    public func generateCodeWithContext(
        for file: FileRequirement,
        existingCode: String?,
        relatedFiles: [String: String],
        architectureRules: [String]
    ) async throws -> GenerationResult {
        logger.info("Generating code with context for: \(file.path)")

        let prompt = buildContextualPrompt(
            for: file,
            existingCode: existingCode,
            relatedFiles: relatedFiles,
            rules: architectureRules
        )

        let providers = await getConfiguredProviders()

        if providers.isEmpty {
            throw GenerationError.noProvidersConfigured
        }

        var errors: [String] = []

        for provider in providers {
            do {
                let result = try await callProvider(provider, prompt: prompt)
                if result.success {
                    return result
                }
            } catch {
                errors.append("\(provider): \(error.localizedDescription)")
            }
        }

        throw GenerationError.allProvidersFailed(errors: errors)
    }

    // MARK: - Prompt Building

    private func buildPrompt(for file: FileRequirement, rules: [String]) -> String {
        let fileName = (file.path as NSString).lastPathComponent
        let rulesText = rules.joined(separator: "\n")

        var prompt = """
        You are a Swift 6 expert generating production-ready code for Thea, a macOS AI assistant app.

        ## Architecture Rules (MUST FOLLOW)
        \(rulesText)

        ## Task
        Generate the complete implementation for: `\(fileName)`
        Path: `\(file.path)`

        ## Requirements
        \(file.description)

        """

        if !file.codeHints.isEmpty {
            prompt += """

            ## Implementation Hints (from spec)
            ```swift
            \(file.codeHints.joined(separator: "\n\n"))
            ```

            """
        }

        prompt += """

        ## Output Format
        Return ONLY the complete Swift code. No explanations, no markdown code fences.
        Start directly with imports and end with the final closing brace.

        ## Critical Requirements
        1. All types must be `public` for cross-module access
        2. Services must be `actor` with `static let shared`
        3. Use `async/await` for all asynchronous operations
        4. Include comprehensive error handling
        5. Add `Logger` calls for debugging
        6. Follow the exact patterns shown in hints
        """

        return prompt
    }

    private func buildContextualPrompt(
        for file: FileRequirement,
        existingCode: String?,
        relatedFiles: [String: String],
        rules: [String]
    ) -> String {
        var prompt = buildPrompt(for: file, rules: rules)

        if let existing = existingCode {
            prompt += """

            ## Existing Code (to modify)
            ```swift
            \(existing)
            ```

            """
        }

        if !relatedFiles.isEmpty {
            prompt += "\n## Related Files (for context)\n"
            for (path, content) in relatedFiles.prefix(3) {
                let fileName = (path as NSString).lastPathComponent
                prompt += """

                ### \(fileName)
                ```swift
                \(content.prefix(2000))
                ```

                """
            }
        }

        return prompt
    }

    // MARK: - Provider Integration

    private func getConfiguredProviders() async -> [String] {
        // Check which providers have API keys configured
        var providers: [String] = []

        // Priority order: Claude (best for Swift) → OpenAI → OpenRouter → Local
        if await hasAnthropicKey() {
            providers.append("anthropic")
        }
        if await hasOpenAIKey() {
            providers.append("openai")
        }
        if await hasOpenRouterKey() {
            providers.append("openrouter")
        }
        if await hasLocalModels() {
            providers.append("local")
        }

        return providers
    }

    private func hasAnthropicKey() async -> Bool {
        // Check AppConfiguration for Anthropic API key
        // TODO: Connect to actual configuration
        return UserDefaults.standard.string(forKey: "anthropic_api_key")?.isEmpty == false
    }

    private func hasOpenAIKey() async -> Bool {
        return UserDefaults.standard.string(forKey: "openai_api_key")?.isEmpty == false
    }

    private func hasOpenRouterKey() async -> Bool {
        return UserDefaults.standard.string(forKey: "openrouter_api_key")?.isEmpty == false
    }

    private func hasLocalModels() async -> Bool {
        let modelsPath = UserDefaults.standard.string(forKey: "local_models_path") ?? ""
        return FileManager.default.fileExists(atPath: modelsPath)
    }

    private func callProvider(_ provider: String, prompt: String) async throws -> GenerationResult {
        switch provider {
        case "anthropic":
            return try await callAnthropic(prompt: prompt)
        case "openai":
            return try await callOpenAI(prompt: prompt)
        case "openrouter":
            return try await callOpenRouter(prompt: prompt)
        case "local":
            return try await callLocalModel(prompt: prompt)
        default:
            throw GenerationError.noProvidersConfigured
        }
    }

    private func callAnthropic(prompt: String) async throws -> GenerationResult {
        guard let apiKey = UserDefaults.standard.string(forKey: "anthropic_api_key"),
              !apiKey.isEmpty else {
            throw GenerationError.noProvidersConfigured
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 8192,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Anthropic", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["content"] as? [[String: Any]])?.first
        let text = content?["text"] as? String ?? ""
        let usage = json?["usage"] as? [String: Any]
        let tokens = (usage?["input_tokens"] as? Int ?? 0) + (usage?["output_tokens"] as? Int ?? 0)

        return GenerationResult(
            success: !text.isEmpty,
            code: cleanGeneratedCode(text),
            tokensUsed: tokens,
            provider: "anthropic",
            error: text.isEmpty ? "Empty response" : nil
        )
    }

    private func callOpenAI(prompt: String) async throws -> GenerationResult {
        guard let apiKey = UserDefaults.standard.string(forKey: "openai_api_key"),
              !apiKey.isEmpty else {
            throw GenerationError.noProvidersConfigured
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 8192,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let text = message?["content"] as? String ?? ""
        let usage = json?["usage"] as? [String: Any]
        let tokens = usage?["total_tokens"] as? Int ?? 0

        return GenerationResult(
            success: !text.isEmpty,
            code: cleanGeneratedCode(text),
            tokensUsed: tokens,
            provider: "openai",
            error: text.isEmpty ? "Empty response" : nil
        )
    }

    private func callOpenRouter(prompt: String) async throws -> GenerationResult {
        guard let apiKey = UserDefaults.standard.string(forKey: "openrouter_api_key"),
              !apiKey.isEmpty else {
            throw GenerationError.noProvidersConfigured
        }

        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "anthropic/claude-sonnet-4",
            "max_tokens": 8192,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenRouter", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let text = message?["content"] as? String ?? ""

        return GenerationResult(
            success: !text.isEmpty,
            code: cleanGeneratedCode(text),
            tokensUsed: 0,
            provider: "openrouter",
            error: text.isEmpty ? "Empty response" : nil
        )
    }

    private func callLocalModel(prompt: String) async throws -> GenerationResult {
        // TODO: Implement local MLX model integration
        throw GenerationError.noProvidersConfigured
    }

    private func cleanGeneratedCode(_ code: String) -> String {
        var cleaned = code

        // Remove markdown code fences if present
        if cleaned.hasPrefix("```swift") {
            cleaned = String(cleaned.dropFirst(8))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }

        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
