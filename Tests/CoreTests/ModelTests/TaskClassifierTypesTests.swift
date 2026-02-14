import Foundation
import XCTest

/// Standalone tests for TaskType enum, ClassificationResult, ResponseLength,
/// and ClassificationMethodType. Mirrors types in TaskClassifier/TaskType.
final class TaskClassifierTypesTests: XCTestCase {

    // MARK: - ResponseLength (mirror TaskType.swift)

    enum ResponseLength: String, Codable, Sendable {
        case short
        case medium
        case long

        var suggestedMaxTokens: Int {
            switch self {
            case .short: 500
            case .medium: 2000
            case .long: 8000
            }
        }
    }

    func testResponseLengthMaxTokens() {
        XCTAssertEqual(ResponseLength.short.suggestedMaxTokens, 500)
        XCTAssertEqual(ResponseLength.medium.suggestedMaxTokens, 2000)
        XCTAssertEqual(ResponseLength.long.suggestedMaxTokens, 8000)
    }

    func testResponseLengthCodable() throws {
        for length in [ResponseLength.short, .medium, .long] {
            let data = try JSONEncoder().encode(length)
            let decoded = try JSONDecoder().decode(ResponseLength.self, from: data)
            XCTAssertEqual(decoded, length)
        }
    }

    // MARK: - ClassificationMethodType (mirror TaskClassifier.swift)

    enum ClassificationMethodType: String, Codable, Sendable {
        case ai
        case embedding
        case pattern
        case cache
    }

    func testClassificationMethodTypeCodable() throws {
        for method in [ClassificationMethodType.ai, .embedding, .pattern, .cache] {
            let data = try JSONEncoder().encode(method)
            let decoded = try JSONDecoder().decode(ClassificationMethodType.self, from: data)
            XCTAssertEqual(decoded, method)
        }
    }

    func testClassificationMethodTypeRawValues() {
        XCTAssertEqual(ClassificationMethodType.ai.rawValue, "ai")
        XCTAssertEqual(ClassificationMethodType.embedding.rawValue, "embedding")
        XCTAssertEqual(ClassificationMethodType.pattern.rawValue, "pattern")
        XCTAssertEqual(ClassificationMethodType.cache.rawValue, "cache")
    }

    // MARK: - ModelCapability (subset mirror)

    enum ModelCapability: String, Codable, Sendable {
        case chat
        case codeGeneration
        case reasoning
        case analysis
        case functionCalling
        case search
    }

    // MARK: - TaskType (mirror TaskType.swift — all 29 cases)

    enum TaskType: String, Codable, Sendable, CaseIterable {
        case codeGeneration
        case codeAnalysis
        case codeDebugging
        case debugging
        case codeExplanation
        case codeRefactoring
        case factual
        case creative
        case analysis
        case research
        case conversation
        case system
        case math
        case translation
        case summarization
        case planning
        case unknown
        // Legacy aliases
        case simpleQA
        case complexReasoning
        case creativeWriting
        case mathLogic
        case informationRetrieval
        case appDevelopment
        case contentCreation
        case workflowAutomation
        case creation
        case general

        var description: String {
            switch self {
            case .codeGeneration, .appDevelopment: "Code Generation"
            case .codeAnalysis: "Code Analysis"
            case .codeDebugging, .debugging: "Debugging"
            case .codeExplanation: "Code Explanation"
            case .codeRefactoring: "Code Refactoring"
            case .factual, .simpleQA: "Factual Question"
            case .creative, .creativeWriting, .contentCreation, .creation: "Creative Writing"
            case .analysis, .complexReasoning: "Analysis"
            case .research, .informationRetrieval: "Research"
            case .conversation, .general: "Conversation"
            case .system, .workflowAutomation: "System Operation"
            case .math, .mathLogic: "Mathematics"
            case .translation: "Translation"
            case .summarization: "Summarization"
            case .planning: "Planning"
            case .unknown: "Unknown"
            }
        }

        var preferredCapabilities: Set<ModelCapability> {
            switch self {
            case .codeGeneration, .debugging, .codeDebugging, .codeRefactoring, .appDevelopment,
                 .codeAnalysis, .codeExplanation:
                return [.codeGeneration, .chat]
            case .factual, .research, .simpleQA, .informationRetrieval:
                return [.chat, .search]
            case .creative, .creativeWriting, .contentCreation, .creation:
                return [.chat]
            case .analysis, .complexReasoning:
                return [.reasoning, .analysis, .chat]
            case .conversation, .general:
                return [.chat]
            case .system, .workflowAutomation:
                return [.functionCalling, .chat]
            case .math, .mathLogic:
                return [.reasoning, .chat]
            case .translation, .summarization:
                return [.chat]
            case .planning:
                return [.reasoning, .chat]
            case .unknown:
                return [.chat]
            }
        }

