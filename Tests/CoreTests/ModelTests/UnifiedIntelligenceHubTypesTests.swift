// UnifiedIntelligenceHubTypesTests.swift
// Tests for UnifiedIntelligenceHub types (standalone test doubles)

import Testing
import Foundation

// MARK: - Intelligence Pattern Test Doubles

private enum TestPatternType: String, Sendable, CaseIterable {
    case workflow, temporal, contextSwitch, queryStyle
    case errorRecovery, learningProgress, productivity, preference
}

private struct TestIntelligencePattern: Identifiable, Sendable {
    let id: UUID
    let type: TestPatternType
    let description: String
    let confidence: Double
    let occurrences: Int
    let firstSeen: Date
    let lastSeen: Date
    let metadata: [String: String]

    init(
        id: UUID = UUID(), type: TestPatternType, description: String,
        confidence: Double, occurrences: Int = 1,
        firstSeen: Date = Date(), lastSeen: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.confidence = confidence
        self.occurrences = occurrences
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.metadata = metadata
    }
}

// MARK: - Unified Suggestion Test Doubles

private enum TestSuggestionSource: String, Sendable, CaseIterable {
    case proactiveEngine, blockerAnticipator, goalProgress
    case workflowAutomation, memoryInsight, contextPrediction, causalAnalysis
}

private enum TestSuggestionAction: Sendable {
    case showMessage(String)
    case executeWorkflow(workflowId: String)
    case loadContext(resources: [String])
    case suggestBreak(duration: TimeInterval)
    case offerHelp(topic: String)
    case switchModel(modelId: String)
    case preloadResources([String])
}

private enum TestTimeSensitivity: String, Sendable, CaseIterable {
    case immediate, soon, whenIdle, scheduled, lowPriority

    var factor: Double {
        switch self {
        case .immediate: 1.0
        case .soon: 0.8
        case .whenIdle: 0.5
        case .scheduled: 0.6
        case .lowPriority: 0.3
        }
    }
}

private enum TestCognitiveLoad: String, Sendable, CaseIterable {
    case minimal, low, moderate, high

    var factor: Double {
        switch self {
        case .minimal: 1.0
        case .low: 0.9
        case .moderate: 0.7
        case .high: 0.5
        }
    }
}

private struct TestUnifiedSuggestion: Identifiable, Sendable {
    let id: UUID
    let source: TestSuggestionSource
    let title: String
    let description: String
    let action: TestSuggestionAction
    let relevanceScore: Double
    let confidenceScore: Double
    let timeSensitivity: TestTimeSensitivity
    let cognitiveLoad: TestCognitiveLoad
    let expiresAt: Date?
    let metadata: [String: String]

    init(
        id: UUID = UUID(), source: TestSuggestionSource, title: String,
        description: String, action: TestSuggestionAction,
        relevanceScore: Double, confidenceScore: Double,
        timeSensitivity: TestTimeSensitivity = .whenIdle,
        cognitiveLoad: TestCognitiveLoad = .low,
        expiresAt: Date? = nil, metadata: [String: String] = [:]
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.description = description
        self.action = action
        self.relevanceScore = relevanceScore
        self.confidenceScore = confidenceScore
        self.timeSensitivity = timeSensitivity
        self.cognitiveLoad = cognitiveLoad
        self.expiresAt = expiresAt
        self.metadata = metadata
    }

    /// Combined score matching production formula
    var combinedScore: Double {
        let weights = (relevance: 0.4, confidence: 0.3, timeFactor: 0.2, loadFactor: 0.1)
        return (relevanceScore * weights.relevance) +
               (confidenceScore * weights.confidence) +
               (timeSensitivity.factor * weights.timeFactor) +
               (cognitiveLoad.factor * weights.loadFactor)
    }
}

// MARK: - Detected Blocker Test Doubles

private enum TestBlockerType: String, Sendable, CaseIterable {
    case stuckOnTask, repeatedQuery, errorLoop, resourceExhausted
    case dependencyWait, complexityOverload, toolFailure
}

