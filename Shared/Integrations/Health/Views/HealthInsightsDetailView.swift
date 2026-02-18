import Charts
import SwiftUI

/// Aggregated health insights dashboard with AI-powered recommendations
@MainActor
public struct HealthInsightsDetailView: View {
    @State private var viewModel = HealthInsightsDetailViewModel()
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
                ScoreComponentRow(label: "Sleep Quality", score: viewModel.sleepScore, color: .theaInfo)
                ScoreComponentRow(label: "Activity Level", score: viewModel.activityScore, color: .theaSuccess)
                ScoreComponentRow(label: "Heart Health", score: viewModel.heartScore, color: .theaError)
                ScoreComponentRow(label: "Nutrition", score: viewModel.nutritionScore, color: .theaWarning)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var healthScoreColor: Color {
        if viewModel.healthScore >= 80 { return .theaSuccess }
        if viewModel.healthScore >= 60 { return .theaWarning }
        if viewModel.healthScore >= 40 { return .theaWarning }
        return .theaError
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
                    color: .theaInfo
                )

                MetricCard(
                    icon: "figure.walk",
                    label: "Daily Steps",
                    value: "\(viewModel.averageSteps)",
                    trend: viewModel.activityTrend,
                    color: .theaSuccess
                )

                MetricCard(
                    icon: "heart.fill",
                    label: "Resting HR",
                    value: "\(viewModel.averageRestingHR) BPM",
                    trend: viewModel.heartRateTrend,
                    color: .theaError
                )

                MetricCard(
                    icon: "flame.fill",
                    label: "Active Cal",
                    value: "\(viewModel.averageActiveCalories)",
                    trend: viewModel.caloriesTrend,
                    color: .theaWarning
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
                color: .theaInfo,
                unit: "hours"
            )

            // Activity Trend Chart
            TrendChartView(
                title: "Daily Steps",
                data: viewModel.activityTrendData,
                color: .theaSuccess,
                unit: "steps"
            )

            // Heart Rate Trend Chart
            TrendChartView(
                title: "Resting Heart Rate",
                data: viewModel.heartRateTrendData,
                color: .theaError,
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
                                .foregroundStyle(Color.theaSuccess)

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
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
        }
    }
}

public struct HealthInsightDisplay: Identifiable, Sendable {
    public let id = UUID()
    public var category: HealthInsightCategory
    public var title: String
    public var message: String
    public var icon: String
    public var severity: InsightSeverity
    public var recommendations: [String]

