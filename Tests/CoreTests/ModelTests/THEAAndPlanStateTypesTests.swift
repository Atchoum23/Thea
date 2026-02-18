// THEAAndPlanStateTypesTests.swift
// Tests for THEATypes + PlanState types (standalone test doubles)

import Testing
import Foundation

// MARK: - THEA Types Test Doubles

private enum TestTHEAExecutionStrategy: String, Sendable, CaseIterable {
    case direct, decomposed, multiModel, localFallback, planMode
}

private enum TestInfluenceLevel: String, Sendable, CaseIterable {
    case critical, high, medium, low
}

private struct TestContextFactor: Identifiable, Sendable {
    let id: UUID
    let name: String
    let value: String
    let influence: TestInfluenceLevel
    let description: String

    init(id: UUID = UUID(), name: String, value: String,
         influence: TestInfluenceLevel, description: String) {
        self.id = id
        self.name = name
        self.value = value
        self.influence = influence
        self.description = description
    }
}

private enum TestTHEASuggestionType: String, Sendable, CaseIterable {
    case action, followUp, info
}

private struct TestTHEASuggestion: Identifiable, Sendable {
    let id: UUID
    let type: TestTHEASuggestionType
    let title: String
    let description: String
    let action: String

    init(id: UUID = UUID(), type: TestTHEASuggestionType,
         title: String, description: String, action: String) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.action = action
    }
}

private struct TestTHEAResponseMetadata: Sendable {
    let startTime: Date
    let endTime: Date
    let tokenCount: Int
    let modelUsed: String
    let providerUsed: String

    var latency: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

private enum TestLearningType: String, Sendable, CaseIterable {
    case taskPattern, modelPerformance, userPreference, contextPattern
}

private struct TestTHEALearning: Identifiable, Sendable {
    let id: UUID
    let type: TestLearningType
    let description: String
    let confidence: Double

    init(id: UUID = UUID(), type: TestLearningType, description: String, confidence: Double) {
        self.id = id
        self.type = type
        self.description = description
        self.confidence = confidence
    }
}

// MARK: - Plan State Test Doubles

private enum TestPlanStepStatus: String, Codable, Sendable, CaseIterable {
    case pending, inProgress, completed, failed, skipped, modified
}

private struct TestPlanStep: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var activeDescription: String
    var status: TestPlanStepStatus
    var taskType: String
    var result: String?
    var error: String?
    var startedAt: Date?
    var completedAt: Date?

    init(
        id: UUID = UUID(), title: String, activeDescription: String,
        status: TestPlanStepStatus = .pending, taskType: String = "general",
        result: String? = nil, error: String? = nil,
        startedAt: Date? = nil, completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.activeDescription = activeDescription
        self.status = status
        self.taskType = taskType
        self.result = result
        self.error = error
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    var duration: TimeInterval? {
        guard let start = startedAt, let end = completedAt else { return nil }
        return end.timeIntervalSince(start)
    }
}

private struct TestPlanPhase: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var steps: [TestPlanStep]

    init(id: UUID = UUID(), title: String, steps: [TestPlanStep]) {
        self.id = id
        self.title = title
        self.steps = steps
    }

    var completedSteps: Int {
        steps.filter { $0.status == .completed }.count
    }

    var totalSteps: Int { steps.count }

    var isComplete: Bool {
        steps.allSatisfy { $0.status == .completed || $0.status == .skipped }
    }

    var currentStep: TestPlanStep? {
        steps.first { $0.status == .inProgress }
    }

    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(completedSteps) / Double(totalSteps)
    }
}

private enum TestPlanStatus: String, Codable, Sendable, CaseIterable {
    case creating, executing, paused, completed, failed, cancelled, modifying

    var displayName: String {
        switch self {
        case .creating: "Creating plan..."
        case .executing: "Executing"
        case .paused: "Paused"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .modifying: "Updating plan..."
        }
    }
}

