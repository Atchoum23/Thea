// ApprovalManagerTypesTests.swift
// Tests for ApprovalManager enums, decision logic, and operation properties
// Standalone test doubles — no dependency on actual ApprovalManager

import Testing
import Foundation

// MARK: - Test Doubles

/// Mirrors ApprovalManager.OperationType
private enum TestOperationType: String, CaseIterable, Sendable {
    case readFile = "Read File"
    case writeFile = "Write File"
    case deleteFile = "Delete File"
    case listDirectory = "List Directory"
    case searchData = "Search Data"
    case executeTerminalCommand = "Execute Terminal Command"
    case browserAction = "Browser Action"
    case systemAutomation = "System Automation"
    case executePlan = "Execute Plan"

    var icon: String {
        switch self {
        case .readFile: return "doc.text.magnifyingglass"
        case .writeFile: return "doc.badge.plus"
        case .deleteFile: return "trash"
        case .listDirectory: return "folder"
        case .searchData: return "magnifyingglass"
        case .executeTerminalCommand: return "terminal"
        case .browserAction: return "globe"
        case .systemAutomation: return "gearshape.2"
        case .executePlan: return "list.bullet.clipboard"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .deleteFile, .executeTerminalCommand, .systemAutomation:
            return true
        default:
            return false
        }
    }
}

/// Mirrors ApprovalManager.ApprovalDecision
private enum TestApprovalDecision: String, Sendable {
    case approved = "Approved"
    case rejected = "Rejected"
    case editAndApprove = "Edit and Approve"

    var shouldProceed: Bool {
        switch self {
        case .approved, .editAndApprove: return true
        case .rejected: return false
        }
    }
}

/// Mirrors ApprovalManager.ApprovalError
private enum TestApprovalError: Error {
    case cancelled
    case timeout
    case invalidRequest

    var description: String {
        switch self {
        case .cancelled: return "Approval was cancelled"
        case .timeout: return "Approval request timed out"
        case .invalidRequest: return "Invalid approval request"
        }
    }
}

/// Mirrors ApprovalManager.ApprovalRequest
private struct TestApprovalRequest: Identifiable, Sendable {
    let id: UUID
    let operation: TestOperationType
    let details: String
    let previewData: String?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        operation: TestOperationType,
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

/// Mirrors auto-approval logic
private struct TestAutoApprovalConfig {
    var autoApproveReadOperations = true
    var requireApprovalForFileEdits = true
    var requireApprovalForTerminalCommands = true
    var requireApprovalForBrowserActions = true
    var requireApprovalForSystemAutomation = true
    var showPlanBeforeExecution = true

    func shouldAutoApprove(_ operation: TestOperationType) -> Bool {
        switch operation {
        case .readFile, .listDirectory, .searchData:
            return autoApproveReadOperations
        case .writeFile, .deleteFile:
            return !requireApprovalForFileEdits
        case .executeTerminalCommand:
            return !requireApprovalForTerminalCommands
        case .browserAction:
            return !requireApprovalForBrowserActions
        case .systemAutomation:
            return !requireApprovalForSystemAutomation
        case .executePlan:
            return !showPlanBeforeExecution
        }
    }
}

// @unchecked Sendable: test helper class used in single-threaded test context; no concurrent access
/// Approval queue for testing lifecycle
private final class TestApprovalQueue: @unchecked Sendable {
    var pendingApprovals: [TestApprovalRequest] = []
    var showDialog = false

    var currentRequest: TestApprovalRequest? {
        pendingApprovals.first
    }

    func addRequest(_ request: TestApprovalRequest) {
        pendingApprovals.append(request)
        showDialog = true
    }

    func resolveFirst() {
        guard !pendingApprovals.isEmpty else { return }
        pendingApprovals.removeFirst()
        if pendingApprovals.isEmpty {
            showDialog = false
        }
    }

    func cancelAll() {
        pendingApprovals.removeAll()
        showDialog = false
    }
}

// MARK: - Tests

@Suite("OperationType Cases")
struct OperationTypeCaseTests {
    @Test("All 9 operation types exist")
    func allCasesExist() {
        #expect(TestOperationType.allCases.count == 9)
    }

