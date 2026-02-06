//
//  AutonomyPolicy.swift
//  Thea
//
//  Defines autonomy levels and trust scoring for AI actions.
//  Determines what actions Thea can take autonomously vs requiring confirmation.
//
//  Copyright 2026. All rights reserved.
//

import Combine
import Foundation
import os.log

// MARK: - Autonomy Level

/// Defines the level of autonomy Thea has for different action types
public enum AutonomyLevel: Int, Codable, Sendable, CaseIterable, Comparable {
    /// Always ask for confirmation
    case alwaysAsk = 0

    /// Ask for confirmation on first use, then remember preference
    case askOnce = 1

    /// Ask only for potentially destructive or expensive actions
    case cautious = 2

    /// Act autonomously for most actions, ask for high-risk only
    case confident = 3

    /// Full autonomy - only ask for critical/irreversible actions
    case autonomous = 4

    public static func < (lhs: AutonomyLevel, rhs: AutonomyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .alwaysAsk: "Always Ask"
        case .askOnce: "Ask Once"
        case .cautious: "Cautious"
        case .confident: "Confident"
        case .autonomous: "Autonomous"
        }
    }

    public var description: String {
        switch self {
        case .alwaysAsk:
            "Always ask for confirmation before taking any action"
        case .askOnce:
            "Ask once per action type, then remember your preference"
        case .cautious:
            "Act on safe operations, ask for potentially risky ones"
        case .confident:
            "Act autonomously on most tasks, ask only for high-risk actions"
        case .autonomous:
            "Full autonomy - only ask for critical or irreversible actions"
        }
    }
}

// MARK: - Action Category

/// Categories of actions with different risk levels
public enum ActionCategory: String, Codable, Sendable, CaseIterable {
    // Low risk - generally safe
    case read
    case search
    case analyze
    case summarize
    case explain

    // Medium risk - reversible but impactful
    case create
    case modify
    case organize
    case send
    case schedule

    // High risk - potentially destructive or costly
    case delete
    case purchase
    case publish
    case share
    case execute

    // Critical - irreversible or highly sensitive
    case deletePermenent
    case financialTransaction
    case accountChange
    case systemChange
    case externalAPI

    public var riskLevel: ActionRiskLevel {
        switch self {
        case .read, .search, .analyze, .summarize, .explain:
            return .low
        case .create, .modify, .organize, .send, .schedule:
            return .medium
        case .delete, .purchase, .publish, .share, .execute:
            return .high
        case .deletePermenent, .financialTransaction, .accountChange, .systemChange, .externalAPI:
            return .critical
        }
    }

    public var displayName: String {
        switch self {
        case .read: "Read"
        case .search: "Search"
        case .analyze: "Analyze"
        case .summarize: "Summarize"
        case .explain: "Explain"
        case .create: "Create"
        case .modify: "Modify"
        case .organize: "Organize"
        case .send: "Send"
        case .schedule: "Schedule"
        case .delete: "Delete"
        case .purchase: "Purchase"
        case .publish: "Publish"
        case .share: "Share"
        case .execute: "Execute"
        case .deletePermenent: "Permanent Delete"
        case .financialTransaction: "Financial Transaction"
        case .accountChange: "Account Change"
        case .systemChange: "System Change"
        case .externalAPI: "External API Call"
        }
    }
}

/// Risk levels for actions in autonomy context
public enum ActionRiskLevel: Int, Codable, Sendable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: ActionRiskLevel, rhs: ActionRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Minimum autonomy level required to act without confirmation
    public var minimumAutonomyForAutoAction: AutonomyLevel {
        switch self {
        case .low: .cautious
        case .medium: .confident
        case .high: .autonomous
        case .critical: .autonomous // Still requires confirmation even at autonomous
        }
    }
}

// MARK: - Trust Score

/// Represents trust earned through successful interactions
public struct AutonomyTrustScore: Codable, Sendable {
    /// Overall trust score (0.0 - 1.0)
    public var overall: Double

