// BehavioralAnalyticsView.swift
// Thea — Behavioral Analytics Dashboard
// Shows insights from BehavioralFingerprint (7×24 temporal model)

import SwiftUI

#if os(macOS)
struct BehavioralAnalyticsView: View {
    private let fingerprint = BehavioralFingerprint.shared

    private func formatHour(_ h: Int) -> String {
        let ampm = h < 12 ? "AM" : "PM"
        let hour = h == 0 ? 12 : h > 12 ? h - 12 : h
        return "\(hour):00 \(ampm)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Behavioral Analytics")
                    .font(.largeTitle.bold())

                GroupBox("Daily Patterns") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Typical wake time", systemImage: "sunrise.fill")
                            Spacer()
                            Text(formatHour(fingerprint.typicalWakeTime)).foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Typical sleep time", systemImage: "moon.fill")
                            Spacer()
                            Text(formatHour(fingerprint.typicalSleepTime)).foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Notification responsiveness", systemImage: "bolt.fill")
                            Spacer()
                            Text(String(format: "%.0f%%", fingerprint.overallResponsiveness * 100))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }

                GroupBox("Data Quality") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Total observations", systemImage: "number.circle")
                            Spacer()
                            Text("\(fingerprint.totalObservations)").foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Time slots recorded", systemImage: "chart.bar")
                            Spacer()
                            Text("\(fingerprint.totalRecordedSlots) / 168").foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }

                Spacer()
            }
            .padding()
        }
    }
}
#endif