    public init(
        category: HealthInsightCategory,
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

public enum HealthInsightCategory: String, Sendable {
    case sleep
    case activity
    case heart
    case nutrition
    case overall

    var displayName: String {
        switch self {
        case .sleep: "Sleep"
        case .activity: "Activity"
        case .heart: "Heart Health"
        case .nutrition: "Nutrition"
        case .overall: "Overall Health"
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
        case .positive: .theaSuccess
        case .neutral: .theaInfo
        case .warning: .theaWarning
        case .critical: .theaError
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
                    .foregroundStyle(Color.theaSuccess)
            case .neutral:
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.theaInfo)
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.theaWarning)
            case .critical:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.theaError)
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
        case .strong: "Strong"
        case .moderate: "Moderate"
        case .weak: "Weak"
        }
    }

    var color: Color {
        switch self {
        case .strong: .theaSuccess
        case .moderate: .theaWarning
        case .weak: .theaWarning
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class HealthInsightsDetailViewModel {
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

    private let healthKitService = HealthKitService()

    func loadData(timeRange: TimeRange) async {
        do {
            _ = try await healthKitService.requestAuthorization()
            await loadFromHealthKit(timeRange: timeRange)
        } catch {
            healthScore = 0; sleepScore = 0; activityScore = 0; heartScore = 0; nutritionScore = 0
        }
    }

    func refreshInsights() async {
        generateInsightsFromData()
    }

    private func loadFromHealthKit(timeRange: TimeRange) async {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -timeRange.days, to: endDate) ?? endDate

        // Fetch sleep data
        var sleepMinutes: [Double] = []
        let sleepRange = DateInterval(start: startDate.addingTimeInterval(-30 * 3600), end: endDate)
        if let records = try? await healthKitService.fetchSleepData(for: sleepRange) { // Safe: nil = no data, view shows empty state
            for record in records {
                sleepMinutes.append(record.endDate.timeIntervalSince(record.startDate) / 60)
            }
            averageSleepDuration = sleepMinutes.isEmpty ? 0 : Int(sleepMinutes.reduce(0, +) / Double(sleepMinutes.count))
            sleepScore = min(100, Double(averageSleepDuration) / 480 * 100)
            sleepTrendData = records.map { TrendDataPoint(date: $0.startDate, value: $0.endDate.timeIntervalSince($0.startDate) / 3600) }
            sleepTrend = computeTrend(from: sleepTrendData)
        }

        // Fetch activity data per day
        var stepValues: [Double] = []
        var calorieValues: [Double] = []
        var activityPoints: [TrendDataPoint] = []
        for dayOffset in 0 ..< timeRange.days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: endDate) ?? endDate
            if let summary = try? await healthKitService.fetchActivityData(for: date) { // Safe: nil = no activity data for this day, skip
                stepValues.append(Double(summary.steps))
                calorieValues.append(Double(summary.activeCalories))
                activityPoints.append(TrendDataPoint(date: date, value: Double(summary.steps)))
            }
        }
        averageSteps = stepValues.isEmpty ? 0 : Int(stepValues.reduce(0, +) / Double(stepValues.count))
        averageActiveCalories = calorieValues.isEmpty ? 0 : Int(calorieValues.reduce(0, +) / Double(calorieValues.count))
        activityScore = min(100, Double(averageSteps) / 10000 * 100)
        activityTrendData = activityPoints.reversed()
        activityTrend = computeTrend(from: activityTrendData)
        caloriesTrend = computeTrend(from: calorieValues.reversed().enumerated().map {
            TrendDataPoint(date: calendar.date(byAdding: .day, value: $0.offset - calorieValues.count, to: endDate) ?? endDate, value: $0.element)
        })

        // Fetch heart rate data
        let hrRange = DateInterval(start: startDate, end: endDate)
        if let hrRecords = try? await healthKitService.fetchHeartRateData(for: hrRange) { // Safe: nil = no HR data, view shows dashes
            let restingHR = hrRecords.filter { $0.context == .resting || $0.context == .sleep }
            averageRestingHR = restingHR.isEmpty ? 0 : restingHR.map(\.beatsPerMinute).reduce(0, +) / restingHR.count
            heartScore = averageRestingHR > 0 ? min(100, max(0, 100 - Double(averageRestingHR - 50))) : 0

            var hrByDay: [Date: [Int]] = [:]
            for record in hrRecords {
                let day = calendar.startOfDay(for: record.timestamp)
                hrByDay[day, default: []].append(record.beatsPerMinute)
            }
            heartRateTrendData = hrByDay.sorted { $0.key < $1.key }.map { day, bpms in
                TrendDataPoint(date: day, value: Double(bpms.reduce(0, +)) / Double(bpms.count))
            }
            heartRateTrend = computeTrend(from: heartRateTrendData)
        }

        // Nutrition score derived from activity + body composition signals
        // (HealthKit dietary tracking requires explicit user logging)
        // Use calorie balance and activity diversity as proxy
        let calorieBalance = averageActiveCalories > 0
            ? min(100.0, Double(averageActiveCalories) / 500.0 * 100.0)
            : 0.0
        let activityConsistency = stepValues.isEmpty ? 0.0 : {
            let avg = stepValues.reduce(0, +) / Double(stepValues.count)
            guard avg > 0 else { return 0.0 }
            let variance = stepValues.map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(stepValues.count)
            let cv = sqrt(variance) / avg // coefficient of variation
            return min(100.0, max(0.0, (1.0 - cv) * 100.0))
        }()
        nutritionScore = (calorieBalance * 0.6 + activityConsistency * 0.4)
        healthScore = (sleepScore + activityScore + heartScore + nutritionScore) / 4

        generateInsightsFromData()
        generateCorrelationsFromData()
    }

    private func computeTrend(from data: [TrendDataPoint]) -> Trend {
        guard data.count >= 4 else { return .unknown }
        let half = data.count / 2
        let firstAvg = data.prefix(half).map(\.value).reduce(0, +) / Double(half)
        let secondAvg = data.suffix(half).map(\.value).reduce(0, +) / Double(half)
        guard firstAvg > 0 else { return .unknown }
        let change = (secondAvg - firstAvg) / firstAvg
        if change > 0.05 { return .improving }
        if change < -0.05 { return .declining }
        return .stable
    }

    private func generateInsightsFromData() {
        var result: [HealthInsightDisplay] = []
        if averageSleepDuration >= 420 {
            result.append(HealthInsightDisplay(
                category: .sleep, title: "Good Sleep Duration",
                message: "Your average sleep of \(averageSleepDuration / 60)h \(averageSleepDuration % 60)m meets recommended levels.",
                icon: "bed.double.fill", severity: .positive,
                recommendations: ["Keep a consistent sleep schedule", "Avoid caffeine after 2 PM"]
            ))
        } else if averageSleepDuration > 0 {
            result.append(HealthInsightDisplay(
                category: .sleep, title: "Sleep Below Target",
                message: "Your average sleep is \(averageSleepDuration / 60)h \(averageSleepDuration % 60)m — below the 7-hour recommendation.",
                icon: "bed.double.fill", severity: .warning,
                recommendations: ["Try going to bed 30 minutes earlier", "Create a wind-down routine"]
            ))
        }
        if averageSteps >= 10000 {
            result.append(HealthInsightDisplay(
                category: .activity, title: "Excellent Activity Level",
                message: "Averaging \(averageSteps) steps daily — you're hitting the 10,000-step target!",
                icon: "figure.walk", severity: .positive,
                recommendations: ["Consider adding variety with cycling or swimming"]
            ))
        } else if averageSteps > 0 {
            result.append(HealthInsightDisplay(
                category: .activity, title: "Room for More Activity",
                message: "Averaging \(averageSteps) steps daily. Aim for 10,000.",
                icon: "figure.walk", severity: .neutral,
                recommendations: ["Take walking meetings", "Use stairs instead of elevator"]
            ))
        }
        if averageRestingHR > 0 && averageRestingHR < 70 {
            result.append(HealthInsightDisplay(
                category: .heart, title: "Healthy Resting Heart Rate",
                message: "Your resting HR of \(averageRestingHR) BPM indicates good cardiovascular fitness.",
                icon: "heart.fill", severity: .positive,
                recommendations: ["Continue regular exercise", "Monitor for sudden changes"]
            ))
        } else if averageRestingHR >= 80 {
            result.append(HealthInsightDisplay(
                category: .heart, title: "Elevated Resting Heart Rate",
                message: "Your resting HR of \(averageRestingHR) BPM is above the optimal range.",
                icon: "heart.fill", severity: .warning,
                recommendations: ["Consult your doctor if persistently elevated", "Increase aerobic exercise gradually"]
            ))
        }
        insights = result
    }

    private func generateCorrelationsFromData() {
        var result: [HealthCorrelation] = []
        if sleepTrend == activityTrend && sleepTrend != .unknown {
            result.append(HealthCorrelation(
                metric1: "Sleep Duration", metric2: "Activity Level", strength: .strong,
                description: "Sleep and activity trends are moving together"
            ))
        }
        if heartRateTrend == .improving {
            result.append(HealthCorrelation(
                metric1: "Resting HR", metric2: "Fitness Level", strength: .moderate,
                description: "Resting heart rate is improving — cardiovascular fitness increasing"
            ))
        }
        correlations = result
    }
}

#Preview {
    NavigationStack {
        HealthInsightsDetailView()
    }
}
