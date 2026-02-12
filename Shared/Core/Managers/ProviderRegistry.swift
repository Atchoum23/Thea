import Foundation
import Observation
import os.log

private let registryLogger = Logger(subsystem: "ai.thea.app", category: "ProviderRegistry")

@MainActor
@Observable
final class ProviderRegistry {
    static let shared = ProviderRegistry()

    private(set) var availableProviders: [ProviderInfo] = []
    private var providers: [String: AIProvider] = [:]
    private var localProviders: [String: AIProvider] = [:]

    /// All instantiated providers (cloud + local), keyed by provider ID.
    /// Used by InferenceRelayHandler to enumerate models.
    var allProviders: [String: AIProvider] {
        var result = providers
        for (key, value) in localProviders {
            result[key] = value
        }
        return result
    }

    // Configuration accessor
    private var orchestratorConfig: OrchestratorConfiguration {
        AppConfiguration.shared.orchestratorConfig
    }

    private init() {
        debugLog("🚀 ProviderRegistry initializing...")
        setupBuiltInProviders()
        setupLocalProviders()
        debugLog("✅ ProviderRegistry init complete")
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
            id = provider.metadata.name
            name = provider.metadata.name
            displayName = provider.metadata.displayName
            requiresAPIKey = true
            self.isConfigured = isConfigured
            metadata = provider.metadata
        }
    }

    // MARK: - Setup

    private func setupBuiltInProviders() {
        debugLog("🔧 Setting up built-in providers...")

        let providerNames = [
            "openai": "OpenAI",
            "anthropic": "Anthropic",
            "google": "Google",
            "perplexity": "Perplexity",
            "openrouter": "OpenRouter",
            "groq": "Groq"
        ]

        // Create provider instances without checking Keychain yet
        // This avoids Keychain prompts blocking app startup
        for (id, _) in providerNames {
            // Defer Keychain access - check lazily when provider is first used
            let isConfigured = checkAPIKeyConfigured(for: id)
            debugLog("  Provider \(id): isConfigured=\(isConfigured)")

            if let provider = createProvider(id: id) {
                availableProviders.append(ProviderInfo(provider: provider, isConfigured: isConfigured))
                if isConfigured {
                    providers[id] = provider
                }
            }
        }

        debugLog("✅ Built-in providers setup complete: \(availableProviders.count) providers")
    }

    /// Check if API key is configured (already handles Keychain errors gracefully)
    private func checkAPIKeyConfigured(for provider: String) -> Bool {
        SecureStorage.shared.hasAPIKey(for: provider)
    }

    // MARK: - Local Model Setup

    private func setupLocalProviders() {
        #if os(macOS)
        // Discover and register local models from LocalModelManager (macOS only)
        Task {
            await refreshLocalProviders()
        }
        #elseif os(iOS)
        // iOS: Discover CoreML models for on-device inference
        Task {
            await refreshCoreMLProviders()
        }
        #else
        // Local models not supported on watchOS/tvOS
        debugLog("📱 Local models not available on this platform")
        #endif
    }

    /// Refresh local model providers - call when local models change
    func refreshLocalProviders() async {
        #if os(macOS)
        localProviders.removeAll()

        debugLog("🔄 Starting local model discovery...")

        let localManager = LocalModelManager.shared
        await localManager.discoverModels()

        debugLog("📦 Found \(localManager.availableModels.count) local models to register")

        for model in localManager.availableModels {
            debugLog("📂 Attempting to load: \(model.name) at \(model.path.path)")
            do {
                let instance = try await localManager.loadModel(model)
                let provider = LocalModelProvider(modelName: model.name, instance: instance)
                localProviders["local:\(model.name)"] = provider
                debugLog("✅ Registered local model: \(model.name)")
                print("✅ Registered local model: \(model.name)")
            } catch {
                debugLog("⚠️ Failed to load local model \(model.name): \(error)")
                print("⚠️ Failed to load local model \(model.name): \(error)")
            }
        }

        debugLog("📊 Total local models registered: \(localProviders.count)")
        print("📊 Total local models registered: \(localProviders.count)")
        #else
        // Local models not available on watchOS/tvOS
        debugLog("📱 Skipping local model refresh - not available on this platform")
        #endif
    }

    /// Discover and register CoreML models for iOS on-device inference
    func refreshCoreMLProviders() async {
        localProviders.removeAll()

        let engine = CoreMLInferenceEngine.shared
        let models = engine.discoverLLMModels()

        debugLog("📱 Found \(models.count) CoreML models")

        for info in models {
            let localModel = LocalModel(
                id: UUID(),
                name: info.name,
                path: info.path,
                type: .coreML,
                format: info.path.pathExtension,
                sizeInBytes: Int(info.sizeBytes),
                runtime: .coreML,
                size: info.sizeBytes,
                parameters: "",
                quantization: ""
            )
            let instance = CoreMLModelInstance(model: localModel)
            let provider = LocalModelProvider(modelName: info.name, instance: instance)
            localProviders["local:\(info.name)"] = provider
            debugLog("✅ Registered CoreML model: \(info.name)")
        }

        debugLog("📊 Total CoreML models registered: \(localProviders.count)")
    }

    /// Write debug log using os_log (viewable in Console.app)
    private func debugLog(_ message: String) {
        registryLogger.info("\(message)")
    }

    /// Get all available local model names
    func getAvailableLocalModels() -> [String] {
        Array(localProviders.keys).map { $0.replacingOccurrences(of: "local:", with: "") }
    }

    /// Check if any local models are available
    var hasLocalModels: Bool {
        !localProviders.isEmpty
    }

    /// Get all providers that have API keys configured
    var configuredProviders: [AIProvider] {
        Array(providers.values)
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
        // Check for local model first (format: "local:modelname")
        if id.hasPrefix("local:") {
            return localProviders[id]
        }

        // Check cloud providers
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
        // Check orchestrator configuration for local model preference
        let preference = orchestratorConfig.localModelPreference

        switch preference {
        case .always:
            // Only use local models, fail if none available
            if let localProvider = localProviders.values.first {
                return localProvider
            }
            return nil

        case .prefer:
            // Try local first, fallback to cloud
            if let localProvider = localProviders.values.first {
                return localProvider
            }
            return getCloudProvider()

        case .balanced:
            // Use local for simple tasks - for default provider, prefer cloud
            // This is the entry point; routing happens elsewhere
            return getCloudProvider() ?? localProviders.values.first

        case .cloudFirst:
            // Prefer cloud, use local only if no cloud available
            return getCloudProvider() ?? localProviders.values.first
        }
    }

    /// Get a cloud-based provider
    func getCloudProvider() -> AIProvider? {
        // Try user's default provider first
        let defaultProviderID = SettingsManager.shared.defaultProvider
        if let provider = getProvider(id: defaultProviderID) {
            return provider
        }

        // Fallback order: OpenRouter → OpenAI → Anthropic → any
        if let openRouter = getProvider(id: "openrouter") {
            return openRouter
        }
        if let openAI = getProvider(id: "openai") {
            return openAI
        }
        if let anthropic = getProvider(id: "anthropic") {
            return anthropic
        }
        return providers.values.first
    }

    /// Get a local model provider by name
    func getLocalProvider(modelName: String? = nil) -> AIProvider? {
        if let name = modelName {
            return localProviders["local:\(name)"]
        }
        return localProviders.values.first
    }

    /// Get a provider based on task complexity (for orchestrator)
    func getProviderForTask(complexity: QueryComplexity) -> AIProvider? {
        let preference = orchestratorConfig.localModelPreference

        switch (preference, complexity) {
        case (.always, _):
            // Always local
            return localProviders.values.first

        case (.prefer, _):
            // Local first
            return localProviders.values.first ?? getCloudProvider()

        case (.balanced, .simple):
            // Simple tasks → local if available
            return localProviders.values.first ?? getCloudProvider()

        case (.balanced, .moderate), (.balanced, .complex):
            // Complex tasks → cloud preferred
            return getCloudProvider() ?? localProviders.values.first

        case (.cloudFirst, _):
            // Cloud first
            return getCloudProvider() ?? localProviders.values.first
        }
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
           let provider = createDummyProvider(id: id)
        {
            availableProviders[index] = ProviderInfo(provider: provider, isConfigured: false)
        }
    }

    // MARK: - Helper

    private func createDummyProvider(id: String) -> AIProvider? {
        switch id {
        case "openai":
            OpenAIProvider(apiKey: "")
        case "anthropic":
            AnthropicProvider(apiKey: "")
        case "google":
            GoogleProvider(apiKey: "")
        case "perplexity":
            PerplexityProvider(apiKey: "")
        case "openrouter":
            OpenRouterProvider(apiKey: "")
        case "groq":
            GroqProvider(apiKey: "")
        default:
            nil
        }
    }
}
