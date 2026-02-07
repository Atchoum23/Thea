// PlanPanel.swift
// Thea
//
// Right-side inspector panel displaying the active plan with phases,
// steps, progress tracking, and live status updates.
// Modeled on ArtifactPanel.swift.

import SwiftUI

// MARK: - Plan Panel View

struct PlanPanel: View {
    @State private var planManager = PlanManager.shared

    var body: some View {
        VStack(spacing: 0) {
            panelHeader

            Divider()

            if let plan = planManager.activePlan {
                planContent(plan)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 280, idealWidth: 380)
        #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
        #else
            .background(Color(uiColor: .systemBackground))
        #endif
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: TheaSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(planManager.activePlan?.title ?? "Plan")
                    .font(.headline)
                    .lineLimit(1)

                if let plan = planManager.activePlan {
                    Text("\(plan.completedSteps)/\(plan.totalSteps) steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                planManager.collapsePanel()
            } label: {
                Image(systemName: "rectangle.compress.vertical")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Collapse to compact bar")

            Button {
                planManager.hidePanel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Close panel")
        }
        .padding(.horizontal, TheaSpacing.lg)
        .padding(.vertical, TheaSpacing.md)
    }

    // MARK: - Plan Content

    @ViewBuilder
    private func planContent(_ plan: PlanState) -> some View {
        ScrollView {
            LazyVStack(spacing: TheaSpacing.md) {
                PlanProgressBar(plan: plan)
                    .padding(.horizontal, TheaSpacing.lg)

                ForEach(plan.phases) { phase in
                    PlanPhaseView(phase: phase)
                }
            }
            .padding(.vertical, TheaSpacing.md)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: TheaSpacing.lg) {
            Spacer()

            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Active Plan")
                .font(.headline)

            Text("Complex queries will automatically generate a plan here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TheaSpacing.xxl)

            Spacer()
        }
    }
}

// MARK: - Plan Progress Bar

struct PlanProgressBar: View {
    let plan: PlanState

    var body: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.xs) {
            ProgressView(value: plan.progress)
                .tint(TheaBrandColors.gold)

            HStack {
                Text(plan.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(plan.progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Phase View

struct PlanPhaseView: View {
    let phase: PlanPhase
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Phase header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: TheaSpacing.sm) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16)

                    Text(phase.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(phase.completedSteps)/\(phase.totalSteps)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, TheaSpacing.lg)
                .padding(.vertical, TheaSpacing.sm)
            }
            .buttonStyle(.plain)

            // Steps
            if isExpanded {
                ForEach(phase.steps) { step in
                    PlanStepRow(step: step)
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: TheaRadius.md)
                .fill(.quaternary.opacity(0.3))
        }
        .padding(.horizontal, TheaSpacing.md)
    }
}

// MARK: - Step Row

struct PlanStepRow: View {
    let step: PlanStep

    var body: some View {
        HStack(spacing: TheaSpacing.sm) {
            stepStatusIcon
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(
                        size: 12,
                        weight: step.status == .inProgress ? .semibold : .regular
                    ))
                    .foregroundStyle(
                        step.status == .completed ? .secondary : .primary
                    )
                    .strikethrough(step.status == .completed)

                if step.status == .inProgress {
                    Text(step.activeDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(TheaBrandColors.gold)
                }

                if step.status == .failed, let error = step.error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let duration = step.duration {
                Text(String(format: "%.1fs", duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, TheaSpacing.lg)
        .padding(.vertical, TheaSpacing.xs + 2)
        .background(
            step.status == .inProgress
                ? TheaBrandColors.gold.opacity(0.05)
                : Color.clear
        )
        .animation(.easeInOut(duration: 0.2), value: step.status)
    }

    @ViewBuilder
    private var stepStatusIcon: some View {
        switch step.status {
        case .pending:
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)

        case .inProgress:
            ProgressView()
                .scaleEffect(0.6)

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)

        case .skipped:
            Image(systemName: "arrow.right.circle")
                .foregroundStyle(.secondary)

        case .modified:
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(TheaBrandColors.gold)
        }
    }
}
