import Foundation
import XCTest

/// Standalone tests for TheaConfig configuration section types.
/// Tests defaults, Codable round-trips, and getValue/setValue behaviors
/// mirroring the types in TheaConfig.swift.
final class ConfigurationTypesTests: XCTestCase {

    // MARK: - AIConfiguration Mirror

    struct TestAIConfig: Codable, Equatable {
        var defaultProvider: String = "openrouter"
        var defaultModel: String = "anthropic/claude-sonnet-4"
        var temperature: Double = 0.7
        var maxTokens: Int = 8192
        var streamingEnabled: Bool = true
        var enableTaskClassification: Bool = true
        var enableModelRouting: Bool = true
        var learningRate: Double = 0.1
        var feedbackDecayFactor: Double = 0.95

        func getValue(_ key: String) -> Any? {
            switch key {
            case "defaultProvider": return defaultProvider
            case "defaultModel": return defaultModel
            case "temperature": return temperature
            case "maxTokens": return maxTokens
            case "streamingEnabled": return streamingEnabled
            case "enableTaskClassification": return enableTaskClassification
            case "enableModelRouting": return enableModelRouting
            case "learningRate": return learningRate
            case "feedbackDecayFactor": return feedbackDecayFactor
            default: return nil
            }
        }

        mutating func setValue(_ value: Any, forKey key: String) -> Bool {
            switch key {
            case "defaultProvider":
                if let val = value as? String { defaultProvider = val; return true }
            case "defaultModel":
                if let val = value as? String { defaultModel = val; return true }
            case "temperature":
                if let val = value as? Double { temperature = val; return true }
            case "maxTokens":
                if let val = value as? Int { maxTokens = val; return true }
            case "streamingEnabled":
                if let val = value as? Bool { streamingEnabled = val; return true }
            case "learningRate":
                if let val = value as? Double { learningRate = val; return true }
            default:
                break
            }
            return false
        }
    }

    func testAIConfigDefaults() {
        let config = TestAIConfig()
        XCTAssertEqual(config.defaultProvider, "openrouter")
        XCTAssertEqual(config.defaultModel, "anthropic/claude-sonnet-4")
        XCTAssertEqual(config.temperature, 0.7, accuracy: 0.001)
        XCTAssertEqual(config.maxTokens, 8192)
        XCTAssertTrue(config.streamingEnabled)
        XCTAssertTrue(config.enableTaskClassification)
        XCTAssertTrue(config.enableModelRouting)
        XCTAssertEqual(config.learningRate, 0.1, accuracy: 0.001)
        XCTAssertEqual(config.feedbackDecayFactor, 0.95, accuracy: 0.001)
    }

