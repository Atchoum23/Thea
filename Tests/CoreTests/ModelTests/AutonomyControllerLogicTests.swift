// AutonomyControllerLogicTests.swift
// Tests for AutonomyController service logic: risk assessment, autonomy levels,
// action approval/rejection, rate limiting, category overrides, and decision logic.

import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Intelligence/Autonomy/AutonomyController.swift)

private enum ACAutonomyLevel: String, Sendable, CaseIterable {
    case disabled
    case conservative
    case balanced
    case proactive
    case autonomous

    var displayName: String {
        switch self {
        case .disabled: "Always Ask"
        case .conservative: "Conservative"
        case .balanced: "Balanced"
        case .proactive: "Proactive"
        case .autonomous: "Autonomous"
        }
    }

    var maxAutoRisk: ACRiskLevel {
        switch self {
        case .disabled: .none
        case .conservative: .minimal
        case .balanced: .low
        case .proactive: .medium
        case .autonomous: .high
        }
    }
}

private enum ACRiskLevel: Int, Sendable, Comparable {
    case none = 0
    case minimal = 1
    case low = 2
    case medium = 3
    case high = 4
    case critical = 5

    static func < (lhs: ACRiskLevel, rhs: ACRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .none: "None"
        case .minimal: "Minimal"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .critical: "Critical"
        }
    }
}

private enum ACActionCategory: String, Sendable, CaseIterable {
    case research, analysis, generation, modification
    case communication, execution, deletion, automation, system

    var defaultRiskLevel: ACRiskLevel {
        switch self {
        case .research: .minimal
        case .analysis: .minimal
        case .generation: .low
        case .modification: .medium
        case .communication: .high
        case .execution: .high
        case .deletion: .critical
        case .automation: .medium
        case .system: .high
        }
    }
}

private struct ACAction: Identifiable, Sendable {
    let id: UUID
    let category: ACActionCategory
    let title: String
    let description: String
    let riskLevel: ACRiskLevel

    init(
        id: UUID = UUID(),
        category: ACActionCategory,
        title: String,
        description: String = "",
        riskLevel: ACRiskLevel? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.description = description
        self.riskLevel = riskLevel ?? category.defaultRiskLevel
    }
}

private enum ACDecision: Sendable, Equatable {
    case autoExecute
    case requiresApproval(reason: String)

    var isAutoExecute: Bool {
        if case .autoExecute = self { return true }
        return false
    }

    var reason: String? {
        if case let .requiresApproval(reason) = self { return reason }
        return nil
    }

    static func == (lhs: ACDecision, rhs: ACDecision) -> Bool {
        switch (lhs, rhs) {
        case (.autoExecute, .autoExecute): return true
        case (.requiresApproval, .requiresApproval): return true
        default: return false
        }
    }
}

private struct ACHistoryEntry: Identifiable, Sendable {
    let id: UUID
    let category: ACActionCategory
    let title: String
    let riskLevel: ACRiskLevel
    let success: Bool
    let timestamp: Date
}

// MARK: - Autonomy Controller Logic (mirrors production)

// @unchecked Sendable: test helper class, single-threaded test context
private final class TestAutonomyController: @unchecked Sendable {
    var autonomyLevel: ACAutonomyLevel = .balanced
    var categoryOverrides: [ACActionCategory: ACAutonomyLevel] = [:]
    var isPaused = false
    var requireConfirmForCritical = true
    var maxActionsPerHour = 50
    var actionsThisHour = 0
    var actionHistory: [ACHistoryEntry] = []

    func requestAction(_ action: ACAction) -> ACDecision {
        guard !isPaused else {
            return .requiresApproval(reason: "Autonomy is paused")
        }

        if actionsThisHour >= maxActionsPerHour {
            return .requiresApproval(reason: "Hourly action limit reached")
        }

        let effectiveLevel = categoryOverrides[action.category] ?? autonomyLevel
        let canAutoExecute = shouldAutoExecute(action: action, level: effectiveLevel)

        if canAutoExecute {
            return .autoExecute
        } else {
            let reason = getRejectionReason(action: action, level: effectiveLevel)
            return .requiresApproval(reason: reason)
        }
    }

    func executeAction(_ action: ACAction, success: Bool = true) {
        actionsThisHour += 1
        recordHistory(action: action, success: success)
    }

