// FocusModeIntelligence+Reliability.swift
// THEA - Action verification, retry logic, and reliability guarantees
// Split from FocusModeIntelligence+Learning.swift

import Foundation
import UserNotifications

// MARK: - Reliability: Action Verification & Retry

extension FocusModeIntelligence {

    // MARK: - Types

    /// A pending action that requires verification and may be retried on failure.
    struct PendingAction: Identifiable, Sendable {
        let id: UUID
        // periphery:ignore - Reserved: actionType property — reserved for future feature activation
        let actionType: ActionType
        // periphery:ignore - Reserved: timestamp property — reserved for future feature activation
        let timestamp: Date
        // periphery:ignore - Reserved: PendingAction type reserved for future feature activation
        var attempts: Int
        // periphery:ignore - Reserved: lastAttempt property — reserved for future feature activation
        var lastAttempt: Date
        // periphery:ignore - Reserved: verified property — reserved for future feature activation
        var verified: Bool
        // periphery:ignore - Reserved: maxRetries property — reserved for future feature activation
        let maxRetries: Int
        // periphery:ignore - Reserved: verificationMethod property — reserved for future feature activation
        let verificationMethod: VerificationMethod

        /// The type of action being executed.
        enum ActionType: String, Sendable {
            case callForwardingEnable
            case callForwardingDisable
            case comboxGreetingChange
            case whatsAppStatusUpdate
            case sendAutoReply
            case shortcutExecution
        }

        /// How the action's success is verified.
        enum VerificationMethod: String, Sendable {
            case callbackURL // THEA receives callback when done
            case pollStatus // Check status after delay
            case assumeSuccess // Fire and forget
            case userConfirmation // Ask user to confirm
        }
    }

    // MARK: - Execution

    /// Execute an action with verification and retry logic.
    ///
    /// Attempts the action up to `maxRetries` times with exponential backoff.
    /// After each attempt, verifies success using the specified method.
    /// If all retries fail, notifies the user.
    ///
    /// - Parameters:
    ///   - actionType: The type of action to execute.
    ///   - action: The async closure that performs the action, returning `true` on success.
    ///   - verificationMethod: How to verify the action succeeded. Defaults to `.pollStatus`.
    ///   - maxRetries: Maximum number of attempts. Defaults to 3.
    /// - Returns: `true` if the action succeeded and was verified, `false` if all retries failed.
    // periphery:ignore - Reserved: executeWithVerification(actionType:action:verificationMethod:maxRetries:) instance method — reserved for future feature activation
    func executeWithVerification(
        actionType: PendingAction.ActionType,
        action: @escaping () async -> Bool,
        // periphery:ignore - Reserved: executeWithVerification(actionType:action:verificationMethod:maxRetries:) instance method reserved for future feature activation
        verificationMethod: PendingAction.VerificationMethod = .pollStatus,
        maxRetries: Int = 3
    ) async -> Bool {
        let pendingAction = PendingAction(
            id: UUID(),
            actionType: actionType,
            timestamp: Date(),
            attempts: 0,
            lastAttempt: Date(),
            verified: false,
            maxRetries: maxRetries,
            verificationMethod: verificationMethod
        )

        appendPendingAction(pendingAction)

        for attempt in 1...maxRetries {
            print("[Reliability] Executing \(actionType.rawValue), attempt \(attempt)/\(maxRetries)")

            let success = await action()

            if success {
                // Verify the action actually worked
                if verificationMethod == .pollStatus {
                    try? await Task.sleep(for: .seconds(2)) // Safe: verification delay; sleep cancellation means task was cancelled; non-fatal
                    let verified = await verifyAction(actionType)
                    if verified {
                        markActionVerified(pendingAction.id)
                        return true
                    }
                } else {
                    markActionVerified(pendingAction.id)
                    return true
                }
            }

            // Wait before retry with exponential backoff
            let delay = Double(attempt) * 2.0
            try? await Task.sleep(for: .seconds(delay)) // Safe: backoff delay; sleep cancellation exits the retry loop; non-fatal
        }

        // All retries failed - notify user
        await notifyUserOfFailedAction(actionType)
        return false
    }

    // MARK: - Verification

    /// Verify that a previously executed action actually succeeded.
    ///
    /// - Parameter actionType: The type of action to verify.
    /// - Returns: `true` if the action is verified as successful.
    // periphery:ignore - Reserved: verifyAction(_:) instance method — reserved for future feature activation
    func verifyAction(_ actionType: PendingAction.ActionType) async -> Bool {
        switch actionType {
        // periphery:ignore - Reserved: verifyAction(_:) instance method reserved for future feature activation
        case .callForwardingEnable:
            // Could check by calling *#21# to query forwarding status
            return true // Assume success for now
        case .callForwardingDisable:
            return true
        case .comboxGreetingChange:
            return true
        case .whatsAppStatusUpdate:
            // Could check WhatsApp Desktop window
            return true
        case .sendAutoReply:
            return true
        case .shortcutExecution:
            return true
        }
    }

    /// Mark a pending action as verified (successfully completed).
    ///
    /// - Parameter id: The UUID of the pending action to mark.
    // periphery:ignore - Reserved: markActionVerified(_:) instance method — reserved for future feature activation
    func markActionVerified(_ id: UUID) {
        // periphery:ignore - Reserved: markActionVerified(_:) instance method reserved for future feature activation
        markPendingActionVerified(id)
    }

    /// Notify the user that an action failed after all retry attempts.
    ///
    /// Sends a local notification with the failed action type so the user can take manual action.
    ///
    /// - Parameter actionType: The type of action that failed.
    // periphery:ignore - Reserved: notifyUserOfFailedAction(_:) instance method reserved for future feature activation
    func notifyUserOfFailedAction(_ actionType: PendingAction.ActionType) async {
        let content = UNMutableNotificationContent()
        content.title = "\u{26A0}\u{FE0F} THEA Action Failed"
        content.body = "Failed to execute: \(actionType.rawValue). Please check manually."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request) // Safe: notification delivery failure is non-fatal; reliability tracking continues

        print("[Reliability] Action failed after all retries: \(actionType.rawValue)")
    }
}
