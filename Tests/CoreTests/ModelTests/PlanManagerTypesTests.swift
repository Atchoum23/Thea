import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Core/Managers/PlanManager.swift)

private enum TestPlanStatusPM: String, Sendable, CaseIterable {
    case creating
    case ready
    case executing
    case modifying
    case completed
    case cancelled
    case failed

    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed: return true
        case .creating, .ready, .executing, .modifying: return false
        }
    }

    var isActive: Bool {
        self == .executing || self == .modifying
    }

    var canStart: Bool {
        self == .ready
    }

    var canCancel: Bool {
        !isTerminal
    }
}

private enum TestStepStatus: String, Sendable, CaseIterable {
    case pending
    case inProgress
    case completed
    case failed
    case skipped
    case modified

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .skipped: return true
        case .pending, .inProgress, .modified: return false
        }
    }

    var isActive: Bool {
        self == .inProgress
    }
}

private struct TestPlanStep: Identifiable, Sendable {
    let id: UUID
    var title: String
    var activeDescription: String
    var taskType: String
    var status: TestStepStatus
    var startedAt: Date?
    var completedAt: Date?
    var result: String?
    var error: String?
    var modelUsed: String?

    init(title: String, activeDescription: String = "", taskType: String = "general") {
        self.id = UUID()
        self.title = title
        self.activeDescription = activeDescription.isEmpty ? "Working on \(title)" : activeDescription
        self.taskType = taskType
        self.status = .pending
    }

    var duration: TimeInterval? {
        guard let start = startedAt, let end = completedAt else { return nil }
        return end.timeIntervalSince(start)
    }
}

private struct TestPlanPhase: Identifiable, Sendable {
    let id: UUID
    let title: String
    var steps: [TestPlanStep]

    init(title: String, steps: [TestPlanStep] = []) {
        self.id = UUID()
        self.title = title
        self.steps = steps
    }

    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        let completed = steps.filter { $0.status == .completed }.count
        return Double(completed) / Double(steps.count)
    }

    var isComplete: Bool {
        !steps.isEmpty && steps.allSatisfy { $0.status.isTerminal }
    }

    var currentStep: TestPlanStep? {
        steps.first { $0.status == .inProgress }
    }

    var nextPendingStep: TestPlanStep? {
        steps.first { $0.status == .pending }
    }
}

private struct TestPlanStatePM: Identifiable, Sendable {
    let id: UUID
    var title: String
    var phases: [TestPlanPhase]
    var status: TestPlanStatusPM
    var conversationId: UUID?
    var originalQuery: String
    let createdAt: Date
    var updatedAt: Date

