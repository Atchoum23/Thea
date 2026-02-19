//
//  LifeTrackingDashboardView.swift
//  Thea
//
//  Comprehensive life tracking dashboard
//  Shows real-time activity across all monitored data sources
//

import Charts
import SwiftUI

// MARK: - Life Tracking Dashboard

public struct LifeTrackingDashboardView: View {
    @StateObject private var viewModel = LifeTrackingDashboardViewModel()

    @State private var selectedTimeRange: LifeTrackingTimeRange = .today
    @State private var showingSettings = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range picker
                    timeRangePicker

                    // Quick stats cards
                    quickStatsSection

                    // Activity timeline
                    if !viewModel.recentEvents.isEmpty {
                        activityTimelineSection
                    }

                    // Data sources grid
                    dataSourcesSection

                    // Category breakdown
                    categoryBreakdownSection

                    // Recent activity list
                    recentActivitySection
                }
                .padding()
            }
            .navigationTitle("Life Tracking")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                LifeTrackingDashboardSettingsView()
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(LifeTrackingTimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedTimeRange) { _, newValue in
            Task {
                await viewModel.loadData(for: newValue)
            }
        }
    }

    // MARK: - Quick Stats Section

    private var quickStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            QuickStatCard(
                title: "Total Events",
                value: "\(viewModel.totalEvents)",
                icon: "chart.bar.fill",
                color: .blue
            )

            QuickStatCard(
                title: "Active Sources",
                value: "\(viewModel.activeSources)",
                icon: "antenna.radiowaves.left.and.right",
                color: .green
            )

            QuickStatCard(
                title: "Screen Time",
                value: viewModel.formattedScreenTime,
                icon: "display",
                color: .purple
            )

            QuickStatCard(
                title: "Media Time",
                value: viewModel.formattedMediaTime,
                icon: "play.circle",
                color: .orange
            )
        }
    }

    // MARK: - Activity Timeline Section

    private var activityTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Timeline")
                .font(.headline)

            if #available(iOS 16.0, macOS 13.0, *) {
                Chart(viewModel.hourlyActivity, id: \.hour) { item in
                    BarMark(
                        x: .value("Hour", item.hour),
                        y: .value("Events", item.count)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .stride(by: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text("\(hour):00")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // MARK: - Data Sources Section

    private var dataSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Sources")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100, maximum: 150))
            ], spacing: 12) {
                ForEach(viewModel.dataSourceStats, id: \.type) { source in
                    DataSourceCard(source: source)
                }
            }
        }
    }

    // MARK: - Category Breakdown Section

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Categories")
                .font(.headline)

            ForEach(viewModel.categoryStats, id: \.category) { stat in
                LifeTrackingCategoryRow(stat: stat)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)

                Spacer()

                NavigationLink("See All") {
                    ActivityListView()
                }
                .font(.subheadline)
            }

            ForEach(viewModel.recentEvents.prefix(10)) { event in
                ActivityRow(event: event)
            }
        }
    }

    // MARK: - Helpers

    private var cardBackgroundColor: Color {
        #if os(macOS)
            Color(NSColor.windowBackgroundColor)
        #else
            Color(UIColor.systemBackground)
        #endif
    }
}

// MARK: - Quick Stat Card

private struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Data Source Card

private struct DataSourceCard: View {
    let source: DataSourceStat

    private var cardBackgroundColor: Color {
        #if os(macOS)
            Color(NSColor.windowBackgroundColor)
        #else
            Color(UIColor.systemBackground)
        #endif
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(source.isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: source.icon)
                    .foregroundColor(source.isActive ? .green : .gray)
            }

            Text(source.displayName)
                .font(.caption)
                .lineLimit(1)

            Text("\(source.eventCount)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3)
    }
}

// MARK: - Category Row

private struct LifeTrackingCategoryRow: View {
    let stat: CategoryStat

