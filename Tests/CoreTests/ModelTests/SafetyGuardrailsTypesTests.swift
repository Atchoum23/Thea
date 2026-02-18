// SafetyGuardrailsTypesTests.swift
// Tests for SafetyGuardrails types (standalone test doubles)

import Testing
import Foundation

// MARK: - Safety Test Doubles

private enum TestSafetyActionCategory: String, Codable, Sendable, CaseIterable {
    case fileRead, fileWrite, fileDelete, codeExecution, systemCommand
    case networkRequest, databaseOperation, configurationChange
    case authentication, communication, dataExport, installation, other
}

private enum TestSafetyRiskLevel: String, Codable, Sendable, Comparable, CaseIterable {
    case safe, low, medium, high, critical

    static func < (lhs: TestSafetyRiskLevel, rhs: TestSafetyRiskLevel) -> Bool {
        let order: [TestSafetyRiskLevel] = [.safe, .low, .medium, .high, .critical]
        guard let li = order.firstIndex(of: lhs), let ri = order.firstIndex(of: rhs) else { return false }
        return li < ri
    }
}

private struct TestAffectedResource: Identifiable, Sendable {
    let id: UUID
    let type: ResourceType
    let identifier: String
    let changeType: ChangeType

    init(id: UUID = UUID(), type: ResourceType, identifier: String, changeType: ChangeType) {
        self.id = id
        self.type = type
        self.identifier = identifier
        self.changeType = changeType
    }

    enum ResourceType: String, Sendable, CaseIterable {
        case file, directory, database, configuration, system, network, credential, process
    }

    enum ChangeType: String, Sendable, CaseIterable {
        case create, read, update, delete, execute
    }
}

private struct TestActionClassification: Sendable {
    let action: String
    let category: TestSafetyActionCategory
    let riskLevel: TestSafetyRiskLevel
    let isReversible: Bool
    let requiresConfirmation: Bool
    let requiresAuthentication: Bool
    let affectedResources: [TestAffectedResource]
    let potentialImpact: String
    let mitigations: [String]

    init(
        action: String,
        category: TestSafetyActionCategory,
        riskLevel: TestSafetyRiskLevel,
        isReversible: Bool,
        requiresConfirmation: Bool = false,
        requiresAuthentication: Bool = false,
        affectedResources: [TestAffectedResource] = [],
        potentialImpact: String = "",
        mitigations: [String] = []
    ) {
        self.action = action
        self.category = category
        self.riskLevel = riskLevel
        self.isReversible = isReversible
        self.requiresConfirmation = requiresConfirmation
        self.requiresAuthentication = requiresAuthentication
        self.affectedResources = affectedResources
        self.potentialImpact = potentialImpact
        self.mitigations = mitigations
    }
}

private struct TestSnapshotItem: Identifiable, Codable, Sendable {
    let id: UUID
    let resourceType: String
    let resourcePath: String
    let originalContent: String?
    let originalMetadata: [String: String]
    let snapshotPath: String?

    init(
        id: UUID = UUID(), resourceType: String, resourcePath: String,
        originalContent: String? = nil, originalMetadata: [String: String] = [:],
        snapshotPath: String? = nil
    ) {
        self.id = id
        self.resourceType = resourceType
        self.resourcePath = resourcePath
        self.originalContent = originalContent
        self.originalMetadata = originalMetadata
        self.snapshotPath = snapshotPath
    }
}

private struct TestRollbackPoint: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let description: String
    let actionId: UUID
    let snapshotData: [TestSnapshotItem]
    let isValid: Bool
    let expiresAt: Date?

    init(
        id: UUID = UUID(), timestamp: Date = Date(), description: String,
        actionId: UUID, snapshotData: [TestSnapshotItem],
        isValid: Bool = true, expiresAt: Date? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.actionId = actionId
        self.snapshotData = snapshotData
        self.isValid = isValid
        self.expiresAt = expiresAt
    }
}