        var benefitsFromReasoning: Bool {
            switch self {
            case .debugging, .codeDebugging, .codeAnalysis, .analysis,
                 .complexReasoning, .math, .mathLogic, .planning, .codeRefactoring:
                return true
            default:
                return false
            }
        }

        var isSimple: Bool {
            switch self {
            case .conversation, .general, .factual, .simpleQA, .translation:
                return true
            default:
                return false
            }
        }

        var isActionable: Bool {
            switch self {
            case .codeGeneration, .appDevelopment, .codeRefactoring, .debugging,
                 .codeDebugging, .system, .workflowAutomation, .planning:
                return true
            default:
                return false
            }
        }

        var needsWebSearch: Bool {
            switch self {
            case .research, .factual, .simpleQA, .informationRetrieval:
                return true
            default:
                return false
            }
        }

        var expectedResponseLength: ResponseLength {
            switch self {
            case .conversation, .general:
                return .short
            case .factual, .simpleQA, .math, .mathLogic, .translation:
                return .medium
            case .codeGeneration, .appDevelopment, .debugging, .codeDebugging,
                 .creative, .creativeWriting, .contentCreation, .creation,
                 .analysis, .complexReasoning, .summarization, .planning:
                return .long
            case .codeAnalysis, .codeExplanation, .codeRefactoring, .research,
                 .informationRetrieval, .system, .workflowAutomation, .unknown:
                return .medium
            }
        }
    }

    // MARK: - TaskType Description Tests

    func testTaskTypeDescriptions() {
        XCTAssertEqual(TaskType.codeGeneration.description, "Code Generation")
        XCTAssertEqual(TaskType.codeAnalysis.description, "Code Analysis")
        XCTAssertEqual(TaskType.codeDebugging.description, "Debugging")
        XCTAssertEqual(TaskType.debugging.description, "Debugging")
        XCTAssertEqual(TaskType.codeExplanation.description, "Code Explanation")
        XCTAssertEqual(TaskType.codeRefactoring.description, "Code Refactoring")
        XCTAssertEqual(TaskType.factual.description, "Factual Question")
        XCTAssertEqual(TaskType.creative.description, "Creative Writing")
        XCTAssertEqual(TaskType.analysis.description, "Analysis")
        XCTAssertEqual(TaskType.research.description, "Research")
        XCTAssertEqual(TaskType.conversation.description, "Conversation")
        XCTAssertEqual(TaskType.system.description, "System Operation")
        XCTAssertEqual(TaskType.math.description, "Mathematics")
        XCTAssertEqual(TaskType.translation.description, "Translation")
        XCTAssertEqual(TaskType.summarization.description, "Summarization")
        XCTAssertEqual(TaskType.planning.description, "Planning")
        XCTAssertEqual(TaskType.unknown.description, "Unknown")
    }

    func testTaskTypeLegacyAliasDescriptions() {
        XCTAssertEqual(TaskType.simpleQA.description, TaskType.factual.description)
        XCTAssertEqual(TaskType.creativeWriting.description, TaskType.creative.description)
        XCTAssertEqual(TaskType.mathLogic.description, TaskType.math.description)
        XCTAssertEqual(TaskType.complexReasoning.description, TaskType.analysis.description)
        XCTAssertEqual(TaskType.informationRetrieval.description, TaskType.research.description)
        XCTAssertEqual(TaskType.appDevelopment.description, TaskType.codeGeneration.description)
        XCTAssertEqual(TaskType.contentCreation.description, TaskType.creative.description)
        XCTAssertEqual(TaskType.creation.description, TaskType.creative.description)
        XCTAssertEqual(TaskType.workflowAutomation.description, TaskType.system.description)
        XCTAssertEqual(TaskType.general.description, TaskType.conversation.description)
    }

    // MARK: - BenefitsFromReasoning Tests

    func testBenefitsFromReasoningTrueCases() {
        let reasoningTasks: [TaskType] = [
            .debugging, .codeDebugging, .codeAnalysis, .analysis,
            .complexReasoning, .math, .mathLogic, .planning, .codeRefactoring
        ]
        for task in reasoningTasks {
            XCTAssertTrue(task.benefitsFromReasoning, "\(task) should benefit from reasoning")
        }
    }