private struct TestPlanState: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var phases: [TestPlanPhase]
    var status: TestPlanStatus
    var originalQuery: String

    init(
        id: UUID = UUID(), title: String, phases: [TestPlanPhase],
        status: TestPlanStatus = .creating, originalQuery: String
    ) {
        self.id = id
        self.title = title
        self.phases = phases
        self.status = status
        self.originalQuery = originalQuery
    }

    var totalSteps: Int {
        phases.flatMap(\.steps).count
    }

    var completedSteps: Int {
        phases.flatMap(\.steps).filter { $0.status == .completed }.count
    }

    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(completedSteps) / Double(totalSteps)
    }

    var currentStepTitle: String? {
        phases.flatMap(\.steps).first { $0.status == .inProgress }?.activeDescription
    }

    var isActive: Bool {
        status == .executing || status == .creating || status == .modifying
    }
}

// MARK: - THEA Execution Strategy Tests

@Suite("THEA Execution Strategy — Cases")
struct THEAExecutionStrategyTests {
    @Test("All 5 strategies exist")
    func allCases() {
        #expect(TestTHEAExecutionStrategy.allCases.count == 5)
    }

    @Test("All strategies have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestTHEAExecutionStrategy.allCases.map(\.rawValue))
        #expect(rawValues.count == 5)
    }
}

// MARK: - Influence Level Tests

@Suite("Influence Level — Cases")
struct InfluenceLevelTests {
    @Test("All 4 influence levels exist")
    func allCases() {
        #expect(TestInfluenceLevel.allCases.count == 4)
    }

    @Test("All levels have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestInfluenceLevel.allCases.map(\.rawValue))
        #expect(rawValues.count == 4)
    }
}

// MARK: - Context Factor Tests

@Suite("Context Factor — Construction")
struct ContextFactorTests {
    @Test("Factor has unique ID")
    func uniqueID() {
        let a = TestContextFactor(name: "time", value: "morning", influence: .medium, description: "Time of day")
        let b = TestContextFactor(name: "time", value: "morning", influence: .medium, description: "Time of day")
        #expect(a.id != b.id)
    }

    @Test("Factor preserves properties")
    func propertiesPreserved() {
        let factor = TestContextFactor(name: "complexity", value: "high", influence: .critical,
                                        description: "Task is highly complex")
        #expect(factor.name == "complexity")
        #expect(factor.value == "high")
        #expect(factor.influence == .critical)
    }
}

// MARK: - THEA Suggestion Type Tests

@Suite("THEA Suggestion Type — Cases")
struct THEASuggestionTypeTests {
    @Test("All 3 suggestion types exist")
    func allCases() {
        #expect(TestTHEASuggestionType.allCases.count == 3)
    }

    @Test("All types have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestTHEASuggestionType.allCases.map(\.rawValue))
        #expect(rawValues.count == 3)
    }
}

// MARK: - THEA Suggestion Tests

@Suite("THEA Suggestion — Construction")
struct THEASuggestionTests {
    @Test("Suggestion has unique ID")
    func uniqueID() {
        let a = TestTHEASuggestion(type: .action, title: "T", description: "D", action: "A")
        let b = TestTHEASuggestion(type: .action, title: "T", description: "D", action: "A")
        #expect(a.id != b.id)
    }

    @Test("All suggestion types can be constructed")
    func allTypes() {
        let action = TestTHEASuggestion(type: .action, title: "Run tests", description: "D", action: "swift test")
        let followUp = TestTHEASuggestion(type: .followUp, title: "Add docs", description: "D", action: "add docs")
        let info = TestTHEASuggestion(type: .info, title: "Note", description: "D", action: "n/a")
        #expect(action.type == .action)
        #expect(followUp.type == .followUp)
        #expect(info.type == .info)
    }
}

// MARK: - Response Metadata Tests

@Suite("THEA Response Metadata — Latency")
struct THEAResponseMetadataTests {
    @Test("Latency is computed from start and end time")
    func latencyComputed() {
        let start = Date()
        let end = start.addingTimeInterval(2.5)
        let meta = TestTHEAResponseMetadata(startTime: start, endTime: end,
                                             tokenCount: 150, modelUsed: "claude-3-opus",
                                             providerUsed: "anthropic")
        #expect(abs(meta.latency - 2.5) < 0.001)
    }

