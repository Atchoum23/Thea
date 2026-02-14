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
        case .steps: "Steps"
        case .distance: "Distance"
        case .calories: "Calories"
        case .activeMinutes: "Active Minutes"
        }
    }

    public var icon: String {
        switch self {
        case .steps: "figure.walk"
        case .distance: "map"
        case .calories: "flame.fill"
        case .activeMinutes: "timer"
        }
    }

    public var unit: String {
        switch self {
        case .steps: "steps"
        case .distance: "km"
        case .calories: "kcal"
        case .activeMinutes: "minutes"
        }
    }

    public var color: Color {
        switch self {
        case .steps: .green
        case .distance: .blue
        case .calories: .orange
        case .activeMinutes: .purple
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
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
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
        case .positive: .green
        case .neutral: .blue
        case .warning: .orange
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

    private let healthKitService = HealthKitService()

    func loadData(metric: ActivityMetric, timeRange: ActivityTimeRange) async {
        do {
            _ = try await healthKitService.requestAuthorization()
            await loadFromHealthKit(metric: metric, timeRange: timeRange)
        } catch {
            todayValue = "—"
            averageValue = "—"
            chartData = []
        }
    }

    private func loadFromHealthKit(metric: ActivityMetric, timeRange: ActivityTimeRange) async {
        let calendar = Calendar.current
        let today = Date()

        do {
            let todaySummary = try await healthKitService.fetchActivityData(for: today)
            let todayVal = extractMetric(metric, from: todaySummary)
            todayValue = formatValue(todayVal, metric: metric)

            var dataPoints: [ActivityDataPoint] = []
            var total: Double = 0

            for dayOffset in (0 ..< timeRange.days).reversed() {
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
                do {
                    let summary = try await healthKitService.fetchActivityData(for: date)
                    let value = extractMetric(metric, from: summary)
                    dataPoints.append(ActivityDataPoint(date: date, value: value))
                    total += value
                } catch {
                    dataPoints.append(ActivityDataPoint(date: date, value: 0))
                }
            }

            chartData = dataPoints
            let avg = dataPoints.isEmpty ? 0 : total / Double(dataPoints.count)
            averageValue = formatValue(avg, metric: metric)

            let halfCount = max(1, dataPoints.count / 2)
            let firstHalf = dataPoints.prefix(halfCount).map(\.value).reduce(0, +) / Double(halfCount)
            let secondHalf = dataPoints.suffix(halfCount).map(\.value).reduce(0, +) / Double(halfCount)
            if firstHalf > 0 {
                let change = (secondHalf - firstHalf) / firstHalf * 100
                trendPercentage = String(format: "%+.0f%%", change)
                trend = change > 5 ? .improving : change < -5 ? .declining : .stable
            } else {
                trendPercentage = "+0%"
                trend = .stable
            }

            goalValue = switch metric {
            case .steps: 10000
            case .distance: 8.0
            case .calories: 500
            case .activeMinutes: 60
            }

            var streak = 0
            var longest = 0
            var activeDays = 0
            let thisMonth = calendar.component(.month, from: today)
            var monthDays = 0
            for point in dataPoints.reversed() {
                if point.value >= (goalValue ?? 0) {
                    streak += 1
                    activeDays += 1
                    longest = max(longest, streak)
                    if calendar.component(.month, from: point.date) == thisMonth { monthDays += 1 }
                } else {
                    streak = 0
                }
            }
            currentStreak = streak
            longestStreak = longest
            totalActiveDays = activeDays
            activeDaysThisMonth = monthDays

            insights = buildInsights(todayVal: todayVal, avg: avg, metric: metric, timeRange: timeRange)
            goals = [
                ActivityGoal(name: "Daily \(metric.displayName)", current: Int(todayVal), target: Int(goalValue ?? 0), unit: metric.unit)
            ]

        } catch {
            todayValue = "—"
            averageValue = "—"
        }
    }

    private func extractMetric(_ metric: ActivityMetric, from summary: ActivitySummary) -> Double {
        switch metric {
        case .steps: Double(summary.steps)
        case .distance: summary.distance / 1000.0
        case .calories: Double(summary.activeCalories)
        case .activeMinutes: Double(summary.activeMinutes)
        }
    }

    private func formatValue(_ value: Double, metric: ActivityMetric) -> String {
        switch metric {
        case .steps: String(format: "%.0f", value)
        case .distance: String(format: "%.1f", value)
        case .calories: String(format: "%.0f", value)
        case .activeMinutes: String(format: "%.0f", value)
        }
    }

    private func buildInsights(todayVal: Double, avg: Double, metric: ActivityMetric, timeRange: ActivityTimeRange) -> [ActivityInsight] {
        var result: [ActivityInsight] = []
        if avg > 0 {
            let pctDiff = (todayVal - avg) / avg * 100
            if pctDiff > 10 {
                result.append(ActivityInsight(
                    type: .positive, title: "Above Average!",
                    message: "Today's \(metric.displayName.lowercased()) is \(String(format: "%.0f", pctDiff))% above your \(timeRange.displayName.lowercased()) average",
                    icon: "chart.line.improvingtrend.xyaxis"
                ))
            } else if pctDiff < -10 {
                result.append(ActivityInsight(
                    type: .warning, title: "Below Average",
                    message: "Today's \(metric.displayName.lowercased()) is \(String(format: "%.0f", abs(pctDiff)))% below your average",
                    icon: "exclamationmark.triangle"
                ))
            }
        }
        if let goal = goalValue, todayVal >= goal {
            result.append(ActivityInsight(
                type: .positive, title: "Goal Reached!",
                message: "You've hit your daily \(metric.displayName.lowercased()) goal",
                icon: "checkmark.circle.fill"
            ))
        }
        return result
    }
}

// MARK: - ActivityTrend Enum

enum ActivityTrend {
    case improving
    case stable
    case declining

    var iconName: String {
        switch self {
        case .improving: "arrow.up.right.circle.fill"
        case .stable: "arrow.right.circle.fill"
        case .declining: "arrow.down.right.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .improving: .green
        case .stable: .blue
        case .declining: .red
        }
    }

    var displayName: String {
        switch self {
        case .improving: "Improving"
        case .stable: "Stable"
        case .declining: "Declining"
        }
    }
}

#Preview {
    NavigationStack {
        ActivityActivityTrendsView()
    }
}