private struct TestRollbackResult: Sendable {
    let rollbackPointId: UUID
    let success: Bool
    let restoredItems: [String]
    let failedItems: [(path: String, reason: String)]
    let duration: TimeInterval
}

private enum TestInterventionReason: String, Sendable, CaseIterable {
    case highRisk, policyViolation, ambiguousAction, sensitiveData
    case externalSystem, unusualPattern, firstTimeAction
}

private enum TestInterventionUrgency: String, Sendable, CaseIterable {
    case low, normal, high, critical
}

private enum TestAuditOutcome: String, Codable, Sendable, CaseIterable {
    case allowed, blocked, modified, deferred, escalated, timedOut
}

private struct TestSafetyRule: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let category: String
    let riskThreshold: String
    let action: TestRuleAction
    let isEnabled: Bool

    init(
        id: UUID = UUID(), name: String, description: String,
        category: String, riskThreshold: String,
        action: TestRuleAction, isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.riskThreshold = riskThreshold
        self.action = action
        self.isEnabled = isEnabled
    }

    enum TestRuleAction: String, Codable, Sendable, CaseIterable {
        case allow, block, confirm, log, alert
    }
}

// MARK: - Safety Action Category Tests

@Suite("Safety Action Category — Completeness")
struct SafetyActionCategoryTests {
    @Test("All 13 action categories exist")
    func allCases() {
        #expect(TestSafetyActionCategory.allCases.count == 13)
    }

    @Test("All categories have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestSafetyActionCategory.allCases.map(\.rawValue))
        #expect(rawValues.count == 13)
    }

    @Test("Category is Codable")
    func codableRoundtrip() throws {
        for category in TestSafetyActionCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(TestSafetyActionCategory.self, from: data)
            #expect(decoded == category)
        }
    }

    @Test("File operations: read, write, delete")
    func fileOperations() {
        let fileOps: [TestSafetyActionCategory] = [.fileRead, .fileWrite, .fileDelete]
        for op in fileOps {
            #expect(op.rawValue.hasPrefix("file"))
        }
    }
}

// MARK: - Safety Risk Level Tests

@Suite("Safety Risk Level — Ordering")
struct SafetyRiskLevelTests {
    @Test("All 5 risk levels exist")
    func allCases() {
        #expect(TestSafetyRiskLevel.allCases.count == 5)
    }

    @Test("Risk levels are ordered: safe < low < medium < high < critical")
    func ordering() {
        #expect(TestSafetyRiskLevel.safe < .low)
        #expect(TestSafetyRiskLevel.low < .medium)
        #expect(TestSafetyRiskLevel.medium < .high)
        #expect(TestSafetyRiskLevel.high < .critical)
    }

    @Test("safe is not greater than critical")
    func safeNotGreater() {
        #expect(!(TestSafetyRiskLevel.safe > .critical))
    }

    @Test("Sorted risk levels are in ascending order")
    func sortedOrder() {
        let shuffled: [TestSafetyRiskLevel] = [.critical, .safe, .high, .low, .medium]
        let sorted = shuffled.sorted()
        #expect(sorted == [.safe, .low, .medium, .high, .critical])
    }

    @Test("Risk level is Codable")
    func codableRoundtrip() throws {
        for level in TestSafetyRiskLevel.allCases {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(TestSafetyRiskLevel.self, from: data)
            #expect(decoded == level)
        }
    }
}

// MARK: - Affected Resource Tests

@Suite("Affected Resource — Types")
struct AffectedResourceTests {
    @Test("All 8 resource types exist")
    func resourceTypes() {
        #expect(TestAffectedResource.ResourceType.allCases.count == 8)
    }

    @Test("All 5 change types exist")
    func changeTypes() {
        #expect(TestAffectedResource.ChangeType.allCases.count == 5)
    }

