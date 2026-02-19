// ConvergenceDetector.swift
// Thea V2 - System Convergence Detection and Stability Management
//
// Monitors all adaptive systems to detect:
// - Exploring: System is actively learning
// - Converging: Metrics are stabilizing
// - Converged: System has reached stable optimal state
// - Diverging: Performance is degrading
// - Unstable: Oscillating without settling
//
// Enables confidence-based decision making and automatic rollback.
// "Absolutely Everything AI-Powered"

import Foundation
import os.log
import Combine

// MARK: - Convergence States

/// Possible states of the adaptive system
public enum ConvergenceState: String, Codable, Sendable {
    case exploring      // High variance, actively learning
    case converging     // Variance decreasing, trending toward stability
    case converged      // Stable, optimal state reached
    case diverging      // Performance degrading from previous good state
    case unstable       // Oscillating without settling
    case unknown        // Not enough data

    /// Recommended action for this state
    public var recommendedAction: RecommendedAction {
        switch self {
        case .exploring: return .continueExploration
        case .converging: return .reduceExploration
        case .converged: return .maintainStability
        case .diverging: return .investigateAndRevert
        case .unstable: return .pauseAndStabilize
        case .unknown: return .gatherData
        }
    }

    /// Whether the system should accept new changes
    public var acceptsChanges: Bool {
        switch self {
        case .exploring, .converging, .diverging: return true
        case .converged: return false  // Only accept if significantly better
        case .unstable, .unknown: return false
        }
    }

    /// Exploration multiplier for this state
    public var explorationMultiplier: Double {
        switch self {
        case .exploring: return 1.5
        case .converging: return 0.7
        case .converged: return 0.2
        case .diverging: return 2.0  // Need more exploration to find better
        case .unstable: return 0.1   // Reduce changes
        case .unknown: return 1.0
        }
    }
}

public enum RecommendedAction: String, Sendable {
    case continueExploration
    case reduceExploration
    case maintainStability
    case investigateAndRevert
    case pauseAndStabilize
    case gatherData
}

// MARK: - Metric Snapshot

/// A point-in-time snapshot of system metrics
public struct MetricSnapshot: Codable, Sendable {
    public let timestamp: Date
    public let compositeQuality: Double
    public let latency: Double
    public let userSatisfaction: Double
    public let errorRate: Double
    public let resourceEfficiency: Double

    public init(
        compositeQuality: Double,
        latency: Double,
        userSatisfaction: Double,
        errorRate: Double,
        resourceEfficiency: Double
    ) {
        self.timestamp = Date()
        self.compositeQuality = compositeQuality
        self.latency = latency
        self.userSatisfaction = userSatisfaction
        self.errorRate = errorRate
        self.resourceEfficiency = resourceEfficiency
    }

    /// Combined score for comparison
    public var overallScore: Double {
        // Weight: quality (40%), satisfaction (30%), efficiency (20%), -errors (10%)
        let errorPenalty = 1.0 - errorRate
        return compositeQuality * 0.4 +
               userSatisfaction * 0.3 +
               resourceEfficiency * 0.2 +
               errorPenalty * 0.1
    }
}

// MARK: - Convergence Analysis

/// Result of convergence analysis
public struct ConvergenceAnalysis: Sendable {
    public let state: ConvergenceState
    public let confidence: Double           // How confident we are in this assessment
    public let variance: Double             // Current metric variance
    public let trend: Double                // Trend direction (positive = improving)
    public let oscillationCount: Int        // Number of direction changes
    public let sinceConverged: TimeInterval?  // Time since last converged state
    public let recommendation: String

    public init(
        state: ConvergenceState,
        confidence: Double,
        variance: Double,
        trend: Double,
        oscillationCount: Int,
        sinceConverged: TimeInterval?,
        recommendation: String
    ) {
        self.state = state
        self.confidence = confidence
        self.variance = variance
        self.trend = trend
        self.oscillationCount = oscillationCount
        self.sinceConverged = sinceConverged
        self.recommendation = recommendation
    }
}

// MARK: - Decision Types

/// Decision about whether to apply a proposed change
public enum ChangeDecision: Sendable {
    case apply(reason: String)
    case postpone(reason: String)
    case experimentSmall(reason: String, scale: Double)
    case reject(reason: String)

    public var shouldProceed: Bool {
        switch self {
        case .apply, .experimentSmall: return true
        case .postpone, .reject: return false
        }
    }
}

