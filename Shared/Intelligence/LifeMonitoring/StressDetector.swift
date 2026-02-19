// StressDetector.swift
// Thea — Real-Time Stress Detection Monitor
//
// Aggregates multiple passive signals (HRV, heart rate, app switching frequency,
// message sentiment, calendar density, sleep, late-night activity) to compute
// a real-time stress score using exponential moving average.
// Feeds high-stress signals into BehavioralFingerprint as .healthSuggestion.

import Combine
import Foundation
import os.log

// MARK: - Stress Signal

enum StressSignal: String, Codable, Sendable, CaseIterable {
    case heartRateElevated
    case hrvDepressed
    case highAppSwitching
    case negativeSentiment
    case calendarDensity
    case lateNightActivity
    case missedBreaks
    case shortSleep

    /// Weight of this signal in the composite stress score
    var weight: Double {
        switch self {
        case .heartRateElevated: 0.25
        case .hrvDepressed: 0.20
        case .highAppSwitching: 0.15
        case .negativeSentiment: 0.15
        case .calendarDensity: 0.10
        case .lateNightActivity: 0.10
        case .missedBreaks: 0.05
        case .shortSleep: 0.05
        }
    }
}

// MARK: - Stress Level

enum StressLevel: String, Codable, Sendable, Comparable {
    case minimal
    case low
    case moderate
    case high
    case critical

    var numericValue: Double {
        switch self {
        case .minimal: 0.0
        case .low: 0.25
        case .moderate: 0.5
        case .high: 0.75
        case .critical: 1.0
        }
    }

    private var ordinal: Int {
        switch self {
        case .minimal: 0
        case .low: 1
        case .moderate: 2
        case .high: 3
        case .critical: 4
        }
    }

    static func < (lhs: StressLevel, rhs: StressLevel) -> Bool {
        lhs.ordinal < rhs.ordinal
    }
}

// MARK: - Stress Snapshot

struct StressSnapshot: Codable, Sendable {
    let level: StressLevel
    let score: Double
    let activeSignals: [StressSignal]
    let timestamp: Date
}

// MARK: - Stress Detector

@MainActor
@Observable
final class StressDetector {
    // periphery:ignore - Reserved: shared static property — reserved for future feature activation
    static let shared = StressDetector()

    private let logger = Logger(subsystem: "ai.thea.app", category: "StressDetector")

    // MARK: - Published State

    private(set) var currentLevel: StressLevel = .minimal
    private(set) var currentScore: Double = 0.0
    private(set) var activeSignals: Set<StressSignal> = []
    private(set) var history: [StressSnapshot] = []

    // MARK: - Configuration

    /// EMA smoothing factor — higher values make the score more reactive
    private let emaAlpha = 0.3

    /// Maximum snapshots retained (7 days at ~1 snapshot per 5 minutes)
    private let maxHistoryCount = 2016

    /// App switch frequency threshold: >10 switches in 5 minutes
    // periphery:ignore - Reserved: appSwitchThreshold property — reserved for future feature activation
    private let appSwitchThreshold = 10
    // periphery:ignore - Reserved: appSwitchWindowSeconds property — reserved for future feature activation
    private let appSwitchWindowSeconds: TimeInterval = 300

    /// Heart rate baseline and elevation threshold (bpm above baseline)
    private var heartRateBaseline: Double = 72.0
    // periphery:ignore - Reserved: heartRateElevationDelta property — reserved for future feature activation
    private let heartRateElevationDelta: Double = 15.0

    // periphery:ignore - Reserved: shared static property reserved for future feature activation
    /// HRV baseline and depression threshold (percentage below baseline)
    private var hrvBaseline: Double = 50.0
    // periphery:ignore - Reserved: hrvDepressionFraction property — reserved for future feature activation
    private let hrvDepressionFraction: Double = 0.20

    /// Negative sentiment threshold (LifeEvent sentiment range: -1 to 1)
    // periphery:ignore - Reserved: negativeSentimentThreshold property — reserved for future feature activation
    private let negativeSentimentThreshold: Double = -0.3

    /// Calendar density: overlapping events threshold
    // periphery:ignore - Reserved: calendarDensityThreshold property — reserved for future feature activation
    private let calendarDensityThreshold = 3

    /// Late-night activity cutoff hour (24h)
    // periphery:ignore - Reserved: lateNightStartHour property — reserved for future feature activation
    private let lateNightStartHour = 23
    // periphery:ignore - Reserved: lateNightEndHour property — reserved for future feature activation
    private let lateNightEndHour = 5

// periphery:ignore - Reserved: emaAlpha property reserved for future feature activation