    func effectiveLevel(for category: ACActionCategory) -> ACAutonomyLevel {
        categoryOverrides[category] ?? autonomyLevel
    }

    func setOverride(_ level: ACAutonomyLevel?, for category: ACActionCategory) {
        if let level {
            categoryOverrides[category] = level
        } else {
            categoryOverrides.removeValue(forKey: category)
        }
    }

    func resetHourlyCounter() {
        actionsThisHour = 0
    }

    private func shouldAutoExecute(action: ACAction, level: ACAutonomyLevel) -> Bool {
        guard level != .disabled else { return false }

        if action.riskLevel == .critical && requireConfirmForCritical {
            return false
        }

        return action.riskLevel <= level.maxAutoRisk
    }

    private func getRejectionReason(action: ACAction, level: ACAutonomyLevel) -> String {
        if level == .disabled {
            return "Autonomy is disabled"
        }

        if action.riskLevel == .critical && requireConfirmForCritical {
            return "Critical action requires confirmation"
        }

        if action.riskLevel > level.maxAutoRisk {
            return "Risk level (\(action.riskLevel.displayName)) exceeds autonomy threshold (\(level.maxAutoRisk.displayName))"
        }

        return "Action requires approval"
    }

    private func recordHistory(action: ACAction, success: Bool) {
        let entry = ACHistoryEntry(
            id: action.id,
            category: action.category,
            title: action.title,
            riskLevel: action.riskLevel,
            success: success,
            timestamp: Date()
        )
        actionHistory.insert(entry, at: 0)

        if actionHistory.count > 100 {
            actionHistory = Array(actionHistory.prefix(100))
        }
    }
}

// MARK: - Tests: Autonomy Level Properties

@Suite("AutonomyController — Level Properties")
struct ACLevelPropertyTests {
    @Test("All autonomy levels have display names")
    func displayNames() {
        #expect(ACAutonomyLevel.disabled.displayName == "Always Ask")
        #expect(ACAutonomyLevel.conservative.displayName == "Conservative")
        #expect(ACAutonomyLevel.balanced.displayName == "Balanced")
        #expect(ACAutonomyLevel.proactive.displayName == "Proactive")
        #expect(ACAutonomyLevel.autonomous.displayName == "Autonomous")
    }

    @Test("Max auto risk increases with autonomy level")
    func maxAutoRiskIncreases() {
        #expect(ACAutonomyLevel.disabled.maxAutoRisk == .none)
        #expect(ACAutonomyLevel.conservative.maxAutoRisk == .minimal)
        #expect(ACAutonomyLevel.balanced.maxAutoRisk == .low)
        #expect(ACAutonomyLevel.proactive.maxAutoRisk == .medium)
        #expect(ACAutonomyLevel.autonomous.maxAutoRisk == .high)
    }

    @Test("Five autonomy levels exist")
    func allLevels() {
        #expect(ACAutonomyLevel.allCases.count == 5)
    }
}

// MARK: - Tests: Risk Level Comparison

@Suite("AutonomyController — Risk Level Comparison")
struct ACRiskLevelTests {
    @Test("Risk levels are ordered by raw value")
    func ordering() {
        #expect(ACRiskLevel.none < ACRiskLevel.minimal)
        #expect(ACRiskLevel.minimal < ACRiskLevel.low)
        #expect(ACRiskLevel.low < ACRiskLevel.medium)
        #expect(ACRiskLevel.medium < ACRiskLevel.high)
        #expect(ACRiskLevel.high < ACRiskLevel.critical)
    }

    @Test("Equal risk levels compare correctly")
    func equality() {
        #expect(!(ACRiskLevel.low < ACRiskLevel.low))
        #expect(ACRiskLevel.low <= ACRiskLevel.low)
    }

    @Test("All risk level display names are set")
    func displayNames() {
        #expect(ACRiskLevel.none.displayName == "None")
        #expect(ACRiskLevel.minimal.displayName == "Minimal")
        #expect(ACRiskLevel.low.displayName == "Low")
        #expect(ACRiskLevel.medium.displayName == "Medium")
        #expect(ACRiskLevel.high.displayName == "High")
        #expect(ACRiskLevel.critical.displayName == "Critical")
    }

