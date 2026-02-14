@testable import TheaModels
import XCTest

/// Advanced tests for PlanState: multi-phase progress, phase completion logic,
/// step duration edge cases, modification types, and Codable round-trips.
final class PlanStateAdvancedTests: XCTestCase {

    // MARK: - PlanStep Duration Edge Cases

    func testStepDurationNegativeInterval() {
        // End before start — should still compute (just negative)
        let start = Date(timeIntervalSince1970: 2000)
        let end = Date(timeIntervalSince1970: 1000)
        let step = PlanStep(
            title: "S",
            activeDescription: "S",
            startedAt: start,
            completedAt: end
        )
        let duration = step.duration
        XCTAssertNotNil(duration)
        XCTAssertLessThan(duration!, 0)
    }

    func testStepDurationSameStartAndEnd() {
        let date = Date()
        let step = PlanStep(
            title: "S",
            activeDescription: "S",
            startedAt: date,
            completedAt: date
        )
        XCTAssertEqual(step.duration, 0)
    }

    func testStepDurationLongRunning() throws {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 86400) // 24 hours
        let step = PlanStep(
            title: "S",
            activeDescription: "S",
            startedAt: start,
            completedAt: end
        )
        let duration = try XCTUnwrap(step.duration)
        XCTAssertEqual(duration, 86400, accuracy: 0.001)
    }

    // MARK: - PlanPhase — isComplete with All Statuses

    func testPhaseNotCompleteWithPending() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .pending)
        ]
        XCTAssertFalse(PlanPhase(title: "P", steps: steps).isComplete)
    }

    func testPhaseNotCompleteWithInProgress() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .inProgress)
        ]
        XCTAssertFalse(PlanPhase(title: "P", steps: steps).isComplete)
    }

    func testPhaseNotCompleteWithFailed() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .failed)
        ]
        XCTAssertFalse(PlanPhase(title: "P", steps: steps).isComplete)
    }

    func testPhaseNotCompleteWithModified() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .modified)
        ]
        XCTAssertFalse(PlanPhase(title: "P", steps: steps).isComplete)
    }

    func testPhaseCompleteAllCompleted() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .completed),
            PlanStep(title: "C", activeDescription: "C", status: .completed)
        ]
        XCTAssertTrue(PlanPhase(title: "P", steps: steps).isComplete)
    }

    func testPhaseCompleteWithMixOfCompletedAndSkipped() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .skipped),
            PlanStep(title: "C", activeDescription: "C", status: .completed),
            PlanStep(title: "D", activeDescription: "D", status: .skipped)
        ]
        XCTAssertTrue(PlanPhase(title: "P", steps: steps).isComplete)
    }

    func testPhaseAllSkipped() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .skipped),
            PlanStep(title: "B", activeDescription: "B", status: .skipped)
        ]
        XCTAssertTrue(PlanPhase(title: "P", steps: steps).isComplete)
    }

    // MARK: - PlanPhase — completedSteps vs skippedSteps

    func testCompletedStepsExcludesSkipped() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .skipped),
            PlanStep(title: "C", activeDescription: "C", status: .completed)
        ]
        let phase = PlanPhase(title: "P", steps: steps)
        XCTAssertEqual(phase.completedSteps, 2)
        XCTAssertEqual(phase.totalSteps, 3)
    }

    func testProgressExcludesSkippedFromNumerator() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .skipped),
            PlanStep(title: "C", activeDescription: "C", status: .pending),
            PlanStep(title: "D", activeDescription: "D", status: .pending)
        ]
        let phase = PlanPhase(title: "P", steps: steps)
        // 1 completed / 4 total = 0.25
        XCTAssertEqual(phase.progress, 0.25, accuracy: 0.001)
    }

    // MARK: - PlanPhase — currentStep

    func testCurrentStepReturnsFirstInProgress() {
        let steps = [
            PlanStep(title: "Done", activeDescription: "Done", status: .completed),
            PlanStep(title: "Active1", activeDescription: "Working 1", status: .inProgress),
            PlanStep(title: "Active2", activeDescription: "Working 2", status: .inProgress),
            PlanStep(title: "Pending", activeDescription: "Waiting", status: .pending)
        ]
        let phase = PlanPhase(title: "P", steps: steps)
        XCTAssertEqual(phase.currentStep?.title, "Active1")
    }

    func testCurrentStepNilWhenAllCompleted() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .completed),
            PlanStep(title: "B", activeDescription: "B", status: .completed)
        ]
        XCTAssertNil(PlanPhase(title: "P", steps: steps).currentStep)
    }

    func testCurrentStepNilWhenAllPending() {
        let steps = [
            PlanStep(title: "A", activeDescription: "A", status: .pending),
            PlanStep(title: "B", activeDescription: "B", status: .pending)
        ]
        XCTAssertNil(PlanPhase(title: "P", steps: steps).currentStep)
    }

    // MARK: - PlanState — Multi-Phase Progress

    func testProgressAcrossThreePhases() {
        let p1 = PlanPhase(title: "P1", steps: [
            PlanStep(title: "1", activeDescription: "1", status: .completed),
            PlanStep(title: "2", activeDescription: "2", status: .completed)
        ])
        let p2 = PlanPhase(title: "P2", steps: [
            PlanStep(title: "3", activeDescription: "3", status: .completed),
            PlanStep(title: "4", activeDescription: "4", status: .inProgress)
        ])
        let p3 = PlanPhase(title: "P3", steps: [
            PlanStep(title: "5", activeDescription: "5", status: .pending),
            PlanStep(title: "6", activeDescription: "6", status: .pending)
        ])
        let state = PlanState(
            title: "Big Plan",
            phases: [p1, p2, p3],
            originalQuery: "Do everything"
        )
        XCTAssertEqual(state.totalSteps, 6)
        XCTAssertEqual(state.completedSteps, 3)
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.001)
    }

    func testCurrentStepTitleFromSecondPhase() {
        let p1 = PlanPhase(title: "P1", steps: [
            PlanStep(title: "Done1", activeDescription: "Done step", status: .completed)
        ])
        let p2 = PlanPhase(title: "P2", steps: [
            PlanStep(title: "Active", activeDescription: "Currently working", status: .inProgress)
        ])
        let state = PlanState(
            title: "Plan",
            phases: [p1, p2],
            originalQuery: "Q"
        )
        XCTAssertEqual(state.currentStepTitle, "Currently working")
    }

    func testCurrentStepTitleNilWhenAllComplete() {
        let phase = PlanPhase(title: "P", steps: [
            PlanStep(title: "Done", activeDescription: "Done", status: .completed)
        ])
        let state = PlanState(
            title: "Plan",
            phases: [phase],
            status: .completed,
            originalQuery: "Q"
        )
        XCTAssertNil(state.currentStepTitle)
    }

    // MARK: - PlanStatus — isActive

    func testAllStatusesIsActive() {
        let activeStatuses: [PlanStatus] = [.creating, .executing, .modifying]
        let inactiveStatuses: [PlanStatus] = [.paused, .completed, .failed, .cancelled]

        for status in activeStatuses {
            let state = PlanState(title: "P", phases: [], status: status, originalQuery: "Q")
            XCTAssertTrue(state.isActive, "\(status) should be active")
        }
        for status in inactiveStatuses {
            let state = PlanState(title: "P", phases: [], status: status, originalQuery: "Q")
            XCTAssertFalse(state.isActive, "\(status) should not be active")
        }
    }

    // MARK: - PlanStatus Codable

    func testAllPlanStatusesCodable() throws {
        let allStatuses: [PlanStatus] = [
            .creating, .executing, .paused, .completed, .failed, .cancelled, .modifying
        ]
        for status in allStatuses {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(PlanStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - PlanState Codable

    func testPlanStateCodableRoundtrip() throws {
        let step = PlanStep(
            title: "Build",
            activeDescription: "Building",
            status: .inProgress,
            taskType: "coding",
            startedAt: Date(timeIntervalSince1970: 1000),
            modelUsed: "claude-4"
        )
        let phase = PlanPhase(title: "Phase 1", steps: [step])
        let state = PlanState(
            title: "My Plan",
            phases: [phase],
            status: .executing,
            conversationId: UUID(),
            originalQuery: "Build the app"
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PlanState.self, from: data)

        XCTAssertEqual(decoded.title, "My Plan")
        XCTAssertEqual(decoded.status, .executing)
        XCTAssertEqual(decoded.originalQuery, "Build the app")
        XCTAssertEqual(decoded.phases.count, 1)
        XCTAssertEqual(decoded.phases[0].steps.count, 1)
        XCTAssertEqual(decoded.phases[0].steps[0].title, "Build")
        XCTAssertEqual(decoded.phases[0].steps[0].modelUsed, "claude-4")
    }

    // MARK: - PlanModification Types

    func testModificationUpdateStep() {
        let stepId = UUID()
        let mod = PlanModification(
            type: .updateStep(stepId, newTitle: "Updated Title", newDescription: "New desc"),
            reason: "Changed requirements"
        )
        if case let .updateStep(id, title, desc) = mod.type {
            XCTAssertEqual(id, stepId)
            XCTAssertEqual(title, "Updated Title")
            XCTAssertEqual(desc, "New desc")
        } else {
            XCTFail("Expected .updateStep")
        }
    }

    func testModificationReorderPhases() {
        let ids = [UUID(), UUID(), UUID()]
        let mod = PlanModification(
            type: .reorderPhases(ids),
            reason: "Reordering"
        )
        if case let .reorderPhases(phaseIds) = mod.type {
            XCTAssertEqual(phaseIds.count, 3)
        } else {
            XCTFail("Expected .reorderPhases")
        }
    }

    func testModificationAddPhase() {
        let newPhase = PlanPhase(title: "New Phase", steps: [
            PlanStep(title: "S1", activeDescription: "Step 1")
        ])
        let mod = PlanModification(
            type: .addPhase(newPhase, atIndex: 2),
            reason: "Adding phase"
        )
        if case let .addPhase(phase, index) = mod.type {
            XCTAssertEqual(phase.title, "New Phase")
            XCTAssertEqual(index, 2)
        } else {
            XCTFail("Expected .addPhase")
        }
    }

    func testModificationInsertStepsAfterNil() {
        let newStep = PlanStep(title: "First", activeDescription: "First step")
        let mod = PlanModification(
            type: .insertSteps([newStep], afterStepId: nil),
            reason: "Insert at beginning"
        )
        if case let .insertSteps(steps, afterId) = mod.type {
            XCTAssertEqual(steps.count, 1)
            XCTAssertNil(afterId)
        } else {
            XCTFail("Expected .insertSteps")
        }
    }
}