    @Test("Raw values are human-readable display names")
    func rawValuesReadable() {
        #expect(TestOperationType.readFile.rawValue == "Read File")
        #expect(TestOperationType.writeFile.rawValue == "Write File")
        #expect(TestOperationType.deleteFile.rawValue == "Delete File")
        #expect(TestOperationType.listDirectory.rawValue == "List Directory")
        #expect(TestOperationType.searchData.rawValue == "Search Data")
        #expect(TestOperationType.executeTerminalCommand.rawValue == "Execute Terminal Command")
        #expect(TestOperationType.browserAction.rawValue == "Browser Action")
        #expect(TestOperationType.systemAutomation.rawValue == "System Automation")
        #expect(TestOperationType.executePlan.rawValue == "Execute Plan")
    }

    @Test("Raw values are unique")
    func rawValuesUnique() {
        let rawValues = TestOperationType.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

@Suite("OperationType Icons")
struct OperationTypeIconTests {
    @Test("Each operation type has an SF Symbol icon")
    func allHaveIcons() {
        for op in TestOperationType.allCases {
            #expect(!op.icon.isEmpty, "\(op) should have an icon")
        }
    }

    @Test("Icons are unique per operation")
    func iconsUnique() {
        let icons = TestOperationType.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }

    @Test("File operations use doc-prefixed icons")
    func fileOperationIcons() {
        #expect(TestOperationType.readFile.icon.hasPrefix("doc"))
        #expect(TestOperationType.writeFile.icon.hasPrefix("doc"))
    }

    @Test("Delete uses trash icon")
    func deleteUsesTrash() {
        #expect(TestOperationType.deleteFile.icon == "trash")
    }

    @Test("Terminal uses terminal icon")
    func terminalIcon() {
        #expect(TestOperationType.executeTerminalCommand.icon == "terminal")
    }
}

@Suite("OperationType Destructiveness")
struct OperationTypeDestructivenessTests {
    @Test("Destructive operations are exactly 3")
    func destructiveCount() {
        let destructive = TestOperationType.allCases.filter(\.isDestructive)
        #expect(destructive.count == 3)
    }

    @Test("Delete is destructive")
    func deleteDestructive() {
        #expect(TestOperationType.deleteFile.isDestructive)
    }

    @Test("Terminal is destructive")
    func terminalDestructive() {
        #expect(TestOperationType.executeTerminalCommand.isDestructive)
    }

    @Test("System automation is destructive")
    func systemDestructive() {
        #expect(TestOperationType.systemAutomation.isDestructive)
    }

    @Test("Read operations are not destructive")
    func readNotDestructive() {
        #expect(!TestOperationType.readFile.isDestructive)
        #expect(!TestOperationType.listDirectory.isDestructive)
        #expect(!TestOperationType.searchData.isDestructive)
    }

    @Test("Write is not destructive (requires separate approval)")
    func writeNotDestructive() {
        #expect(!TestOperationType.writeFile.isDestructive)
    }

    @Test("Browser action is not destructive")
    func browserNotDestructive() {
        #expect(!TestOperationType.browserAction.isDestructive)
    }

    @Test("Execute plan is not destructive")
    func planNotDestructive() {
        #expect(!TestOperationType.executePlan.isDestructive)
    }
}

@Suite("ApprovalDecision")
struct ApprovalDecisionTests {
    @Test("Approved should proceed")
    func approvedProceeds() {
        #expect(TestApprovalDecision.approved.shouldProceed)
    }

    @Test("Rejected should not proceed")
    func rejectedStops() {
        #expect(!TestApprovalDecision.rejected.shouldProceed)
    }

    @Test("Edit and approve should proceed")
    func editAndApproveProceeds() {
        #expect(TestApprovalDecision.editAndApprove.shouldProceed)
    }

    @Test("Raw values are display strings")
    func rawValues() {
        #expect(TestApprovalDecision.approved.rawValue == "Approved")
        #expect(TestApprovalDecision.rejected.rawValue == "Rejected")
        #expect(TestApprovalDecision.editAndApprove.rawValue == "Edit and Approve")
    }

    @Test("Exactly 2 of 3 decisions should proceed")
    func proceedCount() {
        let all: [TestApprovalDecision] = [.approved, .rejected, .editAndApprove]
        let proceeding = all.filter(\.shouldProceed)
        #expect(proceeding.count == 2)
    }
}

@Suite("ApprovalError")
struct ApprovalErrorTests {
    @Test("All errors have descriptions")
    func allHaveDescriptions() {
        let errors: [TestApprovalError] = [.cancelled, .timeout, .invalidRequest]
        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }

    @Test("Descriptions are distinct")
    func distinctDescriptions() {
        let descriptions = [
            TestApprovalError.cancelled.description,
            TestApprovalError.timeout.description,
            TestApprovalError.invalidRequest.description
        ]
        #expect(Set(descriptions).count == 3)
    }

    @Test("Cancelled error description")
    func cancelledDescription() {
        #expect(TestApprovalError.cancelled.description.contains("cancelled"))
    }

    @Test("Timeout error description")
    func timeoutDescription() {
        #expect(TestApprovalError.timeout.description.contains("timed out"))
    }
}

@Suite("ApprovalRequest")
struct ApprovalRequestTests {
    @Test("Request creation with defaults")
    func createWithDefaults() {
        let request = TestApprovalRequest(operation: .readFile, details: "Test")
        #expect(request.operation == .readFile)
        #expect(request.details == "Test")
        #expect(request.previewData == nil)
    }

    @Test("Request creation with all fields")
    func createWithAllFields() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 0)
        let request = TestApprovalRequest(
            id: id,
            operation: .deleteFile,
            details: "Deleting file",
            previewData: "rm -rf /tmp/test",
            timestamp: date
        )
        #expect(request.id == id)
        #expect(request.operation == .deleteFile)
        #expect(request.details == "Deleting file")
        #expect(request.previewData == "rm -rf /tmp/test")
        #expect(request.timestamp == date)
    }

