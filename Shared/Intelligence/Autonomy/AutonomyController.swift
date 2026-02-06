//
//  AutonomyController.swift
//  Thea
//
//  Autonomous Task Completion System - manages THEA's autonomy levels
//  and automatic task execution based on user preferences.
//
//  Copyright 2026. All rights reserved.
//

import Foundation
import SwiftUI
import os.log

// MARK: - THEA Autonomy Level

/// Defines how autonomous THEA should be for different actions
public enum THEATHEAAutonomyLevel: String, Codable, Sendable, CaseIterable {
    case disabled       // Always ask, never auto-complete
    case conservative   // Only auto-complete very safe actions
    case balanced       // Auto-complete medium-risk actions
    case proactive      // Auto-complete most actions except high-risk
    case autonomous     // Maximum autonomy, minimal confirmations

    var displayName: String {
        switch self {
        case .disabled: return "Always Ask"
        case .conservative: return "Conservative"
        case .balanced: return "Balanced"
        case .proactive: return "Proactive"
        case .autonomous: return "Autonomous"
        }
    }

    var description: String {
        switch self {
        case .disabled:
            return "THEA will always ask for confirmation before taking any action."
        case .conservative:
            return "Auto-complete only safe, reversible actions. Ask for most things."
        case .balanced:
            return "Auto-complete routine tasks. Ask for anything that modifies data."
        case .proactive:
            return "Auto-complete most actions. Only ask for high-risk operations."
        case .autonomous:
            return "Maximum autonomy. THEA acts independently on your behalf."
        }
    }

    var icon: String {
        switch self {
        case .disabled: return "hand.raised.fill"
        case .conservative: return "shield.checkered"
        case .balanced: return "scale.3d"
        case .proactive: return "hare.fill"
        case .autonomous: return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .disabled: return .gray
        case .conservative: return .blue
        case .balanced: return .green
        case .proactive: return .orange
        case .autonomous: return .purple
        }
    }

    /// Maximum allowed risk level for auto-execution
    var maxAutoRisk: THEARiskLevel {
        switch self {
        case .disabled: return .none
        case .conservative: return .minimal
        case .balanced: return .low
        case .proactive: return .medium
        case .autonomous: return .high
        }
    }
}

// MARK: - Action Risk Level

/// Risk classification for autonomous actions
public enum THEARiskLevel: Int, Codable, Sendable, Comparable {
    case none = 0       // No action
    case minimal = 1    // Read-only, no side effects
    case low = 2        // Minor changes, easily reversible
    case medium = 3     // Moderate changes, may need manual reversal
    case high = 4       // Significant changes, difficult to reverse
    case critical = 5   // Irreversible actions (delete, send, publish)