private enum TestBlockerSeverity: String, Sendable, CaseIterable {
    case low, medium, high, critical
}

private struct TestBlockerContext: Sendable {
    let taskType: String?
    let timeSpent: TimeInterval
    let attemptCount: Int
    let relatedQueries: [String]
    let errorMessages: [String]

    init(
        taskType: String? = nil, timeSpent: TimeInterval = 0,
        attemptCount: Int = 1, relatedQueries: [String] = [],
        errorMessages: [String] = []
    ) {
        self.taskType = taskType
        self.timeSpent = timeSpent
        self.attemptCount = attemptCount
        self.relatedQueries = relatedQueries
        self.errorMessages = errorMessages
    }
}

private struct TestDetectedBlocker: Identifiable, Sendable {
    let id: UUID
    let type: TestBlockerType
    let description: String
    let severity: TestBlockerSeverity
    let detectedAt: Date
    let context: TestBlockerContext
    let suggestedResolutions: [String]

    init(
        id: UUID = UUID(), type: TestBlockerType, description: String,
        severity: TestBlockerSeverity, detectedAt: Date = Date(),
        context: TestBlockerContext = TestBlockerContext(),
        suggestedResolutions: [String] = []
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.severity = severity
        self.detectedAt = detectedAt
        self.context = context
        self.suggestedResolutions = suggestedResolutions
    }
}

// MARK: - Inferred Goal Test Doubles

private enum TestGoalCategory: String, Sendable, CaseIterable {
    case project, learning, productivity, problemSolving
    case creation, maintenance, exploration
}

private enum TestGoalPriority: String, Sendable, CaseIterable {
    case critical, high, medium, low, background
}

private struct TestInferredGoal: Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let category: TestGoalCategory
    let confidence: Double
    let priority: TestGoalPriority
    let deadline: Date?
    let progress: Double
    let relatedConversations: [UUID]
    let relatedProjects: [String]
    let inferredAt: Date
    let lastUpdated: Date

    init(
        id: UUID = UUID(), title: String, description: String,
        category: TestGoalCategory, confidence: Double,
        priority: TestGoalPriority = .medium, deadline: Date? = nil,
        progress: Double = 0, relatedConversations: [UUID] = [],
        relatedProjects: [String] = [],
        inferredAt: Date = Date(), lastUpdated: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.confidence = confidence
        self.priority = priority
        self.deadline = deadline
        self.progress = progress
        self.relatedConversations = relatedConversations
        self.relatedProjects = relatedProjects
        self.inferredAt = inferredAt
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Preloaded Resource Test Doubles

private enum TestResourceType: String, Sendable, CaseIterable {
    case file, conversation, memory, documentation, codeSnippet, model
}

private struct TestPreloadedResource: Identifiable, Sendable {
    let id: UUID
    let type: TestResourceType
    let identifier: String
    let relevanceScore: Double
    let loadedAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(), type: TestResourceType, identifier: String,
        relevanceScore: Double, loadedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(300)
    ) {
        self.id = id
        self.type = type
        self.identifier = identifier
        self.relevanceScore = relevanceScore
        self.loadedAt = loadedAt
        self.expiresAt = expiresAt
    }
}

// MARK: - User Model Aspect Test Double

private enum TestUserModelAspect: String, Sendable, CaseIterable {
    case communicationStyle, technicalLevel, preferredDepth, learningStyle
    case workHabits, toolPreferences, errorHandling, decisionMaking
}

// MARK: - Intelligence Context Test Double

private struct TestUserModelSnapshot: Sendable {
    let technicalLevel: Double
    let preferredVerbosity: Double
    let currentCognitiveLoad: Double
    let recentProductivity: Double

    init(
        technicalLevel: Double = 0.5, preferredVerbosity: Double = 0.5,
        currentCognitiveLoad: Double = 0.5, recentProductivity: Double = 0.5
    ) {
        self.technicalLevel = technicalLevel
        self.preferredVerbosity = preferredVerbosity
        self.currentCognitiveLoad = currentCognitiveLoad
        self.recentProductivity = recentProductivity
    }
}

