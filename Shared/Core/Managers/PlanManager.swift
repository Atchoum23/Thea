// PlanManager.swift
// Thea
//
// Manages Plan Mode lifecycle — creating plans from QueryDecomposition,
// tracking step execution, handling mid-session modifications,
// and controlling the plan panel visibility.

import Foundation
import os.log

@MainActor
@Observable
public final class PlanManager {
    public static let shared = PlanManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "PlanManager")

    // MARK: - State

    public private(set) var activePlan: PlanState?
    public private(set) var planHistory: [PlanState] = []
    public var isPanelVisible: Bool = false
    public var isPanelCollapsed: Bool = false

    private init() {
        logger.info("PlanManager initialized")
    }

    // MARK: - Plan Lifecycle

    #if os(macOS)
    /// Create a plan from a QueryDecomposition result (macOS only - requires MetaAI)
    public func createPlan(
        from decomposition: QueryDecomposition,
        title: String,
        conversationId: UUID?
    ) -> PlanState {
        let phases = buildPhases(
            from: decomposition.subQueries,
            strategy: decomposition.executionPlan
        )

        let plan = PlanState(
            title: title,
            phases: phases,
            status: .creating,
            conversationId: conversationId,
            originalQuery: decomposition.originalQuery
        )

        activePlan = plan
        logger.info("Created plan '\(title)' with \(plan.totalSteps) steps across \(phases.count) phases")
        return plan
    }

    /// Convert SubQuery array into PlanPhases by analyzing dependencies
    private func buildPhases(
        from subQueries: [SubQuery],
        strategy: SubQueryExecutionStrategy
    ) -> [PlanPhase] {
        guard !subQueries.isEmpty else { return [] }

        switch strategy {
        case .sequential:
            // Each sub-query is its own phase, executed in order
            return subQueries.enumerated().map { index, subQuery in
                PlanPhase(
                    title: "Step \(index + 1)",
                    steps: [stepFrom(subQuery)]
                )
            }

        case .parallel:
            // All sub-queries in a single phase (executed concurrently)
            let steps = subQueries.map { stepFrom($0) }
            return [PlanPhase(title: "Parallel Execution", steps: steps)]

        case .mixed:
            // Group by dependency level using topological ordering
            return buildDependencyPhases(from: subQueries)
        }
    }

    /// Build phases from dependency graph — queries at the same depth are in the same phase
    private func buildDependencyPhases(from subQueries: [SubQuery]) -> [PlanPhase] {
        var depthMap: [UUID: Int] = [:]
        var resolved = Set<UUID>()

        // Assign depth levels based on dependencies
        func assignDepth(_ query: SubQuery) -> Int {
            if let cached = depthMap[query.id] { return cached }

            if query.dependencies.isEmpty {
                depthMap[query.id] = 0
                return 0
            }

            let maxDepDep = query.dependencies.compactMap { depId -> Int? in
                guard let dep = subQueries.first(where: { $0.id == depId }) else { return nil }
                return assignDepth(dep)
            }.max() ?? 0

            let depth = maxDepDep + 1
            depthMap[query.id] = depth
            return depth
        }

        for query in subQueries {
            _ = assignDepth(query)
            resolved.insert(query.id)
        }

        // Group by depth
        let maxDepth = depthMap.values.max() ?? 0
        var phases: [PlanPhase] = []

        for depth in 0 ... maxDepth {
            let queriesAtDepth = subQueries.filter { depthMap[$0.id] == depth }
            guard !queriesAtDepth.isEmpty else { continue }

            let steps = queriesAtDepth.map { stepFrom($0) }
            let phaseTitle = depth == 0 ? "Foundation" : "Phase \(depth + 1)"
            phases.append(PlanPhase(title: phaseTitle, steps: steps))
        }

        return phases
    }

    /// Convert a SubQuery into a PlanStep
    private func stepFrom(_ subQuery: SubQuery) -> PlanStep {
        let queryStr = String(subQuery.query.prefix(80))
        let trimmed = queryStr.trimmingCharacters(in: .whitespacesAndNewlines)
        return PlanStep(
            title: trimmed + (subQuery.query.count > 80 ? "..." : ""),
            activeDescription: activeDescriptionFor(subQuery),
            subQueryId: subQuery.id,
            taskType: subQuery.taskType.rawValue
        )
    }

    /// Generate present-tense description from a sub-query
    private func activeDescriptionFor(_ subQuery: SubQuery) -> String {
        let query = subQuery.query.lowercased()
        let prefix60 = String(subQuery.query.prefix(60)).lowercased()

        if query.hasPrefix("design") || query.hasPrefix("create") || query.hasPrefix("build") {
            return "Building \(prefix60)..."
        } else if query.hasPrefix("implement") || query.hasPrefix("write") || query.hasPrefix("add") {
            return "Implementing \(prefix60)..."
        } else if query.hasPrefix("test") || query.hasPrefix("verify") || query.hasPrefix("validate") {
            return "Testing \(prefix60)..."
        } else if query.hasPrefix("analyze") || query.hasPrefix("review") || query.hasPrefix("evaluate") {
            return "Analyzing \(prefix60)..."
        } else if query.hasPrefix("document") || query.hasPrefix("explain") {
            return "Documenting \(prefix60)..."
        } else {
            return "Working on \(prefix60)..."
        }
    }
    #endif

    // MARK: - Platform-Independent Plan Creation

    /// Create a plan from simple step descriptions (works on all platforms)
    public func createSimplePlan(
        title: String,
        steps: [String],
        conversationId: UUID? = nil
    ) -> PlanState {
        let planSteps = steps.enumerated().map { index, step in
            PlanStep(
                title: step,
                activeDescription: "Working on step \(index + 1)...",
                subQueryId: nil,
                taskType: "general"
            )
        }

        let phase = PlanPhase(title: "Steps", steps: planSteps)
        let plan = PlanState(
            title: title,
            phases: [phase],
            status: .creating,
            conversationId: conversationId,
            originalQuery: title
        )

        activePlan = plan
        logger.info("Created simple plan '\(title)' with \(steps.count) steps")
        return plan
    }

    // MARK: - Execution Tracking

    /// Mark the plan as actively executing
    public func startExecution() {
        guard activePlan != nil else { return }
        activePlan?.status = .executing
        activePlan?.updatedAt = Date()
        logger.info("Plan execution started")
    }

    /// Mark a step as started
    public func stepStarted(_ stepId: UUID, modelUsed: String?) {
        guard var plan = activePlan else { return }

        for phaseIdx in plan.phases.indices {
            if let stepIdx = plan.phases[phaseIdx].steps.firstIndex(where: { $0.id == stepId }) {
                plan.phases[phaseIdx].steps[stepIdx].status = .inProgress
                plan.phases[phaseIdx].steps[stepIdx].startedAt = Date()
                plan.phases[phaseIdx].steps[stepIdx].modelUsed = modelUsed
                break
            }
        }

        plan.updatedAt = Date()
        activePlan = plan
        logger.debug("Step started: \(stepId)")
    }

    /// Mark a step as completed
    public func stepCompleted(_ stepId: UUID, result: String?) {
        guard var plan = activePlan else { return }

        for phaseIdx in plan.phases.indices {
            if let stepIdx = plan.phases[phaseIdx].steps.firstIndex(where: { $0.id == stepId }) {
                plan.phases[phaseIdx].steps[stepIdx].status = .completed
                plan.phases[phaseIdx].steps[stepIdx].completedAt = Date()
                plan.phases[phaseIdx].steps[stepIdx].result = result
                break
            }
        }

        plan.updatedAt = Date()

        // Check if all steps are done
        let allSteps = plan.phases.flatMap(\.steps)
        if allSteps.allSatisfy({ $0.status == .completed || $0.status == .skipped }) {
            plan.status = .completed
            logger.info("Plan completed: all \(allSteps.count) steps done")
        }

        activePlan = plan
    }

    /// Mark a step as failed
    public func stepFailed(_ stepId: UUID, error: String) {
        guard var plan = activePlan else { return }

        for phaseIdx in plan.phases.indices {
            if let stepIdx = plan.phases[phaseIdx].steps.firstIndex(where: { $0.id == stepId }) {
                plan.phases[phaseIdx].steps[stepIdx].status = .failed
                plan.phases[phaseIdx].steps[stepIdx].completedAt = Date()
                plan.phases[phaseIdx].steps[stepIdx].error = error
                break
            }
        }

        plan.updatedAt = Date()
        activePlan = plan
        logger.warning("Step failed: \(stepId) — \(error)")
    }

    /// Cancel the active plan
    public func cancelPlan() {
        guard var plan = activePlan else { return }
        plan.status = .cancelled
        plan.updatedAt = Date()
        activePlan = plan

        planHistory.append(plan)
        logger.info("Plan cancelled")
    }

    /// Archive the current plan and clear active state
    public func archivePlan() {
        guard let plan = activePlan else { return }
        planHistory.append(plan)
        activePlan = nil
        logger.info("Plan archived")
    }

    // MARK: - Mid-Session Modification

    /// Apply a modification to the active plan
    public func applyModification(_ modification: PlanModification) {
        guard var plan = activePlan else { return }

        plan.status = .modifying

        switch modification.type {
        case let .insertSteps(newSteps, afterStepId):
            insertSteps(newSteps, after: afterStepId, in: &plan)

        case let .removeSteps(stepIds):
            for phaseIdx in plan.phases.indices {
                plan.phases[phaseIdx].steps.removeAll { stepIds.contains($0.id) }
            }
            // Remove empty phases
            plan.phases.removeAll { $0.steps.isEmpty }

        case let .updateStep(stepId, newTitle, newDescription):
            for phaseIdx in plan.phases.indices {
                if let stepIdx = plan.phases[phaseIdx].steps.firstIndex(where: { $0.id == stepId }) {
                    if let title = newTitle {
                        plan.phases[phaseIdx].steps[stepIdx].title = title
                    }
                    if let desc = newDescription {
                        plan.phases[phaseIdx].steps[stepIdx].activeDescription = desc
                    }
                    plan.phases[phaseIdx].steps[stepIdx].status = .modified
                    break
                }
            }

        case let .reorderPhases(newOrder):
            let phaseMap = Dictionary(uniqueKeysWithValues: plan.phases.map { ($0.id, $0) })
            plan.phases = newOrder.compactMap { phaseMap[$0] }

        case let .addPhase(phase, atIndex):
            let safeIndex = min(atIndex, plan.phases.count)
            plan.phases.insert(phase, at: safeIndex)
        }

        plan.status = .executing
        plan.updatedAt = Date()
        activePlan = plan
        logger.info("Plan modified: \(modification.reason)")
    }

    private func insertSteps(_ steps: [PlanStep], after afterStepId: UUID?, in plan: inout PlanState) {
        if let afterId = afterStepId {
            // Find the phase and index, insert after it
            for phaseIdx in plan.phases.indices {
                if let stepIdx = plan.phases[phaseIdx].steps.firstIndex(where: { $0.id == afterId }) {
                    plan.phases[phaseIdx].steps.insert(contentsOf: steps, at: stepIdx + 1)
                    return
                }
            }
        }

        // If no afterStepId or not found, append to last phase
        if !plan.phases.isEmpty {
            plan.phases[plan.phases.count - 1].steps.append(contentsOf: steps)
        }
    }

    // MARK: - Panel Control

    public func showPanel() {
        isPanelVisible = true
        isPanelCollapsed = false
    }

    public func hidePanel() {
        isPanelVisible = false
    }

    public func collapsePanel() {
        isPanelCollapsed = true
    }

    public func expandPanel() {
        isPanelCollapsed = false
        isPanelVisible = true
    }

    public func togglePanel() {
        if isPanelVisible {
            isPanelVisible = false
        } else {
            showPanel()
        }
    }
}
