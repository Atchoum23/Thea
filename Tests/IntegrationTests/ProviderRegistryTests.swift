@testable import TheaCore
import XCTest

/// Tests for ProviderRegistry singleton, provider lookup, and routing logic
@MainActor
final class ProviderRegistryTests: XCTestCase {

    // MARK: - Singleton Tests

    func testProviderRegistrySingleton() {
        let registry = ProviderRegistry.shared
        XCTAssertNotNil(registry)
        XCTAssertTrue(registry === ProviderRegistry.shared)
    }

    // MARK: - Available Providers Tests

    func testAvailableProvidersContainsSixBuiltIn() {
        let registry = ProviderRegistry.shared
        // Should have at least 6 built-in providers (openai, anthropic, google, perplexity, openrouter, groq)
        XCTAssertGreaterThanOrEqual(registry.availableProviders.count, 6)
    }

    func testAvailableProviderIDs() {
        let registry = ProviderRegistry.shared
        let ids = Set(registry.availableProviders.map(\.id))
        XCTAssertTrue(ids.contains("openai"))
        XCTAssertTrue(ids.contains("anthropic"))
        XCTAssertTrue(ids.contains("google"))
        XCTAssertTrue(ids.contains("perplexity"))
        XCTAssertTrue(ids.contains("openrouter"))
        XCTAssertTrue(ids.contains("groq"))
    }

    func testAvailableProviderDisplayNames() {
        let registry = ProviderRegistry.shared
        for provider in registry.availableProviders {
            XCTAssertFalse(provider.displayName.isEmpty, "Provider \(provider.id) should have a display name")
        }
    }

    func testAllProvidersRequireAPIKey() {
        let registry = ProviderRegistry.shared
        for provider in registry.availableProviders {
            XCTAssertTrue(provider.requiresAPIKey, "Provider \(provider.id) should require API key")
        }
    }

    // MARK: - Provider Info Tests

    func testProviderInfoIdentifiable() {
        let registry = ProviderRegistry.shared
        let ids = registry.availableProviders.map(\.id)
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count, "All provider IDs should be unique")
    }

    // MARK: - Local Model Access Tests

    func testGetLocalProviderWithoutModels() {
        // Local models may or may not be loaded depending on environment
        // Just verify the method doesn't crash
        let registry = ProviderRegistry.shared
        _ = registry.getLocalProvider()
    }

    func testGetLocalProviderByName() {
        let registry = ProviderRegistry.shared
        // Should return nil for a non-existent model name
        let provider = registry.getLocalProvider(modelName: "nonexistent-model-xyz")
        XCTAssertNil(provider)
    }

    func testGetAvailableLocalModelsFormat() {
        let registry = ProviderRegistry.shared
        let models = registry.getAvailableLocalModels()
        // All model names should NOT have the "local:" prefix
        for model in models {
            XCTAssertFalse(model.hasPrefix("local:"), "Model name should not have 'local:' prefix: \(model)")
        }
    }

    // MARK: - Provider Lookup Tests

    func testGetProviderUnknownID() {
        let registry = ProviderRegistry.shared
        let provider = registry.getProvider(id: "nonexistent-provider")
        XCTAssertNil(provider)
    }

    func testGetProviderLocalPrefix() {
        let registry = ProviderRegistry.shared
        // Looking up "local:nonexistent" should return nil gracefully
        let provider = registry.getProvider(id: "local:nonexistent-model")
        XCTAssertNil(provider)
    }

    // MARK: - AllProviders Merge

    func testAllProvidersMergesCloudAndLocal() {
        let registry = ProviderRegistry.shared
        let allProviders = registry.allProviders
        // allProviders should contain at least the configured cloud providers
        let configuredCount = registry.configuredProviders.count
        XCTAssertGreaterThanOrEqual(allProviders.count, configuredCount)
    }
}