    @Test("Zero latency when start equals end")
    func zeroLatency() {
        let now = Date()
        let meta = TestTHEAResponseMetadata(startTime: now, endTime: now,
                                             tokenCount: 0, modelUsed: "test",
                                             providerUsed: "test")
        #expect(meta.latency == 0)
    }

    @Test("Metadata preserves properties")
    func propertiesPreserved() {
        let meta = TestTHEAResponseMetadata(startTime: Date(), endTime: Date(),
                                             tokenCount: 500, modelUsed: "gpt-4",
                                             providerUsed: "openai")
        #expect(meta.tokenCount == 500)
        #expect(meta.modelUsed == "gpt-4")
        #expect(meta.providerUsed == "openai")
    }
}

// MARK: - Learning Type Tests

@Suite("THEA Learning Type — Cases")
struct THEALearningTypeTests {
    @Test("All 4 learning types exist")
    func allCases() {
        #expect(TestLearningType.allCases.count == 4)
    }

    @Test("All types have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestLearningType.allCases.map(\.rawValue))
        #expect(rawValues.count == 4)
    }
}

// MARK: - THEA Learning Tests

@Suite("THEA Learning — Construction")
struct THEALearningTests {
    @Test("Learning has unique ID")
    func uniqueID() {
        let a = TestTHEALearning(type: .taskPattern, description: "D", confidence: 0.8)
        let b = TestTHEALearning(type: .taskPattern, description: "D", confidence: 0.8)
        #expect(a.id != b.id)
    }

    @Test("Learning preserves confidence")
    func confidencePreserved() {
        let learning = TestTHEALearning(type: .modelPerformance, description: "Opus better for code",
                                         confidence: 0.92)
        #expect(learning.confidence == 0.92)
    }
}

// MARK: - Plan Step Status Tests

@Suite("Plan Step Status — Cases")
struct PlanStepStatusTests {
    @Test("All 6 step statuses exist")
    func allCases() {
        #expect(TestPlanStepStatus.allCases.count == 6)
    }

    @Test("All statuses have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestPlanStepStatus.allCases.map(\.rawValue))
        #expect(rawValues.count == 6)
    }

    @Test("Status is Codable")
    func codableRoundtrip() throws {
        for status in TestPlanStepStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TestPlanStepStatus.self, from: data)
            #expect(decoded == status)
        }
    }
}

// MARK: - Plan Step Tests

@Suite("Plan Step — Duration Computation")
struct PlanStepDurationTests {
    @Test("Duration is nil when no start/end times")
    func noDuration() {
        let step = TestPlanStep(title: "Build", activeDescription: "Building...")
        #expect(step.duration == nil)
    }

    @Test("Duration is nil when only start time")
    func partialDuration() {
        let step = TestPlanStep(title: "Build", activeDescription: "Building...", startedAt: Date())
        #expect(step.duration == nil)
    }

    @Test("Duration computed from start and end")
    func computedDuration() {
        let start = Date()
        let end = start.addingTimeInterval(10.0)
        let step = TestPlanStep(title: "Build", activeDescription: "Building...",
                                 status: .completed, startedAt: start, completedAt: end)
        #expect(step.duration != nil)
        #expect(abs(step.duration! - 10.0) < 0.001)
    }

    @Test("Default status is pending")
    func defaultStatus() {
        let step = TestPlanStep(title: "Test", activeDescription: "Testing...")
        #expect(step.status == .pending)
    }

    @Test("Default task type is general")
    func defaultTaskType() {
        let step = TestPlanStep(title: "Test", activeDescription: "Testing...")
        #expect(step.taskType == "general")
    }

    @Test("Step Codable roundtrip")
    func codableRoundtrip() throws {
        let step = TestPlanStep(title: "Build", activeDescription: "Building...",
                                 status: .completed, taskType: "build", result: "Success")
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(TestPlanStep.self, from: data)
        #expect(decoded.title == "Build")
        #expect(decoded.status == .completed)
        #expect(decoded.result == "Success")
    }
}