    /// Trust by action category
    public var byCategory: [ActionCategory: Double]

    /// Number of successful actions
    public var successfulActions: Int

    /// Number of failed or rejected actions
    public var failedActions: Int

    /// Number of user corrections
    public var corrections: Int

    /// Last updated timestamp
    public var lastUpdated: Date

    public init(
        overall: Double = 0.5,
        byCategory: [ActionCategory: Double] = [:],
        successfulActions: Int = 0,
        failedActions: Int = 0,
        corrections: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.overall = overall
        self.byCategory = byCategory
        self.successfulActions = successfulActions
        self.failedActions = failedActions
        self.corrections = corrections
        self.lastUpdated = lastUpdated
    }

    /// Get trust for a specific category (falls back to overall)
    public func trust(for category: ActionCategory) -> Double {
        byCategory[category] ?? overall
    }

    /// Calculate effective autonomy adjustment based on trust
    public func autonomyAdjustment() -> Int {
        if overall >= 0.9 && successfulActions >= 100 {
            return 1 // Can upgrade autonomy by 1 level
        } else if overall < 0.3 || corrections > successfulActions / 10 {
            return -1 // Should downgrade autonomy by 1 level
        }
        return 0
    }
}

// MARK: - Action Request

/// Represents a request for an action with context
public struct ActionRequest: Identifiable, Sendable {
    public let id: UUID
    public let category: ActionCategory
    public let description: String
    public let details: [String: String]
    public let estimatedImpact: String?
    public let isReversible: Bool
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        category: ActionCategory,
        description: String,
        details: [String: String] = [:],
        estimatedImpact: String? = nil,
        isReversible: Bool = true,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.description = description
        self.details = details
        self.estimatedImpact = estimatedImpact
        self.isReversible = isReversible
        self.timestamp = timestamp
    }
}

/// Result of an autonomy check
public enum AutonomyDecision: Sendable {
    case proceed
    case askConfirmation(reason: String)
    case deny(reason: String)

    public var canProceed: Bool {
        if case .proceed = self { return true }
        return false
    }

    public var requiresConfirmation: Bool {
        if case .askConfirmation = self { return true }
        return false
    }
}

// MARK: - Autonomy Policy Manager