    // MARK: - Internal Tracking

// periphery:ignore - Reserved: maxHistoryCount property reserved for future feature activation

    private var recentAppSwitches: [Date] = []
    // periphery:ignore - Reserved: appSwitchThreshold property reserved for future feature activation
    // periphery:ignore - Reserved: appSwitchWindowSeconds property reserved for future feature activation
    private var recentNegativeSentiments: [Date] = []
    private var overlappingCalendarEvents: Int = 0
    private var cancellables = Set<AnyCancellable>()

// periphery:ignore - Reserved: heartRateElevationDelta property reserved for future feature activation

    // MARK: - Persistence

    // periphery:ignore - Reserved: hrvDepressionFraction property reserved for future feature activation
    private let storageURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            // periphery:ignore - Reserved: negativeSentimentThreshold property reserved for future feature activation
            .appendingPathComponent("Thea", isDirectory: true)
            .appendingPathComponent("LifeMonitoring", isDirectory: true)
        // periphery:ignore - Reserved: calendarDensityThreshold property reserved for future feature activation
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) // Safe: directory may already exist; error means state not persisted (works in-memory)
        return dir.appendingPathComponent("stress_state.json")
    // periphery:ignore - Reserved: lateNightStartHour property reserved for future feature activation
    // periphery:ignore - Reserved: lateNightEndHour property reserved for future feature activation
    }()

    // MARK: - Init

    private init() {
        loadFromDisk()
    }

    // MARK: - Lifecycle

    /// Subscribe to LifeMonitoringCoordinator event stream and begin processing
    // periphery:ignore - Reserved: start() instance method — reserved for future feature activation
    func start() {
        guard cancellables.isEmpty else {
            logger.info("StressDetector already running")
            return
        }

        LifeMonitoringCoordinator.shared.eventStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.processEvent(event)
                }
            }
            .store(in: &cancellables)

        logger.info("StressDetector started — current level: \(self.currentLevel.rawValue)")
    // periphery:ignore - Reserved: start() instance method reserved for future feature activation
    }

    /// Stop processing events
    // periphery:ignore - Reserved: stop() instance method — reserved for future feature activation
    func stop() {
        cancellables.removeAll()
        saveToDisk()
        logger.info("StressDetector stopped")
    }

    // MARK: - Event Processing

    // periphery:ignore - Reserved: processEvent(_:) instance method — reserved for future feature activation
    func processEvent(_ event: LifeEvent) {
        let now = event.timestamp

        switch event.type {
        // App switching frequency
        case .appSwitch:
            recordAppSwitch(at: now)

// periphery:ignore - Reserved: stop() instance method reserved for future feature activation

        // Message sentiment
        case .messageSent, .messageReceived, .emailReceived, .emailSent:
            if event.sentiment < negativeSentimentThreshold {
                recordNegativeSentiment(at: now)
            }

        // periphery:ignore - Reserved: processEvent(_:) instance method reserved for future feature activation
        // Calendar density
        case .eventStart:
            evaluateCalendarDensity(event)

        // Health metrics (heart rate, HRV)
        case .healthMetric:
            evaluateHealthMetric(event)

        default:
            break
        }

        // Check late-night activity for any event
        evaluateLateNightActivity(at: now)

        // Recompute composite score
        updateScore()

        // Feed BehavioralFingerprint when stress is elevated
        feedBehavioralFingerprint()
    }

    // MARK: - Signal Evaluators

    // periphery:ignore - Reserved: recordAppSwitch(at:) instance method — reserved for future feature activation
    private func recordAppSwitch(at timestamp: Date) {
        recentAppSwitches.append(timestamp)

        // Trim to window
        let cutoff = timestamp.addingTimeInterval(-appSwitchWindowSeconds)
        recentAppSwitches.removeAll { $0 < cutoff }

        if recentAppSwitches.count > appSwitchThreshold {
            activeSignals.insert(.highAppSwitching)
        } else {
            activeSignals.remove(.highAppSwitching)
        }
    }