    var body: some View {
        HStack {
            Image(systemName: stat.icon)
                .foregroundColor(stat.color)
                .frame(width: 24)

            Text(stat.category.displayName)

            Spacer()

            Text("\(stat.count)")
                .foregroundColor(.secondary)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    Rectangle()
                        .fill(stat.color)
                        .frame(width: geometry.size.width * stat.percentage, height: 4)
                }
            }
            .frame(width: 60, height: 4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let event: LifeEventDisplay

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(event.color.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: event.icon)
                    .foregroundColor(event.color)
                    .font(.system(size: 14))
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.summary)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(event.sourceName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Time
            Text(event.timeAgo)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Types

enum LifeTrackingTimeRange: String, CaseIterable {
    case today
    case yesterday
    case thisWeek
    case thisMonth

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "Week"
        case .thisMonth: return "Month"
        }
    }
}

enum LifeActivityCategory: String, CaseIterable {
    case communication
    case productivity
    case entertainment
    case health
    case social
    case home

    var displayName: String {
        switch self {
        case .communication: return "Communication"
        case .productivity: return "Productivity"
        case .entertainment: return "Entertainment"
        case .health: return "Health"
        case .social: return "Social"
        case .home: return "Home"
        }
    }

    var icon: String {
        switch self {
        case .communication: return "message"
        case .productivity: return "doc.text"
        case .entertainment: return "play.circle"
        case .health: return "heart"
        case .social: return "person.2"
        case .home: return "house"
        }
    }

    var color: Color {
        switch self {
        case .communication: return .blue
        case .productivity: return .orange
        case .entertainment: return .purple
        case .health: return .red
        case .social: return .green
        case .home: return .cyan
        }
    }
}

struct DataSourceStat: Identifiable {
    var id: String { type.rawValue }
    let type: DataSourceType
    let displayName: String
    let icon: String
    let eventCount: Int
    let isActive: Bool
}

struct CategoryStat {
    let category: LifeActivityCategory
    let count: Int
    let percentage: Double
    let icon: String
    let color: Color
}

struct LifeEventDisplay: Identifiable {
    let id: UUID
    let summary: String
    let sourceName: String
    let icon: String
    let color: Color
    let timestamp: Date

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

struct HourlyActivity {
    let hour: Int
    let count: Int
}

// MARK: - View Model

@MainActor
class LifeTrackingDashboardViewModel: ObservableObject {
    @Published var totalEvents = 0
    @Published var activeSources = 0
    @Published var formattedScreenTime = "0h"
    @Published var formattedMediaTime = "0h"
    @Published var recentEvents: [LifeEventDisplay] = []
    @Published var dataSourceStats: [DataSourceStat] = []
    @Published var categoryStats: [CategoryStat] = []
    @Published var hourlyActivity: [HourlyActivity] = []

    private let coordinator = LifeMonitoringCoordinator.shared

    // periphery:ignore - Reserved: _timeRange parameter kept for API compatibility
    func loadData(for _timeRange: LifeTrackingTimeRange = .today) async {
        let stats = coordinator.getStatistics()

        totalEvents = stats.todayEventCount
        activeSources = stats.activeSources.count

        // Screen time from AppUsageMonitor (real app usage tracking via NSWorkspace/ProcessInfo)
        let appUsageStats = AppUsageMonitor.shared.getStats(for: .today)
        formattedScreenTime = appUsageStats.formattedScreenTime

        // Media time from MediaMonitor (real MPNowPlayingInfoCenter tracking)
        let mediaStats = MediaMonitor.shared.getStatistics(for: .today)
        let totalMediaSeconds = mediaStats.totalMusicTime + mediaStats.totalVideoTime
        let mediaHours = Int(totalMediaSeconds) / 3600
        let mediaMinutes = (Int(totalMediaSeconds) % 3600) / 60
        formattedMediaTime = mediaHours > 0 ? "\(mediaHours)h \(mediaMinutes)m" : "\(mediaMinutes)m"

        // Build data source stats from real per-source event counts
        let topApps = AppUsageMonitor.shared.getTopApps(limit: 50, period: .today)
        var eventsBySource: [DataSourceType: Int] = [:]
        for record in topApps {
            let source: DataSourceType = switch record.app.category {
            case .browser: .browserExtension
            case .social, .communication: .messages
            case .entertainment, .games: .media
            default: .appUsage
            }
            eventsBySource[source, default: 0] += 1
        }
        dataSourceStats = DataSourceType.allCases.map { type in
            let isActive = stats.activeSources.contains(type)
            return DataSourceStat(
                type: type,
                displayName: type.displayName,
                icon: type.icon,
                eventCount: eventsBySource[type] ?? 0,
                isActive: isActive
            )
        }

        // Build category stats from real app usage breakdown
        let categoryBreakdown = appUsageStats.categoryBreakdown
        let totalTime = max(1.0, appUsageStats.totalScreenTime)
        categoryStats = LifeActivityCategory.allCases.map { category in
            let matchingTime = categoryTimeForLifeCategory(category, from: categoryBreakdown)
            let count = Int(matchingTime / 60) // minutes
            let proportion = matchingTime / totalTime
            return CategoryStat(
                category: category,
                count: count,
                percentage: proportion,
                icon: category.icon,
                color: category.color
            )
        }

        // Build hourly activity from real app usage session history
        let todayApps = AppUsageMonitor.shared.getTopApps(limit: 200, period: .today)
        var hourCounts = [Int](repeating: 0, count: 24)
        for record in todayApps {
            let hour = Calendar.current.component(.hour, from: record.date)
            hourCounts[hour] += 1
        }
        hourlyActivity = (0..<24).map { hour in
            HourlyActivity(hour: hour, count: hourCounts[hour])
        }
    }

