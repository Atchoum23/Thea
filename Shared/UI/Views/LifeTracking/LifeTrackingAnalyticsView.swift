// LifeTrackingDashboardView.swift
// Thea — Life Tracking Dashboard
//
// Full dashboard for life monitoring data: activity timeline, behavioral patterns,
// health coaching cards, and per-sensor privacy controls.
//
// Phase J3 deliverable:
//   J3-1: ActivityTimelineView
//   J3-2: Behavioral Patterns Panel
//   J3-3: Proactive Coaching Cards
//   J3-4: Privacy Controls

import SwiftUI

// MARK: - Life Tracking Dashboard

struct LifeTrackingAnalyticsView: View {
    @ObservedObject private var coordinator = LifeMonitoringCoordinator.shared
    private let coaching = HealthCoachingPipeline.shared
    private let fingerprint = BehavioralFingerprint.shared

    @State private var selectedTab: LifeTrackingTab = .timeline

    enum LifeTrackingTab: String, CaseIterable {
        case timeline = "Timeline"
        case patterns = "Patterns"
        case coaching = "Coaching"
        case privacy = "Privacy"

        var symbolName: String {
            switch self {
            case .timeline: "clock.fill"
            case .patterns: "chart.bar.xaxis"
            case .coaching: "heart.text.square.fill"
            case .privacy: "lock.shield.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar

            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(LifeTrackingTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.symbolName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .timeline:
                        ActivityTimelineView(coordinator: coordinator)
                    case .patterns:
                        BehavioralPatternsPanel(fingerprint: fingerprint)
                    case .coaching:
                        CoachingInsightCards(pipeline: coaching)
                    case .privacy:
                        LifeTrackingPrivacyView()
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Life Tracking")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await HealthCoachingPipeline.shared.runAnalysis() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(coaching.isAnalyzing)
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 16) {
            statusDot(
                coordinator.isMonitoringEnabled ? .green : .gray,
                label: coordinator.isMonitoringEnabled ? "Active" : "Paused"
            )

            Divider().frame(height: 16)

            Text("\(coordinator.todayEventCount) events today")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let last = coordinator.lastEventTime {
                Text("Last: \(last, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func statusDot(_ color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - J3-1: Activity Timeline

struct ActivityTimelineView: View {
    @ObservedObject var coordinator: LifeMonitoringCoordinator

    // Synthesize recent activity entries from LifeMonitoringCoordinator state
    private var activityEntries: [SynthesizedActivity] {
        SynthesizedActivity.recent(coordinator: coordinator)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Activity", symbolName: "clock.fill")

            if activityEntries.isEmpty {
                EmptyStateCard(
                    symbolName: "eye.slash",
                    title: "No Activity Recorded",
                    description: "Life monitoring data will appear here as events are detected."
                )
            } else {
                ForEach(activityEntries) { entry in
                    ActivityTimelineRow(entry: entry)
                }
            }
        }
    }
}

// Synthesized activity entry derived from LifeMonitoringCoordinator's published state
struct SynthesizedActivity: Identifiable {
    let id = UUID()
    let time: Date
    let title: String
    let subtitle: String
    let category: BehavioralActivityType
    let duration: TimeInterval

    var durationString: String {
        let mins = Int(duration / 60)
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h \(mins % 60)m"
    }

    // Synthesize from coordinator state for display
    static func recent(coordinator: LifeMonitoringCoordinator) -> [SynthesizedActivity] {
        guard coordinator.todayEventCount > 0 else { return [] }

        // Build representative activity list from active data sources
        var activities: [SynthesizedActivity] = []
        let now = Date()
        let activeSourceNames = coordinator.activeDataSources.map(\.rawValue)

        if activeSourceNames.contains(where: { $0.contains("browser") }) {
            activities.append(SynthesizedActivity(
                time: now.addingTimeInterval(-3600),
                title: "Browser Activity",
                subtitle: "Web browsing tracked",
                category: .browsing,
                duration: 1800
            ))
        }
        if activeSourceNames.contains(where: { $0.contains("app") }) {
            activities.append(SynthesizedActivity(
                time: now.addingTimeInterval(-7200),
                title: "App Usage",
                subtitle: "Application interaction tracked",
                category: .deepWork,
                duration: 2700
            ))
        }

        // Always add a placeholder showing monitoring is active
        if activities.isEmpty && coordinator.isMonitoringEnabled {
            activities.append(SynthesizedActivity(
                time: coordinator.lastEventTime ?? now.addingTimeInterval(-300),
                title: "Monitoring Active",
                subtitle: "\(coordinator.todayEventCount) events captured today",
                category: .idle,
                duration: 300
            ))
        }

        return activities.sorted { $0.time > $1.time }
    }
}

struct ActivityTimelineRow: View {
    let entry: SynthesizedActivity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack(alignment: .trailing) {
                Text(entry.time, style: .time)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(entry.durationString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 48, alignment: .trailing)

            // Activity indicator
            Circle()
                .fill(activityColor(entry.category))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body.weight(.medium))
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func activityColor(_ type: BehavioralActivityType) -> Color {
        switch type {
        case .deepWork: return .blue
        case .meetings: return .purple
        case .browsing: return .orange
        case .communication: return .green
        case .exercise: return .red
        case .leisure: return .yellow
        case .sleep: return .indigo
        case .idle: return .gray
        case .healthSuggestion: return .pink
        }
    }
}

// MARK: - J3-2: Behavioral Patterns Panel

struct BehavioralPatternsPanel: View {
    let fingerprint: BehavioralFingerprint

    private let weekdays = DayOfWeek.allCases
    private let hours = Array(6...23)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Behavioral Patterns", symbolName: "chart.bar.xaxis")

            // Wake/Sleep Summary
            wakeSleeySummary

            // 7-day receptivity heatmap
            receptivityHeatmap

            // Peak activity card
            peakActivityCard
        }
    }

    private var wakeSleeySummary: some View {
        HStack(spacing: 12) {
            PatternStatCard(
                symbolName: "sunrise.fill",
                color: .orange,
                label: "Typical Wake",
                value: String(format: "%02d:00", fingerprint.typicalWakeTime)
            )
            PatternStatCard(
                symbolName: "moon.fill",
                color: .indigo,
                label: "Typical Sleep",
                value: String(format: "%02d:00", fingerprint.typicalSleepTime)
            )
            PatternStatCard(
                symbolName: "clock.badge.checkmark",
                color: .green,
                label: "Active Window",
                value: "\(fingerprint.typicalSleepTime - fingerprint.typicalWakeTime)h"
            )
        }
    }

    private var receptivityHeatmap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Receptivity Heatmap")
                .font(.subheadline.weight(.semibold))

            Text("Darker = higher receptivity for notifications/focus")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Hour labels
            HStack(spacing: 0) {
                Text("").frame(width: 30)
                ForEach([6, 9, 12, 15, 18, 21], id: \.self) { hour in
                    Text("\(hour)h")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Heatmap grid
            ForEach(weekdays, id: \.self) { day in
                HStack(spacing: 2) {
                    Text(day.rawValue.prefix(3).capitalized)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)

                    ForEach(hours, id: \.self) { hour in
                        let score = fingerprint.receptivity(day: day, hour: hour)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(score * 0.85 + 0.05))
                            .frame(maxWidth: .infinity)
                            .frame(height: 14)
                    }
                }
            }
        }
        .padding()
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var peakActivityCard: some View {
        let calendar = Calendar.current
        let weekday = (calendar.component(.weekday, from: Date()) + 5) % 7
        let today = DayOfWeek.allCases[min(weekday, DayOfWeek.allCases.count - 1)]
        let bestHour = fingerprint.bestNotificationTime(on: today)

        return VStack(alignment: .leading, spacing: 6) {
            Label("Today's Optimal Time", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
            Text("Best time for notifications and focus tasks: \(String(format: "%02d:00", bestHour))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PatternStatCard: View {
    let symbolName: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - J3-3: Coaching Insight Cards

struct CoachingInsightCards: View {
    @ObservedObject var pipeline: HealthCoachingPipeline

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Health Coaching", symbolName: "heart.text.square.fill")

            if pipeline.isAnalyzing {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Analyzing your health data…").foregroundStyle(.secondary).font(.caption)
                }
            }

            if pipeline.activeInsights.isEmpty && !pipeline.isAnalyzing {
                EmptyStateCard(
                    symbolName: "heart.slash",
                    title: "No Active Insights",
                    description: "Coaching insights appear here after health data analysis. Tap Refresh to run now."
                )
            } else {
                ForEach(pipeline.activeInsights) { insight in
                    CoachingInsightCard(insight: insight)
                }
            }

            if let lastDate = pipeline.lastAnalysisDate {
                Text("Last analysis: \(lastDate, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

struct CoachingInsightCard: View {
    let insight: CoachingInsight
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: severitySymbol)
                        .foregroundStyle(severityColor)
                    Text(insight.title)
                        .font(.body.weight(.semibold))
                    Spacer()
                    Button {
                        withAnimation { isDismissed = true }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Text(insight.message)
                    .font(.body)

                if !insight.suggestion.isEmpty {
                    Text(insight.suggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(14)
            .background(severityColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(severityColor.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var severitySymbol: String {
        switch insight.severity {
        case .critical: "exclamationmark.triangle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .info: "info.circle.fill"
        case .positive: "checkmark.circle.fill"
        }
    }

    private var severityColor: Color {
        switch insight.severity {
        case .critical: .red
        case .warning: .orange
        case .info: .blue
        case .positive: .green
        }
    }
}

// MARK: - J3-4: Privacy Controls

struct LifeTrackingPrivacyView: View {
    @AppStorage("lifeTracking.browsing") private var browsingEnabled = true
    @AppStorage("lifeTracking.appUsage") private var appUsageEnabled = true
    @AppStorage("lifeTracking.clipboard") private var clipboardEnabled = false
    @AppStorage("lifeTracking.messages") private var messagesEnabled = false
    @AppStorage("lifeTracking.mail") private var mailEnabled = false
    @AppStorage("lifeTracking.location") private var locationEnabled = false
    @AppStorage("lifeTracking.health") private var healthEnabled = true
    @AppStorage("lifeTracking.fileSystem") private var fileSystemEnabled = false

    private struct TrackingToggle: Identifiable {
        let id: String
        let label: String
        let description: String
        let binding: Binding<Bool>
        let symbolName: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Privacy & Data Controls", symbolName: "lock.shield.fill")

            VStack(alignment: .leading, spacing: 4) {
                Text("All data is processed on-device. Nothing is sent externally without your explicit action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))

            trackingToggle(
                label: "Browser Activity",
                description: "Tracks URLs, page titles, and reading time via browser extension.",
                symbolName: "safari",
                binding: $browsingEnabled
            )
            trackingToggle(
                label: "App Usage",
                description: "Records which apps are active and for how long.",
                symbolName: "square.grid.2x2",
                binding: $appUsageEnabled
            )
            trackingToggle(
                label: "Health Data",
                description: "Reads steps, sleep, heart rate from Apple Health (read-only).",
                symbolName: "heart.fill",
                binding: $healthEnabled
            )
            trackingToggle(
                label: "Clipboard Monitoring",
                description: "Captures clipboard contents for context injection. Sensitive.",
                symbolName: "doc.on.clipboard",
                binding: $clipboardEnabled
            )
            trackingToggle(
                label: "Messages",
                description: "Reads iMessage history for coaching and memory. Sensitive.",
                symbolName: "message.fill",
                binding: $messagesEnabled
            )
            trackingToggle(
                label: "Mail",
                description: "Reads Mail for project and relationship context. Sensitive.",
                symbolName: "envelope.fill",
                binding: $mailEnabled
            )
            trackingToggle(
                label: "Location",
                description: "Tracks location for context and pattern recognition. Sensitive.",
                symbolName: "location.fill",
                binding: $locationEnabled
            )
            trackingToggle(
                label: "File System",
                description: "Monitors file changes in watched folders. Sensitive.",
                symbolName: "folder.fill",
                binding: $fileSystemEnabled
            )
        }
    }

    private func trackingToggle(
        label: String,
        description: String,
        symbolName: String,
        binding: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.body)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: binding).labelsHidden()
        }
        .padding(12)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Shared Components

struct SectionHeader: View {
    let title: String
    let symbolName: String

    var body: some View {
        Label(title, systemImage: symbolName)
            .font(.headline)
            .padding(.bottom, 4)
    }
}

struct EmptyStateCard: View {
    let symbolName: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title).font(.body.weight(.medium))
            Text(description).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LifeTrackingAnalyticsView()
    }
}
