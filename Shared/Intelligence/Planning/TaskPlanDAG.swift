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

    // MARK: - G3: Plan Caching & Quality

    /// Cache of successful plans keyed by goal pattern hash → plan outcome
    private var planCache: [Int: CachedPlan] = [:]
    private var planOutcomes: [UUID: PlanOutcome] = [:]
    private let cacheKey = "thea.taskPlanCache"

    private init() {
        loadCache()
    }

    // MARK: - Plan Creation

    /// Create a task plan from a user goal.
    /// G3: checks plan cache first; returns adapted cached plan if quality > 0.8.
    func createPlan(goal: String, context: String = "") async throws -> TaskPlan {
        isPlanning = true
        defer { isPlanning = false }

        logger.info("Creating plan for goal: \(goal)")

        // G3: Check plan cache for similar successful plans
        let hash = hashGoalPattern(goal)
        if let cached = planCache[hash], cached.quality > 0.8 {
            logger.info("TaskPlanDAG: reusing cached plan (quality \(String(format: "%.2f", cached.quality)))")
            var adaptedPlan = cached.plan
            adaptedPlan.id = UUID()
            adaptedPlan.goal = goal
            adaptedPlan.createdAt = Date()
            adaptedPlan.status = .ready
            activePlans.append(adaptedPlan)
            return adaptedPlan
        }

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

    // MARK: - G3: Quality Scoring & Caching

    /// Record the outcome of a plan execution for future quality-based routing.
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func recordPlanOutcome(
        planID: UUID,
        executionTime: TimeInterval,
        successRate: Double,
        confidenceScore: Double
    ) {
        guard let plan = activePlans.first(where: { $0.id == planID }) else { return }
        let outcome = PlanOutcome(
            planID: planID,
            patternHash: hashGoalPattern(plan.goal),
            executionTime: executionTime,
            successRate: successRate,
            confidence: confidenceScore,
            timestamp: Date()
        )
        planOutcomes[planID] = outcome

        // Update cache if this was a high-quality plan
        let quality = (successRate + confidenceScore) / 2.0
        if quality > 0.7 {
            let cached = CachedPlan(plan: plan, quality: quality, lastUsed: Date())
            planCache[outcome.patternHash] = cached
            saveCache()
            logger.info("TaskPlanDAG: cached plan for pattern \(outcome.patternHash) (quality \(String(format: "%.2f", quality)))")
        }
    }

    /// Find a similar cached plan for a given goal.
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func findSimilarPlan(for goal: String) async -> TaskPlan? {
        let hash = hashGoalPattern(goal)
        return planCache[hash]?.plan
    }

    /// Hash a goal string to a stable pattern key (ignores specific nouns, focuses on structure).
    func hashGoalPattern(_ goal: String) -> Int {
        // Normalize: lowercase, strip specific entities, keep structural words
        let structural = goal.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { $0.count > 3 }  // Skip short filler words
            .prefix(6)
            .joined(separator: " ")
        return structural.hashValue
    }

    // MARK: - G3: Cache Persistence

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([Int: CachedPlan].self, from: data) else { return }
        planCache = cached
        logger.info("TaskPlanDAG: loaded \(cached.count) cached plans")
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    private func saveCache() {
        // Keep only top 50 plans by quality
        let sorted = planCache.sorted { $0.value.quality > $1.value.quality }
        let trimmed = sorted.prefix(50).reduce(into: [Int: CachedPlan]()) { $0[$1.key] = $1.value }
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Plan Execution

    // periphery:ignore - Reserved: execute(_:) instance method — reserved for future feature activation
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

    // periphery:ignore - Reserved: executeNode(_:) instance method — reserved for future feature activation
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

    // periphery:ignore - Reserved: executeAIQuery(_:) instance method — reserved for future feature activation
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

    // periphery:ignore - Reserved: executeIntegration(_:) instance method — reserved for future feature activation
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

    // periphery:ignore - Reserved: context parameter — kept for API compatibility
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

    // periphery:ignore - Reserved: removePlan(_:) instance method — reserved for future feature activation
    func removePlan(_ planID: UUID) {
        activePlans.removeAll { $0.id == planID }
    }

    // periphery:ignore - Reserved: clearCompletedPlans() instance method — reserved for future feature activation
    func clearCompletedPlans() {
        activePlans.removeAll { $0.status == .completed }
    // periphery:ignore - Reserved: removePlan(_:) instance method reserved for future feature activation
    }
}

// MARK: - G3: Supporting Types

/// Records the outcome of a plan execution for quality learning.
struct PlanOutcome: Codable, Sendable {
    let planID: UUID
    let patternHash: Int
    let executionTime: TimeInterval
    let successRate: Double
    let confidence: Double
    let timestamp: Date
}

/// A cached successful plan for reuse with similar goals.
struct CachedPlan: Codable, Sendable {
    var plan: TaskPlan
    let quality: Double
    let lastUsed: Date
}

// periphery:ignore - Reserved: clearCompletedPlans() instance method reserved for future feature activation
// MARK: - Types

struct TaskPlan: Identifiable, Codable, Sendable {
    var id: UUID
    var goal: String
    var nodes: [TaskPlanNode]
    var createdAt: Date
    var status: PlanStatus

// periphery:ignore - Reserved: goal property reserved for future feature activation

    // periphery:ignore - Reserved: createdAt property reserved for future feature activation
    enum PlanStatus: String, Codable, Sendable {
        case ready
        case executing
        case completed
        case partiallyCompleted
        case failed
    }
}

struct TaskPlanNode: Identifiable, Codable, Sendable {
    let id: UUID
    // periphery:ignore - Reserved: title property — reserved for future feature activation
    let title: String
    let action: String
    // periphery:ignore - Reserved: title property reserved for future feature activation
    let actionType: ActionType
    let dependsOn: [UUID]
    var status: NodeStatus = .pending
    // periphery:ignore - Reserved: result property — reserved for future feature activation
    var result: String?

// periphery:ignore - Reserved: result property reserved for future feature activation

    init(title: String, action: String, actionType: ActionType, dependsOn: [UUID]) {
        self.id = UUID()
        self.title = title
        self.action = action
        self.actionType = actionType
        self.dependsOn = dependsOn
    }

    enum ActionType: String, Codable, Sendable {
        case aiQuery       // Send to AI provider
        case integration   // Execute via FunctionGemma/integrations
        case compound      // Aggregate results from dependencies
        case userInput     // Wait for user input
    }

    enum NodeStatus: String, Codable, Sendable {
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
