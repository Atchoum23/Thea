// TaskPlanDAGServiceTests.swift
// Tests for TaskPlanDAG service logic: goal decomposition patterns, plan management,
// execution simulation, and DAG validation via Kahn's algorithm.

import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Intelligence/Planning/TaskPlanDAG.swift)

private enum TPlanStatus: String, Sendable, Codable {
    case ready, executing, completed, partiallyCompleted, failed
}

private enum TActionType: String, Sendable, Codable {
    case aiQuery, integration, compound, userInput
}

private enum TNodeStatus: String, Sendable, Codable {
    case pending, executing, completed, failed
}

private struct TPlanNode: Identifiable, Sendable {
    let id: UUID
    let title: String
    let action: String
    let actionType: TActionType
    let dependsOn: [UUID]
    var status: TNodeStatus = .pending
    var result: String?

    init(title: String, action: String, actionType: TActionType = .aiQuery, dependsOn: [UUID] = []) {
        self.id = UUID()
        self.title = title
        self.action = action
        self.actionType = actionType
        self.dependsOn = dependsOn
    }
}

private struct TPlan: Identifiable, Sendable {
    let id: UUID
    let goal: String
    var nodes: [TPlanNode]
    let createdAt: Date
    var status: TPlanStatus

    init(goal: String, nodes: [TPlanNode] = []) {
        self.id = UUID()
        self.goal = goal
        self.nodes = nodes
        self.createdAt = Date()
        self.status = .ready
    }
}

private struct TNodeResult: Sendable {
    let success: Bool
    let output: String
}

private struct TPlanResult: Sendable {
    let planID: UUID
    let success: Bool
    let completedNodes: Int
    let totalNodes: Int
    let results: [UUID: TNodeResult]
}

// MARK: - Plan Manager (mirrors production TaskPlanDAG service logic)

// @unchecked Sendable: test helper class used in single-threaded test context; no concurrent access
private final class TestTaskPlanManager: @unchecked Sendable {
    var activePlans: [TPlan] = []

    // MARK: - Goal Decomposition

    func decompose(goal: String) -> [TPlanNode] {
        let lower = goal.lowercased()

        if lower.contains("plan my week") || lower.contains("weekly plan") {
            return weeklyPlanSteps()
        }
        if lower.contains("morning routine") || lower.contains("start my day") {
            return morningRoutineSteps()
        }
        if lower.contains("research") {
            return researchSteps(topic: goal)
        }

        return [TPlanNode(title: "Process request", action: goal, actionType: .aiQuery)]
    }

    private func weeklyPlanSteps() -> [TPlanNode] {
        let checkCalendar = TPlanNode(title: "Check calendar events", action: "Get calendar events for next 7 days", actionType: .integration)
        let checkReminders = TPlanNode(title: "Check pending reminders", action: "List incomplete reminders", actionType: .integration)
        let analyze = TPlanNode(title: "Analyze schedule patterns", action: "Identify conflicts and gaps", actionType: .aiQuery, dependsOn: [checkCalendar.id, checkReminders.id])
        let generate = TPlanNode(title: "Generate weekly plan", action: "Create optimized plan", actionType: .aiQuery, dependsOn: [analyze.id])
        return [checkCalendar, checkReminders, analyze, generate]
    }

    private func morningRoutineSteps() -> [TPlanNode] {
        let checkCalendar = TPlanNode(title: "Check today's schedule", action: "Get today's events", actionType: .integration)
        let checkReminders = TPlanNode(title: "Check due reminders", action: "List reminders due today", actionType: .integration)
        let briefing = TPlanNode(title: "Generate morning briefing", action: "Create briefing", actionType: .aiQuery, dependsOn: [checkCalendar.id, checkReminders.id])
        return [checkCalendar, checkReminders, briefing]
    }

    private func researchSteps(topic: String) -> [TPlanNode] {
        let search = TPlanNode(title: "Research topic", action: "Research: \(topic)", actionType: .aiQuery)
        let organize = TPlanNode(title: "Organize findings", action: "Organize research", actionType: .aiQuery, dependsOn: [search.id])
        return [search, organize]
    }

    // MARK: - DAG Validation (Kahn's Algorithm)