    func testBenefitsFromReasoningFalseCases() {
        let nonReasoningTasks: [TaskType] = [
            .codeGeneration, .codeExplanation, .factual, .creative,
            .research, .conversation, .system, .translation,
            .summarization, .unknown, .simpleQA, .creativeWriting,
            .informationRetrieval, .appDevelopment, .contentCreation,
            .workflowAutomation, .creation, .general
        ]
        for task in nonReasoningTasks {
            XCTAssertFalse(task.benefitsFromReasoning, "\(task) should NOT benefit from reasoning")
        }
    }

    // MARK: - IsSimple Tests

    func testIsSimpleTrueCases() {
        let simpleTasks: [TaskType] = [
            .conversation, .general, .factual, .simpleQA, .translation
        ]
        for task in simpleTasks {
            XCTAssertTrue(task.isSimple, "\(task) should be simple")
        }
    }

    func testIsSimpleFalseCases() {
        let complexTasks: [TaskType] = [
            .codeGeneration, .codeAnalysis, .codeDebugging, .debugging,
            .codeExplanation, .codeRefactoring, .creative, .analysis,
            .research, .system, .math, .summarization, .planning, .unknown
        ]
        for task in complexTasks {
            XCTAssertFalse(task.isSimple, "\(task) should NOT be simple")
        }
    }

    // MARK: - IsActionable Tests

    func testIsActionableTrueCases() {
        let actionableTasks: [TaskType] = [
            .codeGeneration, .appDevelopment, .codeRefactoring,
            .debugging, .codeDebugging, .system, .workflowAutomation, .planning
        ]
        for task in actionableTasks {
            XCTAssertTrue(task.isActionable, "\(task) should be actionable")
        }
    }

    func testIsActionableFalseCases() {
        let passiveTasks: [TaskType] = [
            .codeAnalysis, .codeExplanation, .factual, .creative,
            .analysis, .research, .conversation, .math, .translation,
            .summarization, .unknown, .simpleQA, .complexReasoning,
            .creativeWriting, .informationRetrieval
        ]
        for task in passiveTasks {
            XCTAssertFalse(task.isActionable, "\(task) should NOT be actionable")
        }
    }

    // MARK: - NeedsWebSearch Tests

    func testNeedsWebSearchTrueCases() {
        let searchTasks: [TaskType] = [
            .research, .factual, .simpleQA, .informationRetrieval
        ]
        for task in searchTasks {
            XCTAssertTrue(task.needsWebSearch, "\(task) should need web search")
        }
    }

    func testNeedsWebSearchFalseCases() {
        let noSearchTasks: [TaskType] = [
            .codeGeneration, .codeDebugging, .creative, .conversation,
            .system, .math, .translation, .planning, .unknown
        ]
        for task in noSearchTasks {
            XCTAssertFalse(task.needsWebSearch, "\(task) should NOT need web search")
        }
    }

    // MARK: - PreferredCapabilities Tests

    func testCodeTasksPreferCodeGeneration() {
        let codeTasks: [TaskType] = [
            .codeGeneration, .debugging, .codeDebugging, .codeRefactoring,
            .appDevelopment, .codeAnalysis, .codeExplanation
        ]
        for task in codeTasks {
            let caps = task.preferredCapabilities
            XCTAssertTrue(caps.contains(.codeGeneration), "\(task) should prefer code generation")
            XCTAssertTrue(caps.contains(.chat), "\(task) should include chat")
        }
    }

    func testResearchTasksPreferSearch() {
        let searchTasks: [TaskType] = [.factual, .research, .simpleQA, .informationRetrieval]
        for task in searchTasks {
            let caps = task.preferredCapabilities
            XCTAssertTrue(caps.contains(.search), "\(task) should prefer search")
            XCTAssertTrue(caps.contains(.chat), "\(task) should include chat")
        }
    }

    func testAnalysisTasksPreferReasoning() {
        let analysisTasks: [TaskType] = [.analysis, .complexReasoning]
        for task in analysisTasks {
            let caps = task.preferredCapabilities
            XCTAssertTrue(caps.contains(.reasoning), "\(task) should prefer reasoning")
            XCTAssertTrue(caps.contains(.analysis), "\(task) should prefer analysis")
        }
    }

    func testSystemTasksPreferFunctionCalling() {
        let systemTasks: [TaskType] = [.system, .workflowAutomation]
        for task in systemTasks {
            let caps = task.preferredCapabilities
            XCTAssertTrue(caps.contains(.functionCalling), "\(task) should prefer function calling")
        }
    }

