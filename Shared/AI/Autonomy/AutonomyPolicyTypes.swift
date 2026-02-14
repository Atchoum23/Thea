//
//  AutonomyPolicyTypes.swift
//  Thea
//
//  Supporting types and SwiftUI view extracted from AutonomyPolicy.swift
//  for file_length compliance.
//
//  Copyright 2026. All rights reserved.
//

import Foundation
import SwiftUI

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
struct AutonomyState: Codable {
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
                            Text("Risk: \(String(describing: category.riskLevel))")
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
