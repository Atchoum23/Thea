//
//  AdaptiveIntervalScheduler.swift
//  Thea
//
//  Created by Claude on 2026-02-05.
//
//  Replaces fixed governance intervals with dynamic, learned timing.
//  Uses activity patterns, system stability, and resource availability
//  to determine optimal governance cycle frequency.
//

import Foundation

// MARK: - Activity Level

/// Current system activity intensity
public enum AdaptiveActivityLevel: Int, Sendable, Comparable, CaseIterable, Codable {
    case idle = 0
    case low = 1
    case moderate = 2
    case high = 3
    case intense = 4

    public static func < (lhs: AdaptiveActivityLevel, rhs: AdaptiveActivityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Multiplier for interval adjustment
    public var intervalMultiplier: Double {
        switch self {
        case .idle: return 2.0      // Longer intervals when idle
        case .low: return 1.5
        case .moderate: return 1.0  // Baseline
        case .high: return 0.7
        case .intense: return 0.5   // Shorter intervals when busy
        }
    }
}

// MARK: - Stability State

/// System stability for interval decisions
public enum StabilityState: Int, Sendable, Comparable {
    case unstable = 0
    case stabilizing = 1
    case stable = 2
    case veryStable = 3

    public static func < (lhs: StabilityState, rhs: StabilityState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Multiplier for interval adjustment
    public var intervalMultiplier: Double {
        switch self {
        case .unstable: return 0.5   // More frequent checks when unstable
        case .stabilizing: return 0.75
        case .stable: return 1.0     // Baseline
        case .veryStable: return 1.5 // Can afford longer intervals
        }
    }
}

// MARK: - Resource Availability

/// Current resource availability state
public enum ResourceAvailability: Int, Sendable, Comparable {
    case constrained = 0
    case limited = 1
    case adequate = 2
    case abundant = 3

    public static func < (lhs: ResourceAvailability, rhs: ResourceAvailability) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Multiplier for interval adjustment
    public var intervalMultiplier: Double {
        switch self {
        case .constrained: return 1.5  // Longer intervals to save resources
        case .limited: return 1.2
        case .adequate: return 1.0     // Baseline
        case .abundant: return 0.8     // Can afford more frequent governance
        }
    }
}

// MARK: - Time Pattern

/// Learned time-of-day pattern for activity
public struct IntervalTimePattern: Sendable, Codable {
    public let hour: Int
    public var expectedActivity: AdaptiveActivityLevel
    public var confidence: Double
    public var sampleCount: Int

    public init(hour: Int, expectedActivity: AdaptiveActivityLevel = .moderate, confidence: Double = 0.1, sampleCount: Int = 0) {
        self.hour = hour
        self.expectedActivity = expectedActivity
        self.confidence = confidence
        self.sampleCount = sampleCount
    }

    public mutating func update(observedActivity: AdaptiveActivityLevel, learningRate: Double = 0.1) {
        sampleCount += 1

        // Bayesian-style update
        let newConfidence = min(0.95, confidence + (1.0 - confidence) * 0.05)

        // Weighted average toward observed
        let currentWeight = confidence
        let observedWeight = learningRate * (1.0 - confidence) + (1.0 - learningRate)

        let weightedCurrent = Double(expectedActivity.rawValue) * currentWeight
        let weightedObserved = Double(observedActivity.rawValue) * observedWeight
        let newRaw = Int(round((weightedCurrent + weightedObserved) / (currentWeight + observedWeight)))

        expectedActivity = AdaptiveActivityLevel(rawValue: max(0, min(4, newRaw))) ?? .moderate
        confidence = newConfidence
    }
}

// MARK: - Interval Decision

/// Result of interval calculation
public struct IntervalDecision: Sendable {
    public let interval: TimeInterval
    public let reason: String
    public let confidence: Double
    public let factors: [String: Double]

    public init(interval: TimeInterval, reason: String, confidence: Double, factors: [String: Double]) {
        self.interval = interval
        self.reason = reason
        self.confidence = confidence
        self.factors = factors
    }
}

// MARK: - Scheduler Configuration

/// Configuration for the adaptive scheduler
public struct SchedulerConfiguration: Sendable {
    /// Minimum allowed interval (floor)
    public let minimumInterval: TimeInterval