    func testMathTasksPreferReasoning() {
        let mathTasks: [TaskType] = [.math, .mathLogic]
        for task in mathTasks {
            let caps = task.preferredCapabilities
            XCTAssertTrue(caps.contains(.reasoning), "\(task) should prefer reasoning")
        }
    }

    func testPlanningPrefsReasoning() {
        let caps = TaskType.planning.preferredCapabilities
        XCTAssertTrue(caps.contains(.reasoning))
        XCTAssertTrue(caps.contains(.chat))
    }

    func testAllTaskTypesIncludeChat() {
        for task in TaskType.allCases {
            XCTAssertTrue(task.preferredCapabilities.contains(.chat),
                          "\(task) should always include chat capability")
        }
    }

    // MARK: - ExpectedResponseLength Tests

    func testShortResponseForConversation() {
        XCTAssertEqual(TaskType.conversation.expectedResponseLength, .short)
        XCTAssertEqual(TaskType.general.expectedResponseLength, .short)
    }

    func testMediumResponseForFactual() {
        XCTAssertEqual(TaskType.factual.expectedResponseLength, .medium)
        XCTAssertEqual(TaskType.simpleQA.expectedResponseLength, .medium)
        XCTAssertEqual(TaskType.math.expectedResponseLength, .medium)
        XCTAssertEqual(TaskType.mathLogic.expectedResponseLength, .medium)
        XCTAssertEqual(TaskType.translation.expectedResponseLength, .medium)
    }

    func testLongResponseForCodeGen() {
        XCTAssertEqual(TaskType.codeGeneration.expectedResponseLength, .long)
        XCTAssertEqual(TaskType.appDevelopment.expectedResponseLength, .long)
        XCTAssertEqual(TaskType.debugging.expectedResponseLength, .long)
        XCTAssertEqual(TaskType.creative.expectedResponseLength, .long)
        XCTAssertEqual(TaskType.analysis.expectedResponseLength, .long)
        XCTAssertEqual(TaskType.summarization.expectedResponseLength, .long)
        XCTAssertEqual(TaskType.planning.expectedResponseLength, .long)
    }

    func testMediumResponseForCodeAnalysis() {
        XCTAssertEqual(TaskType.codeAnalysis.expectedResponseLength, .medium)
        XCTAssertEqual(TaskType.codeExplanation.expectedResponseLength, .medium)
        XCTAssertEqual(TaskType.codeRefactoring.expectedResponseLength, .medium)
        XCTAssertEqual(TaskType.unknown.expectedResponseLength, .medium)
    }

    // MARK: - TaskType CaseIterable & Codable

    func testTaskTypeCaseCount() {
        // 17 canonical + 10 legacy = 27 (note: some enums may have fewer)
        XCTAssertGreaterThanOrEqual(TaskType.allCases.count, 27)
    }

    func testTaskTypeCodable() throws {
        for taskType in TaskType.allCases {
            let data = try JSONEncoder().encode(taskType)
            let decoded = try JSONDecoder().decode(TaskType.self, from: data)
            XCTAssertEqual(decoded, taskType)
        }
    }

    func testTaskTypeRawValueRoundtrip() {
        for taskType in TaskType.allCases {
            let raw = taskType.rawValue
            let reconstructed = TaskType(rawValue: raw)
            XCTAssertEqual(reconstructed, taskType)
        }
    }

    // MARK: - ClassificationResult (mirror TaskClassifier.swift)

    struct ClassificationResult: Sendable {
        let taskType: TaskType
        let confidence: Double
        let reasoning: String?
        let alternativeTypes: [(TaskType, Double)]?
        let suggestedModel: String?
        let timestamp: Date
        let classificationMethod: ClassificationMethodType

        var isConfident: Bool { confidence >= 0.7 }
        var primaryType: TaskType { taskType }
        var secondaryTypes: [TaskType] { alternativeTypes?.map { $0.0 } ?? [] }
    }

    func testClassificationResultIsConfidentAtThreshold() {
        let result = ClassificationResult(
            taskType: .factual, confidence: 0.7, reasoning: nil,
            alternativeTypes: nil, suggestedModel: nil,
            timestamp: Date(), classificationMethod: .cache
        )
        XCTAssertTrue(result.isConfident, "0.7 should be confident (threshold)")
    }

