// NotificationIntelligenceView.swift
// Thea
//
// V3-4: Delivery stats and configuration for SmartNotificationScheduler.
// Shows scheduled/immediate/deferred counts and the scheduler's config.

import SwiftUI

// MARK: - Notification Intelligence View

struct NotificationIntelligenceView: View {
    @State private var scheduler = SmartNotificationScheduler.shared

    var body: some View {
        List {
            // MARK: Status
            Section("Scheduler") {
                LabeledContent("Smart Scheduling") {
                    Toggle("", isOn: Bindable(scheduler).isEnabled)
                        .labelsHidden()
                }
                LabeledContent("Max Deferral", value: "\(scheduler.maxDelayHours)h")
                LabeledContent("Delivery Threshold") {
                    Text(String(format: "%.0f%%", scheduler.receptivityThreshold * 100))
                        .monospacedDigit()
                }
            }

            // MARK: Delivery Stats
            Section("Delivery Statistics") {
                deliveryStat(
                    label: "Scheduled",
                    count: scheduler.scheduledCount,
                    icon: "calendar.badge.clock",
                    color: .blue
                )
                deliveryStat(
                    label: "Delivered Immediately",
                    count: scheduler.immediateCount,
                    icon: "bolt.fill",
                    color: .green
                )
                deliveryStat(
                    label: "Deferred",
                    count: scheduler.deferredCount,
                    icon: "clock.arrow.circlepath",
                    color: .orange
                )

                if scheduler.scheduledCount > 0 {
                    let pct = Double(scheduler.immediateCount) / Double(scheduler.scheduledCount)
                    LabeledContent("Immediate Rate") {
                        Text(String(format: "%.0f%%", pct * 100))
                            .monospacedDigit()
                            .foregroundStyle(pct > 0.5 ? .green : .secondary)
                    }
                }
            }

            // MARK: Current Context
            Section("Optimal Delivery Now?") {
                let decision = scheduler.optimalDeliveryTime(priority: .normal, category: nil)
                switch decision {
                case .now(let reason):
                    Label("Now — \(reason)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .deferred(let until, let reason):
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Deferred — \(reason)", systemImage: "clock.badge.xmark")
                            .foregroundStyle(.orange)
                        Text("Optimal: \(until, style: .relative)")
                            .font(.theaCaption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: Bypass Priorities
            if !scheduler.bypassPriorities.isEmpty {
                Section("Bypass Priorities (always immediate)") {
                    ForEach(Array(scheduler.bypassPriorities), id: \.self) { (priority: NotificationPriority) in
                        Label(String(describing: priority).capitalized, systemImage: "bolt.shield.fill")
                    }
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.grouped)
        #endif
        .navigationTitle("Notification Intelligence")
        #if os(macOS)
        .padding()
        #endif
    }

    // MARK: - Helpers

    private func deliveryStat(label: String, count: Int, icon: String, color: Color) -> some View {
        LabeledContent(label) {
            HStack(spacing: TheaSpacing.xs) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text("\(count)")
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
        }
    }
}
