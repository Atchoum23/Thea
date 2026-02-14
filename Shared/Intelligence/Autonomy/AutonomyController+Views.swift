// AutonomyController+Views.swift
// Thea
//
// UI views for autonomy settings and pending actions.

import Foundation
import SwiftUI
import os.log

// MARK: - Autonomy Settings View

/// UI for configuring autonomy settings
public struct THEAAutonomySettingsView: View {
    @StateObject private var controller = AutonomyController.shared

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
    @StateObject private var controller = AutonomyController.shared

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
