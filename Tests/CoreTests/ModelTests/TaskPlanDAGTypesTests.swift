import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Intelligence/Planning/TaskPlanDAG.swift)

private enum TestPlanStatus: String, Sendable, CaseIterable {
    case ready
    case executing
    case completed
    case partiallyCompleted
    case failed

    var isTerminal: Bool {
        switch self {
        case .completed, .partiallyCompleted, .failed: return true
        case .ready, .executing: return false
        }
    }

    var isActive: Bool {
        self == .executing
    }
}

private enum TestActionType: String, Sendable, CaseIterable {
    case aiQuery
    case integration
    case compound
    case userInput

    var requiresAI: Bool {
        self == .aiQuery || self == .compound
    }

    var requiresUserInteraction: Bool {
        self == .userInput
    }
}

private enum TestNodeStatus: String, Sendable, CaseIterable {
    case pending
    case executing
    case completed
    case failed

    var isTerminal: Bool {
        self == .completed || self == .failed
    }
}

private enum TestTaskPlanError: Error, LocalizedError {
    case cyclicDependency
    case planNotFound
    case nodeExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .cyclicDependency: return "Plan contains cyclic dependencies"
        case .planNotFound: return "Plan not found"
        case .nodeExecutionFailed(let msg): return "Node execution failed: \(msg)"
        }
    }
}

private struct TestTaskPlanNode: Identifiable, Sendable {
    let id: UUID
    let title: String
    let action: String
    let actionType: TestActionType
    let dependsOn: [UUID]
    var status: TestNodeStatus = .pending
    var result: String?

    init(title: String, action: String, actionType: TestActionType = .aiQuery, dependsOn: [UUID] = []) {
        self.id = UUID()
        self.title = title
        self.action = action
        self.actionType = actionType
        self.dependsOn = dependsOn
    }
}

private struct TestTaskPlan: Identifiable, Sendable {
    let id: UUID
    let goal: String
    var nodes: [TestTaskPlanNode]
    let createdAt: Date
    var status: TestPlanStatus

    init(goal: String, nodes: [TestTaskPlanNode] = []) {
        self.id = UUID()
        self.goal = goal
        self.nodes = nodes
        self.createdAt = Date()
        self.status = .ready
    }

    var completedNodes: Int { nodes.filter { $0.status == .completed }.count }
    var failedNodes: Int { nodes.filter { $0.status == .failed }.count }
    var progress: Double {
        guard !nodes.isEmpty else { return 0 }
        return Double(completedNodes) / Double(nodes.count)
    }
}

private struct TestTaskNodeResult: Sendable {
    let success: Bool
    let output: String
}

private struct TestTaskPlanResult: Sendable {
    let planID: UUID
    let success: Bool
    let completedNodes: Int
    let totalNodes: Int
    let results: [UUID: TestTaskNodeResult]

    var completionRate: Double {
        guard totalNodes > 0 else { return 0 }
        return Double(completedNodes) / Double(totalNodes)
    }
}

// MARK: - DAG Validation Logic

private func validateDAG(_ plan: TestTaskPlan) -> Bool {
    let nodeIDs = Set(plan.nodes.map(\.id))
    for node in plan.nodes {
        for dep in node.dependsOn {
            if !nodeIDs.contains(dep) { return false }
        }
    }
    // Check for cycles using DFS
    var visited = Set<UUID>()
    var recursionStack = Set<UUID>()

    func hasCycle(from nodeID: UUID) -> Bool {
        visited.insert(nodeID)
        recursionStack.insert(nodeID)

        let node = plan.nodes.first { $0.id == nodeID }!
        for dep in node.dependsOn {
            if !visited.contains(dep) {
                if hasCycle(from: dep) { return true }
            } else if recursionStack.contains(dep) {
                return true
            }
        }
        recursionStack.remove(nodeID)
        return false
    }

    for node in plan.nodes {
        if !visited.contains(node.id) {
            if hasCycle(from: node.id) { return false }
        }
    }
    return true
}

