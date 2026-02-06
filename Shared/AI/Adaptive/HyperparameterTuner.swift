// HyperparameterTuner.swift
// Thea V2 - Adaptive Hyperparameter Management
//
// Replaces ALL fixed hyperparameters with self-tuning alternatives using:
// - Thompson Sampling for exploration/exploitation balance
// - Bayesian posterior updates from outcomes
// - Volatility-adaptive learning rates
// - Confidence-based decision making
//
// "Absolutely Everything AI-Powered" - No hardcoded values

import Foundation
import os.log

// MARK: - Hyperparameter Identifiers

/// All tunable hyperparameters in the governance system
public enum HyperparameterID: String, CaseIterable, Codable, Sendable {
    // Governance timing
    case governanceIntervalSeconds
    case resourceSnapshotIntervalSeconds

    // EMA alphas (learning rates)
    case qualityEmaAlpha
    case predictiveEmaAlpha
    case proactivityLearningRate

    // Scoring weights (Supra-Model selection)
    case supraQualityWeight
    case supraResourceWeight
    case supraVersatilityWeight
    case supraRecencyWeight
    case supraCommunityWeight

    // Quality composite weights
    case qualitySuccessWeight
    case qualityLatencyWeight
    case qualitySatisfactionWeight
    case qualityThroughputWeight

    // Thresholds
    case evolutionThreshold
    case convergenceThreshold
    case rollbackSensitivity

    // Exploration rates
    case explorationRate
    case banditExplorationBonus

    // Memory tier thresholds (GB)
    case memoryTierUltra
    case memoryTierPro
    case memoryTierPlus

    /// Default initial value for each hyperparameter
    var defaultValue: Double {
        switch self {
        case .governanceIntervalSeconds: return 300.0
        case .resourceSnapshotIntervalSeconds: return 5.0
        case .qualityEmaAlpha: return 0.2
        case .predictiveEmaAlpha: return 0.3
        case .proactivityLearningRate: return 0.02
        case .supraQualityWeight: return 0.30
        case .supraResourceWeight: return 0.25
        case .supraVersatilityWeight: return 0.25
        case .supraRecencyWeight: return 0.10
        case .supraCommunityWeight: return 0.10
        case .qualitySuccessWeight: return 0.40
        case .qualityLatencyWeight: return 0.20
        case .qualitySatisfactionWeight: return 0.30
        case .qualityThroughputWeight: return 0.10
        case .evolutionThreshold: return 0.15
        case .convergenceThreshold: return 0.01
        case .rollbackSensitivity: return 0.15
        case .explorationRate: return 0.1
        case .banditExplorationBonus: return 2.0
        case .memoryTierUltra: return 24.0  // GB - ultra tier threshold
        case .memoryTierPro: return 12.0    // GB - pro tier threshold
        case .memoryTierPlus: return 6.0    // GB - plus tier threshold
        }
    }

    /// Valid range for this hyperparameter
    var validRange: ClosedRange<Double> {
        switch self {
        case .governanceIntervalSeconds: return 30.0...1800.0  // 30s to 30min
        case .resourceSnapshotIntervalSeconds: return 1.0...60.0
        case .qualityEmaAlpha, .predictiveEmaAlpha: return 0.01...0.9
        case .proactivityLearningRate: return 0.001...0.1
        case .supraQualityWeight, .supraResourceWeight, .supraVersatilityWeight,
             .supraRecencyWeight, .supraCommunityWeight: return 0.0...1.0
        case .qualitySuccessWeight, .qualityLatencyWeight,
             .qualitySatisfactionWeight, .qualityThroughputWeight: return 0.0...1.0
        case .evolutionThreshold: return 0.01...0.5
        case .convergenceThreshold: return 0.001...0.1
        case .rollbackSensitivity: return 0.05...0.5
        case .explorationRate: return 0.01...0.5
        case .banditExplorationBonus: return 0.5...5.0
        case .memoryTierUltra: return 16.0...64.0  // GB
        case .memoryTierPro: return 8.0...32.0     // GB
        case .memoryTierPlus: return 4.0...16.0    // GB
        }
    }

