@testable import TheaCoreCore
import XCTest

final class AllProvidersTests: XCTestCase {
    func testAllProvidersHaveMetadata() {
        let providers: [AIProvider] = [
            OpenAIProvider(apiKey: "test"),
            AnthropicProvider(apiKey: "test"),
            GoogleProvider(apiKey: "test"),
            PerplexityProvider(apiKey: "test"),
            OpenRouterProvider(apiKey: "test"),
            GroqProvider(apiKey: "test")
        ]

        for provider in providers {
            XCTAssertFalse(provider.metadata.name.isEmpty)
            XCTAssertFalse(provider.metadata.displayName.isEmpty)
            XCTAssertNotNil(provider.metadata.websiteURL)
            XCTAssertNotNil(provider.metadata.documentationURL)
        }
    }

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

    func testAllProvidersHaveModels() async throws {
        let providers: [AIProvider] = [
            OpenAIProvider(apiKey: "test"),
            AnthropicProvider(apiKey: "test"),
            GoogleProvider(apiKey: "test"),
            PerplexityProvider(apiKey: "test"),
            GroqProvider(apiKey: "test")
        ]

        for provider in providers {
            let models = try await provider.listModels()
            XCTAssertFalse(models.isEmpty, "\(provider.metadata.name) should have models")
        }
    }

    func testPerplexitySupportsWebSearch() {
        let provider = PerplexityProvider(apiKey: "test")
        XCTAssertTrue(provider.capabilities.supportsWebSearch, "Perplexity should support web search")
    }

    func testGoogleHasLargestContext() {
        let google = GoogleProvider(apiKey: "test")
        XCTAssertEqual(google.capabilities.maxContextTokens, 1_000_000, "Google should have 1M context window")
    }

    func testAnthropicHasLargestContext() {
        let anthropic = AnthropicProvider(apiKey: "test")
        XCTAssertEqual(anthropic.capabilities.maxContextTokens, 200_000, "Anthropic should have 200K context")
    }
}
