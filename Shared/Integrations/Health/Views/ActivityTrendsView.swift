import Charts
import SwiftUI

/// Activity pattern visualization and trend analysis
@MainActor
public struct ActivityActivityTrendsView: View {
    @State private var viewModel = ActivityActivityTrendsViewModel()
    @State private var selectedMetric: ActivityMetric = .steps
    @State private var selectedTimeRange: ActivityTimeRange = .week

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Metric Selector
                metricPicker

                // Time Range Selector
                timeRangePicker

                // Current Stats Card
                currentStatsCard

                // ActivityTrend Chart
                trendChartSection

                // Daily Patterns
                dailyPatternsSection

                // Activity Insights
                insightsSection

                // Goals Progress
                goalsProgressSection

                // Activity Streaks
                streaksSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Activity ActivityTrends")
        .task {
            await viewModel.loadData(metric: selectedMetric, timeRange: selectedTimeRange)
        }
        .onChange(of: selectedMetric) { _, newValue in
            Task {
                await viewModel.loadData(metric: newValue, timeRange: selectedTimeRange)
            }
        }
        .onChange(of: selectedTimeRange) { _, newValue in
            Task {
                await viewModel.loadData(metric: selectedMetric, timeRange: newValue)
            }
        }
    }

    // MARK: - Metric Picker

    private var metricPicker: some View {
        Picker("Activity Metric", selection: $selectedMetric) {
            ForEach(ActivityMetric.allCases, id: \.self) { metric in
                Label(metric.displayName, systemImage: metric.icon)
                    .tag(metric)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(ActivityTimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Current Stats Card

    private var currentStatsCard: some View {
        HStack(spacing: 24) {
            // Today's value
            VStack(spacing: 8) {
                Image(systemName: selectedMetric.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(selectedMetric.color)

                Text(viewModel.todayValue)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(selectedMetric.color)

                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Average value
            VStack(spacing: 8) {
                Text(selectedTimeRange.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(viewModel.averageValue)
                    .font(.title3)
                    .bold()

                Text("Average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // ActivityTrend indicator
            VStack(spacing: 8) {
                Image(systemName: viewModel.trend.iconName)
                    .font(.title2)
                    .foregroundStyle(viewModel.trend.color)

                Text(viewModel.trendPercentage)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(viewModel.trend.color)

                Text(viewModel.trend.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - ActivityTrend Chart Section

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ActivityTrend Analysis")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(viewModel.chartData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.unit, dataPoint.value)
                    )
                    .foregroundStyle(selectedMetric.color)
                    .symbol(.circle)

                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.unit, dataPoint.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [selectedMetric.color.opacity(0.3), selectedMetric.color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // Goal line
                if let goal = viewModel.goalValue {
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(.green.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .padding(4)
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                }
            }
            .frame(height: 250)
            .chartYAxisLabel(selectedMetric.unit, position: .leading)
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Daily Patterns Section

    private var dailyPatternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Activity Patterns")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(viewModel.hourlyData) { hourData in
                    BarMark(
                        x: .value("Hour", hourData.hour),
                        y: .value(selectedMetric.unit, hourData.value)
                    )
                    .foregroundStyle(selectedMetric.color.gradient)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(formatHour(hour))
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxisLabel(selectedMetric.unit, position: .leading)
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Insights")
                .font(.headline)
                .padding(.horizontal)

            if viewModel.insights.isEmpty {
                EmptyInsightsView()
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.insights) { insight in
                        ActivityInsightCard(insight: insight)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Goals Progress Section

    private var goalsProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goals Progress")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(viewModel.goals) { goal in
                    GoalProgressRow(goal: goal)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Streaks Section

    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Streaks")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StreakCard(
                    title: "Current Streak",
                    value: "\(viewModel.currentStreak)",
                    unit: "days",
                    icon: "flame.fill",
                    color: .orange
                )

                StreakCard(
                    title: "Longest Streak",
                    value: "\(viewModel.longestStreak)",
                    unit: "days",
                    icon: "star.fill",
                    color: .yellow
                )

                StreakCard(
                    title: "Total Active Days",
                    value: "\(viewModel.totalActiveDays)",
                    unit: "days",
                    icon: "calendar.badge.checkmark",
                    color: .green
                )

                StreakCard(
                    title: "This Month",
                    value: "\(viewModel.activeDaysThisMonth)",
                    unit: "days",
                    icon: "calendar",
                    color: .blue
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
}

// MARK: - Empty Insights View

private struct EmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lightbulb")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No insights yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Keep tracking to generate insights")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Activity Insight Card

private struct ActivityInsightCard: View {
    let insight: ActivityInsight

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title2)
                .foregroundStyle(insight.type.color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .bold()

                Text(insight.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(insight.type.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(insight.type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Goal Progress Row

private struct GoalProgressRow: View {
    let goal: ActivityGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.name)
                    .font(.subheadline)
                    .bold()

                Spacer()

                Text("\(Int(goal.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(goal.progressColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [goal.progressColor, goal.progressColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * goal.progress, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(goal.current) / \(goal.target) \(goal.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if goal.progress >= 1.0 {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Streak Card

private struct StreakCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(spacing: 4) {
                Text(value)
                    .font(.title)
                    .bold()
                    .foregroundStyle(color)

                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Models

public enum ActivityMetric: String, CaseIterable, Sendable {
    case steps
    case distance
    case calories
    case activeMinutes

    public var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .distance: return "Distance"
        case .calories: return "Calories"
        case .activeMinutes: return "Active Minutes"
        }
    }

    public var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .distance: return "map"
        case .calories: return "flame.fill"
        case .activeMinutes: return "timer"
        }
    }

    public var unit: String {
        switch self {
        case .steps: return "steps"
        case .distance: return "km"
        case .calories: return "kcal"
        case .activeMinutes: return "minutes"
        }
    }

    public var color: Color {
        switch self {
        case .steps: return .green
        case .distance: return .blue
        case .calories: return .orange
        case .activeMinutes: return .purple
        }
    }
}

public enum ActivityTimeRange: String, CaseIterable, Sendable {
    case week = "Week"
    case month = "Month"
    case quarter = "3 Months"
    case year = "Year"

    public var displayName: String { rawValue }

    public var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

public struct ActivityDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public var date: Date
    public var value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct HourlyActivityData: Identifiable, Sendable {
    public let id = UUID()
    public var hour: Int
    public var value: Double

    public init(hour: Int, value: Double) {
        self.hour = hour
        self.value = value
    }
}

public struct ActivityInsight: Identifiable, Sendable {
    public let id = UUID()
    public var type: ActivityInsightType
    public var title: String
    public var message: String
    public var icon: String

    public init(type: ActivityInsightType, title: String, message: String, icon: String) {
        self.type = type
        self.title = title
        self.message = message
        self.icon = icon
    }
}

public enum ActivityInsightType: Sendable {
    case positive
    case neutral
    case warning

    var color: Color {
        switch self {
        case .positive: return .green
        case .neutral: return .blue
        case .warning: return .orange
        }
    }

    var backgroundColor: Color {
        color.opacity(0.05)
    }
}

public struct ActivityGoal: Identifiable, Sendable {
    public let id = UUID()
    public var name: String
    public var current: Int
    public var target: Int
    public var unit: String

    public var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    public var progressColor: Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.75 { return .blue }
        if progress >= 0.5 { return .yellow }
        return .orange
    }

    public init(name: String, current: Int, target: Int, unit: String) {
        self.name = name
        self.current = current
        self.target = target
        self.unit = unit
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class ActivityActivityTrendsViewModel {
    var todayValue: String = "0"
    var averageValue: String = "0"
    var trendPercentage: String = "+0%"
    var trend: ActivityTrend = .stable
    var goalValue: Double?

    var chartData: [ActivityDataPoint] = []
    var hourlyData: [HourlyActivityData] = []
    var insights: [ActivityInsight] = []
    var goals: [ActivityGoal] = []

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalActiveDays: Int = 0
    var activeDaysThisMonth: Int = 0

    func loadData(metric: ActivityMetric, timeRange: ActivityTimeRange) async {
        // Would integrate with HealthKit
        // Mock data for demonstration
        await generateMockData(metric: metric, timeRange: timeRange)
    }

    private func generateMockData(metric: ActivityMetric, timeRange: ActivityTimeRange) async {
        // Simulate loading
        try? await Task.sleep(for: .milliseconds(300))

        // Mock values
        switch metric {
        case .steps:
            todayValue = "9,847"
            averageValue = "8,523"
            goalValue = 10_000
        case .distance:
            todayValue = "7.2"
            averageValue = "6.4"
            goalValue = 8.0
        case .calories:
            todayValue = "487"
            averageValue = "425"
            goalValue = 500
        case .activeMinutes:
            todayValue = "64"
            averageValue = "52"
            goalValue = 60
        }

        trendPercentage = "+15%"
        trend = .improving

        // Generate chart data
        chartData = (0..<timeRange.days).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -timeRange.days + dayOffset, to: Date()) ?? Date().addingTimeInterval(Double(-timeRange.days + dayOffset) * 86400)
            let baseValue: Double
            switch metric {
            case .steps: baseValue = 8_500
            case .distance: baseValue = 6.5
            case .calories: baseValue = 425
            case .activeMinutes: baseValue = 50
            }
            let variance = baseValue * 0.3
            let value = baseValue + Double.random(in: -variance...variance)
            return ActivityDataPoint(date: date, value: max(0, value))
        }

        // Generate hourly data
        hourlyData = (0..<24).map { hour in
            let baseValue: Double
            switch metric {
            case .steps: baseValue = hour >= 8 && hour <= 20 ? 600 : 50
            case .distance: baseValue = hour >= 8 && hour <= 20 ? 0.5 : 0.05
            case .calories: baseValue = hour >= 8 && hour <= 20 ? 35 : 5
            case .activeMinutes: baseValue = hour >= 8 && hour <= 20 ? 4 : 0.5
            }
            let variance = baseValue * 0.4
            let value = baseValue + Double.random(in: -variance...variance)
            return HourlyActivityData(hour: hour, value: max(0, value))
        }

        // Generate insights
        insights = [
            ActivityInsight(
                type: .positive,
                title: "Great Progress!",
                message: "You're 15% more active than last \(timeRange.displayName.lowercased())",
                icon: "chart.line.improvingtrend.xyaxis"
            ),
            ActivityInsight(
                type: .neutral,
                title: "Peak Activity Time",
                message: "You're most active between 2 PM - 6 PM",
                icon: "clock.fill"
            )
        ]

        // Generate goals
        goals = [
            ActivityGoal(name: "Daily Steps", current: 9_847, target: 10_000, unit: "steps"),
            ActivityGoal(name: "Weekly Distance", current: 45, target: 50, unit: "km"),
            ActivityGoal(name: "Monthly Calories", current: 12_750, target: 15_000, unit: "kcal")
        ]

        // Generate streaks
        currentStreak = 12
        longestStreak = 28
        totalActiveDays = 156
        activeDaysThisMonth = 18
    }
}

// MARK: - ActivityTrend Enum

enum ActivityTrend {
    case improving
    case stable
    case declining

    var iconName: String {
        switch self {
        case .improving: return "arrow.up.right.circle.fill"
        case .stable: return "arrow.right.circle.fill"
        case .declining: return "arrow.down.right.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .red
        }
    }

    var displayName: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }
}

#Preview {
    NavigationStack {
        ActivityActivityTrendsView()
    }
}
