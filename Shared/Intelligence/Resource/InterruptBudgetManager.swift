// InterruptBudgetManager.swift
// Thea — AK3: Interrupt Budget Manager
//
// Enforces PersonalParameters.interruptBudget (default: 4/day).
// Gates all notification dispatch and active interruption paths.
// Emergency priority (> 0.9) always bypasses the gate.
//
// Integrated with SmartNotificationScheduler and HumanReadinessEngine.

import Foundation
import OSLog

// MARK: - InterruptBudgetManager

@MainActor
public final class InterruptBudgetManager: ObservableObject {
    public static let shared = InterruptBudgetManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "InterruptBudgetManager")
    private let params = PersonalParameters.shared

    // MARK: - Published State

    @Published public private(set) var usedToday: Int = 0
    @Published public private(set) var budgetExhausted: Bool = false

    // MARK: - Daily Reset Tracking

    private var lastResetDate = Calendar.current.startOfDay(for: .now)

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// How many interrupts remain in today's budget.
    public var remaining: Int { max(0, params.interruptBudget - usedToday) }

    /// Whether an interrupt is permitted.
    /// - Parameter priority: 0..1 — values > 0.9 are treated as emergency and always permitted.
    /// - Returns: true if the interrupt should be delivered.
    public func canInterrupt(priority: Double = 1.0) -> Bool {
        resetIfNewDay()
        if priority > 0.9 { return true }      // Emergency bypass
        return usedToday < params.interruptBudget
    }

    /// Record that an interrupt was delivered. Updates HumanReadinessEngine.
    public func recordInterrupt() {
        resetIfNewDay()
        usedToday += 1
        budgetExhausted = usedToday >= params.interruptBudget
        HumanReadinessEngine.shared.recordInterrupt()
        let status = budgetExhausted ? "EXHAUSTED" : "OK"
        logger.info("Interrupt recorded: \(self.usedToday)/\(self.params.interruptBudget) today — \(status, privacy: .public)")
    }

    // MARK: - Private

    private func resetIfNewDay() {
        let today = Calendar.current.startOfDay(for: .now)
        guard today > lastResetDate else { return }
        logger.info("New day — resetting interrupt budget (was \(self.usedToday) used)")
        usedToday = 0
        budgetExhausted = false
        lastResetDate = today
    }
}