// MARK: - Convergence Detector

/// Monitors system convergence and stability
@MainActor
public final class ConvergenceDetector: ObservableObject {
    public static let shared = ConvergenceDetector()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ConvergenceDetector")

    // MARK: - State

    /// History of metric snapshots
    private var metricHistory: [MetricSnapshot] = []

    /// Current convergence state
    @Published public private(set) var currentState: ConvergenceState = .unknown

    /// Last time system was in converged state
    @Published public private(set) var lastConvergedAt: Date?

    /// Checkpoints for rollback
    private var checkpoints: [Checkpoint] = []

    // MARK: - Configuration

    /// Maximum history size
    private let maxHistorySize = 500

    /// Minimum samples for reliable analysis
    public var minSamplesForAnalysis: Int = 20

    /// Variance threshold for convergence
    public var convergenceVarianceThreshold: Double {
        HyperparameterTuner.shared.getValue(.convergenceThreshold)
    }

    /// Threshold for detecting divergence
    public var divergenceThreshold: Double {
        HyperparameterTuner.shared.getValue(.rollbackSensitivity)
    }

    /// Oscillation threshold for instability
    public var oscillationThreshold: Int = 5

    /// Window size for trend calculation
    public var trendWindowSize: Int = 20

    /// Window size for variance calculation
    public var varianceWindowSize: Int = 50

    // MARK: - Persistence

    private let persistenceKey = "ConvergenceDetector.state"

    // MARK: - Initialization

    private init() {
        loadState()
        logger.info("ConvergenceDetector initialized")
    }

    // MARK: - Recording

    /// Record a new metric snapshot
    public func recordSnapshot(_ snapshot: MetricSnapshot) {
        metricHistory.append(snapshot)

        // Trim history if needed
        if metricHistory.count > maxHistorySize {
            metricHistory.removeFirst(metricHistory.count - maxHistorySize)
        }

        // Update convergence state
        let analysis = analyze()
        currentState = analysis.state

        // Update converged timestamp
        if currentState == .converged {
            lastConvergedAt = Date()
        }

        // Persist periodically
        if metricHistory.count % 50 == 0 {
            saveState()
        }

        logger.debug("Recorded snapshot: score=\(snapshot.overallScore, format: .fixed(precision: 3)), state=\(self.currentState.rawValue)")
    }

    /// Record from individual metrics
    public func recordMetrics(
        quality: Double,
        latency: Double,
        satisfaction: Double,
        errorRate: Double,
        efficiency: Double
    ) {
        let snapshot = MetricSnapshot(
            compositeQuality: quality,
            latency: latency,
            userSatisfaction: satisfaction,
            errorRate: errorRate,
            resourceEfficiency: efficiency
        )
        recordSnapshot(snapshot)
    }

    // MARK: - Analysis

    /// Analyze current convergence state
    public func analyze() -> ConvergenceAnalysis {
        guard metricHistory.count >= minSamplesForAnalysis else {
            return ConvergenceAnalysis(
                state: .unknown,
                confidence: 0.0,
                variance: 0.0,
                trend: 0.0,
                oscillationCount: 0,
                sinceConverged: nil,
                recommendation: "Gathering data - need at least \(minSamplesForAnalysis) samples"
            )
        }

        // Calculate variance over recent window
        let recentScores = metricHistory.suffix(varianceWindowSize).map(\.overallScore)
        let variance = calculateVariance(recentScores)

        // Calculate trend over recent window
        let trend = calculateTrend(Array(metricHistory.suffix(trendWindowSize)))

        // Count oscillations (direction changes in trend)
        let oscillations = countOscillations(Array(metricHistory.suffix(trendWindowSize * 2)))

        // Determine state
        let state: ConvergenceState
        var recommendation: String
        var confidence: Double

        if oscillations > oscillationThreshold {
            state = .unstable
            recommendation = "System is oscillating - reduce exploration and stabilize"
            confidence = 0.7 + min(0.3, Double(oscillations - oscillationThreshold) * 0.05)
        } else if variance < convergenceVarianceThreshold && abs(trend) < 0.01 {
            state = .converged
            recommendation = "System has converged - maintain current parameters"
            confidence = min(1.0, 0.7 + (convergenceVarianceThreshold - variance) * 10)
        } else if variance < convergenceVarianceThreshold * 3 && trend > 0 {
            state = .converging
            recommendation = "System is converging - gradually reduce exploration"
            confidence = 0.6 + min(0.3, trend * 5)
        } else if trend < -divergenceThreshold {
            state = .diverging
            recommendation = "Performance degrading - consider rollback to checkpoint"
            confidence = 0.6 + min(0.4, abs(trend) * 3)
        } else {
            state = .exploring
            recommendation = "Continue exploration - learning optimal parameters"
            confidence = 0.5
        }

        // periphery:ignore - Reserved: changeRisk parameter — kept for API compatibility
        let timeSinceConverged: TimeInterval?
        if let lastConverged = lastConvergedAt {
            timeSinceConverged = Date().timeIntervalSince(lastConverged)
        } else {
            timeSinceConverged = nil
        }

        return ConvergenceAnalysis(
            state: state,
            confidence: confidence,
            // periphery:ignore - Reserved: changeRisk parameter — kept for API compatibility
            variance: variance,
            trend: trend,
            oscillationCount: oscillations,
            sinceConverged: timeSinceConverged,
            recommendation: recommendation
        )
    }

