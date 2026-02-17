// BehavioralPatternsView.swift
// Thea — Behavioral Fingerprint Visualization

import SwiftUI
import os.log

struct BehavioralPatternsView: View {
    private let fingerprint = BehavioralFingerprint.shared
    @State private var selectedDay: DayOfWeek?
    @State private var selectedHour: Int?

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let days = DayOfWeek.allCases

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                currentContextSection
                heatMapSection
                scheduleSection
                statisticsSection
            }
            .padding()
        }
        .navigationTitle("Behavioral Patterns")
    }

    // MARK: - Current Context

    private var currentContextSection: some View {
        let context = fingerprint.currentContext()
        return Section {
            HStack(spacing: 24) {
                contextCard(
                    title: "Activity",
                    value: displayName(for: context.activity),
                    color: color(for: context.activity)
                )
                contextCard(
                    title: "Receptivity",
                    value: String(format: "%.0f%%", context.receptivity * 100),
                    color: context.receptivity > 0.5 ? .green : .orange
                )
                contextCard(
                    title: "Cognitive Load",
                    value: String(format: "%.0f%%", context.cognitiveLoad * 100),
                    color: context.cognitiveLoad > 0.7 ? .red : .blue
                )
                contextCard(
                    title: "Status",
                    value: context.isAwake ? "Awake" : "Asleep",
                    color: context.isAwake ? .green : .gray
                )
            }
        } header: {
            Text("Current Context")
                .font(.theaHeadline)
        }
    }

    private func contextCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.theaTitle3)
                .foregroundStyle(color)
            Text(title)
                .font(.theaCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Heat Map

    private var heatMapSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                // Hour labels row
                HStack(spacing: 2) {
                    Text("")
                        .frame(width: 32)
                    ForEach(0..<24, id: \.self) { hour in
                        if hour % 3 == 0 {
                            Text("\(hour)")
                                .font(.system(size: 8))
                                .frame(width: 14)
                                .foregroundStyle(.secondary)
                        } else {
                            Spacer().frame(width: 14)
                        }
                    }
                }

                // Grid rows
                ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
                    HStack(spacing: 2) {
                        Text(dayLabels[dayIndex])
                            .font(.theaCaption2)
                            .frame(width: 32, alignment: .leading)
                        ForEach(0..<24, id: \.self) { hour in
                            let activity = fingerprint.dominantActivity(day: day, hour: hour)
                            Rectangle()
                                .fill(color(for: activity).opacity(cellOpacity(day: day, hour: hour)))
                                .frame(width: 14, height: 14)
                                .cornerRadius(2)
                                .onTapGesture {
                                    selectedDay = day
                                    selectedHour = hour
                                }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 12) {
                ForEach(legendItems, id: \.label) { item in
                    HStack(spacing: 4) {
                        Circle().fill(item.color).frame(width: 8, height: 8)
                        Text(item.label).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 4)

            // Selection detail
            if let day = selectedDay, let hour = selectedHour {
                let activity = fingerprint.dominantActivity(day: day, hour: hour)
                let receptivity = fingerprint.receptivity(day: day, hour: hour)
                HStack {
                    Text("\(day.rawValue.capitalized) \(hour):00")
                        .font(.theaCaption1)
                    Spacer()
                    Text(displayName(for: activity))
                        .foregroundStyle(color(for: activity))
                    Text("Receptivity: \(String(format: "%.0f%%", receptivity * 100))")
                        .foregroundStyle(.secondary)
                }
                .font(.theaCaption2)
                .padding(.top, 4)
            }
        } header: {
            Text("Weekly Activity Heat Map")
                .font(.theaHeadline)
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section {
            HStack(spacing: 32) {
                Label("\(fingerprint.typicalWakeTime):00", systemImage: "sunrise.fill")
                    .foregroundStyle(.orange)
                Label("\(fingerprint.typicalSleepTime):00", systemImage: "moon.fill")
                    .foregroundStyle(.indigo)
                Spacer()
                Text("Responsiveness: \(String(format: "%.0f%%", fingerprint.overallResponsiveness * 100))")
                    .foregroundStyle(.secondary)
            }
            .font(.theaBody)
        } header: {
            Text("Sleep Schedule")
                .font(.theaHeadline)
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        Section {
            HStack(spacing: 32) {
                LabeledContent("Observations", value: "\(fingerprint.totalObservations)")
                LabeledContent("Recorded Slots", value: "\(fingerprint.totalRecordedSlots) / 168")
            }
            .font(.theaBody)
        } header: {
            Text("Data")
                .font(.theaHeadline)
        }
    }

    // MARK: - Helpers

    private func color(for activity: BehavioralActivityType) -> Color {
        switch activity {
        case .deepWork: .blue
        case .communication: .green
        case .browsing: .orange
        case .leisure: .purple
        case .sleep: .gray
        case .idle: Color(.separatorColor)
        case .meetings: .teal
        case .exercise: .pink
        case .healthSuggestion: .mint
        }
    }

    private func cellOpacity(day: DayOfWeek, hour: Int) -> Double {
        let slot = fingerprint.timeSlots[day.index][hour]
        let total = slot.activityCounts.values.reduce(0, +)
        guard total > 0 else { return 0.15 }
        return min(0.3 + Double(total) / 20.0, 1.0)
    }

    private func displayName(for activity: BehavioralActivityType) -> String {
        switch activity {
        case .deepWork: "Deep Work"
        case .communication: "Communication"
        case .browsing: "Browsing"
        case .leisure: "Leisure"
        case .sleep: "Sleep"
        case .idle: "Idle"
        case .meetings: "Meetings"
        case .exercise: "Exercise"
        case .healthSuggestion: "Health"
        }
    }

    private var legendItems: [(label: String, color: Color)] {
        [
            ("Deep Work", .blue), ("Communication", .green), ("Browsing", .orange),
            ("Leisure", .purple), ("Sleep", .gray), ("Meetings", .teal),
            ("Exercise", .pink), ("Idle", Color(.separatorColor))
        ]
    }
}

#Preview {
    BehavioralPatternsView()
        .frame(width: 700, height: 500)
}