    private func categoryTimeForLifeCategory(
        _ lifeCategory: LifeActivityCategory,
        from breakdown: [AppCategory: TimeInterval]
    ) -> TimeInterval {
        switch lifeCategory {
        case .productivity:
            return (breakdown[.productivity] ?? 0) + (breakdown[.development] ?? 0) + (breakdown[.education] ?? 0)
        case .communication:
            return (breakdown[.communication] ?? 0)
        case .entertainment:
            return (breakdown[.entertainment] ?? 0) + (breakdown[.games] ?? 0)
        case .health:
            return breakdown[.health] ?? 0
        case .social:
            return breakdown[.social] ?? 0
        case .home:
            return (breakdown[.utility] ?? 0) + (breakdown[.other] ?? 0)
        }
    }

    func refresh() async {
        await loadData()
    }
}

// MARK: - Activity List View

struct ActivityListView: View {
    @State private var events: [LifeEventDisplay] = []

    var body: some View {
        List(events) { event in
            ActivityRow(event: event)
        }
        .navigationTitle("All Activity")
        .task {
            // Load all events
        }
    }
}

// MARK: - Settings View

struct LifeTrackingDashboardSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config = LifeMonitoringConfiguration()

    var body: some View {
        NavigationStack {
            Form {
                Section("Data Sources") {
                    Toggle("Browser Activity", isOn: $config.browserMonitoringEnabled)
                    Toggle("Clipboard", isOn: $config.clipboardMonitoringEnabled)
                    Toggle("Messages", isOn: $config.messagesMonitoringEnabled)
                    Toggle("Mail", isOn: $config.mailMonitoringEnabled)
                    Toggle("Files", isOn: $config.fileSystemMonitoringEnabled)
                }

                Section("Extended Sources") {
                    Toggle("Calendar", isOn: $config.calendarMonitoringEnabled)
                    Toggle("Reminders", isOn: $config.remindersMonitoringEnabled)
                    Toggle("HomeKit", isOn: $config.homeKitMonitoringEnabled)
                    Toggle("Shortcuts", isOn: $config.shortcutsMonitoringEnabled)
                    Toggle("Media", isOn: $config.mediaMonitoringEnabled)
                    Toggle("Photos", isOn: $config.photosMonitoringEnabled)
                    Toggle("Notifications", isOn: $config.notificationMonitoringEnabled)
                }

                Section("Social") {
                    Toggle("Social Media", isOn: $config.socialMediaMonitoringEnabled)
                    Toggle("App Usage", isOn: $config.appUsageMonitoringEnabled)
                    Toggle("Interaction Tracking", isOn: $config.interactionTrackingEnabled)
                }

                Section("Cloud") {
                    Toggle("iCloud Sync", isOn: $config.iCloudSyncEnabled)
                    Toggle("AI Analysis", isOn: $config.aiAnalysisEnabled)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            await LifeMonitoringCoordinator.shared.updateConfiguration(config)
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LifeTrackingDashboardView()
}