    // MARK: - Decision Making

    // periphery:ignore:parameters changeRisk - Reserved: parameter(s) kept for API compatibility
    /// Decide whether to apply a proposed change
    public func shouldApplyChange(
        expectedImprovement: Double,
        // periphery:ignore - Reserved: changeRisk parameter kept for API compatibility
        changeRisk: Double = 0.5
    ) -> ChangeDecision {
        let analysis = analyze()

        switch analysis.state {
        case .converged:
            // Only accept significant improvements
            if expectedImprovement > divergenceThreshold * 2 {
                return .experimentSmall(
                    reason: "System converged, but significant improvement expected",
                    scale: 0.3
                )
            }
            return .reject(reason: "System converged - change not warranted")

        case .unstable:
            return .postpone(reason: "System unstable - stabilize first")

        case .diverging:
            if expectedImprovement > 0 {
                return .apply(reason: "System diverging - trying proposed improvement")
            }
            return .postpone(reason: "System diverging - investigating before more changes")

        case .exploring:
            return .apply(reason: "Actively exploring - change accepted")

        case .converging:
            // Be more selective
            if expectedImprovement > divergenceThreshold {
                return .experimentSmall(
                    reason: "System converging - testing promising change",
                    scale: 0.5
                )
            }
            return .postpone(reason: "System converging - waiting for stabilization")

        case .unknown:
            return .postpone(reason: "Not enough data to assess impact")
        }
    }

    /// Confidence-based decision using Kelly Criterion inspiration
    public func kellyDecision(
        expectedImprovement: Double,
        winProbability: Double
    ) -> ChangeDecision {
        // Kelly fraction: f* = (bp - q) / b
        // where b = odds, p = win prob, q = loss prob
        let edgeRatio = expectedImprovement / max(0.01, divergenceThreshold)
        let kellyFraction = (edgeRatio * winProbability - (1 - winProbability)) / max(0.01, edgeRatio)

        if kellyFraction <= 0 {
            return .reject(reason: "Expected value negative - Kelly suggests no bet")
        }

        if kellyFraction < 0.1 {
            return .experimentSmall(
                reason: "Small positive edge - minimal experiment",
                scale: kellyFraction
            )
        }

        if kellyFraction < 0.5 {
            return .experimentSmall(
                reason: "Moderate positive edge - scaled experiment",
                scale: kellyFraction
            )
        }

        return .apply(reason: "Strong positive edge - full application")
    }

    // MARK: - Checkpointing

    /// Create a checkpoint of current state
    public func createCheckpoint(reason: String) {
        guard let lastSnapshot = metricHistory.last else { return }

        let checkpoint = Checkpoint(
            timestamp: Date(),
            metrics: lastSnapshot,
            reason: reason
        )

        checkpoints.append(checkpoint)

        // Keep only recent checkpoints
        if checkpoints.count > 20 {
            checkpoints.removeFirst()
        }

        logger.info("Created checkpoint: \(reason)")
    }

    /// Find best checkpoint for rollback
    public func findBestCheckpoint() -> Checkpoint? {
        checkpoints.max { $0.metrics.overallScore < $1.metrics.overallScore }
    }

