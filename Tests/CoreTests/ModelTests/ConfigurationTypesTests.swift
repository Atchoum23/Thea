import Foundation
import XCTest

/// Standalone tests for configuration enums and their logic.
/// Creates local test doubles mirroring the real types in Shared/Core/Configuration/.
/// Pattern: same as TaskClassifierTypesTests.swift — no app module imports.
///
/// Part 1 of 2: Enum types (ExecutionMode, ContextStrategy, MetaAIPriority,
/// TokenCountingMethod, LocalModelPreference, ExecutionStrategy, QueryComplexity,
/// QATool, QAIssueSeverity, AITaskCategory).
/// Part 2: ConfigurationStructTests.swift (PerformanceMetrics, QAToolResult,
/// QAIssue, ConversationConfig, OrchestratorConfig, SystemPromptConfig,
/// VerificationConfig, SecurityConfig).
final class ConfigurationTypesTests: XCTestCase {

    // =========================================================================
    // MARK: - 1. ExecutionMode (mirror AppConfigurationTypes.swift)
    // =========================================================================

    enum ExecutionMode: String, Codable, Sendable, CaseIterable {
        case safe
        case normal
        case aggressive

        var displayName: String {
            switch self {
            case .safe: "Safe Mode (Manual Approval)"
            case .normal: "Normal Mode (Smart Approval)"
            case .aggressive: "Aggressive Mode (Autonomous)"
            }
        }

        var description: String {
            switch self {
            case .safe:
                "Every operation requires manual approval. Best for learning or sensitive work."
            case .normal:
                "Approve plans upfront, allow safe operations automatically. Recommended for most users."
            case .aggressive:
                "Pre-approve all operations. AI continues until mission complete. Use with caution."
            }
        }
    }

    func testExecutionModeRawValues() {
        XCTAssertEqual(ExecutionMode.safe.rawValue, "safe")
        XCTAssertEqual(ExecutionMode.normal.rawValue, "normal")
        XCTAssertEqual(ExecutionMode.aggressive.rawValue, "aggressive")
    }

    func testExecutionModeCaseIterable() {
        XCTAssertEqual(ExecutionMode.allCases.count, 3)
        XCTAssertEqual(ExecutionMode.allCases, [.safe, .normal, .aggressive])
    }