    /// Maximum allowed interval (ceiling)
    public let maximumInterval: TimeInterval

    /// Baseline interval before adjustments
    public let baselineInterval: TimeInterval

    /// Learning rate for pattern updates
    public let learningRate: Double

    /// How much to weight recent observations
    public let recencyBias: Double

    public static let `default` = SchedulerConfiguration(
        minimumInterval: 60,      // 1 minute minimum
        maximumInterval: 900,     // 15 minutes maximum
        baselineInterval: 300,    // 5 minutes baseline
        learningRate: 0.1,
        recencyBias: 0.3
    )

    public init(
        minimumInterval: TimeInterval,
        maximumInterval: TimeInterval,
        baselineInterval: TimeInterval,
        learningRate: Double,
        recencyBias: Double
    ) {
        self.minimumInterval = minimumInterval
        self.maximumInterval = maximumInterval
        self.baselineInterval = baselineInterval
        self.learningRate = learningRate
        self.recencyBias = recencyBias
    }
}

// MARK: - Activity Sample

/// A sample of observed activity
public struct IntervalActivitySample: Sendable, Codable {
    public let timestamp: Date
    public let activity: AdaptiveActivityLevel
    public let queryCount: Int
    public let errorCount: Int
    public let resourcePressure: Double

    public init(timestamp: Date, activity: AdaptiveActivityLevel, queryCount: Int, errorCount: Int, resourcePressure: Double) {
        self.timestamp = timestamp
        self.activity = activity
        self.queryCount = queryCount
        self.errorCount = errorCount
        self.resourcePressure = resourcePressure
    }
}

// MARK: - Adaptive Interval Scheduler

/// Dynamically schedules governance intervals based on learned patterns
public actor AdaptiveIntervalScheduler {

    // MARK: - Properties

    private let configuration: SchedulerConfiguration

    /// Learned hourly patterns (24 hours)
    private var hourlyPatterns: [IntervalTimePattern]

    /// Recent activity samples
    private var recentSamples: [IntervalActivitySample] = []
    private let maxSamples = 1000

    /// Current state tracking
    private var currentActivity: AdaptiveActivityLevel = .moderate
    private var currentStability: StabilityState = .stable
    private var currentResources: ResourceAvailability = .adequate

    /// Adaptive baseline (learned over time)
    private var adaptiveBaseline: TimeInterval

    /// Statistics
    private var totalDecisions: Int = 0
    private var averageInterval: TimeInterval = 300
    private var intervalVariance: Double = 0

    // MARK: - Initialization

    public init(configuration: SchedulerConfiguration = .default) {
        self.configuration = configuration
        self.adaptiveBaseline = configuration.baselineInterval

        // Initialize hourly patterns with moderate defaults
        self.hourlyPatterns = (0..<24).map { hour in
            // Pre-seed with typical patterns
            let expectedActivity: AdaptiveActivityLevel
            switch hour {
            case 0...5: expectedActivity = .idle
            case 6...8: expectedActivity = .low
            case 9...11: expectedActivity = .high
            case 12...13: expectedActivity = .moderate
            case 14...17: expectedActivity = .high
            case 18...20: expectedActivity = .moderate
            case 21...23: expectedActivity = .low
            default: expectedActivity = .moderate
            }
            return IntervalTimePattern(hour: hour, expectedActivity: expectedActivity, confidence: 0.3)
        }
    }

    // MARK: - State Updates

    /// Update current activity level
    public func updateActivity(_ level: AdaptiveActivityLevel) {
        currentActivity = level

        // Record sample
        let sample = IntervalActivitySample(
            timestamp: Date(),
            activity: level,
            queryCount: 0,
            errorCount: 0,
            resourcePressure: 0
        )
        recordSample(sample)
    }

    /// Update current activity with detailed metrics
    public func updateActivityDetailed(queryCount: Int, errorCount: Int, resourcePressure: Double) {
        // Infer activity level from metrics
        let level: AdaptiveActivityLevel
        if queryCount == 0 && errorCount == 0 {
            level = .idle
        } else if queryCount < 5 {
            level = .low
        } else if queryCount < 15 {
            level = .moderate
        } else if queryCount < 30 {
            level = .high
        } else {
            level = .intense
        }

        currentActivity = level

        let sample = IntervalActivitySample(
            timestamp: Date(),
            activity: level,
            queryCount: queryCount,
            errorCount: errorCount,
            resourcePressure: resourcePressure
        )
        recordSample(sample)
    }

    /// Update stability state
    public func updateStability(_ state: StabilityState) {
        currentStability = state
    }

    /// Update resource availability
    public func updateResources(_ availability: ResourceAvailability) {
        currentResources = availability
    }

    // MARK: - Interval Calculation

    /// Calculate the next governance interval
    public func calculateNextInterval() -> IntervalDecision {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)

        var factors: [String: Double] = [:]

        // Factor 1: Current activity
        let activityMultiplier = currentActivity.intervalMultiplier
        factors["activity"] = activityMultiplier

        // Factor 2: System stability
        let stabilityMultiplier = currentStability.intervalMultiplier
        factors["stability"] = stabilityMultiplier

        // Factor 3: Resource availability
        let resourceMultiplier = currentResources.intervalMultiplier
        factors["resources"] = resourceMultiplier

        // Factor 4: Time-of-day pattern prediction
        let pattern = hourlyPatterns[hour]
        let predictedActivity = pattern.expectedActivity
        let patternConfidence = pattern.confidence
        let patternMultiplier = predictedActivity.intervalMultiplier
        factors["pattern"] = patternMultiplier
        factors["patternConfidence"] = patternConfidence

        // Factor 5: Recent trend
        let trendMultiplier = calculateTrendMultiplier()
        factors["trend"] = trendMultiplier

        // Combine factors with weighted average
        // Current state gets more weight than predictions
        let combinedMultiplier = (
            activityMultiplier * 0.3 +
            stabilityMultiplier * 0.25 +
            resourceMultiplier * 0.2 +
            patternMultiplier * patternConfidence * 0.15 +
            trendMultiplier * 0.1
        ) / (0.3 + 0.25 + 0.2 + 0.15 * patternConfidence + 0.1)

        // Apply to adaptive baseline
        var interval = adaptiveBaseline * combinedMultiplier

        // Clamp to configured bounds
        interval = max(configuration.minimumInterval, min(configuration.maximumInterval, interval))

        // Update statistics
        totalDecisions += 1
        let alpha = 0.1
        averageInterval = averageInterval * (1 - alpha) + interval * alpha
        let diff = interval - averageInterval
        intervalVariance = intervalVariance * (1 - alpha) + diff * diff * alpha

        // Calculate confidence based on data quality
        let confidence = calculateConfidence(patternConfidence: patternConfidence)

        // Build reason string
        // periphery:ignore - Reserved: actualInterval parameter — kept for API compatibility
        let reason = buildReason(
            activity: currentActivity,
            stability: currentStability,
            resources: currentResources,
            predictedActivity: predictedActivity
        )

        return IntervalDecision(
            interval: interval,
            reason: reason,
            confidence: confidence,
            factors: factors
        )
    }