    public static func < (lhs: THEARiskLevel, rhs: THEARiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

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

    var color: Color {
        switch self {
        case .none: return .secondary
        case .minimal: return .green
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Action Category

/// Categories of actions THEA can perform
public enum THEAActionCategory: String, Codable, Sendable, CaseIterable {
    case research       // Web search, reading
    case analysis       // Code review, data analysis
    case generation     // Creating content, code
    case modification   // Editing files, settings
    case communication  // Sending messages, emails
    case execution      // Running code, scripts
    case deletion       // Removing files, data
    case automation     // Workflow automation
    case system         // System settings, preferences

    var icon: String {
        switch self {
        case .research: return "magnifyingglass"
        case .analysis: return "waveform.and.magnifyingglass"
        case .generation: return "sparkles"
        case .modification: return "pencil"
        case .communication: return "envelope"
        case .execution: return "play.fill"
        case .deletion: return "trash"
        case .automation: return "gearshape.2"
        case .system: return "gear"
        }
    }

    /// Default risk level for this category
    var defaultRiskLevel: THEARiskLevel {
        switch self {
        case .research: return .minimal
        case .analysis: return .minimal
        case .generation: return .low
        case .modification: return .medium
        case .communication: return .high
        case .execution: return .high
        case .deletion: return .critical
        case .automation: return .medium
        case .system: return .high
        }
    }
}

// MARK: - Autonomous Action

/// Represents an action THEA wants to perform autonomously
public struct AutonomousAction: Identifiable, Sendable {
    public let id: UUID
    public let category: THEAActionCategory
    public let title: String
    public let description: String
    public let riskLevel: THEARiskLevel
    public let requiredApprovals: [ApprovalType]
    public let execute: @Sendable () async throws -> ActionResult
    public let rollback: (@Sendable () async throws -> Void)?
    public let createdAt: Date

    public enum ApprovalType: String, Sendable {
        case userConfirmation
        case biometricAuth
        case timeDelay
        case none
    }

    public struct ActionResult: Sendable {
        public let success: Bool
        public let message: String
        public let data: [String: String]?
        public let canUndo: Bool

        public init(success: Bool, message: String, data: [String: String]? = nil, canUndo: Bool = false) {
            self.success = success
            self.message = message
            self.data = data
            self.canUndo = canUndo
        }
    }

    public init(
        id: UUID = UUID(),
        category: THEAActionCategory,
        title: String,
        description: String,
        riskLevel: THEARiskLevel? = nil,
        requiredApprovals: [ApprovalType] = [],
        execute: @escaping @Sendable () async throws -> ActionResult,
        rollback: (@Sendable () async throws -> Void)? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.description = description
        self.riskLevel = riskLevel ?? category.defaultRiskLevel
        self.requiredApprovals = requiredApprovals
        self.execute = execute
        self.rollback = rollback
        self.createdAt = Date()
    }
}

// MARK: - Pending Action

/// An action awaiting user approval
public struct THEAPendingAction: Identifiable {
    public let id: UUID
    public let action: AutonomousAction
    public let reason: String
    public var status: Status

    public enum Status: String {
        case pending
        case approved
        case rejected
        case expired
        case executing
        case completed
        case failed
    }

    public init(action: AutonomousAction, reason: String) {
        self.id = action.id
        self.action = action
        self.reason = reason
        self.status = .pending
    }
}

// MARK: - Autonomy Controller

/// Controls THEA's autonomous behavior and task execution
@MainActor
public final class AutonomyController: ObservableObject {
    public static let shared = AutonomyController()

    private let logger = Logger(subsystem: "ai.thea.app", category: "Autonomy")

    // MARK: - Published State

    /// Global autonomy level
    @Published public var autonomyLevel: THEAAutonomyLevel = .balanced {
        didSet { saveSettings() }
    }

    /// Per-category overrides
    @Published public var categoryOverrides: [THEAActionCategory: THEAAutonomyLevel] = [:] {
        didSet { saveSettings() }
    }

    /// Pending actions requiring approval
    @Published public private(set) var pendingActions: [THEAPendingAction] = []

    /// Recently executed actions (for undo)
    @Published public private(set) var recentActions: [ExecutedAction] = []

    /// Whether autonomy is temporarily paused
    @Published public var isPaused: Bool = false

    /// Action history
    @Published public private(set) var actionHistory: [ActionHistoryEntry] = []

    // MARK: - Settings

    /// Require extra confirmation for critical actions even in autonomous mode
    @Published public var requireConfirmForCritical: Bool = true {
        didSet { saveSettings() }
    }

    /// Time delay before executing high-risk actions (seconds)
    @Published public var highRiskDelay: TimeInterval = 5.0 {
        didSet { saveSettings() }
    }

    /// Maximum number of auto-actions per hour
    @Published public var maxActionsPerHour: Int = 50 {
        didSet { saveSettings() }
    }

    // MARK: - Tracking

    private var actionsThisHour: Int = 0
    private var hourResetTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        loadSettings()
        startHourlyReset()
        logger.info("AutonomyController initialized with level: \(self.autonomyLevel.rawValue)")
    }

    // MARK: - Public API

    /// Request an autonomous action
    public func requestAction(_ action: AutonomousAction) async -> ActionDecision {
        guard !isPaused else {
            return .requiresApproval(reason: "Autonomy is paused")
        }

        // Check rate limit
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

    /// Execute an action (either auto or after approval)
    public func executeAction(_ action: AutonomousAction) async -> AutonomousAction.ActionResult {
        actionsThisHour += 1

        // Log execution
        logger.info("Executing action: \(action.title) [Risk: \(action.riskLevel.displayName)]")

        do {
            let result = try await action.execute()

            // Track for undo if possible
            if result.canUndo, let rollback = action.rollback {
                recentActions.append(ExecutedAction(
                    action: action,
                    result: result,
                    rollback: rollback
                ))
                // Keep only last 10 undoable actions
                if recentActions.count > 10 {
                    recentActions.removeFirst()
                }
            }

            // Record in history
            recordHistory(action: action, result: result)

            return result
        } catch {
            logger.error("Action failed: \(error.localizedDescription)")
            let failedResult = AutonomousAction.ActionResult(
                success: false,
                message: "Failed: \(error.localizedDescription)"
            )
            recordHistory(action: action, result: failedResult)
            return failedResult
        }
    }

    /// Queue an action for approval
    public func queueForApproval(_ action: AutonomousAction, reason: String) {
        let pending = THEAPendingAction(action: action, reason: reason)
        pendingActions.append(pending)
        logger.info("Queued action for approval: \(action.title)")
    }

    /// Approve a pending action
    public func approveAction(_ pendingId: UUID) async {
        guard let index = pendingActions.firstIndex(where: { $0.id == pendingId }) else { return }
        pendingActions[index].status = .approved

        let action = pendingActions[index].action
        pendingActions[index].status = .executing

        let result = await executeAction(action)
        pendingActions[index].status = result.success ? .completed : .failed

        // Remove after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.pendingActions.removeAll { $0.id == pendingId }
        }
    }

    /// Reject a pending action
    public func rejectAction(_ pendingId: UUID) {
        if let index = pendingActions.firstIndex(where: { $0.id == pendingId }) {
            pendingActions[index].status = .rejected
            logger.info("Rejected action: \(self.pendingActions[index].action.title)")

            // Remove after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.pendingActions.removeAll { $0.id == pendingId }
            }
        }
    }

    /// Undo the last action if possible
    public func undoLastAction() async -> Bool {
        guard let last = recentActions.popLast() else { return false }

        do {
            try await last.rollback()
            logger.info("Undid action: \(last.action.title)")
            return true
        } catch {
            logger.error("Failed to undo: \(error.localizedDescription)")
            return false
        }
    }

    /// Get effective autonomy level for a category
    public func effectiveLevel(for category: THEAActionCategory) -> THEAAutonomyLevel {
        categoryOverrides[category] ?? autonomyLevel
    }

    /// Set category-specific override
    public func setOverride(_ level: THEAAutonomyLevel?, for category: THEAActionCategory) {
        if let level {
            categoryOverrides[category] = level
        } else {
            categoryOverrides.removeValue(forKey: category)
        }
    }

    // MARK: - Private Methods

    private func shouldAutoExecute(action: AutonomousAction, level: THEAAutonomyLevel) -> Bool {
        // Never auto-execute if disabled
        guard level != .disabled else { return false }

        // Critical actions require confirmation if setting is enabled
        if action.riskLevel == .critical && requireConfirmForCritical {
            return false
        }

        // Check if action risk is within acceptable level
        return action.riskLevel <= level.maxAutoRisk
    }

    private func getRejectionReason(action: AutonomousAction, level: THEAAutonomyLevel) -> String {
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

    private func recordHistory(action: AutonomousAction, result: AutonomousAction.ActionResult) {
        let entry = ActionHistoryEntry(
            id: action.id,
            category: action.category,
            title: action.title,
            riskLevel: action.riskLevel,
            success: result.success,
            timestamp: Date()
        )
        actionHistory.insert(entry, at: 0)

        // Keep last 100 entries
        if actionHistory.count > 100 {
            actionHistory = Array(actionHistory.prefix(100))
        }

        saveHistory()
    }

    private func startHourlyReset() {
        hourResetTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
                await MainActor.run {
                    self.actionsThisHour = 0
                }
            }
        }
    }

    // MARK: - Persistence

    private func saveSettings() {
        UserDefaults.standard.set(autonomyLevel.rawValue, forKey: "thea.autonomy.level")
        UserDefaults.standard.set(requireConfirmForCritical, forKey: "thea.autonomy.confirmCritical")
        UserDefaults.standard.set(highRiskDelay, forKey: "thea.autonomy.highRiskDelay")
        UserDefaults.standard.set(maxActionsPerHour, forKey: "thea.autonomy.maxPerHour")

        // Save category overrides
        let overrideData = categoryOverrides.reduce(into: [String: String]()) { result, pair in
            result[pair.key.rawValue] = pair.value.rawValue
        }
        if let encoded = try? JSONEncoder().encode(overrideData) {
            UserDefaults.standard.set(encoded, forKey: "thea.autonomy.overrides")
        }
    }

    private func loadSettings() {
        if let levelStr = UserDefaults.standard.string(forKey: "thea.autonomy.level"),
           let level = THEAAutonomyLevel(rawValue: levelStr) {
            autonomyLevel = level
        }

        requireConfirmForCritical = UserDefaults.standard.object(forKey: "thea.autonomy.confirmCritical") as? Bool ?? true
        highRiskDelay = UserDefaults.standard.double(forKey: "thea.autonomy.highRiskDelay")
        if highRiskDelay == 0 { highRiskDelay = 5.0 }

        maxActionsPerHour = UserDefaults.standard.integer(forKey: "thea.autonomy.maxPerHour")
        if maxActionsPerHour == 0 { maxActionsPerHour = 50 }

        // Load category overrides
        if let data = UserDefaults.standard.data(forKey: "thea.autonomy.overrides"),
           let overrideData = try? JSONDecoder().decode([String: String].self, from: data) {
            categoryOverrides = overrideData.reduce(into: [:]) { result, pair in
                if let category = THEAActionCategory(rawValue: pair.key),
                   let level = THEAAutonomyLevel(rawValue: pair.value) {
                    result[category] = level
                }
            }
        }

        loadHistory()
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(actionHistory) {
            UserDefaults.standard.set(encoded, forKey: "thea.autonomy.history")
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "thea.autonomy.history"),
           let decoded = try? JSONDecoder().decode([ActionHistoryEntry].self, from: data) {
            actionHistory = decoded
        }
    }
}

// MARK: - Supporting Types

public enum ActionDecision: Sendable {
    case autoExecute
    case requiresApproval(reason: String)
}

public struct ExecutedAction {
    let action: AutonomousAction
    let result: AutonomousAction.ActionResult
    let rollback: @Sendable () async throws -> Void
}

public struct ActionHistoryEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let category: THEAActionCategory
    public let title: String
    public let riskLevel: THEARiskLevel
    public let success: Bool
    public let timestamp: Date
}

