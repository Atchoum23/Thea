// BehavioralAnalyticsView.swift
// Thea — Behavioral Fingerprint Analytics Dashboard
//
// Displays the user's observed behavioral patterns: daily rhythms, activity
// distributions, notification receptivity, and wake/sleep estimates derived
// from BehavioralFingerprint.shared.

import SwiftUI

// MARK: - Behavioral Analytics View

struct BehavioralAnalyticsView: View {
    @State private var selectedDay: DayOfWeek = .monday
    @State private var hourlySummary: [BehavioralHourSummary] = []
    @State private var refreshTick = 0

    private var fingerprint: BehavioralFingerprint { BehavioralFingerprint.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                overviewCards
                dayPicker
                hourlyReceptivityChart
                activityBreakdownSection
            }
            .padding(20)
        }
        .navigationTitle("Behavioral Analytics")
        .onAppear { refreshSummary() }
        .onChange(of: selectedDay) { _, _ in refreshSummary() }
        .onChange(of: refreshTick) { _, _ in refreshSummary() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Behavioral Fingerprint")
                .font(.title2).bold()
            Text("Patterns learned from \(fingerprint.totalObservations) observations")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Total Observations",
                value: "\(fingerprint.totalObservations)",
                icon: "eye.circle.fill",
                color: .blue
            )
            StatCard(
                title: "Typical Wake",
                value: formattedHour(fingerprint.typicalWakeTime),
                icon: "sunrise.fill",
                color: .orange
            )
            StatCard(
                title: "Typical Sleep",
                value: formattedHour(fingerprint.typicalSleepTime),
                icon: "moon.fill",
                color: .indigo
            )
            StatCard(
                title: "Responsiveness",
                value: String(format: "%.0f%%", fingerprint.overallResponsiveness * 100),
                icon: "bell.badge.fill",
                color: .green
            )
            StatCard(
                title: "Active Slots",
                value: "\(fingerprint.totalRecordedSlots) / 168",
                icon: "chart.bar.fill",
                color: .purple
            )
            StatCard(
                title: "Awake Now",
                value: fingerprint.isLikelyAwake(at: Calendar.current.component(.hour, from: Date())) ? "Yes" : "No",
                icon: "circle.fill",
                color: fingerprint.isLikelyAwake(at: Calendar.current.component(.hour, from: Date())) ? .green : .gray
            )
        }
    }

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Rhythm")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DayOfWeek.allCases, id: \.rawValue) { day in
                        Button {
                            selectedDay = day
                        } label: {
                            Text(day.rawValue.prefix(3).capitalized)
                                .font(.caption).bold()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedDay == day ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundStyle(selectedDay == day ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var hourlyReceptivityChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Receptivity by Hour — \(selectedDay.rawValue.capitalized)")
                .font(.subheadline).bold()

            if hourlySummary.isEmpty {
                Text("No data recorded yet. Use Thea to build your behavioral profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(hourlySummary, id: \.hour) { slot in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(receptivityColor(slot.receptivity))
                                .frame(width: 14, height: max(4, slot.receptivity * 80))
                            if slot.hour % 6 == 0 {
                                Text("\(slot.hour)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)

                HStack(spacing: 16) {
                    legendItem(color: .green, label: "High receptivity")
                    legendItem(color: .yellow, label: "Moderate")
                    legendItem(color: .red, label: "Low / sleeping")
                }
                .font(.caption)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var activityBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity Distribution — \(selectedDay.rawValue.capitalized)")
                .font(.subheadline).bold()

            let counts = activityCountsForDay(selectedDay)
            if counts.isEmpty {
                Text("No activity data recorded for this day yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(counts, id: \.activity) { item in
                    HStack {
                        Image(systemName: iconForActivity(item.activity))
                            .frame(width: 20)
                            .foregroundStyle(colorForActivity(item.activity))
                        Text(item.activity.rawValue.capitalized)
                            .font(.caption)
                        Spacer()
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorForActivity(item.activity).opacity(0.7))
                                .frame(width: geo.size.width * item.fraction, height: 10)
                        }
                        .frame(height: 10)
                        Text("\(item.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func refreshSummary() {
        hourlySummary = fingerprint.dailySummary(for: selectedDay)
    }

    private func formattedHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h):00 \(suffix)"
    }

    private func receptivityColor(_ value: Double) -> Color {
        switch value {
        case 0.6...: return .green
        case 0.3..<0.6: return .yellow
        default: return .red
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 8)
            Text(label)
        }
    }

    private struct ActivityCount {
        let activity: BehavioralActivityType
        let count: Int
        let fraction: Double
    }

    private func activityCountsForDay(_ day: DayOfWeek) -> [ActivityCount] {
        let slots = fingerprint.timeSlots[day.index]
        var totals: [BehavioralActivityType: Int] = [:]
        for slot in slots {
            for (key, count) in slot.activityCounts {
                if let type = BehavioralActivityType(rawValue: key) {
                    totals[type, default: 0] += count
                }
            }
        }
        let grandTotal = totals.values.reduce(0, +)
        guard grandTotal > 0 else { return [] }
        return totals
            .sorted { $0.value > $1.value }
            .map { ActivityCount(activity: $0.key, count: $0.value, fraction: Double($0.value) / Double(grandTotal)) }
    }

    private func iconForActivity(_ activity: BehavioralActivityType) -> String {
        switch activity {
        case .deepWork:       "brain.head.profile"
        case .meetings:       "video.fill"
        case .browsing:       "globe"
        case .communication:  "bubble.left.and.bubble.right.fill"
        case .exercise:       "figure.run"
        case .leisure:        "gamecontroller.fill"
        case .sleep:          "moon.zzz.fill"
        case .idle:           "circle.dashed"
        case .healthSuggestion: "heart.fill"
        }
    }

    private func colorForActivity(_ activity: BehavioralActivityType) -> Color {
        switch activity {
        case .deepWork:       .blue
        case .meetings:       .purple
        case .browsing:       .cyan
        case .communication:  .green
        case .exercise:       .orange
        case .leisure:        .pink
        case .sleep:          .indigo
        case .idle:           .gray
        case .healthSuggestion: .red
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                Spacer()
            }
            Text(value)
                .font(.title3).bold()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        BehavioralAnalyticsView()
    }
    .frame(width: 700, height: 600)
}
#endif
