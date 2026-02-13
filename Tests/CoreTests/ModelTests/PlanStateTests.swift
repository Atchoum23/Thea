@testable import TheaModels
import XCTest

final class PlanStateTests: XCTestCase {

    // MARK: - PlanStepStatus

    func testPlanStepStatusAllCases() {
        let cases: [PlanStepStatus] = [.pending, .inProgress, .completed, .failed, .skipped, .modified]
        XCTAssertEqual(cases.count, 6)
    }

    func testPlanStepStatusCodableRoundtrip() throws {
        for status in [PlanStepStatus.pending, .inProgress, .completed, .failed, .skipped, .modified] {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(PlanStepStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - PlanStep

    func testPlanStepDefaults() {
        let step = PlanStep(title: "Test", activeDescription: "Testing")
        XCTAssertEqual(step.status, .pending)
        XCTAssertEqual(step.taskType, "general")
        XCTAssertNil(step.result)
        XCTAssertNil(step.error)
        XCTAssertNil(step.startedAt)
        XCTAssertNil(step.completedAt)
        XCTAssertNil(step.modelUsed)
        XCTAssertNil(step.subQueryId)
    }

    func testPlanStepDurationBothDatesSet() throws {
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 1060)
        let step = PlanStep(
            title: "Step",
            activeDescription: "Doing step",
            startedAt: start,
            completedAt: end
        )
        let duration = try XCTUnwrap(step.duration)
        XCTAssertEqual(duration, 60.0, accuracy: 0.001)
    }

    func testPlanStepDurationNoStartDate() {
        let step = PlanStep(
            title: "Step",
            activeDescription: "Doing step",
            completedAt: Date()
        )
        XCTAssertNil(step.duration)
    }

    func testPlanStepDurationNoEndDate() {
        let step = PlanStep(
            title: "Step",
            activeDescription: "Doing step",
            startedAt: Date()
        )
        XCTAssertNil(step.duration)
    }

    func testPlanStepDurationNoDates() {
        let step = PlanStep(title: "Step", activeDescription: "Doing step")
        XCTAssertNil(step.duration)
    }

    func testPlanStepCodableRoundtrip() throws {
        let step = PlanStep(
            title: "Build UI",
            activeDescription: "Building the UI",
            status: .inProgress,
            taskType: "frontend",
            modelUsed: "gpt-4"
        )
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(PlanStep.self, from: data)
        XCTAssertEqual(decoded.title, "Build UI")
        XCTAssertEqual(decoded.status, .inProgress)
        XCTAssertEqual(decoded.taskType, "frontend")
        XCTAssertEqual(decoded.modelUsed, "gpt-4")
    }

    // MARK: - PlanPhase

    func testPlanPhaseEmptySteps() {
        let phase = PlanPhase(title: "Empty Phase", steps: [])
        XCTAssertEqual(phase.completedSteps, 0)
        XCTAssertEqual(phase.totalSteps, 0)
        XCTAssertTrue(phase.isComplete) // allSatisfy on empty is true
        XCTAssertNil(phase.currentStep)
        XCTAssertEqual(phase.progress, 0)
    }

    func testPlanPhaseProgress() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .inProgress),
            PlanStep(title: "C", activeDescription: "C", status: .pending),
            PlanStep(title: "D", activeDescription: "D", status: .completed)
        ]
        let phase = PlanPhase(title: "Phase 1", steps: steps)

