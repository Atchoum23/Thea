//
//  ProviderRegistryProtocol.swift
//  Thea
//
//  Protocol abstraction for ProviderRegistry, enabling testability
//  and dependency injection across 74+ call sites.
//

import Foundation

// MARK: - Provider Registry Protocol

/// Abstracts the ProviderRegistry singleton for testability and dependency injection.
///
/// This protocol captures the public query API of ProviderRegistry — the methods
/// called by ChatManager, AutonomousAgent, MemoryRetrieval, TaskClassifier, and
/// UI views to discover, resolve, and access AI providers.
///
/// **What this enables:**
/// - Unit tests can inject a mock registry with deterministic provider responses
/// - Feature flags can swap between real and stub registries
/// - New provider sources (e.g., remote model catalogs) can conform without
///   modifying existing consumers
@MainActor
protocol ProviderRegistryProtocol: AnyObject {

// periphery:ignore - Reserved: ProviderRegistryProtocol protocol reserved for future feature activation

    // MARK: - Discovery

    /// All known providers (cloud + local), keyed by provider ID
    var allProviders: [String: AIProvider] { get }

    /// Info about all registered providers (configured or not)
    var availableProviders: [ProviderRegistry.ProviderInfo] { get }

    /// Only providers with valid API keys / active local models
    var configuredProviders: [AIProvider] { get }

    /// Whether any local models are loaded
    var hasLocalModels: Bool { get }

    /// Names of available local models
    func getAvailableLocalModels() -> [String]

    // MARK: - Resolution

    /// Resolve a provider by its canonical ID (e.g., "openai", "anthropic")
    func getProvider(id: String) -> AIProvider?

    /// Resolve which provider serves a given model ID (e.g., "gpt-4o" -> OpenAI)
    func getProvider(for modelId: String) -> AIProvider?

    /// Get the user's preferred default provider (respects orchestrator config)
    func getDefaultProvider() -> AIProvider?

    /// Get a cloud-based provider (for tasks that cannot use local models)
    func getCloudProvider() -> AIProvider?

    /// Get a local model provider, optionally by name
    func getLocalProvider(modelName: String?) -> AIProvider?

    /// Route to optimal provider based on task complexity
    func getProviderForTask(complexity: QueryComplexity) -> AIProvider?

    // MARK: - Creation

    /// Create a fresh provider instance for the given ID
    func createProvider(id: String) -> AIProvider?

    // MARK: - Registration

    /// Register an external provider at runtime (plugin support)
    func registerProvider(_ provider: AIProvider, id: String)

    // MARK: - Refresh

    /// Re-scan for local models (macOS: MLX, iOS: CoreML)
    func refreshLocalProviders() async

    /// Re-scan for CoreML models (iOS)
    func refreshCoreMLProviders() async
}

// MARK: - Default Implementation (for optional methods)

// periphery:ignore - Reserved: ProviderRegistryProtocol protocol extension reserved for future feature activation
extension ProviderRegistryProtocol {
    func getLocalProvider(modelName: String? = nil) -> AIProvider? {
        getLocalProvider(modelName: modelName)
    }
}