private struct TestIntelligenceContext: Sendable {
    let currentQuery: String?
    let conversationId: UUID?
    let recentQueries: [String]
    let currentTaskType: String?
    let activeGoals: [TestInferredGoal]
    let userModel: TestUserModelSnapshot
    let timeOfDay: Date
    let sessionDuration: TimeInterval

    init(
        currentQuery: String? = nil, conversationId: UUID? = nil,
        recentQueries: [String] = [], currentTaskType: String? = nil,
        activeGoals: [TestInferredGoal] = [],
        userModel: TestUserModelSnapshot = TestUserModelSnapshot(),
        timeOfDay: Date = Date(), sessionDuration: TimeInterval = 0
    ) {
        self.currentQuery = currentQuery
        self.conversationId = conversationId
        self.recentQueries = recentQueries
        self.currentTaskType = currentTaskType
        self.activeGoals = activeGoals
        self.userModel = userModel
        self.timeOfDay = timeOfDay
        self.sessionDuration = sessionDuration
    }
}

// MARK: - Delivery Decision Test Double

private enum TestDeliveryDecision: Sendable {
    case now(reason: String)
    case deferred(until: Date, reason: String)

    var isImmediate: Bool {
        if case .now = self { return true }
        return false
    }
}

// MARK: - Intelligence Pattern Tests

@Suite("Intelligence Pattern — Construction")
struct IntelligencePatternTests {
    @Test("All 8 pattern types exist")
    func allPatternTypes() {
        #expect(TestPatternType.allCases.count == 8)
    }

    @Test("All pattern types have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestPatternType.allCases.map(\.rawValue))
        #expect(rawValues.count == TestPatternType.allCases.count)
    }

    @Test("Pattern preserves properties")
    func propertiesPreserved() {
        let now = Date()
        let pattern = TestIntelligencePattern(
            type: .workflow, description: "User always commits before pushing",
            confidence: 0.92, occurrences: 15,
            firstSeen: now.addingTimeInterval(-86400), lastSeen: now,
            metadata: ["frequency": "daily"]
        )
        #expect(pattern.type == .workflow)
        #expect(pattern.confidence == 0.92)
        #expect(pattern.occurrences == 15)
        #expect(pattern.metadata["frequency"] == "daily")
    }

    @Test("Pattern has unique ID")
    func uniqueID() {
        let a = TestIntelligencePattern(type: .temporal, description: "A", confidence: 0.5)
        let b = TestIntelligencePattern(type: .temporal, description: "A", confidence: 0.5)
        #expect(a.id != b.id)
    }

    @Test("Default occurrences is 1")
    func defaultOccurrences() {
        let pattern = TestIntelligencePattern(type: .preference, description: "Prefers dark mode", confidence: 0.8)
        #expect(pattern.occurrences == 1)
    }

    @Test("Default metadata is empty")
    func defaultMetadata() {
        let pattern = TestIntelligencePattern(type: .queryStyle, description: "Short queries", confidence: 0.7)
        #expect(pattern.metadata.isEmpty)
    }
}

// MARK: - Suggestion Source Tests

@Suite("Suggestion Source — Completeness")
struct SuggestionSourceTests {
    @Test("All 7 sources exist")
    func allCases() {
        #expect(TestSuggestionSource.allCases.count == 7)
    }

    @Test("All sources have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestSuggestionSource.allCases.map(\.rawValue))
        #expect(rawValues.count == TestSuggestionSource.allCases.count)
    }
}

// MARK: - Time Sensitivity Tests

@Suite("Time Sensitivity — Factors")
struct TimeSensitivityTests {
    @Test("All 5 sensitivity levels exist")
    func allCases() {
        #expect(TestTimeSensitivity.allCases.count == 5)
    }

