@preconcurrency import SwiftData
import SwiftUI

// MARK: - Life Tracking Dashboard

struct LifeTrackingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedDate = Date()
    @State private var healthSnapshot: HealthSnapshot?
    @State private var screenTimeRecord: DailyScreenTimeRecord?
    @State private var inputStats: DailyInputStatistics?
    @State private var insights: [LifeInsight] = []

    private var config: LifeTrackingConfiguration {
        AppConfiguration.shared.lifeTrackingConfig
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    trackingStatusSection

                    if healthSnapshot != nil || screenTimeRecord != nil || inputStats != nil {
                        healthSection
                        activitySection
                        insightsSection
                    } else {
                        emptyStateSection
                    }
                }
                .padding()
            }
            .navigationTitle("Life Tracking")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .accessibilityLabel("Tracking date")
                        .accessibilityHint("Select a date to view life tracking data")
                }
            }
            .task(id: selectedDate) {
                await loadData()
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        // Fetch health snapshot
        let healthDescriptor = FetchDescriptor<HealthSnapshot>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        healthSnapshot = try? modelContext.fetch(healthDescriptor).first

        // Fetch screen time
        let screenDescriptor = FetchDescriptor<DailyScreenTimeRecord>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        screenTimeRecord = try? modelContext.fetch(screenDescriptor).first

        // Fetch input stats
        let inputDescriptor = FetchDescriptor<DailyInputStatistics>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        inputStats = try? modelContext.fetch(inputDescriptor).first

        // Fetch recent insights
        var insightDescriptor = FetchDescriptor<LifeInsight>(
            sortBy: [SortDescriptor(\LifeInsight.date, order: .reverse)]
        )
        insightDescriptor.fetchLimit = 5
        insights = (try? modelContext.fetch(insightDescriptor)) ?? []
    }

    // MARK: - Tracking Status

    private var trackingStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracking Status")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                #if os(iOS) || os(watchOS)
                if config.healthTrackingEnabled {
                    TrackingStatusRow(title: "Health Tracking", isEnabled: true)
                }

                if config.locationTrackingEnabled {
                    TrackingStatusRow(title: "Location Tracking", isEnabled: true)
                }
                #endif

                #if os(macOS)
                if config.screenTimeTrackingEnabled {
                    TrackingStatusRow(title: "Screen Time", isEnabled: true)
                }

                if config.inputTrackingEnabled {
                    TrackingStatusRow(title: "Input Activity", isEnabled: true)
                }
                #endif

                if config.browserTrackingEnabled {
                    TrackingStatusRow(title: "Browsing History", isEnabled: true)
                }
            }
            .padding()
            #if os(macOS)
            .background(Color(NSColor.controlBackgroundColor))
            #else
            .background(Color(.secondarySystemBackground))
            #endif
            .cornerRadius(12)
        }
    }

    // MARK: - Health Section

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let snapshot = healthSnapshot {
                    StatCard(
                        title: "Steps",
                        value: "\(snapshot.steps)",
                        icon: "figure.walk",
                        color: .green
                    )

                    StatCard(
                        title: "Calories",
                        value: String(format: "%.0f", snapshot.activeCalories),
                        icon: "flame.fill",
                        color: .orange
                    )

                    if let hr = snapshot.heartRateAverage {
                        StatCard(
                            title: "Avg Heart Rate",
                            value: String(format: "%.0f bpm", hr),
                            icon: "heart.fill",
                            color: .red
                        )
                    }

                    if snapshot.sleepDuration > 0 {
                        let hours = snapshot.sleepDuration / 3600
                        StatCard(
                            title: "Sleep",
                            value: String(format: "%.1fh", hours),
                            icon: "moon.fill",
                            color: .indigo
                        )
                    }

                    if snapshot.workoutMinutes > 0 {
                        StatCard(
                            title: "Workout",
                            value: "\(snapshot.workoutMinutes) min",
                            icon: "dumbbell.fill",
                            color: .blue
                        )
                    }
                }
            }
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let screen = screenTimeRecord {
                    let hours = screen.totalScreenTime / 3600
                    StatCard(
                        title: "Screen Time",
                        value: String(format: "%.1fh", hours),
                        icon: "desktopcomputer",
                        color: .blue
                    )

                    StatCard(
                        title: "Focus Time",
                        value: "\(screen.focusTimeMinutes) min",
                        icon: "brain.head.profile",
                        color: .purple
                    )

                    if screen.productivityScore > 0 {
                        StatCard(
                            title: "Productivity",
                            value: String(format: "%.0f%%", screen.productivityScore * 100),
                            icon: "chart.bar.fill",
                            color: .green
                        )
                    }
                }

                if let input = inputStats {
                    StatCard(
                        title: "Keystrokes",
                        value: formatNumber(input.keystrokes),
                        icon: "keyboard",
                        color: .teal
                    )

                    StatCard(
                        title: "Active Time",
                        value: "\(input.activeMinutes) min",
                        icon: "clock.fill",
                        color: .cyan
                    )
                }
            }
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        Group {
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Insights")
                        .font(.headline)

                    ForEach(insights) { insight in
                        InsightRow(insight: insight)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            Text("No Data for This Date")
                .font(.title2)
                .bold()

            Text("Life tracking data will appear here as it's collected throughout the day.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000)
        }
        return "\(number)"
    }
}

// MARK: - Supporting Views

struct TrackingStatusRow: View {
    let title: String
    let isEnabled: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(isEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(title)
                .font(.body)

            Spacer()

            Text(isEnabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isEnabled ? "enabled" : "disabled")")
    }
}

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
                    .accessibilityHidden(true)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(.secondarySystemBackground))
        #endif
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct InsightRow: View {
    let insight: LifeInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: insightIcon)
                    .foregroundStyle(priorityColor)
                    .accessibilityHidden(true)

                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(insight.priority)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor.opacity(0.15))
                    .foregroundStyle(priorityColor)
                    .cornerRadius(4)
            }

            Text(insight.insightDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(.secondarySystemBackground))
        #endif
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title), \(insight.priority) priority. \(insight.insightDescription)")
    }

    private var insightIcon: String {
        switch insight.insightType {
        case "health": "heart.text.clipboard"
        case "productivity": "chart.bar"
        case "activity": "figure.walk"
        default: "lightbulb"
        }
    }

    private var priorityColor: Color {
        switch insight.priority {
        case "critical": .red
        case "high": .orange
        case "medium": .yellow
        case "low": .green
        default: .secondary
        }
    }
}
