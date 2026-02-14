import Foundation
import XCTest

/// Standalone tests for advanced configuration struct types (Part 2b of 3).
/// Covers: SystemPromptConfiguration, VerificationConfiguration, SecurityConfiguration.
/// See also ConfigurationTypesTests.swift (enums) and
/// ConfigurationStructTests.swift (PerformanceMetrics, QA, Conversation, Orchestrator).
final class ConfigurationAdvancedTests: XCTestCase {

    // =========================================================================
    // MARK: - 16. SystemPromptConfiguration (mirror SystemPromptConfiguration.swift)
    // =========================================================================

    enum TestTaskType: String, CaseIterable {
        case codeGeneration, debugging, mathLogic, creativeWriting
        case analysis, complexReasoning, summarization, planning
        case factual, simpleQA, conversation, unknown
    }

    struct TestSystemPromptConfig: Codable, Equatable {
        var basePrompt: String
        var taskPrompts: [String: String]
        var useDynamicPrompts: Bool

        static func defaults() -> TestSystemPromptConfig {
            TestSystemPromptConfig(
                basePrompt: "You are THEA, a helpful AI assistant.",
                taskPrompts: [
                    "codeGeneration": "CODE GENERATION GUIDELINES:\n- Write clean code",
                    "debugging": "DEBUGGING GUIDELINES:\n- Analyze the error",
                    "mathLogic": "MATHEMATICAL REASONING GUIDELINES:\n- Show your work",
                    "creativeWriting": "CREATIVE WRITING GUIDELINES:\n- Be imaginative",
                    "analysis": "ANALYSIS GUIDELINES:\n- Examine from multiple perspectives",
                    "complexReasoning": "COMPLEX REASONING GUIDELINES:\n- Break down the problem",
                    "summarization": "SUMMARIZATION GUIDELINES:\n- Identify key information",
                    "planning": "PLANNING GUIDELINES:\n- Break down goals",
                    "factual": "FACTUAL RESPONSE GUIDELINES:\n- Provide accurate info",
                    "simpleQA": "SIMPLE Q&A GUIDELINES:\n- Answer directly"
                ],
                useDynamicPrompts: true
            )
        }

        func prompt(for taskType: TestTaskType) -> String {
            taskPrompts[taskType.rawValue] ?? ""
        }

        mutating func setPrompt(_ prompt: String, for taskType: TestTaskType) {
            taskPrompts[taskType.rawValue] = prompt
        }

        func isCustomized(for taskType: TestTaskType) -> Bool {
            guard let current = taskPrompts[taskType.rawValue] else { return false }
            let defaultConfig = Self.defaults()
            guard let defaultPrompt = defaultConfig.taskPrompts[taskType.rawValue] else {
                return !current.isEmpty
            }
            return current != defaultPrompt
        }

        func fullPrompt(for taskType: TestTaskType?) -> String {
            guard useDynamicPrompts, let taskType = taskType else {
                return basePrompt
            }
            let taskSpecific = prompt(for: taskType)
            if taskSpecific.isEmpty { return basePrompt }
            return "\(basePrompt)\n\n\(taskSpecific)"
        }
    }

    func testSystemPromptConfigDefaults() {
        let config = TestSystemPromptConfig.defaults()
        XCTAssertFalse(config.basePrompt.isEmpty)
        XCTAssertTrue(config.basePrompt.contains("THEA"))
        XCTAssertTrue(config.useDynamicPrompts)
        XCTAssertGreaterThanOrEqual(config.taskPrompts.count, 10)
    }

    func testSystemPromptConfigPromptComposition() {
        let config = TestSystemPromptConfig.defaults()
        let full = config.fullPrompt(for: .codeGeneration)
        XCTAssertTrue(full.contains("THEA"))
        XCTAssertTrue(full.contains("CODE GENERATION"))
    }

    func testSystemPromptConfigNilTaskType() {
        let config = TestSystemPromptConfig.defaults()
        let prompt = config.fullPrompt(for: nil)
        XCTAssertEqual(prompt, config.basePrompt)
    }

    func testSystemPromptConfigDynamicPromptsDisabled() {
        var config = TestSystemPromptConfig.defaults()
        config.useDynamicPrompts = false
        let prompt = config.fullPrompt(for: .codeGeneration)
        XCTAssertEqual(prompt, config.basePrompt)
        XCTAssertFalse(prompt.contains("CODE GENERATION"))
    }

    func testSystemPromptConfigTaskSpecificPrompts() {
        let config = TestSystemPromptConfig.defaults()
        let taskTypes: [TestTaskType] = [
            .codeGeneration, .debugging, .mathLogic, .creativeWriting,
            .analysis, .complexReasoning, .summarization, .planning,
            .factual, .simpleQA
        ]
        for taskType in taskTypes {
            let prompt = config.prompt(for: taskType)
            XCTAssertFalse(prompt.isEmpty, "\(taskType) should have a task prompt")
        }
    }

    func testSystemPromptConfigUnknownTaskReturnsBaseOnly() {
        let config = TestSystemPromptConfig.defaults()
        let prompt = config.prompt(for: .unknown)
        XCTAssertTrue(prompt.isEmpty)
        let full = config.fullPrompt(for: .unknown)
        XCTAssertEqual(full, config.basePrompt)
    }

