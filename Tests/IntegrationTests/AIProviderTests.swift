@testable import TheaCore
import XCTest

/// Tests for AI provider implementations — metadata, capabilities, model listing, error handling
@MainActor
final class AIProviderTests: XCTestCase {

    // MARK: - Provider Instantiation Tests

    func testAnthropicProviderCreation() {
        let provider = AnthropicProvider(apiKey: "test-key")
        XCTAssertEqual(provider.metadata.name, "anthropic")
        XCTAssertEqual(provider.metadata.displayName, "Anthropic (Claude)")
    }

    func testOpenAIProviderCreation() {
        let provider = OpenAIProvider(apiKey: "test-key")
        XCTAssertEqual(provider.metadata.name, "openai")
    }

    func testGoogleProviderCreation() {
        let provider = GoogleProvider(apiKey: "test-key")
        XCTAssertEqual(provider.metadata.name, "google")
    }

    func testPerplexityProviderCreation() {
        let provider = PerplexityProvider(apiKey: "test-key")
        XCTAssertEqual(provider.metadata.name, "perplexity")
    }

    func testOpenRouterProviderCreation() {
        let provider = OpenRouterProvider(apiKey: "test-key")
        XCTAssertEqual(provider.metadata.name, "openrouter")
    }

    func testGroqProviderCreation() {
        let provider = GroqProvider(apiKey: "test-key")
        XCTAssertEqual(provider.metadata.name, "groq")
    }

    // MARK: - Capabilities Tests

    func testAllProvidersSupportStreaming() {
        let providers: [AIProvider] = [
            OpenAIProvider(apiKey: "test"),
            AnthropicProvider(apiKey: "test"),
            GoogleProvider(apiKey: "test"),
            PerplexityProvider(apiKey: "test"),
            OpenRouterProvider(apiKey: "test"),
            GroqProvider(apiKey: "test")
        ]
        for provider in providers {
            XCTAssertTrue(provider.capabilities.supportsStreaming, "\(provider.metadata.name) should support streaming")
        }
    }

    func testAnthropicSupportsVision() {
        let provider = AnthropicProvider(apiKey: "test")
        XCTAssertTrue(provider.capabilities.supportsVision)
    }

    func testAnthropicSupportsFunctionCalling() {
        let provider = AnthropicProvider(apiKey: "test")
        XCTAssertTrue(provider.capabilities.supportsFunctionCalling)
    }

    func testPerplexitySupportsWebSearch() {
        let provider = PerplexityProvider(apiKey: "test")
        XCTAssertTrue(provider.capabilities.supportsWebSearch)
    }

    func testGoogleHasLargestContextWindow() {
        let google = GoogleProvider(apiKey: "test")
        let anthropic = AnthropicProvider(apiKey: "test")
        XCTAssertGreaterThan(google.capabilities.maxContextTokens, anthropic.capabilities.maxContextTokens)
    }

    // MARK: - Metadata Tests

    func testAllProvidersHaveValidMetadata() {
        let providers: [AIProvider] = [
            OpenAIProvider(apiKey: "test"),
            AnthropicProvider(apiKey: "test"),
            GoogleProvider(apiKey: "test"),
            PerplexityProvider(apiKey: "test"),
            OpenRouterProvider(apiKey: "test"),
            GroqProvider(apiKey: "test")
        ]
        for provider in providers {
            XCTAssertFalse(provider.metadata.name.isEmpty, "\(provider.metadata.name)")
            XCTAssertFalse(provider.metadata.displayName.isEmpty, "\(provider.metadata.name)")
            XCTAssertNotNil(provider.metadata.websiteURL)
            XCTAssertNotNil(provider.metadata.documentationURL)
        }
    }

    func testProviderNamesAreUnique() {
        let providers: [AIProvider] = [
            OpenAIProvider(apiKey: "test"),
            AnthropicProvider(apiKey: "test"),
            GoogleProvider(apiKey: "test"),
            PerplexityProvider(apiKey: "test"),
            OpenRouterProvider(apiKey: "test"),
            GroqProvider(apiKey: "test")
        ]
        let names = providers.map(\.metadata.name)
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "All provider names should be unique")
    }

    // MARK: - Model Listing Tests

    func testAnthropicListModels() async throws {
        let provider = AnthropicProvider(apiKey: "test")
        let models = try await provider.listModels()
        XCTAssertFalse(models.isEmpty)
        XCTAssertTrue(models.contains { $0.id.contains("claude") })
    }

    func testAnthropicModelPricing() async throws {
        let provider = AnthropicProvider(apiKey: "test")
        let models = try await provider.listModels()
        for model in models {
            XCTAssertGreaterThan(model.inputPricePerMillion, 0, "Model \(model.id) should have pricing")
            XCTAssertGreaterThan(model.outputPricePerMillion, 0, "Model \(model.id) should have pricing")
        }
    }

    func testAnthropicContextWindows() async throws {
        let provider = AnthropicProvider(apiKey: "test")
        let models = try await provider.listModels()
        for model in models {
            XCTAssertEqual(model.contextWindow, 200_000, "All Anthropic models should have 200K context")
        }
    }

    func testGroqListModels() async throws {
        let provider = GroqProvider(apiKey: "test")
        let models = try await provider.listModels()
        XCTAssertFalse(models.isEmpty)
    }

    func testGoogleListModels() async throws {
        let provider = GoogleProvider(apiKey: "test")
        let models = try await provider.listModels()
        XCTAssertFalse(models.isEmpty)
        XCTAssertTrue(models.contains { $0.id.contains("gemini") })
    }

    // MARK: - Error Type Tests

    func testAnthropicErrorDescriptions() {
        let errors: [AnthropicError] = [
            .invalidResponse,
            .noResponse
        ]
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
}
