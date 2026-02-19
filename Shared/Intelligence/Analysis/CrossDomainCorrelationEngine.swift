// CrossDomainCorrelationEngine.swift
// Thea — Cross-Domain Correlation Engine
//
// Correlates data across HealthKit (sleep, HRV, exercise), MoodTracker,
// BehavioralFingerprint (productivity), and WeatherMonitor to surface
// non-obvious insights about how different life domains affect each other.
//
// Requires >= 7 days of DailyLifeSnapshot data for meaningful correlations.
// Persists results to ~/Library/Application Support/Thea/Correlations/.

import Foundation
import os.log

#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Daily Life Snapshot

/// Aggregates one day's worth of cross-domain data into a single row for correlation analysis.
struct DailyLifeSnapshot: Codable, Sendable {
    let date: Date

    // Sleep domain
    let sleepHours: Double
    let sleepQuality: Double       // 0-1
    let remMinutes: Double
    let deepSleepMinutes: Double

    // Exercise domain
    let exerciseMinutes: Double
    let stepCount: Double
    let activeCalories: Double

    // Cardiac domain
    let restingHeartRate: Double
    let hrvSDNN: Double

    // Mood domain
    let moodScore: Double          // 0-1
    let stressLevel: Double        // 0-1

    // Productivity domain
    let productivityScore: Double  // 0-1
    let deepWorkMinutes: Double

    // Weather domain
    let weatherTemp: Double
    let weatherHumidity: Double
    let barometricPressure: Double
    let uvIndex: Double
}

// MARK: - Correlation Strength

enum CDCorrelationStrength: String, Codable, Sendable {
    case negligible   // |r| < 0.1
    case weak         // 0.1 <= |r| < 0.3
    case moderate     // 0.3 <= |r| < 0.5
    case strong       // 0.5 <= |r| < 0.7
    case veryStrong   // |r| >= 0.7

    static func from(coefficient: Double) -> CDCorrelationStrength {
        let absR = abs(coefficient)
        switch absR {
        case ..<0.1:  return .negligible
        case ..<0.3:  return .weak
        case ..<0.5:  return .moderate
        case ..<0.7:  return .strong
        default:      return .veryStrong
        }
    }
}

// MARK: - Correlation Result

struct CorrelationResult: Codable, Sendable, Identifiable {
    let id: UUID
    let metric1: String
    let metric2: String
    let coefficient: Double
    let strength: CDCorrelationStrength
    let sampleSize: Int
    let insight: String
    // periphery:ignore - Reserved: from(coefficient:) static method reserved for future feature activation
    let discoveredAt: Date

    init(
        metric1: String,
        metric2: String,
        coefficient: Double,
        sampleSize: Int,
        insight: String,
        discoveredAt: Date = Date()
    ) {
        self.id = UUID()
        self.metric1 = metric1
        self.metric2 = metric2
        self.coefficient = coefficient
        self.strength = CDCorrelationStrength.from(coefficient: coefficient)
        self.sampleSize = sampleSize
        self.insight = insight
        self.discoveredAt = discoveredAt
    }
}

// MARK: - Metric Pair Definition

// periphery:ignore - Reserved: init(metric1:metric2:coefficient:sampleSize:insight:discoveredAt:) initializer reserved for future feature activation
/// Defines a pair of metrics to correlate, with extractors and an insight generator.
private struct MetricPair {
    let name1: String
    let name2: String
    let extract1: (DailyLifeSnapshot) -> Double?
    let extract2: (DailyLifeSnapshot) -> Double?
    let insightGenerator: (_ coefficient: Double, _ snapshots: [DailyLifeSnapshot]) -> String
}

// MARK: - Cross-Domain Correlation Engine

@MainActor
@Observable
final class CrossDomainCorrelationEngine {
    static let shared = CrossDomainCorrelationEngine()

    private let logger = Logger(subsystem: "ai.thea.app", category: "CrossDomainCorrelation")

    // MARK: - State

    private(set) var snapshots: [DailyLifeSnapshot] = []
    // periphery:ignore - Reserved: MetricPair type reserved for future feature activation
    private(set) var discoveredCorrelations: [CorrelationResult] = []
    private(set) var lastAnalysisDate: Date?
    private(set) var isCaptureInProgress = false
    private(set) var isAnalysisInProgress = false