    @Test("Immediate has highest factor (1.0)")
    func immediateFactor() {
        #expect(TestTimeSensitivity.immediate.factor == 1.0)
    }

    @Test("Low priority has lowest factor (0.3)")
    func lowPriorityFactor() {
        #expect(TestTimeSensitivity.lowPriority.factor == 0.3)
    }

    @Test("Factors span from 0.3 to 1.0")
    func factorRange() {
        let factors = TestTimeSensitivity.allCases.map(\.factor)
        #expect(factors.min() == 0.3)
        #expect(factors.max() == 1.0)
    }

    @Test("Scheduled factor (0.6) > whenIdle factor (0.5)")
    func scheduledVsWhenIdle() {
        #expect(TestTimeSensitivity.scheduled.factor > TestTimeSensitivity.whenIdle.factor)
    }
}

// MARK: - Cognitive Load Tests

@Suite("Cognitive Load — Factors")
struct CognitiveLoadTests {
    @Test("All 4 load levels exist")
    func allCases() {
        #expect(TestCognitiveLoad.allCases.count == 4)
    }

    @Test("Minimal has highest factor (1.0)")
    func minimalFactor() {
        #expect(TestCognitiveLoad.minimal.factor == 1.0)
    }

    @Test("High has lowest factor (0.5)")
    func highFactor() {
        #expect(TestCognitiveLoad.high.factor == 0.5)
    }

    @Test("Factors decrease with increasing load")
    func factorsDecreasing() {
        let ordered: [TestCognitiveLoad] = [.minimal, .low, .moderate, .high]
        let factors = ordered.map(\.factor)
        for i in 0..<factors.count - 1 {
            #expect(factors[i] > factors[i + 1])
        }
    }
}

// MARK: - Combined Score Tests

@Suite("Unified Suggestion — Combined Score")
struct CombinedScoreTests {
    @Test("Perfect scores give maximum combined score")
    func perfectScores() {
        let suggestion = TestUnifiedSuggestion(
            source: .proactiveEngine, title: "T", description: "D",
            action: .showMessage("msg"),
            relevanceScore: 1.0, confidenceScore: 1.0,
            timeSensitivity: .immediate, cognitiveLoad: .minimal
        )
        // 1.0*0.4 + 1.0*0.3 + 1.0*0.2 + 1.0*0.1 = 1.0
        #expect(abs(suggestion.combinedScore - 1.0) < 0.001)
    }

    @Test("Zero scores give minimum combined score based on defaults")
    func zeroScores() {
        let suggestion = TestUnifiedSuggestion(
            source: .proactiveEngine, title: "T", description: "D",
            action: .showMessage("msg"),
            relevanceScore: 0.0, confidenceScore: 0.0,
            timeSensitivity: .lowPriority, cognitiveLoad: .high
        )
        // 0*0.4 + 0*0.3 + 0.3*0.2 + 0.5*0.1 = 0.06 + 0.05 = 0.11
        #expect(abs(suggestion.combinedScore - 0.11) < 0.001)
    }

    @Test("Default suggestion uses whenIdle + low load")
    func defaultSuggestion() {
        let suggestion = TestUnifiedSuggestion(
            source: .memoryInsight, title: "T", description: "D",
            action: .offerHelp(topic: "Swift"),
            relevanceScore: 0.8, confidenceScore: 0.6
        )
        // 0.8*0.4 + 0.6*0.3 + 0.5*0.2 + 0.9*0.1 = 0.32 + 0.18 + 0.10 + 0.09 = 0.69
        #expect(abs(suggestion.combinedScore - 0.69) < 0.001)
    }

    @Test("Higher relevance increases score more than higher confidence")
    func relevanceWeightHigher() {
        let highRelevance = TestUnifiedSuggestion(
            source: .proactiveEngine, title: "T", description: "D",
            action: .showMessage("msg"),
            relevanceScore: 1.0, confidenceScore: 0.0
        )
        let highConfidence = TestUnifiedSuggestion(
            source: .proactiveEngine, title: "T", description: "D",
            action: .showMessage("msg"),
            relevanceScore: 0.0, confidenceScore: 1.0
        )
        #expect(highRelevance.combinedScore > highConfidence.combinedScore)
    }

