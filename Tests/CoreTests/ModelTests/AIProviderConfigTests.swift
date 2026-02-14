@testable import TheaModels
import XCTest

/// Tests for AIProviderConfig — provider enable/disable, API key validation,
/// plugin versioning, and configuration integrity.
final class AIProviderConfigTests: XCTestCase {

    // MARK: - Creation

    func testDefaultCreation() {
        let config = AIProviderConfig(providerName: "openai", displayName: "OpenAI")
        XCTAssertEqual(config.providerName, "openai")
        XCTAssertEqual(config.displayName, "OpenAI")
        XCTAssertTrue(config.isEnabled, "Should be enabled by default")
        XCTAssertFalse(config.hasValidAPIKey, "Should not have valid key by default")
        XCTAssertNil(config.pluginVersion)
    }

    func testCustomCreation() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let config = AIProviderConfig(
            providerName: "anthropic",
            displayName: "Anthropic",
            isEnabled: false,
            hasValidAPIKey: true,
            installedAt: date,
            pluginVersion: "2.1.0"
        )
        XCTAssertEqual(config.providerName, "anthropic")
        XCTAssertFalse(config.isEnabled)
        XCTAssertTrue(config.hasValidAPIKey)
        XCTAssertEqual(config.installedAt, date)
        XCTAssertEqual(config.pluginVersion, "2.1.0")
    }

    // MARK: - Enable/Disable

    func testProviderEnablement() {
        let config = AIProviderConfig(providerName: "google", displayName: "Google")
        XCTAssertTrue(config.isEnabled)
        config.isEnabled = false
        XCTAssertFalse(config.isEnabled)
        config.isEnabled = true
        XCTAssertTrue(config.isEnabled)
    }

    // MARK: - API Key Validation States

    func testAPIKeyValidation() {
        let config = AIProviderConfig(providerName: "openai", displayName: "OpenAI")
        XCTAssertFalse(config.hasValidAPIKey)
        config.hasValidAPIKey = true
        XCTAssertTrue(config.hasValidAPIKey)
    }

    func testDisabledProviderCanHaveValidKey() {
        let config = AIProviderConfig(
            providerName: "deepseek",
            displayName: "DeepSeek",
            isEnabled: false,
            hasValidAPIKey: true
        )
        XCTAssertFalse(config.isEnabled)
        XCTAssertTrue(config.hasValidAPIKey, "Disabled provider can still have a valid key")
    }

    // MARK: - Plugin Version

    func testPluginVersionTracking() {
        let config = AIProviderConfig(providerName: "local", displayName: "Local Model")
        XCTAssertNil(config.pluginVersion)
        config.pluginVersion = "1.0.0"
        XCTAssertEqual(config.pluginVersion, "1.0.0")
        config.pluginVersion = "1.1.0"
        XCTAssertEqual(config.pluginVersion, "1.1.0")
    }

    // MARK: - Identifiable

    func testUniqueIDs() {
        let config1 = AIProviderConfig(providerName: "a", displayName: "A")
        let config2 = AIProviderConfig(providerName: "b", displayName: "B")
        XCTAssertNotEqual(config1.id, config2.id)
    }

    func testCustomID() {
        let id = UUID()
        let config = AIProviderConfig(id: id, providerName: "test", displayName: "Test")
        XCTAssertEqual(config.id, id)
    }

    // MARK: - Provider Name Patterns

    func testCommonProviderNames() {
        let providers = [
            ("anthropic", "Anthropic"),
            ("openai", "OpenAI"),
            ("google", "Google"),
            ("openrouter", "OpenRouter"),
            ("local", "Local"),
            ("groq", "Groq"),
            ("perplexity", "Perplexity"),
            ("deepseek", "DeepSeek")
        ]
        for (name, display) in providers {
            let config = AIProviderConfig(providerName: name, displayName: display)
            XCTAssertFalse(config.providerName.isEmpty)
            XCTAssertFalse(config.displayName.isEmpty)
        }
    }

    func testEmptyNameAllowed() {
        let config = AIProviderConfig(providerName: "", displayName: "")
        XCTAssertEqual(config.providerName, "")
        XCTAssertEqual(config.displayName, "")
    }
}