    /// Whether this parameter should be normalized with others (e.g., weights summing to 1)
    var normalizationGroup: NormalizationGroup? {
        switch self {
        case .supraQualityWeight, .supraResourceWeight, .supraVersatilityWeight,
             .supraRecencyWeight, .supraCommunityWeight:
            return .supraModelWeights
        case .qualitySuccessWeight, .qualityLatencyWeight,
             .qualitySatisfactionWeight, .qualityThroughputWeight:
            return .qualityWeights
        default:
            return nil
        }
    }
}

/// Groups of parameters that must sum to 1.0
public enum NormalizationGroup: String, CaseIterable, Codable, Sendable {
    case supraModelWeights
    case qualityWeights

    var members: [HyperparameterID] {
        switch self {
        case .supraModelWeights:
            return [.supraQualityWeight, .supraResourceWeight, .supraVersatilityWeight,
                    .supraRecencyWeight, .supraCommunityWeight]
        case .qualityWeights:
            return [.qualitySuccessWeight, .qualityLatencyWeight,
                    .qualitySatisfactionWeight, .qualityThroughputWeight]
        }
    }
}

// MARK: - Adaptive Hyperparameter

/// A self-tuning hyperparameter using Thompson Sampling
public struct AdaptiveHyperparameter: Codable, Sendable {
    public let id: HyperparameterID

    /// Current best estimate of optimal value
    public private(set) var currentValue: Double

    /// Beta distribution parameters for Thompson Sampling
    /// alpha = successes + 1, beta = failures + 1
    public private(set) var posteriorAlpha: Double
    public private(set) var posteriorBeta: Double

    /// Running statistics for adaptive learning
    public private(set) var sampleCount: Int
    public private(set) var runningMean: Double
    public private(set) var runningVariance: Double
    public private(set) var lastUpdated: Date

    /// History for trend analysis
    public private(set) var recentOutcomes: [OutcomeRecord]

    /// Convergence tracking
    public private(set) var consecutiveStableUpdates: Int

    private static let maxHistorySize = 100

    public init(id: HyperparameterID) {
        self.id = id
        self.currentValue = id.defaultValue
        self.posteriorAlpha = 1.0  // Uniform prior
        self.posteriorBeta = 1.0
        self.sampleCount = 0
        self.runningMean = id.defaultValue
        self.runningVariance = 0.0
        self.lastUpdated = Date()
        self.recentOutcomes = []
        self.consecutiveStableUpdates = 0
    }

    // MARK: - Thompson Sampling

    /// Sample a value using Thompson Sampling for exploration/exploitation
    public mutating func sample() -> Double {
        // Sample from Beta distribution
        let sampled = sampleBetaDistribution(alpha: posteriorAlpha, beta: posteriorBeta)

        // Map [0, 1] to valid range
        let range = id.validRange
        let value = range.lowerBound + sampled * (range.upperBound - range.lowerBound)

        return value.clamped(to: range)
    }

    /// Sample with UCB (Upper Confidence Bound) for guaranteed exploration
    public func sampleUCB(totalTrials: Int, explorationBonus: Double = 2.0) -> Double {
        guard sampleCount > 0, totalTrials > 0 else {
            return id.defaultValue
        }

        // UCB1 formula: mean + c * sqrt(ln(t) / n)
        let mean = runningMean
        let exploration = explorationBonus * sqrt(log(Double(totalTrials)) / Double(sampleCount))

        let range = id.validRange
        let normalizedMean = (mean - range.lowerBound) / (range.upperBound - range.lowerBound)
        let ucbValue = normalizedMean + exploration

        return (range.lowerBound + ucbValue * (range.upperBound - range.lowerBound))
            .clamped(to: range)
    }

    // MARK: - Bayesian Update