    @Test("Resource has unique ID")
    func uniqueID() {
        let a = TestAffectedResource(type: .file, identifier: "/tmp/a", changeType: .create)
        let b = TestAffectedResource(type: .file, identifier: "/tmp/a", changeType: .create)
        #expect(a.id != b.id)
    }

    @Test("Resource preserves properties")
    func propertiesPreserved() {
        let resource = TestAffectedResource(type: .database, identifier: "users_table", changeType: .delete)
        #expect(resource.type == .database)
        #expect(resource.identifier == "users_table")
        #expect(resource.changeType == .delete)
    }
}

// MARK: - Action Classification Tests

@Suite("Action Classification — Construction")
struct ActionClassificationTests {
    @Test("Minimal classification with defaults")
    func minimalDefaults() {
        let action = TestActionClassification(
            action: "read file", category: .fileRead,
            riskLevel: .safe, isReversible: true
        )
        #expect(action.requiresConfirmation == false)
        #expect(action.requiresAuthentication == false)
        #expect(action.affectedResources.isEmpty)
        #expect(action.potentialImpact.isEmpty)
        #expect(action.mitigations.isEmpty)
    }

    @Test("High-risk action with all properties")
    func highRiskAction() {
        let resource = TestAffectedResource(type: .system, identifier: "kernel", changeType: .execute)
        let action = TestActionClassification(
            action: "reboot system", category: .systemCommand,
            riskLevel: .critical, isReversible: false,
            requiresConfirmation: true, requiresAuthentication: true,
            affectedResources: [resource],
            potentialImpact: "System will restart, losing all unsaved work",
            mitigations: ["Save all work", "Notify users"]
        )
        #expect(action.riskLevel == .critical)
        #expect(!action.isReversible)
        #expect(action.requiresConfirmation)
        #expect(action.requiresAuthentication)
        #expect(action.affectedResources.count == 1)
        #expect(action.mitigations.count == 2)
    }
}

// MARK: - Snapshot Item Tests

@Suite("Snapshot Item — Codable")
struct SnapshotItemTests {
    @Test("Snapshot item with content")
    func withContent() {
        let item = TestSnapshotItem(resourceType: "file", resourcePath: "/tmp/test.txt", originalContent: "hello world")
        #expect(item.originalContent == "hello world")
        #expect(item.snapshotPath == nil)
    }

    @Test("Snapshot item with metadata")
    func withMetadata() {
        let item = TestSnapshotItem(
            resourceType: "file", resourcePath: "/etc/config",
            originalMetadata: ["permissions": "644", "owner": "root"]
        )
        #expect(item.originalMetadata.count == 2)
    }

    @Test("Snapshot item Codable roundtrip")
    func codableRoundtrip() throws {
        let item = TestSnapshotItem(
            resourceType: "file", resourcePath: "/tmp/test.txt",
            originalContent: "content", originalMetadata: ["key": "value"]
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(TestSnapshotItem.self, from: data)
        #expect(decoded.resourcePath == item.resourcePath)
        #expect(decoded.originalContent == item.originalContent)
        #expect(decoded.originalMetadata == item.originalMetadata)
    }
}

// MARK: - Rollback Point Tests

@Suite("Rollback Point — Lifecycle")
struct RollbackPointTests {
    @Test("Valid rollback point by default")
    func defaultValid() {
        let point = TestRollbackPoint(description: "Before edit", actionId: UUID(), snapshotData: [])
        #expect(point.isValid)
        #expect(point.expiresAt == nil)
    }

    @Test("Expired rollback point")
    func expired() {
        let past = Date().addingTimeInterval(-3600)
        let point = TestRollbackPoint(description: "Old", actionId: UUID(), snapshotData: [], expiresAt: past)
        #expect(point.expiresAt! < Date())
    }

