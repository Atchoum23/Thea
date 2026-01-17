import Foundation
import Observation

@MainActor
@Observable
final class ProviderRegistry {
    static let shared = ProviderRegistry()

    private(set) var availableProviders: [ProviderInfo] = []
    private var providers: [String: AIProvider] = [:]

    private init() {
        setupBuiltInProviders()
    }

    // MARK: - Provider Info

    struct ProviderInfo: Identifiable {
        let id: String
        let name: String
        let displayName: String
        let requiresAPIKey: Bool
        let isConfigured: Bool
        let metadata: ProviderMetadata

        init(provider: AIProvider, isConfigured: Bool) {
            self.id = provider.metadata.name
            self.name = provider.metadata.name
            self.displayName = provider.metadata.displayName
            self.requiresAPIKey = true
            self.isConfigured = isConfigured
            self.metadata = provider.metadata
        }
    }

    // MARK: - Setup

    private func setupBuiltInProviders() {
        let providerNames = [
            "openai": "OpenAI",
            "anthropic": "Anthropic",
            "google": "Google",
            "perplexity": "Perplexity",
            "openrouter": "OpenRouter",
            "groq": "Groq"
        ]

        for (id, _) in providerNames {
            let isConfigured = SecureStorage.shared.hasAPIKey(for: id)

            if let provider = createProvider(id: id) {
                availableProviders.append(ProviderInfo(provider: provider, isConfigured: isConfigured))
                if isConfigured {
                    providers[id] = provider
                }
            }
        }
    }

    // MARK: - Provider Creation

    func createProvider(id: String) -> AIProvider? {
        guard let apiKey = try? SecureStorage.shared.loadAPIKey(for: id) else {
            return nil
        }

        switch id {
        case "openai":
            return OpenAIProvider(apiKey: apiKey)
        case "anthropic":
            return AnthropicProvider(apiKey: apiKey)
        case "google":
            return GoogleProvider(apiKey: apiKey)
        case "perplexity":
            return PerplexityProvider(apiKey: apiKey)
        case "openrouter":
            return OpenRouterProvider(apiKey: apiKey)
        case "groq":
            return GroqProvider(apiKey: apiKey)
        default:
            return nil
        }
    }

    // MARK: - Provider Access

    func getProvider(id: String) -> AIProvider? {
        if let existing = providers[id] {
            return existing
        }

        if let provider = createProvider(id: id) {
            providers[id] = provider
            return provider
        }

        return nil
    }

    func getDefaultProvider() -> AIProvider? {
        // Try OpenAI first, then Anthropic, then any available
        if let openAI = getProvider(id: "openai") {
            return openAI
        }

        if let anthropic = getProvider(id: "anthropic") {
            return anthropic
        }

        return providers.values.first
    }

    // MARK: - Configuration

    func configureProvider(id: String, apiKey: String) async throws -> ValidationResult {
        // Create temporary provider to validate
        let provider: AIProvider
        switch id {
        case "openai":
            provider = OpenAIProvider(apiKey: apiKey)
        case "anthropic":
            provider = AnthropicProvider(apiKey: apiKey)
        case "google":
            provider = GoogleProvider(apiKey: apiKey)
        case "perplexity":
            provider = PerplexityProvider(apiKey: apiKey)
        case "openrouter":
            provider = OpenRouterProvider(apiKey: apiKey)
        case "groq":
            provider = GroqProvider(apiKey: apiKey)
        default:
            return .failure("Unknown provider")
        }

        // Validate API key
        let result = try await provider.validateAPIKey(apiKey)

        if result.isValid {
            // Save to Keychain
            try SecureStorage.shared.saveAPIKey(apiKey, for: id)

            // Add to active providers
            providers[id] = provider

            // Update available providers list
            if let index = availableProviders.firstIndex(where: { $0.id == id }) {
                availableProviders[index] = ProviderInfo(provider: provider, isConfigured: true)
            }
        }

        return result
    }

    func removeProvider(id: String) throws {
        try SecureStorage.shared.deleteAPIKey(for: id)
        providers.removeValue(forKey: id)

        if let index = availableProviders.firstIndex(where: { $0.id == id }),
           let provider = createDummyProvider(id: id) {
            availableProviders[index] = ProviderInfo(provider: provider, isConfigured: false)
        }
    }

    // MARK: - Helper

    private func createDummyProvider(id: String) -> AIProvider? {
        switch id {
        case "openai":
            return OpenAIProvider(apiKey: "")
        case "anthropic":
            return AnthropicProvider(apiKey: "")
        case "google":
            return GoogleProvider(apiKey: "")
        case "perplexity":
            return PerplexityProvider(apiKey: "")
        case "openrouter":
            return OpenRouterProvider(apiKey: "")
        case "groq":
            return GroqProvider(apiKey: "")
        default:
            return nil
        }
    }
}