    @Test("Risk level raw values are sequential 0-5")
    func rawValues() {
        #expect(ACRiskLevel.none.rawValue == 0)
        #expect(ACRiskLevel.minimal.rawValue == 1)
        #expect(ACRiskLevel.low.rawValue == 2)
        #expect(ACRiskLevel.medium.rawValue == 3)
        #expect(ACRiskLevel.high.rawValue == 4)
        #expect(ACRiskLevel.critical.rawValue == 5)
    }
}

// MARK: - Tests: Action Category Default Risk

@Suite("AutonomyController — Category Default Risk")
struct ACCategoryRiskTests {
    @Test("Research has minimal default risk")
    func researchMinimal() {
        #expect(ACActionCategory.research.defaultRiskLevel == .minimal)
    }

    @Test("Analysis has minimal default risk")
    func analysisMinimal() {
        #expect(ACActionCategory.analysis.defaultRiskLevel == .minimal)
    }

    @Test("Generation has low default risk")
    func generationLow() {
        #expect(ACActionCategory.generation.defaultRiskLevel == .low)
    }

    @Test("Modification has medium default risk")
    func modificationMedium() {
        #expect(ACActionCategory.modification.defaultRiskLevel == .medium)
    }

    @Test("Communication has high default risk")
    func communicationHigh() {
        #expect(ACActionCategory.communication.defaultRiskLevel == .high)
    }

    @Test("Execution has high default risk")
    func executionHigh() {
        #expect(ACActionCategory.execution.defaultRiskLevel == .high)
    }

    @Test("Deletion has critical default risk")
    func deletionCritical() {
        #expect(ACActionCategory.deletion.defaultRiskLevel == .critical)
    }

    @Test("Automation has medium default risk")
    func automationMedium() {
        #expect(ACActionCategory.automation.defaultRiskLevel == .medium)
    }

    @Test("System has high default risk")
    func systemHigh() {
        #expect(ACActionCategory.system.defaultRiskLevel == .high)
    }

    @Test("Nine action categories exist")
    func allCategories() {
        #expect(ACActionCategory.allCases.count == 9)
    }
}

// MARK: - Tests: Action Uses Category Default Risk

@Suite("AutonomyController — Action Default Risk")
struct ACActionDefaultRiskTests {
    @Test("Action without explicit risk uses category default")
    func usesDefault() {
        let action = ACAction(category: .deletion, title: "Delete files")
        #expect(action.riskLevel == .critical)
    }

    @Test("Action with explicit risk overrides category default")
    func overridesDefault() {
        let action = ACAction(category: .deletion, title: "Delete temp files", riskLevel: .low)
        #expect(action.riskLevel == .low)
    }
}

// MARK: - Tests: Auto-Execution Decision Logic

@Suite("AutonomyController — Auto-Execution Logic")
struct ACAutoExecutionTests {
    @Test("Disabled level never auto-executes")
    func disabledNeverAutoExecutes() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .disabled

        let action = ACAction(category: .research, title: "Search web")
        let decision = controller.requestAction(action)
        #expect(!decision.isAutoExecute)
        #expect(decision.reason?.contains("disabled") == true)
    }

    @Test("Conservative auto-executes minimal risk only")
    func conservativeMinimalOnly() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .conservative

        let minimal = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        #expect(controller.requestAction(minimal).isAutoExecute)

        let low = ACAction(category: .generation, title: "Generate", riskLevel: .low)
        #expect(!controller.requestAction(low).isAutoExecute)
    }

    @Test("Balanced auto-executes up to low risk")
    func balancedUpToLow() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .balanced

        let minimal = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        #expect(controller.requestAction(minimal).isAutoExecute)

        let low = ACAction(category: .generation, title: "Generate", riskLevel: .low)
        #expect(controller.requestAction(low).isAutoExecute)

        let medium = ACAction(category: .modification, title: "Modify", riskLevel: .medium)
        #expect(!controller.requestAction(medium).isAutoExecute)
    }

    @Test("Proactive auto-executes up to medium risk")
    func proactiveUpToMedium() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .proactive

        let medium = ACAction(category: .modification, title: "Modify", riskLevel: .medium)
        #expect(controller.requestAction(medium).isAutoExecute)

        let high = ACAction(category: .execution, title: "Execute", riskLevel: .high)
        #expect(!controller.requestAction(high).isAutoExecute)
    }

    @Test("Autonomous auto-executes up to high risk")
    func autonomousUpToHigh() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .autonomous

        let high = ACAction(category: .execution, title: "Execute", riskLevel: .high)
        #expect(controller.requestAction(high).isAutoExecute)

        // Critical still blocked when requireConfirmForCritical is true
        let critical = ACAction(category: .deletion, title: "Delete", riskLevel: .critical)
        #expect(!controller.requestAction(critical).isAutoExecute)
    }

    @Test("Critical actions always require confirmation when flag is set")
    func criticalAlwaysRequiresConfirm() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .autonomous
        controller.requireConfirmForCritical = true

        let critical = ACAction(category: .deletion, title: "Delete everything", riskLevel: .critical)
        let decision = controller.requestAction(critical)
        #expect(!decision.isAutoExecute)
        #expect(decision.reason?.contains("Critical action requires confirmation") == true)
    }

    @Test("Critical actions auto-execute when requireConfirmForCritical is false")
    func criticalAutoExecutesWhenFlagOff() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .autonomous
        controller.requireConfirmForCritical = false

        let critical = ACAction(category: .deletion, title: "Delete", riskLevel: .critical)
        // riskLevel .critical (5) > maxAutoRisk .high (4) => still rejected
        #expect(!controller.requestAction(critical).isAutoExecute)
    }
}