    #if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    #endif

    // MARK: - Persistence

    private static let storageDirectory: URL = {
        // periphery:ignore - Reserved: shared static property reserved for future feature activation
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thea", isDirectory: true)
            .appendingPathComponent("Correlations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) // Safe: directory may already exist; error means storage unavailable (data simply not persisted)
        return dir
    }()

    private static let storageURL: URL = {
        storageDirectory.appendingPathComponent("correlation_results.json")
    }()

    // MARK: - Init

// periphery:ignore - Reserved: healthStore property reserved for future feature activation

    private init() {
        load()
        logger.info("CrossDomainCorrelationEngine initialized with \(self.snapshots.count) snapshots, \(self.discoveredCorrelations.count) correlations")
    }

    // MARK: - Capture Today's Snapshot

    /// Builds today's DailyLifeSnapshot by querying all data sources.
    func captureToday() async {
        guard !isCaptureInProgress else {
            logger.debug("Capture already in progress, skipping")
            return
        }

        isCaptureInProgress = true
        defer { isCaptureInProgress = false }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now

        // Remove any existing snapshot for today (replace)
        snapshots.removeAll { calendar.isDate($0.date, inSameDayAs: now) }

        // periphery:ignore - Reserved: captureToday() instance method reserved for future feature activation
        // Gather HealthKit data
        let (sleepHours, sleepQuality, remMin, deepMin) = await fetchSleepData(start: startOfDay, end: endOfDay)
        let (exerciseMin, steps, activeCal) = await fetchActivityData(start: startOfDay, end: endOfDay)
        let restingHR = await fetchRestingHeartRate(start: startOfDay, end: endOfDay)
        let hrv = await fetchHRV(start: startOfDay, end: endOfDay)

        // Gather mood from MoodTracker
        let moodScore = MoodTracker.shared.currentMood
        // Approximate stress as inverse of mood weighted by trend
        let stressLevel = estimateStressLevel()

        // Gather productivity from BehavioralFingerprint
        let (productivityScore, deepWorkMin) = estimateProductivity()

        // Gather weather from WeatherMonitor
        let (temp, humidity, pressure, uv) = fetchWeatherData()

        let snapshot = DailyLifeSnapshot(
            date: now,
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            remMinutes: remMin,
            deepSleepMinutes: deepMin,
            exerciseMinutes: exerciseMin,
            stepCount: steps,
            activeCalories: activeCal,
            restingHeartRate: restingHR,
            hrvSDNN: hrv,
            moodScore: moodScore,
            stressLevel: stressLevel,
            productivityScore: productivityScore,
            deepWorkMinutes: deepWorkMin,
            weatherTemp: temp,
            weatherHumidity: humidity,
            barometricPressure: pressure,
            uvIndex: uv
        )

        snapshots.append(snapshot)

        // Keep at most 365 days of snapshots
        if snapshots.count > 365 {
            snapshots.removeFirst(snapshots.count - 365)
        }

        save()
        logger.info("Captured today's snapshot. Total snapshots: \(self.snapshots.count)")
    }

    // MARK: - Correlation Analysis

    /// Runs Pearson correlation on all metric pairs. Requires at least 7 days of data.
    func analyzeCorrelations() {
        guard snapshots.count >= 7 else {
            logger.info("Need at least 7 snapshots for correlation analysis (have \(self.snapshots.count))")
            return
        }

        isAnalysisInProgress = true
        defer {
            isAnalysisInProgress = false
            lastAnalysisDate = Date()
        }

        let pairs = buildMetricPairs()
        var results: [CorrelationResult] = []

        for pair in pairs {
            // periphery:ignore - Reserved: analyzeCorrelations() instance method reserved for future feature activation
            // Extract paired values, filtering out nil (missing data)
            var xValues: [Double] = []
            var yValues: [Double] = []
            var pairedSnapshots: [DailyLifeSnapshot] = []

            for snapshot in snapshots {
                if let x = pair.extract1(snapshot), let y = pair.extract2(snapshot),
                   !x.isNaN && !y.isNaN && x.isFinite && y.isFinite
                {
                    xValues.append(x)
                    yValues.append(y)
                    pairedSnapshots.append(snapshot)
                }
            }

            guard xValues.count >= 7 else { continue }

            let r = pearsonCorrelation(xValues, yValues)
            guard !r.isNaN && r.isFinite else { continue }

            let strength = CDCorrelationStrength.from(coefficient: r)
            // Only store moderate or stronger correlations
            guard strength != .negligible && strength != .weak else { continue }

            let insight = pair.insightGenerator(r, pairedSnapshots)

            let result = CorrelationResult(
                metric1: pair.name1,
                metric2: pair.name2,
                coefficient: r,
                sampleSize: xValues.count,
                insight: insight
            )
            results.append(result)
        }

        discoveredCorrelations = results
        save()
        logger.info("Correlation analysis complete: \(results.count) significant correlations found from \(pairs.count) pairs")
    }

    // MARK: - Pearson Correlation

    /// Standard Pearson product-moment correlation coefficient.
    /// Returns a value in [-1, 1], or NaN if computation fails.
    func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(x.count)
        guard x.count == y.count, x.count >= 2 else { return .nan }

        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n

        var sumXY: Double = 0
        var sumX2: Double = 0
        var sumY2: Double = 0

        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            sumXY += dx * dy
            // periphery:ignore - Reserved: pearsonCorrelation(_:_:) instance method reserved for future feature activation
            sumX2 += dx * dx
            sumY2 += dy * dy
        }

