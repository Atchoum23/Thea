// TaskPlanDAG.swift
// Thea — DAG-Based Task Planner
//
// Decomposes complex user goals into a directed acyclic graph of subtasks.
// Supports parallel execution of independent nodes via TaskGroup.
// Integrates with FunctionGemma and AnthropicToolCatalog for action execution.

import Foundation
import OSLog

// MARK: - Task Plan DAG

@MainActor
@Observable
final class TaskPlanDAG {
    static let shared = TaskPlanDAG()

    private let logger = Logger(subsystem: "com.thea.app", category: "TaskPlanDAG")

    // MARK: - State

    private(set) var activePlans: [TaskPlan] = []
    private(set) var isPlanning = false

    private init() {}

    // MARK: - Plan Creation

    /// Create a task plan from a user goal
    func createPlan(goal: String, context: String = "") async throws -> TaskPlan {
        isPlanning = true
        defer { isPlanning = false }

        logger.info("Creating plan for goal: \(goal)")

        // Decompose the goal into steps
        let steps = decompose(goal: goal, context: context)

        // Build the DAG
        let plan = TaskPlan(
            id: UUID(),
            goal: goal,
            nodes: steps,
            createdAt: Date(),
            status: .ready
        )

        // Validate DAG (no cycles)
        guard validateDAG(plan) else {
            throw TaskPlanError.cyclicDependency
        }

        activePlans.append(plan)
        return plan
    }

    // MARK: - Plan Execution

    /// Execute a plan, running parallelizable nodes concurrently
    func execute(_ plan: TaskPlan) async throws -> TaskPlanResult {
        guard let index = activePlans.firstIndex(where: { $0.id == plan.id }) else {
            throw TaskPlanError.planNotFound
        }

        activePlans[index].status = .executing
        var results: [UUID: TaskNodeResult] = [:]

        // Execute in topological order, parallelizing when possible
        while true {
            let readyNodes = activePlans[index].nodes.filter { node in
                // periphery:ignore - Reserved: execute(_:) instance method reserved for future feature activation
                node.status == .pending &&
                    node.dependsOn.allSatisfy { depID in
                        results[depID]?.success == true
                    }
            }

            if readyNodes.isEmpty {
                // Check if all done or blocked
                let allDone = activePlans[index].nodes.allSatisfy { $0.status != .pending }
                if allDone { break }

                // Check for blocked nodes (dependencies failed)
                let hasBlockedNodes = activePlans[index].nodes.contains { node in
                    node.status == .pending &&
                        node.dependsOn.contains { depID in results[depID]?.success == false }
                }
                if hasBlockedNodes {
                    // Mark blocked nodes as failed
                    for i in activePlans[index].nodes.indices {
                        if activePlans[index].nodes[i].status == .pending {
                            activePlans[index].nodes[i].status = .failed
                        }
                    }
                    break
                }

                break
            }

            // Execute ready nodes in parallel
            await withTaskGroup(of: (UUID, TaskNodeResult).self) { group in
                for node in readyNodes {
                    // Mark as executing
                    if let nodeIdx = activePlans[index].nodes.firstIndex(where: { $0.id == node.id }) {
                        activePlans[index].nodes[nodeIdx].status = .executing
                    }

                    group.addTask { @Sendable [node] in
                        let result = await self.executeNode(node)
                        return (node.id, result)
                    }
                }

                for await (nodeID, result) in group {
                    results[nodeID] = result
                    if let nodeIdx = activePlans[index].nodes.firstIndex(where: { $0.id == nodeID }) {
                        activePlans[index].nodes[nodeIdx].status = result.success ? .completed : .failed
                        activePlans[index].nodes[nodeIdx].result = result.output
                    }
                }
            }
        }

        let allSuccess = activePlans[index].nodes.allSatisfy { $0.status == .completed }
        activePlans[index].status = allSuccess ? .completed : .partiallyCompleted

        return TaskPlanResult(
            planID: plan.id,
            success: allSuccess,
            completedNodes: activePlans[index].nodes.filter { $0.status == .completed }.count,
            totalNodes: activePlans[index].nodes.count,
            results: results
        )
    }

