// PersonalBaselineMonitor.swift
// Thea
//
// Anomaly detection on personal health baselines.
// Establishes rolling 30-day baselines per metric,
// computes z-scores, runs CUSUM change-point detection,
// and fires proactive alerts on significant deviations.

import Foundation
import HealthKit
import os.log

// MARK: - Supporting Types

enum AnomalyDeviation: String, Codable, Sendable {
    case aboveNormal
    case belowNormal
    case sustained3Day
    case sustained7Day
}

enum HealthAnomalySeverity: String, Codable, Sendable, Comparable {
    case mild
    case moderate
    case significant
    case critical

    private var rank: Int {
        switch self {
        case .mild: 0
        case .moderate: 1
        case .significant: 2
        case .critical: 3
        }
    }

    static func < (lhs: HealthAnomalySeverity, rhs: HealthAnomalySeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

struct MetricBaseline: Codable, Sendable {
    let metricName: String
    var rollingMean: Double
    var rollingStdDev: Double
    var recentValues: [Double]
    var lastUpdated: Date

    /// Maximum number of values kept in the rolling window.
    static let windowSize = 30
}

struct AnomalyAlert: Codable, Sendable, Identifiable {
    var id: String { "\(metricName)-\(timestamp.timeIntervalSince1970)" }
    let metricName: String
    let currentValue: Double
    let baselineMean: Double
    let zScore: Double
    let deviation: AnomalyDeviation
    let severity: HealthAnomalySeverity
    let message: String
    let timestamp: Date
}

// MARK: - PersonalBaselineMonitor

@MainActor
@Observable
final class PersonalBaselineMonitor: Sendable {

    // MARK: Singleton

    static let shared = PersonalBaselineMonitor()

    // MARK: Published State

    private(set) var baselines: [String: MetricBaseline] = [:]
    private(set) var activeAlerts: [AnomalyAlert] = []
    private(set) var alertHistory: [AnomalyAlert] = []

    // MARK: Private

    private let logger = Logger(subsystem: "ai.thea.app", category: "PersonalBaseline")
    private let healthStore = HKHealthStore()

    /// CUSUM accumulator per metric (not persisted — rebuilt on launch).
    private var cusumUpperAccumulator: [String: Double] = [:]
    private var cusumLowerAccumulator: [String: Double] = [:]

    /// Metric-name to HealthKit mapping.
    private static let metricDefinitions: [(name: String, quantityType: HKQuantityTypeIdentifier?, categoryType: HKCategoryTypeIdentifier?, unit: HKUnit)] = [
        ("restingHeartRate",      .restingHeartRate,            nil,            HKUnit.count().unitDivided(by: .minute())),
        ("heartRateVariability",  .heartRateVariabilitySDNN,    nil,            HKUnit.secondUnit(with: .milli)),
        ("stepCount",             .stepCount,                   nil,            .count()),
        ("exerciseMinutes",       .appleExerciseTime,           nil,            .minute()),
        ("activeCalories",        .activeEnergyBurned,          nil,            .kilocalorie()),
        ("respiratoryRate",       .respiratoryRate,             nil,            HKUnit.count().unitDivided(by: .minute())),
        ("sleepDuration",         nil,                          .sleepAnalysis, .hour()),
    ]

    // MARK: Init

    private init() {
        loadFromDisk()
        pruneAlertHistory()
        logger.info("PersonalBaselineMonitor initialized with \(self.baselines.count) tracked metrics")
    }

    // MARK: - Public API

    /// Add a new data point and recompute the rolling baseline.
    func updateBaseline(metric: String, value: Double) {
        var baseline = baselines[metric] ?? MetricBaseline(
            metricName: metric,
            rollingMean: 0,
            rollingStdDev: 0,
            recentValues: [],
            lastUpdated: Date()
        )

        baseline.recentValues.append(value)

        // Trim to window size.
        if baseline.recentValues.count > MetricBaseline.windowSize {
            baseline.recentValues.removeFirst(baseline.recentValues.count - MetricBaseline.windowSize)
        }

        // Recompute statistics.
        let count = Double(baseline.recentValues.count)
        let mean = baseline.recentValues.reduce(0, +) / count
        let variance = baseline.recentValues.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / max(count - 1, 1)
        let stdDev = sqrt(variance)

        baseline.rollingMean = mean
        baseline.rollingStdDev = stdDev
        baseline.lastUpdated = Date()

        baselines[metric] = baseline
        saveToDisk()

        logger.debug("Updated baseline for \(metric): mean=\(String(format: "%.2f", mean)), stddev=\(String(format: "%.2f", stdDev)), n=\(baseline.recentValues.count)")
    }

    /// Scan all tracked baselines and return any anomalies detected right now.
    func checkForAnomalies() -> [AnomalyAlert] {
        var alerts: [AnomalyAlert] = []
        let now = Date()

        for (metric, baseline) in baselines {
            guard baseline.recentValues.count >= 7 else { continue }
            guard baseline.rollingStdDev > 0 else { continue }

            guard let latestValue = baseline.recentValues.last else { continue }
            let zScore = (latestValue - baseline.rollingMean) / baseline.rollingStdDev
            let absZ = abs(zScore)

            guard absZ > 1.5 else { continue }

            let severity = severityForZScore(absZ)
            let deviation = classifyDeviation(metric: metric, zScore: zScore, baseline: baseline)
            let message = generateMessage(metric: metric, currentValue: latestValue, baseline: baseline, deviation: deviation)

            let alert = AnomalyAlert(
                metricName: metric,
                currentValue: latestValue,
                baselineMean: baseline.rollingMean,
                zScore: zScore,
                deviation: deviation,
                severity: severity,
                message: message,
                timestamp: now
            )
            alerts.append(alert)
        }

        activeAlerts = alerts
        alertHistory.append(contentsOf: alerts)
        pruneAlertHistory()
        saveToDisk()

        if !alerts.isEmpty {
            logger.notice("Detected \(alerts.count) anomalies: \(alerts.map { $0.metricName }.joined(separator: ", "))")
        }

        return alerts
    }

    /// Full daily workflow: query HealthKit, update baselines, check anomalies.
    func runDailyCheck() async {
        logger.info("Starting daily baseline check")

        guard HKHealthStore.isHealthDataAvailable() else {
            logger.warning("HealthKit not available on this device")
            return
        }

        let calendar = Calendar.current
        let endOfDay = Date()
        guard let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: endOfDay) else { return }

        for definition in Self.metricDefinitions {
            do {
                let value: Double?
                if definition.name == "sleepDuration" {
                    value = try await querySleepDuration(start: startOfDay, end: endOfDay)
                } else if let quantityID = definition.quantityType {
                    value = try await queryDailySum(
                        quantityType: HKQuantityType(quantityID),
                        unit: definition.unit,
                        start: startOfDay,
                        end: endOfDay,
                        isCumulative: ["stepCount", "exerciseMinutes", "activeCalories"].contains(definition.name)
                    )
                } else {
                    value = nil
                }

                if let value {
                    updateBaseline(metric: definition.name, value: value)
                    logger.debug("Daily value for \(definition.name): \(String(format: "%.2f", value))")
                }
            } catch {
                logger.error("Failed to query \(definition.name): \(error.localizedDescription)")
            }
        }

        let alerts = checkForAnomalies()
        if !alerts.isEmpty {
            logger.notice("Daily check produced \(alerts.count) alert(s)")
        } else {
            logger.info("Daily check complete — no anomalies")
        }
    }

    /// CUSUM (Cumulative Sum) change-point detection for sustained shifts.
    /// Returns `true` when a sustained directional shift exceeds the threshold.
    func cusumChangeDetection(metric: String, threshold: Double = 2.0) -> Bool {
        guard let baseline = baselines[metric],
              baseline.recentValues.count >= 7,
              baseline.rollingStdDev > 0,
              let latestValue = baseline.recentValues.last else {
            return false
        }

        let normalized = (latestValue - baseline.rollingMean) / baseline.rollingStdDev

        // Allowance (slack) — small deviations are absorbed.
        let slack = 0.5

        let upperPrev = cusumUpperAccumulator[metric] ?? 0
        let lowerPrev = cusumLowerAccumulator[metric] ?? 0

        let upperNew = max(0, upperPrev + normalized - slack)
        let lowerNew = max(0, lowerPrev - normalized - slack)

        cusumUpperAccumulator[metric] = upperNew
        cusumLowerAccumulator[metric] = lowerNew

        let triggered = upperNew > threshold || lowerNew > threshold

        if triggered {
            // Reset after detection to avoid repeated alerts.
            cusumUpperAccumulator[metric] = 0
            cusumLowerAccumulator[metric] = 0
            logger.notice("CUSUM triggered for \(metric) (upper=\(String(format: "%.2f", upperNew)), lower=\(String(format: "%.2f", lowerNew)))")
        }

        return triggered
    }

    // MARK: - Severity Classification

    private func severityForZScore(_ absZ: Double) -> HealthAnomalySeverity {
        switch absZ {
        case 3.0...: .critical
        case 2.5..<3.0: .significant
        case 2.0..<2.5: .moderate
        default: .mild
        }
    }

    // MARK: - Deviation Classification

    private func classifyDeviation(metric: String, zScore: Double, baseline: MetricBaseline) -> AnomalyDeviation {
        let recentCount = baseline.recentValues.count

        // Check for sustained deviations.
        if recentCount >= 7 {
            let last7 = baseline.recentValues.suffix(7)
            let allAbove = last7.allSatisfy { $0 > baseline.rollingMean + baseline.rollingStdDev }
            let allBelow = last7.allSatisfy { $0 < baseline.rollingMean - baseline.rollingStdDev }
            if allAbove || allBelow {
                return .sustained7Day
            }
        }

        if recentCount >= 3 {
            let last3 = baseline.recentValues.suffix(3)
            let allAbove = last3.allSatisfy { $0 > baseline.rollingMean + baseline.rollingStdDev }
            let allBelow = last3.allSatisfy { $0 < baseline.rollingMean - baseline.rollingStdDev }
            if allAbove || allBelow {
                return .sustained3Day
            }
        }

        return zScore > 0 ? .aboveNormal : .belowNormal
    }

    // MARK: - Message Generation

    private func generateMessage(metric: String, currentValue: Double, baseline: MetricBaseline, deviation: AnomalyDeviation) -> String {
        let friendlyName = friendlyMetricName(metric)
        let formattedCurrent = formatValue(currentValue, metric: metric)
        let formattedMean = formatValue(baseline.rollingMean, metric: metric)
        let unit = unitLabel(for: metric)

        switch deviation {
        case .sustained7Day:
            let direction = currentValue > baseline.rollingMean ? "above" : "below"
            let diff = formatValue(abs(currentValue - baseline.rollingMean), metric: metric)
            return "Your \(friendlyName) (\(formattedCurrent) \(unit)) has been \(diff) \(unit) \(direction) your 30-day average for 7 consecutive days"
        case .sustained3Day:
            let direction = currentValue > baseline.rollingMean ? "above" : "below"
            let diff = formatValue(abs(currentValue - baseline.rollingMean), metric: metric)
            return "Your \(friendlyName) (\(formattedCurrent) \(unit)) has been \(diff) \(unit) \(direction) your 30-day average for 3 consecutive days"
        case .aboveNormal:
            return "\(friendlyName) anomaly: \(formattedCurrent) \(unit) today vs your usual \(formattedMean) \(unit)"
        case .belowNormal:
            return "Your \(friendlyName) dropped to \(formattedCurrent) \(unit) — significantly below your \(formattedMean) \(unit) baseline"
        }
    }

    private func friendlyMetricName(_ metric: String) -> String {
        switch metric {
        case "restingHeartRate": "resting heart rate"
        case "heartRateVariability": "heart rate variability"
        case "sleepDuration": "sleep duration"
        case "stepCount": "step count"
        case "exerciseMinutes": "exercise minutes"
        case "activeCalories": "active calories"
        case "respiratoryRate": "respiratory rate"
        default: metric
        }
    }

    private func unitLabel(for metric: String) -> String {
        switch metric {
        case "restingHeartRate": "BPM"
        case "heartRateVariability": "ms"
        case "sleepDuration": "hours"
        case "stepCount": "steps"
        case "exerciseMinutes": "minutes"
        case "activeCalories": "kcal"
        case "respiratoryRate": "breaths/min"
        default: ""
        }
    }

    private func formatValue(_ value: Double, metric: String) -> String {
        switch metric {
        case "stepCount":
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        case "sleepDuration":
            return String(format: "%.1f", value)
        case "heartRateVariability":
            return String(format: "%.1f", value)
        default:
            return String(format: "%.0f", value)
        }
    }

    // MARK: - HealthKit Queries

    private func queryDailySum(
        quantityType: HKQuantityType,
        unit: HKUnit,
        start: Date,
        end: Date,
        isCumulative: Bool
    ) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        if isCumulative {
            let descriptor = HKStatisticsQueryDescriptor(
                predicate: HKSamplePredicate<HKQuantitySample>.quantitySample(type: quantityType, predicate: predicate),
                options: .cumulativeSum
            )
            let result = try await descriptor.result(for: healthStore)
            return result?.sumQuantity()?.doubleValue(for: unit)
        } else {
            // For discrete metrics (heart rate, HRV, respiratory rate), use the most recent sample.
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: quantityType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
                limit: 1
            )
            let samples = try await descriptor.result(for: healthStore)
            return samples.first?.quantity.doubleValue(for: unit)
        }
    }

    private func querySleepDuration(start: Date, end: Date) async throws -> Double? {
        guard let sleepType = HKCategoryType(.sleepAnalysis) as HKCategoryType? else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)],
            limit: HKObjectQueryNoLimit
        )

        let samples = try await descriptor.result(for: healthStore)

        // Sum duration of non-awake sleep stages.
        let totalSeconds = samples.reduce(0.0) { total, sample in
            let value = sample.value
            // Filter out "inBed" (0) and "awake" (2) — keep asleepUnspecified(1), asleepCore(3), asleepDeep(4), asleepREM(5).
            let isAsleep = value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            guard isAsleep else { return total }
            return total + sample.endDate.timeIntervalSince(sample.startDate)
        }

        let hours = totalSeconds / 3600.0
        return hours > 0 ? hours : nil
    }

    // MARK: - Alert History Management

    private func pruneAlertHistory() {
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        alertHistory.removeAll { $0.timestamp < ninetyDaysAgo }
    }

    // MARK: - Persistence

    private static var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Thea/Health", isDirectory: true)
    }

    private static var baselinesFileURL: URL {
        storageDirectory.appendingPathComponent("baselines.json")
    }

    private static var alertHistoryFileURL: URL {
        storageDirectory.appendingPathComponent("alert_history.json")
    }

    private func saveToDisk() {
        let directory = Self.storageDirectory
        let fileManager = FileManager.default
        do {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let baselinesData = try encoder.encode(baselines)
            try baselinesData.write(to: Self.baselinesFileURL, options: .atomic)

            let historyData = try encoder.encode(alertHistory)
            try historyData.write(to: Self.alertHistoryFileURL, options: .atomic)

            logger.debug("Saved baselines and alert history to disk")
        } catch {
            logger.error("Failed to save baselines: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: Self.baselinesFileURL),
           let decoded = try? decoder.decode([String: MetricBaseline].self, from: data) {
            baselines = decoded
            logger.info("Loaded \(decoded.count) baselines from disk")
        }

        if let data = try? Data(contentsOf: Self.alertHistoryFileURL),
           let decoded = try? decoder.decode([AnomalyAlert].self, from: data) {
            alertHistory = decoded
            logger.info("Loaded \(decoded.count) historical alerts from disk")
        }
    }
}