    /// Update posterior distribution based on observed outcome
    /// - Parameters:
    ///   - testedValue: The value that was tested
    ///   - outcome: Normalized outcome in [0, 1] where 1 is best
    ///   - context: Optional context for the trial
    public mutating func update(testedValue: Double, outcome: Double, context: TuningContext? = nil) {
        let clampedOutcome = outcome.clamped(to: 0.0...1.0)

        // Bayesian update for Beta distribution
        // Treat outcome as probability of success in Bernoulli trial
        posteriorAlpha += clampedOutcome
        posteriorBeta += (1 - clampedOutcome)

        // Update running statistics using Welford's algorithm
        sampleCount += 1
        let delta = testedValue - runningMean
        runningMean += delta / Double(sampleCount)
        let delta2 = testedValue - runningMean
        runningVariance += delta * delta2

        // Record outcome
        let record = OutcomeRecord(
            value: testedValue,
            outcome: clampedOutcome,
            timestamp: Date(),
            context: context
        )
        recentOutcomes.append(record)
        if recentOutcomes.count > Self.maxHistorySize {
            recentOutcomes.removeFirst()
        }

        // Update current value if outcome is good
        if clampedOutcome > 0.5 {
            // Weighted update toward tested value
            let adaptiveAlpha = getAdaptiveAlpha()
            currentValue = currentValue * (1 - adaptiveAlpha) + testedValue * adaptiveAlpha
            currentValue = currentValue.clamped(to: id.validRange)
        }

        // Track stability
        let wasStable = abs(testedValue - currentValue) / max(currentValue, 0.001) < 0.05
        if wasStable && clampedOutcome > 0.6 {
            consecutiveStableUpdates += 1
        } else {
            consecutiveStableUpdates = 0
        }

        lastUpdated = Date()
    }

    // MARK: - Adaptive Learning Rate

    /// Get volatility-adaptive learning rate
    public func getAdaptiveAlpha() -> Double {
        let baseAlpha = 0.1
        let minAlpha = 0.01
        let maxAlpha = 0.5

        guard sampleCount > 5 else { return baseAlpha }

        // Calculate coefficient of variation
        let variance = runningVariance / Double(sampleCount)
        let stdDev = sqrt(max(0, variance))
        let cv = stdDev / max(abs(runningMean), 0.001)

        // High volatility → higher alpha (respond faster)
        // Low volatility → lower alpha (smooth noise)
        let alpha = baseAlpha + cv * 0.3

        return alpha.clamped(to: minAlpha...maxAlpha)
    }

    // MARK: - Convergence Detection

    /// Check if this parameter has converged
    public var isConverged: Bool {
        guard sampleCount >= 20 else { return false }

        // Check variance is low
        let variance = runningVariance / Double(sampleCount)
        let cv = sqrt(max(0, variance)) / max(abs(runningMean), 0.001)

        // Check recent outcomes are stable
        let recentStable = consecutiveStableUpdates >= 10

        return cv < 0.1 && recentStable
    }

    /// Confidence in current value (0-1)
    public var confidence: Double {
        guard sampleCount > 0 else { return 0.0 }

        // Based on sample count and variance
        let sampleConfidence = min(1.0, Double(sampleCount) / 50.0)

        let variance = runningVariance / Double(sampleCount)
        let cv = sqrt(max(0, variance)) / max(abs(runningMean), 0.001)
        let varianceConfidence = max(0, 1.0 - cv)

        // Decay confidence over time
        let age = Date().timeIntervalSince(lastUpdated)
        let recencyConfidence = max(0, 1.0 - age / (3600 * 24 * 7))  // 1 week decay

        return (sampleConfidence * 0.4 + varianceConfidence * 0.4 + recencyConfidence * 0.2)
    }

    /// Get 95% confidence interval
    public var confidenceInterval: (lower: Double, upper: Double) {
        guard sampleCount > 2 else {
            return (id.validRange.lowerBound, id.validRange.upperBound)
        }

        let variance = runningVariance / Double(sampleCount)
        let stdErr = sqrt(variance / Double(sampleCount))
        let margin = 1.96 * stdErr  // 95% CI

        let lower = max(id.validRange.lowerBound, currentValue - margin)
        let upper = min(id.validRange.upperBound, currentValue + margin)

        return (lower, upper)
    }