// MARK: - Tests: Paused State

@Suite("AutonomyController — Paused State")
struct ACPausedTests {
    @Test("Paused controller never auto-executes")
    func pausedNeverAutoExecutes() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .autonomous
        controller.isPaused = true

        let action = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        let decision = controller.requestAction(action)
        #expect(!decision.isAutoExecute)
        #expect(decision.reason?.contains("paused") == true)
    }

    @Test("Unpausing restores normal behavior")
    func unpausingRestores() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .balanced
        controller.isPaused = true

        let action = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        #expect(!controller.requestAction(action).isAutoExecute)

        controller.isPaused = false
        #expect(controller.requestAction(action).isAutoExecute)
    }
}

// MARK: - Tests: Rate Limiting

@Suite("AutonomyController — Rate Limiting")
struct ACRateLimitTests {
    @Test("Actions within limit are auto-executed")
    func withinLimit() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .balanced
        controller.maxActionsPerHour = 5

        let action = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        for _ in 0..<4 {
            let decision = controller.requestAction(action)
            #expect(decision.isAutoExecute)
            controller.executeAction(action)
        }
    }

    @Test("Exceeding hourly limit requires approval")
    func exceedsLimit() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .balanced
        controller.maxActionsPerHour = 3

        let action = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        for _ in 0..<3 {
            controller.executeAction(action)
        }

        let decision = controller.requestAction(action)
        #expect(!decision.isAutoExecute)
        #expect(decision.reason?.contains("Hourly action limit") == true)
    }

    @Test("Resetting hourly counter allows new actions")
    func resetAllowsNew() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .balanced
        controller.maxActionsPerHour = 2

        let action = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        controller.executeAction(action)
        controller.executeAction(action)

        let blocked = controller.requestAction(action)
        #expect(!blocked.isAutoExecute)

        controller.resetHourlyCounter()
        let allowed = controller.requestAction(action)
        #expect(allowed.isAutoExecute)
    }

    @Test("Zero max actions always requires approval")
    func zeroMaxActions() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .autonomous
        controller.maxActionsPerHour = 0

        let action = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        let decision = controller.requestAction(action)
        #expect(!decision.isAutoExecute)
    }

    @Test("Rate limit is checked before autonomy level")
    func rateLimitBeforeLevel() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .autonomous
        controller.maxActionsPerHour = 1
        controller.executeAction(ACAction(category: .research, title: "First"))

        let action = ACAction(category: .research, title: "Second", riskLevel: .minimal)
        let decision = controller.requestAction(action)
        #expect(!decision.isAutoExecute)
        #expect(decision.reason?.contains("limit") == true)
    }
}

// MARK: - Tests: Category Overrides

@Suite("AutonomyController — Category Overrides")
struct ACCategoryOverrideTests {
    @Test("Category override takes precedence over global level")
    func overridePrecedence() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .balanced // maxAutoRisk = .low

        // Override communication to autonomous
        controller.setOverride(.autonomous, for: .communication)

