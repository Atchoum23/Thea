#if os(macOS)
import Foundation
import OSLog

// MARK: - AICodeFixGenerator
// AI-powered code fix generation with full provider integration
// Supports Claude, OpenAI, OpenRouter, and local MLX models

public actor AICodeFixGenerator {
    public static let shared = AICodeFixGenerator()

    private let logger = Logger(subsystem: "com.thea.metaai", category: "AICodeFixGenerator")
    
    /// Cache for recent fixes to avoid redundant API calls
    private var fixCache: [String: GeneratedFix] = [:]
    private let maxCacheSize = 100

    private init() {}

    // MARK: - Public Types

    public struct GeneratedFix: Sendable {
        public let originalCode: String
        public let fixedCode: String
        public let explanation: String
        public let confidence: Double
        public let provider: String
        public let model: String
        public let applySuggestion: String?

        public init(
            originalCode: String,
            fixedCode: String,
            explanation: String,
            confidence: Double,
            provider: String = "unknown",
            model: String = "unknown",
            applySuggestion: String? = nil
        ) {
            self.originalCode = originalCode
            self.fixedCode = fixedCode
            self.explanation = explanation
            self.confidence = confidence
            self.provider = provider
            self.model = model
            self.applySuggestion = applySuggestion
        }
    }

    public enum AIError: LocalizedError, Sendable {
        case noProvidersConfigured
        case generationFailed(String)
        case invalidResponse
        case providerError(String)
        case rateLimited
        case contextTooLarge

        public var errorDescription: String? {
            switch self {
            case .noProvidersConfigured:
                return "No AI providers configured. Please add API keys in Settings."
            case .generationFailed(let message):
                return "Fix generation failed: \(message)"
            case .invalidResponse:
                return "Received invalid response from AI provider"
            case .providerError(let message):
                return "Provider error: \(message)"
            case .rateLimited:
                return "Rate limited by AI provider. Please try again later."
            case .contextTooLarge:
                return "Code context too large for the model's context window."
            }
        }
    }

    // MARK: - Generate Fix

    public func generateFix(for error: ErrorParser.ParsedError) async throws -> GeneratedFix {
        logger.info("AI fix generation requested for: \(error.file):\(error.line)")

        // Check cache first
        let cacheKey = "\(error.file):\(error.line):\(error.message)"
        if let cached = fixCache[cacheKey] {
            logger.info("Returning cached fix")
            return cached
        }

        // Get available provider
        guard let (provider, providerId) = await getAvailableProvider() else {
            throw AIError.noProvidersConfigured
        }

        let prompt = buildFixPrompt(for: error)
        let model = await getPreferredModel(for: providerId)
        
        logger.info("Using provider: \(providerId), model: \(model)")

        let fix = try await callProvider(provider, prompt: prompt, model: model, providerId: providerId)
        
        // Cache the result
        cacheResult(fix, forKey: cacheKey)
        
        return fix
    }

    // MARK: - Generate Fix with Context

    public func generateFixWithContext(
        error: ErrorParser.ParsedError,
        surroundingCode: String,
        projectContext: String? = nil
    ) async throws -> GeneratedFix {
        logger.info("AI fix generation with context requested")

        guard let (provider, providerId) = await getAvailableProvider() else {
            throw AIError.noProvidersConfigured
        }

        let prompt = buildContextualFixPrompt(
            error: error,
            surroundingCode: surroundingCode,
            projectContext: projectContext
        )
        
        let model = await getPreferredModel(for: providerId)
        
        return try await callProvider(provider, prompt: prompt, model: model, providerId: providerId)
    }
    
    // MARK: - Batch Fix Generation
    
    /// Result of a batch fix operation
    public struct BatchFixResult: Sendable {
        public let error: ErrorParser.ParsedError
        public let fix: GeneratedFix?
        public let failureReason: String?
        
        public var success: Bool { fix != nil }
    }
    
    /// Generate fixes for multiple errors efficiently
    public func generateFixes(for errors: [ErrorParser.ParsedError]) async -> [BatchFixResult] {
        var results: [BatchFixResult] = []
        
        // Process in batches to avoid overwhelming the API
        let batchSize = 5
        for batch in errors.chunked(into: batchSize) {
            await withTaskGroup(of: BatchFixResult.self) { group in
                for parsedError in batch {
                    group.addTask {
                        do {
                            let fix = try await self.generateFix(for: parsedError)
                            return BatchFixResult(error: parsedError, fix: fix, failureReason: nil)
                        } catch let err {
                            return BatchFixResult(error: parsedError, fix: nil, failureReason: err.localizedDescription)
                        }
                    }
                }
                
                for await result in group {
                    results.append(result)
                }
            }
        }
        
        return results
    }

    // MARK: - Prompt Building

    private func buildFixPrompt(for error: ErrorParser.ParsedError) -> String {
        var prompt = """
        You are a Swift 6 expert specializing in fixing compilation errors. Analyze the following error and provide a fix.

        ## Error Details
        - File: \(error.file)
        - Line: \(error.line), Column: \(error.column)
        - Error Message: \(error.message)
        - Category: \(error.category.rawValue)

        """

        if !error.context.isEmpty {
            prompt += "\n## Code Context\n```swift\n"
            for (index, line) in error.context.enumerated() {
                let lineNumber = error.line - error.context.count / 2 + index
                let marker = lineNumber == error.line ? " >>> " : "     "
                prompt += "\(lineNumber)\(marker)\(line)\n"
            }
            prompt += "```\n"
        }

        prompt += """

        ## Required Response Format
        Provide your response in the following format:

        ### Fixed Code
        ```swift
        // The corrected code snippet
        ```

        ### Explanation
        Brief explanation of what was wrong and how to fix it.

        ### Confidence
        A number between 0 and 1 indicating your confidence in this fix.

        ## Guidelines
        - Focus on Swift 6 concurrency patterns (Sendable, @MainActor, async/await) if the error is concurrency-related
        - Provide the minimal change needed to fix the error
        - Consider the broader context and avoid introducing new issues
        - If the fix requires importing a module, mention it
        """

        return prompt
    }

    private func buildContextualFixPrompt(
        error: ErrorParser.ParsedError,
        surroundingCode: String,
        projectContext: String?
    ) -> String {
        var prompt = buildFixPrompt(for: error)

        prompt += "\n\n## Extended Code Context\n```swift\n\(surroundingCode)\n```\n"

        if let context = projectContext {
            prompt += "\n## Project Information\n\(context)\n"
        }

        return prompt
    }

    // MARK: - Provider Integration

    private func getAvailableProvider() async -> (any AIProvider, String)? {
        let registry = await ProviderRegistry.shared
        
        // Try providers in order of preference
        let preferredOrder = ["anthropic", "openai", "openrouter", "groq", "local"]
        
        for providerId in preferredOrder {
            if let provider = await registry.getProvider(id: providerId) {
                if await isProviderConfigured(providerId) {
                    return (provider, providerId)
                }
            }
        }
        
        // Try any available provider from the registry's available providers
        for providerInfo in await registry.availableProviders {
            if providerInfo.isConfigured {
                if let provider = await registry.getProvider(id: providerInfo.id) {
                    return (provider, providerInfo.id)
                }
            }
        }
        
        return nil
    }
    
    private func isProviderConfigured(_ providerId: String) async -> Bool {
        switch providerId {
        case "anthropic", "openai", "openrouter", "groq", "google", "perplexity":
            // Check SecureStorage for API key
            return await SecureStorage.shared.hasAPIKey(for: providerId)
        case "local":
            // Local models don't need API keys
            return true
        default:
            return false
        }
    }
    
    private func getPreferredModel(for providerId: String) async -> String {
        switch providerId {
        case "anthropic":
            return "claude-sonnet-4-20250514"
        case "openai":
            return "gpt-4o"
        case "openrouter":
            return "anthropic/claude-sonnet-4-20250514"
        case "groq":
            return "llama-3.3-70b-versatile"
        case "local":
            return "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"
        default:
            return "gpt-4o"
        }
    }
    
    private func callProvider(
        _ provider: any AIProvider,
        prompt: String,
        model: String,
        providerId: String
    ) async throws -> GeneratedFix {
        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: model
        )
        
        var result = ""
        
        do {
            let stream = try await provider.chat(messages: [message], model: model, stream: true)
            
            for try await chunk in stream {
                switch chunk.type {
                case .delta(let text):
                    result += text
                case .complete:
                    break
                case .error(let error):
                    throw error
                }
            }
        } catch {
            logger.error("Provider call failed: \(error.localizedDescription)")
            throw AIError.providerError(error.localizedDescription)
        }
        
        return parseResponse(result, provider: providerId, model: model)
    }
    
    private func parseResponse(_ response: String, provider: String, model: String) -> GeneratedFix {
        // Extract fixed code from markdown code block
        var fixedCode = ""
        if let codeMatch = response.range(of: "```swift\n([\\s\\S]*?)```", options: .regularExpression) {
            fixedCode = String(response[codeMatch])
                .replacingOccurrences(of: "```swift\n", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract explanation
        var explanation = ""
        if let explainStart = response.range(of: "### Explanation"),
           let explainEnd = response.range(of: "### Confidence") {
            explanation = String(response[explainStart.upperBound..<explainEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Fallback: extract text after code block
            if let swiftRange = response.range(of: "```swift"),
               let codeEnd = response.range(of: "```", range: swiftRange.upperBound..<response.endIndex) {
                explanation = String(response[codeEnd.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: "###").first ?? ""
            }
        }
        
        // Extract confidence
        var confidence = 0.7 // Default confidence
        if let confidenceMatch = response.range(of: "### Confidence[\\s\\S]*?([0-9.]+)", options: .regularExpression) {
            let confidenceStr = String(response[confidenceMatch])
            if let value = Double(confidenceStr.filter { $0.isNumber || $0 == "." }) {
                confidence = min(1.0, max(0.0, value))
            }
        }
        
        return GeneratedFix(
            originalCode: "",
            fixedCode: fixedCode,
            explanation: explanation,
            confidence: confidence,
            provider: provider,
            model: model,
            applySuggestion: fixedCode.isEmpty ? nil : "Replace the problematic code with the fix above"
        )
    }

    // MARK: - Configuration Check

    public func hasConfiguredProviders() async -> Bool {
        await getAvailableProvider() != nil
    }

    public func getAvailableProviders() async -> [String] {
        var available: [String] = []
        let allProviders = ["anthropic", "openai", "openrouter", "groq", "local"]
        
        for providerId in allProviders {
            if await isProviderConfigured(providerId) {
                available.append(providerId)
            }
        }
        
        return available
    }
    
    // MARK: - Cache Management
    
    private func cacheResult(_ fix: GeneratedFix, forKey key: String) {
        // Evict oldest entries if cache is full
        if fixCache.count >= maxCacheSize {
            fixCache.removeAll()
        }
        fixCache[key] = fix
    }
    
    /// Clear the fix cache
    public func clearCache() {
        fixCache.removeAll()
        logger.info("Fix cache cleared")
    }
}

// MARK: - Array Extension for Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#endif