    func validateDAG(_ plan: TPlan) -> Bool {
        var inDegree: [UUID: Int] = [:]
        var adjacency: [UUID: [UUID]] = [:]

        for node in plan.nodes {
            inDegree[node.id] = node.dependsOn.count
            for dep in node.dependsOn {
                adjacency[dep, default: []].append(node.id)
            }
        }

        var queue = plan.nodes.filter { $0.dependsOn.isEmpty }.map(\.id)
        var visited = 0

        while !queue.isEmpty {
            let current = queue.removeFirst()
            visited += 1
            for neighbor in adjacency[current, default: []] {
                inDegree[neighbor, default: 0] -= 1
                if inDegree[neighbor] == 0 {
                    queue.append(neighbor)
                }
            }
        }

        return visited == plan.nodes.count
    }

    // MARK: - Plan CRUD

    func createPlan(goal: String) throws -> TPlan {
        let steps = decompose(goal: goal)
        let plan = TPlan(goal: goal, nodes: steps)
        guard validateDAG(plan) else {
            throw TPlanError.cyclicDependency
        }
        activePlans.append(plan)
        return plan
    }

    func removePlan(_ planID: UUID) {
        activePlans.removeAll { $0.id == planID }
    }

    func clearCompletedPlans() {
        activePlans.removeAll { $0.status == .completed }
    }

    // MARK: - Execution Simulation

    /// Find nodes that are pending and whose dependencies are all completed
    func findReadyNodes(in plan: TPlan) -> [TPlanNode] {
        let completedIDs = Set(plan.nodes.filter { $0.status == .completed }.map(\.id))
        return plan.nodes.filter { node in
            node.status == .pending && node.dependsOn.allSatisfy { completedIDs.contains($0) }
        }
    }

    func simulateExecution(_ plan: inout TPlan) -> TPlanResult {
        plan.status = .executing
        var results: [UUID: TNodeResult] = [:]

        while true {
            let ready = findReadyNodes(in: plan)
            if ready.isEmpty { break }

            for node in ready {
                if let idx = plan.nodes.firstIndex(where: { $0.id == node.id }) {
                    plan.nodes[idx].status = .completed
                    plan.nodes[idx].result = "Simulated output for: \(node.title)"
                    results[node.id] = TNodeResult(success: true, output: "OK")
                }
            }
        }

        let allSuccess = plan.nodes.allSatisfy { $0.status == .completed }
        plan.status = allSuccess ? .completed : .partiallyCompleted

        return TPlanResult(
            planID: plan.id,
            success: allSuccess,
            completedNodes: plan.nodes.filter { $0.status == .completed }.count,
            totalNodes: plan.nodes.count,
            results: results
        )
    }
}

private enum TPlanError: Error {
    case cyclicDependency
    case planNotFound
}

// MARK: - Tests: Goal Decomposition

@Suite("TaskPlanDAG — Goal Decomposition")
struct TPlanDecompositionTests {
    @Test("Weekly plan goal produces 4 nodes with dependencies")
    func weeklyPlan() {
        let mgr = TestTaskPlanManager()
        let steps = mgr.decompose(goal: "Plan my week")
        #expect(steps.count == 4)
        // First two (calendar + reminders) should have no deps
        #expect(steps[0].dependsOn.isEmpty)
        #expect(steps[1].dependsOn.isEmpty)
        // Third depends on first two
        #expect(steps[2].dependsOn.count == 2)
        #expect(steps[2].dependsOn.contains(steps[0].id))
        #expect(steps[2].dependsOn.contains(steps[1].id))
        // Fourth depends on third
        #expect(steps[3].dependsOn == [steps[2].id])
    }

    @Test("Morning routine goal produces 3 nodes")
    func morningRoutine() {
        let mgr = TestTaskPlanManager()
        let steps = mgr.decompose(goal: "Start my day")
        #expect(steps.count == 3)
        // Briefing depends on both calendar and reminders
        #expect(steps[2].dependsOn.count == 2)
    }

    @Test("Research goal produces 2 sequential nodes")
    func research() {
        let mgr = TestTaskPlanManager()
        let steps = mgr.decompose(goal: "Research quantum computing")
        #expect(steps.count == 2)
        #expect(steps[0].dependsOn.isEmpty)
        #expect(steps[1].dependsOn == [steps[0].id])
    }

    @Test("Unknown goal produces single AI query node")
    func unknownGoal() {
        let mgr = TestTaskPlanManager()
        let steps = mgr.decompose(goal: "Tell me a joke")
        #expect(steps.count == 1)
        #expect(steps[0].actionType == .aiQuery)
        #expect(steps[0].dependsOn.isEmpty)
    }