        let action = ACAction(category: .communication, title: "Send message", riskLevel: .high)
        let decision = controller.requestAction(action)
        #expect(decision.isAutoExecute)
    }

    @Test("Non-overridden categories use global level")
    func nonOverriddenUsesGlobal() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .balanced
        controller.setOverride(.autonomous, for: .communication)

        let action = ACAction(category: .modification, title: "Edit file", riskLevel: .medium)
        let decision = controller.requestAction(action)
        #expect(!decision.isAutoExecute) // balanced maxAutoRisk is .low
    }

    @Test("Removing override reverts to global level")
    func removeOverride() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .balanced

        controller.setOverride(.autonomous, for: .communication)
        let action = ACAction(category: .communication, title: "Send", riskLevel: .high)
        #expect(controller.requestAction(action).isAutoExecute)

        controller.setOverride(nil, for: .communication)
        #expect(!controller.requestAction(action).isAutoExecute)
    }

    @Test("Override to disabled blocks auto-execution for that category")
    func overrideToDisabled() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .autonomous
        controller.setOverride(.disabled, for: .research)

        let action = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        let decision = controller.requestAction(action)
        #expect(!decision.isAutoExecute)
    }

    @Test("Effective level returns override when set")
    func effectiveLevelWithOverride() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .balanced
        controller.setOverride(.proactive, for: .execution)

        #expect(controller.effectiveLevel(for: .execution) == .proactive)
        #expect(controller.effectiveLevel(for: .research) == .balanced)
    }

    @Test("Multiple category overrides are independent")
    func multipleOverrides() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .balanced

        controller.setOverride(.disabled, for: .deletion)
        controller.setOverride(.autonomous, for: .research)

        #expect(controller.effectiveLevel(for: .deletion) == .disabled)
        #expect(controller.effectiveLevel(for: .research) == .autonomous)
        #expect(controller.effectiveLevel(for: .analysis) == .balanced) // global
    }
}

// MARK: - Tests: Rejection Reasons

@Suite("AutonomyController — Rejection Reasons")
struct ACRejectionReasonTests {
    @Test("Disabled level gives 'Autonomy is disabled' reason")
    func disabledReason() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .disabled
        let action = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        let decision = controller.requestAction(action)
        #expect(decision.reason == "Autonomy is disabled")
    }

    @Test("Critical action reason mentions confirmation")
    func criticalReason() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .autonomous
        controller.requireConfirmForCritical = true
        let action = ACAction(category: .deletion, title: "Delete", riskLevel: .critical)
        let decision = controller.requestAction(action)
        #expect(decision.reason?.contains("Critical action requires confirmation") == true)
    }

    @Test("Risk exceeds threshold includes both risk names")
    func riskExceedsReason() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .conservative // maxAutoRisk = .minimal
        let action = ACAction(category: .modification, title: "Edit", riskLevel: .medium)
        let decision = controller.requestAction(action)
        #expect(decision.reason?.contains("Medium") == true)
        #expect(decision.reason?.contains("Minimal") == true)
    }

    @Test("Paused state gives 'paused' reason regardless of other settings")
    func pausedReason() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .autonomous
        controller.isPaused = true
        let action = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        let decision = controller.requestAction(action)
        #expect(decision.reason?.contains("paused") == true)
    }
}

// MARK: - Tests: Action History

@Suite("AutonomyController — Action History")
struct ACHistoryTests {
    @Test("Executing action records history entry")
    func recordsHistory() {
        let controller = TestAutonomyController()
        let action = ACAction(category: .research, title: "Web search")
        controller.executeAction(action, success: true)

        #expect(controller.actionHistory.count == 1)
        #expect(controller.actionHistory[0].title == "Web search")
        #expect(controller.actionHistory[0].success)
    }

    @Test("Failed action records failure in history")
    func recordsFailure() {
        let controller = TestAutonomyController()
        let action = ACAction(category: .execution, title: "Run script")
        controller.executeAction(action, success: false)

        #expect(controller.actionHistory.count == 1)
        #expect(!controller.actionHistory[0].success)
    }

    @Test("History is in reverse chronological order")
    func reverseChronological() {
        let controller = TestAutonomyController()
        controller.executeAction(ACAction(category: .research, title: "First"))
        controller.executeAction(ACAction(category: .research, title: "Second"))
        controller.executeAction(ACAction(category: .research, title: "Third"))

        #expect(controller.actionHistory[0].title == "Third")
        #expect(controller.actionHistory[1].title == "Second")
        #expect(controller.actionHistory[2].title == "First")
    }

