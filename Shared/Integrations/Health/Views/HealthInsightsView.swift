import Charts
import SwiftUI

/// Aggregated health insights dashboard with AI-powered recommendations
@MainActor
public struct HealthInsightsView: View {
    @State private var viewModel = HealthInsightsViewModel()
    @State private var selectedTimeRange: TimeRange = .week

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Time Range Picker
                timeRangePicker

                // Overall Health Score
                healthScoreCard

                // Key Metrics Summary
                keyMetricsSection

                // Insights & Recommendations
                insightsSection

                // Trend Analysis
                trendAnalysisSection

                // Correlations
                correlationsSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Health Insights")
        .toolbar {
            Button {
                Task {
                    await viewModel.refreshInsights()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .task {
            await viewModel.loadData(timeRange: selectedTimeRange)
        }
        .onChange(of: selectedTimeRange) { _, newValue in
            Task {
                await viewModel.loadData(timeRange: newValue)
            }
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Health Score Card

    private var healthScoreCard: some View {
        VStack(spacing: 16) {
            // Score Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: viewModel.healthScore / 100)
                    .stroke(
                        healthScoreColor,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.0), value: viewModel.healthScore)

                VStack(spacing: 4) {
                    Text("\(Int(viewModel.healthScore))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(healthScoreColor)

                    Text("Health Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Score Interpretation
            Text(healthScoreInterpretation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Score Breakdown
            VStack(spacing: 8) {
                ScoreComponentRow(label: "Sleep Quality", score: viewModel.sleepScore, color: .blue)
                ScoreComponentRow(label: "Activity Level", score: viewModel.activityScore, color: .green)
                ScoreComponentRow(label: "Heart Health", score: viewModel.heartScore, color: .red)
                ScoreComponentRow(label: "Nutrition", score: viewModel.nutritionScore, color: .orange)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var healthScoreColor: Color {
        if viewModel.healthScore >= 80 { return .green }
        if viewModel.healthScore >= 60 { return .yellow }
        if viewModel.healthScore >= 40 { return .orange }
        return .red
    }

    private var healthScoreInterpretation: String {
        if viewModel.healthScore >= 80 { return "Excellent health metrics across the board" }
        if viewModel.healthScore >= 60 { return "Good overall health with room for improvement" }
        if viewModel.healthScore >= 40 { return "Fair health metrics, focus on key areas" }
        return "Health metrics need attention, prioritize improvements"
    }

    // MARK: - Key Metrics

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics (\(selectedTimeRange.displayName))")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    icon: "bed.double.fill",
                    label: "Avg Sleep",
                    value: formatDuration(viewModel.averageSleepDuration),
                    trend: viewModel.sleepTrend,
                    color: .blue
                )

                MetricCard(
                    icon: "figure.walk",
                    label: "Daily Steps",
                    value: "\(viewModel.averageSteps)",
                    trend: viewModel.activityTrend,
                    color: .green
                )

                MetricCard(
                    icon: "heart.fill",
                    label: "Resting HR",
                    value: "\(viewModel.averageRestingHR) BPM",
                    trend: viewModel.heartRateTrend,
                    color: .red
                )

                MetricCard(
                    icon: "flame.fill",
                    label: "Active Cal",
                    value: "\(viewModel.averageActiveCalories)",
                    trend: viewModel.caloriesTrend,
                    color: .orange
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI-Powered Insights")
                .font(.headline)
                .padding(.horizontal)

            if viewModel.insights.isEmpty {
                EmptyInsightsView()
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.insights) { insight in
                        HealthInsightCard(insight: insight)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Trend Analysis

    private var trendAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend Analysis")
                .font(.headline)
                .padding(.horizontal)

            // Sleep Trend Chart
            TrendChartView(
                title: "Sleep Duration",
                data: viewModel.sleepTrendData,
                color: .blue,
                unit: "hours"
            )

            // Activity Trend Chart
            TrendChartView(
                title: "Daily Steps",
                data: viewModel.activityTrendData,
                color: .green,
                unit: "steps"
            )

            // Heart Rate Trend Chart
            TrendChartView(
                title: "Resting Heart Rate",
                data: viewModel.heartRateTrendData,
                color: .red,
                unit: "BPM"
            )
        }
    }

    // MARK: - Correlations

    private var correlationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pattern Correlations")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(viewModel.correlations) { correlation in
                    CorrelationCard(correlation: correlation)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
}

// MARK: - Score Component Row

private struct ScoreComponentRow: View {
    let label: String
    let score: Double
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * (score / 100), height: 8)
                }
            }
            .frame(width: 100, height: 8)

            Text("\(Int(score))")
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    let trend: Trend
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(spacing: 4) {
                Text(value)
                    .font(.title3)
                    .bold()

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: trend.iconName)
                    .font(.caption)
                    .foregroundStyle(trend.swiftUIColor)

                Text(trend.displayName)
                    .font(.caption)
                    .foregroundStyle(trend.swiftUIColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Insight Card

private struct HealthInsightCard: View {
    let insight: HealthInsightDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: insight.icon)
                    .font(.title2)
                    .foregroundStyle(insight.severity.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.headline)

                    Text(insight.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                insight.severity.badge
            }

            Text(insight.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !insight.recommendations.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations:")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.secondary)

                    ForEach(insight.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)

                            Text(recommendation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(insight.severity.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(insight.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Empty Insights View

private struct EmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.improvingtrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No insights available")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Keep tracking your health metrics to receive personalized insights")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Trend Chart View

private struct TrendChartView: View {
    let title: String
    let data: [TrendDataPoint]
    let color: Color
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .bold()

            if data.isEmpty {
                Text("No data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(unit, point.value)
                        )
                        .foregroundStyle(color)
                        .symbol(.circle)

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value(unit, point.value)
                        )
                        .foregroundStyle(color.opacity(0.1))
                    }
                }
                .frame(height: 120)
                .chartYAxisLabel(unit, position: .leading)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Correlation Card

private struct CorrelationCard: View {
    let correlation: HealthCorrelation

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(correlation.metric1)
                    .font(.caption)
                    .bold()

                Image(systemName: "arrow.improving.arrow.declining")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(correlation.metric2)
                    .font(.caption)
                    .bold()
            }
            .frame(width: 100, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Strength:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(correlation.strength.displayName)
                        .font(.caption)
                        .bold()
                        .foregroundStyle(correlation.strength.color)
                }

                Text(correlation.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Models

public enum TimeRange: String, CaseIterable, Sendable {
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

public struct HealthInsightDisplay: Identifiable, Sendable {
    public let id = UUID()
    public var category: InsightCategory
    public var title: String
    public var message: String
    public var icon: String
    public var severity: InsightSeverity
    public var recommendations: [String]

    public init(
        category: InsightCategory,
        title: String,
        message: String,
        icon: String,
        severity: InsightSeverity,
        recommendations: [String]
    ) {
        self.category = category
        self.title = title
        self.message = message
        self.icon = icon
        self.severity = severity
        self.recommendations = recommendations
    }
}

public enum InsightCategory: String, Sendable {
    case sleep
    case activity
    case heart
    case nutrition
    case overall

    var displayName: String {
        switch self {
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        case .heart: return "Heart Health"
        case .nutrition: return "Nutrition"
        case .overall: return "Overall Health"
        }
    }
}

public enum InsightSeverity: Sendable {
    case positive
    case neutral
    case warning
    case critical

    var color: Color {
        switch self {
        case .positive: return .green
        case .neutral: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }

    var backgroundColor: Color {
        color.opacity(0.05)
    }

    var badge: some View {
        Group {
            switch self {
            case .positive:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .neutral:
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .critical:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}

public struct TrendDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public var date: Date
    public var value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct HealthCorrelation: Identifiable, Sendable {
    public let id = UUID()
    public var metric1: String
    public var metric2: String
    public var strength: CorrelationStrength
    public var description: String

    public init(metric1: String, metric2: String, strength: CorrelationStrength, description: String) {
        self.metric1 = metric1
        self.metric2 = metric2
        self.strength = strength
        self.description = description
    }
}

public enum CorrelationStrength: Sendable {
    case strong
    case moderate
    case weak

    var displayName: String {
        switch self {
        case .strong: return "Strong"
        case .moderate: return "Moderate"
        case .weak: return "Weak"
        }
    }

    var color: Color {
        switch self {
        case .strong: return .green
        case .moderate: return .yellow
        case .weak: return .orange
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class HealthInsightsViewModel {
    var healthScore: Double = 0
    var sleepScore: Double = 0
    var activityScore: Double = 0
    var heartScore: Double = 0
    var nutritionScore: Double = 0

    var averageSleepDuration: Int = 0
    var averageSteps: Int = 0
    var averageRestingHR: Int = 0
    var averageActiveCalories: Int = 0

    var sleepTrend: Trend = .unknown
    var activityTrend: Trend = .unknown
    var heartRateTrend: Trend = .unknown
    var caloriesTrend: Trend = .unknown

    var insights: [HealthInsightDisplay] = []
    var sleepTrendData: [TrendDataPoint] = []
    var activityTrendData: [TrendDataPoint] = []
    var heartRateTrendData: [TrendDataPoint] = []
    var correlations: [HealthCorrelation] = []

    func loadData(timeRange: TimeRange) async {
        // Would integrate with HealthKit and other services
        // Mock data for demonstration
        await generateMockData(timeRange: timeRange)
    }

    func refreshInsights() async {
        // Would trigger AI analysis
        await generateInsights()
    }

    private func generateMockData(timeRange: TimeRange) async {
        // Simulate loading
        try? await Task.sleep(for: .milliseconds(500))

        // Mock scores
        healthScore = 75.0
        sleepScore = 80.0
        activityScore = 70.0
        heartScore = 75.0
        nutritionScore = 65.0

        // Mock averages
        averageSleepDuration = 420 // 7 hours
        averageSteps = 8_500
        averageRestingHR = 62
        averageActiveCalories = 450

        // Mock trends
        sleepTrend = .stable
        activityTrend = .improving
        heartRateTrend = .stable
        caloriesTrend = .improving

        // Mock trend data
        sleepTrendData = generateMockTrendData(days: timeRange.days, baseValue: 7.0, variance: 1.5)
        activityTrendData = generateMockTrendData(days: timeRange.days, baseValue: 8_500, variance: 2_000)
        heartRateTrendData = generateMockTrendData(days: timeRange.days, baseValue: 62, variance: 5)

        await generateInsights()
        generateCorrelations()
    }

    private func generateMockTrendData(days: Int, baseValue: Double, variance: Double) -> [TrendDataPoint] {
        (0..<days).map { day in
            let date = Calendar.current.date(byAdding: .day, value: -days + day, to: Date())!
            let randomVariance = Double.random(in: -variance...variance)
            return TrendDataPoint(date: date, value: baseValue + randomVariance)
        }
    }

    private func generateInsights() async {
        insights = [
            HealthInsightDisplay(
                category: .sleep,
                title: "Consistent Sleep Pattern",
                message: "You've maintained a regular sleep schedule for the past 7 days. Keep it up!",
                icon: "bed.double.fill",
                severity: .positive,
                recommendations: [
                    "Continue going to bed at the same time",
                    "Aim for 7-9 hours per night",
                    "Avoid screens 1 hour before bed"
                ]
            ),
            HealthInsightDisplay(
                category: .activity,
                title: "Increasing Activity Trend",
                message: "Your daily step count has increased by 15% this week compared to last week.",
                icon: "figure.walk",
                severity: .positive,
                recommendations: [
                    "Try to maintain this momentum",
                    "Consider adding strength training",
                    "Take movement breaks every hour"
                ]
            ),
            HealthInsightDisplay(
                category: .heart,
                title: "Resting Heart Rate Optimal",
                message: "Your resting heart rate of 62 BPM is in the excellent range for your age.",
                icon: "heart.fill",
                severity: .positive,
                recommendations: [
                    "Continue regular cardiovascular exercise",
                    "Monitor for any sudden changes",
                    "Consider HRV tracking"
                ]
            )
        ]
    }

    private func generateCorrelations() {
        correlations = [
            HealthCorrelation(
                metric1: "Sleep Duration",
                metric2: "Activity Level",
                strength: .strong,
                description: "Better sleep correlates with higher next-day activity"
            ),
            HealthCorrelation(
                metric1: "Resting HR",
                metric2: "Sleep Quality",
                strength: .moderate,
                description: "Lower resting HR associates with better sleep"
            )
        ]
    }
}

#Preview {
    NavigationStack {
        HealthInsightsView()
    }
}
