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

    /// Show the plan execution panel.
    public func showPanel() {
        isPanelVisible = true
        isPanelCollapsed = false
    }

    /// Hide the plan execution panel.
    public func hidePanel() {
        isPanelVisible = false
    }

    /// Collapse the plan panel to its minimized state.
    public func collapsePanel() {
        isPanelCollapsed = true
    }

    /// Expand the plan panel to its full state.
    public func expandPanel() {
        isPanelCollapsed = false
        isPanelVisible = true
    }

    /// Toggle the plan panel visibility.
    public func togglePanel() {
        if isPanelVisible {
            isPanelVisible = false
        } else {
            showPanel()
        }
    }
}