    // MARK: - Trend Analysis

    /// Calculate recent trend (positive = improving)
    public func calculateTrend(windowSize: Int = 20) -> Double {
        let window = Array(recentOutcomes.suffix(windowSize))
        guard window.count >= 5 else { return 0.0 }

        // Linear regression on outcomes
        let n = Double(window.count)
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0

        for (i, record) in window.enumerated() {
            let x = Double(i)
            let y = record.outcome
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        return slope
    }

    // MARK: - Reset

    /// Reset to initial state (for rollback)
    public mutating func reset() {
        currentValue = id.defaultValue
        posteriorAlpha = 1.0
        posteriorBeta = 1.0
        sampleCount = 0
        runningMean = id.defaultValue
        runningVariance = 0.0
        recentOutcomes = []
        consecutiveStableUpdates = 0
        lastUpdated = Date()
    }

    // MARK: - Direct Value Setting (for normalization)

    /// Directly set the current value (used for weight normalization)
    internal mutating func setCurrentValue(_ value: Double) {
        currentValue = value.clamped(to: id.validRange)
        lastUpdated = Date()
    }
}

// MARK: - Supporting Types

/// Record of a single trial outcome
public struct OutcomeRecord: Codable, Sendable {
    public let value: Double
    public let outcome: Double
    public let timestamp: Date
    public let context: TuningContext?
}

/// Context for hyperparameter tuning
public struct TuningContext: Codable, Hashable, Sendable {
    public let taskType: String?
    public let timeOfDay: Int?  // Hour 0-23
    public let resourcePressure: ResourcePressure?
    public let userActivity: UserActivityLevel?

    public init(
        taskType: String? = nil,
        timeOfDay: Int? = nil,
        resourcePressure: ResourcePressure? = nil,
        userActivity: UserActivityLevel? = nil
    ) {
        self.taskType = taskType
        self.timeOfDay = timeOfDay
        self.resourcePressure = resourcePressure
        self.userActivity = userActivity
    }

    public static var current: TuningContext {
        TuningContext(
            timeOfDay: Calendar.current.component(.hour, from: Date())
        )
    }
}

public enum ResourcePressure: String, Codable, Sendable {
    case low, moderate, high, critical
}

public enum UserActivityLevel: String, Codable, Sendable {
    case idle, light, moderate, heavy
}

// MARK: - Hyperparameter Tuner Actor

/// Central manager for all adaptive hyperparameters
@MainActor
public final class HyperparameterTuner: ObservableObject {
    public static let shared = HyperparameterTuner()

    private let logger = Logger(subsystem: "ai.thea.app", category: "HyperparameterTuner")

    // MARK: - Published State

    @Published public private(set) var parameters: [HyperparameterID: AdaptiveHyperparameter]
    @Published public private(set) var totalTrials: Int = 0
    @Published public private(set) var lastGlobalUpdate = Date()

    // MARK: - Configuration

    public var explorationMode: ExplorationMode = .balanced

    public enum ExplorationMode: String, CaseIterable, Sendable {
        case aggressive   // High exploration
        case balanced     // Thompson Sampling default
        case conservative // Prefer exploitation
        case convergent   // Minimize exploration (for stable systems)
    }

    // MARK: - Persistence

    private let persistenceKey = "HyperparameterTuner.state"

    // MARK: - Initialization

    private init() {
        // Initialize all parameters with defaults
        var params: [HyperparameterID: AdaptiveHyperparameter] = [:]
        for id in HyperparameterID.allCases {
            params[id] = AdaptiveHyperparameter(id: id)
        }
        self.parameters = params

        // Load persisted state
        loadState()

        logger.info("HyperparameterTuner initialized with \(HyperparameterID.allCases.count) parameters")
    }

    // MARK: - Public API

    /// Get current value for a hyperparameter
    public func getValue(_ id: HyperparameterID) -> Double {
        parameters[id]?.currentValue ?? id.defaultValue
    }

