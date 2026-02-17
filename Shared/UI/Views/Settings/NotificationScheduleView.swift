// NotificationScheduleView.swift
// Thea — Smart Notification Scheduler Dashboard

import SwiftUI
import os.log

struct NotificationScheduleView: View {
    private let scheduler = SmartNotificationScheduler.shared
    private let fingerprint = BehavioralFingerprint.shared

    @State private var bestTimeToday: Int = 9
    @State private var currentReceptivity: Double = 0.5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statisticsSection
                receptivitySection
                configurationSection
                timingSection
            }
            .padding()
        }
        .navigationTitle("Notification Schedule")
        .task { refreshTimingData() }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        Section {
            HStack(spacing: 16) {
                statTile(
                    "Scheduled",
                    value: "\(scheduler.scheduledCount)",
                    icon: "bell.badge",
                    color: .blue
                )
                statTile(
                    "Immediate",
                    value: "\(scheduler.immediateCount)",
                    icon: "bolt.fill",
                    color: .green
                )
                statTile(
                    "Deferred",
                    value: "\(scheduler.deferredCount)",
                    icon: "clock.arrow.circlepath",
                    color: .orange
                )
                statTile(
                    "Defer Rate",
                    value: deferRateText,
                    icon: "percent",
                    color: .purple
                )
            }
        } header: {
            Text("Delivery Statistics")
                .font(.theaHeadline)
        }
    }

    private func statTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.theaTitle3)
            Text(title)
                .font(.theaCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private var deferRateText: String {
        guard scheduler.scheduledCount > 0 else { return "---" }
        let rate = Double(scheduler.deferredCount) / Double(scheduler.scheduledCount) * 100
        return String(format: "%.0f%%", rate)
    }

    // MARK: - Current Receptivity

    private var receptivitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    receptivityGauge
                    VStack(alignment: .leading, spacing: 4) {
                        Text(receptivityLabel)
                            .font(.theaBody)
                            .foregroundStyle(receptivityColor)
                        Text("Threshold: \(String(format: "%.0f%%", scheduler.receptivityThreshold * 100))")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                        if currentReceptivity >= scheduler.receptivityThreshold {
                            Label("Good time to notify", systemImage: "checkmark.circle.fill")
                                .font(.theaCaption1)
                                .foregroundStyle(.green)
                        } else {
                            Label("Notifications may be deferred", systemImage: "clock.fill")
                                .font(.theaCaption1)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                }
            }
        } header: {
            Text("Current Receptivity")
                .font(.theaHeadline)
        }
    }

    private var receptivityGauge: some View {
        ZStack {
            Circle()
                .stroke(receptivityColor.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: currentReceptivity)
                .stroke(receptivityColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(String(format: "%.0f%%", currentReceptivity * 100))
                .font(.theaTitle3)
                .foregroundStyle(receptivityColor)
        }
        .frame(width: 72, height: 72)
    }

    private var receptivityColor: Color {
        switch currentReceptivity {
        case 0.6...: .green
        case 0.3..<0.6: .orange
        default: .red
        }
    }

    private var receptivityLabel: String {
        switch currentReceptivity {
        case 0.6...: "High Receptivity"
        case 0.3..<0.6: "Moderate Receptivity"
        default: "Low Receptivity"
        }
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        Section {
            Form {
                Toggle("Smart Scheduling", isOn: Binding(
                    get: { scheduler.isEnabled },
                    set: { scheduler.isEnabled = $0 }
                ))

                if scheduler.isEnabled {
                    HStack {
                        Text("Max Delay")
                        Spacer()
                        Text("\(scheduler.maxDelayHours) hour(s)")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(scheduler.maxDelayHours) },
                            set: { scheduler.maxDelayHours = Int($0) }
                        ),
                        in: 1...8,
                        step: 1
                    )

                    HStack {
                        Text("Receptivity Threshold")
                        Spacer()
                        Text(String(format: "%.0f%%", scheduler.receptivityThreshold * 100))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { scheduler.receptivityThreshold },
                            set: { scheduler.receptivityThreshold = $0 }
                        ),
                        in: 0.1...0.9,
                        step: 0.1
                    )
                }
            }
            .formStyle(.grouped)
        } header: {
            Text("Configuration")
                .font(.theaHeadline)
        }
    }

    // MARK: - Timing

    private var timingSection: some View {
        Section {
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Image(systemName: "bell.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Text("\(bestTimeToday):00")
                        .font(.theaTitle3)
                    Text("Best Notification Time")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Image(systemName: "sunrise.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("\(fingerprint.typicalWakeTime):00")
                        .font(.theaTitle3)
                    Text("Wake Time")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                    Text("\(fingerprint.typicalSleepTime):00")
                        .font(.theaTitle3)
                    Text("Sleep Time")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(10)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        } header: {
            Text("Today's Timing")
                .font(.theaHeadline)
        }
    }

    // MARK: - Helpers

    private func refreshTimingData() {
        let calendar = Calendar.current
        let weekday = (calendar.component(.weekday, from: Date()) + 5) % 7
        let day: DayOfWeek = DayOfWeek.allCases[weekday]
        bestTimeToday = fingerprint.bestNotificationTime(on: day)
        currentReceptivity = fingerprint.currentContext().receptivity
    }
}

#Preview {
    NotificationScheduleView()
        .frame(width: 600, height: 550)
}