// periphery:ignore - Reserved: recordAppSwitch(at:) instance method reserved for future feature activation

    private func recordNegativeSentiment(at timestamp: Date) {
        recentNegativeSentiments.append(timestamp)

        // Keep last 30 minutes of sentiment data
        let cutoff = timestamp.addingTimeInterval(-1800)
        recentNegativeSentiments.removeAll { $0 < cutoff }

        // 3+ negative sentiments in 30 minutes triggers the signal
        if recentNegativeSentiments.count >= 3 {
            activeSignals.insert(.negativeSentiment)
        } else {
            activeSignals.remove(.negativeSentiment)
        // periphery:ignore - Reserved: recordNegativeSentiment(at:) instance method reserved for future feature activation
        }
    }

    // periphery:ignore - Reserved: evaluateCalendarDensity(_:) instance method — reserved for future feature activation
    private func evaluateCalendarDensity(_ event: LifeEvent) {
        // Check for overlapping events via event data
        if let countStr = event.data["overlappingCount"],
           let count = Int(countStr) {
            overlappingCalendarEvents = count
        } else {
            // Increment for concurrent events (heuristic)
            overlappingCalendarEvents += 1

            // Decay after 30 minutes
            Task { @MainActor [weak self] in
                // periphery:ignore - Reserved: evaluateCalendarDensity(_:) instance method reserved for future feature activation
                try? await Task.sleep(for: .seconds(1800)) // Safe: decay timer; sleep cancellation means task was cancelled; non-fatal
                guard let self else { return }
                self.overlappingCalendarEvents = max(0, self.overlappingCalendarEvents - 1)
            }
        }

        if overlappingCalendarEvents >= calendarDensityThreshold {
            activeSignals.insert(.calendarDensity)
        } else {
            activeSignals.remove(.calendarDensity)
        }
    }

    // periphery:ignore - Reserved: evaluateHealthMetric(_:) instance method — reserved for future feature activation
    private func evaluateHealthMetric(_ event: LifeEvent) {
        guard let category = event.data["category"],
              let valueStr = event.data["value"],
              let value = Double(valueStr) else { return }

        switch category {
        case "heartRate", "heart_rate":
            // Update baseline with slow EMA
            heartRateBaseline = 0.95 * heartRateBaseline + 0.05 * value

            // periphery:ignore - Reserved: evaluateHealthMetric(_:) instance method reserved for future feature activation
            if value > heartRateBaseline + heartRateElevationDelta {
                activeSignals.insert(.heartRateElevated)
            } else {
                activeSignals.remove(.heartRateElevated)
            }

        case "hrv", "heartRateVariability", "heart_rate_variability":
            // Update baseline with slow EMA
            hrvBaseline = 0.95 * hrvBaseline + 0.05 * value

            let threshold = hrvBaseline * (1.0 - hrvDepressionFraction)
            if value < threshold {
                activeSignals.insert(.hrvDepressed)
            } else {
                activeSignals.remove(.hrvDepressed)
            }

        default:
            break
        }
    }

    // periphery:ignore - Reserved: evaluateLateNightActivity(at:) instance method — reserved for future feature activation
    private func evaluateLateNightActivity(at timestamp: Date) {
        let hour = Calendar.current.component(.hour, from: timestamp)

        if hour >= lateNightStartHour || hour < lateNightEndHour {
            activeSignals.insert(.lateNightActivity)
        } else {
            activeSignals.remove(.lateNightActivity)
        }
    }

// periphery:ignore - Reserved: evaluateLateNightActivity(at:) instance method reserved for future feature activation

    // MARK: - Score Computation

    func updateScore() {
        // Compute weighted raw score from active signals
        let rawScore = activeSignals.reduce(0.0) { $0 + $1.weight }

        // Clamp to 0...1
        let clampedRaw = min(max(rawScore, 0.0), 1.0)

        // Apply exponential moving average
        // periphery:ignore - Reserved: updateScore() instance method reserved for future feature activation
        currentScore = emaAlpha * clampedRaw + (1.0 - emaAlpha) * currentScore

        // Derive level
        currentLevel = computeLevel(from: currentScore)

        // Record snapshot
        let snapshot = StressSnapshot(
            level: currentLevel,
            score: currentScore,
            activeSignals: Array(activeSignals),
            timestamp: Date()
        )
        history.append(snapshot)

        // Trim history to 7-day cap
        if history.count > maxHistoryCount {
            history.removeFirst(history.count - maxHistoryCount)
        }

        // Persist periodically (every 12 snapshots ~ 1 hour at 5-min intervals)
        if history.count % 12 == 0 {
            saveToDisk()
        }
    }

    func computeLevel(from score: Double) -> StressLevel {
        switch score {
        case ..<0.15:
            return .minimal
        case 0.15..<0.35:
            return .low
        case 0.35..<0.55:
            // periphery:ignore - Reserved: computeLevel(from:) instance method reserved for future feature activation
            return .moderate
        case 0.55..<0.80:
            return .high
        default:
            return .critical
        }
    }

    // MARK: - BehavioralFingerprint Integration

    // periphery:ignore - Reserved: feedBehavioralFingerprint() instance method — reserved for future feature activation
    func feedBehavioralFingerprint() {
        if currentLevel >= .high {
            BehavioralFingerprint.shared.recordActivity(.healthSuggestion)
            logger.notice("Stress level \(self.currentLevel.rawValue) — recorded healthSuggestion in BehavioralFingerprint")
        }
    }