// MARK: - Plan Phase Tests

@Suite("Plan Phase — Progress Computation")
struct PlanPhaseProgressTests {
    @Test("Empty phase has 0 progress")
    func emptyPhase() {
        let phase = TestPlanPhase(title: "Phase 1", steps: [])
        #expect(phase.totalSteps == 0)
        #expect(phase.completedSteps == 0)
        #expect(phase.progress == 0)
        #expect(phase.isComplete)
        #expect(phase.currentStep == nil)
    }

    @Test("All pending steps: 0 progress, not complete")
    func allPending() {
        let steps = [
            TestPlanStep(title: "A", activeDescription: "A..."),
            TestPlanStep(title: "B", activeDescription: "B...")
        ]
        let phase = TestPlanPhase(title: "Phase 1", steps: steps)
        #expect(phase.totalSteps == 2)
        #expect(phase.completedSteps == 0)
        #expect(phase.progress == 0)
        #expect(!phase.isComplete)
    }

    @Test("Half completed: 50% progress")
    func halfCompleted() {
        let steps = [
            TestPlanStep(title: "A", activeDescription: "A...", status: .completed),
            TestPlanStep(title: "B", activeDescription: "B...", status: .pending)
        ]
        let phase = TestPlanPhase(title: "Phase 1", steps: steps)
        #expect(phase.progress == 0.5)
        #expect(!phase.isComplete)
    }

    @Test("All completed: 100% progress, isComplete")
    func allCompleted() {
        let steps = [
            TestPlanStep(title: "A", activeDescription: "A...", status: .completed),
            TestPlanStep(title: "B", activeDescription: "B...", status: .completed)
        ]
        let phase = TestPlanPhase(title: "Phase 1", steps: steps)
        #expect(phase.progress == 1.0)
        #expect(phase.isComplete)
    }

    @Test("Skipped steps count as complete for isComplete")
    func skippedCountsAsComplete() {
        let steps = [
            TestPlanStep(title: "A", activeDescription: "A...", status: .completed),
            TestPlanStep(title: "B", activeDescription: "B...", status: .skipped)
        ]
        let phase = TestPlanPhase(title: "Phase 1", steps: steps)
        #expect(phase.isComplete)
        // But only completed steps count for progress numerator
        #expect(phase.completedSteps == 1)
        #expect(phase.progress == 0.5)
    }

    @Test("Failed step prevents isComplete")
    func failedPreventsComplete() {
        let steps = [
            TestPlanStep(title: "A", activeDescription: "A...", status: .completed),
            TestPlanStep(title: "B", activeDescription: "B...", status: .failed)
        ]
        let phase = TestPlanPhase(title: "Phase 1", steps: steps)
        #expect(!phase.isComplete)
    }

    @Test("currentStep returns in-progress step")
    func currentStep() {
        let steps = [
            TestPlanStep(title: "A", activeDescription: "A...", status: .completed),
            TestPlanStep(title: "B", activeDescription: "Building...", status: .inProgress),
            TestPlanStep(title: "C", activeDescription: "C...", status: .pending)
        ]
        let phase = TestPlanPhase(title: "Phase 1", steps: steps)
        #expect(phase.currentStep?.title == "B")
    }

    @Test("currentStep is nil when no in-progress step")
    func noCurrentStep() {
        let steps = [
            TestPlanStep(title: "A", activeDescription: "A...", status: .completed),
            TestPlanStep(title: "B", activeDescription: "B...", status: .pending)
        ]
        let phase = TestPlanPhase(title: "Phase 1", steps: steps)
        #expect(phase.currentStep == nil)
    }
}

// MARK: - Plan Status Tests

@Suite("Plan Status — Display Names")
struct PlanStatusDisplayTests {
    @Test("All 7 plan statuses exist")
    func allCases() {
        #expect(TestPlanStatus.allCases.count == 7)
    }

    @Test("All statuses have non-empty display names")
    func displayNames() {
        for status in TestPlanStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
    }

