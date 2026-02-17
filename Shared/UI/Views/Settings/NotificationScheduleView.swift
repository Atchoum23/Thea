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
                statisticsSection; receptivitySection; configSection; timingSection
            }.padding()
        }
        .navigationTitle("Notification Schedule")
        .task { refreshTimingData() }
    }

    // MARK: - Statistics
    private var statisticsSection: some View {
        Section {
            HStack(spacing: 16) {
                tile("Scheduled", "\(scheduler.scheduledCount)", "bell.badge", .blue)
                tile("Immediate", "\(scheduler.immediateCount)", "bolt.fill", .green)
                tile("Deferred", "\(scheduler.deferredCount)", "clock.arrow.circlepath", .orange)
                tile("Defer Rate", deferRate, "percent", .purple)
            }
        } header: { Text("Delivery Statistics").font(.theaHeadline) }
    }

    private func tile(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
            Text(value).font(.theaTitle3)
            Text(title).font(.theaCaption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private var deferRate: String {
        guard scheduler.scheduledCount > 0 else { return "---" }
        return String(format: "%.0f%%", Double(scheduler.deferredCount) / Double(scheduler.scheduledCount) * 100)
    }

    // MARK: - Receptivity
    private var receptivitySection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(recepColor.opacity(0.2), lineWidth: 8)
                    Circle().trim(from: 0, to: currentReceptivity)
                        .stroke(recepColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(String(format: "%.0f%%", currentReceptivity * 100)).font(.theaTitle3).foregroundStyle(recepColor)
                }.frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(recepLabel).font(.theaBody).foregroundStyle(recepColor)
                    Text("Threshold: \(String(format: "%.0f%%", scheduler.receptivityThreshold * 100))").font(.theaCaption2).foregroundStyle(.secondary)
                    if currentReceptivity >= scheduler.receptivityThreshold {
                        Label("Good time to notify", systemImage: "checkmark.circle.fill").font(.theaCaption1).foregroundStyle(.green)
                    } else {
                        Label("Notifications may be deferred", systemImage: "clock.fill").font(.theaCaption1).foregroundStyle(.orange)
                    }
                }
                Spacer()
            }
        } header: { Text("Current Receptivity").font(.theaHeadline) }
    }

    private var recepColor: Color {
        switch currentReceptivity { case 0.6...: .green; case 0.3..<0.6: .orange; default: .red }
    }

    private var recepLabel: String {
        switch currentReceptivity { case 0.6...: "High Receptivity"; case 0.3..<0.6: "Moderate Receptivity"; default: "Low Receptivity" }
    }

    // MARK: - Configuration
    private var configSection: some View {
        Section {
            Form {
                Toggle("Smart Scheduling", isOn: Binding(
                    get: { scheduler.isEnabled }, set: { scheduler.isEnabled = $0 }
                ))
                if scheduler.isEnabled {
                    HStack {
                        Text("Max Delay"); Spacer()
                        Text("\(scheduler.maxDelayHours) hour(s)").foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(scheduler.maxDelayHours) }, set: { scheduler.maxDelayHours = Int($0) }
                    ), in: 1...8, step: 1)
                    HStack {
                        Text("Receptivity Threshold"); Spacer()
                        Text(String(format: "%.0f%%", scheduler.receptivityThreshold * 100)).foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { scheduler.receptivityThreshold }, set: { scheduler.receptivityThreshold = $0 }
                    ), in: 0.1...0.9, step: 0.1)
                }
            }.formStyle(.grouped)
        } header: { Text("Configuration").font(.theaHeadline) }
    }

    // MARK: - Timing
    private var timingSection: some View {
        Section {
            HStack(spacing: 24) {
                timeCard("bell.circle.fill", .blue, "\(bestTimeToday):00", "Best Notification Time")
                timeCard("sunrise.fill", .orange, "\(fingerprint.typicalWakeTime):00", "Wake Time")
                timeCard("moon.fill", .indigo, "\(fingerprint.typicalSleepTime):00", "Sleep Time")
            }
            .padding(10).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        } header: { Text("Today's Timing").font(.theaHeadline) }
    }

    private func timeCard(_ icon: String, _ tint: Color, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint)
            Text(value).font(.theaTitle3)
            Text(label).font(.theaCaption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Helpers
    private func refreshTimingData() {
        let weekday = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        let day = DayOfWeek.allCases[weekday]
        bestTimeToday = fingerprint.bestNotificationTime(on: day)
        currentReceptivity = fingerprint.currentContext().receptivity
    }
}

#Preview { NotificationScheduleView().frame(width: 600, height: 550) }