    init(title: String, phases: [TestPlanPhase] = [], originalQuery: String = "") {
        self.id = UUID()
        self.title = title
        self.phases = phases
        self.status = .creating
        self.originalQuery = originalQuery
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var overallProgress: Double {
        guard !phases.isEmpty else { return 0 }
        let totalSteps = phases.flatMap(\.steps).count
        guard totalSteps > 0 else { return 0 }
        let completedSteps = phases.flatMap(\.steps).filter { $0.status == .completed }.count
        return Double(completedSteps) / Double(totalSteps)
    }

    var totalSteps: Int {
        phases.flatMap(\.steps).count
    }

    var completedSteps: Int {
        phases.flatMap(\.steps).filter { $0.status == .completed }.count
    }

    var failedSteps: Int {
        phases.flatMap(\.steps).filter { $0.status == .failed }.count
    }

    var currentPhase: TestPlanPhase? {
        phases.first { !$0.isComplete }
    }

    var isComplete: Bool {
        !phases.isEmpty && phases.allSatisfy(\.isComplete)
    }
}

// MARK: - Plan Management Logic

private func createSimplePlan(title: String, steps: [String]) -> TestPlanStatePM {
    let planSteps = steps.map { TestPlanStep(title: $0) }
    let phase = TestPlanPhase(title: "Main", steps: planSteps)
    var plan = TestPlanStatePM(title: title, phases: [phase])
    plan.status = .ready
    return plan
}

private func startExecution(_ plan: inout TestPlanStatePM) {
    guard plan.status.canStart else { return }
    plan.status = .executing
    plan.updatedAt = Date()
}

private func stepStarted(_ plan: inout TestPlanStatePM, stepId: UUID, modelUsed: String? = nil) {
    for phaseIndex in plan.phases.indices {
        if let stepIndex = plan.phases[phaseIndex].steps.firstIndex(where: { $0.id == stepId }) {
            plan.phases[phaseIndex].steps[stepIndex].status = .inProgress
            plan.phases[phaseIndex].steps[stepIndex].startedAt = Date()
            plan.phases[phaseIndex].steps[stepIndex].modelUsed = modelUsed
            plan.updatedAt = Date()
            return
        }
    }
}

private func stepCompleted(_ plan: inout TestPlanStatePM, stepId: UUID, result: String? = nil) {
    for phaseIndex in plan.phases.indices {
        if let stepIndex = plan.phases[phaseIndex].steps.firstIndex(where: { $0.id == stepId }) {
            plan.phases[phaseIndex].steps[stepIndex].status = .completed
            plan.phases[phaseIndex].steps[stepIndex].completedAt = Date()
            plan.phases[phaseIndex].steps[stepIndex].result = result
            plan.updatedAt = Date()
            // Check if plan is complete
            if plan.isComplete {
                plan.status = .completed
            }
            return
        }
    }
}

private func stepFailed(_ plan: inout TestPlanStatePM, stepId: UUID, error: String) {
    for phaseIndex in plan.phases.indices {
        if let stepIndex = plan.phases[phaseIndex].steps.firstIndex(where: { $0.id == stepId }) {
            plan.phases[phaseIndex].steps[stepIndex].status = .failed
            plan.phases[phaseIndex].steps[stepIndex].completedAt = Date()
            plan.phases[phaseIndex].steps[stepIndex].error = error
            plan.updatedAt = Date()
            return
        }
    }
}

private func cancelPlan(_ plan: inout TestPlanStatePM) {
    guard plan.status.canCancel else { return }
    plan.status = .cancelled
    plan.updatedAt = Date()
}

// MARK: - Tests

@Suite("PlanStatus Enum")
struct PlanStatusPMTests {
    @Test("All 7 statuses exist")
    func allCases() {
        #expect(TestPlanStatusPM.allCases.count == 7)
    }

    @Test("Terminal states")
    func terminalStates() {
        #expect(TestPlanStatusPM.completed.isTerminal)
        #expect(TestPlanStatusPM.cancelled.isTerminal)
        #expect(TestPlanStatusPM.failed.isTerminal)
        #expect(!TestPlanStatusPM.creating.isTerminal)
        #expect(!TestPlanStatusPM.ready.isTerminal)
        #expect(!TestPlanStatusPM.executing.isTerminal)
    }

    @Test("Active states")
    func activeStates() {
        #expect(TestPlanStatusPM.executing.isActive)
        #expect(TestPlanStatusPM.modifying.isActive)
        #expect(!TestPlanStatusPM.ready.isActive)
    }

    @Test("Can start only from ready")
    func canStart() {
        #expect(TestPlanStatusPM.ready.canStart)
        #expect(!TestPlanStatusPM.creating.canStart)
        #expect(!TestPlanStatusPM.executing.canStart)
        #expect(!TestPlanStatusPM.completed.canStart)
    }

    @Test("Can cancel non-terminal states")
    func canCancel() {
        #expect(TestPlanStatusPM.creating.canCancel)
        #expect(TestPlanStatusPM.ready.canCancel)
        #expect(TestPlanStatusPM.executing.canCancel)
        #expect(!TestPlanStatusPM.completed.canCancel)
        #expect(!TestPlanStatusPM.cancelled.canCancel)
    }
}

@Suite("StepStatus Enum")
struct StepStatusTests {
    @Test("All 6 statuses exist")
    func allCases() {
        #expect(TestStepStatus.allCases.count == 6)
    }

    @Test("Terminal states")
    func terminalStates() {
        #expect(TestStepStatus.completed.isTerminal)
        #expect(TestStepStatus.failed.isTerminal)
        #expect(TestStepStatus.skipped.isTerminal)
        #expect(!TestStepStatus.pending.isTerminal)
        #expect(!TestStepStatus.inProgress.isTerminal)
        #expect(!TestStepStatus.modified.isTerminal)
    }
}

@Suite("PlanStep Struct")
struct PlanStepTests {
    @Test("Creation with defaults")
    func creation() {
        let step = TestPlanStep(title: "Research")
        #expect(step.title == "Research")
        #expect(step.activeDescription == "Working on Research")
        #expect(step.status == .pending)
        #expect(step.startedAt == nil)
        #expect(step.completedAt == nil)
    }