    /// Find last good checkpoint (before divergence)
    public func findLastGoodCheckpoint(minimumScore: Double? = nil) -> Checkpoint? {
        let threshold = minimumScore ?? (metricHistory.last?.overallScore ?? 0.5) + divergenceThreshold

        return checkpoints.last { $0.metrics.overallScore >= threshold }
    }

    // MARK: - Statistical Helpers

    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }

        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count - 1)
    }

    private func calculateTrend(_ snapshots: [MetricSnapshot]) -> Double {
        guard snapshots.count >= 5 else { return 0 }

        // Linear regression on scores
        let scores = snapshots.map(\.overallScore)
        let n = Double(scores.count)

        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0

        for (i, score) in scores.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += score
            sumXY += x * score
            sumX2 += x * x
        }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return 0 }

        return (n * sumXY - sumX * sumY) / denominator
    }

    private func countOscillations(_ snapshots: [MetricSnapshot]) -> Int {
        guard snapshots.count >= 3 else { return 0 }

        let scores = snapshots.map(\.overallScore)
        var oscillations = 0
        var lastDirection: Int?  // 1 = up, -1 = down

        for i in 1..<scores.count {
            let diff = scores[i] - scores[i-1]
            let direction = diff > 0.01 ? 1 : (diff < -0.01 ? -1 : 0)

            if direction != 0 {
                if let last = lastDirection, last != direction {
                    oscillations += 1
                }
                lastDirection = direction
            }
        }

        return oscillations
    }

    // MARK: - Persistence

    private func saveState() {
        let state = DetectorState(
            recentMetrics: Array(metricHistory.suffix(200)),
            checkpoints: checkpoints,
            lastConvergedAt: lastConvergedAt
        )

        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            logger.error("Failed to encode DetectorState: \(error.localizedDescription)")
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        let state: DetectorState
        do {
            state = try JSONDecoder().decode(DetectorState.self, from: data)
        } catch {
            logger.error("Failed to decode DetectorState: \(error.localizedDescription)")
            return
        }

        self.metricHistory = state.recentMetrics
        self.checkpoints = state.checkpoints
        self.lastConvergedAt = state.lastConvergedAt

        // Recompute current state
        if metricHistory.count >= minSamplesForAnalysis {
            currentState = analyze().state
        }

        logger.info("Loaded convergence state: \(self.metricHistory.count) samples, state=\(self.currentState.rawValue)")
    }

    private struct DetectorState: Codable {
        let recentMetrics: [MetricSnapshot]
        let checkpoints: [Checkpoint]
        let lastConvergedAt: Date?
    }

    // MARK: - Reset

    /// Reset all convergence data
    public func resetAll() {
        metricHistory.removeAll()
        checkpoints.removeAll()
        currentState = .unknown
        lastConvergedAt = nil
        saveState()
        logger.warning("Reset all convergence data")
    }

    // MARK: - Diagnostics

    /// Get detailed diagnostics
    public func getDiagnostics() -> ConvergenceDiagnostics {
        let analysis = analyze()
        let scores = metricHistory.suffix(50).map(\.overallScore)
        let avgScore = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
        let minScore = scores.min() ?? 0
        let maxScore = scores.max() ?? 0

        return ConvergenceDiagnostics(
            currentState: currentState,
            analysis: analysis,
            sampleCount: metricHistory.count,
            checkpointCount: checkpoints.count,
            averageScore: avgScore,
            minScore: minScore,
            maxScore: maxScore,
            lastConvergedAt: lastConvergedAt
        )
    }
}

// MARK: - Checkpoint

public struct Checkpoint: Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let metrics: MetricSnapshot
    public let reason: String

    public init(timestamp: Date, metrics: MetricSnapshot, reason: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.metrics = metrics
        self.reason = reason
    }
}

// MARK: - Diagnostics

public struct ConvergenceDiagnostics: Sendable {
    public let currentState: ConvergenceState
    public let analysis: ConvergenceAnalysis
    public let sampleCount: Int
    public let checkpointCount: Int
    public let averageScore: Double
    public let minScore: Double
    public let maxScore: Double
    public let lastConvergedAt: Date?
}

// MARK: - Notifications

public extension Notification.Name {
    static let convergenceStateChanged = Notification.Name("ai.thea.convergenceStateChanged")
    static let systemDiverging = Notification.Name("ai.thea.systemDiverging")
    static let systemUnstable = Notification.Name("ai.thea.systemUnstable")
}
