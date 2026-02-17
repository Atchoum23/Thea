import Foundation
import OSLog
import SwiftUI

/// Centralized approval manager for all operations
/// Handles user confirmation for sensitive operations with proper async continuation handling
@MainActor
@Observable
public final class ApprovalManager {
    public static let shared = ApprovalManager()

    private let logger = Logger(subsystem: "com.thea.core", category: "ApprovalManager")

    // Pending approvals
    public var pendingApprovals: [ApprovalRequest] = []
    public var showApprovalDialog: Bool = false
    public var currentRequest: ApprovalRequest?

    /// Stored continuations for pending approval requests
    private var continuations: [UUID: CheckedContinuation<ApprovalDecision, Error>] = [:]

    /// Timeout for approval requests (default: 5 minutes)
    public var approvalTimeout: TimeInterval = 300

    private init() {}

    /// Request approval for an operation
    public func requestApproval(
        operation: OperationType,
        details: String,
        previewData: String? = nil
    ) async throws -> ApprovalDecision {
        let mode = AppConfiguration.shared.executionMode.mode

        // In aggressive mode, auto-approve everything
        if mode == .aggressive {
            logger.debug("Auto-approving \(operation.rawValue) in aggressive mode")
            return .approved
        }

        // In normal mode, check if operation requires approval
        if mode == .normal, shouldAutoApprove(operation) {
            logger.debug("Auto-approving \(operation.rawValue) based on settings")
            return .approved
        }

        // Safe mode or normal mode destructive operation - ask user
        let request = ApprovalRequest(
            id: UUID(),
            operation: operation,
            details: details,
            previewData: previewData,
            timestamp: Date()
        )

        logger.info("Requesting user approval for \(operation.rawValue)")
        return try await requestUserApproval(request)
    }

    private func shouldAutoApprove(_ operation: OperationType) -> Bool {
        let config = AppConfiguration.shared.executionMode

        switch operation {
        case .readFile, .listDirectory, .searchData:
            return config.autoApproveReadOperations
        case .writeFile, .deleteFile:
            return !config.requireApprovalForFileEdits
        case .executeTerminalCommand:
            return !config.requireApprovalForTerminalCommands
        case .browserAction:
            return !config.requireApprovalForBrowserActions
        case .systemAutomation:
            return !config.requireApprovalForSystemAutomation
        case .executePlan:
            return !config.showPlanBeforeExecution
        }
    }

    private func requestUserApproval(_ request: ApprovalRequest) async throws -> ApprovalDecision {
        try await withCheckedThrowingContinuation { continuation in
            // Store the continuation for later resolution
            self.continuations[request.id] = continuation

            // Update UI state
            self.currentRequest = request
            self.pendingApprovals.append(request)
            self.showApprovalDialog = true

            // Set up timeout
            Task {
                try? await Task.sleep(for: .seconds(approvalTimeout))

                // If still pending after timeout, reject
                if self.continuations[request.id] != nil {
                    self.logger.warning("Approval request timed out: \(request.id)")
                    self.respondToRequest(id: request.id, decision: .rejected)
                }
            }
        }
    }

    /// User responded to approval request
    public func respondToRequest(id: UUID, decision: ApprovalDecision) {
        logger.info("User responded to approval \(id): \(decision.rawValue)")

        // Resume the continuation with the decision
        if let continuation = continuations.removeValue(forKey: id) {
            continuation.resume(returning: decision)
        }

        // Update pending approvals list
        pendingApprovals.removeAll { $0.id == id }

        // Update UI state
        if pendingApprovals.isEmpty {
            showApprovalDialog = false
            currentRequest = nil
        } else {
            currentRequest = pendingApprovals.first
        }
    }

    /// Cancel a pending approval request
    public func cancelRequest(id: UUID) {
        logger.info("Cancelling approval request: \(id)")

        if let continuation = continuations.removeValue(forKey: id) {
            continuation.resume(throwing: ApprovalError.cancelled)
        }

        pendingApprovals.removeAll { $0.id == id }

        if pendingApprovals.isEmpty {
            showApprovalDialog = false
            currentRequest = nil
        } else {
            currentRequest = pendingApprovals.first
        }
    }

    /// Cancel all pending approval requests
    public func cancelAllRequests() {
        let count = continuations.count
        logger.info("Cancelling all \(count) pending approval requests")

        for (id, continuation) in continuations {
            continuation.resume(throwing: ApprovalError.cancelled)
            pendingApprovals.removeAll { $0.id == id }
        }

        continuations.removeAll()
        pendingApprovals.removeAll()
        showApprovalDialog = false
        currentRequest = nil
    }

    /// Check if there are any pending approvals
    public var hasPendingApprovals: Bool {
        !pendingApprovals.isEmpty
    }

    /// Get the count of pending approvals
    public var pendingCount: Int {
        pendingApprovals.count
    }
}

// MARK: - Error Types

public enum ApprovalError: LocalizedError {
    case cancelled
    case timeout
    case invalidRequest

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            "Approval request was cancelled"
        case .timeout:
            "Approval request timed out"
        case .invalidRequest:
            "Invalid approval request"
        }
    }
}

// MARK: - Operation Types

public enum OperationType: String, Codable, Sendable, CaseIterable {
    case readFile = "Read File"
    case writeFile = "Write File"
    case deleteFile = "Delete File"
    case listDirectory = "List Directory"
    case searchData = "Search Data"
    case executeTerminalCommand = "Execute Terminal Command"
    case browserAction = "Browser Action"
    case systemAutomation = "System Automation"
    case executePlan = "Execute Plan"

    /// Icon for the operation type
    public var icon: String {
        switch self {
        case .readFile: "doc.text"
        case .writeFile: "doc.text.fill"
        case .deleteFile: "trash"
        case .listDirectory: "folder"
        case .searchData: "magnifyingglass"
        case .executeTerminalCommand: "terminal"
        case .browserAction: "globe"
        case .systemAutomation: "gearshape.2"
        case .executePlan: "list.bullet.clipboard"
        }
    }

    /// Whether this operation is considered destructive
    public var isDestructive: Bool {
        switch self {
        case .deleteFile, .executeTerminalCommand, .systemAutomation:
            true
        default:
            false
        }
    }
}

// MARK: - Decision Types

public enum ApprovalDecision: String, Codable, Sendable {
    case approved = "Approved"
    case rejected = "Rejected"
    case editAndApprove = "Edit and Approve"

    /// Whether the operation should proceed
    public var shouldProceed: Bool {
        switch self {
        case .approved, .editAndApprove:
            true
        case .rejected:
            false
        }
    }
}

// MARK: - Request Model

public struct ApprovalRequest: Identifiable, Sendable {
    public let id: UUID
    public let operation: OperationType
    public let details: String
    public let previewData: String?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        operation: OperationType,
        details: String,
        previewData: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.operation = operation
        self.details = details
        self.previewData = previewData
        self.timestamp = timestamp
    }
}