    @Test("Custom active description")
    func customDescription() {
        let step = TestPlanStep(title: "Build", activeDescription: "Building project")
        #expect(step.activeDescription == "Building project")
    }

    @Test("Duration calculation")
    func duration() {
        var step = TestPlanStep(title: "Test")
        step.startedAt = Date(timeIntervalSince1970: 1000)
        step.completedAt = Date(timeIntervalSince1970: 1010)
        #expect(step.duration == 10.0)
    }

    @Test("Duration nil when incomplete")
    func durationNil() {
        var step = TestPlanStep(title: "Test")
        step.startedAt = Date()
        #expect(step.duration == nil)
    }
}

@Suite("PlanPhase Struct")
struct PlanPhaseTests {
    @Test("Creation with steps")
    func creation() {
        let phase = TestPlanPhase(title: "Phase 1", steps: [
            TestPlanStep(title: "A"),
            TestPlanStep(title: "B")
        ])
        #expect(phase.title == "Phase 1")
        #expect(phase.steps.count == 2)
    }

    @Test("Progress calculation")
    func progress() {
        var phase = TestPlanPhase(title: "Test", steps: [
            TestPlanStep(title: "A"),
            TestPlanStep(title: "B"),
            TestPlanStep(title: "C"),
            TestPlanStep(title: "D")
        ])
        phase.steps[0].status = .completed
        phase.steps[1].status = .completed
        #expect(phase.progress == 0.5)
    }

    @Test("Empty phase progress is 0")
    func emptyProgress() {
        let phase = TestPlanPhase(title: "Empty")
        #expect(phase.progress == 0)
    }

    @Test("Phase completion")
    func completion() {
        var phase = TestPlanPhase(title: "Test", steps: [
            TestPlanStep(title: "A"),
            TestPlanStep(title: "B")
        ])
        #expect(!phase.isComplete)
        phase.steps[0].status = .completed
        phase.steps[1].status = .completed
        #expect(phase.isComplete)
    }

    @Test("Phase complete with mixed terminal states")
    func mixedTerminal() {
        var phase = TestPlanPhase(title: "Test", steps: [
            TestPlanStep(title: "A"),
            TestPlanStep(title: "B")
        ])
        phase.steps[0].status = .completed
        phase.steps[1].status = .skipped
        #expect(phase.isComplete) // Both terminal
    }

    @Test("Current step")
    func currentStep() {
        var phase = TestPlanPhase(title: "Test", steps: [
            TestPlanStep(title: "A"),
            TestPlanStep(title: "B")
        ])
        #expect(phase.currentStep == nil)
        phase.steps[0].status = .inProgress
        #expect(phase.currentStep?.title == "A")
    }

    @Test("Next pending step")
    func nextPending() {
        var phase = TestPlanPhase(title: "Test", steps: [
            TestPlanStep(title: "A"),
            TestPlanStep(title: "B")
        ])
        phase.steps[0].status = .completed
        #expect(phase.nextPendingStep?.title == "B")
    }
}

@Suite("PlanState Struct")
struct PlanStatePMTests {
    @Test("Overall progress")
    func overallProgress() {
        var plan = createSimplePlan(title: "Test", steps: ["A", "B", "C", "D"])
        #expect(plan.overallProgress == 0)
        let step1 = plan.phases[0].steps[0].id
        let step2 = plan.phases[0].steps[1].id
        stepCompleted(&plan, stepId: step1)
        stepCompleted(&plan, stepId: step2)
        #expect(plan.overallProgress == 0.5)
    }

    @Test("Total and completed step counts")
    func stepCounts() {
        var plan = createSimplePlan(title: "Test", steps: ["A", "B", "C"])
        #expect(plan.totalSteps == 3)
        #expect(plan.completedSteps == 0)
        stepCompleted(&plan, stepId: plan.phases[0].steps[0].id)
        #expect(plan.completedSteps == 1)
    }