    func testSystemPromptConfigIsCustomized() {
        var config = TestSystemPromptConfig.defaults()
        XCTAssertFalse(config.isCustomized(for: .codeGeneration))
        config.setPrompt("Custom code prompt", for: .codeGeneration)
        XCTAssertTrue(config.isCustomized(for: .codeGeneration))
    }

    // =========================================================================
    // MARK: - 17. VerificationConfiguration (mirror TheaConfigSections.swift)
    // =========================================================================

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

        var allEnabled: Bool {
            enableMultiModel && enableWebSearch && enableCodeExecution &&
                enableStaticAnalysis && enableFeedbackLearning
        }
        var totalWeight: Double {
            consensusWeight + webSearchWeight + codeExecutionWeight +
                staticAnalysisWeight + feedbackWeight
        }
    }

    func testVerificationConfigDefaults() {
        let config = TestVerificationConfig()
        XCTAssertTrue(config.enableMultiModel)
        XCTAssertTrue(config.enableWebSearch)
        XCTAssertTrue(config.enableCodeExecution)
        XCTAssertTrue(config.enableStaticAnalysis)
        XCTAssertTrue(config.enableFeedbackLearning)
        XCTAssertTrue(config.allEnabled)
    }

    func testVerificationConfigThresholdOrdering() {
        let config = TestVerificationConfig()
        XCTAssertGreaterThan(config.highConfidenceThreshold, config.mediumConfidenceThreshold)
        XCTAssertGreaterThan(config.mediumConfidenceThreshold, config.lowConfidenceThreshold)
        XCTAssertGreaterThan(config.lowConfidenceThreshold, 0)
    }

    func testVerificationConfigWeightsSumToOne() {
        let config = TestVerificationConfig()
        XCTAssertEqual(config.totalWeight, 1.0, accuracy: 0.001)
    }

    func testVerificationConfigDisableFlags() {
        var config = TestVerificationConfig()
        config.enableMultiModel = false
        XCTAssertFalse(config.allEnabled)
        config.enableMultiModel = true
        config.enableCodeExecution = false
        XCTAssertFalse(config.allEnabled)
    }

    func testVerificationConfigCodableRoundTrip() throws {
        var config = TestVerificationConfig()
        config.enableMultiModel = false
        config.highConfidenceThreshold = 0.90
        config.consensusWeight = 0.40
        config.feedbackWeight = 0.00

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestVerificationConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    // =========================================================================
    // MARK: - 18. SecurityConfiguration (mirror TheaConfigSections.swift)
    // =========================================================================

    struct TestSecurityConfig: Codable, Equatable {
        var requireApprovalForFiles: Bool = true
        var requireApprovalForTerminal: Bool = true
        var requireApprovalForNetwork: Bool = false
        var blockedCommands: [String] = ["rm -rf /", "sudo rm", "mkfs", "dd if="]
        var allowedDomains: [String] = []
        var maxFileSize: Int = 100_000_000
        var enableSandbox: Bool = true
        var logSensitiveOperations: Bool = true

        func isCommandBlocked(_ command: String) -> Bool {
            blockedCommands.contains { command.contains($0) }
        }
        func isDomainAllowed(_ domain: String) -> Bool {
            guard !allowedDomains.isEmpty else { return true }
            return allowedDomains.contains(domain)
        }
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

    func testSecurityConfigBlockedCommands() {
        let config = TestSecurityConfig()
        XCTAssertTrue(config.blockedCommands.contains("rm -rf /"))
        XCTAssertTrue(config.blockedCommands.contains("sudo rm"))
        XCTAssertTrue(config.blockedCommands.contains("mkfs"))
        XCTAssertTrue(config.blockedCommands.contains("dd if="))
        XCTAssertGreaterThanOrEqual(config.blockedCommands.count, 4)
    }

    func testSecurityConfigIsCommandBlocked() {
        let config = TestSecurityConfig()
        XCTAssertTrue(config.isCommandBlocked("rm -rf /"))
        XCTAssertTrue(config.isCommandBlocked("sudo rm -rf /tmp"))
        XCTAssertTrue(config.isCommandBlocked("dd if=/dev/zero of=/dev/sda"))
        XCTAssertFalse(config.isCommandBlocked("ls -la"))
        XCTAssertFalse(config.isCommandBlocked("git status"))
    }

    func testSecurityConfigSandboxMode() {
        var config = TestSecurityConfig()
        XCTAssertTrue(config.enableSandbox)
        config.enableSandbox = false
        XCTAssertFalse(config.enableSandbox)
    }

    func testSecurityConfigAllowedDomains() {
        var config = TestSecurityConfig()
        XCTAssertTrue(config.isDomainAllowed("anything.com"))

        config.allowedDomains = ["api.anthropic.com", "api.openai.com"]
        XCTAssertTrue(config.isDomainAllowed("api.anthropic.com"))
        XCTAssertTrue(config.isDomainAllowed("api.openai.com"))
        XCTAssertFalse(config.isDomainAllowed("evil.com"))
    }

    func testSecurityConfigCodableRoundTrip() throws {
        var config = TestSecurityConfig()
        config.blockedCommands.append("format")
        config.allowedDomains = ["api.example.com"]
        config.maxFileSize = 50_000_000

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestSecurityConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }
}
