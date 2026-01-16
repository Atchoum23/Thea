import XCTest

@testable import TheaCoreCore

final class AnthropicProviderTests: XCTestCase {
  var provider: AnthropicProvider!

  override func setUp() {
    provider = AnthropicProvider(apiKey: "test-key")
  }

  override func tearDown() {
    provider = nil
  }

  func testProviderMetadata() {
    XCTAssertEqual(provider.metadata.name, "anthropic")
    XCTAssertEqual(provider.metadata.displayName, "Anthropic (Claude)")
    XCTAssertEqual(provider.metadata.websiteURL.absoluteString, "https://anthropic.com")
  }

  func testProviderCapabilities() {
    let capabilities = provider.capabilities

    XCTAssertTrue(capabilities.supportsStreaming)
    XCTAssertTrue(capabilities.supportsVision)
    XCTAssertTrue(capabilities.supportsFunctionCalling)
    XCTAssertEqual(capabilities.maxContextTokens, 200000)
    XCTAssertEqual(capabilities.maxOutputTokens, 8192)
  }

  func testListModels() async throws {
    let models = try await provider.listModels()

    XCTAssertFalse(models.isEmpty)
    XCTAssertTrue(models.contains { $0.id == "claude-opus-4-20250514" })
    XCTAssertTrue(models.contains { $0.id == "claude-3-5-sonnet-20241022" })
    XCTAssertTrue(models.contains { $0.id == "claude-3-5-haiku-20241022" })
  }

  func testClaudeOpusPricing() async throws {
    let models = try await provider.listModels()
    let opus = models.first { $0.id == "claude-opus-4-20250514" }

    XCTAssertNotNil(opus)
    XCTAssertEqual(opus?.inputPricePerMillion, 15.00)
    XCTAssertEqual(opus?.outputPricePerMillion, 75.00)
  }

  func testContextWindow() async throws {
    let models = try await provider.listModels()

    for model in models {
      XCTAssertEqual(model.contextWindow, 200000, "All Claude models should have 200K context")
    }
  }
}
