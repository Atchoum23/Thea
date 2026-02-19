// TaskPlanDAGTests.swift
// Tests for TaskPlanDAG — DAG-based task planner
//
// Tests cover: plan creation, goal decomposition patterns, DAG validation,
// plan/node structures, status management, cleanup, and error types.
// Node execution (AI/integration) is not tested as it requires live providers.

@testable import TheaCore
import XCTest

// MARK: - Supporting value type tests (no actor/MainActor needed)

final class TaskPlanNodeTests: XCTestCase {

    func testNodeInitSetsAllFields() {
        let node = TaskPlanNode(
            title: "My Node",
            action: "Do something",
            actionType: .aiQuery,
            dependsOn: []
        )
        XCTAssertEqual(node.title, "My Node")
        XCTAssertEqual(node.action, "Do something")
        XCTAssertEqual(node.actionType, .aiQuery)
        XCTAssertTrue(node.dependsOn.isEmpty)
        XCTAssertEqual(node.status, .pending)
        XCTAssertNil(node.result)
    }

    func testNodeIDIsUnique() {
        let n1 = TaskPlanNode(title: "A", action: "a", actionType: .aiQuery, dependsOn: [])
        let n2 = TaskPlanNode(title: "A", action: "a", actionType: .aiQuery, dependsOn: [])
        XCTAssertNotEqual(n1.id, n2.id)
    }

    func testActionTypeAllCases() {
        let types: [TaskPlanNode.ActionType] = [.aiQuery, .integration, .compound, .userInput]
        for type_ in types {
            XCTAssertFalse(type_.rawValue.isEmpty)
        }
    }

    func testNodeStatusAllCases() {
        let statuses: [TaskPlanNode.NodeStatus] = [.pending, .executing, .completed, .failed]
        for s in statuses {
            XCTAssertFalse(s.rawValue.isEmpty)
        }
    }
}

// MARK: - TaskNodeResult Tests

final class TaskNodeResultTests: XCTestCase {

    func testSuccessResult() {
        let result = TaskNodeResult(success: true, output: "Done")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "Done")
    }

    func testFailureResult() {
        let result = TaskNodeResult(success: false, output: "Error: timeout")
        XCTAssertFalse(result.success)
        XCTAssertFalse(result.output.isEmpty)
    }
}

// MARK: - TaskPlanResult Tests

final class TaskPlanResultTests: XCTestCase {

    func testAllSuccessResult() {
        let planID = UUID()
        let result = TaskPlanResult(
            planID: planID,
            success: true,
            completedNodes: 4,
            totalNodes: 4,
            results: [:]
        )
        XCTAssertEqual(result.planID, planID)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.completedNodes, 4)
        XCTAssertEqual(result.totalNodes, 4)
    }

    func testPartialSuccessResult() {
        let result = TaskPlanResult(
            planID: UUID(),
            success: false,
            completedNodes: 2,
            totalNodes: 5,
            results: [:]
        )
        XCTAssertFalse(result.success)
        XCTAssertLessThan(result.completedNodes, result.totalNodes)
    }
}

// MARK: - TaskPlanError Tests

final class TaskPlanErrorTests: XCTestCase {

    func testCyclicDependencyDescription() {
        let error = TaskPlanError.cyclicDependency
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
        XCTAssertTrue(error.errorDescription!.lowercased().contains("cycl"))
    }

    func testPlanNotFoundDescription() {
        let error = TaskPlanError.planNotFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testNodeExecutionFailedDescription() {
        let error = TaskPlanError.nodeExecutionFailed("timeout after 30s")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("timeout after 30s"))
    }
}

// MARK: - TaskPlan.PlanStatus Tests

final class PlanStatusTests: XCTestCase {

    func testAllStatusesHaveRawValues() {
        let statuses: [TaskPlan.PlanStatus] = [.ready, .executing, .completed, .partiallyCompleted, .failed]
        for s in statuses {
            XCTAssertFalse(s.rawValue.isEmpty)
        }
    }

    func testDistinctRawValues() {
        let statuses: [TaskPlan.PlanStatus] = [.ready, .executing, .completed, .partiallyCompleted, .failed]
        let rawValues = statuses.map { $0.rawValue }
        XCTAssertEqual(rawValues.count, Set(rawValues).count)
    }
}

// MARK: - TaskPlanDAG Tests (MainActor)

@MainActor
final class TaskPlanDAGTests: XCTestCase {

    private let dag = TaskPlanDAG.shared

    // MARK: - Initialization

