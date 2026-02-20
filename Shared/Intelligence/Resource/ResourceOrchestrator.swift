// ResourceOrchestrator.swift
// Thea — AK3: Resource Orchestrator
//
// 4-state machine (degraded / normal / elevated / flowProtected) driven by:
// - HumanReadinessEngine.readinessScore
// - DataFreshnessOrchestrator.stalenessScore()
// - InterruptBudgetManager.remaining
//
// Publishes recommendedWorkBlockMinutes (scales with PersonalParameters.workBlockMinutes).
// EnergyAdaptiveThrottler reads currentState to scale polling intervals (AM3).

import Combine
import Foundation
import OSLog

// MARK: - ResourceOrchestrator

@MainActor
public final class ResourceOrchestrator: ObservableObject {
    public static let shared = ResourceOrchestrator()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ResourceOrchestrator")
    private let params = PersonalParameters.shared

    // MARK: - Published State

    @Published public private(set) var currentState: ResourceState = .normal
    @Published public private(set) var recommendedWorkBlockMinutes: Double = 75
    @Published public private(set) var stateReason: String = "Initializing"

    // MARK: - Types

    public enum ResourceState: String, Sendable, CaseIterable {
        case degraded      // Low readiness — back off, conserve cognitive resources
        case normal        // Standard operation
        case elevated      // High readiness — can handle more throughput
        case flowProtected // In flow state — protect from all non-critical interrupts
    }

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    private var evaluationTimer: Timer?

    // MARK: - Init

    private init() {
        // Re-evaluate state every 60 seconds
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateState() }
        }
        // Also react immediately when readiness changes
        HumanReadinessEngine.shared.$readinessScore
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.evaluateState() }
            .store(in: &cancellables)

        evaluateState()
    }

    // MARK: - State Evaluation

    public func evaluateState() {
        let readiness = HumanReadinessEngine.shared.readinessScore
        let phase = HumanReadinessEngine.shared.ultradianPhase
        let budgetRemaining = InterruptBudgetManager.shared.remaining

        let newState: ResourceState
        let reason: String

        switch readiness {
        case params.stateHighThreshold...:
            if phase == .peak {
                newState = .flowProtected
                reason = "Flow state — readiness \(Int(readiness * 100))% + ultradian peak"
            } else {
                newState = .elevated
                reason = "High readiness \(Int(readiness * 100))%"
            }

        case params.stateActiveThreshold...:
            newState = .normal
            reason = "Normal readiness \(Int(readiness * 100))%"

        default:
            if budgetRemaining == 0 {
                newState = .degraded
                reason = "Low readiness \(Int(readiness * 100))% + interrupt budget exhausted"
            } else {
                newState = .degraded
                reason = "Low readiness \(Int(readiness * 100))%"
            }
        }

        if newState != currentState {
            logger.info("State \(self.currentState.rawValue) → \(newState.rawValue): \(reason)")
            currentState = newState
            stateReason = reason
        }

        // Scale recommended work block based on state
        recommendedWorkBlockMinutes = switch currentState {
        case .degraded:      params.workBlockMinutes * 0.5   // Shorter blocks when tired
        case .normal:        params.workBlockMinutes
        case .elevated:      params.workBlockMinutes * 1.2   // Slightly longer when fresh
        case .flowProtected: params.workBlockMinutes * 1.5   // Extended block in flow
        }
    }

    // MARK: - EnergyAdaptiveThrottler Integration

    /// Polling interval multiplier for EnergyAdaptiveThrottler.
    /// Higher = slower polling (conserve resources when degraded or in flow).
    public var throttleMultiplier: Double {
        switch currentState {
        case .degraded:      return 3.0   // User tired — back off significantly
        case .normal:        return 1.0   // Standard cadence
        case .elevated:      return 0.8   // Slight speedup
        case .flowProtected: return 2.0   // Protect flow — reduce background polling
        }
    }
}