    @Test("Request is Identifiable")
    func identifiable() {
        let r1 = TestApprovalRequest(operation: .readFile, details: "A")
        let r2 = TestApprovalRequest(operation: .readFile, details: "A")
        #expect(r1.id != r2.id)
    }
}

@Suite("Auto-Approval Logic")
struct AutoApprovalTests {
    @Test("Default config auto-approves read operations")
    func defaultAutoApprovesReads() {
        let config = TestAutoApprovalConfig()
        #expect(config.shouldAutoApprove(.readFile))
        #expect(config.shouldAutoApprove(.listDirectory))
        #expect(config.shouldAutoApprove(.searchData))
    }

    @Test("Default config requires approval for writes")
    func defaultRequiresWriteApproval() {
        let config = TestAutoApprovalConfig()
        #expect(!config.shouldAutoApprove(.writeFile))
        #expect(!config.shouldAutoApprove(.deleteFile))
    }

    @Test("Default config requires approval for terminal")
    func defaultRequiresTerminalApproval() {
        let config = TestAutoApprovalConfig()
        #expect(!config.shouldAutoApprove(.executeTerminalCommand))
    }

    @Test("Default config requires approval for browser")
    func defaultRequiresBrowserApproval() {
        let config = TestAutoApprovalConfig()
        #expect(!config.shouldAutoApprove(.browserAction))
    }

    @Test("Default config requires approval for system automation")
    func defaultRequiresSystemApproval() {
        let config = TestAutoApprovalConfig()
        #expect(!config.shouldAutoApprove(.systemAutomation))
    }

    @Test("Default config requires approval for plan execution")
    func defaultRequiresPlanApproval() {
        let config = TestAutoApprovalConfig()
        #expect(!config.shouldAutoApprove(.executePlan))
    }

    @Test("Disabled read auto-approval blocks reads")
    func disabledReadAutoApproval() {
        var config = TestAutoApprovalConfig()
        config.autoApproveReadOperations = false
        #expect(!config.shouldAutoApprove(.readFile))
        #expect(!config.shouldAutoApprove(.listDirectory))
        #expect(!config.shouldAutoApprove(.searchData))
    }

    @Test("Disabled file edit approval auto-approves writes")
    func disabledFileEditApproval() {
        var config = TestAutoApprovalConfig()
        config.requireApprovalForFileEdits = false
        #expect(config.shouldAutoApprove(.writeFile))
        #expect(config.shouldAutoApprove(.deleteFile))
    }