    func testSharedSingletonNotNil() {
        XCTAssertNotNil(dag)
    }

    func testInitiallyNotPlanning() {
        // After init (or previous tests completing), isPlanning should be false
        XCTAssertFalse(dag.isPlanning)
    }

    // MARK: - Plan Creation (generic goal — single node)

    func testCreatePlanReturnsValidPlan() async throws {
        let plan = try await dag.createPlan(goal: "Tell me a joke")
        XCTAssertFalse(plan.goal.isEmpty)
        XCTAssertEqual(plan.goal, "Tell me a joke")
        XCTAssertFalse(plan.nodes.isEmpty)
        XCTAssertEqual(plan.status, .ready)
    }

    func testCreatePlanAddsToActivePlans() async throws {
        let countBefore = dag.activePlans.count
        _ = try await dag.createPlan(goal: "Generic query \(UUID().uuidString)")
        XCTAssertEqual(dag.activePlans.count, countBefore + 1)
    }

    func testCreatePlanForGenericGoalProducesSingleAINode() async throws {
        let plan = try await dag.createPlan(goal: "What is the capital of France?")
        XCTAssertEqual(plan.nodes.count, 1)
        XCTAssertEqual(plan.nodes.first?.actionType, .aiQuery)
    }

    func testCreatePlanNodeHasPendingStatus() async throws {
        let plan = try await dag.createPlan(goal: "Simple generic goal")
        for node in plan.nodes {
            XCTAssertEqual(node.status, .pending)
        }
    }

    func testIsNotPlanningAfterCreatePlanCompletes() async throws {
        _ = try await dag.createPlan(goal: "Measure planning state")
        // defer in createPlan sets isPlanning = false
        XCTAssertFalse(dag.isPlanning)
    }

    // MARK: - Goal Decomposition Patterns

    func testWeeklyPlanGoalProducesMultipleNodes() async throws {
        let plan = try await dag.createPlan(goal: "Plan my week for maximum productivity")
        XCTAssertGreaterThan(plan.nodes.count, 1)
    }

    func testWeeklyPlanGoalHasDependencies() async throws {
        let plan = try await dag.createPlan(goal: "plan my week")
        // The last aiQuery nodes depend on earlier integration nodes
        let dependentNodes = plan.nodes.filter { !$0.dependsOn.isEmpty }
        XCTAssertFalse(dependentNodes.isEmpty)
    }

    func testWeeklyPlanGoalHasIntegrationNodes() async throws {
        let plan = try await dag.createPlan(goal: "weekly plan")
        let integrationNodes = plan.nodes.filter { $0.actionType == .integration }
        XCTAssertFalse(integrationNodes.isEmpty)
    }

    func testMorningRoutineGoalProducesMultipleNodes() async throws {
        let plan = try await dag.createPlan(goal: "Help me start my day right")
        XCTAssertGreaterThan(plan.nodes.count, 1)
    }

    func testMorningRoutineHasDependentBriefingNode() async throws {
        let plan = try await dag.createPlan(goal: "morning routine")
        let dependentNodes = plan.nodes.filter { !$0.dependsOn.isEmpty }
        XCTAssertFalse(dependentNodes.isEmpty)
    }

    func testResearchGoalProducesMultipleNodes() async throws {
        let plan = try await dag.createPlan(goal: "research Swift concurrency best practices")
        XCTAssertGreaterThan(plan.nodes.count, 1)
    }

    func testResearchGoalHasOrganizeNode() async throws {
        let plan = try await dag.createPlan(goal: "research quantum computing")
        // Second node depends on first (search node)
        XCTAssertGreaterThanOrEqual(plan.nodes.count, 2)
        let lastNode = plan.nodes.last
        XCTAssertFalse(lastNode?.dependsOn.isEmpty ?? true)
    }

    // MARK: - DAG Validation

    func testValidPlanPassesValidation() async throws {
        // createPlan internally calls validateDAG — if cyclic, it throws
        // A simple linear plan is always valid, so no throw expected
        XCTAssertNoThrow(try await dag.createPlan(goal: "Simple query"))
    }

    func testPlanNodeDependenciesReferenceExistingNodes() async throws {
        let plan = try await dag.createPlan(goal: "plan my week")
        let nodeIDs = Set(plan.nodes.map { $0.id })

        for node in plan.nodes {
            for depID in node.dependsOn {
                XCTAssertTrue(nodeIDs.contains(depID), "Dependency \(depID) not found in plan nodes")
            }
        }
    }