/// Manages autonomy levels, trust scoring, and action decisions
@MainActor
public final class AutonomyPolicyManager: ObservableObject {
    public static let shared = AutonomyPolicyManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "AutonomyPolicy")

    // MARK: - Published State

    /// Global autonomy level
    @Published public var globalAutonomyLevel: AutonomyLevel = .cautious

    /// Per-category autonomy overrides
    @Published public var categoryOverrides: [ActionCategory: AutonomyLevel] = [:]

    /// Current trust score
    @Published public private(set) var trustScore: AutonomyTrustScore = AutonomyTrustScore()

    /// Actions that have been approved once (for askOnce mode)
    @Published public private(set) var approvedActionTypes: Set<String> = []

    /// Actions that have been denied (remembered to not ask again)
    @Published public private(set) var deniedActionTypes: Set<String> = []

    /// Recent action history
    @Published public private(set) var actionHistory: [ActionHistoryEntry] = []

    // MARK: - Cascading Trust

    /// Trust scores per conversation (for cascading trust)
    @Published public private(set) var conversationTrustScores: [UUID: ConversationTrust] = [:]

    /// Factor for inheriting trust from conversation (0.0-1.0)
    @Published public var cascadingTrustFactor: Double = 0.7

    /// Enable cascading trust from high-trust conversations
    @Published public var cascadingTrustEnabled: Bool = true

    // MARK: - Configuration

    /// Whether to use trust-based autonomy adjustment
    @Published public var useTrustAdjustment: Bool = true

    /// Maximum actions to keep in history
    @Published public var maxHistorySize: Int = 1000

    /// Whether to learn from user decisions
    @Published public var learningEnabled: Bool = true

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadState()
        logger.info("AutonomyPolicyManager initialized with level: \(self.globalAutonomyLevel.displayName)")
    }

    // MARK: - Public API

    /// Check if an action can proceed autonomously
    public func checkAutonomy(for request: ActionRequest) -> AutonomyDecision {
        let category = request.category
        let riskLevel = category.riskLevel

        // Get effective autonomy level for this category
        let baseLevel = categoryOverrides[category] ?? globalAutonomyLevel
        var effectiveLevel = baseLevel

        // Apply trust adjustment if enabled
        if useTrustAdjustment {
            let adjustment = trustScore.autonomyAdjustment()
            let adjustedRaw = max(0, min(AutonomyLevel.allCases.count - 1, baseLevel.rawValue + adjustment))
            effectiveLevel = AutonomyLevel(rawValue: adjustedRaw) ?? baseLevel
        }

        // Check if previously approved/denied
        let actionKey = "\(category.rawValue):\(request.description.prefix(50))"

        if deniedActionTypes.contains(actionKey) {
            return .deny(reason: "Previously denied by user")
        }

        if approvedActionTypes.contains(actionKey) && effectiveLevel >= .askOnce {
            return .proceed
        }

        // Critical actions always require confirmation
        if riskLevel == .critical {
            return .askConfirmation(reason: "Critical action requiring confirmation")
        }

        // Check autonomy level against risk
        switch effectiveLevel {
        case .alwaysAsk:
            return .askConfirmation(reason: "Current policy requires confirmation for all actions")

        case .askOnce:
            return .askConfirmation(reason: "First time performing this action type")

        case .cautious:
            if riskLevel >= .medium {
                return .askConfirmation(reason: "Action has potential impact")
            }
            return .proceed

        case .confident:
            if riskLevel >= .high {
                return .askConfirmation(reason: "High-risk action")
            }
            return .proceed

        case .autonomous:
            if riskLevel == .critical || !request.isReversible {
                return .askConfirmation(reason: "Irreversible or critical action")
            }
            return .proceed
        }
    }

    /// Record a successful action
    public func recordSuccess(for request: ActionRequest) {
        trustScore.successfulActions += 1
        trustScore.byCategory[request.category] = min(
            1.0,
            (trustScore.byCategory[request.category] ?? 0.5) + 0.01
        )
        updateOverallTrust()

        let entry = ActionHistoryEntry(
            actionId: request.id,
            category: request.category,
            description: request.description,
            outcome: .success,
            timestamp: Date()
        )
        addToHistory(entry)

        saveState()
        logger.debug("Recorded success for \(request.category.rawValue)")
    }

    /// Record a failed action
    public func recordFailure(for request: ActionRequest, reason: String) {
        trustScore.failedActions += 1
        trustScore.byCategory[request.category] = max(
            0.0,
            (trustScore.byCategory[request.category] ?? 0.5) - 0.05
        )
        updateOverallTrust()

        let entry = ActionHistoryEntry(
            actionId: request.id,
            category: request.category,
            description: request.description,
            outcome: .failure(reason: reason),
            timestamp: Date()
        )
        addToHistory(entry)

        saveState()
        logger.debug("Recorded failure for \(request.category.rawValue): \(reason)")
    }

    /// Record a user correction
    public func recordCorrection(for request: ActionRequest, correction: String) {
        trustScore.corrections += 1
        trustScore.byCategory[request.category] = max(
            0.0,
            (trustScore.byCategory[request.category] ?? 0.5) - 0.03
        )
        updateOverallTrust()

        let entry = ActionHistoryEntry(
            actionId: request.id,
            category: request.category,
            description: request.description,
            outcome: .corrected(correction: correction),
            timestamp: Date()
        )
        addToHistory(entry)

        saveState()
        logger.debug("Recorded correction for \(request.category.rawValue)")
    }

    /// User approved an action (for askOnce learning)
    public func userApproved(request: ActionRequest) {
        let actionKey = "\(request.category.rawValue):\(request.description.prefix(50))"
        approvedActionTypes.insert(actionKey)
        deniedActionTypes.remove(actionKey)

        if learningEnabled {
            recordSuccess(for: request)
        }

        saveState()
        logger.debug("User approved action: \(actionKey)")
    }

    /// User denied an action
    public func userDenied(request: ActionRequest, rememberChoice: Bool) {
        let actionKey = "\(request.category.rawValue):\(request.description.prefix(50))"

        if rememberChoice {
            deniedActionTypes.insert(actionKey)
            approvedActionTypes.remove(actionKey)
        }

        recordFailure(for: request, reason: "User denied")

        saveState()
        logger.debug("User denied action: \(actionKey), remember: \(rememberChoice)")
    }

    /// Set autonomy level for a specific category
    public func setAutonomy(_ level: AutonomyLevel, for category: ActionCategory) {
        categoryOverrides[category] = level
        saveState()
        logger.info("Set \(category.rawValue) autonomy to \(level.displayName)")
    }

    /// Reset autonomy for a category to global default
    public func resetAutonomy(for category: ActionCategory) {
        categoryOverrides.removeValue(forKey: category)
        saveState()
    }

    /// Clear all learned preferences
    public func clearLearnedPreferences() {
        approvedActionTypes.removeAll()
        deniedActionTypes.removeAll()
        saveState()
        logger.info("Cleared all learned preferences")
    }

    /// Reset trust score
    public func resetAutonomyTrustScore() {
        trustScore = AutonomyTrustScore()
        saveState()
        logger.info("Reset trust score")
    }

    /// Get effective autonomy level for a category
    public func effectiveAutonomy(for category: ActionCategory) -> AutonomyLevel {
        let base = categoryOverrides[category] ?? globalAutonomyLevel

        if useTrustAdjustment {
            let adjustment = trustScore.autonomyAdjustment()
            let adjustedRaw = max(0, min(AutonomyLevel.allCases.count - 1, base.rawValue + adjustment))
            return AutonomyLevel(rawValue: adjustedRaw) ?? base
        }

        return base
    }

    // MARK: - Cascading Trust API

    /// Check autonomy with cascading trust from conversation context
    public func checkCascadingAutonomy(for request: ActionRequest, conversationId: UUID) -> AutonomyDecision {
        guard cascadingTrustEnabled else {
            return checkAutonomy(for: request)
        }

        // Get conversation trust
        let convTrust = conversationTrustScores[conversationId]

        // If conversation has high trust, we can be more lenient
        if let trust = convTrust, trust.trustScore >= 0.8 && trust.successfulActions >= 5 {
            let riskLevel = request.category.riskLevel

            // Allow medium-risk actions automatically in high-trust conversations
            if riskLevel == .medium {
                logger.debug("Cascading trust: allowing medium-risk action in trusted conversation")
                return .proceed
            }

            // For high-risk, just proceed with the normal check but log the context
            logger.debug("Cascading trust: conversation trust=\(trust.trustScore)")
        }

        return checkAutonomy(for: request)
    }

    /// Inherit trust from a conversation into a new action context
    public func inheritTrust(from conversationId: UUID, factor: Double? = nil) {
        guard let existingTrust = conversationTrustScores[conversationId] else { return }

        let effectiveFactor = factor ?? cascadingTrustFactor
        let inheritedTrust = existingTrust.trustScore * effectiveFactor

        // Apply to overall trust with decay
        let oldOverall = trustScore.overall
        trustScore.overall = (oldOverall * 0.7) + (inheritedTrust * 0.3)

        logger.debug("Inherited trust \(inheritedTrust) from conversation (factor: \(effectiveFactor))")
        saveState()
    }

    /// Record success for a conversation (builds conversation-specific trust)
    public func recordConversationSuccess(_ conversationId: UUID, category: ActionCategory) {
        var trust = conversationTrustScores[conversationId] ?? ConversationTrust(conversationId: conversationId)
        trust.successfulActions += 1
        trust.categorySuccesses[category, default: 0] += 1
        trust.trustScore = min(1.0, trust.trustScore + 0.02)
        trust.lastUpdated = Date()

        conversationTrustScores[conversationId] = trust
        saveState()
    }

    /// Record failure for a conversation
    public func recordConversationFailure(_ conversationId: UUID, category: ActionCategory) {
        var trust = conversationTrustScores[conversationId] ?? ConversationTrust(conversationId: conversationId)
        trust.failedActions += 1
        trust.categoryFailures[category, default: 0] += 1
        trust.trustScore = max(0.0, trust.trustScore - 0.05)
        trust.lastUpdated = Date()

        conversationTrustScores[conversationId] = trust
        saveState()
    }

    /// Get trust score for a specific conversation
    public func getConversationTrust(_ conversationId: UUID) -> ConversationTrust? {
        conversationTrustScores[conversationId]
    }

    /// Reset trust for a conversation
    public func resetConversationTrust(_ conversationId: UUID) {
        conversationTrustScores.removeValue(forKey: conversationId)
        saveState()
    }

    /// Prune old conversation trust entries
    public func pruneOldConversationTrust(olderThan days: Int = 30) {
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)

        conversationTrustScores = conversationTrustScores.filter { _, trust in
            trust.lastUpdated > cutoff
        }

        saveState()
        logger.info("Pruned conversation trust entries older than \(days) days")
    }

    // MARK: - Private Methods

    private func updateOverallTrust() {
        let total = trustScore.successfulActions + trustScore.failedActions
        guard total > 0 else { return }

        let successRate = Double(trustScore.successfulActions) / Double(total)
        let correctionPenalty = Double(trustScore.corrections) / Double(max(1, trustScore.successfulActions)) * 0.1

        trustScore.overall = max(0, min(1, successRate - correctionPenalty))
        trustScore.lastUpdated = Date()
    }

    private func addToHistory(_ entry: ActionHistoryEntry) {
        actionHistory.insert(entry, at: 0)

        if actionHistory.count > maxHistorySize {
            actionHistory = Array(actionHistory.prefix(maxHistorySize))
        }
    }

    // MARK: - Persistence

    private let stateKey = "thea.autonomy_policy.state"

    private func saveState() {
        let state = AutonomyState(
            globalLevel: globalAutonomyLevel,
            categoryOverrides: categoryOverrides,
            trustScore: trustScore,
            approvedActionTypes: approvedActionTypes,
            deniedActionTypes: deniedActionTypes,
            conversationTrustScores: conversationTrustScores,
            cascadingTrustEnabled: cascadingTrustEnabled,
            cascadingTrustFactor: cascadingTrustFactor
        )

        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(AutonomyState.self, from: data) else {
            return
        }

        globalAutonomyLevel = state.globalLevel
        categoryOverrides = state.categoryOverrides
        trustScore = state.trustScore
        approvedActionTypes = state.approvedActionTypes
        deniedActionTypes = state.deniedActionTypes

        // Load cascading trust state
        if let convTrust = state.conversationTrustScores {
            conversationTrustScores = convTrust
        }
        if let enabled = state.cascadingTrustEnabled {
            cascadingTrustEnabled = enabled
        }
        if let factor = state.cascadingTrustFactor {
            cascadingTrustFactor = factor
        }

        logger.info("Loaded autonomy state: level=\(self.globalAutonomyLevel.displayName), trust=\(self.trustScore.overall), conversations=\(self.conversationTrustScores.count)")
    }
}