    /// Get sampled value for exploration (Thompson Sampling)
    public func sample(_ id: HyperparameterID) -> Double {
        guard var param = parameters[id] else {
            return id.defaultValue
        }

        let sampled: Double
        switch explorationMode {
        case .aggressive:
            sampled = param.sample()
        case .balanced:
            sampled = param.sample()
        case .conservative:
            // Blend sample with current value
            let sample = param.sample()
            sampled = param.currentValue * 0.7 + sample * 0.3
        case .convergent:
            // Use UCB with low exploration bonus
            sampled = param.sampleUCB(totalTrials: totalTrials, explorationBonus: 0.5)
        }

        parameters[id] = param
        return sampled.clamped(to: id.validRange)
    }

    /// Get sampled value with UCB exploration guarantee
    public func sampleUCB(_ id: HyperparameterID, explorationBonus: Double? = nil) -> Double {
        guard let param = parameters[id] else {
            return id.defaultValue
        }

        let bonus = explorationBonus ?? getValue(.banditExplorationBonus)
        return param.sampleUCB(totalTrials: totalTrials, explorationBonus: bonus)
    }

    /// Record outcome for a hyperparameter
    public func recordOutcome(
        _ id: HyperparameterID,
        testedValue: Double,
        outcome: Double,
        context: TuningContext? = nil
    ) {
        guard var param = parameters[id] else { return }

        param.update(testedValue: testedValue, outcome: outcome, context: context)
        parameters[id] = param

        totalTrials += 1
        lastGlobalUpdate = Date()

        // Normalize weight groups if needed
        if let group = id.normalizationGroup {
            normalizeGroup(group)
        }

        // Persist periodically
        if totalTrials % 10 == 0 {
            saveState()
        }

        logger.debug("Updated \(id.rawValue): value=\(testedValue, format: .fixed(precision: 4)), outcome=\(outcome, format: .fixed(precision: 3))")
    }

    /// Get all weights for a normalization group
    public func getWeights(_ group: NormalizationGroup) -> [HyperparameterID: Double] {
        var weights: [HyperparameterID: Double] = [:]
        for id in group.members {
            weights[id] = getValue(id)
        }
        return weights
    }

    /// Get confidence for a parameter
    public func getConfidence(_ id: HyperparameterID) -> Double {
        parameters[id]?.confidence ?? 0.0
    }

    /// Check if parameter has converged
    public func isConverged(_ id: HyperparameterID) -> Bool {
        parameters[id]?.isConverged ?? false
    }

    /// Get overall system convergence (proportion of converged parameters)
    public var systemConvergence: Double {
        let converged = parameters.values.filter { $0.isConverged }.count
        return Double(converged) / Double(parameters.count)
    }

    /// Get adaptive EMA alpha based on parameter volatility
    public func getAdaptiveEmaAlpha(for id: HyperparameterID) -> Double {
        parameters[id]?.getAdaptiveAlpha() ?? 0.1
    }

    // MARK: - Weight Normalization

    /// Normalize weights in a group to sum to 1.0
    private func normalizeGroup(_ group: NormalizationGroup) {
        let members = group.members
        let total = members.reduce(0.0) { $0 + (parameters[$1]?.currentValue ?? 0) }

        guard total > 0 else { return }

        for id in members {
            if let param = parameters[id] {
                let normalized = param.currentValue / total
                parameters[id]?.setCurrentValue(normalized)
            }
        }
    }

    // MARK: - Rollback

    /// Reset a parameter to default
    public func resetParameter(_ id: HyperparameterID) {
        parameters[id]?.reset()
        logger.info("Reset parameter: \(id.rawValue)")
    }

    /// Reset all parameters to defaults
    public func resetAll() {
        for id in HyperparameterID.allCases {
            parameters[id]?.reset()
        }
        totalTrials = 0
        saveState()
        logger.warning("Reset all hyperparameters to defaults")
    }

    // MARK: - Persistence

