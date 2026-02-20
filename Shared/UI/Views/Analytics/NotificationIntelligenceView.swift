// NotificationIntelligenceView.swift
// Thea — Smart Notification Scheduler Dashboard
//
// Shows configuration and statistics for SmartNotificationScheduler:
// how many notifications were delivered immediately vs deferred, current
// thresholds, and a live preview of the optimal delivery decision for now.

import SwiftUI

// MARK: - Notification Intelligence View

@MainActor
struct NotificationIntelligenceView: View {
    @State private var scheduler = SmartNotificationScheduler.shared
    @State private var fingerprint = BehavioralFingerprint.shared
    @State private var previewDecision: DeliveryDecision?
    @State private var isRefreshing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                overviewCards
                configurationSection
                bypassPrioritiesSection
                deliveryPreviewSection
                weeklyBestTimesSection
            }
            .padding(20)
        }
        .navigationTitle("Notification Intelligence")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    refreshPreview()
                } label: {
                    Label("Refresh Preview", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear { refreshPreview() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Smart Notification Scheduler")
                .font(.title2).bold()
            Text("Delivers notifications at the moment you're most likely to engage with them.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            NotifStatCard(
                value: "\(scheduler.scheduledCount)",
                label: "Total Scheduled",
                icon: "bell.fill",
                color: .blue
            )
            NotifStatCard(
                value: "\(scheduler.immediateCount)",
                label: "Delivered Now",
                icon: "bolt.fill",
                color: .green
            )
            NotifStatCard(
                value: "\(scheduler.deferredCount)",
                label: "Deferred",
                icon: "clock.fill",
                color: .orange
            )
        }
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Configuration")
                .font(.headline)

            HStack {
                Label("Smart Scheduling", systemImage: "brain")
                    .font(.subheadline)
                Spacer()
                Toggle("", isOn: $scheduler.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Max Delay")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(scheduler.maxDelayHours) hour\(scheduler.maxDelayHours == 1 ? "" : "s")")
                        .font(.caption).bold()
                }
                Slider(value: Binding(
                    get: { Double(scheduler.maxDelayHours) },
                    set: { scheduler.maxDelayHours = Int($0) }
                ), in: 1...12, step: 1)
                .tint(.blue)
                Text("Maximum time a notification can be delayed seeking better receptivity.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Receptivity Threshold")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", scheduler.receptivityThreshold * 100))
                        .font(.caption).bold()
                }
                Slider(value: $scheduler.receptivityThreshold, in: 0.1...0.9, step: 0.05)
                    .tint(.green)
                Text("Minimum engagement probability required for immediate delivery.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bypassPrioritiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Priority Bypass")
                .font(.headline)
            Text("These priority levels always deliver immediately, bypassing smart scheduling.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(NotificationPriority.allCases, id: \.rawValue) { priority in
                    let isBypassed = scheduler.bypassPriorities.contains(priority)
                    Button {
                        if isBypassed {
                            scheduler.bypassPriorities.remove(priority)
                        } else {
                            scheduler.bypassPriorities.insert(priority)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: priority.icon)
                            Text(priority.displayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isBypassed ? priorityColor(priority) : Color.secondary.opacity(0.12))
                        .foregroundStyle(isBypassed ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var deliveryPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Delivery Preview")
                .font(.headline)
            Text("What would happen if a normal-priority notification arrived right now?")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let decision = previewDecision {
                HStack(spacing: 12) {
                    Image(systemName: decision.isImmediate ? "bolt.fill" : "clock.fill")
                        .font(.title2)
                        .foregroundStyle(decision.isImmediate ? .green : .orange)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(decision.isImmediate ? "Deliver Now" : "Defer Delivery")
                            .font(.subheadline).bold()
                        Text(decisionReason(decision))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if case let .deferred(until, _) = decision {
                            Text("Target: \(until.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(12)
                .background(decision.isImmediate ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ProgressView("Calculating…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            }

            HStack {
                Text("Current receptivity: \(String(format: "%.0f%%", fingerprint.currentContext().receptivity * 100))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Observations: \(fingerprint.totalObservations)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var weeklyBestTimesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Optimal Notification Times by Day")
                .font(.headline)
            ForEach(DayOfWeek.allCases, id: \.rawValue) { day in
                let bestHour = fingerprint.bestNotificationTime(on: day)
                let receptivity = fingerprint.receptivity(day: day, hour: bestHour)
                HStack {
                    Text(day.rawValue.prefix(3).capitalized)
                        .font(.caption).bold()
                        .frame(width: 32, alignment: .leading)
                    Text(formattedHour(bestHour))
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .frame(width: 70)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(receptivityBarColor(receptivity))
                            .frame(width: max(4, geo.size.width * receptivity), height: 10)
                    }
                    .frame(height: 10)
                    Text(String(format: "%.0f%%", receptivity * 100))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func refreshPreview() {
        previewDecision = scheduler.optimalDeliveryTime(priority: .normal)
    }

    private func formattedHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h):00 \(suffix)"
    }

    private func decisionReason(_ decision: DeliveryDecision) -> String {
        switch decision {
        case let .now(reason): reason
        case let .deferred(_, reason): reason
        }
    }

    private func receptivityBarColor(_ value: Double) -> Color {
        switch value {
        case 0.6...: return .green
        case 0.3..<0.6: return .yellow
        default: return .red
        }
    }

    private func priorityColor(_ priority: NotificationPriority) -> Color {
        switch priority {
        case .silent:   .gray
        case .low:      .blue
        case .normal:   .green
        case .high:     .orange
        case .critical: .red
        }
    }
}

// MARK: - Notification Stat Card

private struct NotifStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(.title2).bold()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        NotificationIntelligenceView()
    }
    .frame(width: 700, height: 700)
}
#endif
