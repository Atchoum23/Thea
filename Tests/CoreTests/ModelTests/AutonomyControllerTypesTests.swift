import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Intelligence/Autonomy/AutonomyController.swift)

private enum TestAutonomyLevel: String, Sendable, CaseIterable, Codable, Comparable {
    case disabled
    case conservative
    case balanced
    case proactive
    case autonomous

    var displayName: String {
        switch self {
        case .disabled: return "Disabled"
        case .conservative: return "Conservative"
        case .balanced: return "Balanced"
        case .proactive: return "Proactive"
        case .autonomous: return "Autonomous"
        }
    }

    var description: String {
        switch self {
        case .disabled: return "No autonomous actions"
        case .conservative: return "Only safe, reversible actions"
        case .balanced: return "Moderate risk tolerance"
        case .proactive: return "High initiative, some risk"
        case .autonomous: return "Full autonomy, minimal guardrails"
        }
    }

    var maxAutoRisk: TestRiskLevel {
        switch self {
        case .disabled: return .none
        case .conservative: return .minimal
        case .balanced: return .low
        case .proactive: return .medium
        case .autonomous: return .high
        }
    }

    var riskTolerance: Double {
        switch self {
        case .disabled: return 0.0
        case .conservative: return 0.2
        case .balanced: return 0.5
        case .proactive: return 0.7
        case .autonomous: return 0.9
        }
    }

    static func < (lhs: TestAutonomyLevel, rhs: TestAutonomyLevel) -> Bool {
        lhs.riskTolerance < rhs.riskTolerance
    }
}

private enum TestRiskLevel: Int, Sendable, CaseIterable, Codable, Comparable {
    case none = 0
    case minimal = 1
    case low = 2
    case medium = 3
    case high = 4
    case critical = 5

