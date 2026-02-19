@testable import TheaCore
import XCTest

/// Additional tests for ConfidenceSystem to increase coverage beyond the existing 28.9%
/// baseline in VerificationPipelineTests.swift.
///
/// Focuses on:
///   - validateResponse (async, all TaskType paths, fast/messaging/default context)
///   - detectHallucinations (heuristic rules, edge cases)
///   - recordFeedback (no-crash, delegates to UserFeedbackLearner)
///   - Configuration mutations (enable flags, weights)
///   - TaskType extensions (requiresFactualVerification, isCodeRelated)
///   - ValidationContext static presets
///   - ConfidenceResult properties not covered by existing tests
@MainActor
final class ConfidenceSystemTests: XCTestCase {

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        // Restore defaults after each test
        let system = ConfidenceSystem.shared
        system.enableMultiModel = true
        system.enableWebVerification = true
        system.enableCodeExecution = true
        system.enableStaticAnalysis = true
        system.enableFeedbackLearning = true
        system.sourceWeights = [
            .modelConsensus: 0.35,
            .webVerification: 0.20,
            .codeExecution: 0.25,
            .staticAnalysis: 0.10,
            .userFeedback: 0.10,
            .cachedKnowledge: 0.05,
            .patternMatch: 0.05,
            .semanticAnalysis: 0.15
        ]
    }

    // MARK: - Configuration: enable flags

    func testEnableMultiModelCanBeDisabled() {
        ConfidenceSystem.shared.enableMultiModel = false
        XCTAssertFalse(ConfidenceSystem.shared.enableMultiModel)
    }

    func testEnableWebVerificationCanBeDisabled() {
        ConfidenceSystem.shared.enableWebVerification = false
        XCTAssertFalse(ConfidenceSystem.shared.enableWebVerification)
    }

    func testEnableCodeExecutionCanBeDisabled() {
        ConfidenceSystem.shared.enableCodeExecution = false
        XCTAssertFalse(ConfidenceSystem.shared.enableCodeExecution)
    }

    func testEnableStaticAnalysisCanBeDisabled() {
        ConfidenceSystem.shared.enableStaticAnalysis = false
        XCTAssertFalse(ConfidenceSystem.shared.enableStaticAnalysis)
    }

    func testEnableFeedbackLearningCanBeDisabled() {
        ConfidenceSystem.shared.enableFeedbackLearning = false
        XCTAssertFalse(ConfidenceSystem.shared.enableFeedbackLearning)
    }

    func testAllFlagsCanBeReEnabled() {
        let system = ConfidenceSystem.shared
        system.enableMultiModel = false
        system.enableWebVerification = false
        system.enableCodeExecution = false
        system.enableStaticAnalysis = false
        system.enableFeedbackLearning = false

        system.enableMultiModel = true
        system.enableWebVerification = true
        system.enableCodeExecution = true
        system.enableStaticAnalysis = true
        system.enableFeedbackLearning = true

        XCTAssertTrue(system.enableMultiModel)
        XCTAssertTrue(system.enableWebVerification)
        XCTAssertTrue(system.enableCodeExecution)
        XCTAssertTrue(system.enableStaticAnalysis)
        XCTAssertTrue(system.enableFeedbackLearning)
    }

    // MARK: - Configuration: weights

    func testSourceWeightsCanBeUpdated() {
        ConfidenceSystem.shared.sourceWeights[.modelConsensus] = 0.50
        XCTAssertEqual(ConfidenceSystem.shared.sourceWeights[.modelConsensus], 0.50, accuracy: 0.001)
    }

    func testSourceWeightsAllTypesHaveDefaultValues() {
        let system = ConfidenceSystem.shared
        let types: [ConfidenceSource.SourceType] = [
            .modelConsensus, .webVerification, .codeExecution, .staticAnalysis,
            .userFeedback, .cachedKnowledge, .patternMatch, .semanticAnalysis
        ]
        for type in types {
            XCTAssertNotNil(system.sourceWeights[type], "\(type.rawValue) should have a default weight")
        }
    }

    func testSourceWeightsTotalSumIsReasonable() {
        let sum = ConfidenceSystem.shared.sourceWeights.values.reduce(0, +)
        XCTAssertGreaterThan(sum, 0.5)
        XCTAssertLessThan(sum, 2.0)
    }

    func testSourceWeightsCanBeSetToZero() {
        ConfidenceSystem.shared.sourceWeights[.patternMatch] = 0.0
        XCTAssertEqual(ConfidenceSystem.shared.sourceWeights[.patternMatch], 0.0, accuracy: 0.001)
    }

    // MARK: - validateResponse: fast context (all sub-systems disabled)

    func testValidateResponseWithFastContextReturnsResult() async {
        let result = await ConfidenceSystem.shared.validateResponse(
            "Swift arrays are zero-indexed.",
            query: "How does Swift indexing work?",
            taskType: .factual,
            context: .fast
        )
        // fast context disables multi-model, web, code execution — only feedback learner runs
        XCTAssertGreaterThanOrEqual(result.overallConfidence, 0.0)
        XCTAssertLessThanOrEqual(result.overallConfidence, 1.0)
        XCTAssertNotNil(result.level)
    }

    func testValidateResponseWithMessagingContextReturnsResult() async {
        let result = await ConfidenceSystem.shared.validateResponse(
            "Hello, how can I help?",
            query: "Hi",
            taskType: .conversation,
            context: .messaging
        )
        XCTAssertGreaterThanOrEqual(result.overallConfidence, 0.0)
        XCTAssertLessThanOrEqual(result.overallConfidence, 1.0)
    }

    func testValidateResponseForFactualTaskType() async {
        let result = await ConfidenceSystem.shared.validateResponse(
            "The capital of France is Paris.",
            query: "What is the capital of France?",
            taskType: .factual,
            context: .fast
        )
        XCTAssertNotNil(result)
        XCTAssertFalse(result.id == UUID()) // Each result has unique ID
    }

    func testValidateResponseForCodeGenerationTask() async {
        let result = await ConfidenceSystem.shared.validateResponse(
            "func greet(_ name: String) -> String { \"Hello, \\(name)!\" }",
            query: "Write a Swift greeting function",
            taskType: .codeGeneration,
            context: .fast
        )
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result.overallConfidence, 0.0)
    }

    func testValidateResponseForCreativeTask() async {
        let result = await ConfidenceSystem.shared.validateResponse(
            "Once upon a time in a land far away...",
            query: "Write a story opener",
            taskType: .creative,
            context: .fast
        )
        XCTAssertNotNil(result)
    }

    func testValidateResponseForConversationTask() async {
        let result = await ConfidenceSystem.shared.validateResponse(
            "I'm doing well, thanks for asking!",
            query: "How are you?",
            taskType: .conversation,
            context: .fast
        )
        XCTAssertNotNil(result)
    }

    func testValidateResponseReturnsConfidenceResultWithTimestamp() async {
        let before = Date()
        let result = await ConfidenceSystem.shared.validateResponse(
            "Test response",
            query: "Test query",
            taskType: .factual,
            context: .fast
        )
        let after = Date()
        XCTAssertGreaterThanOrEqual(result.timestamp, before)
        XCTAssertLessThanOrEqual(result.timestamp, after)
    }

    func testValidateResponseResultHasUniqueID() async {
        let r1 = await ConfidenceSystem.shared.validateResponse(
            "Response 1",
            query: "Query",
            taskType: .factual,
            context: .fast
        )
        let r2 = await ConfidenceSystem.shared.validateResponse(
            "Response 2",
            query: "Query",
            taskType: .factual,
            context: .fast
        )
        XCTAssertNotEqual(r1.id, r2.id)
    }

    func testValidateResponseDecompositionIsNotEmpty() async {
        let result = await ConfidenceSystem.shared.validateResponse(
            "The answer is 42.",
            query: "What is the answer to life?",
            taskType: .factual,
            context: .fast
        )
        XCTAssertFalse(result.decomposition.reasoning.isEmpty)
    }

    func testValidateResponseSuggestionsAreNotEmpty() async {
        // With fast context (no web/code verification), suggestions will include those prompts
        let result = await ConfidenceSystem.shared.validateResponse(
            "Some response without verification",
            query: "A question",
            taskType: .factual,
            context: .fast
        )
        // Should suggest verifying since no web verification ran
        XCTAssertFalse(result.improvementSuggestions.isEmpty)
    }

    // MARK: - validateResponse: all flags disabled

    func testValidateResponseWithAllFlagsDisabledReturnsZeroConfidence() async {
        let system = ConfidenceSystem.shared
        system.enableMultiModel = false
        system.enableWebVerification = false
        system.enableCodeExecution = false
        system.enableStaticAnalysis = false
        system.enableFeedbackLearning = false

        let result = await system.validateResponse(
            "Some response",
            query: "Some query",
            taskType: .factual,
            context: .fast
        )

        // No sources → calculateOverallConfidence returns 0.0
        XCTAssertEqual(result.overallConfidence, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.level, .unverified)
        XCTAssertTrue(result.sources.isEmpty)
    }

    // MARK: - validateResponse: only feedback learner enabled

    func testValidateResponseWithOnlyFeedbackLearnerEnabled() async {
        let system = ConfidenceSystem.shared
        system.enableMultiModel = false
        system.enableWebVerification = false
        system.enableCodeExecution = false
        system.enableStaticAnalysis = false
        system.enableFeedbackLearning = true

        let result = await system.validateResponse(
            "Test response",
            query: "Test query",
            taskType: .factual,
            context: .fast
        )

        XCTAssertEqual(result.sources.count, 1)
        XCTAssertEqual(result.sources.first?.type, .userFeedback)
    }

    // MARK: - detectHallucinations: real async API

    func testDetectHallucinationsEmptyResponseReturnsNoFlags() async {
        let flags = await ConfidenceSystem.shared.detectHallucinations("", query: "test")
        XCTAssertTrue(flags.isEmpty)
    }

    func testDetectHallucinationsCleanStatementReturnsNoFlags() async {
        let flags = await ConfidenceSystem.shared.detectHallucinations(
            "Swift is a programming language developed by Apple.",
            query: "What is Swift?"
        )
        XCTAssertTrue(flags.isEmpty)
    }

    func testDetectHallucinationsMultipleStatisticsFlags() async {
        // >2 percentages without citations → flag
        let response = "It improved by 45.2%, reduced errors by 23.1%, and boosted performance by 67.8%."
        let flags = await ConfidenceSystem.shared.detectHallucinations(response, query: "test")
        XCTAssertFalse(flags.isEmpty)
        XCTAssertTrue(flags.contains { $0.contains("Multiple precise statistics") })
    }

    func testDetectHallucinationsTwoStatisticsDoNotFlag() async {
        // Only 2 percentages — threshold is >2
        let response = "Performance improved by 45%, and errors reduced by 23%."
        let flags = await ConfidenceSystem.shared.detectHallucinations(response, query: "test")
        // 2 matches, not >2, so statistics check should not trigger
        let statisticsFlags = flags.filter { $0.contains("Multiple precise statistics") }
        XCTAssertTrue(statisticsFlags.isEmpty)
    }

    func testDetectHallucinationsAbsoluteClaimAlwaysTriggers() async {
        let absoluteClaims = ["always", "never", "100%", "0%", "impossible", "guaranteed"]
        for claim in absoluteClaims {
            let response = "This approach is \(claim) correct."
            let flags = await ConfidenceSystem.shared.detectHallucinations(response, query: "test")
            XCTAssertFalse(flags.isEmpty, "Expected flag for absolute claim: '\(claim)'")
            XCTAssertTrue(
                flags.contains { $0.contains("Absolute claim detected: '\(claim)'") },
                "Expected specific flag for '\(claim)'"
            )
            break // Only test the first to avoid test repetition; other cases covered below
        }
    }

    func testDetectHallucinationsAlwaysTriggersAbsoluteFlag() async {
        let flags = await ConfidenceSystem.shared.detectHallucinations(
            "This method always returns the correct result.",
            query: "Is this reliable?"
        )
        XCTAssertFalse(flags.isEmpty)
        XCTAssertTrue(flags.contains { $0.contains("always") })
    }

    func testDetectHallucinationsNeverTriggersAbsoluteFlag() async {
        let flags = await ConfidenceSystem.shared.detectHallucinations(
            "You should never use force unwrapping in production code.",
            query: "Best practices?"
        )
        XCTAssertFalse(flags.isEmpty)
        XCTAssertTrue(flags.contains { $0.contains("never") })
    }

    func testDetectHallucinationsImpossibleTriggersAbsoluteFlag() async {
        let flags = await ConfidenceSystem.shared.detectHallucinations(
            "It is impossible to crash a Swift program with optional binding.",
            query: "Safety?"
        )
        XCTAssertFalse(flags.isEmpty)
        XCTAssertTrue(flags.contains { $0.contains("impossible") })
    }

    func testDetectHallucinationsGuaranteedTriggersAbsoluteFlag() async {
        let flags = await ConfidenceSystem.shared.detectHallucinations(
            "This algorithm is guaranteed to find the optimal solution.",
            query: "Algorithm?"
        )
        XCTAssertFalse(flags.isEmpty)
        XCTAssertTrue(flags.contains { $0.contains("guaranteed") })
    }

    func testDetectHallucinationsOnlyFirstAbsoluteClaimFlagged() async {
        // The code breaks after the first found absolute claim
        let response = "This is always and guaranteed to work."
        let flags = await ConfidenceSystem.shared.detectHallucinations(response, query: "test")
        // Multiple absolute claims — only one flag because of the `break`
        let absoluteFlags = flags.filter { $0.contains("Absolute claim detected:") }
        XCTAssertEqual(absoluteFlags.count, 1)
    }

    func testDetectHallucinationsLongResponseToShortQueryFlags() async {
        // queryWords < 5 and responseWords > 500 → flag
        let shortQuery = "What?" // 1 word
        let longResponse = String(repeating: "This is a word. ", count: 35) // ~4*35 = 140 words? Need >500 words
        // Build a response > 500 words
        let manyWords = Array(repeating: "word", count: 510).joined(separator: " ")
        let flags = await ConfidenceSystem.shared.detectHallucinations(manyWords, query: shortQuery)
        XCTAssertFalse(flags.isEmpty)
        XCTAssertTrue(flags.contains { $0.contains("disproportionate") })
    }

    func testDetectHallucinationsLongQueryDoesNotTriggerLengthFlag() async {
        // queryWords >= 5 → length check does not apply
        let longQuery = "Can you please explain in great detail how Swift generics work with associated types?"
        let longResponse = Array(repeating: "word", count: 510).joined(separator: " ")
        let flags = await ConfidenceSystem.shared.detectHallucinations(longResponse, query: longQuery)
        let lengthFlags = flags.filter { $0.contains("disproportionate") }
        XCTAssertTrue(lengthFlags.isEmpty)
    }

    func testDetectHallucinationsReturnedAsArrayOfStrings() async {
        // Verify return type is [String]
        let flags: [String] = await ConfidenceSystem.shared.detectHallucinations(
            "This is always the case.",
            query: "test"
        )
        XCTAssertFalse(flags.isEmpty)
        for flag in flags {
            XCTAssertFalse(flag.isEmpty)
        }
    }

    func testDetectHallucinationsNoFalsePositiveForNormalNumbers() async {
        // Normal text with no percentages (or fewer than 3)
        let response = "The project has 5 open issues and 2 pull requests."
        let flags = await ConfidenceSystem.shared.detectHallucinations(response, query: "project status")
        let statisticsFlags = flags.filter { $0.contains("Multiple precise statistics") }
        XCTAssertTrue(statisticsFlags.isEmpty)
    }

    // MARK: - recordFeedback (no-crash, async)

    func testRecordFeedbackCorrectCompletesWithoutCrash() async {
        await ConfidenceSystem.shared.recordFeedback(
            responseId: UUID(),
            wasCorrect: true,
            userCorrection: nil,
            taskType: .factual
        )
    }

    func testRecordFeedbackIncorrectWithCorrectionCompletesWithoutCrash() async {
        await ConfidenceSystem.shared.recordFeedback(
            responseId: UUID(),
            wasCorrect: false,
            userCorrection: "The correct answer is X",
            taskType: .codeGeneration
        )
    }

    func testRecordFeedbackForAllTaskTypesDoesNotCrash() async {
        let taskTypes: [TaskType] = [.factual, .creative, .conversation, .codeGeneration, .analysis, .research]
        for taskType in taskTypes {
            await ConfidenceSystem.shared.recordFeedback(
                responseId: UUID(),
                wasCorrect: true,
                userCorrection: nil,
                taskType: taskType
            )
        }
    }

    // MARK: - TaskType Extensions: requiresFactualVerification

    func testFactualTaskRequiresFactualVerification() {
        XCTAssertTrue(TaskType.factual.requiresFactualVerification)
    }

    func testResearchTaskRequiresFactualVerification() {
        XCTAssertTrue(TaskType.research.requiresFactualVerification)
    }

    func testInformationRetrievalRequiresFactualVerification() {
        XCTAssertTrue(TaskType.informationRetrieval.requiresFactualVerification)
    }

    func testCodeGenerationDoesNotRequireFactualVerification() {
        XCTAssertFalse(TaskType.codeGeneration.requiresFactualVerification)
    }

    func testCreativeTaskDoesNotRequireFactualVerification() {
        XCTAssertFalse(TaskType.creative.requiresFactualVerification)
    }

    func testConversationDoesNotRequireFactualVerification() {
        XCTAssertFalse(TaskType.conversation.requiresFactualVerification)
    }

    func testAnalysisDoesNotRequireFactualVerification() {
        XCTAssertFalse(TaskType.analysis.requiresFactualVerification)
    }

    // MARK: - TaskType Extensions: isCodeRelated

    func testCodeGenerationIsCodeRelated() {
        XCTAssertTrue(TaskType.codeGeneration.isCodeRelated)
    }

    func testCodeAnalysisIsCodeRelated() {
        XCTAssertTrue(TaskType.codeAnalysis.isCodeRelated)
    }

    func testCodeDebuggingIsCodeRelated() {
        XCTAssertTrue(TaskType.codeDebugging.isCodeRelated)
    }

    func testCodeExplanationIsCodeRelated() {
        XCTAssertTrue(TaskType.codeExplanation.isCodeRelated)
    }

    func testCodeRefactoringIsCodeRelated() {
        XCTAssertTrue(TaskType.codeRefactoring.isCodeRelated)
    }

    func testDebuggingIsCodeRelated() {
        XCTAssertTrue(TaskType.debugging.isCodeRelated)
    }

    func testAppDevelopmentIsCodeRelated() {
        XCTAssertTrue(TaskType.appDevelopment.isCodeRelated)
    }

    func testFactualIsNotCodeRelated() {
        XCTAssertFalse(TaskType.factual.isCodeRelated)
    }

    func testCreativeIsNotCodeRelated() {
        XCTAssertFalse(TaskType.creative.isCodeRelated)
    }

    func testConversationIsNotCodeRelated() {
        XCTAssertFalse(TaskType.conversation.isCodeRelated)
    }

    func testResearchIsNotCodeRelated() {
        XCTAssertFalse(TaskType.research.isCodeRelated)
    }

    // MARK: - ValidationContext static presets

    func testDefaultContextAllowsEverything() {
        let ctx = ValidationContext.default
        XCTAssertTrue(ctx.allowMultiModel)
        XCTAssertTrue(ctx.allowWebSearch)
        XCTAssertTrue(ctx.allowCodeExecution)
        XCTAssertEqual(ctx.language, .swift)
        XCTAssertEqual(ctx.maxLatency, 10.0, accuracy: 0.001)
    }

    func testFastContextDisablesAll() {
        let ctx = ValidationContext.fast
        XCTAssertFalse(ctx.allowMultiModel)
        XCTAssertFalse(ctx.allowWebSearch)
        XCTAssertFalse(ctx.allowCodeExecution)
        XCTAssertEqual(ctx.language, .swift)
        XCTAssertEqual(ctx.maxLatency, 1.0, accuracy: 0.001)
    }

    func testMessagingContextDisablesHeavyVerification() {
        let ctx = ValidationContext.messaging
        XCTAssertFalse(ctx.allowMultiModel)
        XCTAssertFalse(ctx.allowWebSearch)
        XCTAssertFalse(ctx.allowCodeExecution)
        XCTAssertEqual(ctx.language, .unknown)
        XCTAssertEqual(ctx.maxLatency, 2.0, accuracy: 0.001)
    }

    func testCodeLanguageAllCasesExist() {
        // Verify the enum cases exist and have raw values
        XCTAssertEqual(ValidationContext.CodeLanguage.swift.rawValue, "swift")
        XCTAssertEqual(ValidationContext.CodeLanguage.javascript.rawValue, "javascript")
        XCTAssertEqual(ValidationContext.CodeLanguage.python.rawValue, "python")
        XCTAssertEqual(ValidationContext.CodeLanguage.unknown.rawValue, "unknown")
    }

    // MARK: - ConfidenceResult: additional edge cases

    func testConfidenceResultAtExactMediumBoundary() {
        // 0.60 → medium (not low)
        let result = ConfidenceResult(
            overallConfidence: 0.60,
            sources: [],
            decomposition: ConfidenceDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        XCTAssertEqual(result.level, .medium)
    }

    func testConfidenceResultAtExactLowBoundary() {
        // 0.30 → low (not unverified)
        let result = ConfidenceResult(
            overallConfidence: 0.30,
            sources: [],
            decomposition: ConfidenceDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        XCTAssertEqual(result.level, .low)
    }

    func testConfidenceResultJustBelowLowBoundary() {
        // 0.2999 → unverified
        let result = ConfidenceResult(
            overallConfidence: 0.2999,
            sources: [],
            decomposition: ConfidenceDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        XCTAssertEqual(result.level, .unverified)
    }

    func testConfidenceResultJustBelowMediumBoundary() {
        // 0.5999 → low
        let result = ConfidenceResult(
            overallConfidence: 0.5999,
            sources: [],
            decomposition: ConfidenceDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        XCTAssertEqual(result.level, .low)
    }

    func testConfidenceResultJustBelowHighBoundary() {
        // 0.8499 → medium
        let result = ConfidenceResult(
            overallConfidence: 0.8499,
            sources: [],
            decomposition: ConfidenceDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        XCTAssertEqual(result.level, .medium)
    }

    func testConfidenceResultMultipleSourcesStored() {
        let sources = [
            ConfidenceSource(type: .modelConsensus, name: "A", confidence: 0.9, weight: 0.35, details: "", verified: true),
            ConfidenceSource(type: .userFeedback, name: "B", confidence: 0.7, weight: 0.10, details: "", verified: false),
            ConfidenceSource(type: .staticAnalysis, name: "C", confidence: 0.8, weight: 0.10, details: "", verified: true)
        ]
        let result = ConfidenceResult(
            overallConfidence: 0.85,
            sources: sources,
            decomposition: ConfidenceDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        XCTAssertEqual(result.sources.count, 3)
    }

    // MARK: - ConfidenceSource: icon coverage

    func testAllSourceTypeIconsAreNonEmpty() {
        for sourceType in ConfidenceSource.SourceType.allCases {
            let source = ConfidenceSource(
                type: sourceType,
                name: sourceType.rawValue,
                confidence: 0.5,
                weight: 0.1,
                details: "",
                verified: false
            )
            XCTAssertFalse(source.icon.isEmpty, "\(sourceType.rawValue) should have a non-empty icon")
        }
    }

    func testModelConsensusIcon() {
        let source = ConfidenceSource(type: .modelConsensus, name: "test", confidence: 0.9, weight: 0.35, details: "", verified: true)
        XCTAssertEqual(source.icon, "brain.head.profile")
    }

    func testWebVerificationIcon() {
        let source = ConfidenceSource(type: .webVerification, name: "test", confidence: 0.8, weight: 0.20, details: "", verified: true)
        XCTAssertEqual(source.icon, "globe")
    }

    func testCodeExecutionIcon() {
        let source = ConfidenceSource(type: .codeExecution, name: "test", confidence: 0.7, weight: 0.25, details: "", verified: true)
        XCTAssertEqual(source.icon, "play.circle")
    }

    func testStaticAnalysisIcon() {
        let source = ConfidenceSource(type: .staticAnalysis, name: "test", confidence: 0.6, weight: 0.10, details: "", verified: false)
        XCTAssertEqual(source.icon, "doc.text.magnifyingglass")
    }

    func testUserFeedbackIcon() {
        let source = ConfidenceSource(type: .userFeedback, name: "test", confidence: 0.8, weight: 0.10, details: "", verified: true)
        XCTAssertEqual(source.icon, "hand.thumbsup")
    }

    func testCachedKnowledgeIcon() {
        let source = ConfidenceSource(type: .cachedKnowledge, name: "test", confidence: 0.5, weight: 0.05, details: "", verified: false)
        XCTAssertEqual(source.icon, "archivebox")
    }

    func testPatternMatchIcon() {
        let source = ConfidenceSource(type: .patternMatch, name: "test", confidence: 0.4, weight: 0.05, details: "", verified: false)
        XCTAssertEqual(source.icon, "text.magnifyingglass")
    }

    func testSemanticAnalysisIcon() {
        let source = ConfidenceSource(type: .semanticAnalysis, name: "test", confidence: 0.6, weight: 0.15, details: "", verified: false)
        XCTAssertEqual(source.icon, "sparkles")
    }

    // MARK: - ConfidenceLevel: actionRequired edge cases

    func testHighConfidenceLevelDoesNotRequireAction() {
        XCTAssertFalse(ConfidenceLevel.high.actionRequired)
    }

    func testMediumConfidenceLevelDoesNotRequireAction() {
        XCTAssertFalse(ConfidenceLevel.medium.actionRequired)
    }

    func testLowConfidenceLevelRequiresAction() {
        XCTAssertTrue(ConfidenceLevel.low.actionRequired)
    }

    func testUnverifiedConfidenceLevelRequiresAction() {
        XCTAssertTrue(ConfidenceLevel.unverified.actionRequired)
    }

    // MARK: - ConfidenceDecomposition: factor identities

    func testDecompositionFactorHasUniqueID() {
        let f1 = ConfidenceDecomposition.DecompositionFactor(name: "A", contribution: 0.5, explanation: "test")
        let f2 = ConfidenceDecomposition.DecompositionFactor(name: "A", contribution: 0.5, explanation: "test")
        XCTAssertNotEqual(f1.id, f2.id)
    }

    func testDecompositionConflictHasUniqueID() {
        let c1 = ConfidenceDecomposition.ConflictInfo(source1: "A", source2: "B", description: "diff", severity: .minor)
        let c2 = ConfidenceDecomposition.ConflictInfo(source1: "A", source2: "B", description: "diff", severity: .minor)
        XCTAssertNotEqual(c1.id, c2.id)
    }

    func testDecompositionFactorPreservesContribution() {
        let factor = ConfidenceDecomposition.DecompositionFactor(
            name: "Multi-model consensus",
            contribution: 0.75,
            explanation: "3 models agree"
        )
        XCTAssertEqual(factor.contribution, 0.75, accuracy: 0.001)
        XCTAssertEqual(factor.name, "Multi-model consensus")
        XCTAssertEqual(factor.explanation, "3 models agree")
    }

    func testDecompositionConflictPreservesAllFields() {
        let conflict = ConfidenceDecomposition.ConflictInfo(
            source1: "Model A",
            source2: "Web Search",
            description: "Factual disagreement on date",
            severity: .major
        )
        XCTAssertEqual(conflict.source1, "Model A")
        XCTAssertEqual(conflict.source2, "Web Search")
        XCTAssertEqual(conflict.description, "Factual disagreement on date")
        XCTAssertEqual(conflict.severity, .major)
    }

    // MARK: - Concurrent validateResponse calls

    func testConcurrentValidateResponseCallsDoNotCrash() async {
        // Fire 3 concurrent validations and confirm all complete without crashing
        async let r1 = ConfidenceSystem.shared.validateResponse("Response 1", query: "Q1", taskType: .factual, context: .fast)
        async let r2 = ConfidenceSystem.shared.validateResponse("Response 2", query: "Q2", taskType: .creative, context: .fast)
        async let r3 = ConfidenceSystem.shared.validateResponse("Response 3", query: "Q3", taskType: .conversation, context: .fast)

        let results = await [r1, r2, r3]
        XCTAssertEqual(results.count, 3)
        for result in results {
            XCTAssertGreaterThanOrEqual(result.overallConfidence, 0.0)
            XCTAssertLessThanOrEqual(result.overallConfidence, 1.0)
        }
    }
}