// MARK: - Autonomy Settings View

/// UI for configuring autonomy settings
public struct THEAAutonomySettingsView: View {
    @ObservedObject var controller = AutonomyController.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                autonomyLevelPicker
                    .padding(.vertical, 8)
            } header: {
                Text("Global Autonomy Level")
            } footer: {
                Text(controller.autonomyLevel.description)
            }

            Section("Category Overrides") {
                ForEach(THEAActionCategory.allCases, id: \.self) { category in
                    categoryOverrideRow(category)
                }
            }

            Section("Safety Settings") {
                Toggle("Require confirmation for critical actions", isOn: $controller.requireConfirmForCritical)

                HStack {
                    Text("High-risk delay")
                    Spacer()
                    Text("\(Int(controller.highRiskDelay))s")
                        .foregroundStyle(.secondary)
                    Stepper("", value: $controller.highRiskDelay, in: 0...30, step: 1)
                        .labelsHidden()
                }

                HStack {
                    Text("Max actions per hour")
                    Spacer()
                    Text("\(controller.maxActionsPerHour)")
                        .foregroundStyle(.secondary)
                    Stepper("", value: $controller.maxActionsPerHour, in: 10...100, step: 10)
                        .labelsHidden()
                }
            }

            if controller.isPaused {
                Section {
                    Button("Resume Autonomy") {
                        controller.isPaused = false
                    }
                    .foregroundStyle(.green)
                }
            } else {
                Section {
                    Button("Pause Autonomy") {
                        controller.isPaused = true
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Autonomy Settings")
    }

    private var autonomyLevelPicker: some View {
        VStack(spacing: 12) {
            ForEach(THEAAutonomyLevel.allCases, id: \.self) { level in
                THEAAutonomyLevelOption(
                    level: level,
                    isSelected: controller.autonomyLevel == level
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        controller.autonomyLevel = level
                    }
                }
            }
        }
    }

    private func categoryOverrideRow(_ category: THEAActionCategory) -> some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(category.rawValue.capitalized)

            Spacer()

            Menu {
                Button("Use Global") {
                    controller.setOverride(nil, for: category)
                }
                Divider()
                ForEach(THEAAutonomyLevel.allCases, id: \.self) { level in
                    Button {
                        controller.setOverride(level, for: category)
                    } label: {
                        HStack {
                            Text(level.displayName)
                            if controller.categoryOverrides[category] == level {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if let override = controller.categoryOverrides[category] {
                        Text(override.displayName)
                            .foregroundStyle(override.color)
                    } else {
                        Text("Global")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Autonomy Level Option

private struct THEAAutonomyLevelOption: View {
    let level: THEAAutonomyLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: level.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(level.color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(level.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(level.color)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? level.color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? level.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pending Action Card

/// UI for a pending action awaiting approval
public struct THEAPendingActionCard: View {
    let pending: THEAPendingAction
    let onApprove: () -> Void
    let onReject: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: pending.action.category.icon)
                    .foregroundStyle(pending.action.riskLevel.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pending.action.title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(pending.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                RiskBadge(level: pending.action.riskLevel)
            }

            Text(pending.action.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Reject") {
                    onReject()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)

                Button("Approve") {
                    onApprove()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(pending.action.riskLevel.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Risk Badge

private struct RiskBadge: View {
    let level: THEARiskLevel

    var body: some View {
        Text(level.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(level.color.opacity(0.2))
            .foregroundStyle(level.color)
            .clipShape(Capsule())
    }
}

// MARK: - Pending Actions View

/// Shows all pending actions awaiting approval
public struct THEAPendingActionsView: View {
    @ObservedObject var controller = AutonomyController.shared

    public init() {}

    public var body: some View {
        if !controller.pendingActions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.badge.questionmark")
                        .foregroundStyle(.orange)
                    Text("Pending Actions")
                        .font(.headline)
                    Spacer()
                    Text("\(controller.pendingActions.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }

                ForEach(controller.pendingActions) { pending in
                    THEAPendingActionCard(
                        pending: pending,
                        onApprove: {
                            Task {
                                await controller.approveAction(pending.id)
                            }
                        },
                        onReject: {
                            controller.rejectAction(pending.id)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
            .padding()
            .animation(.spring(response: 0.4), value: controller.pendingActions.count)
        }
    }
}

// MARK: - Preview

#Preview("Autonomy Settings") {
    NavigationStack {
        THEAAutonomySettingsView()
    }
}
