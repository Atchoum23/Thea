import Foundation
import XCTest

/// Standalone tests for configuration struct types and their logic.
/// Creates local test doubles mirroring the real types in Shared/Core/Configuration/.
/// Pattern: same as TaskClassifierTypesTests.swift — no app module imports.
///
/// Part 2 of 2: Struct types (PerformanceMetrics, QAToolResult, QAIssue,
/// ConversationConfiguration, OrchestratorConfiguration, SystemPromptConfiguration,
/// VerificationConfiguration, SecurityConfiguration).
/// Part 1: ConfigurationTypesTests.swift (enum types).
final class ConfigurationStructTests: XCTestCase {

    // =========================================================================
    // MARK: - Shared Enum Doubles (needed by struct tests)
    // =========================================================================

    enum ContextStrategy: String, Codable, CaseIterable, Sendable {
        case unlimited = "Unlimited"
        case sliding = "Sliding Window"
        case summarize = "Smart Summarization"
        case hybrid = "Hybrid (Summarize + Recent)"
    }

    enum MetaAIPriority: String, Codable, CaseIterable, Sendable {
        case normal = "Normal"
        case high = "High"
        case maximum = "Maximum"
        var allocationPercentage: Double {
            switch self {
            case .normal: 0.5
            case .high: 0.7
            case .maximum: 0.9
            }
        }
    }

    enum TokenCountingMethod: String, Codable, Sendable {
        case estimate = "Estimate (Fast)"
        case accurate = "Accurate (Slower)"
    }

    enum LocalModelPreference: String, Codable, CaseIterable, Sendable {
        case always = "Always"
        case prefer = "Prefer"
        case balanced = "Balanced"
        case cloudFirst = "Cloud-First"
    }

    enum ExecutionStrategy: String, Codable, Sendable {
        case direct, decompose, deepAgent
    }

    enum QueryComplexity: String, Codable, Sendable {
        case simple, moderate, complex
    }

    enum QATool: String, Codable, Sendable, CaseIterable {
        case swiftLint = "SwiftLint"
        case codeCov = "CodeCov"
        case sonarCloud = "SonarCloud"
        case deepSource = "DeepSource"
    }

    enum QAIssueSeverity: String, Codable, Sendable {
        case error, warning, info, hint
    }

    // =========================================================================
    // MARK: - 11. PerformanceMetrics (mirror DynamicConfig.swift)
    // =========================================================================

    struct PerformanceMetrics {
        let averageResponseTime: Double
        let errorRate: Double
        let cacheHitRate: Double
        let memoryUsage: Double
        let batteryDrain: Double
    }

    func testPerformanceMetricsCreation() {
        let metrics = PerformanceMetrics(
            averageResponseTime: 0.5, errorRate: 0.01,
            cacheHitRate: 0.8, memoryUsage: 0.5, batteryDrain: 0.1
        )
        XCTAssertEqual(metrics.averageResponseTime, 0.5, accuracy: 0.001)
        XCTAssertEqual(metrics.errorRate, 0.01, accuracy: 0.001)
        XCTAssertEqual(metrics.cacheHitRate, 0.8, accuracy: 0.001)
        XCTAssertEqual(metrics.memoryUsage, 0.5, accuracy: 0.001)
        XCTAssertEqual(metrics.batteryDrain, 0.1, accuracy: 0.001)
    }

    func testPerformanceMetricsZeroValues() {
        let zero = PerformanceMetrics(
            averageResponseTime: 0.0, errorRate: 0.0,
            cacheHitRate: 0.0, memoryUsage: 0.0, batteryDrain: 0.0
        )
        XCTAssertEqual(zero.averageResponseTime, 0.0, accuracy: 0.001)
        XCTAssertEqual(zero.errorRate, 0.0, accuracy: 0.001)
        XCTAssertEqual(zero.cacheHitRate, 0.0, accuracy: 0.001)
    }

    func testPerformanceMetricsFullLoad() {
        let full = PerformanceMetrics(
            averageResponseTime: 10.0, errorRate: 1.0,
            cacheHitRate: 1.0, memoryUsage: 1.0, batteryDrain: 1.0
        )
        XCTAssertEqual(full.errorRate, 1.0, accuracy: 0.001)
        XCTAssertEqual(full.memoryUsage, 1.0, accuracy: 0.001)
    }

    func testPerformanceMetricsComparison() {
        let good = PerformanceMetrics(
            averageResponseTime: 0.2, errorRate: 0.01,
            cacheHitRate: 0.95, memoryUsage: 0.3, batteryDrain: 0.05
        )
        let bad = PerformanceMetrics(
            averageResponseTime: 5.0, errorRate: 0.5,
            cacheHitRate: 0.1, memoryUsage: 0.9, batteryDrain: 0.8
        )
        XCTAssertLessThan(good.averageResponseTime, bad.averageResponseTime)
        XCTAssertLessThan(good.errorRate, bad.errorRate)
        XCTAssertGreaterThan(good.cacheHitRate, bad.cacheHitRate)
        XCTAssertLessThan(good.memoryUsage, bad.memoryUsage)
        XCTAssertLessThan(good.batteryDrain, bad.batteryDrain)
    }