// periphery:ignore - Reserved: feedBehavioralFingerprint() instance method reserved for future feature activation

    // MARK: - Lagging Signal Setters

    /// Set from external sources (e.g. HealthKit sleep analysis, break detection)
    func setLaggingSignal(_ signal: StressSignal, active: Bool) {
        guard signal == .missedBreaks || signal == .shortSleep else {
            logger.warning("setLaggingSignal called with non-lagging signal: \(signal.rawValue)")
            return
        }

// periphery:ignore - Reserved: setLaggingSignal(_:active:) instance method reserved for future feature activation

        if active {
            activeSignals.insert(signal)
        } else {
            activeSignals.remove(signal)
        }
        updateScore()
    }

    // MARK: - Querying

    /// Average stress score over the last N hours
    // periphery:ignore - Reserved: averageScore(hours:) instance method — reserved for future feature activation
    func averageScore(hours: Int = 6) -> Double? {
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        let recent = history.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return nil }
        // periphery:ignore - Reserved: averageScore(hours:) instance method reserved for future feature activation
        return recent.reduce(0.0) { $0 + $1.score } / Double(recent.count)
    }

    /// Stress trend direction over the last N hours
    // periphery:ignore - Reserved: trend(hours:) instance method — reserved for future feature activation
    func trend(hours: Int = 6) -> StressTrend {
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        let recent = history.filter { $0.timestamp >= cutoff }
        // periphery:ignore - Reserved: trend(hours:) instance method reserved for future feature activation
        guard recent.count >= 2 else { return .stable }

        let midpoint = recent.count / 2
        let firstHalf = recent.prefix(midpoint)
        let secondHalf = recent.suffix(from: midpoint)

        let avgFirst = firstHalf.reduce(0.0) { $0 + $1.score } / Double(firstHalf.count)
        let avgSecond = secondHalf.reduce(0.0) { $0 + $1.score } / Double(secondHalf.count)
        let delta = avgSecond - avgFirst

        if delta > 0.05 { return .increasing }
        if delta < -0.05 { return .decreasing }
        return .stable
    }

    /// Peak stress level in the last N hours
    // periphery:ignore - Reserved: peakLevel(hours:) instance method — reserved for future feature activation
    func peakLevel(hours: Int = 24) -> StressLevel {
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        // periphery:ignore - Reserved: peakLevel(hours:) instance method reserved for future feature activation
        let recent = history.filter { $0.timestamp >= cutoff }
        guard let peak = recent.max(by: { $0.score < $1.score }) else { return .minimal }
        return peak.level
    }

    // MARK: - Persistence

    private struct PersistedStressState: Codable {
        let currentScore: Double
        let currentLevel: StressLevel
        let activeSignals: [StressSignal]
        let history: [StressSnapshot]
        let heartRateBaseline: Double
        let hrvBaseline: Double
    }

    func saveToDisk() {
        // periphery:ignore - Reserved: saveToDisk() instance method reserved for future feature activation
        let state = PersistedStressState(
            currentScore: currentScore,
            currentLevel: currentLevel,
            activeSignals: Array(activeSignals),
            history: history,
            heartRateBaseline: heartRateBaseline,
            hrvBaseline: hrvBaseline
        )

        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            logger.error("Failed to save stress state: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            let state = try JSONDecoder().decode(PersistedStressState.self, from: data)
            currentScore = state.currentScore
            currentLevel = state.currentLevel
            activeSignals = Set(state.activeSignals)
            history = state.history
            heartRateBaseline = state.heartRateBaseline
            hrvBaseline = state.hrvBaseline

            // Prune history older than 7 days
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
            history.removeAll { $0.timestamp < sevenDaysAgo }

            logger.info("Loaded stress state: \(self.history.count) snapshots, level=\(self.currentLevel.rawValue)")
        } catch {
            logger.error("Failed to load stress state: \(error.localizedDescription)")
        }
    }
}

// MARK: - Stress Trend

// periphery:ignore - Reserved: StressTrend type reserved for future feature activation
enum StressTrend: String, Sendable {
    case increasing
    case stable
    case decreasing
}