    // MARK: - Node Execution

    nonisolated private func executeNode(_ node: TaskPlanNode) async -> TaskNodeResult {
        do {
            // Route to the appropriate executor based on node type
            switch node.actionType {
            case .aiQuery:
                let result = try await executeAIQuery(node)
                return TaskNodeResult(success: true, output: result)

            case .integration:
                let result = try await executeIntegration(node)
                // periphery:ignore - Reserved: executeNode(_:) instance method reserved for future feature activation
                return TaskNodeResult(success: true, output: result)

            case .compound:
                return TaskNodeResult(success: true, output: "Compound node completed")

            case .userInput:
                return TaskNodeResult(success: true, output: "Awaiting user input")
            }
        } catch {
            return TaskNodeResult(success: false, output: "Error: \(error.localizedDescription)")
        }
    }

    nonisolated private func executeAIQuery(_ node: TaskPlanNode) async throws -> String {
        guard let provider = await ProviderRegistry.shared.getDefaultProvider() else {
            return "No AI provider available"
        }

        let models = try await provider.listModels()
        guard let modelID = models.first?.id else {
            return "No model available"
        }

// periphery:ignore - Reserved: executeAIQuery(_:) instance method reserved for future feature activation

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(node.action),
            timestamp: Date(),
            model: modelID
        )

        let stream = try await provider.chat(messages: [message], model: modelID, stream: false)
        var result = ""
        for try await response in stream {
            switch response.type {
            case let .delta(text): result += text
            case let .complete(msg): result = msg.content.textValue
            case .error: break
            }
        }

        return result
    }

    nonisolated private func executeIntegration(_ node: TaskPlanNode) async throws -> String {
        #if os(macOS)
        let bridge = await FunctionGemmaBridge.shared
        let result = try await bridge.processInstruction(node.action)
        return result.message
        #else
        return "Integration actions not available on this platform"
        #endif
    // periphery:ignore - Reserved: executeIntegration(_:) instance method reserved for future feature activation
    }

    // MARK: - Goal Decomposition

    private func decompose(goal: String, context: String) -> [TaskPlanNode] {
        let lower = goal.lowercased()

        // Pattern-based decomposition for common goals
        if lower.contains("plan my week") || lower.contains("weekly plan") {
            return weeklyPlanSteps()
        }

// periphery:ignore - Reserved: context parameter kept for API compatibility

        if lower.contains("morning routine") || lower.contains("start my day") {
            return morningRoutineSteps()
        }

        if lower.contains("research") {
            return researchSteps(topic: goal)
        }

        // Default: single AI query node
        return [
            TaskPlanNode(
                title: "Process request",
                action: goal,
                actionType: .aiQuery,
                dependsOn: []
            )
        ]
    }

    private func weeklyPlanSteps() -> [TaskPlanNode] {
        let checkCalendar = TaskPlanNode(
            title: "Check calendar events",
            action: "Get all calendar events for the next 7 days",
            actionType: .integration,
            dependsOn: []
        )

        let checkReminders = TaskPlanNode(
            title: "Check pending reminders",
            action: "List all incomplete reminders",
            actionType: .integration,
            dependsOn: []
        )

        let analyzePatterns = TaskPlanNode(
            title: "Analyze schedule patterns",
            action: "Based on the calendar events and reminders, identify scheduling conflicts, gaps, and optimization opportunities for the week ahead.",
            actionType: .aiQuery,
            dependsOn: [checkCalendar.id, checkReminders.id]
        )

        let generatePlan = TaskPlanNode(
            title: "Generate weekly plan",
            action: "Create an optimized weekly plan with specific time blocks for deep work, meetings, personal time, and pending tasks.",
            actionType: .aiQuery,
            dependsOn: [analyzePatterns.id]
        )

        return [checkCalendar, checkReminders, analyzePatterns, generatePlan]
    }

    private func morningRoutineSteps() -> [TaskPlanNode] {
        let checkCalendar = TaskPlanNode(
            title: "Check today's schedule",
            action: "Get today's calendar events",
            actionType: .integration,
            dependsOn: []
        )

        let checkReminders = TaskPlanNode(
            title: "Check due reminders",
            action: "List reminders due today",
            actionType: .integration,
            dependsOn: []
        )

        let briefing = TaskPlanNode(
            title: "Generate morning briefing",
            action: "Create a concise morning briefing summarizing today's schedule, priorities, and any preparation needed.",
            actionType: .aiQuery,
            dependsOn: [checkCalendar.id, checkReminders.id]
        )

        return [checkCalendar, checkReminders, briefing]
    }

    private func researchSteps(topic: String) -> [TaskPlanNode] {
        let search = TaskPlanNode(
            title: "Research topic",
            action: "Research and summarize: \(topic)",
            actionType: .aiQuery,
            dependsOn: []
        )

        let organize = TaskPlanNode(
            title: "Organize findings",
            action: "Organize the research findings into key takeaways, action items, and follow-up questions.",
            actionType: .aiQuery,
            dependsOn: [search.id]
        )

        return [search, organize]
    }

    // MARK: - DAG Validation

    private func validateDAG(_ plan: TaskPlan) -> Bool {
        // Topological sort using Kahn's algorithm
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

    // MARK: - Cleanup

    func removePlan(_ planID: UUID) {
        activePlans.removeAll { $0.id == planID }
    }

    func clearCompletedPlans() {
        activePlans.removeAll { $0.status == .completed }
    // periphery:ignore - Reserved: removePlan(_:) instance method reserved for future feature activation
    }
}