    /// Get the recommended interval (simplified API)
    public func recommendedInterval() -> TimeInterval {
        calculateNextInterval().interval
    }

    // MARK: - Learning

    // periphery:ignore:parameters actualInterval - Reserved: parameter(s) kept for API compatibility
    /// Record outcome of a governance cycle for learning
    public func recordGovernanceOutcome(
        actualInterval: TimeInterval,
        // periphery:ignore - Reserved: actualInterval parameter kept for API compatibility
        changesApplied: Int,
        issuesDetected: Int,
        resourceUsage: Double
    ) {
        // Learn from outcome
        let effectiveness = calculateEffectiveness(
            changesApplied: changesApplied,
            issuesDetected: issuesDetected,
            resourceUsage: resourceUsage
        )

        // Adjust adaptive baseline based on effectiveness
        let adjustment: Double
        if effectiveness > 0.7 {
            // Good outcome - current interval is appropriate
            adjustment = 0
        } else if effectiveness < 0.3 {
            // Poor outcome - need to adjust
            if issuesDetected > changesApplied {
                // Too slow - shorten interval
                adjustment = -0.05
            } else {
                // Too aggressive - lengthen interval
                adjustment = 0.05
            }
        } else {
            // Moderate outcome - small adjustment
            adjustment = (0.5 - effectiveness) * 0.02
        }

        if adjustment != 0 {
            adaptiveBaseline = max(
                configuration.minimumInterval,
                min(configuration.maximumInterval, adaptiveBaseline * (1 + adjustment))
            )
        }
    }