// MARK: - Supporting Types

/// Entry in action history
public struct ActionHistoryEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let actionId: UUID
    public let category: ActionCategory
    public let description: String
    public let outcome: ActionOutcome
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        actionId: UUID,
        category: ActionCategory,
        description: String,
        outcome: ActionOutcome,
        timestamp: Date
    ) {
        self.id = id
        self.actionId = actionId
        self.category = category
        self.description = description
        self.outcome = outcome
        self.timestamp = timestamp
    }
}

/// Outcome of an action
public enum ActionOutcome: Codable, Sendable {
    case success
    case failure(reason: String)
    case corrected(correction: String)
    case cancelled
}

/// Serializable state for persistence
private struct AutonomyState: Codable {
    let globalLevel: AutonomyLevel
    let categoryOverrides: [ActionCategory: AutonomyLevel]
    let trustScore: AutonomyTrustScore
    let approvedActionTypes: Set<String>
    let deniedActionTypes: Set<String>
    var conversationTrustScores: [UUID: ConversationTrust]?
    var cascadingTrustEnabled: Bool?
    var cascadingTrustFactor: Double?
}

/// Trust score for a specific conversation
public struct ConversationTrust: Codable, Sendable {
    public let conversationId: UUID
    public var trustScore: Double
    public var successfulActions: Int
    public var failedActions: Int
    public var categorySuccesses: [ActionCategory: Int]
    public var categoryFailures: [ActionCategory: Int]
    public var lastUpdated: Date

