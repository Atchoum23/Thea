import Charts
import SwiftUI

/// Blood pressure tracking view with trend analysis
public struct BloodPressureView: View {
    @State private var viewModel = BloodPressureViewModel()
    @State private var showingLogger = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Reading
                if let latest = viewModel.latestReading {
                    currentReadingCard(latest)
                }

                // Trend Chart
                if !viewModel.readings.isEmpty {
                    trendChartSection
                }

                // Statistics
                statisticsSection

                // Recent Readings
                recentReadingsSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Blood Pressure")
        .toolbar {
            Button {
                showingLogger = true
            } label: {
                Label("Log Reading", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingLogger) {
            BloodPressureLoggerView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Current Reading Card

    private func currentReadingCard(_ reading: BloodPressureReading) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Latest Reading")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(reading.systolic)")
                            .font(.system(size: 48, weight: .bold))

                        Text("/")
                            .font(.title)
                            .foregroundStyle(.secondary)

                        Text("\(reading.diastolic)")
                            .font(.system(size: 48, weight: .bold))
                    }

                    Text("mmHg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(reading.category.displayName)
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(reading.category.color).opacity(0.2))
                        .foregroundStyle(Color(reading.category.color))
                        .clipShape(Capsule())

                    // Pulse data not available in current model
                    /* if let pulse = reading.pulse {
                         HStack(spacing: 4) {
                             Image(systemName: "heart.fill")
                                 .foregroundStyle(.red)
                             Text("\(pulse) BPM")
                                 .font(.subheadline)
                         }
                     } */
                }
            }

            Text(reading.timestamp, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Trend Chart Section

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Trend")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(viewModel.readings.prefix(7)) { reading in
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Systolic", reading.systolic)
                    )
                    .foregroundStyle(.red)
                    .symbol(.circle)

                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Diastolic", reading.diastolic)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.circle)
                }

                // Reference lines
                RuleMark(y: .value("Normal Systolic", 120))
                    .foregroundStyle(.red.opacity(0.3))
                    .lineStyle(StrokeStyle(dash: [5]))

                RuleMark(y: .value("Normal Diastolic", 80))
                    .foregroundStyle(.blue.opacity(0.3))
                    .lineStyle(StrokeStyle(dash: [5]))
            }
            .frame(height: 200)
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics (7 Days)")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                BPStatCard(
                    title: "Avg Systolic",
                    value: "\(viewModel.averageSystolic)",
                    unit: "mmHg",
                    color: .red
                )

                BPStatCard(
                    title: "Avg Diastolic",
                    value: "\(viewModel.averageDiastolic)",
                    unit: "mmHg",
                    color: .blue
                )

                if viewModel.averagePulse > 0 {
                    BPStatCard(
                        title: "Avg Pulse",
                        value: "\(viewModel.averagePulse)",
                        unit: "BPM",
                        color: .pink
                    )
                }

                BPStatCard(
                    title: "Readings",
                    value: "\(viewModel.readingCount)",
                    unit: "",
                    color: .green
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Recent Readings Section

    private var recentReadingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Readings")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.readings.prefix(10)) { reading in
                ReadingRow(reading: reading)
            }
        }
    }
}

// MARK: - Stat Card

private struct BPStatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2)
                .bold()
                .foregroundStyle(color)

            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Reading Row

private struct ReadingRow: View {
    let reading: BloodPressureReading

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(reading.systolic)/\(reading.diastolic)")
                    .font(.headline)

                Text(reading.timestamp, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(reading.category.displayName)
                    .font(.caption)
                    .foregroundStyle(Color(reading.category.color))

                if let pulse = reading.pulse {
                    Text("\(pulse) BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

// MARK: - Logger View

private struct BloodPressureLoggerView: View {
    @Bindable var viewModel: BloodPressureViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var systolic = ""
    @State private var diastolic = ""
    @State private var pulse = ""
    @State private var timestamp = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Blood Pressure") {
                    TextField("Systolic", text: $systolic)
                    TextField("Diastolic", text: $diastolic)
                }

                Section("Pulse (Optional)") {
                    TextField("Heart Rate (BPM)", text: $pulse)
                }

                Section("Time") {
                    DatePicker("Timestamp", selection: $timestamp)
                }
            }
            .navigationTitle("Log Reading")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let sys = Int(systolic), let dia = Int(diastolic) {
                            Task {
                                await viewModel.logReading(
                                    systolic: sys,
                                    diastolic: dia,
                                    pulse: Int(pulse),
                                    timestamp: timestamp
                                )
                                dismiss()
                            }
                        }
                    }
                    .disabled(systolic.isEmpty || diastolic.isEmpty)
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class BloodPressureViewModel {
    var readings: [BloodPressureReading] = []
    var isLoading = false
    private let healthKitService = HealthKitService()

    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await healthKitService.requestAuthorization()
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate) ?? endDate.addingTimeInterval(-90 * 86400)
            let dateRange = DateInterval(start: startDate, end: endDate)
            readings = try await healthKitService.fetchBloodPressureData(for: dateRange)
                .sorted { $0.timestamp > $1.timestamp }
        } catch {
            readings = []
        }
    }

    func logReading(systolic: Int, diastolic: Int, pulse: Int?, timestamp: Date) async {
        let reading = BloodPressureReading(
            timestamp: timestamp,
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse,
            source: .manual
        )
        readings.insert(reading, at: 0)
    }

    var latestReading: BloodPressureReading? {
        readings.first
    }

    var averageSystolic: Int {
        guard !readings.isEmpty else { return 0 }
        return readings.reduce(0) { $0 + $1.systolic } / readings.count
    }

    var averageDiastolic: Int {
        guard !readings.isEmpty else { return 0 }
        return readings.reduce(0) { $0 + $1.diastolic } / readings.count
    }

    var averagePulse: Int {
        let pulseReadings = readings.compactMap(\.pulse)
        guard !pulseReadings.isEmpty else { return 0 }
        return pulseReadings.reduce(0, +) / pulseReadings.count
    }

    var readingCount: Int {
        readings.count
    }
}

// MARK: - Models

enum BPCategory {
    case normal
    case elevated
    case stage1Hypertension
    case stage2Hypertension
    case hypertensiveCrisis

    var displayName: String {
        switch self {
        case .normal: "Normal"
        case .elevated: "Elevated"
        case .stage1Hypertension: "Stage 1"
        case .stage2Hypertension: "Stage 2"
        case .hypertensiveCrisis: "Crisis"
        }
    }

    var color: String {
        switch self {
        case .normal: "green"
        case .elevated: "yellow"
        case .stage1Hypertension: "orange"
        case .stage2Hypertension: "red"
        case .hypertensiveCrisis: "purple"
        }
    }
}

#Preview {
    NavigationStack {
        BloodPressureView()
    }
}
