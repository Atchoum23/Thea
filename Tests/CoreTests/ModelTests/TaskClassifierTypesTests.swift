import Foundation
import XCTest

/// Standalone tests for TaskType enum, ClassificationResult, ResponseLength,
/// and ClassificationMethodType. Mirrors types in TaskClassifier/TaskType.
final class TaskClassifierTypesTests: XCTestCase {

    // MARK: - ResponseLength (mirror TaskType.swift)

    enum ResponseLength: String, Codable, Sendable {
        case short, medium, long
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
        case ai, embedding, pattern, cache
    }

    func testClassificationMethodTypeCodableAndRawValues() throws {
        let expected: [(ClassificationMethodType, String)] = [
            (.ai, "ai"), (.embedding, "embedding"), (.pattern, "pattern"), (.cache, "cache")
        ]
        for (method, raw) in expected {
            XCTAssertEqual(method.rawValue, raw)
            let data = try JSONEncoder().encode(method)
            XCTAssertEqual(try JSONDecoder().decode(ClassificationMethodType.self, from: data), method)
        }
    }

    // MARK: - ModelCapability (subset mirror)

    enum ModelCapability: String, Codable, Sendable {
        case chat, codeGeneration, reasoning, analysis, functionCalling, search
    }

    // MARK: - TaskType (mirror TaskType.swift)