    @Test("Rollback point with snapshots")
    func withSnapshots() {
        let items = [
            TestSnapshotItem(resourceType: "file", resourcePath: "/a"),
            TestSnapshotItem(resourceType: "file", resourcePath: "/b"),
        ]
        let point = TestRollbackPoint(description: "Multi-file edit", actionId: UUID(), snapshotData: items)
        #expect(point.snapshotData.count == 2)
    }

    @Test("Rollback point Codable roundtrip")
    func codableRoundtrip() throws {
        let point = TestRollbackPoint(description: "Test", actionId: UUID(), snapshotData: [])
        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(TestRollbackPoint.self, from: data)
        #expect(decoded.description == "Test")
        #expect(decoded.isValid)
    }
}

// MARK: - Rollback Result Tests

@Suite("Rollback Result — Success/Failure")
struct RollbackResultTests {
    @Test("Successful rollback")
    func success() {
        let result = TestRollbackResult(
            rollbackPointId: UUID(), success: true,
            restoredItems: ["/a", "/b"], failedItems: [], duration: 0.5
        )
        #expect(result.success)
        #expect(result.restoredItems.count == 2)
        #expect(result.failedItems.isEmpty)
    }

    @Test("Partial rollback failure")
    func partialFailure() {
        let result = TestRollbackResult(
            rollbackPointId: UUID(), success: false,
            restoredItems: ["/a"],
            failedItems: [("/b", "Permission denied")],
            duration: 1.2
        )
        #expect(!result.success)
        #expect(result.restoredItems.count == 1)
        #expect(result.failedItems.count == 1)
    }
}

// MARK: - Intervention Tests

@Suite("Intervention — Reason & Urgency")
struct InterventionTests {
    @Test("All 7 intervention reasons exist")
    func allReasons() {
        #expect(TestInterventionReason.allCases.count == 7)
    }

    @Test("All 4 urgency levels exist")
    func allUrgencies() {
        #expect(TestInterventionUrgency.allCases.count == 4)
    }

    @Test("All reasons have unique raw values")
    func uniqueReasons() {
        let rawValues = Set(TestInterventionReason.allCases.map(\.rawValue))
        #expect(rawValues.count == TestInterventionReason.allCases.count)
    }
}

// MARK: - Audit Outcome Tests

@Suite("Audit Outcome — Cases")
struct SafetyAuditOutcomeTests {
    @Test("All 6 outcomes exist")
    func allCases() {
        #expect(TestAuditOutcome.allCases.count == 6)
    }

    @Test("Outcome is Codable")
    func codableRoundtrip() throws {
        for outcome in TestAuditOutcome.allCases {
            let data = try JSONEncoder().encode(outcome)
            let decoded = try JSONDecoder().decode(TestAuditOutcome.self, from: data)
            #expect(decoded == outcome)
        }
    }
}

// MARK: - Safety Rule Tests

@Suite("Safety Rule — Configuration")
struct SafetyRuleTests {
    @Test("All 5 rule actions exist")
    func allActions() {
        #expect(TestSafetyRule.TestRuleAction.allCases.count == 5)
    }

    @Test("Rule is enabled by default")
    func defaultEnabled() {
        let rule = TestSafetyRule(name: "Block rm -rf", description: "Prevent recursive deletion",
                                  category: "systemCommand", riskThreshold: "critical", action: .block)
        #expect(rule.isEnabled)
    }

    @Test("Disabled rule")
    func disabled() {
        let rule = TestSafetyRule(name: "Log reads", description: "Log file reads",
                                  category: "fileRead", riskThreshold: "safe", action: .log, isEnabled: false)
        #expect(!rule.isEnabled)
    }

    @Test("Rule Codable roundtrip")
    func codableRoundtrip() throws {
        let rule = TestSafetyRule(name: "Test", description: "Desc",
                                  category: "other", riskThreshold: "low", action: .confirm)
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(TestSafetyRule.self, from: data)
        #expect(decoded.name == "Test")
        #expect(decoded.action == .confirm)
    }
}