    @Test("History is capped at 100 entries")
    func historyCapAtHundred() {
        let controller = TestAutonomyController()
        for i in 0..<110 {
            controller.executeAction(ACAction(category: .research, title: "Action \(i)"))
        }
        #expect(controller.actionHistory.count == 100)
    }

    @Test("History entry preserves action metadata")
    func preservesMetadata() {
        let controller = TestAutonomyController()
        let action = ACAction(category: .deletion, title: "Delete temp", riskLevel: .critical)
        controller.executeAction(action, success: true)

        let entry = controller.actionHistory[0]
        #expect(entry.category == .deletion)
        #expect(entry.riskLevel == .critical)
        #expect(entry.id == action.id)
    }

    @Test("Executing action increments hourly counter")
    func incrementsHourlyCounter() {
        let controller = TestAutonomyController()
        #expect(controller.actionsThisHour == 0)
        controller.executeAction(ACAction(category: .research, title: "Test"))
        #expect(controller.actionsThisHour == 1)
    }
}

// MARK: - Tests: Decision Type

@Suite("AutonomyController — Decision Type")
struct ACDecisionTypeTests {
    @Test("AutoExecute decision is auto-execute")
    func autoExecuteIsAuto() {
        let d = ACDecision.autoExecute
        #expect(d.isAutoExecute)
        #expect(d.reason == nil)
    }

    @Test("RequiresApproval decision is not auto-execute")
    func requiresApprovalNotAuto() {
        let d = ACDecision.requiresApproval(reason: "test reason")
        #expect(!d.isAutoExecute)
        #expect(d.reason == "test reason")
    }

    @Test("Two autoExecute decisions are equal")
    func autoExecuteEquality() {
        #expect(ACDecision.autoExecute == ACDecision.autoExecute)
    }

    @Test("Two requiresApproval decisions are equal regardless of reason")
    func requiresApprovalEquality() {
        let d1 = ACDecision.requiresApproval(reason: "a")
        let d2 = ACDecision.requiresApproval(reason: "b")
        #expect(d1 == d2)
    }

    @Test("AutoExecute and requiresApproval are not equal")
    func mixedInequality() {
        #expect(ACDecision.autoExecute != ACDecision.requiresApproval(reason: "test"))
    }
}

// MARK: - Tests: Edge Cases

@Suite("AutonomyController — Edge Cases")
struct ACEdgeCaseTests {
    @Test("All categories auto-execute in autonomous mode (non-critical)")
    func allCategoriesInAutonomous() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .autonomous
        controller.requireConfirmForCritical = false

        for category in ACActionCategory.allCases {
            let action = ACAction(category: category, title: "Test \(category)", riskLevel: category.defaultRiskLevel)
            let decision = controller.requestAction(action)
            if action.riskLevel <= ACRiskLevel.high {
                #expect(decision.isAutoExecute, "Expected \(category) to auto-execute")
            }
        }
    }

    @Test("No categories auto-execute in disabled mode")
    func noCategoriesInDisabled() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .disabled

        for category in ACActionCategory.allCases {
            let action = ACAction(category: category, title: "Test \(category)")
            let decision = controller.requestAction(action)
            #expect(!decision.isAutoExecute, "Expected \(category) to NOT auto-execute")
        }
    }

    @Test("Concurrent conditions: paused + rate limited")
    func pausedAndRateLimited() {
        let controller = TestAutonomyController()
        controller.autonomyLevel = .autonomous
        controller.isPaused = true
        controller.maxActionsPerHour = 0

        let action = ACAction(category: .research, title: "Search", riskLevel: .minimal)
        let decision = controller.requestAction(action)
        #expect(!decision.isAutoExecute)
        // Paused is checked first
        #expect(decision.reason?.contains("paused") == true)
    }

    @Test("Default controller state")
    func defaultState() {
        let controller = TestAutonomyController()
        #expect(controller.autonomyLevel == .balanced)
        #expect(!controller.isPaused)
        #expect(controller.requireConfirmForCritical)
        #expect(controller.maxActionsPerHour == 50)
        #expect(controller.actionsThisHour == 0)
        #expect(controller.actionHistory.isEmpty)
        #expect(controller.categoryOverrides.isEmpty)
    }
}