    @Test("Immediate time sensitivity boosts score vs low priority")
    func timeSensitivityImpact() {
        let immediate = TestUnifiedSuggestion(
            source: .proactiveEngine, title: "T", description: "D",
            action: .showMessage("msg"),
            relevanceScore: 0.5, confidenceScore: 0.5,
            timeSensitivity: .immediate
        )
        let lowPriority = TestUnifiedSuggestion(
            source: .proactiveEngine, title: "T", description: "D",
            action: .showMessage("msg"),
            relevanceScore: 0.5, confidenceScore: 0.5,
            timeSensitivity: .lowPriority
        )
        #expect(immediate.combinedScore > lowPriority.combinedScore)
    }

    @Test("Minimal cognitive load boosts score vs high load")
    func cognitiveLoadImpact() {
        let minimal = TestUnifiedSuggestion(
            source: .proactiveEngine, title: "T", description: "D",
            action: .showMessage("msg"),
            relevanceScore: 0.5, confidenceScore: 0.5,
            cognitiveLoad: .minimal
        )
        let high = TestUnifiedSuggestion(
            source: .proactiveEngine, title: "T", description: "D",
            action: .showMessage("msg"),
            relevanceScore: 0.5, confidenceScore: 0.5,
            cognitiveLoad: .high
        )
        #expect(minimal.combinedScore > high.combinedScore)
    }

    @Test("Suggestion has unique ID")
    func uniqueID() {
        let a = TestUnifiedSuggestion(source: .goalProgress, title: "A", description: "",
                                       action: .showMessage(""), relevanceScore: 0.5, confidenceScore: 0.5)
        let b = TestUnifiedSuggestion(source: .goalProgress, title: "A", description: "",
                                       action: .showMessage(""), relevanceScore: 0.5, confidenceScore: 0.5)
        #expect(a.id != b.id)
    }

    @Test("Default expiresAt is nil")
    func defaultExpiry() {
        let s = TestUnifiedSuggestion(source: .proactiveEngine, title: "T", description: "D",
                                       action: .showMessage(""), relevanceScore: 0.5, confidenceScore: 0.5)
        #expect(s.expiresAt == nil)
    }

    @Test("Default metadata is empty")
    func defaultMetadata() {
        let s = TestUnifiedSuggestion(source: .proactiveEngine, title: "T", description: "D",
                                       action: .showMessage(""), relevanceScore: 0.5, confidenceScore: 0.5)
        #expect(s.metadata.isEmpty)
    }
}

// MARK: - Blocker Type Tests

@Suite("Blocker Type — Completeness")
struct BlockerTypeTests {
    @Test("All 7 blocker types exist")
    func allCases() {
        #expect(TestBlockerType.allCases.count == 7)
    }

    @Test("All blocker types have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestBlockerType.allCases.map(\.rawValue))
        #expect(rawValues.count == TestBlockerType.allCases.count)
    }
}

// MARK: - Blocker Severity Tests

@Suite("Blocker Severity — Levels")
struct BlockerSeverityTests {
    @Test("All 4 severity levels exist")
    func allCases() {
        #expect(TestBlockerSeverity.allCases.count == 4)
    }

    @Test("All severity levels have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestBlockerSeverity.allCases.map(\.rawValue))
        #expect(rawValues.count == TestBlockerSeverity.allCases.count)
    }
}

// MARK: - Blocker Context Tests

@Suite("Blocker Context — Defaults")
struct BlockerContextTests {
    @Test("Default context has nil taskType")
    func defaultTaskType() {
        let ctx = TestBlockerContext()
        #expect(ctx.taskType == nil)
    }