    @Test("Weekly plan has integration action types for data gathering")
    func actionTypes() {
        let mgr = TestTaskPlanManager()
        let steps = mgr.decompose(goal: "Plan my week ahead")
        #expect(steps[0].actionType == .integration)
        #expect(steps[1].actionType == .integration)
        #expect(steps[2].actionType == .aiQuery)
        #expect(steps[3].actionType == .aiQuery)
    }
}

// MARK: - Tests: DAG Validation (Kahn's Algorithm)

@Suite("TaskPlanDAG — Kahn's Algorithm Validation")
struct TPlanKahnsValidationTests {
    @Test("Valid linear chain passes validation")
    func validLinear() {
        let mgr = TestTaskPlanManager()
        let a = TPlanNode(title: "A", action: "a")
        let b = TPlanNode(title: "B", action: "b", dependsOn: [a.id])
        let c = TPlanNode(title: "C", action: "c", dependsOn: [b.id])
        let plan = TPlan(goal: "Test", nodes: [a, b, c])
        #expect(mgr.validateDAG(plan))
    }

    @Test("Valid diamond DAG passes validation")
    func validDiamond() {
        let mgr = TestTaskPlanManager()
        let a = TPlanNode(title: "A", action: "a")
        let b = TPlanNode(title: "B", action: "b", dependsOn: [a.id])
        let c = TPlanNode(title: "C", action: "c", dependsOn: [a.id])
        let d = TPlanNode(title: "D", action: "d", dependsOn: [b.id, c.id])
        let plan = TPlan(goal: "Diamond", nodes: [a, b, c, d])
        #expect(mgr.validateDAG(plan))
    }

    @Test("All independent nodes pass validation")
    func allIndependent() {
        let mgr = TestTaskPlanManager()
        let plan = TPlan(goal: "Parallel", nodes: [
            TPlanNode(title: "A", action: "a"),
            TPlanNode(title: "B", action: "b"),
            TPlanNode(title: "C", action: "c")
        ])
        #expect(mgr.validateDAG(plan))
    }

    @Test("Empty plan passes validation")
    func emptyPlan() {
        let mgr = TestTaskPlanManager()
        let plan = TPlan(goal: "Empty")
        #expect(mgr.validateDAG(plan))
    }

    @Test("Node depending on nonexistent ID fails validation")
    func missingDep() {
        let mgr = TestTaskPlanManager()
        let node = TPlanNode(title: "A", action: "a", dependsOn: [UUID()])
        let plan = TPlan(goal: "Bad", nodes: [node])
        #expect(!mgr.validateDAG(plan))
    }

    @Test("Decomposed plans always produce valid DAGs")
    func decomposedPlanIsValid() {
        let mgr = TestTaskPlanManager()
        let goals = ["Plan my week", "Start my day", "Research AI", "Random question"]
        for goal in goals {
            let steps = mgr.decompose(goal: goal)
            let plan = TPlan(goal: goal, nodes: steps)
            #expect(mgr.validateDAG(plan), "Decomposed plan for '\(goal)' should be a valid DAG")
        }
    }
}

// MARK: - Tests: Plan CRUD

@Suite("TaskPlanDAG — Plan Management")
struct TPlanCRUDTests {
    @Test("Create plan adds to active plans")
    func createAdds() throws {
        let mgr = TestTaskPlanManager()
        let plan = try mgr.createPlan(goal: "Plan my week")
        #expect(mgr.activePlans.count == 1)
        #expect(mgr.activePlans[0].id == plan.id)
    }

    @Test("Remove plan by ID")
    func removePlan() throws {
        let mgr = TestTaskPlanManager()
        let plan = try mgr.createPlan(goal: "Test")
        #expect(mgr.activePlans.count == 1)
        mgr.removePlan(plan.id)
        #expect(mgr.activePlans.isEmpty)
    }

    @Test("Clear completed plans only removes completed")
    func clearCompleted() throws {
        let mgr = TestTaskPlanManager()
        var plan1 = try mgr.createPlan(goal: "Done task")
        plan1.status = .completed
        mgr.activePlans[0] = plan1

        _ = try mgr.createPlan(goal: "In progress task")
        #expect(mgr.activePlans.count == 2)

        mgr.clearCompletedPlans()
        #expect(mgr.activePlans.count == 1)
        #expect(mgr.activePlans[0].goal == "In progress task")
    }

