@testable import TheaCore
import XCTest

/// Tests for TaskType properties and ClassificationResult logic
@MainActor
final class TaskClassifierTests: XCTestCase {

    // MARK: - TaskType Description Tests

    func testTaskTypeDescriptions() {
        XCTAssertFalse(TaskType.codeGeneration.description.isEmpty)
        XCTAssertFalse(TaskType.factual.description.isEmpty)
        XCTAssertFalse(TaskType.creative.description.isEmpty)
        XCTAssertFalse(TaskType.analysis.description.isEmpty)
        XCTAssertFalse(TaskType.unknown.description.isEmpty)
    }

    func testTaskTypeDisplayNameMatchesDescription() {
        for taskType in [TaskType.codeGeneration, .factual, .creative, .analysis, .research, .planning] {
            XCTAssertEqual(taskType.displayName, taskType.description)
        }
    }

    // MARK: - BenefitsFromReasoning Tests

    func testBenefitsFromReasoningCodeTasks() {
        XCTAssertTrue(TaskType.codeDebugging.benefitsFromReasoning)
        XCTAssertTrue(TaskType.codeRefactoring.benefitsFromReasoning)
        XCTAssertTrue(TaskType.debugging.benefitsFromReasoning)
    }

    func testBenefitsFromReasoningAnalysisTasks() {
        XCTAssertTrue(TaskType.analysis.benefitsFromReasoning)
        XCTAssertTrue(TaskType.math.benefitsFromReasoning)
        XCTAssertTrue(TaskType.planning.benefitsFromReasoning)
    }

    func testBenefitsFromReasoningFalseForSimpleTasks() {
        XCTAssertFalse(TaskType.conversation.benefitsFromReasoning)
        XCTAssertFalse(TaskType.factual.benefitsFromReasoning)
        XCTAssertFalse(TaskType.translation.benefitsFromReasoning)
        XCTAssertFalse(TaskType.creative.benefitsFromReasoning)
    }

    // MARK: - IsSimple Tests

    func testIsSimpleForSimpleTasks() {
        XCTAssertTrue(TaskType.conversation.isSimple)
        XCTAssertTrue(TaskType.factual.isSimple)
        XCTAssertTrue(TaskType.translation.isSimple)
    }

    func testIsSimpleFalseForComplexTasks() {
        XCTAssertFalse(TaskType.codeGeneration.isSimple)
        XCTAssertFalse(TaskType.analysis.isSimple)
        XCTAssertFalse(TaskType.planning.isSimple)
        XCTAssertFalse(TaskType.codeDebugging.isSimple)
    }

    // MARK: - IsActionable Tests

    func testIsActionableForCodeTasks() {
        XCTAssertTrue(TaskType.codeGeneration.isActionable)
        XCTAssertTrue(TaskType.codeRefactoring.isActionable)
        XCTAssertTrue(TaskType.codeDebugging.isActionable)
    }

    func testIsActionableForSystemAndPlanning() {
        XCTAssertTrue(TaskType.system.isActionable)
        XCTAssertTrue(TaskType.planning.isActionable)
    }

    func testIsActionableFalseForPassiveTasks() {
        XCTAssertFalse(TaskType.factual.isActionable)
        XCTAssertFalse(TaskType.creative.isActionable)
        XCTAssertFalse(TaskType.conversation.isActionable)
        XCTAssertFalse(TaskType.research.isActionable)
    }

    // MARK: - NeedsWebSearch Tests

    func testNeedsWebSearchForResearchTasks() {
        XCTAssertTrue(TaskType.research.needsWebSearch)
        XCTAssertTrue(TaskType.factual.needsWebSearch)
    }

    func testNeedsWebSearchFalseForCodeTasks() {
        XCTAssertFalse(TaskType.codeGeneration.needsWebSearch)
        XCTAssertFalse(TaskType.codeDebugging.needsWebSearch)
        XCTAssertFalse(TaskType.creative.needsWebSearch)
    }

    // MARK: - PreferredCapabilities Tests

    func testCodeTasksPreferCodeGeneration() {
        let caps = TaskType.codeGeneration.preferredCapabilities
        XCTAssertTrue(caps.contains(.codeGeneration))
        XCTAssertTrue(caps.contains(.chat))
    }

    func testAnalysisTasksPreferReasoning() {
        let caps = TaskType.analysis.preferredCapabilities
        XCTAssertTrue(caps.contains(.reasoning))
    }

    func testSystemTasksPreferFunctionCalling() {
        let caps = TaskType.system.preferredCapabilities
        XCTAssertTrue(caps.contains(.functionCalling))
    }

    // MARK: - ExpectedResponseLength Tests

    func testShortResponseForSimpleTasks() {
        XCTAssertEqual(TaskType.conversation.expectedResponseLength, .short)
        XCTAssertEqual(TaskType.factual.expectedResponseLength, .short)
    }

    func testLongResponseForCodeGeneration() {
        XCTAssertEqual(TaskType.codeGeneration.expectedResponseLength, .long)
    }

    func testResponseLengthTokenLimits() {
        XCTAssertEqual(ResponseLength.short.maxTokens, 500)
        XCTAssertEqual(ResponseLength.medium.maxTokens, 2000)
        XCTAssertEqual(ResponseLength.long.maxTokens, 8000)
    }

    // MARK: - Legacy Alias Tests

    func testLegacyAliases() {
        XCTAssertEqual(TaskType.simpleQA.description, TaskType.factual.description)
        XCTAssertEqual(TaskType.creativeWriting.description, TaskType.creative.description)
        XCTAssertEqual(TaskType.mathLogic.description, TaskType.math.description)
    }

    // MARK: - ClassificationResult Tests

    func testClassificationResultIsConfident() {
        let result = ClassificationResult(
            taskType: .codeGeneration,
            confidence: 0.85,
            reasoning: "Code-related query",
            alternativeTypes: nil,
            suggestedModel: nil,
            timestamp: Date(),
            classificationMethod: .ai
        )
        XCTAssertTrue(result.isConfident)
    }

    func testClassificationResultNotConfident() {
        let result = ClassificationResult(
            taskType: .unknown,
            confidence: 0.4,
            reasoning: nil,
            alternativeTypes: nil,
            suggestedModel: nil,
            timestamp: Date(),
            classificationMethod: .pattern
        )
        XCTAssertFalse(result.isConfident)
    }

    func testClassificationResultBoundaryConfidence() {
        let result = ClassificationResult(
            taskType: .factual,
            confidence: 0.7,
            reasoning: nil,
            alternativeTypes: nil,
            suggestedModel: nil,
            timestamp: Date(),
            classificationMethod: .cache
        )
        XCTAssertTrue(result.isConfident) // Exactly 0.7 should be confident
    }

    func testClassificationMethodTypes() {
        XCTAssertNotEqual(ClassificationMethodType.ai, .embedding)
        XCTAssertNotEqual(ClassificationMethodType.pattern, .cache)
    }

    // MARK: - TaskClassifier Singleton Tests

    func testTaskClassifierSharedInstance() {
        let classifier = TaskClassifier.shared
        XCTAssertNotNil(classifier)
        XCTAssertTrue(classifier === TaskClassifier.shared)
    }

    func testTaskClassifierDefaultThreshold() {
        let classifier = TaskClassifier.shared
        XCTAssertEqual(classifier.confidenceThreshold, 0.6)
    }
}