private func topologicalSort(_ plan: TestTaskPlan) -> [TestTaskPlanNode]? {
    var inDegree = [UUID: Int]()
    for node in plan.nodes { inDegree[node.id] = 0 }
    for node in plan.nodes {
        for dep in node.dependsOn {
            inDegree[dep, default: 0] += 0 // dep exists
        }
        // Edges are: dep → node (node depends on dep)
        // So node has inDegree = dependsOn.count
    }
    for node in plan.nodes {
        inDegree[node.id] = node.dependsOn.count
    }

    var queue = plan.nodes.filter { $0.dependsOn.isEmpty }.map(\.id)
    var result: [TestTaskPlanNode] = []
    let nodeMap = Dictionary(uniqueKeysWithValues: plan.nodes.map { ($0.id, $0) })

    while !queue.isEmpty {
        let current = queue.removeFirst()
        result.append(nodeMap[current]!)

        for node in plan.nodes where node.dependsOn.contains(current) {
            inDegree[node.id]! -= 1
            if inDegree[node.id]! == 0 {
                queue.append(node.id)
            }
        }
    }

    return result.count == plan.nodes.count ? result : nil
}

private func findExecutableNodes(_ plan: TestTaskPlan) -> [TestTaskPlanNode] {
    let completedIDs = Set(plan.nodes.filter { $0.status == .completed }.map(\.id))
    return plan.nodes.filter { node in
        node.status == .pending &&
        node.dependsOn.allSatisfy { completedIDs.contains($0) }
    }
}

// MARK: - Tests

@Suite("PlanStatus Enum")
struct PlanStatusTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestPlanStatus.allCases.count == 5)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let rawValues = TestPlanStatus.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Terminal states")
    func terminalStates() {
        #expect(TestPlanStatus.completed.isTerminal)
        #expect(TestPlanStatus.partiallyCompleted.isTerminal)
        #expect(TestPlanStatus.failed.isTerminal)
        #expect(!TestPlanStatus.ready.isTerminal)
        #expect(!TestPlanStatus.executing.isTerminal)
    }

    @Test("Active states")
    func activeStates() {
        #expect(TestPlanStatus.executing.isActive)
        #expect(!TestPlanStatus.ready.isActive)
        #expect(!TestPlanStatus.completed.isActive)
    }
}

@Suite("ActionType Enum")
struct ActionTypeTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestActionType.allCases.count == 4)
    }

    @Test("AI requirement")
    func aiRequirement() {
        #expect(TestActionType.aiQuery.requiresAI)
        #expect(TestActionType.compound.requiresAI)
        #expect(!TestActionType.integration.requiresAI)
        #expect(!TestActionType.userInput.requiresAI)
    }

    @Test("User interaction requirement")
    func userInteraction() {
        #expect(TestActionType.userInput.requiresUserInteraction)
        #expect(!TestActionType.aiQuery.requiresUserInteraction)
    }
}

@Suite("NodeStatus Enum")
struct NodeStatusTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestNodeStatus.allCases.count == 4)
    }

    @Test("Terminal states")
    func terminalStates() {
        #expect(TestNodeStatus.completed.isTerminal)
        #expect(TestNodeStatus.failed.isTerminal)
        #expect(!TestNodeStatus.pending.isTerminal)
        #expect(!TestNodeStatus.executing.isTerminal)
    }
}

@Suite("TaskPlanError")
struct TaskPlanErrorTests {
    @Test("Cyclic dependency description")
    func cyclicDependency() {
        let error = TestTaskPlanError.cyclicDependency
        #expect(error.errorDescription?.contains("cyclic") == true)
    }

    @Test("Plan not found description")
    func planNotFound() {
        let error = TestTaskPlanError.planNotFound
        #expect(error.errorDescription?.contains("not found") == true)
    }

    @Test("Node execution failed includes message")
    func nodeExecutionFailed() {
        let error = TestTaskPlanError.nodeExecutionFailed("timeout")
        #expect(error.errorDescription?.contains("timeout") == true)
    }
}

@Suite("TaskPlanNode")
struct TaskPlanNodeTests {
    @Test("Creation with defaults")
    func creation() {
        let node = TestTaskPlanNode(title: "Research", action: "Search web")
        #expect(node.title == "Research")
        #expect(node.action == "Search web")
        #expect(node.actionType == .aiQuery)
        #expect(node.dependsOn.isEmpty)
        #expect(node.status == .pending)
        #expect(node.result == nil)
    }

    @Test("Identifiable")
    func identifiable() {
        let node1 = TestTaskPlanNode(title: "A", action: "a")
        let node2 = TestTaskPlanNode(title: "B", action: "b")
        #expect(node1.id != node2.id)
    }