    @Test("Default timeSpent is 0")
    func defaultTimeSpent() {
        let ctx = TestBlockerContext()
        #expect(ctx.timeSpent == 0)
    }

    @Test("Default attemptCount is 1")
    func defaultAttemptCount() {
        let ctx = TestBlockerContext()
        #expect(ctx.attemptCount == 1)
    }

    @Test("Default related queries is empty")
    func defaultRelatedQueries() {
        let ctx = TestBlockerContext()
        #expect(ctx.relatedQueries.isEmpty)
    }

    @Test("Default error messages is empty")
    func defaultErrorMessages() {
        let ctx = TestBlockerContext()
        #expect(ctx.errorMessages.isEmpty)
    }

    @Test("Context with all properties")
    func fullContext() {
        let ctx = TestBlockerContext(
            taskType: "code_review", timeSpent: 300,
            attemptCount: 5, relatedQueries: ["how to fix", "workaround"],
            errorMessages: ["timeout", "connection refused"]
        )
        #expect(ctx.taskType == "code_review")
        #expect(ctx.timeSpent == 300)
        #expect(ctx.attemptCount == 5)
        #expect(ctx.relatedQueries.count == 2)
        #expect(ctx.errorMessages.count == 2)
    }
}

// MARK: - Detected Blocker Tests

@Suite("Detected Blocker — Construction")
struct DetectedBlockerTests {
    @Test("Blocker has unique ID")
    func uniqueID() {
        let a = TestDetectedBlocker(type: .stuckOnTask, description: "A", severity: .low)
        let b = TestDetectedBlocker(type: .stuckOnTask, description: "A", severity: .low)
        #expect(a.id != b.id)
    }

    @Test("Blocker with suggestions")
    func withSuggestions() {
        let blocker = TestDetectedBlocker(
            type: .errorLoop, description: "Same error 5 times",
            severity: .high,
            suggestedResolutions: ["Try different approach", "Ask for help", "Check logs"]
        )
        #expect(blocker.suggestedResolutions.count == 3)
        #expect(blocker.severity == .high)
    }

    @Test("Default context and resolutions")
    func defaults() {
        let blocker = TestDetectedBlocker(type: .toolFailure, description: "API down", severity: .critical)
        #expect(blocker.context.taskType == nil)
        #expect(blocker.suggestedResolutions.isEmpty)
    }
}

// MARK: - Goal Category Tests

@Suite("Goal Category — Completeness")
struct GoalCategoryTests {
    @Test("All 7 goal categories exist")
    func allCases() {
        #expect(TestGoalCategory.allCases.count == 7)
    }

    @Test("All categories have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestGoalCategory.allCases.map(\.rawValue))
        #expect(rawValues.count == TestGoalCategory.allCases.count)
    }
}

// MARK: - Goal Priority Tests

@Suite("Goal Priority — Completeness")
struct GoalPriorityTests {
    @Test("All 5 goal priorities exist")
    func allCases() {
        #expect(TestGoalPriority.allCases.count == 5)
    }

    @Test("All priorities have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestGoalPriority.allCases.map(\.rawValue))
        #expect(rawValues.count == TestGoalPriority.allCases.count)
    }
}

// MARK: - Inferred Goal Tests

@Suite("Inferred Goal — Construction")
struct InferredGoalTests {
    @Test("Goal has unique ID")
    func uniqueID() {
        let a = TestInferredGoal(title: "G", description: "D", category: .project, confidence: 0.8)
        let b = TestInferredGoal(title: "G", description: "D", category: .project, confidence: 0.8)
        #expect(a.id != b.id)
    }

    @Test("Default priority is medium")
    func defaultPriority() {
        let goal = TestInferredGoal(title: "Learn Swift", description: "D", category: .learning, confidence: 0.7)
        #expect(goal.priority == .medium)
    }

    @Test("Default progress is 0")
    func defaultProgress() {
        let goal = TestInferredGoal(title: "Build app", description: "D", category: .creation, confidence: 0.9)
        #expect(goal.progress == 0)
    }