    public init(
        conversationId: UUID,
        trustScore: Double = 0.5,
        successfulActions: Int = 0,
        failedActions: Int = 0,
        categorySuccesses: [ActionCategory: Int] = [:],
        categoryFailures: [ActionCategory: Int] = [:],
        lastUpdated: Date = Date()
    ) {
        self.conversationId = conversationId
        self.trustScore = trustScore
        self.successfulActions = successfulActions
        self.failedActions = failedActions
        self.categorySuccesses = categorySuccesses
        self.categoryFailures = categoryFailures
        self.lastUpdated = lastUpdated
    }

    public var isHighTrust: Bool {
        trustScore >= 0.8 && successfulActions >= 5
    }

    public var successRate: Double {
        let total = successfulActions + failedActions
        guard total > 0 else { return 0.5 }
        return Double(successfulActions) / Double(total)
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// View for displaying and configuring autonomy settings
public struct AutonomySettingsView: View {
    @StateObject private var manager = AutonomyPolicyManager.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Global Autonomy Level") {
                Picker("Level", selection: $manager.globalAutonomyLevel) {
                    ForEach(AutonomyLevel.allCases, id: \.self) { level in
                        VStack(alignment: .leading) {
                            Text(level.displayName)
                            Text(level.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(level)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("Trust Score") {
                HStack {
                    Text("Overall Trust")
                    Spacer()
                    Text("\(Int(manager.trustScore.overall * 100))%")
                        .foregroundColor(trustColor)
                }

                HStack {
                    Text("Successful Actions")
                    Spacer()
                    Text("\(manager.trustScore.successfulActions)")
                }

                HStack {
                    Text("Corrections")
                    Spacer()
                    Text("\(manager.trustScore.corrections)")
                        .foregroundColor(manager.trustScore.corrections > 10 ? .orange : .primary)
                }

                Toggle("Use Trust-Based Adjustment", isOn: $manager.useTrustAdjustment)
            }

            Section("Category Overrides") {
                ForEach(ActionCategory.allCases, id: \.self) { category in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(category.displayName)
                            Text("Risk: \(category.riskLevel)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if let override = manager.categoryOverrides[category] {
                            Text(override.displayName)
                                .foregroundColor(.blue)
                            Button("Reset") {
                                manager.resetAutonomy(for: category)
                            }
                            .buttonStyle(.borderless)
                        } else {
                            Text("Default")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("Learning") {
                Toggle("Learn from Decisions", isOn: $manager.learningEnabled)

                Button("Clear Learned Preferences") {
                    manager.clearLearnedPreferences()
                }
                .foregroundColor(.orange)

                Button("Reset Trust Score") {
                    manager.resetAutonomyTrustScore()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Autonomy Settings")
    }

    private var trustColor: Color {
        if manager.trustScore.overall >= 0.8 {
            return .green
        } else if manager.trustScore.overall >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}
