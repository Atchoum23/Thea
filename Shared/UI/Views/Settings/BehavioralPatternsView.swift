// BehavioralPatternsView.swift
// Thea — Behavioral Fingerprint Visualization

import SwiftUI
import os.log

struct BehavioralPatternsView: View {
    private let fingerprint = BehavioralFingerprint.shared
    @State private var selectedDay: DayOfWeek?
    @State private var selectedHour: Int?
    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

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
        let ctx = fingerprint.currentContext()
        return Section {
            HStack(spacing: 24) {
                ctxCard("Activity", displayName(ctx.activity), color(for: ctx.activity))
                ctxCard("Receptivity", pct(ctx.receptivity), ctx.receptivity > 0.5 ? .green : .orange)
                ctxCard("Cognitive Load", pct(ctx.cognitiveLoad), ctx.cognitiveLoad > 0.7 ? .red : .blue)
                ctxCard("Status", ctx.isAwake ? "Awake" : "Asleep", ctx.isAwake ? .green : .gray)
            }
        } header: { Text("Current Context").font(.theaHeadline) }
    }

    private func ctxCard(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.theaTitle3).foregroundStyle(tint)
            Text(title).font(.theaCaption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Heat Map
    private var heatMapSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Text("").frame(width: 32)
                    ForEach(0..<24, id: \.self) { h in
                        if h % 3 == 0 {
                            Text("\(h)").font(.system(size: 8)).frame(width: 14).foregroundStyle(.secondary)
                        } else { Spacer().frame(width: 14) }
                    }
                }
                ForEach(Array(DayOfWeek.allCases.enumerated()), id: \.offset) { i, day in
                    HStack(spacing: 2) {
                        Text(dayLabels[i]).font(.theaCaption2).frame(width: 32, alignment: .leading)
                        ForEach(0..<24, id: \.self) { h in
                            Rectangle()
                                .fill(color(for: fingerprint.dominantActivity(day: day, hour: h))
                                    .opacity(cellOpacity(day: day, hour: h)))
                                .frame(width: 14, height: 14).cornerRadius(2)
                                .onTapGesture { selectedDay = day; selectedHour = h }
                        }
                    }
                }
            }
            // Legend
            HStack(spacing: 10) {
                ForEach(legendItems, id: \.0) { label, clr in
                    HStack(spacing: 3) {
                        Circle().fill(clr).frame(width: 7, height: 7)
                        Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }.padding(.top, 4)
            // Selection detail
            if let day = selectedDay, let hour = selectedHour {
                let act = fingerprint.dominantActivity(day: day, hour: hour)
                HStack {
                    Text("\(day.rawValue.capitalized) \(hour):00").font(.theaCaption1)
                    Spacer()
                    Text(displayName(act)).foregroundStyle(color(for: act))
                    Text("Receptivity: \(pct(fingerprint.receptivity(day: day, hour: hour)))").foregroundStyle(.secondary)
                }.font(.theaCaption2).padding(.top, 4)
            }
        } header: { Text("Weekly Activity Heat Map").font(.theaHeadline) }
    }

    // MARK: - Schedule & Stats
    private var scheduleSection: some View {
        Section {
            HStack(spacing: 32) {
                Label("\(fingerprint.typicalWakeTime):00", systemImage: "sunrise.fill").foregroundStyle(.orange)
                Label("\(fingerprint.typicalSleepTime):00", systemImage: "moon.fill").foregroundStyle(.indigo)
                Spacer()
                Text("Responsiveness: \(pct(fingerprint.overallResponsiveness))").foregroundStyle(.secondary)
            }.font(.theaBody)
        } header: { Text("Sleep Schedule").font(.theaHeadline) }
    }

    private var statisticsSection: some View {
        Section {
            HStack(spacing: 32) {
                LabeledContent("Observations", value: "\(fingerprint.totalObservations)")
                LabeledContent("Recorded Slots", value: "\(fingerprint.totalRecordedSlots) / 168")
            }.font(.theaBody)
        } header: { Text("Data").font(.theaHeadline) }
    }

    // MARK: - Helpers
    private func pct(_ v: Double) -> String { String(format: "%.0f%%", v * 100) }

    private func color(for a: BehavioralActivityType) -> Color {
        switch a {
        case .deepWork: .blue; case .communication: .green; case .browsing: .orange
        case .leisure: .purple; case .sleep: .gray; case .idle: Color(.separatorColor)
        case .meetings: .teal; case .exercise: .pink; case .healthSuggestion: .mint
        }
    }

    private func cellOpacity(day: DayOfWeek, hour: Int) -> Double {
        let total = fingerprint.timeSlots[day.index][hour].activityCounts.values.reduce(0, +)
        return total > 0 ? min(0.3 + Double(total) / 20.0, 1.0) : 0.15
    }

    private func displayName(_ a: BehavioralActivityType) -> String {
        switch a {
        case .deepWork: "Deep Work"; case .communication: "Communication"; case .browsing: "Browsing"
        case .leisure: "Leisure"; case .sleep: "Sleep"; case .idle: "Idle"
        case .meetings: "Meetings"; case .exercise: "Exercise"; case .healthSuggestion: "Health"
        }
    }

    private var legendItems: [(String, Color)] {
        [("Deep Work", .blue), ("Comms", .green), ("Browse", .orange), ("Leisure", .purple),
         ("Sleep", .gray), ("Meetings", .teal), ("Exercise", .pink), ("Idle", Color(.separatorColor))]
    }
}

#Preview { BehavioralPatternsView().frame(width: 700, height: 500) }