    @Test("Default deadline is nil")
    func defaultDeadline() {
        let goal = TestInferredGoal(title: "Maintain infra", description: "D", category: .maintenance, confidence: 0.6)
        #expect(goal.deadline == nil)
    }

    @Test("Default related lists are empty")
    func defaultRelatedLists() {
        let goal = TestInferredGoal(title: "G", description: "D", category: .exploration, confidence: 0.5)
        #expect(goal.relatedConversations.isEmpty)
        #expect(goal.relatedProjects.isEmpty)
    }

    @Test("Goal with all properties")
    func fullGoal() {
        let convId = UUID()
        let deadline = Date().addingTimeInterval(86400 * 7)
        let goal = TestInferredGoal(
            title: "Ship v2", description: "Release version 2",
            category: .project, confidence: 0.95,
            priority: .critical, deadline: deadline,
            progress: 0.75,
            relatedConversations: [convId],
            relatedProjects: ["Thea", "TheaKit"]
        )
        #expect(goal.priority == .critical)
        #expect(goal.progress == 0.75)
        #expect(goal.deadline != nil)
        #expect(goal.relatedConversations.count == 1)
        #expect(goal.relatedProjects.count == 2)
    }
}

// MARK: - Preloaded Resource Tests

@Suite("Preloaded Resource — Types")
struct PreloadedResourceTests {
    @Test("All 6 resource types exist")
    func allTypes() {
        #expect(TestResourceType.allCases.count == 6)
    }

    @Test("All types have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestResourceType.allCases.map(\.rawValue))
        #expect(rawValues.count == TestResourceType.allCases.count)
    }

    @Test("Resource has unique ID")
    func uniqueID() {
        let a = TestPreloadedResource(type: .file, identifier: "main.swift", relevanceScore: 0.9)
        let b = TestPreloadedResource(type: .file, identifier: "main.swift", relevanceScore: 0.9)
        #expect(a.id != b.id)
    }

    @Test("Default expiresAt is 300 seconds from loadedAt")
    func defaultExpiry() {
        let resource = TestPreloadedResource(type: .memory, identifier: "recent", relevanceScore: 0.8)
        let diff = resource.expiresAt.timeIntervalSince(resource.loadedAt)
        #expect(abs(diff - 300) < 1.0)
    }

    @Test("Resource preserves properties")
    func propertiesPreserved() {
        let resource = TestPreloadedResource(type: .documentation, identifier: "api-docs", relevanceScore: 0.65)
        #expect(resource.type == .documentation)
        #expect(resource.identifier == "api-docs")
        #expect(resource.relevanceScore == 0.65)
    }
}

// MARK: - User Model Aspect Tests

@Suite("User Model Aspect — Completeness")
struct UserModelAspectTests {
    @Test("All 8 aspects exist")
    func allCases() {
        #expect(TestUserModelAspect.allCases.count == 8)
    }

    @Test("All aspects have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestUserModelAspect.allCases.map(\.rawValue))
        #expect(rawValues.count == TestUserModelAspect.allCases.count)
    }

    @Test("Key aspects present: technicalLevel, workHabits, errorHandling")
    func keyAspects() {
        let cases = TestUserModelAspect.allCases.map(\.rawValue)
        #expect(cases.contains("technicalLevel"))
        #expect(cases.contains("workHabits"))
        #expect(cases.contains("errorHandling"))
    }
}

// MARK: - User Model Snapshot Tests

@Suite("User Model Snapshot — Defaults")
struct UserModelSnapshotTests {
    @Test("All defaults are 0.5")
    func allDefaults() {
        let snapshot = TestUserModelSnapshot()
        #expect(snapshot.technicalLevel == 0.5)
        #expect(snapshot.preferredVerbosity == 0.5)
        #expect(snapshot.currentCognitiveLoad == 0.5)
        #expect(snapshot.recentProductivity == 0.5)
    }

