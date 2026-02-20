// BehavioralAnalyticsView.swift
// Thea
//
// V3-1: 7×24 activity heatmap, sleep/wake patterns, responsiveness overview.
// Uses BehavioralFingerprint.shared (@Observable @MainActor).

import SwiftUI

// MARK: - Behavioral Analytics View

struct BehavioralAnalyticsView: View {
    @State private var fingerprint = BehavioralFingerprint.shared

    private let days = DayOfWeek.allCases
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TheaSpacing.xl) {

                // MARK: Overview Cards
                overviewSection

                // MARK: 7×24 Activity Heatmap
                VStack(alignment: .leading, spacing: TheaSpacing.sm) {
                    Text("Activity Pattern (7 days × 24 hours)")
                        .font(.theaHeadline)
                    Text("Colour intensity = receptivity score")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                    ActivityHeatmapGrid(days: days, fingerprint: fingerprint)
                        .frame(height: 100)
                }

                // MARK: Sleep / Wake
                VStack(alignment: .leading, spacing: TheaSpacing.sm) {
                    Text("Sleep / Wake Pattern")
                        .font(.theaHeadline)
                    sleepWakeRow
                }

                // MARK: Current Context
                VStack(alignment: .leading, spacing: TheaSpacing.sm) {
                    Text("Current Context")
                        .font(.theaHeadline)
                    currentContextRow
                }
            }
            .padding()
        }
        .navigationTitle("Behavioral Analytics")
        #if os(macOS)
        .padding()
        #endif
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        HStack(spacing: TheaSpacing.lg) {
            analyticsCard(
                title: "Responsiveness",
                value: String(format: "%.0f%%", fingerprint.overallResponsiveness * 100),
                icon: "person.fill.checkmark",
                color: .blue
            )
            analyticsCard(
                title: "Observations",
                value: "\(fingerprint.totalObservations)",
                icon: "chart.dots.scatter",
                color: .purple
            )
            analyticsCard(
                title: "Wake Time",
                value: hourLabel(fingerprint.typicalWakeTime),
                icon: "sunrise.fill",
                color: .orange
            )
            analyticsCard(
                title: "Sleep Time",
                value: hourLabel(fingerprint.typicalSleepTime),
                icon: "moon.zzz.fill",
                color: .indigo
            )
        }
    }

    private func analyticsCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: TheaSpacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.theaTitle3)
                .monospacedDigit()
            Text(title)
                .font(.theaCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(TheaSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.md))
    }

    // MARK: - Sleep/Wake Row

    private var sleepWakeRow: some View {
        HStack(spacing: TheaSpacing.xl) {
            Label("Wake: \(hourLabel(fingerprint.typicalWakeTime))", systemImage: "sunrise.fill")
                .foregroundStyle(.orange)
            Label("Sleep: \(hourLabel(fingerprint.typicalSleepTime))", systemImage: "moon.zzz.fill")
                .foregroundStyle(.indigo)
            Spacer()
        }
        .font(.theaBody)
        .padding(TheaSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.md))
    }

    // MARK: - Current Context Row

    private var currentContextRow: some View {
        let context = fingerprint.currentContext()
        return HStack(spacing: TheaSpacing.xl) {
            Label("Activity: \(context.activity.rawValue.capitalized)",
                  systemImage: "bolt.circle")
            Label(String(format: "Receptivity: %.0f%%", context.receptivity * 100),
                  systemImage: "waveform.path.ecg")
            Label(context.isAwake ? "Awake" : "Likely asleep", systemImage: "eye.fill")
            Spacer()
        }
        .font(.theaBody)
        .padding(TheaSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.md))
    }

    // MARK: - Helpers

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h)\(hour < 12 ? "am" : "pm")"
    }
}

// MARK: - Activity Heatmap Grid

struct ActivityHeatmapGrid: View {
    let days: [DayOfWeek]
    let fingerprint: BehavioralFingerprint

    private let hourLabels = ["12a", "3a", "6a", "9a", "12p", "3p", "6p", "9p"]

    var body: some View {
        VStack(spacing: 2) {
            // Hour axis labels
            HStack(spacing: 0) {
                Text("").frame(width: 28)
                ForEach(0..<8, id: \.self) { i in
                    Text(hourLabels[i])
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                HStack(spacing: 2) {
                    Text(dayAbbrev(idx))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)

                    ForEach(0..<24, id: \.self) { hour in
                        let intensity = fingerprint.receptivity(day: day, hour: hour)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cellColor(intensity: intensity))
                            .aspectRatio(1, contentMode: .fill)
                    }
                }
            }
        }
    }

    private func dayAbbrev(_ idx: Int) -> String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][idx % 7]
    }

    private func cellColor(intensity: Double) -> Color {
        if intensity < 0.05 { return Color.primary.opacity(0.05) }
        return Color.purple.opacity(0.15 + min(intensity, 1.0) * 0.75)
    }
}