    @Test("Creating shows 'Creating plan...'")
    func creatingDisplay() {
        #expect(TestPlanStatus.creating.displayName == "Creating plan...")
    }

    @Test("Completed shows 'Completed'")
    func completedDisplay() {
        #expect(TestPlanStatus.completed.displayName == "Completed")
    }

    @Test("Modifying shows 'Updating plan...'")
    func modifyingDisplay() {
        #expect(TestPlanStatus.modifying.displayName == "Updating plan...")
    }

    @Test("Status is Codable")
    func codableRoundtrip() throws {
        for status in TestPlanStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TestPlanStatus.self, from: data)
            #expect(decoded == status)
        }
    }
}

// MARK: - Plan State Tests

@Suite("Plan State — Multi-Phase Progress")
struct PlanStateProgressTests {
    @Test("Empty plan has 0 progress")
    func emptyPlan() {
        let plan = TestPlanState(title: "Plan", phases: [], originalQuery: "Do something")
        #expect(plan.totalSteps == 0)
        #expect(plan.completedSteps == 0)
        #expect(plan.progress == 0)
        #expect(plan.currentStepTitle == nil)
    }

    @Test("Multi-phase progress aggregates across phases")
    func multiPhaseProgress() {
        let phase1 = TestPlanPhase(title: "Setup", steps: [
            TestPlanStep(title: "A", activeDescription: "A...", status: .completed),
            TestPlanStep(title: "B", activeDescription: "B...", status: .completed)
        ])
        let phase2 = TestPlanPhase(title: "Build", steps: [
            TestPlanStep(title: "C", activeDescription: "Building C...", status: .inProgress),
            TestPlanStep(title: "D", activeDescription: "D...", status: .pending)
        ])
        let plan = TestPlanState(title: "Build Plan", phases: [phase1, phase2],
                                  status: .executing, originalQuery: "Build the app")
        #expect(plan.totalSteps == 4)
        #expect(plan.completedSteps == 2)
        #expect(plan.progress == 0.5)
        #expect(plan.currentStepTitle == "Building C...")
    }

    @Test("isActive for executing status")
    func activeExecuting() {
        let plan = TestPlanState(title: "P", phases: [], status: .executing, originalQuery: "Q")
        #expect(plan.isActive)
    }

    @Test("isActive for creating status")
    func activeCreating() {
        let plan = TestPlanState(title: "P", phases: [], status: .creating, originalQuery: "Q")
        #expect(plan.isActive)
    }

    @Test("isActive for modifying status")
    func activeModifying() {
        let plan = TestPlanState(title: "P", phases: [], status: .modifying, originalQuery: "Q")
        #expect(plan.isActive)
    }

    @Test("Not active for completed status")
    func notActiveCompleted() {
        let plan = TestPlanState(title: "P", phases: [], status: .completed, originalQuery: "Q")
        #expect(!plan.isActive)
    }

    @Test("Not active for failed/cancelled/paused")
    func notActiveTerminal() {
        for status: TestPlanStatus in [.failed, .cancelled, .paused] {
            let plan = TestPlanState(title: "P", phases: [], status: status, originalQuery: "Q")
            #expect(!plan.isActive)
        }
    }

    @Test("Default status is creating")
    func defaultStatus() {
        let plan = TestPlanState(title: "P", phases: [], originalQuery: "Q")
        #expect(plan.status == .creating)
    }

    @Test("Plan Codable roundtrip")
    func codableRoundtrip() throws {
        let steps = [TestPlanStep(title: "Build", activeDescription: "Building...", status: .completed)]
        let phase = TestPlanPhase(title: "Phase 1", steps: steps)
        let plan = TestPlanState(title: "Test Plan", phases: [phase],
                                  status: .completed, originalQuery: "Run everything")
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(TestPlanState.self, from: data)
        #expect(decoded.title == "Test Plan")
        #expect(decoded.status == .completed)
        #expect(decoded.totalSteps == 1)
        #expect(decoded.completedSteps == 1)
        #expect(decoded.progress == 1.0)
    }
}
