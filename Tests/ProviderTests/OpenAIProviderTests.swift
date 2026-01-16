import XCTest

@testable import TheaCoreCore

final class OpenAIProviderTests: XCTestCase {
  var provider: OpenAIProvider!

  override func setUp() {
    provider = OpenAIProvider(apiKey: "test-key")
  }

  override func tearDown() {
    provider = nil
  }

  func testProviderMetadata() {
    XCTAssertEqual(provider.metadata.name, "openai")
    XCTAssertEqual(provider.metadata.displayName, "OpenAI")
    XCTAssertEqual(provider.metadata.websiteURL.absoluteString, "https://openai.com")
  }

  func testProviderCapabilities() {
    let capabilities = provider.capabilities

    XCTAssertTrue(capabilities.supportsStreaming)
    XCTAssertTrue(capabilities.supportsVision)
    XCTAssertTrue(capabilities.supportsFunctionCalling)
    XCTAssertFalse(capabilities.supportsWebSearch)
    XCTAssertEqual(capabilities.maxContextTokens, 128000)
    XCTAssertEqual(capabilities.maxOutputTokens, 16384)
  }

  func testListModels() async throws {
    let models = try await provider.listModels()

    XCTAssertFalse(models.isEmpty)
    XCTAssertTrue(models.contains { $0.id == "gpt-4o" })
    XCTAssertTrue(models.contains { $0.id == "gpt-4-turbo" })
    XCTAssertTrue(models.contains { $0.id == "o1" })
  }

  func testModelPricing() async throws {
    let models = try await provider.listModels()
    let gpt4o = models.first { $0.id == "gpt-4o" }

    XCTAssertNotNil(gpt4o)
    XCTAssertEqual(gpt4o?.inputPricePerMillion, 2.50)
    XCTAssertEqual(gpt4o?.outputPricePerMillion, 10.00)
  }

  func testModelCapabilities() async throws {
    let models = try await provider.listModels()
    let gpt4o = models.first { $0.id == "gpt-4o" }

    XCTAssertTrue(gpt4o?.supportsVision ?? false)
    XCTAssertTrue(gpt4o?.supportsFunctionCalling ?? false)
  }

  func testSupportedModalities() {
    let modalities = provider.capabilities.supportedModalities

    XCTAssertTrue(modalities.contains(.text))
    XCTAssertTrue(modalities.contains(.image))
  }
}
