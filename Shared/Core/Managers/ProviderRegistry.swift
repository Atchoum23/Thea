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
        // periphery:ignore - Reserved: name property — reserved for future feature activation
        let name: String
        let displayName: String
        // periphery:ignore - Reserved: requiresAPIKey property — reserved for future feature activation
        let requiresAPIKey: Bool
        let isConfigured: Bool
        // periphery:ignore - Reserved: metadata property — reserved for future feature activation
        let metadata: ProviderMetadata

        init(provider: AIProvider, isConfigured: Bool) {
            id = provider.metadata.name
            // periphery:ignore - Reserved: name property reserved for future feature activation
            name = provider.metadata.name
            // periphery:ignore - Reserved: requiresAPIKey property reserved for future feature activation
            displayName = provider.metadata.displayName
            // periphery:ignore - Reserved: metadata property reserved for future feature activation
            requiresAPIKey = true
            self.isConfigured = isConfigured
            metadata = provider.metadata
        }

        /// Lightweight init for registering provider metadata without an active API key.
        /// Used during app startup to populate `availableProviders` regardless of Keychain state.
        init(id: String, displayName: String, isConfigured: Bool) {
            self.id = id
            self.name = id
            self.displayName = displayName
            self.requiresAPIKey = true
            self.isConfigured = isConfigured
            self.metadata = ProviderMetadata(
                name: id,
                displayName: displayName,
                websiteURL: URL(string: "https://\(id).com") ?? URL(string: "https://example.com")!,
                documentationURL: URL(string: "https://\(id).com/docs") ?? URL(string: "https://example.com")!
            )
        }
    }

    // MARK: - Setup

    private func setupBuiltInProviders() {
        debugLog("🔧 Setting up built-in providers...")

        let providerNames: [(id: String, displayName: String)] = [
            ("openai", "OpenAI"),
            ("anthropic", "Anthropic"),
            ("google", "Google"),
            ("perplexity", "Perplexity"),
            ("openrouter", "OpenRouter"),
            ("groq", "Groq")
        ]

        for (id, displayName) in providerNames {
            let isConfigured = checkAPIKeyConfigured(for: id)
            debugLog("  Provider \(id): isConfigured=\(isConfigured)")

            // Always register provider metadata so availableProviders is populated
            // even when no API key is configured (e.g., first launch, test environment)
            if isConfigured, let provider = createProvider(id: id) {
                availableProviders.append(ProviderInfo(provider: provider, isConfigured: true))
                providers[id] = provider
            } else {
                availableProviders.append(ProviderInfo(id: id, displayName: displayName, isConfigured: false))
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

    // periphery:ignore - Reserved: refreshCoreMLProviders() instance method — reserved for future feature activation
    /// Discover and register CoreML models for iOS on-device inference
    func refreshCoreMLProviders() async {
        localProviders.removeAll()

        let engine = CoreMLInferenceEngine.shared
        let models = engine.discoverLLMModels()

// periphery:ignore - Reserved: refreshCoreMLProviders() instance method reserved for future feature activation

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

    // periphery:ignore - Reserved: hasLocalModels property — reserved for future feature activation
    /// Check if any local models are available
    var hasLocalModels: Bool {
        !localProviders.isEmpty
    }

    // periphery:ignore - Reserved: hasLocalModels property reserved for future feature activation
    /// Get all providers that have API keys configured
    var configuredProviders: [AIProvider] {
        Array(providers.values)
    }

    // MARK: - Provider Creation

    func createProvider(id: String) -> AIProvider? {
        let apiKey: String?
        do {
            apiKey = try SecureStorage.shared.loadAPIKey(for: id)
        } catch {
            registryLogger.error("Failed to load API key for '\(id)': \(error.localizedDescription)")
            return nil
        }
        guard let apiKey else {
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

    /// Resolve a model ID (e.g., "gpt-4o", "claude-4-sonnet") to the provider that serves it.
    func getProvider(for modelId: String) -> AIProvider? {
        if modelId == "local" || modelId.hasPrefix("local:") {
            return localProviders.values.first
        }
        // Match model prefix to provider
        let providerMapping: [(prefix: String, providerId: String)] = [
            ("gpt", "openai"), ("o1", "openai"), ("o3", "openai"),
            ("claude", "anthropic"),
            ("gemini", "google"),
            ("llama", "groq"), ("mixtral", "groq"),
            ("sonar", "perplexity"), ("pplx", "perplexity")
        ]
        for mapping in providerMapping {
            if modelId.lowercased().contains(mapping.prefix) {
                return getProvider(id: mapping.providerId)
            }
        }
        // Fallback to OpenRouter (routes any model)
        return getProvider(id: "openrouter") ?? getDefaultProvider()
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

    // periphery:ignore - Reserved: getProviderForTask(complexity:) instance method — reserved for future feature activation
    /// Get a provider based on task complexity (for orchestrator)
    func getProviderForTask(complexity: QueryComplexity) -> AIProvider? {
        let preference = orchestratorConfig.localModelPreference

        // periphery:ignore - Reserved: getProviderForTask(complexity:) instance method reserved for future feature activation
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

    // periphery:ignore - Reserved: configureProvider(id:apiKey:) instance method — reserved for future feature activation
    func configureProvider(id: String, apiKey: String) async throws -> ValidationResult {
        // Create temporary provider to validate
        // periphery:ignore - Reserved: configureProvider(id:apiKey:) instance method reserved for future feature activation
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

    // periphery:ignore - Reserved: removeProvider(id:) instance method — reserved for future feature activation
    func removeProvider(id: String) throws {
        // periphery:ignore - Reserved: removeProvider(id:) instance method reserved for future feature activation
        try SecureStorage.shared.deleteAPIKey(for: id)
        providers.removeValue(forKey: id)

        if let index = availableProviders.firstIndex(where: { $0.id == id }),
           let provider = createDummyProvider(id: id)
        {
            availableProviders[index] = ProviderInfo(provider: provider, isConfigured: false)
        }
    }

    // MARK: - Helper

    // periphery:ignore - Reserved: createDummyProvider(id:) instance method reserved for future feature activation
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
