import Foundation
import SwiftUI

/// Centralized approval manager for all operations
@MainActor
@Observable
public final class ApprovalManager {
    public static let shared = ApprovalManager()

    // Pending approvals
    public var pendingApprovals: [ApprovalRequest] = []
    public var showApprovalDialog: Bool = false
    public var currentRequest: ApprovalRequest?

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
            return .approved
        }

        // In normal mode, check if operation requires approval
        if mode == .normal && shouldAutoApprove(operation) {
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
        try await withCheckedThrowingContinuation { _ in
            DispatchQueue.main.async {
                self.currentRequest = request
                self.showApprovalDialog = true
                self.pendingApprovals.append(request)

                // Store continuation for later resolution
                // Note: In production, use a dictionary to map request ID to continuation
            }
        }
    }

    /// User responded to approval request
    public func respondToRequest(id: UUID, decision: ApprovalDecision) {
        guard let index = pendingApprovals.firstIndex(where: { $0.id == id }) else { return }
        pendingApprovals.remove(at: index)

        if pendingApprovals.isEmpty {
            showApprovalDialog = false
            currentRequest = nil
        } else {
            currentRequest = pendingApprovals.first
        }
    }
}

public enum OperationType: String, Codable, Sendable {
    case readFile = "Read File"
    case writeFile = "Write File"
    case deleteFile = "Delete File"
    case listDirectory = "List Directory"
    case searchData = "Search Data"
    case executeTerminalCommand = "Execute Terminal Command"
    case browserAction = "Browser Action"
    case systemAutomation = "System Automation"
    case executePlan = "Execute Plan"
}

public enum ApprovalDecision: String, Codable, Sendable {
    case approved = "Approved"
    case rejected = "Rejected"
    case editAndApprove = "Edit and Approve"
}

public struct ApprovalRequest: Identifiable, Sendable {
    public let id: UUID
    public let operation: OperationType
    public let details: String
    public let previewData: String?
    public let timestamp: Date
}