    /// Update hourly pattern from observation
    public func updateHourlyPattern(hour: Int, observedActivity: AdaptiveActivityLevel) {
        guard hour >= 0 && hour < 24 else { return }
        hourlyPatterns[hour].update(
            observedActivity: observedActivity,
            learningRate: configuration.learningRate
        )
    }

    // MARK: - Predictions

    /// Predict activity for a future time
    public func predictActivity(for date: Date) -> (activity: AdaptiveActivityLevel, confidence: Double) {
        let hour = Calendar.current.component(.hour, from: date)
        let pattern = hourlyPatterns[hour]
        return (pattern.expectedActivity, pattern.confidence)
    }

    /// Get optimal governance windows for the next period
    public func optimalGovernanceWindows(count: Int = 5) -> [(start: Date, interval: TimeInterval)] {
        var windows: [(start: Date, interval: TimeInterval)] = []
        var current = Date()

        for _ in 0..<count {
            let hour = Calendar.current.component(.hour, from: current)
            let pattern = hourlyPatterns[hour]

            // Calculate interval for this time
            let baseInterval = adaptiveBaseline * pattern.expectedActivity.intervalMultiplier
            let interval = max(configuration.minimumInterval, min(configuration.maximumInterval, baseInterval))

            windows.append((start: current, interval: interval))
            current = current.addingTimeInterval(interval)
        }

        return windows
    }

    // MARK: - Statistics

    /// Get current scheduler statistics
    public func statistics() -> [String: Any] {
        [
            "totalDecisions": totalDecisions,
            "averageInterval": averageInterval,
            "intervalVariance": intervalVariance,
            "adaptiveBaseline": adaptiveBaseline,
            "currentActivity": currentActivity.rawValue,
            "currentStability": currentStability.rawValue,
            "currentResources": currentResources.rawValue,
            "sampleCount": recentSamples.count
        ]
    }

    /// Get learned hourly patterns
    public func learnedPatterns() -> [IntervalTimePattern] {
        hourlyPatterns
    }

    // MARK: - Private Helpers

    private func recordSample(_ sample: IntervalActivitySample) {
        recentSamples.append(sample)
        if recentSamples.count > maxSamples {
            recentSamples.removeFirst(recentSamples.count - maxSamples)
        }

        // Update hourly pattern
        let hour = Calendar.current.component(.hour, from: sample.timestamp)
        updateHourlyPattern(hour: hour, observedActivity: sample.activity)
    }

    private func calculateTrendMultiplier() -> Double {
        guard recentSamples.count >= 3 else { return 1.0 }

        // Look at last few samples
        let recent = Array(recentSamples.suffix(10))
        let activities = recent.map { Double($0.activity.rawValue) }

        // Simple linear trend
        let n = Double(activities.count)
        let sumX = (0..<activities.count).reduce(0.0) { $0 + Double($1) }
        let sumY = activities.reduce(0, +)
        let sumXY = activities.enumerated().reduce(0.0) { $0 + Double($1.offset) * $1.element }
        let sumX2 = (0..<activities.count).reduce(0.0) { $0 + Double($1 * $1) }

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)

        // Convert slope to multiplier
        // Positive slope (increasing activity) = shorter intervals
        // Negative slope (decreasing activity) = longer intervals
        return max(0.5, min(1.5, 1.0 - slope * 0.2))
    }

