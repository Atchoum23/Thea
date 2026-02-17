//
//  PlanViews.swift
//  Thea
//
//  Plan mode UI components - CompactPlanBar and PlanPanel
//

import SwiftUI

// MARK: - Compact Plan Bar

/// A compact floating bar showing current plan status
struct CompactPlanBar: View {
    @State private var planManager = PlanManager.shared

    var body: some View {
        if let plan = planManager.activePlan {
            HStack(spacing: TheaSpacing.sm) {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text("\(plan.completedSteps)/\(plan.totalSteps) steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ProgressView(value: plan.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 60)

                Button {
                    withAnimation {
                        planManager.isPanelVisible = true
                        planManager.isPanelCollapsed = false
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Expand plan")
            }
            .padding(TheaSpacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: TheaCornerRadius.lg))
            .shadow(radius: 4)
            .frame(maxWidth: 320)
        }
    }
}

// MARK: - Plan Panel

/// Full plan panel showing all phases and steps
struct PlanPanel: View {
    @State private var planManager = PlanManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header

            Divider()

            // Content
            if let plan = planManager.activePlan {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: TheaSpacing.md) {
                        ForEach(plan.phases) { phase in
                            PhaseSection(phase: phase)
                        }
                    }
                    .padding(TheaSpacing.md)
                }
            } else {
                ContentUnavailableView(
                    "No Active Plan",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Create a plan to see it here")
                )
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan Mode")
                    .font(.headline)

                if let plan = planManager.activePlan {
                    Text(plan.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    planManager.isPanelCollapsed = true
                    planManager.isPanelVisible = false
                }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close plan")
        }
        .padding(TheaSpacing.md)
    }
}

// MARK: - Phase Section

private struct PhaseSection: View {
    let phase: PlanPhase

    var body: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            HStack {
                Text(phase.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                statusBadge
            }

            ForEach(phase.steps) { step in
                StepRow(step: step)
            }
        }
        .padding(TheaSpacing.sm)
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: TheaCornerRadius.md))
        #else
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: TheaCornerRadius.md))
        #endif
    }

    @ViewBuilder
    private var statusBadge: some View {
        let completedCount = phase.steps.filter { $0.status == .completed }.count
        let totalCount = phase.steps.count

        Text("\(completedCount)/\(totalCount)")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(completedCount == totalCount ? Color.theaSuccess.opacity(0.2) : Color.secondary.opacity(0.2))
            .clipShape(Capsule())
    }
}

// MARK: - Step Row

private struct StepRow: View {
    let step: PlanStep

    var body: some View {
        HStack(spacing: TheaSpacing.sm) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.callout)
                    .lineLimit(2)

                if let result = step.result {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch step.status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Pending")
        case .inProgress:
            ProgressView()
                .scaleEffect(0.7)
                .accessibilityLabel("In progress")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.theaSuccess)
                .accessibilityLabel("Completed")
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Failed")
        case .skipped:
            Image(systemName: "arrow.turn.up.right")
                .foregroundStyle(.orange)
                .accessibilityLabel("Skipped")
        case .modified:
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.blue)
                .accessibilityLabel("Modified")
        }
    }
}

#if DEBUG
#Preview("Compact Plan Bar") {
    CompactPlanBar()
        .padding()
}

#Preview("Plan Panel") {
    PlanPanel()
        .frame(width: 400, height: 600)
}
#endif