    @Test("Created plan has ready status")
    func readyStatus() throws {
        let mgr = TestTaskPlanManager()
        let plan = try mgr.createPlan(goal: "Test")
        #expect(plan.status == .ready)
    }

    @Test("Multiple plans can coexist")
    func multiplePlans() throws {
        let mgr = TestTaskPlanManager()
        _ = try mgr.createPlan(goal: "Plan my week")
        _ = try mgr.createPlan(goal: "Start my day")
        _ = try mgr.createPlan(goal: "Research ML")
        #expect(mgr.activePlans.count == 3)
    }
}

// MARK: - Tests: Execution Simulation

@Suite("TaskPlanDAG — Execution Simulation")
struct TPlanExecutionTests {
    @Test("Simple plan executes all nodes to completion")
    func simpleExecution() throws {
        let mgr = TestTaskPlanManager()
        var plan = try mgr.createPlan(goal: "Tell me something")
        let result = mgr.simulateExecution(&plan)
        #expect(result.success)
        #expect(result.completedNodes == result.totalNodes)
        #expect(plan.status == .completed)
    }

    @Test("Weekly plan executes in correct topological order")
    func weeklyPlanOrder() throws {
        let mgr = TestTaskPlanManager()
        var plan = try mgr.createPlan(goal: "Plan my week")
        let result = mgr.simulateExecution(&plan)
        #expect(result.success)
        #expect(result.completedNodes == 4)
        #expect(result.totalNodes == 4)
        for node in plan.nodes {
            #expect(node.status == .completed)
        }
    }

    @Test("Ready node finding respects dependency completion status")
    func readyNodeDependencies() {
        let mgr = TestTaskPlanManager()
        let a = TPlanNode(title: "A", action: "a")
        let b = TPlanNode(title: "B", action: "b")
        let c = TPlanNode(title: "C", action: "c", dependsOn: [a.id, b.id])
        var plan = TPlan(goal: "Test", nodes: [a, b, c])

        // Initially A and B are ready, C is blocked
        let ready1 = mgr.findReadyNodes(in: plan)
        #expect(ready1.count == 2)

        // Mark A as completed
        plan.nodes[0].status = .completed
        let ready2 = mgr.findReadyNodes(in: plan)
        // B is still ready (pending, no deps), C is blocked (B not complete)
        #expect(ready2.count == 1)
        #expect(ready2[0].title == "B")

        // Mark B as completed too
        plan.nodes[1].status = .completed
        let ready3 = mgr.findReadyNodes(in: plan)
        // C's dependencies (A, B) both complete, so C is ready
        #expect(ready3.count == 1)
        #expect(ready3[0].title == "C")
    }

    @Test("Execution produces results for each node")
    func nodeResults() throws {
        let mgr = TestTaskPlanManager()
        var plan = try mgr.createPlan(goal: "Research AI advances")
        let result = mgr.simulateExecution(&plan)
        #expect(result.results.count == plan.nodes.count)
        for nodeResult in result.results.values {
            #expect(nodeResult.success)
        }
    }

    @Test("Node results are stored on nodes after execution")
    func nodeResultsStored() throws {
        let mgr = TestTaskPlanManager()
        var plan = try mgr.createPlan(goal: "Start my day")
        _ = mgr.simulateExecution(&plan)
        for node in plan.nodes {
            #expect(node.result != nil)
            #expect(node.result!.contains("Simulated"))
        }
    }
}

// MARK: - Tests: Edge Cases

@Suite("TaskPlanDAG — Edge Cases")
struct TPlanEdgeCaseTests {
    @Test("Plan with single node executes successfully")
    func singleNode() {
        let mgr = TestTaskPlanManager()
        var plan = TPlan(goal: "Simple", nodes: [TPlanNode(title: "Only", action: "do it")])
        let result = mgr.simulateExecution(&plan)
        #expect(result.success)
        #expect(result.completedNodes == 1)
    }

    @Test("Plan with no nodes produces empty result")
    func noNodes() {
        let mgr = TestTaskPlanManager()
        var plan = TPlan(goal: "Empty")
        let result = mgr.simulateExecution(&plan)
        #expect(result.success)
        #expect(result.completedNodes == 0)
        #expect(result.totalNodes == 0)
    }

    @Test("Case insensitive goal decomposition")
    func caseInsensitive() {
        let mgr = TestTaskPlanManager()
        let upper = mgr.decompose(goal: "PLAN MY WEEK")
        let lower = mgr.decompose(goal: "plan my week")
        #expect(upper.count == lower.count)
    }
}