// periphery:ignore - Reserved: clearCompletedPlans() instance method reserved for future feature activation
// MARK: - Types

struct TaskPlan: Identifiable, Sendable {
    let id: UUID
    let goal: String
    var nodes: [TaskPlanNode]
    let createdAt: Date
    var status: PlanStatus

// periphery:ignore - Reserved: goal property reserved for future feature activation

    // periphery:ignore - Reserved: createdAt property reserved for future feature activation
    enum PlanStatus: String, Sendable {
        case ready
        case executing
        case completed
        case partiallyCompleted
        case failed
    }
}

struct TaskPlanNode: Identifiable, Sendable {
    let id: UUID
    let title: String
    let action: String
    // periphery:ignore - Reserved: title property reserved for future feature activation
    let actionType: ActionType
    let dependsOn: [UUID]
    var status: NodeStatus = .pending
    var result: String?

// periphery:ignore - Reserved: result property reserved for future feature activation

    init(title: String, action: String, actionType: ActionType, dependsOn: [UUID]) {
        self.id = UUID()
        self.title = title
        self.action = action
        self.actionType = actionType
        self.dependsOn = dependsOn
    }

    enum ActionType: String, Sendable {
        case aiQuery       // Send to AI provider
        case integration   // Execute via FunctionGemma/integrations
        case compound      // Aggregate results from dependencies
        case userInput     // Wait for user input
    }

    enum NodeStatus: String, Sendable {
        case pending
        case executing
        case completed
        case failed
    }
}

struct TaskNodeResult: Sendable {
    let success: Bool
    let output: String
}

// periphery:ignore - Reserved: TaskPlanResult type reserved for future feature activation
struct TaskPlanResult: Sendable {
    let planID: UUID
    let success: Bool
    let completedNodes: Int
    let totalNodes: Int
    let results: [UUID: TaskNodeResult]
}

enum TaskPlanError: Error, LocalizedError {
    case cyclicDependency
    case planNotFound
    case nodeExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .cyclicDependency:
            "Task plan contains cyclic dependencies"
        case .planNotFound:
            "Task plan not found"
        case let .nodeExecutionFailed(reason):
            "Node execution failed: \(reason)"
        }
    }
}
