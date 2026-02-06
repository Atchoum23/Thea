// ProviderRegistry.swift
// Thea V2
//
// Central registry for all AI providers

import Foundation
import OSLog

// MARK: - Provider Registry

/// Central registry managing all AI providers
@MainActor
public final class ProviderRegistry: ObservableObject {
    public static let shared = ProviderRegistry()

    private let logger = Logger(subsystem: "com.thea.v2", category: "ProviderRegistry")

    // MARK: - Published State

    @Published public private(set) var providers: [String: any AIProvider] = [:]
    @Published public private(set) var defaultProviderId: String = "openrouter"
    @Published public private(set) var providerHealth: [String: ProviderHealth] = [:]

    // MARK: - Initialization

    private init() {
        // Providers will be registered during app startup
    }

    // MARK: - Registration

    /// Register a provider
    public func register(_ provider: any AIProvider) {
        providers[provider.id] = provider
        logger.info("Registered provider: \(provider.name)")

        // Publish event
        EventBus.shared.publish(StateEvent(
            source: .system,
            component: "ProviderRegistry",
            newState: "registered:\(provider.id)"
        ))
    }

    /// Unregister a provider
    public func unregister(_ providerId: String) {
        providers.removeValue(forKey: providerId)
        providerHealth.removeValue(forKey: providerId)
        logger.info("Unregistered provider: \(providerId)")
    }

    // MARK: - Access

    /// Get a provider by ID
    public func provider(id: String) -> (any AIProvider)? {
        providers[id]
    }

    /// Get the default provider
    public var defaultProvider: (any AIProvider)? {
        providers[defaultProviderId]
    }

    /// Set the default provider
    public func setDefault(_ providerId: String) {
        guard providers[providerId] != nil else {
            logger.warning("Cannot set default to unknown provider: \(providerId)")
            return
        }
        defaultProviderId = providerId

        // Update config
        TheaConfig.shared.ai.defaultProvider = providerId
        TheaConfig.shared.save()

        // Publish event
        EventBus.shared.publish(StateEvent(
            source: .user,
            component: "ProviderRegistry",
            previousState: defaultProviderId,
            newState: providerId,
            reason: "User changed default provider"
        ))
    }

    /// Get all configured providers
    public var configuredProviders: [any AIProvider] {
        providers.values.filter(\.isConfigured)
    }

    /// Get providers with specific capability
    public func providers(with capability: ProviderCapability) -> [any AIProvider] {
        providers.values.filter { $0.capabilities.contains(capability) }
    }

    // MARK: - Models

    /// Get all available models across all configured providers
    public var allModels: [AIModel] {
        configuredProviders.flatMap(\.supportedModels)
    }

    /// Get models for a specific provider
    public func models(for providerId: String) -> [AIModel] {
        providers[providerId]?.supportedModels ?? []
    }

    /// Find a model by ID
    public func findModel(_ modelId: String) -> (provider: any AIProvider, model: AIModel)? {
        for provider in providers.values {
            if let model = provider.supportedModels.first(where: { $0.id == modelId }) {
                return (provider, model)
            }
        }
        return nil
    }

    // MARK: - Health Checks

    /// Check health of all providers
    public func checkAllHealth() async {
        for (id, provider) in providers {
            let health = await provider.checkHealth()
            providerHealth[id] = health

            if !health.isHealthy {
                logger.warning("Provider \(id) unhealthy: \(health.errorMessage ?? "Unknown")")
            }
        }
    }

    /// Check health of a specific provider
    public func checkHealth(for providerId: String) async -> ProviderHealth? {
        guard let provider = providers[providerId] else { return nil }

        let health = await provider.checkHealth()
        providerHealth[providerId] = health

        return health
    }

    /// Get provider health status
    public func health(for providerId: String) -> ProviderHealth? {
        providerHealth[providerId]
    }

    // MARK: - Chat Helpers

    /// Send a chat request using the best available provider
    public func chat(
        messages: [ChatMessage],
        model: String? = nil,
        options: ChatOptions = .default
    ) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        // Find provider and model
        let (provider, _) = try resolveProviderAndModel(modelId: model)

        let modelId = model ?? TheaConfig.shared.ai.defaultModel

        // Log action
        EventBus.shared.logAction(
            .modelQuery,
            target: modelId,
            parameters: ["provider": provider.id],
            success: true
        )

        return try await provider.chat(
            messages: messages,
            model: modelId,
            options: options
        )
    }

    /// Send a sync chat request
    public func chatSync(
        messages: [ChatMessage],
        model: String? = nil,
        options: ChatOptions = .default
    ) async throws -> ChatResponse {
        let (provider, _) = try resolveProviderAndModel(modelId: model)
        let modelId = model ?? TheaConfig.shared.ai.defaultModel

        return try await provider.chatSync(
            messages: messages,
            model: modelId,
            options: options
        )
    }

    // MARK: - Resolution

    private func resolveProviderAndModel(modelId: String?) throws -> (any AIProvider, AIModel) {
        let targetModelId = modelId ?? TheaConfig.shared.ai.defaultModel

        // First try to find model across providers
        if let found = findModel(targetModelId) {
            guard found.provider.isConfigured else {
                throw ProviderError.notConfigured(provider: found.provider.name)
            }
            return found
        }

        // Try default provider
        if let provider = defaultProvider, provider.isConfigured {
            if let model = provider.supportedModels.first {
                return (provider, model)
            }
        }

        // Try any configured provider
        if let provider = configuredProviders.first,
           let model = provider.supportedModels.first {
            return (provider, model)
        }

        throw ProviderError.notConfigured(provider: "No providers configured")
    }

    // MARK: - Statistics

    public struct RegistryStatistics: Sendable {
        public let totalProviders: Int
        public let configuredProviders: Int
        public let healthyProviders: Int
        public let totalModels: Int
    }

    public func getStatistics() -> RegistryStatistics {
        let healthy = providerHealth.values.filter(\.isHealthy).count

        return RegistryStatistics(
            totalProviders: providers.count,
            configuredProviders: configuredProviders.count,
            healthyProviders: healthy,
            totalModels: allModels.count
        )
    }
}

// MARK: - Provider Registration Extension

public extension ProviderRegistry {
    /// Register all built-in providers
    func registerBuiltInProviders(keychain: KeychainAccess) {
        // This will be called during app initialization
        // Each provider checks keychain for its API key
        logger.info("Provider registration will occur during app startup")
    }
}

// MARK: - V1 Compatibility

public extension ProviderRegistry {
    /// V1 compatibility method
    func getProvider(id: String) -> (any AIProvider)? {
        provider(id: id)
    }

    /// V1 compatibility - all registered providers
    var availableProviders: [any AIProvider] {
        Array(providers.values)
    }
}

// MARK: - Keychain Access Protocol

/// Protocol for accessing stored API keys
public protocol KeychainAccess: Sendable {
    func get(_ key: String) -> String?
    func set(_ value: String, for key: String) throws
    func delete(_ key: String) throws
}