    @Test("Dependencies")
    func dependencies() {
        let dep = UUID()
        let node = TestTaskPlanNode(title: "Analysis", action: "Analyze", dependsOn: [dep])
        #expect(node.dependsOn.count == 1)
        #expect(node.dependsOn.first == dep)
    }

    @Test("Custom action type")
    func customActionType() {
        let node = TestTaskPlanNode(title: "Ask user", action: "Prompt", actionType: .userInput)
        #expect(node.actionType == .userInput)
    }
}

@Suite("TaskPlan")
struct TaskPlanTests {
    @Test("Creation with goal")
    func creation() {
        let plan = TestTaskPlan(goal: "Build a website")
        #expect(plan.goal == "Build a website")
        #expect(plan.nodes.isEmpty)
        #expect(plan.status == .ready)
    }

    @Test("Progress calculation - empty")
    func progressEmpty() {
        let plan = TestTaskPlan(goal: "Test")
        #expect(plan.progress == 0)
    }

    @Test("Progress calculation - partial")
    func progressPartial() {
        var plan = TestTaskPlan(goal: "Test", nodes: [
            TestTaskPlanNode(title: "A", action: "a"),
            TestTaskPlanNode(title: "B", action: "b"),
            TestTaskPlanNode(title: "C", action: "c"),
            TestTaskPlanNode(title: "D", action: "d")
        ])
        plan.nodes[0].status = .completed
        plan.nodes[1].status = .completed
        #expect(plan.progress == 0.5)
    }

    @Test("Progress calculation - all completed")
    func progressComplete() {
        var plan = TestTaskPlan(goal: "Test", nodes: [
            TestTaskPlanNode(title: "A", action: "a")
        ])
        plan.nodes[0].status = .completed
        #expect(plan.progress == 1.0)
    }

    @Test("Completed and failed node counts")
    func nodeCounts() {
        var plan = TestTaskPlan(goal: "Test", nodes: [
            TestTaskPlanNode(title: "A", action: "a"),
            TestTaskPlanNode(title: "B", action: "b"),
            TestTaskPlanNode(title: "C", action: "c")
        ])
        plan.nodes[0].status = .completed
        plan.nodes[2].status = .failed
        #expect(plan.completedNodes == 1)
        #expect(plan.failedNodes == 1)
    }
}

@Suite("TaskPlanResult")
struct TaskPlanResultTests {
    @Test("Completion rate")
    func completionRate() {
        let result = TestTaskPlanResult(
            planID: UUID(),
            success: true,
            completedNodes: 3,
            totalNodes: 4,
            results: [:]
        )
        #expect(result.completionRate == 0.75)
    }

    @Test("Completion rate - zero total")
    func completionRateZero() {
        let result = TestTaskPlanResult(
            planID: UUID(),
            success: false,
            completedNodes: 0,
            totalNodes: 0,
            results: [:]
        )
        #expect(result.completionRate == 0)
    }

    @Test("Full success")
    func fullSuccess() {
        let result = TestTaskPlanResult(
            planID: UUID(),
            success: true,
            completedNodes: 5,
            totalNodes: 5,
            results: [:]
        )
        #expect(result.success)
        #expect(result.completionRate == 1.0)
    }
}

@Suite("DAG Validation")
struct DAGValidationTests {
    @Test("Valid linear DAG")
    func validLinear() {
        let node1 = TestTaskPlanNode(title: "First", action: "a")
        let node2 = TestTaskPlanNode(title: "Second", action: "b", dependsOn: [node1.id])
        let node3 = TestTaskPlanNode(title: "Third", action: "c", dependsOn: [node2.id])
        let plan = TestTaskPlan(goal: "Linear", nodes: [node1, node2, node3])
        #expect(validateDAG(plan))
    }

    @Test("Valid DAG with no dependencies")
    func validNoDeps() {
        let plan = TestTaskPlan(goal: "Parallel", nodes: [
            TestTaskPlanNode(title: "A", action: "a"),
            TestTaskPlanNode(title: "B", action: "b"),
            TestTaskPlanNode(title: "C", action: "c")
        ])
        #expect(validateDAG(plan))
    }

    @Test("Invalid DAG with missing dependency")
    func invalidMissingDep() {
        let fakeID = UUID()
        let node = TestTaskPlanNode(title: "A", action: "a", dependsOn: [fakeID])
        let plan = TestTaskPlan(goal: "Bad", nodes: [node])
        #expect(!validateDAG(plan))
    }

