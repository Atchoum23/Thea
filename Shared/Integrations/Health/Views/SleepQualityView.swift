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
        case .positive: return "Positive"
        case .neutral: return "Neutral"
        case .negative: return "Negative"
        }
    }

    var color: Color {
        switch self {
        case .positive: return .green
        case .neutral: return .blue
        case .negative: return .red
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

    func loadData(for date: Date) async {
        // Would integrate with HealthKit
        // Mock data for demonstration
        await generateMockData(for: date)
    }

    private func generateMockData(for date: Date) async {
        // Simulate loading
        try? await Task.sleep(for: .milliseconds(300))

        let bedtime = Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: date.addingTimeInterval(-86_400))!
        let wakeTime = Calendar.current.date(bySettingHour: 6, minute: 45, second: 0, of: date)!

        let totalMinutes = 450 // 7h 30m

        let stages = [
            SleepStageData(stage: .awake, minutes: 30, percentage: 6.7),
            SleepStageData(stage: .light, minutes: 225, percentage: 50.0),
            SleepStageData(stage: .deep, minutes: 105, percentage: 23.3),
            SleepStageData(stage: .rem, minutes: 90, percentage: 20.0)
        ]

        let timeline = generateMockTimeline(from: bedtime, totalMinutes: totalMinutes)

        let factors = [
            SleepFactor(
                name: "Room Temperature",
                description: "Optimal at 68°F",
                icon: "thermometer.medium",
                impact: .positive
            ),
            SleepFactor(
                name: "Exercise",
                description: "Moderate activity 3 hours before bed",
                icon: "figure.run",
                impact: .positive
            ),
            SleepFactor(
                name: "Caffeine",
                description: "Last coffee at 2 PM",
                icon: "cup.and.saucer.fill",
                impact: .positive
            ),
            SleepFactor(
                name: "Screen Time",
                description: "Device usage until 11 PM",
                icon: "iphone",
                impact: .negative
            )
        ]

        selectedDaySleep = SleepData(
            date: date,
            bedtime: bedtime,
            wakeTime: wakeTime,
            totalMinutes: totalMinutes,
            qualityScore: 82.0,
            efficiency: 88.0,
            sleepLatency: 12,
            interruptions: 2,
            restfulness: 85.0,
            stages: stages,
            timeline: timeline,
            factors: factors
        )

        // Generate weekly data
        weeklyData = (0..<7).compactMap { dayOffset in
            let weekDate = Calendar.current.date(byAdding: .day, value: -dayOffset, to: date)!
            let randomQuality = Double.random(in: 65...90)
            let randomMinutes = Int.random(in: 360...480)

            return SleepData(
                date: weekDate,
                bedtime: bedtime,
                wakeTime: wakeTime,
                totalMinutes: randomMinutes,
                qualityScore: randomQuality,
                efficiency: 85.0,
                sleepLatency: 12,
                interruptions: 2,
                restfulness: 85.0,
                stages: stages,
                timeline: [],
                factors: []
            )
        }.reversed()
    }

    private func generateMockTimeline(from bedtime: Date, totalMinutes: Int) -> [SleepTimelineSegment] {
        var segments: [SleepTimelineSegment] = []
        var currentTime = bedtime

        let stagePattern: [(SleepStage, Int)] = [
            (.awake, 12),
            (.light, 45),
            (.deep, 35),
            (.light, 30),
            (.rem, 25),
            (.light, 40),
            (.deep, 35),
            (.light, 35),
            (.rem, 30),
            (.light, 50),
            (.rem, 35),
            (.light, 45),
            (.awake, 18)
        ]

        for (stage, minutes) in stagePattern {
            let endTime = currentTime.addingTimeInterval(TimeInterval(minutes * 60))
            segments.append(SleepTimelineSegment(
                stage: stage,
                startTime: currentTime,
                endTime: endTime
            ))
            currentTime = endTime
        }

        return segments
    }
}

#Preview {
    NavigationStack {
        SleepQualityView()
    }
}