    @Test("Custom values preserved")
    func customValues() {
        let snapshot = TestUserModelSnapshot(
            technicalLevel: 0.9, preferredVerbosity: 0.3,
            currentCognitiveLoad: 0.7, recentProductivity: 0.85
        )
        #expect(snapshot.technicalLevel == 0.9)
        #expect(snapshot.preferredVerbosity == 0.3)
        #expect(snapshot.currentCognitiveLoad == 0.7)
        #expect(snapshot.recentProductivity == 0.85)
    }
}

// MARK: - Intelligence Context Tests

@Suite("Intelligence Context — Construction")
struct IntelligenceContextTests {
    @Test("Default context has nil query")
    func defaultQuery() {
        let ctx = TestIntelligenceContext()
        #expect(ctx.currentQuery == nil)
    }

    @Test("Default context has nil conversationId")
    func defaultConversationId() {
        let ctx = TestIntelligenceContext()
        #expect(ctx.conversationId == nil)
    }

    @Test("Default context has empty recent queries")
    func defaultRecentQueries() {
        let ctx = TestIntelligenceContext()
        #expect(ctx.recentQueries.isEmpty)
    }

    @Test("Default context has zero session duration")
    func defaultSessionDuration() {
        let ctx = TestIntelligenceContext()
        #expect(ctx.sessionDuration == 0)
    }

    @Test("Default context has empty active goals")
    func defaultActiveGoals() {
        let ctx = TestIntelligenceContext()
        #expect(ctx.activeGoals.isEmpty)
    }

    @Test("Default user model snapshot has 0.5 defaults")
    func defaultUserModel() {
        let ctx = TestIntelligenceContext()
        #expect(ctx.userModel.technicalLevel == 0.5)
        #expect(ctx.userModel.preferredVerbosity == 0.5)
    }

    @Test("Full context with all properties")
    func fullContext() {
        let convId = UUID()
        let goal = TestInferredGoal(title: "Ship", description: "D", category: .project, confidence: 0.9)
        let ctx = TestIntelligenceContext(
            currentQuery: "How to optimize?",
            conversationId: convId,
            recentQueries: ["previous question", "another query"],
            currentTaskType: "optimization",
            activeGoals: [goal],
            userModel: TestUserModelSnapshot(technicalLevel: 0.9),
            sessionDuration: 3600
        )
        #expect(ctx.currentQuery == "How to optimize?")
        #expect(ctx.conversationId == convId)
        #expect(ctx.recentQueries.count == 2)
        #expect(ctx.currentTaskType == "optimization")
        #expect(ctx.activeGoals.count == 1)
        #expect(ctx.userModel.technicalLevel == 0.9)
        #expect(ctx.sessionDuration == 3600)
    }
}

// MARK: - Delivery Decision Tests

@Suite("Delivery Decision — Immediate vs Deferred")
struct DeliveryDecisionTests {
    @Test("Now decision is immediate")
    func nowIsImmediate() {
        let decision = TestDeliveryDecision.now(reason: "High receptivity")
        #expect(decision.isImmediate)
    }

    @Test("Deferred decision is not immediate")
    func deferredNotImmediate() {
        let decision = TestDeliveryDecision.deferred(until: Date().addingTimeInterval(3600), reason: "User asleep")
        #expect(!decision.isImmediate)
    }

    @Test("Now decision carries reason")
    func nowReason() {
        let decision = TestDeliveryDecision.now(reason: "Critical priority")
        if case .now(let reason) = decision {
            #expect(reason == "Critical priority")
        } else {
            Issue.record("Expected .now case")
        }
    }

    @Test("Deferred decision carries date and reason")
    func deferredDateAndReason() {
        let futureDate = Date().addingTimeInterval(7200)
        let decision = TestDeliveryDecision.deferred(until: futureDate, reason: "Better timing")
        if case .deferred(let until, let reason) = decision {
            #expect(until == futureDate)
            #expect(reason == "Better timing")
        } else {
            Issue.record("Expected .deferred case")
        }
    }
}