    // =========================================================================
    // MARK: - 12. QAToolResult (mirror AppConfigurationTypes.swift)
    // =========================================================================

    struct QAToolResult: Codable, Sendable {
        let id: UUID
        let tool: QATool
        let timestamp: Date
        let success: Bool
        let issuesFound: Int
        let warningsFound: Int
        let errorsFound: Int
        let duration: TimeInterval
        let output: String
        let details: [QAIssue]

        init(
            id: UUID = UUID(), tool: QATool, timestamp: Date = Date(),
            success: Bool, issuesFound: Int = 0, warningsFound: Int = 0,
            errorsFound: Int = 0, duration: TimeInterval = 0,
            output: String = "", details: [QAIssue] = []
        ) {
            self.id = id; self.tool = tool; self.timestamp = timestamp
            self.success = success; self.issuesFound = issuesFound
            self.warningsFound = warningsFound; self.errorsFound = errorsFound
            self.duration = duration; self.output = output; self.details = details
        }
    }

    func testQAToolResultCreationSuccess() {
        let result = QAToolResult(tool: .swiftLint, success: true)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.tool, .swiftLint)
        XCTAssertEqual(result.issuesFound, 0)
        XCTAssertEqual(result.warningsFound, 0)
        XCTAssertEqual(result.errorsFound, 0)
        XCTAssertTrue(result.output.isEmpty)
        XCTAssertTrue(result.details.isEmpty)
    }

    func testQAToolResultCreationFailure() {
        let issues = [
            QAIssue(severity: .error, message: "Missing return"),
            QAIssue(severity: .warning, message: "Unused variable")
        ]
        let result = QAToolResult(
            tool: .sonarCloud, success: false, issuesFound: 2,
            warningsFound: 1, errorsFound: 1, duration: 3.5,
            output: "Analysis complete with issues", details: issues
        )
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.tool, .sonarCloud)
        XCTAssertEqual(result.issuesFound, 2)
        XCTAssertEqual(result.warningsFound, 1)
        XCTAssertEqual(result.errorsFound, 1)
        XCTAssertEqual(result.duration, 3.5, accuracy: 0.001)
        XCTAssertEqual(result.details.count, 2)
    }

    func testQAToolResultIssueCountingConsistency() {
        let result = QAToolResult(
            tool: .codeCov, success: true,
            issuesFound: 5, warningsFound: 3, errorsFound: 2
        )
        XCTAssertEqual(result.issuesFound, result.warningsFound + result.errorsFound)
    }

    // =========================================================================
    // MARK: - 13. QAIssue (mirror AppConfigurationTypes.swift)
    // =========================================================================

    struct QAIssue: Codable, Sendable {
        let id: UUID
        let severity: QAIssueSeverity
        let message: String
        let file: String?
        let line: Int?
        let column: Int?
        let rule: String?

        init(
            id: UUID = UUID(), severity: QAIssueSeverity, message: String,
            file: String? = nil, line: Int? = nil,
            column: Int? = nil, rule: String? = nil
        ) {
            self.id = id; self.severity = severity; self.message = message
            self.file = file; self.line = line; self.column = column; self.rule = rule
        }
    }

    func testQAIssueCreationMinimal() {
        let issue = QAIssue(severity: .warning, message: "Unused import")
        XCTAssertEqual(issue.severity, .warning)
        XCTAssertEqual(issue.message, "Unused import")
        XCTAssertNil(issue.file)
        XCTAssertNil(issue.line)
        XCTAssertNil(issue.column)
        XCTAssertNil(issue.rule)
    }

    func testQAIssueCreationFull() {
        let issue = QAIssue(
            severity: .error, message: "Type 'Foo' has no member 'bar'",
            file: "Sources/Foo.swift", line: 42, column: 10, rule: "compiler_error"
        )
        XCTAssertEqual(issue.severity, .error)
        XCTAssertEqual(issue.message, "Type 'Foo' has no member 'bar'")
        XCTAssertEqual(issue.file, "Sources/Foo.swift")
        XCTAssertEqual(issue.line, 42)
        XCTAssertEqual(issue.column, 10)
        XCTAssertEqual(issue.rule, "compiler_error")
    }

    func testQAIssueAllSeverities() {
        let severities: [QAIssueSeverity] = [.error, .warning, .info, .hint]
        for severity in severities {
            let issue = QAIssue(severity: severity, message: "Test \(severity)")
            XCTAssertEqual(issue.severity, severity)
        }
    }

    func testQAIssueCodableRoundTrip() throws {
        let issue = QAIssue(
            severity: .warning, message: "Line too long",
            file: "Main.swift", line: 100, column: 121, rule: "line_length"
        )
        let data = try JSONEncoder().encode(issue)
        let decoded = try JSONDecoder().decode(QAIssue.self, from: data)
        XCTAssertEqual(decoded.severity, issue.severity)
        XCTAssertEqual(decoded.message, issue.message)
        XCTAssertEqual(decoded.file, issue.file)
        XCTAssertEqual(decoded.line, issue.line)
        XCTAssertEqual(decoded.column, issue.column)
        XCTAssertEqual(decoded.rule, issue.rule)
    }

    // =========================================================================
    // MARK: - 14. ConversationConfiguration (mirror ConversationConfiguration.swift)
    // =========================================================================

    struct TestConversationConfig: Codable, Equatable {
        var maxContextTokens: Int?
        var maxConversationLength: Int?
        var maxMessageAgeDays: Int?
        var persistFullHistory: Bool = true
        var contextStrategy: ContextStrategy = .unlimited
        var allowMetaAIContextExpansion: Bool = true
        var metaAIPreferredContext: Int = 200_000
        var metaAIReservedTokens: Int = 50000
        var metaAIContextPriority: MetaAIPriority = .high
        var tokenCountingMethod: TokenCountingMethod = .accurate
        var enableStreaming: Bool = true
        var streamingBufferSize: Int = 100

        static let providerContextSizes: [String: Int] = [
            "anthropic/claude-sonnet-4": 200_000,
            "anthropic/claude-opus-4": 200_000,
            "openai/gpt-4o": 128_000,
            "google/gemini-2.0-flash": 1_000_000
        ]

        func getEffectiveContextSize(for provider: String) -> Int {
            if let custom = maxContextTokens { return custom }
            return Self.providerContextSizes[provider] ?? 128_000
        }

        func getAvailableContextForChat(provider: String) -> Int {
            let total = getEffectiveContextSize(for: provider)
            let reserved = allowMetaAIContextExpansion ? metaAIReservedTokens : 0
            return total - reserved
        }

        var isUnlimited: Bool {
            contextStrategy == .unlimited &&
                maxConversationLength == nil &&
                maxContextTokens == nil
        }
    }

    func testConversationConfigDefaults() {
        let config = TestConversationConfig()
        XCTAssertNil(config.maxContextTokens)
        XCTAssertNil(config.maxConversationLength)
        XCTAssertNil(config.maxMessageAgeDays)
        XCTAssertTrue(config.persistFullHistory)
        XCTAssertEqual(config.contextStrategy, .unlimited)
        XCTAssertTrue(config.allowMetaAIContextExpansion)
        XCTAssertEqual(config.metaAIPreferredContext, 200_000)
        XCTAssertEqual(config.metaAIReservedTokens, 50000)
        XCTAssertEqual(config.metaAIContextPriority, .high)
        XCTAssertTrue(config.enableStreaming)
    }

    func testConversationConfigIsUnlimited() {
        var config = TestConversationConfig()
        XCTAssertTrue(config.isUnlimited)

        config.maxConversationLength = 100
        XCTAssertFalse(config.isUnlimited)

        config.maxConversationLength = nil
        config.maxContextTokens = 50000
        XCTAssertFalse(config.isUnlimited)

        config.maxContextTokens = nil
        config.contextStrategy = .sliding
        XCTAssertFalse(config.isUnlimited)
    }

    func testConversationConfigEffectiveContextSize() {
        var config = TestConversationConfig()
        XCTAssertEqual(config.getEffectiveContextSize(for: "anthropic/claude-sonnet-4"), 200_000)
        XCTAssertEqual(config.getEffectiveContextSize(for: "openai/gpt-4o"), 128_000)
        XCTAssertEqual(config.getEffectiveContextSize(for: "google/gemini-2.0-flash"), 1_000_000)
        XCTAssertEqual(config.getEffectiveContextSize(for: "unknown/model"), 128_000)
        config.maxContextTokens = 50_000
        XCTAssertEqual(config.getEffectiveContextSize(for: "anthropic/claude-sonnet-4"), 50_000)
    }

    func testConversationConfigAvailableContextForChat() {
        var config = TestConversationConfig()
        let available = config.getAvailableContextForChat(provider: "anthropic/claude-sonnet-4")
        XCTAssertEqual(available, 200_000 - 50000)

        config.allowMetaAIContextExpansion = false
        let fullAvailable = config.getAvailableContextForChat(provider: "anthropic/claude-sonnet-4")
        XCTAssertEqual(fullAvailable, 200_000)
    }

    func testConversationConfigCodableRoundTrip() throws {
        var config = TestConversationConfig()
        config.maxContextTokens = 100_000
        config.contextStrategy = .hybrid
        config.metaAIContextPriority = .maximum

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestConversationConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    // =========================================================================
    // MARK: - 15. OrchestratorConfiguration (mirror OrchestratorConfiguration.swift)
    // =========================================================================

    struct TestOrchestratorConfig: Codable, Equatable {
        var orchestratorEnabled: Bool = true
        var localModelPreference: LocalModelPreference = .balanced
        var taskRoutingRules: [String: [String]] = [
            "simpleQA": ["local-any", "openai/gpt-4o-mini"],
            "codeGeneration": ["anthropic/claude-sonnet-4", "openai/gpt-4o"],
            "complexReasoning": ["anthropic/claude-opus-4", "openai/o1"]
        ]
        var costBudgetPerQuery: Double?
        var preferCheaperModels: Bool = true
        var showDecompositionDetails: Bool = false
        var logModelRouting: Bool = true
        var maxParallelAgents: Int = 5
        var agentTimeoutSeconds: TimeInterval = 120
        var enableRetryOnFailure: Bool = true
        var maxRetryAttempts: Int = 3
        var useAIForClassification: Bool = false
        var classificationConfidenceThreshold: Float = 0.7
        var enableResultValidation: Bool = true

        func preferredModels(for taskType: String) -> [String] {
            taskRoutingRules[taskType] ?? []
        }

        func shouldOrchestrate(complexity: QueryComplexity) -> Bool {
            guard orchestratorEnabled else { return false }
            switch complexity {
            case .simple: return false
            case .moderate, .complex: return true
            }
        }

        func executionStrategy(for complexity: QueryComplexity) -> ExecutionStrategy {
            switch complexity {
            case .simple: .direct
            case .moderate: .decompose
            case .complex: .deepAgent
            }
        }
    }

    func testOrchestratorConfigDefaults() {
        let config = TestOrchestratorConfig()
        XCTAssertTrue(config.orchestratorEnabled)
        XCTAssertEqual(config.localModelPreference, .balanced)
        XCTAssertTrue(config.preferCheaperModels)
        XCTAssertFalse(config.showDecompositionDetails)
        XCTAssertTrue(config.logModelRouting)
        XCTAssertEqual(config.maxParallelAgents, 5)
        XCTAssertEqual(config.agentTimeoutSeconds, 120, accuracy: 0.1)
        XCTAssertTrue(config.enableRetryOnFailure)
        XCTAssertEqual(config.maxRetryAttempts, 3)
        XCTAssertFalse(config.useAIForClassification)
        XCTAssertEqual(config.classificationConfidenceThreshold, 0.7, accuracy: 0.01)
        XCTAssertTrue(config.enableResultValidation)
        XCTAssertNil(config.costBudgetPerQuery)
    }

    func testOrchestratorConfigShouldOrchestrate() {
        var config = TestOrchestratorConfig()
        XCTAssertFalse(config.shouldOrchestrate(complexity: .simple))
        XCTAssertTrue(config.shouldOrchestrate(complexity: .moderate))
        XCTAssertTrue(config.shouldOrchestrate(complexity: .complex))

        config.orchestratorEnabled = false
        XCTAssertFalse(config.shouldOrchestrate(complexity: .simple))
        XCTAssertFalse(config.shouldOrchestrate(complexity: .moderate))
        XCTAssertFalse(config.shouldOrchestrate(complexity: .complex))
    }

    func testOrchestratorConfigExecutionStrategy() {
        let config = TestOrchestratorConfig()
        XCTAssertEqual(config.executionStrategy(for: .simple), .direct)
        XCTAssertEqual(config.executionStrategy(for: .moderate), .decompose)
        XCTAssertEqual(config.executionStrategy(for: .complex), .deepAgent)
    }

    func testOrchestratorConfigPreferredModels() {
        let config = TestOrchestratorConfig()
        let simpleModels = config.preferredModels(for: "simpleQA")
        XCTAssertFalse(simpleModels.isEmpty)
        XCTAssertEqual(simpleModels.first, "local-any")

        let codeModels = config.preferredModels(for: "codeGeneration")
        XCTAssertFalse(codeModels.isEmpty)
        XCTAssertTrue(codeModels.first?.contains("claude") ?? false)

        let unknownModels = config.preferredModels(for: "nonexistentTask")
        XCTAssertTrue(unknownModels.isEmpty)
    }

    func testOrchestratorConfigCodableRoundTrip() throws {
        var config = TestOrchestratorConfig()
        config.orchestratorEnabled = false
        config.localModelPreference = .cloudFirst
        config.maxRetryAttempts = 5

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestOrchestratorConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

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