    private func calculateConfidence(patternConfidence: Double) -> Double {
        var confidence = 0.5

        // More samples = more confidence
        let sampleFactor = min(1.0, Double(recentSamples.count) / 100.0)
        confidence += sampleFactor * 0.2

        // Pattern confidence contributes
        confidence += patternConfidence * 0.2

        // More decisions made = more confidence
        let decisionFactor = min(1.0, Double(totalDecisions) / 50.0)
        confidence += decisionFactor * 0.1

        return min(0.95, confidence)
    }

    private func calculateEffectiveness(changesApplied: Int, issuesDetected: Int, resourceUsage: Double) -> Double {
        // periphery:ignore - Reserved: _predictedActivity parameter — kept for API compatibility
        var score = 0.5

        // Good: Found issues and applied changes
        if issuesDetected > 0 && changesApplied > 0 {
            score += 0.2
        }

        // Good: Low resource usage
        if resourceUsage < 0.3 {
            score += 0.1
        } else if resourceUsage > 0.7 {
            score -= 0.1
        }

        // Bad: Missed issues (would need comparison with next cycle)
        // For now, just check ratio
        if issuesDetected > changesApplied * 2 {
            score -= 0.2 // Falling behind
        }

        return max(0, min(1, score))
    }

    // periphery:ignore:parameters _predictedActivity - Reserved: parameter(s) kept for API compatibility
    private func buildReason(
        activity: AdaptiveActivityLevel,
        stability: StabilityState,
        resources: ResourceAvailability,
        // periphery:ignore - Reserved: _predictedActivity parameter kept for API compatibility
        predictedActivity _predictedActivity: AdaptiveActivityLevel
    ) -> String {
        var parts: [String] = []

        switch activity {
        case .idle: parts.append("system idle")
        case .low: parts.append("low activity")
        case .moderate: break
        case .high: parts.append("high activity")
        case .intense: parts.append("intense activity")
        }

        switch stability {
        case .unstable: parts.append("unstable")
        case .stabilizing: parts.append("stabilizing")
        case .stable: break
        case .veryStable: parts.append("very stable")
        }

        switch resources {
        case .constrained: parts.append("resources constrained")
        case .limited: parts.append("limited resources")
        case .adequate: break
        case .abundant: parts.append("abundant resources")
        }

        if parts.isEmpty {
            return "normal conditions"
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Persistence

    /// Export state for persistence
    public func exportState() -> [String: Any] {
        let patternsData = hourlyPatterns.map { pattern -> [String: Any] in
            [
                "hour": pattern.hour,
                "expectedActivity": pattern.expectedActivity.rawValue,
                "confidence": pattern.confidence,
                "sampleCount": pattern.sampleCount
            ]
        }

        return [
            "adaptiveBaseline": adaptiveBaseline,
            "hourlyPatterns": patternsData,
            "totalDecisions": totalDecisions,
            "averageInterval": averageInterval,
            "intervalVariance": intervalVariance
        ]
    }

    /// Import state from persistence
    public func importState(_ state: [String: Any]) {
        if let baseline = state["adaptiveBaseline"] as? TimeInterval {
            adaptiveBaseline = baseline
        }

        if let total = state["totalDecisions"] as? Int {
            totalDecisions = total
        }

        if let avg = state["averageInterval"] as? TimeInterval {
            averageInterval = avg
        }

        if let variance = state["intervalVariance"] as? Double {
            intervalVariance = variance
        }

        if let patterns = state["hourlyPatterns"] as? [[String: Any]] {
            for patternData in patterns {
                guard let hour = patternData["hour"] as? Int,
                      let activityRaw = patternData["expectedActivity"] as? Int,
                      let confidence = patternData["confidence"] as? Double,
                      let sampleCount = patternData["sampleCount"] as? Int,
                      hour >= 0 && hour < 24 else {
                    continue
                }

                let activity = AdaptiveActivityLevel(rawValue: activityRaw) ?? .moderate
                hourlyPatterns[hour] = IntervalTimePattern(
                    hour: hour,
                    expectedActivity: activity,
                    confidence: confidence,
                    sampleCount: sampleCount
                )
            }
        }
    }
}