    func testAIConfigCodable() throws {
        var config = TestAIConfig()
        config.defaultProvider = "anthropic"
        config.temperature = 0.9
        config.maxTokens = 4096

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestAIConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testAIConfigGetValue() {
        let config = TestAIConfig()
        XCTAssertEqual(config.getValue("defaultProvider") as? String, "openrouter")
        XCTAssertEqual(config.getValue("temperature") as? Double, 0.7)
        XCTAssertEqual(config.getValue("maxTokens") as? Int, 8192)
        XCTAssertNil(config.getValue("nonexistentKey"))
    }

    func testAIConfigSetValue() {
        var config = TestAIConfig()
        XCTAssertTrue(config.setValue("anthropic", forKey: "defaultProvider"))
        XCTAssertEqual(config.defaultProvider, "anthropic")

        XCTAssertTrue(config.setValue(0.9, forKey: "temperature"))
        XCTAssertEqual(config.temperature, 0.9, accuracy: 0.001)

        XCTAssertTrue(config.setValue(16384, forKey: "maxTokens"))
        XCTAssertEqual(config.maxTokens, 16384)
    }

    func testAIConfigSetValueTypeMismatch() {
        var config = TestAIConfig()
        XCTAssertFalse(config.setValue("not a number", forKey: "temperature"))
        XCTAssertEqual(config.temperature, 0.7, accuracy: 0.001, "Should not change on type mismatch")

        XCTAssertFalse(config.setValue(42, forKey: "defaultProvider"))
        XCTAssertEqual(config.defaultProvider, "openrouter", "Should not change on type mismatch")
    }

    func testAIConfigSetValueInvalidKey() {
        var config = TestAIConfig()
        XCTAssertFalse(config.setValue("test", forKey: "nonexistentKey"))
    }

    // MARK: - MemoryConfiguration Mirror

    struct TestMemoryConfig: Codable, Equatable {
        var workingCapacity: Int = 100
        var episodicCapacity: Int = 10000
        var semanticCapacity: Int = 50000
        var proceduralCapacity: Int = 1000
        var consolidationInterval: TimeInterval = 3600
        var decayRate: Double = 0.99
        var enableActiveRetrieval: Bool = true
        var enableContextInjection: Bool = true
        var retrievalLimit: Int = 10
        var similarityThreshold: Double = 0.3
    }

    func testMemoryConfigDefaults() {
        let config = TestMemoryConfig()
        XCTAssertEqual(config.workingCapacity, 100)
        XCTAssertEqual(config.episodicCapacity, 10000)
        XCTAssertEqual(config.semanticCapacity, 50000)
        XCTAssertEqual(config.proceduralCapacity, 1000)
        XCTAssertEqual(config.consolidationInterval, 3600, accuracy: 0.1)
        XCTAssertEqual(config.decayRate, 0.99, accuracy: 0.001)
        XCTAssertTrue(config.enableActiveRetrieval)
        XCTAssertTrue(config.enableContextInjection)
        XCTAssertEqual(config.retrievalLimit, 10)
        XCTAssertEqual(config.similarityThreshold, 0.3, accuracy: 0.001)
    }

    func testMemoryConfigCodable() throws {
        var config = TestMemoryConfig()
        config.workingCapacity = 200
        config.decayRate = 0.95
        config.retrievalLimit = 20

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestMemoryConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    // MARK: - VerificationConfiguration Mirror

    struct TestVerificationConfig: Codable, Equatable {
        var enableMultiModel: Bool = true
        var enableWebSearch: Bool = true
        var enableCodeExecution: Bool = true
        var enableStaticAnalysis: Bool = true
        var enableFeedbackLearning: Bool = true
        var highConfidenceThreshold: Double = 0.85
        var mediumConfidenceThreshold: Double = 0.60
        var lowConfidenceThreshold: Double = 0.30
        var consensusWeight: Double = 0.30
        var webSearchWeight: Double = 0.25
        var codeExecutionWeight: Double = 0.25
        var staticAnalysisWeight: Double = 0.10
        var feedbackWeight: Double = 0.10
    }

    func testVerificationConfigDefaults() {
        let config = TestVerificationConfig()
        XCTAssertTrue(config.enableMultiModel)
        XCTAssertTrue(config.enableWebSearch)
        XCTAssertEqual(config.highConfidenceThreshold, 0.85, accuracy: 0.001)
        XCTAssertEqual(config.mediumConfidenceThreshold, 0.60, accuracy: 0.001)
        XCTAssertEqual(config.lowConfidenceThreshold, 0.30, accuracy: 0.001)
    }

    func testVerificationWeightsSum() {
        let config = TestVerificationConfig()
        let totalWeight = config.consensusWeight + config.webSearchWeight +
            config.codeExecutionWeight + config.staticAnalysisWeight + config.feedbackWeight
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.001, "Verification weights should sum to 1.0")
    }

    func testVerificationThresholdOrdering() {
        let config = TestVerificationConfig()
        XCTAssertGreaterThan(config.highConfidenceThreshold, config.mediumConfidenceThreshold)
        XCTAssertGreaterThan(config.mediumConfidenceThreshold, config.lowConfidenceThreshold)
        XCTAssertGreaterThan(config.lowConfidenceThreshold, 0)
    }

    func testVerificationConfigCodable() throws {
        var config = TestVerificationConfig()
        config.enableMultiModel = false
        config.highConfidenceThreshold = 0.90

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestVerificationConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    // MARK: - ProvidersConfiguration Mirror

    struct TestProvidersConfig: Codable, Equatable {
        var anthropicBaseURL: String = "https://api.anthropic.com/v1"
        var openaiBaseURL: String = "https://api.openai.com/v1"
        var openrouterBaseURL: String = "https://openrouter.ai/api/v1"
        var ollamaBaseURL: String = "http://localhost:11434"
        var timeout: TimeInterval = 60.0
        var maxRetries: Int = 3
        var retryDelay: TimeInterval = 1.0
    }

    func testProvidersConfigDefaults() {
        let config = TestProvidersConfig()
        XCTAssertTrue(config.anthropicBaseURL.hasPrefix("https://"))
        XCTAssertTrue(config.openaiBaseURL.hasPrefix("https://"))
        XCTAssertTrue(config.openrouterBaseURL.hasPrefix("https://"))
        XCTAssertTrue(config.ollamaBaseURL.hasPrefix("http://localhost"))
        XCTAssertEqual(config.timeout, 60.0, accuracy: 0.1)
        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.retryDelay, 1.0, accuracy: 0.1)
    }

    func testProvidersConfigCodable() throws {
        var config = TestProvidersConfig()
        config.timeout = 120.0
        config.maxRetries = 5

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestProvidersConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testProvidersBaseURLsAreValid() {
        let config = TestProvidersConfig()
        let urls = [
            config.anthropicBaseURL, config.openaiBaseURL,
            config.openrouterBaseURL, config.ollamaBaseURL
        ]
        for urlString in urls {
            XCTAssertNotNil(URL(string: urlString), "\(urlString) should be valid URL")
        }
    }

    // MARK: - SecurityConfiguration Mirror

    struct TestSecurityConfig: Codable, Equatable {
        var requireApprovalForFiles: Bool = true
        var requireApprovalForTerminal: Bool = true
        var requireApprovalForNetwork: Bool = false
        var blockedCommands: [String] = ["rm -rf /", "sudo rm", "mkfs", "dd if="]
        var allowedDomains: [String] = []
        var maxFileSize: Int = 100_000_000
        var enableSandbox: Bool = true
        var logSensitiveOperations: Bool = true
    }

    func testSecurityConfigDefaults() {
        let config = TestSecurityConfig()
        XCTAssertTrue(config.requireApprovalForFiles)
        XCTAssertTrue(config.requireApprovalForTerminal)
        XCTAssertFalse(config.requireApprovalForNetwork)
        XCTAssertTrue(config.enableSandbox)
        XCTAssertTrue(config.logSensitiveOperations)
        XCTAssertEqual(config.maxFileSize, 100_000_000)
    }

    func testSecurityBlockedCommandsContainDangerous() {
        let config = TestSecurityConfig()
        XCTAssertTrue(config.blockedCommands.contains("rm -rf /"))
        XCTAssertTrue(config.blockedCommands.contains("sudo rm"))
        XCTAssertTrue(config.blockedCommands.contains("mkfs"))
        XCTAssertTrue(config.blockedCommands.contains("dd if="))
        XCTAssertGreaterThanOrEqual(config.blockedCommands.count, 4)
    }

    func testSecurityConfigCodable() throws {
        var config = TestSecurityConfig()
        config.blockedCommands.append("format")
        config.allowedDomains = ["api.example.com"]

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestSecurityConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testSecurityAllowedDomainsDefaultEmpty() {
        let config = TestSecurityConfig()
        XCTAssertTrue(config.allowedDomains.isEmpty, "Should default to empty for restrictive security")
    }

    // MARK: - TrackingConfiguration Mirror

    struct TestTrackingConfig: Codable, Equatable {
        var enableLocation: Bool = false
        var enableHealth: Bool = false
        var enableUsage: Bool = false
        var enableBrowser: Bool = false
        var enableInput: Bool = false
        var localOnly: Bool = true
        var enableCloudSync: Bool = false
        var retentionDays: Int = 365
    }

    func testTrackingConfigPrivacyDefaults() {
        let config = TestTrackingConfig()
        XCTAssertFalse(config.enableLocation, "Location should default off for privacy")
        XCTAssertFalse(config.enableHealth, "Health should default off for privacy")
        XCTAssertFalse(config.enableUsage, "Usage should default off for privacy")
        XCTAssertFalse(config.enableBrowser, "Browser should default off for privacy")
        XCTAssertFalse(config.enableInput, "Input should default off for privacy")
        XCTAssertTrue(config.localOnly, "Should default to local-only for privacy")
        XCTAssertFalse(config.enableCloudSync, "Cloud sync should default off for privacy")
    }

    func testTrackingRetentionDays() {
        let config = TestTrackingConfig()
        XCTAssertEqual(config.retentionDays, 365)
        XCTAssertGreaterThan(config.retentionDays, 0)
    }

    func testTrackingConfigCodable() throws {
        var config = TestTrackingConfig()
        config.enableHealth = true
        config.retentionDays = 90

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestTrackingConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    // MARK: - UIConfiguration Mirror

    struct TestUIConfig: Codable, Equatable {
        var theme: String = "system"
        var accentColor: String = "blue"
        var fontSize: Double = 14.0
        var showConfidenceIndicators: Bool = true
        var showMemoryContext: Bool = true
        var enableAnimations: Bool = true
        var compactMode: Bool = false
        var sidebarWidth: Double = 250.0
        var messageSpacing: Double = 12.0
    }

    func testUIConfigDefaults() {
        let config = TestUIConfig()
        XCTAssertEqual(config.theme, "system")
        XCTAssertEqual(config.accentColor, "blue")
        XCTAssertEqual(config.fontSize, 14.0, accuracy: 0.1)
        XCTAssertTrue(config.showConfidenceIndicators)
        XCTAssertTrue(config.enableAnimations)
        XCTAssertFalse(config.compactMode)
    }

    func testUIConfigCodable() throws {
        var config = TestUIConfig()
        config.theme = "dark"
        config.fontSize = 16.0
        config.compactMode = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestUIConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testUIConfigFontSizeReasonable() {
        let config = TestUIConfig()
        XCTAssertGreaterThanOrEqual(config.fontSize, 8.0, "Font too small")
        XCTAssertLessThanOrEqual(config.fontSize, 72.0, "Font too large")
    }

    func testUIConfigSidebarWidthReasonable() {
        let config = TestUIConfig()
        XCTAssertGreaterThanOrEqual(config.sidebarWidth, 100.0, "Sidebar too narrow")
        XCTAssertLessThanOrEqual(config.sidebarWidth, 600.0, "Sidebar too wide")
    }

    // MARK: - ConfigSnapshot Mirror

    struct TestConfigSnapshot: Codable, Equatable {
        let ai: TestAIConfig
        let memory: TestMemoryConfig
        let verification: TestVerificationConfig
        let providers: TestProvidersConfig
        let ui: TestUIConfig
        let tracking: TestTrackingConfig
        let security: TestSecurityConfig
    }

    func testFullSnapshotCodable() throws {
        let snapshot = TestConfigSnapshot(
            ai: TestAIConfig(),
            memory: TestMemoryConfig(),
            verification: TestVerificationConfig(),
            providers: TestProvidersConfig(),
            ui: TestUIConfig(),
            tracking: TestTrackingConfig(),
            security: TestSecurityConfig()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(snapshot)
        let decoded = try JSONDecoder().decode(TestConfigSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    func testSnapshotJSONIsReadable() throws {
        let snapshot = TestConfigSnapshot(
            ai: TestAIConfig(),
            memory: TestMemoryConfig(),
            verification: TestVerificationConfig(),
            providers: TestProvidersConfig(),
            ui: TestUIConfig(),
            tracking: TestTrackingConfig(),
            security: TestSecurityConfig()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        let json = String(data: data, encoding: .utf8)
        XCTAssertNotNil(json)
        XCTAssertTrue(json?.contains("defaultProvider") ?? false)
        XCTAssertTrue(json?.contains("openrouter") ?? false)
    }

    func testSnapshotWithModifiedValues() throws {
        var ai = TestAIConfig()
        ai.temperature = 0.0
        ai.maxTokens = 100

        var security = TestSecurityConfig()
        security.blockedCommands = []

        let snapshot = TestConfigSnapshot(
            ai: ai,
            memory: TestMemoryConfig(),
            verification: TestVerificationConfig(),
            providers: TestProvidersConfig(),
            ui: TestUIConfig(),
            tracking: TestTrackingConfig(),
            security: security
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(TestConfigSnapshot.self, from: data)
        XCTAssertEqual(decoded.ai.temperature, 0.0, accuracy: 0.001)
        XCTAssertEqual(decoded.ai.maxTokens, 100)
        XCTAssertTrue(decoded.security.blockedCommands.isEmpty)
    }

    // MARK: - Cross-Section Validation

    func testSecurityDefaultsAreRestrictive() {
        let security = TestSecurityConfig()
        let tracking = TestTrackingConfig()

        // Security should require approvals by default
        XCTAssertTrue(security.requireApprovalForFiles)
        XCTAssertTrue(security.requireApprovalForTerminal)
        XCTAssertTrue(security.enableSandbox)

        // Tracking should be off by default
        XCTAssertFalse(tracking.enableLocation)
        XCTAssertFalse(tracking.enableHealth)
        XCTAssertTrue(tracking.localOnly)
    }
}