    private func saveState() {
        let state = PersistentState(
            parameters: parameters,
            totalTrials: totalTrials,
            lastUpdate: lastGlobalUpdate
        )

        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let state = try? JSONDecoder().decode(PersistentState.self, from: data) else {
            return
        }

        self.parameters = state.parameters
        self.totalTrials = state.totalTrials
        self.lastGlobalUpdate = state.lastUpdate

        logger.info("Loaded hyperparameter state: \(self.totalTrials) trials")
    }

    private struct PersistentState: Codable {
        let parameters: [HyperparameterID: AdaptiveHyperparameter]
        let totalTrials: Int
        let lastUpdate: Date
    }

    // MARK: - Diagnostics

    /// Get diagnostic summary
    public func getDiagnostics() -> HyperparameterDiagnostics {
        var paramDiagnostics: [HyperparameterID: ParameterDiagnostic] = [:]

        for (id, param) in parameters {
            let ci = param.confidenceInterval
            paramDiagnostics[id] = ParameterDiagnostic(
                currentValue: param.currentValue,
                defaultValue: id.defaultValue,
                sampleCount: param.sampleCount,
                confidence: param.confidence,
                isConverged: param.isConverged,
                trend: param.calculateTrend(),
                confidenceIntervalLower: ci.lower,
                confidenceIntervalUpper: ci.upper
            )
        }

        return HyperparameterDiagnostics(
            parameters: paramDiagnostics,
            totalTrials: totalTrials,
            systemConvergence: systemConvergence,
            explorationMode: explorationMode,
            lastUpdate: lastGlobalUpdate
        )
    }
}

// MARK: - Diagnostics Types

public struct HyperparameterDiagnostics: Sendable {
    public let parameters: [HyperparameterID: ParameterDiagnostic]
    public let totalTrials: Int
    public let systemConvergence: Double
    public let explorationMode: HyperparameterTuner.ExplorationMode
    public let lastUpdate: Date
}

public struct ParameterDiagnostic: Sendable {
    public let currentValue: Double
    public let defaultValue: Double
    public let sampleCount: Int
    public let confidence: Double
    public let isConverged: Bool
    public let trend: Double
    public let confidenceIntervalLower: Double
    public let confidenceIntervalUpper: Double

    public var deviationFromDefault: Double {
        guard defaultValue != 0 else { return currentValue }
        return (currentValue - defaultValue) / defaultValue
    }
}

// MARK: - Helpers

/// Sample from Beta distribution using transformation method
private func sampleBetaDistribution(alpha: Double, beta: Double) -> Double {
    // Use gamma distribution to generate beta samples
    let x = sampleGammaDistribution(shape: alpha)
    let y = sampleGammaDistribution(shape: beta)
    return x / (x + y)
}

/// Sample from Gamma distribution using Marsaglia and Tsang's method
private func sampleGammaDistribution(shape: Double) -> Double {
    guard shape >= 1 else {
        // For shape < 1, use transformation
        let u = Double.random(in: 0..<1)
        return sampleGammaDistribution(shape: shape + 1) * pow(u, 1 / shape)
    }

    let d = shape - 1.0 / 3.0
    let c = 1.0 / sqrt(9.0 * d)

    while true {
        var x: Double
        var v: Double

        repeat {
            x = sampleStandardNormal()
            v = 1.0 + c * x
        } while v <= 0

        v = v * v * v
        let u = Double.random(in: 0..<1)

        if u < 1.0 - 0.0331 * (x * x) * (x * x) {
            return d * v
        }

        if log(u) < 0.5 * x * x + d * (1.0 - v + log(v)) {
            return d * v
        }
    }
}

/// Sample from standard normal using Box-Muller transform
private func sampleStandardNormal() -> Double {
    let u1 = Double.random(in: 0..<1)
    let u2 = Double.random(in: 0..<1)
    return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Notification Extensions

public extension Notification.Name {
    static let hyperparameterConverged = Notification.Name("ai.thea.hyperparameterConverged")
    static let hyperparameterDiverged = Notification.Name("ai.thea.hyperparameterDiverged")
}