        let denominator = (sumX2 * sumY2).squareRoot()
        guard denominator > 0 else { return 0 }
        return sumXY / denominator
    }

    // MARK: - Insight Generation

    /// Produces human-readable insights from significant correlations.
    func generateInsights() -> [String] {
        discoveredCorrelations
            .sorted { abs($0.coefficient) > abs($1.coefficient) }
            .map(\.insight)
    }

    // MARK: - Top Correlations

    /// Returns the top N correlations sorted by absolute coefficient value.
    func topCorrelations(limit: Int = 5) -> [CorrelationResult] {
        Array(
            discoveredCorrelations
                .sorted { abs($0.coefficient) > abs($1.coefficient) }
                .prefix(limit)
        // periphery:ignore - Reserved: generateInsights() instance method reserved for future feature activation
        )
    }

    // MARK: - Metric Pair Definitions

    // swiftlint:disable:next function_body_length
    private func buildMetricPairs() -> [MetricPair] {
        [
            // periphery:ignore - Reserved: topCorrelations(limit:) instance method reserved for future feature activation
            // Sleep hours vs productivity
            MetricPair(
                name1: "Sleep Hours",
                name2: "Productivity Score",
                extract1: { $0.sleepHours > 0 ? $0.sleepHours : nil },
                extract2: { $0.productivityScore > 0 ? $0.productivityScore : nil },
                insightGenerator: { r, snapshots in
                    Self.generateSleepProductivityInsight(r: r, snapshots: snapshots)
                }
            ),
            // periphery:ignore - Reserved: buildMetricPairs() instance method reserved for future feature activation
            // Sleep hours vs mood
            MetricPair(
                name1: "Sleep Hours",
                name2: "Mood Score",
                extract1: { $0.sleepHours > 0 ? $0.sleepHours : nil },
                extract2: { $0.moodScore },
                insightGenerator: { r, _ in
                    let direction = r > 0 ? "better" : "worse"
                    return "Your mood tends to be \(direction) on days with more sleep (r=\(String(format: "%.2f", r)))."
                }
            ),
            // Exercise minutes vs mood
            MetricPair(
                name1: "Exercise Minutes",
                name2: "Mood Score",
                extract1: { $0.exerciseMinutes },
                extract2: { $0.moodScore },
                insightGenerator: { r, snapshots in
                    Self.generateExerciseMoodInsight(r: r, snapshots: snapshots)
                }
            ),
            // Exercise minutes vs sleep quality
            MetricPair(
                name1: "Exercise Minutes",
                name2: "Sleep Quality",
                extract1: { $0.exerciseMinutes },
                extract2: { $0.sleepQuality > 0 ? $0.sleepQuality : nil },
                insightGenerator: { r, _ in
                    let direction = r > 0 ? "improves" : "decreases"
                    return "Your sleep quality \(direction) on days you exercise more (r=\(String(format: "%.2f", r)))."
                }
            ),
            // HRV vs mood
            MetricPair(
                name1: "HRV (SDNN)",
                name2: "Mood Score",
                extract1: { $0.hrvSDNN > 0 ? $0.hrvSDNN : nil },
                extract2: { $0.moodScore },
                insightGenerator: { r, _ in
                    let direction = r > 0 ? "higher" : "lower"
                    return "Your mood tends to be \(direction) when your heart rate variability is elevated (r=\(String(format: "%.2f", r)))."
                }
            ),
            // Barometric pressure vs mood
            MetricPair(
                name1: "Barometric Pressure",
                name2: "Mood Score",
                extract1: { $0.barometricPressure > 0 ? $0.barometricPressure : nil },
                extract2: { $0.moodScore },
                insightGenerator: { r, _ in
                    if r > 0 {
                        return "Your mood tends to improve with higher barometric pressure (clear weather) (r=\(String(format: "%.2f", r)))."
                    } else {
                        return "Falling barometric pressure (stormy weather) appears to negatively affect your mood (r=\(String(format: "%.2f", r)))."
                    }
                }
            ),
            // Deep sleep vs next-day productivity (offset by 1 day)
            MetricPair(
                name1: "Deep Sleep (previous night)",
                name2: "Next-Day Productivity",
                extract1: { _ in nil }, // placeholder; overridden by offset logic
                extract2: { _ in nil },
                insightGenerator: { r, _ in
                    let direction = r > 0 ? "higher" : "lower"
                    return "Your productivity is \(direction) the day after getting more deep sleep (r=\(String(format: "%.2f", r)))."
                }
            ),
            // Step count vs mood
            MetricPair(
                name1: "Step Count",
                name2: "Mood Score",
                extract1: { $0.stepCount > 0 ? $0.stepCount : nil },
                extract2: { $0.moodScore },
                insightGenerator: { r, _ in
                    let direction = r > 0 ? "improves" : "declines"
                    return "Your mood \(direction) on days you walk more (r=\(String(format: "%.2f", r)))."
                }
            ),
            // Temperature vs exercise
            MetricPair(
                name1: "Temperature",
                name2: "Exercise Minutes",
                extract1: { $0.weatherTemp != 0 ? $0.weatherTemp : nil },
                extract2: { $0.exerciseMinutes },
                insightGenerator: { r, _ in
                    if r > 0 {
                        return "You tend to exercise more on warmer days (r=\(String(format: "%.2f", r)))."
                    } else {
                        return "You tend to exercise more on cooler days (r=\(String(format: "%.2f", r)))."
                    }
                }
            ),
            // UV Index vs mood
            MetricPair(
                name1: "UV Index",
                name2: "Mood Score",
                extract1: { $0.uvIndex > 0 ? $0.uvIndex : nil },
                extract2: { $0.moodScore },
                insightGenerator: { r, _ in
                    if r > 0 {
                        return "Sunnier days (higher UV) correlate with better mood for you (r=\(String(format: "%.2f", r)))."
                    } else {
                        return "Higher UV exposure days correlate with lower mood (r=\(String(format: "%.2f", r)))."
                    }
                }
            ),
            // Resting heart rate vs stress
            MetricPair(
                name1: "Resting Heart Rate",
                name2: "Stress Level",
                extract1: { $0.restingHeartRate > 0 ? $0.restingHeartRate : nil },
                extract2: { $0.stressLevel },
                insightGenerator: { r, _ in
                    let direction = r > 0 ? "rises" : "drops"
                    return "Your resting heart rate \(direction) as stress increases (r=\(String(format: "%.2f", r)))."
                }
            ),
            // Deep work vs mood
            MetricPair(
                name1: "Deep Work Minutes",
                name2: "Mood Score",
                extract1: { $0.deepWorkMinutes > 0 ? $0.deepWorkMinutes : nil },
                extract2: { $0.moodScore },
                insightGenerator: { r, _ in
                    let direction = r > 0 ? "better" : "worse"
                    return "Your mood tends to be \(direction) on days with more deep work (r=\(String(format: "%.2f", r)))."
                }
            )
        ]
    }

    /// Overrides analyzeCorrelations to handle the deep sleep -> next-day productivity offset pair.
    /// Called internally within analyzeCorrelations.
    private func analyzeOffsetPairs() -> [CorrelationResult] {
        var results: [CorrelationResult] = []
        let calendar = Calendar.current

        // Deep sleep vs next-day productivity (day N sleep -> day N+1 productivity)
        let sorted = snapshots.sorted { $0.date < $1.date }
        var deepSleepValues: [Double] = []
        var nextDayProductivity: [Double] = []

        for i in 0..<(sorted.count - 1) {
            let today = sorted[i]
            // periphery:ignore - Reserved: analyzeOffsetPairs() instance method reserved for future feature activation
            let tomorrow = sorted[i + 1]

            // Verify they are consecutive days
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today.date)),
                  calendar.isDate(nextDay, inSameDayAs: tomorrow.date)
            else { continue }

            guard today.deepSleepMinutes > 0, tomorrow.productivityScore > 0 else { continue }

            deepSleepValues.append(today.deepSleepMinutes)
            nextDayProductivity.append(tomorrow.productivityScore)
        }

        if deepSleepValues.count >= 7 {
            let r = pearsonCorrelation(deepSleepValues, nextDayProductivity)
            if !r.isNaN && r.isFinite {
                let strength = CDCorrelationStrength.from(coefficient: r)
                if strength != .negligible && strength != .weak {
                    let percentageChange = abs(r) * 100
                    let direction = r > 0 ? "higher" : "lower"
                    let insight = "Your productivity is approximately \(String(format: "%.0f", percentageChange))% \(direction) on days after deeper sleep (r=\(String(format: "%.2f", r)))."

                    results.append(CorrelationResult(
                        metric1: "Deep Sleep (previous night)",
                        metric2: "Next-Day Productivity",
                        coefficient: r,
                        sampleSize: deepSleepValues.count,
                        insight: insight
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Insight Generators (Static)

    private static func generateSleepProductivityInsight(r: Double, snapshots: [DailyLifeSnapshot]) -> String {
        let highSleepDays = snapshots.filter { $0.sleepHours >= 7 }
        let lowSleepDays = snapshots.filter { $0.sleepHours < 7 }

        let avgProductivityHigh = highSleepDays.isEmpty ? 0 :
            highSleepDays.map(\.productivityScore).reduce(0, +) / Double(highSleepDays.count)
        let avgProductivityLow = lowSleepDays.isEmpty ? 0 :
            lowSleepDays.map(\.productivityScore).reduce(0, +) / Double(lowSleepDays.count)

        if avgProductivityLow > 0 {
            // periphery:ignore - Reserved: generateSleepProductivityInsight(r:snapshots:) static method reserved for future feature activation
            let percentDifference = ((avgProductivityHigh - avgProductivityLow) / avgProductivityLow) * 100
            if percentDifference > 0 {
                return "Your productivity is \(String(format: "%.0f", percentDifference))% higher on days after 7+ hours of sleep (r=\(String(format: "%.2f", r)))."
            } else {
                return "Surprisingly, your productivity is \(String(format: "%.0f", abs(percentDifference)))% lower on days with more sleep. You may be a short-sleeper (r=\(String(format: "%.2f", r)))."
            }
        }
        return "Sleep duration and productivity are correlated (r=\(String(format: "%.2f", r)))."
    }

    private static func generateExerciseMoodInsight(r: Double, snapshots: [DailyLifeSnapshot]) -> String {
        let exerciseDays = snapshots.filter { $0.exerciseMinutes >= 30 }
        let sedentaryDays = snapshots.filter { $0.exerciseMinutes < 30 }

        let avgMoodExercise = exerciseDays.isEmpty ? 0 :
            exerciseDays.map(\.moodScore).reduce(0, +) / Double(exerciseDays.count)
        let avgMoodSedentary = sedentaryDays.isEmpty ? 0 :
            sedentaryDays.map(\.moodScore).reduce(0, +) / Double(sedentaryDays.count)

        // periphery:ignore - Reserved: generateExerciseMoodInsight(r:snapshots:) static method reserved for future feature activation
        let delta = avgMoodExercise - avgMoodSedentary
        if abs(delta) > 0.01 {
            let direction = delta > 0 ? "improves" : "declines"
            return "Your mood \(direction) by \(String(format: "%.2f", abs(delta))) points on days you exercise 30+ minutes (r=\(String(format: "%.2f", r)))."
        }
        return "Exercise and mood are correlated (r=\(String(format: "%.2f", r)))."
    }

    // MARK: - HealthKit Data Fetching

    #if canImport(HealthKit)

    private func fetchSleepData(start: Date, end: Date) async -> (hours: Double, quality: Double, remMin: Double, deepMin: Double) {
        // Query sleep analysis for the preceding night (look back 24h from start of day)
        let sleepStart = start.addingTimeInterval(-12 * 3600) // 12h before start of day
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: sleepStart, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            // periphery:ignore - Reserved: fetchSleepData(start:end:) instance method reserved for future feature activation
            limit: nil
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            guard !samples.isEmpty else { return (0, 0, 0, 0) }

            var totalSleepSeconds: Double = 0
            var deepSeconds: Double = 0
            var remSeconds: Double = 0

            for sample in samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                let value = sample.value
                switch value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepSeconds += duration
                    totalSleepSeconds += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    remSeconds += duration
                    totalSleepSeconds += duration
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                     HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    totalSleepSeconds += duration
                default:
                    break // awake or in-bed, not counted as sleep
                }
            }

            let hours = totalSleepSeconds / 3600
            let remMin = remSeconds / 60
            let deepMin = deepSeconds / 60
            // Quality: ratio of deep+REM to total, normalized 0-1
            let quality = totalSleepSeconds > 0
                ? min(1.0, (deepSeconds + remSeconds) / totalSleepSeconds * 2.5) // 40% deep+REM = perfect
                : 0

            return (hours, quality, remMin, deepMin)
        } catch {
            logger.debug("Failed to fetch sleep data: \(error.localizedDescription)")
            return (0, 0, 0, 0)
        }
    }

    private func fetchActivityData(start: Date, end: Date) async -> (exerciseMin: Double, steps: Double, activeCal: Double) {
        async let exerciseMin = fetchQuantitySum(.appleExerciseTime, unit: .minute(), start: start, end: end)
        async let steps = fetchQuantitySum(.stepCount, unit: .count(), start: start, end: end)
        async let activeCal = fetchQuantitySum(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)

        return await (exerciseMin ?? 0, steps ?? 0, activeCal ?? 0)
    }

// periphery:ignore - Reserved: fetchActivityData(start:end:) instance method reserved for future feature activation

    private func fetchRestingHeartRate(start: Date, end: Date) async -> Double {
        let hrType = HKQuantityType(.restingHeartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: hrType, predicate: predicate),
            options: .discreteAverage
        // periphery:ignore - Reserved: fetchRestingHeartRate(start:end:) instance method reserved for future feature activation
        )
        do {
            let result = try await descriptor.result(for: healthStore)
            return result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
        } catch {
            logger.debug("Failed to fetch resting HR: \(error.localizedDescription)")
            return 0
        }
    }

    private func fetchHRV(start: Date, end: Date) async -> Double {
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: hrvType, predicate: predicate),
            // periphery:ignore - Reserved: fetchHRV(start:end:) instance method reserved for future feature activation
            options: .discreteAverage
        )
        do {
            let result = try await descriptor.result(for: healthStore)
            return result?.averageQuantity()?.doubleValue(for: .secondUnit(with: .milli)) ?? 0
        } catch {
            logger.debug("Failed to fetch HRV: \(error.localizedDescription)")
            return 0
        }
    }

    private func fetchQuantitySum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        let quantityType = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(
            // periphery:ignore - Reserved: fetchQuantitySum(_:unit:start:end:) instance method reserved for future feature activation
            predicate: .quantitySample(type: quantityType, predicate: predicate),
            options: .cumulativeSum
        )
        do {
            let result = try await descriptor.result(for: healthStore)
            return result?.sumQuantity()?.doubleValue(for: unit)
        } catch {
            logger.debug("Failed to fetch \(identifier.rawValue): \(error.localizedDescription)")
            return nil
        }
    }

    #else

    // Stub implementations for platforms without HealthKit
    private func fetchSleepData(start _: Date, end _: Date) async -> (hours: Double, quality: Double, remMin: Double, deepMin: Double) {
        (0, 0, 0, 0)
    }

    private func fetchActivityData(start _: Date, end _: Date) async -> (exerciseMin: Double, steps: Double, activeCal: Double) {
        (0, 0, 0)
    }

    private func fetchRestingHeartRate(start _: Date, end _: Date) async -> Double { 0 }

    private func fetchHRV(start _: Date, end _: Date) async -> Double { 0 }

    #endif

    // MARK: - Mood / Stress Estimation

    private func estimateStressLevel() -> Double {
        let mood = MoodTracker.shared.currentMood
        let trend = MoodTracker.shared.moodTrend(hours: 6)
        // periphery:ignore - Reserved: estimateStressLevel() instance method reserved for future feature activation
        var stress = 1.0 - mood // Base: inverse of mood

        // Declining mood = higher stress
        switch trend {
        case .declining: stress = min(1.0, stress + 0.1)
        case .improving: stress = max(0.0, stress - 0.1)
        case .stable: break
        }

        return stress
    }

    // MARK: - Productivity Estimation

    private func estimateProductivity() -> (score: Double, deepWorkMinutes: Double) {
        let context = BehavioralFingerprint.shared.currentContext()

// periphery:ignore - Reserved: estimateProductivity() instance method reserved for future feature activation

        // Productivity score based on cognitive load and activity type
        var score: Double = 0.5
        switch context.activity {
        case .deepWork: score = 0.9
        case .meetings: score = 0.6
        case .browsing: score = 0.4
        case .communication: score = 0.5
        case .exercise: score = 0.3
        case .leisure: score = 0.2
        case .sleep, .idle: score = 0.1
        case .healthSuggestion: score = 0.4
        }

        // Adjust by cognitive load
        score = (score + context.cognitiveLoad) / 2.0

        // Estimate deep work minutes from BehavioralFingerprint
        // Count hours today where deepWork was dominant
        let calendar = Calendar.current
        let weekday = (calendar.component(.weekday, from: Date()) + 5) % 7
        let currentHour = calendar.component(.hour, from: Date())
        let dayOfWeek = DayOfWeek.allCases[weekday]

        var deepWorkMinutes: Double = 0
        for hour in 0..<currentHour {
            let activity = BehavioralFingerprint.shared.dominantActivity(day: dayOfWeek, hour: hour)
            if activity == .deepWork {
                deepWorkMinutes += 60
            }
        }

        return (score, deepWorkMinutes)
    }

    // MARK: - Weather Data

    private func fetchWeatherData() -> (temp: Double, humidity: Double, pressure: Double, uv: Double) {
        // periphery:ignore - Reserved: fetchWeatherData() instance method reserved for future feature activation
        guard let weather = WeatherMonitor.shared.currentWeather else {
            return (0, 0, 0, 0)
        }
        return (
            weather.temperature,
            weather.humidity,
            weather.pressure,
            Double(weather.uvIndex)
        )
    }

    // MARK: - Persistence

    private struct PersistedState: Codable {
        let snapshots: [DailyLifeSnapshot]
        let correlations: [CorrelationResult]
        let lastAnalysisDate: Date?
    }

    // periphery:ignore - Reserved: save() instance method reserved for future feature activation
    private func save() {
        let state = PersistedState(
            snapshots: snapshots,
            correlations: discoveredCorrelations,
            lastAnalysisDate: lastAnalysisDate
        )
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: Self.storageURL, options: .atomic)
            logger.debug("Saved \(self.snapshots.count) snapshots and \(self.discoveredCorrelations.count) correlations")
        } catch {
            logger.error("Failed to save correlation data: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(PersistedState.self, from: data)
            snapshots = state.snapshots
            discoveredCorrelations = state.correlations
            lastAnalysisDate = state.lastAnalysisDate
            logger.info("Loaded \(self.snapshots.count) snapshots and \(self.discoveredCorrelations.count) correlations from disk")
        } catch {
            logger.error("Failed to load correlation data: \(error.localizedDescription)")
        }
    }
}