    var displayName: String {
        switch self {
        case .none: return "None"
        case .minimal: return "Minimal"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    static func < (lhs: TestRiskLevel, rhs: TestRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private enum TestActionCategory: String, Sendable, CaseIterable, Codable {
    case research
    case analysis
    case generation
    case modification
    case communication
    case execution
    case deletion
    case automation
    case system

    var defaultRiskLevel: TestRiskLevel {
        switch self {
        case .research, .analysis: return .none
        case .generation: return .minimal
        case .modification: return .low
        case .communication: return .medium
        case .execution: return .medium
        case .deletion: return .high
        case .automation: return .medium
        case .system: return .critical
        }
    }
}

private enum TestApprovalType: String, Sendable, CaseIterable {
    case userConfirmation
    case biometricAuth
    case timeDelay
    case none
}

private struct TestActionResult: Sendable {
    let success: Bool
    let message: String
    let data: [String: String]?
    let canUndo: Bool

    init(success: Bool, message: String, data: [String: String]? = nil, canUndo: Bool = false) {
        self.success = success
        self.message = message
        self.data = data
        self.canUndo = canUndo
    }
}

private enum TestPendingStatus: String, Sendable, CaseIterable {
    case pending
    case approved
    case rejected
    case expired
    case executing
    case completed
    case failed

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .rejected, .expired: return true
        case .pending, .approved, .executing: return false
        }
    }

    var isActive: Bool {
        self == .executing
    }
}

// MARK: - Risk Evaluation Logic

private func evaluateAction(
    category: TestActionCategory,
    autonomyLevel: TestAutonomyLevel,
    requireConfirmForCritical: Bool = true
) -> (allowed: Bool, needsApproval: Bool, reason: String) {
    let riskLevel = category.defaultRiskLevel
    let maxAllowed = autonomyLevel.maxAutoRisk

    if autonomyLevel == .disabled {
        return (false, false, "Autonomy is disabled")
    }

    if riskLevel > maxAllowed {
        if requireConfirmForCritical && riskLevel >= .high {
            return (false, true, "Action risk \(riskLevel.displayName) exceeds autonomy level \(autonomyLevel.displayName)")
        }
        return (false, true, "Requires approval")
    }

    return (true, false, "Within autonomy bounds")
}

private func shouldThrottle(actionsThisHour: Int, maxActionsPerHour: Int) -> Bool {
    actionsThisHour >= maxActionsPerHour
}

// MARK: - Tests

@Suite("AutonomyLevel Enum — Controller")
struct AutonomyControllerLevelTests {
    @Test("All 5 levels exist")
    func allCases() {
        #expect(TestAutonomyLevel.allCases.count == 5)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = TestAutonomyLevel.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Display names are non-empty")
    func displayNames() {
        for level in TestAutonomyLevel.allCases {
            #expect(!level.displayName.isEmpty)
        }
    }

    @Test("Descriptions are non-empty")
    func descriptions() {
        for level in TestAutonomyLevel.allCases {
            #expect(!level.description.isEmpty)
        }
    }

    @Test("Risk tolerance ordering")
    func riskToleranceOrdering() {
        let tolerances = TestAutonomyLevel.allCases.map(\.riskTolerance)
        for i in 1..<tolerances.count {
            #expect(tolerances[i] > tolerances[i - 1])
        }
    }

    @Test("Comparable ordering matches risk tolerance")
    func comparableOrdering() {
        #expect(TestAutonomyLevel.disabled < .conservative)
        #expect(TestAutonomyLevel.conservative < .balanced)
        #expect(TestAutonomyLevel.balanced < .proactive)
        #expect(TestAutonomyLevel.proactive < .autonomous)
    }

    @Test("Max auto risk escalates with level")
    func maxAutoRiskEscalation() {
        #expect(TestAutonomyLevel.disabled.maxAutoRisk == .none)
        #expect(TestAutonomyLevel.conservative.maxAutoRisk == .minimal)
        #expect(TestAutonomyLevel.balanced.maxAutoRisk == .low)
        #expect(TestAutonomyLevel.proactive.maxAutoRisk == .medium)
        #expect(TestAutonomyLevel.autonomous.maxAutoRisk == .high)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for level in TestAutonomyLevel.allCases {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(TestAutonomyLevel.self, from: data)
            #expect(decoded == level)
        }
    }
}

@Suite("RiskLevel Enum")
struct RiskLevelTests {
    @Test("All 6 levels exist")
    func allCases() {
        #expect(TestRiskLevel.allCases.count == 6)
    }

    @Test("Raw values 0-5")
    func rawValues() {
        #expect(TestRiskLevel.none.rawValue == 0)
        #expect(TestRiskLevel.minimal.rawValue == 1)
        #expect(TestRiskLevel.low.rawValue == 2)
        #expect(TestRiskLevel.medium.rawValue == 3)
        #expect(TestRiskLevel.high.rawValue == 4)
        #expect(TestRiskLevel.critical.rawValue == 5)
    }

    @Test("Comparable ordering")
    func ordering() {
        #expect(TestRiskLevel.none < .minimal)
        #expect(TestRiskLevel.minimal < .low)
        #expect(TestRiskLevel.low < .medium)
        #expect(TestRiskLevel.medium < .high)
        #expect(TestRiskLevel.high < .critical)
    }

    @Test("Display names unique")
    func displayNames() {
        let names = TestRiskLevel.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }
}

@Suite("ActionCategory Enum")
struct ActionCategoryTests {
    @Test("All 9 categories exist")
    func allCases() {
        #expect(TestActionCategory.allCases.count == 9)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = TestActionCategory.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Safe categories have low default risk")
    func safeCategories() {
        #expect(TestActionCategory.research.defaultRiskLevel <= .minimal)
        #expect(TestActionCategory.analysis.defaultRiskLevel <= .minimal)
    }

    @Test("Dangerous categories have high default risk")
    func dangerousCategories() {
        #expect(TestActionCategory.deletion.defaultRiskLevel >= .high)
        #expect(TestActionCategory.system.defaultRiskLevel >= .critical)
    }

    @Test("Communication has medium risk")
    func communicationRisk() {
        #expect(TestActionCategory.communication.defaultRiskLevel == .medium)
    }
}

@Suite("ApprovalType Enum")
struct ApprovalTypeTests {
    @Test("All 4 types exist")
    func allCases() {
        #expect(TestApprovalType.allCases.count == 4)
    }
}

@Suite("ActionResult Struct")
struct ActionResultTests {
    @Test("Success result")
    func successResult() {
        let result = TestActionResult(success: true, message: "Done")
        #expect(result.success)
        #expect(result.message == "Done")
        #expect(result.data == nil)
        #expect(!result.canUndo)
    }

    @Test("Result with data")
    func withData() {
        let result = TestActionResult(success: true, message: "OK", data: ["key": "value"], canUndo: true)
        #expect(result.data?["key"] == "value")
        #expect(result.canUndo)
    }

    @Test("Failure result")
    func failureResult() {
        let result = TestActionResult(success: false, message: "Error occurred")
        #expect(!result.success)
    }
}

@Suite("PendingStatus Enum")
struct PendingStatusTests {
    @Test("All 7 statuses exist")
    func allCases() {
        #expect(TestPendingStatus.allCases.count == 7)
    }

    @Test("Terminal states")
    func terminalStates() {
        #expect(TestPendingStatus.completed.isTerminal)
        #expect(TestPendingStatus.failed.isTerminal)
        #expect(TestPendingStatus.rejected.isTerminal)
        #expect(TestPendingStatus.expired.isTerminal)
        #expect(!TestPendingStatus.pending.isTerminal)
        #expect(!TestPendingStatus.approved.isTerminal)
        #expect(!TestPendingStatus.executing.isTerminal)
    }

    @Test("Active states")
    func activeStates() {
        #expect(TestPendingStatus.executing.isActive)
        #expect(!TestPendingStatus.pending.isActive)
    }
}

@Suite("Risk Evaluation Logic")
struct RiskEvaluationTests {
    @Test("Disabled autonomy blocks all actions")
    func disabledBlocks() {
        let result = evaluateAction(category: .research, autonomyLevel: .disabled)
        #expect(!result.allowed)
    }

    @Test("Safe action allowed at conservative level")
    func safeAtConservative() {
        let result = evaluateAction(category: .research, autonomyLevel: .conservative)
        #expect(result.allowed)
        #expect(!result.needsApproval)
    }

    @Test("Deletion blocked at conservative level")
    func deletionAtConservative() {
        let result = evaluateAction(category: .deletion, autonomyLevel: .conservative)
        #expect(!result.allowed)
        #expect(result.needsApproval)
    }

    @Test("System action blocked at proactive level")
    func systemAtProactive() {
        let result = evaluateAction(category: .system, autonomyLevel: .proactive)
        #expect(!result.allowed)
        #expect(result.needsApproval)
    }

    @Test("Research allowed at all non-disabled levels")
    func researchAlwaysAllowed() {
        for level in TestAutonomyLevel.allCases where level != .disabled {
            let result = evaluateAction(category: .research, autonomyLevel: level)
            #expect(result.allowed, "Research should be allowed at \(level.displayName)")
        }
    }

    @Test("Autonomous level allows most actions")
    func autonomousAllowsMost() {
        let allowedCategories: [TestActionCategory] = [.research, .analysis, .generation, .modification, .communication, .execution, .automation]
        for category in allowedCategories {
            let result = evaluateAction(category: category, autonomyLevel: .autonomous)
            #expect(result.allowed, "\(category.rawValue) should be allowed at autonomous")
        }
    }
}

@Suite("Throttle Logic")
struct ThrottleTests {
    @Test("Under limit not throttled")
    func underLimit() {
        #expect(!shouldThrottle(actionsThisHour: 10, maxActionsPerHour: 50))
    }

    @Test("At limit throttled")
    func atLimit() {
        #expect(shouldThrottle(actionsThisHour: 50, maxActionsPerHour: 50))
    }

    @Test("Over limit throttled")
    func overLimit() {
        #expect(shouldThrottle(actionsThisHour: 51, maxActionsPerHour: 50))
    }

    @Test("Zero limit always throttles")
    func zeroLimit() {
        #expect(shouldThrottle(actionsThisHour: 0, maxActionsPerHour: 0))
    }
}
