// RoutingDecisionContextTests.swift
// Split from RoutingDecisionTests.swift — covers RoutingContext, LearnedModelPreference,
// ContextualRoutingPattern, and RoutingInsights tests.

import Foundation
import XCTest

// MARK: - Mirrored Types (duplicated from RoutingDecisionTests.swift for file-private access)

private enum TaskType: String, Codable, Sendable, CaseIterable {
    case codeGeneration, codeAnalysis, debugging, factual, creative
    case analysis, research, conversation, system, math
    case translation, summarization, planning, unknown
}

private enum Urgency: String, Sendable {
    case low, normal, high
}

private struct RoutingContext: Sendable {
    let urgency: Urgency
    let budgetConstraint: Decimal?
    let estimatedInputTokens: Int?
    let estimatedOutputTokens: Int?
    let requiresStreaming: Bool
    let requiresVision: Bool
    let requiresFunctions: Bool

    init(
        urgency: Urgency = .normal,
        budgetConstraint: Decimal? = nil,
        estimatedInputTokens: Int? = nil,
        estimatedOutputTokens: Int? = nil,
        requiresStreaming: Bool = true,
        requiresVision: Bool = false,
        requiresFunctions: Bool = false
    ) {
        self.urgency = urgency
        self.budgetConstraint = budgetConstraint
        self.estimatedInputTokens = estimatedInputTokens
        self.estimatedOutputTokens = estimatedOutputTokens
        self.requiresStreaming = requiresStreaming
        self.requiresVision = requiresVision
        self.requiresFunctions = requiresFunctions
    }
}

private struct LearnedModelPreference: Identifiable, Codable {
    let id: UUID
    let modelId: String
    let taskType: TaskType
    var preferenceScore: Double
    var sampleCount: Int
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        modelId: String,
        taskType: TaskType,
        preferenceScore: Double,
        sampleCount: Int,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.modelId = modelId
        self.taskType = taskType
        self.preferenceScore = preferenceScore
        self.sampleCount = sampleCount
        self.lastUpdated = lastUpdated
    }
}

private struct ContextualRoutingPattern: Identifiable, Codable {
    let id: UUID
    let patternType: PatternType
    let description: String
    let modelId: String
    var context: [String: String]
    var confidence: Double
    var sampleCount: Int
    var lastSeen: Date

    enum PatternType: String, Codable, Sendable {
        case taskSequence = "task_sequence"
        case timeOfDay = "time_of_day"
        case userPreference = "user_preference"
        case performanceTrend = "performance_trend"
        case costOptimization = "cost_optimization"
    }

    init(
        id: UUID = UUID(),
        patternType: PatternType,
        description: String,
        modelId: String,
        context: [String: String] = [:],
        confidence: Double = 0.5,
        sampleCount: Int = 1,
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.patternType = patternType
        self.description = description
        self.modelId = modelId
        self.context = context
        self.confidence = confidence
        self.sampleCount = sampleCount
        self.lastSeen = lastSeen
    }
}

private struct RoutingInsights: Sendable {
    let topPerformingModels: [String]
    let recentPatterns: [ContextualRoutingPattern]
    let totalRoutingDecisions: Int
    let totalLearningSamples: Int
    let explorationRate: Double
    let adaptiveRoutingEnabled: Bool

    var summary: String {
        """
        Routing Insights:
        - \(totalRoutingDecisions) routing decisions made
        - \(totalLearningSamples) learning samples collected
        - Top models: \(topPerformingModels.prefix(3).joined(separator: ", "))
        - \(recentPatterns.count) contextual patterns detected
        - Exploration rate: \(String(format: "%.0f%%", explorationRate * 100))
        """
    }
}

// MARK: - RoutingContext Tests

final class RoutingContextTests: XCTestCase {

    func testDefaultValues() {
        let ctx = RoutingContext()
        XCTAssertEqual(ctx.urgency, .normal)
        XCTAssertNil(ctx.budgetConstraint)
        XCTAssertNil(ctx.estimatedInputTokens)
        XCTAssertNil(ctx.estimatedOutputTokens)
        XCTAssertTrue(ctx.requiresStreaming)
        XCTAssertFalse(ctx.requiresVision)
        XCTAssertFalse(ctx.requiresFunctions)
    }

    func testCustomValues() {
        let ctx = RoutingContext(
            urgency: .high,
            budgetConstraint: Decimal(string: "0.50"),
            estimatedInputTokens: 1000,
            estimatedOutputTokens: 2000,
            requiresStreaming: false,
            requiresVision: true,
            requiresFunctions: true
        )
        XCTAssertEqual(ctx.urgency, .high)
        XCTAssertEqual(ctx.budgetConstraint, Decimal(string: "0.50"))
        XCTAssertEqual(ctx.estimatedInputTokens, 1000)
        XCTAssertEqual(ctx.estimatedOutputTokens, 2000)
        XCTAssertFalse(ctx.requiresStreaming)
        XCTAssertTrue(ctx.requiresVision)
        XCTAssertTrue(ctx.requiresFunctions)
    }