    func testExecutionModeCodableRoundTrip() throws {
        for mode in ExecutionMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(ExecutionMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    func testExecutionModeDisplayNames() {
        XCTAssertTrue(ExecutionMode.safe.displayName.contains("Safe"))
        XCTAssertTrue(ExecutionMode.normal.displayName.contains("Normal"))
        XCTAssertTrue(ExecutionMode.aggressive.displayName.contains("Autonomous"))
    }

    // =========================================================================
    // MARK: - 2. ContextStrategy (mirror ConversationConfiguration.swift)
    // =========================================================================

    enum ContextStrategy: String, Codable, CaseIterable, Sendable {
        case unlimited = "Unlimited"
        case sliding = "Sliding Window"
        case summarize = "Smart Summarization"
        case hybrid = "Hybrid (Summarize + Recent)"

        var description: String {
            switch self {
            case .unlimited:
                "Keep all messages, use provider's full context window"
            case .sliding:
                "Keep most recent messages, drop oldest when limit reached"
            case .summarize:
                "Summarize old messages to preserve context efficiently"
            case .hybrid:
                "Keep recent messages verbatim + summary of older context"
            }
        }
    }

    func testContextStrategyAllCases() {
        XCTAssertEqual(ContextStrategy.allCases.count, 4)
        XCTAssertEqual(ContextStrategy.allCases,
                       [.unlimited, .sliding, .summarize, .hybrid])
    }

    func testContextStrategyCodableRoundTrip() throws {
        for strategy in ContextStrategy.allCases {
            let data = try JSONEncoder().encode(strategy)
            let decoded = try JSONDecoder().decode(ContextStrategy.self, from: data)
            XCTAssertEqual(decoded, strategy)
        }
    }

    func testContextStrategyDescriptionsNonEmpty() {
        for strategy in ContextStrategy.allCases {
            XCTAssertFalse(strategy.description.isEmpty, "\(strategy) description should not be empty")
        }
    }

    // =========================================================================
    // MARK: - 3. MetaAIPriority (mirror ConversationConfiguration.swift)
    // =========================================================================

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

    func testMetaAIPriorityAllCases() {
        XCTAssertEqual(MetaAIPriority.allCases.count, 3)
        XCTAssertEqual(MetaAIPriority.allCases, [.normal, .high, .maximum])
    }

    func testMetaAIPriorityAllocationPercentages() {
        XCTAssertEqual(MetaAIPriority.normal.allocationPercentage, 0.5, accuracy: 0.001)
        XCTAssertEqual(MetaAIPriority.high.allocationPercentage, 0.7, accuracy: 0.001)
        XCTAssertEqual(MetaAIPriority.maximum.allocationPercentage, 0.9, accuracy: 0.001)
    }

    func testMetaAIPriorityAllocationOrdering() {
        XCTAssertLessThan(MetaAIPriority.normal.allocationPercentage,
                          MetaAIPriority.high.allocationPercentage)
        XCTAssertLessThan(MetaAIPriority.high.allocationPercentage,
                          MetaAIPriority.maximum.allocationPercentage)
    }

    // =========================================================================
    // MARK: - 4. TokenCountingMethod (mirror ConversationConfiguration.swift)
    // =========================================================================

    enum TokenCountingMethod: String, Codable, Sendable {
        case estimate = "Estimate (Fast)"
        case accurate = "Accurate (Slower)"

        static let tokensPerChar: Double = 0.25
    }

    func testTokenCountingMethodBothCases() {
        XCTAssertEqual(TokenCountingMethod.estimate.rawValue, "Estimate (Fast)")
        XCTAssertEqual(TokenCountingMethod.accurate.rawValue, "Accurate (Slower)")
    }

    func testTokenCountingMethodCodableRoundTrip() throws {
        for method in [TokenCountingMethod.estimate, .accurate] {
            let data = try JSONEncoder().encode(method)
            let decoded = try JSONDecoder().decode(TokenCountingMethod.self, from: data)
            XCTAssertEqual(decoded, method)
        }
    }

    func testTokenCountingMethodTokensPerChar() {
        XCTAssertEqual(TokenCountingMethod.tokensPerChar, 0.25, accuracy: 0.001)
        let chars = 100
        let estimated = Double(chars) * TokenCountingMethod.tokensPerChar
        XCTAssertEqual(estimated, 25.0, accuracy: 0.001)
    }

    // =========================================================================
    // MARK: - 5. LocalModelPreference (mirror OrchestratorConfiguration.swift)
    // =========================================================================

    enum LocalModelPreference: String, Codable, CaseIterable, Sendable {
        case always = "Always"
        case prefer = "Prefer"
        case balanced = "Balanced"
        case cloudFirst = "Cloud-First"

        var description: String {
            switch self {
            case .always:
                "Only use local models (fail if unavailable)"
            case .prefer:
                "Try local first, fallback to cloud"
            case .balanced:
                "Use local for simple tasks, cloud for complex"
            case .cloudFirst:
                "Prefer cloud models, use local only offline"
            }
        }
    }

    func testLocalModelPreferenceAllCases() {
        XCTAssertEqual(LocalModelPreference.allCases.count, 4)
        XCTAssertEqual(LocalModelPreference.allCases,
                       [.always, .prefer, .balanced, .cloudFirst])
    }

    func testLocalModelPreferenceOrdering() {
        let cases = LocalModelPreference.allCases
        XCTAssertEqual(cases.first, .always)
        XCTAssertEqual(cases.last, .cloudFirst)
    }

    func testLocalModelPreferenceDescriptions() {
        XCTAssertTrue(LocalModelPreference.always.description.lowercased().contains("local"))
        XCTAssertTrue(LocalModelPreference.prefer.description.lowercased().contains("local"))
        XCTAssertTrue(LocalModelPreference.balanced.description.lowercased().contains("local"))
        XCTAssertTrue(LocalModelPreference.cloudFirst.description.lowercased().contains("cloud"))
    }

    // =========================================================================
    // MARK: - 6. ExecutionStrategy (mirror OrchestratorConfiguration.swift)
    // =========================================================================

    enum ExecutionStrategy: String, Codable, Sendable {
        case direct
        case decompose
        case deepAgent
    }

    func testExecutionStrategyAllCases() {
        XCTAssertEqual(ExecutionStrategy.direct.rawValue, "direct")
        XCTAssertEqual(ExecutionStrategy.decompose.rawValue, "decompose")
        XCTAssertEqual(ExecutionStrategy.deepAgent.rawValue, "deepAgent")
    }

    func testExecutionStrategyCodableRoundTrip() throws {
        for strategy in [ExecutionStrategy.direct, .decompose, .deepAgent] {
            let data = try JSONEncoder().encode(strategy)
            let decoded = try JSONDecoder().decode(ExecutionStrategy.self, from: data)
            XCTAssertEqual(decoded, strategy)
        }
    }

    // =========================================================================
    // MARK: - 7. QueryComplexity (mirror OrchestrationTypes.swift)
    // =========================================================================

    enum QueryComplexity: String, Codable, Sendable, Comparable {
        case simple
        case moderate
        case complex

        var description: String {
            switch self {
            case .simple: "Single-task, straightforward query"
            case .moderate: "Multi-step or requires decomposition"
            case .complex: "Complex reasoning, verification needed"
            }
        }

        private var sortOrder: Int {
            switch self {
            case .simple: 0
            case .moderate: 1
            case .complex: 2
            }
        }

        static func < (lhs: QueryComplexity, rhs: QueryComplexity) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }

    func testQueryComplexityAllCases() {
        XCTAssertEqual(QueryComplexity.simple.rawValue, "simple")
        XCTAssertEqual(QueryComplexity.moderate.rawValue, "moderate")
        XCTAssertEqual(QueryComplexity.complex.rawValue, "complex")
    }

    func testQueryComplexityComparable() {
        XCTAssertLessThan(QueryComplexity.simple, .moderate)
        XCTAssertLessThan(QueryComplexity.moderate, .complex)
        XCTAssertLessThan(QueryComplexity.simple, .complex)
        XCTAssertFalse(QueryComplexity.complex < .simple)
    }

    func testQueryComplexityCodableRoundTrip() throws {
        for complexity in [QueryComplexity.simple, .moderate, .complex] {
            let data = try JSONEncoder().encode(complexity)
            let decoded = try JSONDecoder().decode(QueryComplexity.self, from: data)
            XCTAssertEqual(decoded, complexity)
        }
    }

    // =========================================================================
    // MARK: - 8. QATool (mirror AppConfigurationTypes.swift)
    // =========================================================================

    enum QATool: String, Codable, Sendable, CaseIterable {
        case swiftLint = "SwiftLint"
        case codeCov = "CodeCov"
        case sonarCloud = "SonarCloud"
        case deepSource = "DeepSource"

        var displayName: String { rawValue }

        var icon: String {
            switch self {
            case .swiftLint: "swift"
            case .codeCov: "chart.pie"
            case .sonarCloud: "cloud"
            case .deepSource: "magnifyingglass.circle"
            }
        }

        var description: String {
            switch self {
            case .swiftLint:
                "Static code analysis for Swift style and conventions"
            case .codeCov:
                "Code coverage reporting and tracking"
            case .sonarCloud:
                "Continuous code quality and security analysis"
            case .deepSource:
                "Automated code review and issue detection"
            }
        }
    }

    func testQAToolAllCases() {
        XCTAssertEqual(QATool.allCases.count, 4)
        XCTAssertEqual(QATool.allCases, [.swiftLint, .codeCov, .sonarCloud, .deepSource])
    }

    func testQAToolCodableRoundTrip() throws {
        for tool in QATool.allCases {
            let data = try JSONEncoder().encode(tool)
            let decoded = try JSONDecoder().decode(QATool.self, from: data)
            XCTAssertEqual(decoded, tool)
        }
    }

    func testQAToolDisplayNameMatchesRawValue() {
        for tool in QATool.allCases {
            XCTAssertEqual(tool.displayName, tool.rawValue)
        }
    }

    func testQAToolIconsNonEmpty() {
        for tool in QATool.allCases {
            XCTAssertFalse(tool.icon.isEmpty, "\(tool) icon should not be empty")
        }
    }

    // =========================================================================
    // MARK: - 9. QAIssueSeverity (mirror AppConfigurationTypes.swift)
    // =========================================================================

    enum QAIssueSeverity: String, Codable, Sendable {
        case error
        case warning
        case info
        case hint

        var color: String {
            switch self {
            case .error: "red"
            case .warning: "orange"
            case .info: "blue"
            case .hint: "gray"
            }
        }

        var icon: String {
            switch self {
            case .error: "xmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .info: "info.circle.fill"
            case .hint: "lightbulb.fill"
            }
        }

        var severityOrder: Int {
            switch self {
            case .error: 3
            case .warning: 2
            case .info: 1
            case .hint: 0
            }
        }
    }

    func testQAIssueSeverityAllCases() {
        let allSeverities: [QAIssueSeverity] = [.error, .warning, .info, .hint]
        for severity in allSeverities {
            XCTAssertNotNil(QAIssueSeverity(rawValue: severity.rawValue))
        }
    }

    func testQAIssueSeverityOrdering() {
        XCTAssertGreaterThan(QAIssueSeverity.error.severityOrder,
                             QAIssueSeverity.warning.severityOrder)
        XCTAssertGreaterThan(QAIssueSeverity.warning.severityOrder,
                             QAIssueSeverity.info.severityOrder)
        XCTAssertGreaterThan(QAIssueSeverity.info.severityOrder,
                             QAIssueSeverity.hint.severityOrder)
    }

    func testQAIssueSeverityColors() {
        XCTAssertEqual(QAIssueSeverity.error.color, "red")
        XCTAssertEqual(QAIssueSeverity.warning.color, "orange")
        XCTAssertEqual(QAIssueSeverity.info.color, "blue")
        XCTAssertEqual(QAIssueSeverity.hint.color, "gray")
    }

    func testQAIssueSeverityCodableRoundTrip() throws {
        for severity in [QAIssueSeverity.error, .warning, .info, .hint] {
            let data = try JSONEncoder().encode(severity)
            let decoded = try JSONDecoder().decode(QAIssueSeverity.self, from: data)
            XCTAssertEqual(decoded, severity)
        }
    }

    // =========================================================================
    // MARK: - 10. AITaskCategory (mirror DynamicConfig.swift)
    // =========================================================================

    enum AITaskCategory: String, Codable, Sendable, CaseIterable {
        case codeGeneration
        case codeReview
        case bugFix
        case conversation
        case assistance
        case creative
        case brainstorming
        case analysis
        case classification
        case translation
        case correction
    }

    func testAITaskCategoryAllCases() {
        XCTAssertEqual(AITaskCategory.allCases.count, 11)
    }

    func testAITaskCategoryCodableRoundTrip() throws {
        for category in AITaskCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(AITaskCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }

    func testAITaskCategoryRawValuesAreCamelCase() {
        for category in AITaskCategory.allCases {
            let first = category.rawValue.first!
            XCTAssertTrue(first.isLowercase,
                          "\(category.rawValue) should start with lowercase")
        }
    }

    func testAITaskCategoryCodeRelatedSubset() {
        let codeRelated: Set<AITaskCategory> = [.codeGeneration, .codeReview, .bugFix]
        XCTAssertEqual(codeRelated.count, 3)
        for cat in codeRelated {
            XCTAssertNotNil(AITaskCategory(rawValue: cat.rawValue))
        }
    }
}
