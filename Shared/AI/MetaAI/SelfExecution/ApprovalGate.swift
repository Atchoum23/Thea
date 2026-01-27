// ApprovalGate.swift
import Foundation
import OSLog

public actor ApprovalGate {
    public static let shared = ApprovalGate()

    private let logger = Logger(subsystem: "com.thea.app", category: "ApprovalGate")

    public enum ApprovalLevel: String, Sendable {
        case phaseStart // Before starting a phase
        case fileCreation // Before creating each file (verbose mode)
        case buildFix // Before applying AI-generated fixes
        case phaseComplete // Before marking phase complete
        case dmgCreation // Before creating DMG
    }

    public struct ApprovalRequest: Sendable {
        public let id: UUID
        public let level: ApprovalLevel
        public let description: String
        public let details: String
        public let timestamp: Date
    }

    public struct ApprovalResponse: Sendable {
        public let approved: Bool
        public let message: String?
        public let timestamp: Date
    }

    private var pendingApproval: ApprovalRequest?
    private var approvalContinuation: CheckedContinuation<ApprovalResponse, Never>?
    private var verboseMode: Bool = false

    // MARK: - Public API

    public func setVerboseMode(_ enabled: Bool) {
        verboseMode = enabled
        logger.info("Verbose approval mode: \(enabled)")
    }

    public func requestApproval(
        level: ApprovalLevel,
        description: String,
        details: String
    ) async -> ApprovalResponse {
        // In verbose mode, always wait for approval
        // In normal mode, only wait for critical gates
        let requiresApproval = verboseMode || level == .phaseStart || level == .phaseComplete || level == .dmgCreation

        if !requiresApproval {
            logger.info("Auto-approving: \(description)")
            return ApprovalResponse(approved: true, message: "Auto-approved", timestamp: Date())
        }

        let request = ApprovalRequest(
            id: UUID(),
            level: level,
            description: description,
            details: details,
            timestamp: Date()
        )

        pendingApproval = request

        logger.info("Requesting approval: \(description)")

        // Post notification for UI
        await MainActor.run {
            NotificationCenter.default.post(
                name: .approvalRequested,
                object: nil,
                userInfo: ["request": request]
            )
        }

        // Wait for response
        return await withCheckedContinuation { continuation in
            approvalContinuation = continuation
        }
    }

    public func approve(message: String? = nil) {
        guard let continuation = approvalContinuation else {
            logger.warning("No pending approval to approve")
            return
        }

        let response = ApprovalResponse(
            approved: true,
            message: message,
            timestamp: Date()
        )

        pendingApproval = nil
        approvalContinuation = nil

        logger.info("Approval granted")
        continuation.resume(returning: response)
    }

    public func reject(reason: String) {
        guard let continuation = approvalContinuation else {
            logger.warning("No pending approval to reject")
            return
        }

        let response = ApprovalResponse(
            approved: false,
            message: reason,
            timestamp: Date()
        )

        pendingApproval = nil
        approvalContinuation = nil

        logger.info("Approval rejected: \(reason)")
        continuation.resume(returning: response)
    }

    public func getPendingApproval() -> ApprovalRequest? {
        pendingApproval
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let approvalRequested = Notification.Name("com.thea.approvalRequested")
    static let phaseProgressUpdated = Notification.Name("com.thea.phaseProgressUpdated")
}
