// AgentSecKillSwitch.swift
// Emergency stop mechanism for AgentSec Strict Mode
// Halts all agent operations on critical violations

import Foundation
import OSLog

// MARK: - AgentSec Kill Switch

/// Emergency kill switch that halts all agent operations
/// Triggered automatically on critical security violations
@MainActor
public final class AgentSecKillSwitch: ObservableObject {
    public static let shared = AgentSecKillSwitch()

    private let logger = Logger(subsystem: "com.thea.app", category: "AgentSecKillSwitch")

    // MARK: - Published State

    @Published public private(set) var isTriggered: Bool = false
    @Published public private(set) var triggerReason: String?
    @Published public private(set) var triggerTimestamp: Date?
    @Published public private(set) var triggerCount: Int = 0

    // MARK: - Configuration

    public var isEnabled: Bool {
        AgentSecPolicy.shared.killSwitch.enabled
    }

    // MARK: - Callbacks

    /// Callback when kill switch is triggered
    public var onTrigger: ((String) -> Void)?

    /// Callback when kill switch is reset
    public var onReset: (() -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Trigger Methods

    /// Trigger the kill switch
    /// - Parameter reason: The reason for triggering
    public func trigger(reason: String) {
        guard isEnabled else {
            logger.warning("Kill switch trigger attempted but kill switch is disabled")
            return
        }

        isTriggered = true
        triggerReason = reason
        triggerTimestamp = Date()
        triggerCount += 1

        logger.critical("KILL SWITCH TRIGGERED: \(reason)")

        // Log to audit trail
        if AgentSecPolicy.shared.killSwitch.logToAudit {
            AgentSecAuditLog.shared.log(
                event: .killSwitchTriggered,
                details: reason,
                severity: .critical
            )
        }

        // Notify user
        if AgentSecPolicy.shared.killSwitch.notifyUser {
            postKillSwitchNotification(reason: reason)
        }

        // Call custom handler
        onTrigger?(reason)
    }

    /// Check if operations should be halted
    public func shouldHalt() -> Bool {
        isTriggered
    }

    /// Get the halt reason if triggered
    public func haltReason() -> String? {
        guard isTriggered else { return nil }
        return triggerReason
    }

    // MARK: - Reset Methods

    /// Reset the kill switch (requires manual confirmation)
    /// - Parameter confirmation: Must be "RESET_KILL_SWITCH" to confirm
    public func reset(confirmation: String) -> Bool {
        guard confirmation == "RESET_KILL_SWITCH" else {
            logger.warning("Kill switch reset attempted with invalid confirmation")
            return false
        }

        isTriggered = false
        triggerReason = nil

        logger.info("Kill switch reset by user")

        AgentSecAuditLog.shared.log(
            event: .killSwitchReset,
            details: "Kill switch manually reset",
            severity: .high
        )

        onReset?()
        return true
    }

    /// Force reset (for testing only)
    func forceReset() {
        isTriggered = false
        triggerReason = nil
        triggerTimestamp = nil
        logger.warning("Kill switch force reset - for testing only")
    }

    // MARK: - Notification

    private func postKillSwitchNotification(reason: String) {
        NotificationCenter.default.post(
            name: .agentSecKillSwitchTriggered,
            object: nil,
            userInfo: [
                "reason": reason,
                "timestamp": Date()
            ]
        )
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let agentSecKillSwitchTriggered = Notification.Name("com.thea.agentSecKillSwitchTriggered")
    static let agentSecKillSwitchReset = Notification.Name("com.thea.agentSecKillSwitchReset")
}

// MARK: - Operation Guard

/// Convenience wrapper for guarding operations with kill switch
public enum KillSwitchGuard {
    /// Execute an operation only if kill switch is not triggered
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - onHalted: Callback if operation is halted
    /// - Returns: Result of operation or nil if halted
    @MainActor
    public static func execute<T>(
        _ operation: () async throws -> T,
        onHalted: ((String) -> Void)? = nil
    ) async throws -> T? {
        let killSwitch = AgentSecKillSwitch.shared

        if killSwitch.shouldHalt() {
            let reason = killSwitch.haltReason() ?? "Kill switch triggered"
            onHalted?(reason)
            return nil
        }

        return try await operation()
    }

    /// Execute an operation with automatic kill switch on failure
    @MainActor
    public static func executeWithProtection<T>(
        _ operation: () async throws -> T,
        triggerOnFailure: Bool = false
    ) async throws -> T {
        let killSwitch = AgentSecKillSwitch.shared

        // Check if already halted
        if killSwitch.shouldHalt() {
            throw KillSwitchError.operationHalted(killSwitch.haltReason() ?? "Kill switch active")
        }

        do {
            return try await operation()
        } catch {
            if triggerOnFailure {
                killSwitch.trigger(reason: "Operation failed with error: \(error.localizedDescription)")
            }
            throw error
        }
    }
}

// MARK: - Errors

public enum KillSwitchError: Error, LocalizedError {
    case operationHalted(String)
    case killSwitchActive

    public var errorDescription: String? {
        switch self {
        case let .operationHalted(reason):
            "Operation halted by kill switch: \(reason)"
        case .killSwitchActive:
            "Kill switch is active - all operations halted"
        }
    }
}
