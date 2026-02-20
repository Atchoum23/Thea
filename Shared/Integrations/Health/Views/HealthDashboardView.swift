import SwiftUI
import OSLog

// periphery:ignore - Reserved: healthDashboardLogger global var reserved for future feature activation
private let healthDashboardLogger = Logger(subsystem: "ai.thea.app", category: "HealthDashboardView")

/// Main health dashboard view
public struct HealthDashboardView: View {
    @State private var exportURL: URL?
    @State private var viewModel = HealthDashboardViewModel()
    // AAI3-4: NutritionBarcodeService wire-in — scan food barcodes → HealthKit logging
    @ObservedObject private var nutritionService = NutritionBarcodeService.shared
    @State private var showingNutritionLastScan = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !viewModel.isAuthorized {
                    authorizationView
                } else if viewModel.isLoading {
                    ProgressView("Loading health data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    healthDataView
                }
            }
            .padding()
        }
        .navigationTitle("Health Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export health data")
                    }

                    // AAI3-4: Scan food barcode → log to HealthKit
                    Button {
                        if let product = nutritionService.lastProduct {
                            showingNutritionLastScan = true
                            _ = product // suppress warning
                        } else {
                            nutritionService.scanAndLog()
                        }
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    .accessibilityLabel("Scan food barcode")
                    .popover(isPresented: $showingNutritionLastScan) {
                        if let p = nutritionService.lastProduct {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(p.name).font(.headline)
                                Text(p.brand).foregroundStyle(.secondary)
                                Text("\(Int(p.caloriesPerServing)) kcal/serving")
                                Text("P: \(String(format: "%.1f", p.proteinG))g  F: \(String(format: "%.1f", p.fatG))g  C: \(String(format: "%.1f", p.carbsG))g")
                                    .font(.caption)
                            }
                            .padding()
                        }
                    }

                    Button(action: {
                        Task {
                            await viewModel.refreshData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Refresh health data")
                }
            }
        }
        .task {
            await viewModel.loadAllData()
        }
    }

    // MARK: - Authorization View

    private var authorizationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Health Data Access")
                .font(.title)
                .fontWeight(.bold)

            Text("Thea needs permission to access your health data to provide personalized insights and tracking.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button(action: {
                Task {
                    await viewModel.requestAuthorization()
                }
            }) {
                Text("Grant Access")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Health Data View

    private var healthDataView: some View {
        VStack(spacing: 20) {
            // Anomaly alerts
            if viewModel.hasCardiacAnomalies {
                anomalyAlertsSection
            }

            // Summary cards
            HStack(spacing: 16) {
                sleepSummaryCard
                activitySummaryCard
            }

            // Sleep section
            sleepSection

            // Activity section
            activitySection

            // Heart rate section
            heartRateSection

            // Blood pressure section
            if !viewModel.bloodPressureReadings.isEmpty {
                bloodPressureSection
            }
        }
    }

    // MARK: - Anomaly Alerts

    private var anomalyAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚠️ Health Alerts")
                .font(.headline)

            ForEach(viewModel.cardiacAnomalies.prefix(3)) { anomaly in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(hex: anomaly.severity.color))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(anomaly.type.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(anomaly.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(anomaly.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(hex: anomaly.severity.color).opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Summary Cards

    private var sleepSummaryCard: some View {
        SummaryCard(
            icon: "bed.double.fill",
            title: "Sleep Quality",
            value: viewModel.averageSleepQuality.displayName,
            color: Color(hex: viewModel.averageSleepQuality.color),
            trend: viewModel.getSleepTrend()
        )
    }

    private var activitySummaryCard: some View {
        SummaryCard(
            icon: "figure.walk",
            title: "Activity",
            value: viewModel.todayActivitySummary.map { "\($0.activityScore)%" } ?? "No data",
            color: .blue,
            trend: viewModel.getActivityTrend()
        )
    }

    // MARK: - Sleep Section

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sleep")
                .font(.headline)

            ForEach(viewModel.sleepRecords.prefix(5)) { record in
                SleepRecordRow(record: record, viewModel: viewModel)
            }
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Activity")
                .font(.headline)

            ForEach(viewModel.activitySummaries.prefix(7)) { summary in
                ActivitySummaryRow(summary: summary, viewModel: viewModel)
            }
        }
    }

    // MARK: - Heart Rate Section

    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Heart Rate")
                    .font(.headline)

                Spacer()

                if viewModel.averageRestingHeartRate > 0 {
                    Text("Avg: \(viewModel.averageRestingHeartRate) bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let latest = viewModel.heartRateRecords.first {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)

                    Text("\(latest.beatsPerMinute) bpm")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(latest.context.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(latest.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Blood Pressure Section

    private var bloodPressureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Blood Pressure")
                .font(.headline)

            ForEach(viewModel.bloodPressureReadings.prefix(5)) { reading in
                BloodPressureRow(reading: reading)
            }
        }
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let trend: Trend

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)

                Spacer()

                Text(trend.displayName)
                    .font(.caption2)
                    .foregroundColor(Color(hex: trend.color))
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Sleep Record Row

private struct SleepRecordRow: View {
    let record: SleepRecord
    let viewModel: HealthDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.startDate, style: .date)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(record.quality.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: record.quality.color).opacity(0.2))
                    .foregroundColor(Color(hex: record.quality.color))
                    .cornerRadius(8)
            }

            HStack(spacing: 16) {
                MetricPill(
                    icon: "bed.double.fill",
                    value: viewModel.formatDuration(record.totalMinutes),
                    color: .blue
                )

                MetricPill(
                    icon: "moon.fill",
                    value: viewModel.formatDuration(record.deepMinutes),
                    color: .indigo
                )

                MetricPill(
                    icon: "brain.head.profile",
                    value: viewModel.formatDuration(record.remMinutes),
                    color: .purple
                )

                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Activity Summary Row

private struct ActivitySummaryRow: View {
    let summary: ActivitySummary
    let viewModel: HealthDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(summary.activityScore)%")
                    .font(.caption)
                    .fontWeight(.bold)
            }

            HStack(spacing: 12) {
                MetricPill(
                    icon: "figure.walk",
                    value: "\(summary.steps)",
                    color: .green
                )

                MetricPill(
                    icon: "flame.fill",
                    value: "\(summary.activeCalories) cal",
                    color: .orange
                )

                MetricPill(
                    icon: "timer",
                    value: viewModel.formatDuration(summary.activeMinutes),
                    color: .blue
                )

                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Blood Pressure Row

private struct BloodPressureRow: View {
    let reading: BloodPressureReading

    var body: some View {
        HStack {
            Image(systemName: "waveform.path.ecg")
                .foregroundColor(Color(hex: reading.category.color))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(reading.systolic)/\(reading.diastolic) mmHg")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(reading.category.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(reading.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Metric Pill

private struct MetricPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)

            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HealthDashboardView()
    }
}