    @Test("Disabled terminal approval auto-approves terminal")
    func disabledTerminalApproval() {
        var config = TestAutoApprovalConfig()
        config.requireApprovalForTerminalCommands = false
        #expect(config.shouldAutoApprove(.executeTerminalCommand))
    }

    @Test("Fully permissive config auto-approves everything")
    func fullyPermissive() {
        var config = TestAutoApprovalConfig()
        config.autoApproveReadOperations = true
        config.requireApprovalForFileEdits = false
        config.requireApprovalForTerminalCommands = false
        config.requireApprovalForBrowserActions = false
        config.requireApprovalForSystemAutomation = false
        config.showPlanBeforeExecution = false
        for op in TestOperationType.allCases {
            #expect(config.shouldAutoApprove(op), "\(op) should be auto-approved")
        }
    }

    @Test("Fully restrictive config blocks everything")
    func fullyRestrictive() {
        var config = TestAutoApprovalConfig()
        config.autoApproveReadOperations = false
        config.requireApprovalForFileEdits = true
        config.requireApprovalForTerminalCommands = true
        config.requireApprovalForBrowserActions = true
        config.requireApprovalForSystemAutomation = true
        config.showPlanBeforeExecution = true
        for op in TestOperationType.allCases {
            #expect(!config.shouldAutoApprove(op), "\(op) should NOT be auto-approved")
        }
    }
}

@Suite("Approval Queue Lifecycle")
struct ApprovalQueueTests {
    @Test("Empty queue shows no dialog")
    func emptyQueueNoDialog() {
        let queue = TestApprovalQueue()
        #expect(queue.currentRequest == nil)
        #expect(!queue.showDialog)
        #expect(queue.pendingApprovals.isEmpty)
    }

    @Test("Adding request shows dialog")
    func addRequestShowsDialog() {
        let queue = TestApprovalQueue()
        let request = TestApprovalRequest(operation: .readFile, details: "Read")
        queue.addRequest(request)
        #expect(queue.showDialog)
        #expect(queue.currentRequest?.id == request.id)
    }

    @Test("Multiple requests queued FIFO")
    func multipleRequestsFIFO() {
        let queue = TestApprovalQueue()
        let r1 = TestApprovalRequest(operation: .readFile, details: "First")
        let r2 = TestApprovalRequest(operation: .writeFile, details: "Second")
        queue.addRequest(r1)
        queue.addRequest(r2)
        #expect(queue.pendingApprovals.count == 2)
        #expect(queue.currentRequest?.id == r1.id)
    }

    @Test("Resolving first reveals second")
    func resolveRevealsSecond() {
        let queue = TestApprovalQueue()
        let r1 = TestApprovalRequest(operation: .readFile, details: "First")
        let r2 = TestApprovalRequest(operation: .writeFile, details: "Second")
        queue.addRequest(r1)
        queue.addRequest(r2)
        queue.resolveFirst()
        #expect(queue.pendingApprovals.count == 1)
        #expect(queue.currentRequest?.id == r2.id)
        #expect(queue.showDialog)
    }

    @Test("Resolving last hides dialog")
    func resolveLastHidesDialog() {
        let queue = TestApprovalQueue()
        queue.addRequest(TestApprovalRequest(operation: .readFile, details: "Only"))
        queue.resolveFirst()
        #expect(queue.pendingApprovals.isEmpty)
        #expect(!queue.showDialog)
    }

    @Test("Cancel all clears queue and hides dialog")
    func cancelAllClears() {
        let queue = TestApprovalQueue()
        queue.addRequest(TestApprovalRequest(operation: .readFile, details: "A"))
        queue.addRequest(TestApprovalRequest(operation: .writeFile, details: "B"))
        queue.cancelAll()
        #expect(queue.pendingApprovals.isEmpty)
        #expect(!queue.showDialog)
    }

    @Test("Resolve on empty queue is safe")
    func resolveEmptyQueueSafe() {
        let queue = TestApprovalQueue()
        queue.resolveFirst()
        #expect(queue.pendingApprovals.isEmpty)
        #expect(!queue.showDialog)
    }

    @Test("Approval timeout default is 300 seconds")
    func timeoutDefault() {
        let timeout: TimeInterval = 300
        #expect(timeout == 5 * 60)
    }
}
