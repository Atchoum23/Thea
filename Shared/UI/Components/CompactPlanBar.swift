// CompactPlanBar.swift
// Thea
//
// Floating compact progress bar shown at bottom-trailing of chat
// when the plan panel is collapsed or when multiple tasks are active.
// Tapping expands the full plan panel.

import SwiftUI

struct CompactPlanBar: View {
    @State private var planManager = PlanManager.shared

    var body: some View {
        if let plan = planManager.activePlan, plan.isActive {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    planManager.expandPanel()
                }
            } label: {
                HStack(spacing: TheaSpacing.sm) {
                    // Circular progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 2.5)

                        Circle()
                            .trim(from: 0, to: plan.progress)
                            .stroke(
                                TheaBrandColors.gold,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 22, height: 22)
                    .animation(.easeInOut(duration: 0.3), value: plan.progress)

                    // Step count
                    Text("\(plan.completedSteps)/\(plan.totalSteps)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())

                    // Current step name
                    if let stepTitle = plan.currentStepTitle {
                        Text(stepTitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 200)
                    }

                    // Expand icon
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