    func testUrgencyRawValues() {
        XCTAssertEqual(Urgency.low.rawValue, "low")
        XCTAssertEqual(Urgency.normal.rawValue, "normal")
        XCTAssertEqual(Urgency.high.rawValue, "high")
    }

    func testLowUrgencyContext() {
        let ctx = RoutingContext(urgency: .low)
        XCTAssertEqual(ctx.urgency, .low)
    }
}

// MARK: - LearnedModelPreference Tests

final class LearnedModelPreferenceTests: XCTestCase {

    func testInitialization() {
        let now = Date()
        let pref = LearnedModelPreference(
            modelId: "gpt-4o",
            taskType: .codeGeneration,
            preferenceScore: 0.85,
            sampleCount: 42,
            lastUpdated: now
        )
        XCTAssertEqual(pref.modelId, "gpt-4o")
        XCTAssertEqual(pref.taskType, .codeGeneration)
        XCTAssertEqual(pref.preferenceScore, 0.85, accuracy: 0.001)
        XCTAssertEqual(pref.sampleCount, 42)
        XCTAssertEqual(pref.lastUpdated, now)
    }

    func testIdentifiable() {
        let pref = LearnedModelPreference(
            modelId: "claude", taskType: .analysis,
            preferenceScore: 0.9, sampleCount: 10
        )
        XCTAssertFalse(pref.id.uuidString.isEmpty)
    }

    func testMutability() {
        var pref = LearnedModelPreference(
            modelId: "model-a", taskType: .factual,
            preferenceScore: 0.5, sampleCount: 1
        )
        pref.preferenceScore = 0.95
        pref.sampleCount = 100
        XCTAssertEqual(pref.preferenceScore, 0.95, accuracy: 0.001)
        XCTAssertEqual(pref.sampleCount, 100)
    }

    func testCodableRoundTrip() throws {
        let pref = LearnedModelPreference(
            modelId: "gemma-3-1b", taskType: .conversation,
            preferenceScore: 0.72, sampleCount: 15
        )
        let data = try JSONEncoder().encode(pref)
        let decoded = try JSONDecoder().decode(
            LearnedModelPreference.self, from: data
        )
        XCTAssertEqual(decoded.modelId, "gemma-3-1b")
        XCTAssertEqual(decoded.taskType, .conversation)
        XCTAssertEqual(decoded.preferenceScore, 0.72, accuracy: 0.001)
        XCTAssertEqual(decoded.sampleCount, 15)
    }
}

// MARK: - ContextualRoutingPattern Tests

final class ContextualRoutingPatternTests: XCTestCase {

    func testPatternTypeRawValues() {
        XCTAssertEqual(
            ContextualRoutingPattern.PatternType.taskSequence.rawValue,
            "task_sequence"
        )
        XCTAssertEqual(
            ContextualRoutingPattern.PatternType.timeOfDay.rawValue,
            "time_of_day"
        )
        XCTAssertEqual(
            ContextualRoutingPattern.PatternType.userPreference.rawValue,
            "user_preference"
        )
        XCTAssertEqual(
            ContextualRoutingPattern.PatternType.performanceTrend.rawValue,
            "performance_trend"
        )
        XCTAssertEqual(
            ContextualRoutingPattern.PatternType.costOptimization.rawValue,
            "cost_optimization"
        )
    }

    func testPatternTypeCodable() throws {
        for pt in [
            ContextualRoutingPattern.PatternType.taskSequence,
            .timeOfDay, .userPreference,
            .performanceTrend, .costOptimization
        ] {
            let data = try JSONEncoder().encode(pt)
            let decoded = try JSONDecoder().decode(
                ContextualRoutingPattern.PatternType.self, from: data
            )
            XCTAssertEqual(decoded, pt)
        }
    }

    func testDefaultValues() {
        let pattern = ContextualRoutingPattern(
            patternType: .timeOfDay,
            description: "Morning code preference",
            modelId: "claude-3-opus"
        )
        XCTAssertTrue(pattern.context.isEmpty)
        XCTAssertEqual(pattern.confidence, 0.5)
        XCTAssertEqual(pattern.sampleCount, 1)
    }

    func testCustomValues() {
        let pattern = ContextualRoutingPattern(
            patternType: .costOptimization,
            description: "Use cheaper model for simple tasks",
            modelId: "gpt-4o-mini",
            context: ["task": "conversation", "budget": "low"],
            confidence: 0.92,
            sampleCount: 150
        )
        XCTAssertEqual(pattern.patternType, .costOptimization)
        XCTAssertEqual(pattern.modelId, "gpt-4o-mini")
        XCTAssertEqual(pattern.context["task"], "conversation")
        XCTAssertEqual(pattern.context["budget"], "low")
        XCTAssertEqual(pattern.confidence, 0.92, accuracy: 0.001)
        XCTAssertEqual(pattern.sampleCount, 150)
    }