    @Test("Empty plan is valid")
    func emptyPlan() {
        let plan = TestTaskPlan(goal: "Empty")
        #expect(validateDAG(plan))
    }

    @Test("Diamond DAG is valid")
    func diamondDAG() {
        let a = TestTaskPlanNode(title: "A", action: "a")
        let b = TestTaskPlanNode(title: "B", action: "b", dependsOn: [a.id])
        let c = TestTaskPlanNode(title: "C", action: "c", dependsOn: [a.id])
        let d = TestTaskPlanNode(title: "D", action: "d", dependsOn: [b.id, c.id])
        let plan = TestTaskPlan(goal: "Diamond", nodes: [a, b, c, d])
        #expect(validateDAG(plan))
    }
}

@Suite("Topological Sort")
struct TopologicalSortTests {
    @Test("Linear chain sorts correctly")
    func linearChain() {
        let a = TestTaskPlanNode(title: "A", action: "a")
        let b = TestTaskPlanNode(title: "B", action: "b", dependsOn: [a.id])
        let c = TestTaskPlanNode(title: "C", action: "c", dependsOn: [b.id])
        let plan = TestTaskPlan(goal: "Linear", nodes: [c, a, b]) // Shuffled
        let sorted = topologicalSort(plan)
        #expect(sorted != nil)
        #expect(sorted!.count == 3)
        #expect(sorted![0].id == a.id)
        #expect(sorted![1].id == b.id)
        #expect(sorted![2].id == c.id)
    }

    @Test("Independent nodes all appear")
    func independentNodes() {
        let plan = TestTaskPlan(goal: "Parallel", nodes: [
            TestTaskPlanNode(title: "A", action: "a"),
            TestTaskPlanNode(title: "B", action: "b")
        ])
        let sorted = topologicalSort(plan)
        #expect(sorted != nil)
        #expect(sorted!.count == 2)
    }

    @Test("Empty plan")
    func emptyPlan() {
        let plan = TestTaskPlan(goal: "Empty")
        let sorted = topologicalSort(plan)
        #expect(sorted != nil)
        #expect(sorted!.isEmpty)
    }
}

@Suite("Executable Node Finding")
struct ExecutableNodeTests {
    @Test("All independent nodes are executable")
    func allIndependent() {
        let plan = TestTaskPlan(goal: "Test", nodes: [
            TestTaskPlanNode(title: "A", action: "a"),
            TestTaskPlanNode(title: "B", action: "b"),
            TestTaskPlanNode(title: "C", action: "c")
        ])
        let executable = findExecutableNodes(plan)
        #expect(executable.count == 3)
    }

    @Test("Dependent node not executable until deps complete")
    func dependentNotReady() {
        let a = TestTaskPlanNode(title: "A", action: "a")
        let b = TestTaskPlanNode(title: "B", action: "b", dependsOn: [a.id])
        let plan = TestTaskPlan(goal: "Test", nodes: [a, b])
        let executable = findExecutableNodes(plan)
        #expect(executable.count == 1)
        #expect(executable[0].id == a.id)
    }

    @Test("Dependent node executable after deps complete")
    func dependentReady() {
        var a = TestTaskPlanNode(title: "A", action: "a")
        a.status = .completed
        let b = TestTaskPlanNode(title: "B", action: "b", dependsOn: [a.id])
        let plan = TestTaskPlan(goal: "Test", nodes: [a, b])
        let executable = findExecutableNodes(plan)
        #expect(executable.count == 1)
        #expect(executable[0].id == b.id)
    }

    @Test("Already executing nodes not returned")
    func executingExcluded() {
        var a = TestTaskPlanNode(title: "A", action: "a")
        a.status = .executing
        let plan = TestTaskPlan(goal: "Test", nodes: [a])
        let executable = findExecutableNodes(plan)
        #expect(executable.isEmpty)
    }

    @Test("Multiple dependencies all must be complete")
    func multiDepsRequired() {
        var a = TestTaskPlanNode(title: "A", action: "a")
        a.status = .completed
        let b = TestTaskPlanNode(title: "B", action: "b")
        let c = TestTaskPlanNode(title: "C", action: "c", dependsOn: [a.id, b.id])
        let plan = TestTaskPlan(goal: "Test", nodes: [a, b, c])
        let executable = findExecutableNodes(plan)
        // B is executable (no deps, pending), C is not (B not complete)
        #expect(executable.count == 1)
        #expect(executable[0].id == b.id)
    }
}