    func testWeeklyPlanIsAcyclic() async throws {
        // If the DAG had a cycle, createPlan would throw .cyclicDependency
        XCTAssertNoThrow(try await dag.createPlan(goal: "plan my week please"))
    }

    func testMorningRoutineIsAcyclic() async throws {
        XCTAssertNoThrow(try await dag.createPlan(goal: "start my day with a briefing"))
    }

    func testResearchIsAcyclic() async throws {
        XCTAssertNoThrow(try await dag.createPlan(goal: "research machine learning trends"))
    }

    // MARK: - Plan Properties

    func testPlanHasUniqueID() async throws {
        let plan1 = try await dag.createPlan(goal: "Goal A")
        let plan2 = try await dag.createPlan(goal: "Goal B")
        XCTAssertNotEqual(plan1.id, plan2.id)
    }

    func testPlanCreatedAtIsRecent() async throws {
        let before = Date()
        let plan = try await dag.createPlan(goal: "Timing test goal")
        let after = Date()
        XCTAssertGreaterThanOrEqual(plan.createdAt, before)
        XCTAssertLessThanOrEqual(plan.createdAt, after)
    }

    // MARK: - Cleanup

    func testRemovePlanReducesActivePlans() async throws {
        let plan = try await dag.createPlan(goal: "Cleanup test \(UUID().uuidString)")
        let countAfterAdd = dag.activePlans.count

        dag.removePlan(plan.id)
        XCTAssertEqual(dag.activePlans.count, countAfterAdd - 1)
        XCTAssertFalse(dag.activePlans.contains { $0.id == plan.id })
    }

    func testRemoveNonExistentPlanIsNoop() async throws {
        let countBefore = dag.activePlans.count
        dag.removePlan(UUID())
        XCTAssertEqual(dag.activePlans.count, countBefore)
    }

    func testClearCompletedPlansOnlyRemovesCompleted() async throws {
        // Add two plans; manually mark one completed in activePlans
        let plan1 = try await dag.createPlan(goal: "Clear test A \(UUID().uuidString)")
        let plan2 = try await dag.createPlan(goal: "Clear test B \(UUID().uuidString)")

        // Mark plan1 as completed by directly mutating through the shared instance
        if let idx = dag.activePlans.firstIndex(where: { $0.id == plan1.id }) {
            dag.activePlans[idx].status = .completed
        }

        let countBefore = dag.activePlans.count
        dag.clearCompletedPlans()

        // Plan1 (completed) should be gone; Plan2 (ready) should remain
        XCTAssertFalse(dag.activePlans.contains { $0.id == plan1.id })
        XCTAssertTrue(dag.activePlans.contains { $0.id == plan2.id })
        XCTAssertLessThan(dag.activePlans.count, countBefore)
    }

    func testClearCompletedPlansWithNoneCompleted() async throws {
        let plan = try await dag.createPlan(goal: "Not completed \(UUID().uuidString)")
        let countBefore = dag.activePlans.count
        // All plans are .ready by default — nothing should be removed
        dag.clearCompletedPlans()
        XCTAssertTrue(dag.activePlans.contains { $0.id == plan.id })
        XCTAssertEqual(dag.activePlans.count, countBefore)
    }

    // MARK: - Edge Cases

    func testEmptyGoalProducesDefaultNode() async throws {
        // Empty string doesn't match any pattern → single aiQuery node
        let plan = try await dag.createPlan(goal: "")
        XCTAssertEqual(plan.nodes.count, 1)
        XCTAssertEqual(plan.nodes.first?.actionType, .aiQuery)
    }

    func testPlanWithContextDoesNotCrash() async throws {
        let plan = try await dag.createPlan(
            goal: "Research Swift actors",
            context: "User is building a concurrent app"
        )
        XCTAssertFalse(plan.nodes.isEmpty)
    }

    func testMultiplePlansAreIndependent() async throws {
        let planA = try await dag.createPlan(goal: "Weekly plan for Alice")
        let planB = try await dag.createPlan(goal: "Morning routine for Bob")
        XCTAssertNotEqual(planA.id, planB.id)
        XCTAssertNotEqual(planA.goal, planB.goal)
    }

    func testExecutePlanNotFoundThrows() async throws {
        // Create a fake plan that is NOT in activePlans
        let fakePlan = TaskPlan(
            id: UUID(),
            goal: "Non-existent plan",
            nodes: [],
            createdAt: Date(),
            status: .ready
        )
        do {
            _ = try await dag.execute(fakePlan)
            XCTFail("Expected TaskPlanError.planNotFound to be thrown")
        } catch TaskPlanError.planNotFound {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
