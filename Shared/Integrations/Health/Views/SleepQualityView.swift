import Charts
import SwiftUI

/// Detailed sleep quality analysis with stage breakdown
@MainActor
public struct SleepQualityView: View {
    @State private var viewModel = SleepQualityViewModel()
    @State private var selectedDate = Date()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Date Picker
                datePicker

                // Sleep Quality Score
                if let sleepData = viewModel.selectedDaySleep {
                    sleepQualityCard(sleepData)

                    // Sleep Stages Breakdown
                    sleepStagesSection(sleepData)

                    // Sleep Timeline
                    sleepTimelineChart(sleepData)

                    // Sleep Metrics
                    sleepMetricsSection(sleepData)

                    // Sleep Factors
                    sleepFactorsSection(sleepData)
                } else {
                    noDataView
                }

                // Weekly Trends
                weeklyTrendsSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Sleep Quality")
        .task {
            await viewModel.loadData(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await viewModel.loadData(for: newDate)
            }
        }
    }

    // MARK: - Date Picker

    private var datePicker: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            .disabled(!viewModel.hasPreviousData)

            Spacer()

            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .disabled(!viewModel.hasNextData || Calendar.current.isDateInToday(selectedDate))
        }
        .padding(.horizontal)
    }

    // MARK: - Sleep Quality Card

    private func sleepQualityCard(_ sleep: SleepData) -> some View {
        VStack(spacing: 16) {
            // Quality Score Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: sleep.qualityScore / 100)
                    .stroke(
                        sleepQualityColor(sleep.qualityScore),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.0), value: sleep.qualityScore)

                VStack(spacing: 4) {
                    Text("\(Int(sleep.qualityScore))")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(sleepQualityColor(sleep.qualityScore))

                    Text("Quality")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Quality Rating
            Text(sleepQualityRating(sleep.qualityScore))
                .font(.headline)
                .foregroundStyle(sleepQualityColor(sleep.qualityScore))

            // Total Duration
            VStack(spacing: 4) {
                Text(formatDuration(sleep.totalMinutes))
                    .font(.title2)
                    .bold()

                Text("Total Sleep")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Sleep Window
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bedtime")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(sleep.bedtime, style: .time)
                        .font(.subheadline)
                        .bold()
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Wake Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(sleep.wakeTime, style: .time)
                        .font(.subheadline)
                        .bold()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Sleep Stages Section

    private func sleepStagesSection(_ sleep: SleepData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stages")
                .font(.headline)
                .padding(.horizontal)

            // Stages Pie Chart
            Chart {
                ForEach(sleep.stages) { stage in
                    SectorMark(
                        angle: .value("Duration", stage.minutes),
                        innerRadius: .ratio(0.618),
                        angularInset: 2
                    )
                    .foregroundStyle(stage.stage.color)
                    .annotation(position: .overlay) {
                        if stage.percentage > 5 {
                            Text("\(Int(stage.percentage))%")
                                .font(.caption)
                                .bold()
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding()

            // Stage Breakdown
            VStack(spacing: 12) {
                ForEach(sleep.stages) { stage in
                    SleepStageRow(stage: stage)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Sleep Timeline Chart

    private func sleepTimelineChart(_ sleep: SleepData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Timeline")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(sleep.timeline) { segment in
                    RectangleMark(
                        x: .value("Time", segment.startTime),
                        y: .value("Stage", segment.stage.displayName),
                        width: .fixed(segment.endTime.timeIntervalSince(segment.startTime))
                    )
                    .foregroundStyle(segment.stage.color)
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.hour())
                    AxisGridLine()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Sleep Metrics Section

    private func sleepMetricsSection(_ sleep: SleepData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Metrics")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    label: "Efficiency",
                    value: "\(Int(sleep.efficiency))%",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue,
                    target: 85,
                    current: sleep.efficiency
                )

                MetricCard(
                    label: "Latency",
                    value: "\(sleep.sleepLatency)m",
                    icon: "clock.fill",
                    color: .orange,
                    target: 20,
                    current: Double(sleep.sleepLatency),
                    inverse: true
                )

                MetricCard(
                    label: "Interruptions",
                    value: "\(sleep.interruptions)",
                    icon: "waveform.path.ecg",
                    color: .red,
                    target: 5,
                    current: Double(sleep.interruptions),
                    inverse: true
                )

                MetricCard(
                    label: "Restfulness",
                    value: "\(Int(sleep.restfulness))%",
                    icon: "heart.fill",
                    color: .green,
                    target: 80,
                    current: sleep.restfulness
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Sleep Factors Section

    private func sleepFactorsSection(_ sleep: SleepData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contributing Factors")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(sleep.factors) { factor in
                    FactorRow(factor: factor)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Weekly Trends Section

    private var weeklyTrendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Trends")
                .font(.headline)
                .padding(.horizontal)

            weeklyTrendsChart
        }
    }

    private var weeklyTrendsChart: some View {
        VStack(spacing: 0) {
            chartContent
                .frame(height: 200)
                .padding()
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding([.horizontal], 16)
        }
    }

    private var chartContent: some View {
        Chart {
            ForEach(viewModel.weeklyData) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Duration", Double(day.totalMinutes) / 60.0)
                )
                .foregroundStyle(by: .value("Quality", day.qualityRating))
            }
        }
        .chartYAxisLabel("Hours")
        .chartForegroundStyleScale([
            "Excellent": Color.green,
            "Good": Color.blue,
            "Fair": Color.yellow,
            "Poor": Color.red
        ])
    }

    // MARK: - No Data View

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Sleep Data")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("No sleep data available for this date")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Helper Functions

    private func sleepQualityColor(_ score: Double) -> Color {
        if score >= 85 { return .green }
        if score >= 70 { return .blue }
        if score >= 50 { return .yellow }
        return .red
    }

    private func sleepQualityRating(_ score: Double) -> String {
        if score >= 85 { return "Excellent Sleep" }
        if score >= 70 { return "Good Sleep" }
        if score >= 50 { return "Fair Sleep" }
        return "Poor Sleep"
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
}

// MARK: - Sleep Stage Row

private struct SleepStageRow: View {
    let stage: SleepStageData

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(stage.stage.color)
                .frame(width: 12, height: 12)

            Text(stage.stage.displayName)
                .font(.subheadline)

            Spacer()

            Text("\(formatDuration(stage.minutes))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("(\(Int(stage.percentage))%)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    let target: Double
    let current: Double
    var inverse: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .bold()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Target indicator
            let isOnTarget = inverse ? current <= target : current >= target
            HStack(spacing: 4) {
                Image(systemName: isOnTarget ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(isOnTarget ? .green : .secondary)

                Text(isOnTarget ? "On target" : "Below target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Factor Row

private struct FactorRow: View {
    let factor: SleepFactor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: factor.icon)
                .font(.title3)
                .foregroundStyle(factor.impact.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(factor.name)
                    .font(.subheadline)
                    .bold()

                Text(factor.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(factor.impact.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(factor.impact.color.opacity(0.2))
                .foregroundStyle(factor.impact.color)
                .clipShape(Capsule())
        }
        .padding()
        .background(Color.gray.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Models

public struct SleepData: Identifiable, Sendable {
    public let id = UUID()
    public var date: Date
    public var bedtime: Date
    public var wakeTime: Date
    public var totalMinutes: Int
    public var qualityScore: Double
    public var efficiency: Double
    public var sleepLatency: Int
    public var interruptions: Int
    public var restfulness: Double
    public var stages: [SleepStageData]
    public var timeline: [SleepTimelineSegment]
    public var factors: [SleepFactor]

    public var qualityRating: String {
        if qualityScore >= 85 { return "Excellent" }
        if qualityScore >= 70 { return "Good" }
        if qualityScore >= 50 { return "Fair" }
        return "Poor"
    }

    public init(
        date: Date,
        bedtime: Date,
        wakeTime: Date,
        totalMinutes: Int,
        qualityScore: Double,
        efficiency: Double,
        sleepLatency: Int,
        interruptions: Int,
        restfulness: Double,
        stages: [SleepStageData],
        timeline: [SleepTimelineSegment],
        factors: [SleepFactor]
    ) {
        self.date = date
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.totalMinutes = totalMinutes
        self.qualityScore = qualityScore
        self.efficiency = efficiency
        self.sleepLatency = sleepLatency
        self.interruptions = interruptions
        self.restfulness = restfulness
        self.stages = stages
        self.timeline = timeline
        self.factors = factors
    }
}

public struct SleepStageData: Identifiable, Sendable {
    public let id = UUID()
    public var stage: SleepStage
    public var minutes: Int
    public var percentage: Double

    public init(stage: SleepStage, minutes: Int, percentage: Double) {
        self.stage = stage
        self.minutes = minutes
        self.percentage = percentage
    }
}

public struct SleepTimelineSegment: Identifiable, Sendable {
    public let id = UUID()
    public var stage: SleepStage
    public var startTime: Date
    public var endTime: Date

    public init(stage: SleepStage, startTime: Date, endTime: Date) {
        self.stage = stage
        self.startTime = startTime
        self.endTime = endTime
    }
}

public struct SleepFactor: Identifiable, Sendable {
    public let id = UUID()
    public var name: String
    public var description: String
    public var icon: String
    public var impact: FactorImpact

    public init(name: String, description: String, icon: String, impact: FactorImpact) {
        self.name = name
        self.description = description
        self.icon = icon
        self.impact = impact
    }
}

public enum FactorImpact: Sendable {
    case positive
    case neutral
    case negative

    var displayName: String {
        switch self {
        case .positive: "Positive"
        case .neutral: "Neutral"
        case .negative: "Negative"
        }
    }

    var color: Color {
        switch self {
        case .positive: .green
        case .neutral: .blue
        case .negative: .red
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class SleepQualityViewModel {
    var selectedDaySleep: SleepData?
    var weeklyData: [SleepData] = []
    var hasPreviousData: Bool = true
    var hasNextData: Bool = true

    private let healthKitService = HealthKitService()

    func loadData(for date: Date) async {
        do {
            _ = try await healthKitService.requestAuthorization()
            await loadFromHealthKit(for: date)
        } catch {
            selectedDaySleep = nil
            weeklyData = []
        }
    }

    private func loadFromHealthKit(for date: Date) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let sleepStart = calendar.date(byAdding: .hour, value: -30, to: startOfDay) ?? startOfDay.addingTimeInterval(-30 * 3600)
        let sleepEnd = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay.addingTimeInterval(12 * 3600)
        let dateRange = DateInterval(start: sleepStart, end: sleepEnd)

        do {
            let records = try await healthKitService.fetchSleepData(for: dateRange)

            if let record = records.last {
                let totalMinutes = Int(record.endDate.timeIntervalSince(record.startDate) / 60)
                let stages = buildStageData(from: record.stages, totalMinutes: totalMinutes)
                let timeline = record.stages.map { segment in
                    SleepTimelineSegment(stage: segment.stage, startTime: segment.startDate, endTime: segment.endDate)
                }

                let awakeMinutes = record.stages.filter { $0.stage == .awake }.reduce(0) { $0 + $1.durationMinutes }
                let sleepMinutes = totalMinutes - awakeMinutes
                let efficiency = totalMinutes > 0 ? Double(sleepMinutes) / Double(totalMinutes) * 100 : 0
                let interruptions = record.stages.filter { $0.stage == .awake }.count

                selectedDaySleep = SleepData(
                    date: date,
                    bedtime: record.startDate,
                    wakeTime: record.endDate,
                    totalMinutes: totalMinutes,
                    qualityScore: Double(record.quality.score),
                    efficiency: efficiency,
                    sleepLatency: record.stages.first?.stage == .awake ? record.stages.first!.durationMinutes : 0,
                    interruptions: max(0, interruptions - 1),
                    restfulness: record.quality.score * 1.05,
                    stages: stages,
                    timeline: timeline,
                    factors: []
                )
            } else {
                selectedDaySleep = nil
            }

            // Load weekly data
            let weekStart = calendar.date(byAdding: .day, value: -6, to: startOfDay) ?? startOfDay.addingTimeInterval(-6 * 86400)
            let weekRange = DateInterval(start: weekStart.addingTimeInterval(-30 * 3600), end: sleepEnd)
            let weekRecords = try await healthKitService.fetchSleepData(for: weekRange)

            weeklyData = (0 ..< 7).compactMap { dayOffset in
                let weekDate = calendar.date(byAdding: .day, value: -6 + dayOffset, to: date) ?? date
                let dayStart = calendar.startOfDay(for: weekDate)
                let dayRecords = weekRecords.filter { record in
                    record.startDate >= dayStart.addingTimeInterval(-30 * 3600) &&
                        record.startDate < dayStart.addingTimeInterval(12 * 3600)
                }
                guard let record = dayRecords.last else { return nil }
                let totalMin = Int(record.endDate.timeIntervalSince(record.startDate) / 60)
                return SleepData(
                    date: weekDate,
                    bedtime: record.startDate,
                    wakeTime: record.endDate,
                    totalMinutes: totalMin,
                    qualityScore: Double(record.quality.score),
                    efficiency: 0,
                    sleepLatency: 0,
                    interruptions: 0,
                    restfulness: 0,
                    stages: [],
                    timeline: [],
                    factors: []
                )
            }
        } catch {
            selectedDaySleep = nil
            weeklyData = []
        }
    }

    private func buildStageData(from segments: [SleepStageSegment], totalMinutes: Int) -> [SleepStageData] {
        let awake = segments.filter { $0.stage == .awake }.reduce(0) { $0 + $1.durationMinutes }
        let light = segments.filter { $0.stage == .light }.reduce(0) { $0 + $1.durationMinutes }
        let deep = segments.filter { $0.stage == .deep }.reduce(0) { $0 + $1.durationMinutes }
        let rem = segments.filter { $0.stage == .rem }.reduce(0) { $0 + $1.durationMinutes }
        let total = max(1, Double(totalMinutes))
        return [
            SleepStageData(stage: .awake, minutes: awake, percentage: Double(awake) / total * 100),
            SleepStageData(stage: .light, minutes: light, percentage: Double(light) / total * 100),
            SleepStageData(stage: .deep, minutes: deep, percentage: Double(deep) / total * 100),
            SleepStageData(stage: .rem, minutes: rem, percentage: Double(rem) / total * 100)
        ]
    }
}

#Preview {
    NavigationStack {
        SleepQualityView()
    }
}