    func testCodableRoundTrip() throws {
        let pattern = ContextualRoutingPattern(
            patternType: .performanceTrend,
            description: "Claude excels at code review",
            modelId: "claude-3-opus",
            context: ["domain": "swift", "type": "review"],
            confidence: 0.88,
            sampleCount: 30
        )
        let data = try JSONEncoder().encode(pattern)
        let decoded = try JSONDecoder().decode(
            ContextualRoutingPattern.self, from: data
        )
        XCTAssertEqual(decoded.patternType, .performanceTrend)
        XCTAssertEqual(decoded.description, "Claude excels at code review")
        XCTAssertEqual(decoded.modelId, "claude-3-opus")
        XCTAssertEqual(decoded.context["domain"], "swift")
        XCTAssertEqual(decoded.confidence, 0.88, accuracy: 0.001)
        XCTAssertEqual(decoded.sampleCount, 30)
    }

    func testIdentifiable() {
        let a = ContextualRoutingPattern(
            patternType: .taskSequence,
            description: "test", modelId: "m1"
        )
        let b = ContextualRoutingPattern(
            patternType: .taskSequence,
            description: "test", modelId: "m1"
        )
        XCTAssertNotEqual(a.id, b.id)
    }
}

// MARK: - RoutingInsights Tests

final class RoutingInsightsTests: XCTestCase {

    func testSummaryFormatting() {
        let insights = RoutingInsights(
            topPerformingModels: ["claude-3-opus", "gpt-4o", "gemma-3"],
            recentPatterns: [],
            totalRoutingDecisions: 250,
            totalLearningSamples: 1000,
            explorationRate: 0.15,
            adaptiveRoutingEnabled: true
        )
        let summary = insights.summary
        XCTAssertTrue(summary.contains("250 routing decisions made"))
        XCTAssertTrue(summary.contains("1000 learning samples collected"))
        XCTAssertTrue(
            summary.contains("claude-3-opus, gpt-4o, gemma-3")
        )
        XCTAssertTrue(summary.contains("0 contextual patterns detected"))
        XCTAssertTrue(summary.contains("15%"))
    }

    func testSummaryTruncatesTopModels() {
        let insights = RoutingInsights(
            topPerformingModels: [
                "model-a", "model-b", "model-c",
                "model-d", "model-e"
            ],
            recentPatterns: [],
            totalRoutingDecisions: 10,
            totalLearningSamples: 5,
            explorationRate: 0.3,
            adaptiveRoutingEnabled: false
        )
        let summary = insights.summary
        // Only first 3 models shown
        XCTAssertTrue(summary.contains("model-a, model-b, model-c"))
        XCTAssertFalse(summary.contains("model-d"))
    }

    func testSummaryWithPatterns() {
        let pattern = ContextualRoutingPattern(
            patternType: .timeOfDay,
            description: "Night coding", modelId: "test"
        )
        let insights = RoutingInsights(
            topPerformingModels: ["gpt-4o"],
            recentPatterns: [pattern],
            totalRoutingDecisions: 50,
            totalLearningSamples: 200,
            explorationRate: 0.1,
            adaptiveRoutingEnabled: true
        )
        XCTAssertTrue(
            insights.summary.contains("1 contextual patterns detected")
        )
    }

    func testSummaryZeroExplorationRate() {
        let insights = RoutingInsights(
            topPerformingModels: [],
            recentPatterns: [],
            totalRoutingDecisions: 0,
            totalLearningSamples: 0,
            explorationRate: 0.0,
            adaptiveRoutingEnabled: false
        )
        XCTAssertTrue(insights.summary.contains("0%"))
        XCTAssertTrue(insights.summary.contains("0 routing decisions"))
    }

    func testSummaryEmptyTopModels() {
        let insights = RoutingInsights(
            topPerformingModels: [],
            recentPatterns: [],
            totalRoutingDecisions: 5,
            totalLearningSamples: 3,
            explorationRate: 0.5,
            adaptiveRoutingEnabled: true
        )
        XCTAssertTrue(insights.summary.contains("Top models: \n"))
    }

    func testSummaryFullExplorationRate() {
        let insights = RoutingInsights(
            topPerformingModels: ["test"],
            recentPatterns: [],
            totalRoutingDecisions: 1,
            totalLearningSamples: 1,
            explorationRate: 1.0,
            adaptiveRoutingEnabled: true
        )
        XCTAssertTrue(insights.summary.contains("100%"))
    }
}