    @Test("Failed step count")
    func failedSteps() {
        var plan = createSimplePlan(title: "Test", steps: ["A", "B"])
        stepFailed(&plan, stepId: plan.phases[0].steps[0].id, error: "timeout")
        #expect(plan.failedSteps == 1)
    }
}

@Suite("Plan Lifecycle")
struct PlanLifecycleTests {
    @Test("Create simple plan")
    func createPlan() {
        let plan = createSimplePlan(title: "Build App", steps: ["Design", "Implement", "Test"])
        #expect(plan.title == "Build App")
        #expect(plan.status == .ready)
        #expect(plan.totalSteps == 3)
    }

    @Test("Start execution")
    func startExec() {
        var plan = createSimplePlan(title: "Test", steps: ["A"])
        startExecution(&plan)
        #expect(plan.status == .executing)
    }

    @Test("Cannot start non-ready plan")
    func cannotStartCreating() {
        var plan = TestPlanStatePM(title: "Test")
        plan.status = .creating
        startExecution(&plan)
        #expect(plan.status == .creating) // Unchanged
    }

    @Test("Step lifecycle: start → complete")
    func stepLifecycle() {
        var plan = createSimplePlan(title: "Test", steps: ["A"])
        startExecution(&plan)
        let stepId = plan.phases[0].steps[0].id
        stepStarted(&plan, stepId: stepId, modelUsed: "claude-opus-4-6")
        #expect(plan.phases[0].steps[0].status == .inProgress)
        #expect(plan.phases[0].steps[0].modelUsed == "claude-opus-4-6")
        stepCompleted(&plan, stepId: stepId, result: "Done")
        #expect(plan.phases[0].steps[0].status == .completed)
        #expect(plan.phases[0].steps[0].result == "Done")
    }

    @Test("Step lifecycle: start → fail")
    func stepFailure() {
        var plan = createSimplePlan(title: "Test", steps: ["A"])
        let stepId = plan.phases[0].steps[0].id
        stepStarted(&plan, stepId: stepId)
        stepFailed(&plan, stepId: stepId, error: "Network error")
        #expect(plan.phases[0].steps[0].status == .failed)
        #expect(plan.phases[0].steps[0].error == "Network error")
    }

    @Test("Plan auto-completes when all steps done")
    func autoComplete() {
        var plan = createSimplePlan(title: "Test", steps: ["A", "B"])
        startExecution(&plan)
        stepCompleted(&plan, stepId: plan.phases[0].steps[0].id)
        #expect(plan.status == .executing)
        stepCompleted(&plan, stepId: plan.phases[0].steps[1].id)
        #expect(plan.status == .completed)
    }

    @Test("Cancel plan")
    func cancel() {
        var plan = createSimplePlan(title: "Test", steps: ["A"])
        startExecution(&plan)
        cancelPlan(&plan)
        #expect(plan.status == .cancelled)
    }

    @Test("Cannot cancel completed plan")
    func cannotCancelCompleted() {
        var plan = createSimplePlan(title: "Test", steps: ["A"])
        startExecution(&plan)
        stepCompleted(&plan, stepId: plan.phases[0].steps[0].id)
        #expect(plan.status == .completed)
        cancelPlan(&plan)
        #expect(plan.status == .completed) // Unchanged
    }
}

@Suite("Multi-Phase Plans")
struct MultiPhasePlanTests {
    @Test("Multiple phases tracked independently")
    func multiPhase() {
        let phase1 = TestPlanPhase(title: "Design", steps: [
            TestPlanStep(title: "Wireframes"),
            TestPlanStep(title: "Mockups")
        ])
        let phase2 = TestPlanPhase(title: "Implementation", steps: [
            TestPlanStep(title: "Frontend"),
            TestPlanStep(title: "Backend")
        ])
        let plan = TestPlanStatePM(title: "Project", phases: [phase1, phase2])
        #expect(plan.totalSteps == 4)
        #expect(plan.phases.count == 2)
    }

    @Test("Current phase is first incomplete")
    func currentPhase() {
        var phase1 = TestPlanPhase(title: "Phase 1", steps: [TestPlanStep(title: "A")])
        let phase2 = TestPlanPhase(title: "Phase 2", steps: [TestPlanStep(title: "B")])
        phase1.steps[0].status = .completed
        let plan = TestPlanStatePM(title: "Test", phases: [phase1, phase2])
        #expect(plan.currentPhase?.title == "Phase 2")
    }
}