        XCTAssertEqual(phase.completedSteps, 2)
        XCTAssertEqual(phase.totalSteps, 4)
        XCTAssertEqual(phase.progress, 0.5, accuracy: 0.001)
        XCTAssertFalse(phase.isComplete)
    }

    func testPlanPhaseCurrentStep() {
        let steps = [
            PlanStep(title: "Done", activeDescription: "Done", status: .completed),
            PlanStep(title: "Active", activeDescription: "Working on it", status: .inProgress),
            PlanStep(title: "Next", activeDescription: "Next", status: .pending)
        ]
        let phase = PlanPhase(title: "Phase", steps: steps)

        XCTAssertEqual(phase.currentStep?.title, "Active")
        XCTAssertEqual(phase.currentStep?.activeDescription, "Working on it")
    }

    func testPlanPhaseCompleteWithSkipped() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .skipped),
            PlanStep(title: "C", activeDescription: "C", status: .completed)
        ]
        let phase = PlanPhase(title: "Phase", steps: steps)
        XCTAssertTrue(phase.isComplete)
        XCTAssertEqual(phase.completedSteps, 2) // Only .completed, not .skipped
    }

    // MARK: - PlanStatus

    func testPlanStatusDisplayNames() {
        XCTAssertEqual(PlanStatus.creating.displayName, "Creating plan...")
        XCTAssertEqual(PlanStatus.executing.displayName, "Executing")
        XCTAssertEqual(PlanStatus.paused.displayName, "Paused")
        XCTAssertEqual(PlanStatus.completed.displayName, "Completed")
        XCTAssertEqual(PlanStatus.failed.displayName, "Failed")
        XCTAssertEqual(PlanStatus.cancelled.displayName, "Cancelled")
        XCTAssertEqual(PlanStatus.modifying.displayName, "Updating plan...")
    }

    // MARK: - PlanState

    func testPlanStateDefaults() {
        let state = PlanState(
            title: "My Plan",
            phases: [],
            originalQuery: "Do something"
        )
        XCTAssertEqual(state.status, .creating)
        XCTAssertNil(state.conversationId)
        XCTAssertEqual(state.totalSteps, 0)
        XCTAssertEqual(state.completedSteps, 0)
        XCTAssertEqual(state.progress, 0)
        XCTAssertNil(state.currentStepTitle)
    }

    func testPlanStateProgressAcrossPhases() {
        let phase1 = PlanPhase(title: "P1", steps: [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .completed)
        ])
        let phase2 = PlanPhase(title: "P2", steps: [
            PlanStep(title: "C", activeDescription: "C", status: .pending),
            PlanStep(title: "D", activeDescription: "D", status: .pending)
        ])
        let state = PlanState(
            title: "Plan",
            phases: [phase1, phase2],
            originalQuery: "Build app"
        )

        XCTAssertEqual(state.totalSteps, 4)
        XCTAssertEqual(state.completedSteps, 2)
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.001)
    }

    func testPlanStateCurrentStepTitle() {
        let phase = PlanPhase(title: "P1", steps: [
            PlanStep(title: "Done", activeDescription: "Done step", status: .completed),
            PlanStep(title: "Active", activeDescription: "Working on active", status: .inProgress)
        ])
        let state = PlanState(
            title: "Plan",
            phases: [phase],
            originalQuery: "Query"
        )
        XCTAssertEqual(state.currentStepTitle, "Working on active")
    }

    func testPlanStateIsActive() {
        let base = { (status: PlanStatus) in
            PlanState(title: "P", phases: [], status: status, originalQuery: "Q")
        }

        XCTAssertTrue(base(.creating).isActive)
        XCTAssertTrue(base(.executing).isActive)
        XCTAssertTrue(base(.modifying).isActive)
        XCTAssertFalse(base(.paused).isActive)
        XCTAssertFalse(base(.completed).isActive)
        XCTAssertFalse(base(.failed).isActive)
        XCTAssertFalse(base(.cancelled).isActive)
    }

    // MARK: - PlanModification

    func testPlanModificationInsertSteps() {
        let newSteps = [PlanStep(title: "New", activeDescription: "New step")]
        let mod = PlanModification(
            type: .insertSteps(newSteps, afterStepId: UUID()),
            reason: "Need more steps"
        )
        XCTAssertEqual(mod.reason, "Need more steps")

        if case .insertSteps(let steps, _) = mod.type {
            XCTAssertEqual(steps.count, 1)
        } else {
            XCTFail("Expected insertSteps")
        }
    }

    func testPlanModificationRemoveSteps() {
        let ids = [UUID(), UUID()]
        let mod = PlanModification(type: .removeSteps(ids), reason: "Cleanup")

        if case .removeSteps(let removedIds) = mod.type {
            XCTAssertEqual(removedIds.count, 2)
        } else {
            XCTFail("Expected removeSteps")
        }
    }
}