    enum TaskType: String, Codable, Sendable, CaseIterable {
        case codeGeneration, codeAnalysis, codeDebugging, debugging
        case codeExplanation, codeRefactoring, factual, creative
        case analysis, research, conversation, system, math
        case translation, summarization, planning, unknown
        // Legacy aliases
        case simpleQA, complexReasoning, creativeWriting, mathLogic
        case informationRetrieval, appDevelopment, contentCreation
        case workflowAutomation, creation, general

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
            default: return false
            }
        }

        var isSimple: Bool {
            switch self {
            case .conversation, .general, .factual, .simpleQA, .translation: return true
            default: return false
            }
        }

        var isActionable: Bool {
            switch self {
            case .codeGeneration, .appDevelopment, .codeRefactoring, .debugging,
                 .codeDebugging, .system, .workflowAutomation, .planning:
                return true
            default: return false
            }
        }

        var needsWebSearch: Bool {
            switch self {
            case .research, .factual, .simpleQA, .informationRetrieval: return true
            default: return false
            }
        }

        var expectedResponseLength: ResponseLength {
            switch self {
            case .conversation, .general: return .short
            case .factual, .simpleQA, .math, .mathLogic, .translation: return .medium
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

    // MARK: - Boolean Property Tests

    func testBenefitsFromReasoningTrueCases() {
        for task in [TaskType.debugging, .codeDebugging, .codeAnalysis, .analysis,
                     .complexReasoning, .math, .mathLogic, .planning, .codeRefactoring] {
            XCTAssertTrue(task.benefitsFromReasoning, "\(task) should benefit from reasoning")
        }
    }

    func testBenefitsFromReasoningFalseCases() {
        for task in [TaskType.codeGeneration, .codeExplanation, .factual, .creative,
                     .research, .conversation, .system, .translation, .summarization,
                     .unknown, .simpleQA, .creativeWriting, .informationRetrieval,
                     .appDevelopment, .contentCreation, .workflowAutomation, .creation, .general] {
            XCTAssertFalse(task.benefitsFromReasoning, "\(task) should NOT benefit from reasoning")
        }
    }

    func testIsSimpleCases() {
        for task in [TaskType.conversation, .general, .factual, .simpleQA, .translation] {
            XCTAssertTrue(task.isSimple, "\(task) should be simple")
        }
        for task in [TaskType.codeGeneration, .codeAnalysis, .codeDebugging, .debugging,
                     .codeExplanation, .codeRefactoring, .creative, .analysis,
                     .research, .system, .math, .summarization, .planning, .unknown] {
            XCTAssertFalse(task.isSimple, "\(task) should NOT be simple")
        }
    }

    func testIsActionableCases() {
        for task in [TaskType.codeGeneration, .appDevelopment, .codeRefactoring,
                     .debugging, .codeDebugging, .system, .workflowAutomation, .planning] {
            XCTAssertTrue(task.isActionable, "\(task) should be actionable")
        }
        for task in [TaskType.codeAnalysis, .codeExplanation, .factual, .creative,
                     .analysis, .research, .conversation, .math, .translation,
                     .summarization, .unknown, .simpleQA, .complexReasoning,
                     .creativeWriting, .informationRetrieval] {
            XCTAssertFalse(task.isActionable, "\(task) should NOT be actionable")
        }
    }

    func testNeedsWebSearchCases() {
        for task in [TaskType.research, .factual, .simpleQA, .informationRetrieval] {
            XCTAssertTrue(task.needsWebSearch, "\(task) should need web search")
        }
        for task in [TaskType.codeGeneration, .codeDebugging, .creative, .conversation,
                     .system, .math, .translation, .planning, .unknown] {
            XCTAssertFalse(task.needsWebSearch, "\(task) should NOT need web search")
        }
    }

    // MARK: - PreferredCapabilities Tests

    func testCodeTasksPreferCodeGeneration() {
        for task in [TaskType.codeGeneration, .debugging, .codeDebugging, .codeRefactoring,
                     .appDevelopment, .codeAnalysis, .codeExplanation] {
            XCTAssertTrue(task.preferredCapabilities.contains(.codeGeneration), "\(task)")
            XCTAssertTrue(task.preferredCapabilities.contains(.chat), "\(task)")
        }
    }

    func testResearchTasksPreferSearch() {
        for task in [TaskType.factual, .research, .simpleQA, .informationRetrieval] {
            XCTAssertTrue(task.preferredCapabilities.contains(.search), "\(task)")
            XCTAssertTrue(task.preferredCapabilities.contains(.chat), "\(task)")
        }
    }

    func testAnalysisTasksPreferReasoning() {
        for task in [TaskType.analysis, .complexReasoning] {
            XCTAssertTrue(task.preferredCapabilities.contains(.reasoning), "\(task)")
            XCTAssertTrue(task.preferredCapabilities.contains(.analysis), "\(task)")
        }
    }

    func testSystemAndMathAndPlanningCapabilities() {
        for task in [TaskType.system, .workflowAutomation] {
            XCTAssertTrue(task.preferredCapabilities.contains(.functionCalling), "\(task)")
        }
        for task in [TaskType.math, .mathLogic, .planning] {
            XCTAssertTrue(task.preferredCapabilities.contains(.reasoning), "\(task)")
        }
        XCTAssertTrue(TaskType.planning.preferredCapabilities.contains(.chat))
    }

    func testAllTaskTypesIncludeChat() {
        for task in TaskType.allCases {
            XCTAssertTrue(task.preferredCapabilities.contains(.chat),
                          "\(task) should always include chat capability")
        }
    }

    // MARK: - ExpectedResponseLength Tests

    func testExpectedResponseLengths() {
        // Short
        XCTAssertEqual(TaskType.conversation.expectedResponseLength, .short)
        XCTAssertEqual(TaskType.general.expectedResponseLength, .short)
        // Medium
        for task in [TaskType.factual, .simpleQA, .math, .mathLogic, .translation,
                     .codeAnalysis, .codeExplanation, .codeRefactoring, .unknown] {
            XCTAssertEqual(task.expectedResponseLength, .medium, "\(task)")
        }
        // Long
        for task in [TaskType.codeGeneration, .appDevelopment, .debugging, .creative,
                     .analysis, .summarization, .planning] {
            XCTAssertEqual(task.expectedResponseLength, .long, "\(task)")
        }
    }

    // MARK: - TaskType CaseIterable & Codable

    func testTaskTypeCaseCountAndCodable() throws {
        XCTAssertGreaterThanOrEqual(TaskType.allCases.count, 27)
        for taskType in TaskType.allCases {
            let data = try JSONEncoder().encode(taskType)
            let decoded = try JSONDecoder().decode(TaskType.self, from: data)
            XCTAssertEqual(decoded, taskType)
            XCTAssertEqual(TaskType(rawValue: taskType.rawValue), taskType)
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

    func testClassificationResultConfidence() {
        let confident = ClassificationResult(
            taskType: .factual, confidence: 0.7, reasoning: nil,
            alternativeTypes: nil, suggestedModel: nil,
            timestamp: Date(), classificationMethod: .cache
        )
        XCTAssertTrue(confident.isConfident, "0.7 should be confident (threshold)")

        let highConfident = ClassificationResult(
            taskType: .codeGeneration, confidence: 0.95, reasoning: "Strong match",
            alternativeTypes: nil, suggestedModel: "claude-opus-4-5",
            timestamp: Date(), classificationMethod: .ai
        )
        XCTAssertTrue(highConfident.isConfident)

        let notConfident = ClassificationResult(
            taskType: .unknown, confidence: 0.69, reasoning: nil,
            alternativeTypes: nil, suggestedModel: nil,
            timestamp: Date(), classificationMethod: .pattern
        )
        XCTAssertFalse(notConfident.isConfident, "0.69 should NOT be confident")

        let zeroConfident = ClassificationResult(
            taskType: .unknown, confidence: 0.0, reasoning: nil,
            alternativeTypes: nil, suggestedModel: nil,
            timestamp: Date(), classificationMethod: .pattern
        )
        XCTAssertFalse(zeroConfident.isConfident)
    }

    func testClassificationResultTypeAccessors() {
        let result = ClassificationResult(
            taskType: .codeGeneration, confidence: 0.9, reasoning: nil,
            alternativeTypes: nil, suggestedModel: nil,
            timestamp: Date(), classificationMethod: .ai
        )
        XCTAssertEqual(result.primaryType, .codeGeneration)
        XCTAssertTrue(result.secondaryTypes.isEmpty)

        let withAlts = ClassificationResult(
            taskType: .analysis, confidence: 0.8, reasoning: nil,
            alternativeTypes: [(.research, 0.5), (.codeAnalysis, 0.3)],
            suggestedModel: nil, timestamp: Date(), classificationMethod: .ai
        )
        XCTAssertEqual(withAlts.secondaryTypes, [.research, .codeAnalysis])
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

    func testClassificationInsightsRates() {
        let insights = ClassificationInsights(totalClassifications: 100,
                                              confidentClassifications: 80, correctionsCount: 5)
        XCTAssertEqual(insights.confidenceRate, 0.8, accuracy: 0.001)
        XCTAssertEqual(insights.correctionRate, 0.05, accuracy: 0.001)

        let zero = ClassificationInsights(totalClassifications: 0,
                                          confidentClassifications: 0, correctionsCount: 0)
        XCTAssertEqual(zero.confidenceRate, 0)
        XCTAssertEqual(zero.correctionRate, 0)
    }

    // MARK: - Domain Confidence Thresholds (mirror TaskClassifier.swift)

    func testDomainConfidenceThresholds() {
        let thresholds: [TaskType: Double] = [
            .codeGeneration: 0.75, .codeAnalysis: 0.70, .codeDebugging: 0.75,
            .math: 0.70, .factual: 0.65, .creative: 0.55,
            .conversation: 0.50, .system: 0.70
        ]
        XCTAssertGreaterThan(thresholds[.codeGeneration]!, thresholds[.creative]!)
        XCTAssertGreaterThan(thresholds[.codeDebugging]!, thresholds[.conversation]!)
        XCTAssertLessThan(thresholds[.creative]!, thresholds[.math]!)
        XCTAssertEqual(thresholds[.conversation]!, 0.50)
    }
}