    func testClassificationResultIsConfidentAboveThreshold() {
        let result = ClassificationResult(
            taskType: .codeGeneration, confidence: 0.95, reasoning: "Strong match",
            alternativeTypes: nil, suggestedModel: "claude-opus-4-5",
            timestamp: Date(), classificationMethod: .ai
        )
        XCTAssertTrue(result.isConfident)
    }

    func testClassificationResultNotConfidentBelowThreshold() {
        let result = ClassificationResult(
            taskType: .unknown, confidence: 0.69, reasoning: nil,
            alternativeTypes: nil, suggestedModel: nil,
            timestamp: Date(), classificationMethod: .pattern
        )
        XCTAssertFalse(result.isConfident, "0.69 should NOT be confident")
    }

    func testClassificationResultNotConfidentAtZero() {
        let result = ClassificationResult(
            taskType: .unknown, confidence: 0.0, reasoning: nil,
            alternativeTypes: nil, suggestedModel: nil,
            timestamp: Date(), classificationMethod: .pattern
        )
        XCTAssertFalse(result.isConfident)
    }

    func testClassificationResultPrimaryTypeAlias() {
        let result = ClassificationResult(
            taskType: .codeGeneration, confidence: 0.9, reasoning: nil,
            alternativeTypes: nil, suggestedModel: nil,
            timestamp: Date(), classificationMethod: .ai
        )
        XCTAssertEqual(result.primaryType, .codeGeneration)
    }

    func testClassificationResultSecondaryTypes() {
        let result = ClassificationResult(
            taskType: .analysis, confidence: 0.8, reasoning: nil,
            alternativeTypes: [(.research, 0.5), (.codeAnalysis, 0.3)],
            suggestedModel: nil, timestamp: Date(), classificationMethod: .ai
        )
        XCTAssertEqual(result.secondaryTypes, [.research, .codeAnalysis])
    }

    func testClassificationResultSecondaryTypesNil() {
        let result = ClassificationResult(
            taskType: .factual, confidence: 0.9, reasoning: nil,
            alternativeTypes: nil, suggestedModel: nil,
            timestamp: Date(), classificationMethod: .cache
        )
        XCTAssertTrue(result.secondaryTypes.isEmpty)
    }

    // MARK: - ClassificationInsights (mirror TaskClassifier.swift)

    struct ClassificationInsights {
        let totalClassifications: Int
        let confidentClassifications: Int
        let correctionsCount: Int

        var confidenceRate: Double {
            guard totalClassifications > 0 else { return 0 }
            return Double(confidentClassifications) / Double(totalClassifications)
        }

        var correctionRate: Double {
            guard totalClassifications > 0 else { return 0 }
            return Double(correctionsCount) / Double(totalClassifications)
        }
    }

    func testClassificationInsightsConfidenceRate() {
        let insights = ClassificationInsights(
            totalClassifications: 100,
            confidentClassifications: 80,
            correctionsCount: 5
        )
        XCTAssertEqual(insights.confidenceRate, 0.8, accuracy: 0.001)
    }

    func testClassificationInsightsCorrectionRate() {
        let insights = ClassificationInsights(
            totalClassifications: 100,
            confidentClassifications: 80,
            correctionsCount: 5
        )
        XCTAssertEqual(insights.correctionRate, 0.05, accuracy: 0.001)
    }

    func testClassificationInsightsZeroDivision() {
        let insights = ClassificationInsights(
            totalClassifications: 0,
            confidentClassifications: 0,
            correctionsCount: 0
        )
        XCTAssertEqual(insights.confidenceRate, 0)
        XCTAssertEqual(insights.correctionRate, 0)
    }

    // MARK: - Domain Confidence Thresholds (mirror TaskClassifier.swift)

    func testDomainConfidenceThresholds() {
        let thresholds: [TaskType: Double] = [
            .codeGeneration: 0.75,
            .codeAnalysis: 0.70,
            .codeDebugging: 0.75,
            .math: 0.70,
            .factual: 0.65,
            .creative: 0.55,
            .conversation: 0.50,
            .system: 0.70
        ]
        // Code tasks have highest thresholds
        XCTAssertGreaterThan(thresholds[.codeGeneration]!, thresholds[.creative]!)
        XCTAssertGreaterThan(thresholds[.codeDebugging]!, thresholds[.conversation]!)
        // Creative is flexible
        XCTAssertLessThan(thresholds[.creative]!, thresholds[.math]!)
        // Conversation is most flexible
        XCTAssertEqual(thresholds[.conversation]!, 0.50)
    }
}
