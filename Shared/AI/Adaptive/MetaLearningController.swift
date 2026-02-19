//
//  MetaLearningController.swift
//  Thea
//
//  Created by Claude on 2026-02-05.
//
//  The optimizer that optimizes itself.
//  Monitors performance of optimization strategies, auto-switches between
//  exploration/exploitation, adjusts learning rates, and triggers rollbacks.
//

import Foundation

// MARK: - Optimization Strategy

/// Available optimization strategies
public enum OptimizationStrategy: String, Sendable, CaseIterable {
    case thompsonSampling = "thompson_sampling"
    case ucb = "ucb"
    case epsilonGreedy = "epsilon_greedy"
    case boltzmann = "boltzmann"
    case gradientBased = "gradient_based"
    case bayesianOptimization = "bayesian_optimization"

    public var description: String {
        switch self {
        case .thompsonSampling: return "Thompson Sampling (Bayesian)"
        case .ucb: return "Upper Confidence Bound"
        case .epsilonGreedy: return "Epsilon-Greedy"
        case .boltzmann: return "Boltzmann Exploration"
        case .gradientBased: return "Gradient-Based Optimization"
        case .bayesianOptimization: return "Bayesian Optimization"
        }
    }

    /// Whether this strategy emphasizes exploration
    public var isExploratory: Bool {
        switch self {
        case .thompsonSampling, .ucb, .boltzmann: return true
        case .epsilonGreedy, .gradientBased, .bayesianOptimization: return false
        }
    }
}

// MARK: - Strategy Performance

/// Tracks performance of an optimization strategy
public struct StrategyPerformance: Sendable {
    public let strategy: OptimizationStrategy
    public var successCount: Int = 0
    public var failureCount: Int = 0
    public var totalReward: Double = 0
    public var averageImprovement: Double = 0
    public var lastUsed: Date?
    public var consecutiveFailures: Int = 0

    /// Beta distribution parameters for Thompson Sampling
    public var alpha: Double = 1.0
    public var beta: Double = 1.0

    public init(strategy: OptimizationStrategy) {
        self.strategy = strategy
    }

    public var totalAttempts: Int { successCount + failureCount }

    public var successRate: Double {
        guard totalAttempts > 0 else { return 0.5 }
        return Double(successCount) / Double(totalAttempts)
    }

    public mutating func recordSuccess(reward: Double) {
        successCount += 1
        totalReward += reward
        consecutiveFailures = 0
        lastUsed = Date()

        // Bayesian update
        alpha += reward
        averageImprovement = totalReward / Double(totalAttempts)
    }

    public mutating func recordFailure() {
        failureCount += 1
        consecutiveFailures += 1
        lastUsed = Date()

        // Bayesian update
        beta += 1
    }

    /// Sample from posterior for Thompson Sampling
    public func sample() -> Double {
        // Beta distribution sampling approximation
        let x = Double.random(in: 0...1)
        let y = Double.random(in: 0...1)

        // Box-Muller transform for normal approximation to beta
        let mean = alpha / (alpha + beta)
        let variance = (alpha * beta) / ((alpha + beta) * (alpha + beta) * (alpha + beta + 1))
        let stdDev = sqrt(variance)

        let z = sqrt(-2 * log(x)) * cos(2 * Double.pi * y)
        return max(0, min(1, mean + z * stdDev))
    }
}

// MARK: - Learning Rate Configuration

/// Configuration for adaptive learning rates
public struct LearningRateConfig: Sendable {
    public var current: Double
    public var minimum: Double
    public var maximum: Double
    public var decayFactor: Double
    public var growthFactor: Double
    public var stabilityThreshold: Int

    public static let `default` = LearningRateConfig(
        current: 0.1,
        minimum: 0.001,
        maximum: 0.5,
        decayFactor: 0.95,
        growthFactor: 1.1,
        stabilityThreshold: 10
    )

    public init(
        current: Double,
        minimum: Double,
        maximum: Double,
        decayFactor: Double,
        growthFactor: Double,
        stabilityThreshold: Int
    ) {
        self.current = current
        self.minimum = minimum
        self.maximum = maximum
        self.decayFactor = decayFactor
        self.growthFactor = growthFactor
        self.stabilityThreshold = stabilityThreshold
    }

    public mutating func decay() {
        current = max(minimum, current * decayFactor)
    }

    public mutating func grow() {
        current = min(maximum, current * growthFactor)
    }
}

// MARK: - Rollback Checkpoint

/// Checkpoint for potential rollback
public struct MetaCheckpoint: Sendable {
    public let timestamp: Date
    public let strategy: OptimizationStrategy
    public let learningRate: Double
    public let performanceMetrics: [String: Double]
    public let hyperparameterSnapshot: [String: Double]

    public init(
        timestamp: Date,
        strategy: OptimizationStrategy,
        learningRate: Double,
        performanceMetrics: [String: Double],
        hyperparameterSnapshot: [String: Double]
    ) {
        self.timestamp = timestamp
        self.strategy = strategy
        self.learningRate = learningRate
        self.performanceMetrics = performanceMetrics
        self.hyperparameterSnapshot = hyperparameterSnapshot
    }
}

// MARK: - Meta Decision

/// Decision made by the meta-learning controller
public struct MetaDecision: Sendable {
    public let action: MetaAction
    public let reason: String
    public let confidence: Double
    public let timestamp: Date

    public init(action: MetaAction, reason: String, confidence: Double) {
        self.action = action
        self.reason = reason
        self.confidence = confidence
        self.timestamp = Date()
    }
}

/// Actions the meta-controller can take
public enum MetaAction: Sendable {
    case continueCurrentStrategy
    case switchStrategy(to: OptimizationStrategy)
    case adjustLearningRate(factor: Double)
    case increaseExploration
    case decreaseExploration
    case rollbackToCheckpoint(MetaCheckpoint)
    case createCheckpoint
    case pauseOptimization(duration: TimeInterval)
    case resumeOptimization
}

// MARK: - Performance Window

/// Rolling window of performance metrics
public struct PerformanceWindow: Sendable {
    public var entries: [(timestamp: Date, value: Double)] = []
    public let maxSize: Int

    public init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }

    public mutating func add(_ value: Double) {
        entries.append((Date(), value))
        if entries.count > maxSize {
            entries.removeFirst(entries.count - maxSize)
        }
    }

    public var average: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map { $0.value }.reduce(0, +) / Double(entries.count)
    }

    public var trend: Double {
        guard entries.count >= 3 else { return 0 }

        let values = entries.map { $0.value }
        let n = Double(values.count)
        let sumX = (0..<values.count).reduce(0.0) { $0 + Double($1) }
        let sumY = values.reduce(0, +)
        let sumXY = values.enumerated().reduce(0.0) { $0 + Double($1.offset) * $1.element }
        let sumX2 = (0..<values.count).reduce(0.0) { $0 + Double($1 * $1) }

        return (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
    }

    public var variance: Double {
        guard entries.count > 1 else { return 0 }
        let mean = average
        let sumSquaredDiffs = entries.map { ($0.value - mean) * ($0.value - mean) }.reduce(0, +)
        return sumSquaredDiffs / Double(entries.count - 1)
    }

    public var recentAverage: Double {
        let recent = entries.suffix(10)
        guard !recent.isEmpty else { return 0 }
        return recent.map { $0.value }.reduce(0, +) / Double(recent.count)
    }
}

// MARK: - Meta-Learning Controller

/// The optimizer that optimizes itself
public actor MetaLearningController {

    // MARK: - Properties

    /// Current active strategy
    private var currentStrategy: OptimizationStrategy = .thompsonSampling

    /// Performance tracking for each strategy
    private var strategyPerformance: [OptimizationStrategy: StrategyPerformance]

    /// Adaptive learning rate
    private var learningRate: LearningRateConfig = .default

    /// Exploration rate (0 = exploit, 1 = explore)
    private var explorationRate: Double = 0.3

    /// Performance tracking
    private var performanceWindow = PerformanceWindow()

    /// Checkpoints for rollback
    private var checkpoints: [MetaCheckpoint] = []
    private let maxCheckpoints = 10

    /// Decision history
    private var decisionHistory: [MetaDecision] = []
    private let maxDecisionHistory = 100

    /// State tracking
    private var consecutiveDeclines: Int = 0
    private var stablePeriodsCount: Int = 0
    private var isPaused: Bool = false
    private var pauseEndTime: Date?

    /// Baseline performance for comparison
    private var baselinePerformance: Double = 0.5

    // MARK: - Initialization

    public init() {
        var performance: [OptimizationStrategy: StrategyPerformance] = [:]
        for strategy in OptimizationStrategy.allCases {
            performance[strategy] = StrategyPerformance(strategy: strategy)
        }
        self.strategyPerformance = performance
    }

    // MARK: - Strategy Management

    /// Get the current optimization strategy
    public func currentOptimizationStrategy() -> OptimizationStrategy {
        currentStrategy
    }

    /// Get current learning rate
    public func currentLearningRate() -> Double {
        learningRate.current
    }

    /// Get current exploration rate
    public func currentExplorationRate() -> Double {
        explorationRate
    }

    /// Record outcome of an optimization attempt
    // periphery:ignore - Reserved: metrics parameter kept for API compatibility
    public func recordOutcome(success: Bool, reward: Double, metrics: [String: Double] = [:]) {
        // Update strategy performance
        if success {
            strategyPerformance[currentStrategy]?.recordSuccess(reward: reward)
        } else {
            strategyPerformance[currentStrategy]?.recordFailure()
        }

        // Track overall performance
        performanceWindow.add(reward)

        // Check for consecutive declines
        if reward < baselinePerformance * 0.9 {
            consecutiveDeclines += 1
        } else {
            consecutiveDeclines = 0
            // Update baseline with EMA
            baselinePerformance = baselinePerformance * 0.9 + reward * 0.1
        }

        // Check for stability
        if abs(performanceWindow.trend) < 0.01 && performanceWindow.variance < 0.05 {
            stablePeriodsCount += 1
        } else {
            stablePeriodsCount = 0
        }
    }

    /// Evaluate and potentially adjust strategy
    public func evaluate() -> MetaDecision {
        // Check if paused
        if isPaused {
            if let endTime = pauseEndTime, Date() >= endTime {
                isPaused = false
                pauseEndTime = nil
                let decision = MetaDecision(
                    action: .resumeOptimization,
                    reason: "Pause period ended",
                    confidence: 1.0
                )
                recordDecision(decision)
                return decision
            }
            return MetaDecision(
                action: .continueCurrentStrategy,
                reason: "Optimization paused",
                confidence: 1.0
            )
        }

        // Check for degradation requiring rollback
        if consecutiveDeclines >= 5 && !checkpoints.isEmpty {
            if let checkpoint = findBestCheckpoint() {
                let decision = MetaDecision(
                    action: .rollbackToCheckpoint(checkpoint),
                    reason: "Performance degradation detected, rolling back to stable state",
                    confidence: 0.8
                )
                recordDecision(decision)
                return decision
            }
        }

        // Check if current strategy is underperforming
        let currentPerf = strategyPerformance[currentStrategy]?.successRate ?? 0.5
        let bestStrategy = findBestStrategy()

        if currentPerf < 0.3 && consecutiveDeclines >= 3 {
            // Current strategy failing - switch
            let decision = MetaDecision(
                action: .switchStrategy(to: bestStrategy),
                reason: "Current strategy underperforming (success rate: \(String(format: "%.1f%%", currentPerf * 100)))",
                confidence: 0.7
            )
            recordDecision(decision)
            return decision
        }

        // Check exploration/exploitation balance
        if stablePeriodsCount >= learningRate.stabilityThreshold {
            // System stable - can exploit more
            if explorationRate > 0.1 {
                let decision = MetaDecision(
                    action: .decreaseExploration,
                    reason: "System stable, decreasing exploration",
                    confidence: 0.6
                )
                recordDecision(decision)
                return decision
            }
        } else if performanceWindow.variance > 0.2 {
            // High variance - explore more
            if explorationRate < 0.5 {
                let decision = MetaDecision(
                    action: .increaseExploration,
                    reason: "High variance detected, increasing exploration",
                    confidence: 0.6
                )
                recordDecision(decision)
                return decision
            }
        }

        // Adjust learning rate based on trend
        if performanceWindow.trend > 0.05 {
            // Improving - can use higher learning rate
            let decision = MetaDecision(
                action: .adjustLearningRate(factor: learningRate.growthFactor),
                reason: "Performance improving, increasing learning rate",
                confidence: 0.5
            )
            recordDecision(decision)
            return decision
        } else if performanceWindow.trend < -0.05 {
            // Degrading - reduce learning rate
            let decision = MetaDecision(
                action: .adjustLearningRate(factor: learningRate.decayFactor),
                reason: "Performance degrading, decreasing learning rate",
                confidence: 0.5
            )
            recordDecision(decision)
            return decision
        }

        // Check if checkpoint should be created
        if shouldCreateCheckpoint() {
            let decision = MetaDecision(
                action: .createCheckpoint,
                reason: "Good performance state, creating checkpoint",
                confidence: 0.6
            )
            recordDecision(decision)
            return decision
        }

        // Default: continue
        let decision = MetaDecision(
            action: .continueCurrentStrategy,
            reason: "No changes needed",
            confidence: 0.8
        )
        recordDecision(decision)
        return decision
    }

    /// Apply a meta decision
    public func applyDecision(_ decision: MetaDecision) {
        switch decision.action {
        case .continueCurrentStrategy:
            break

        case .switchStrategy(let newStrategy):
            currentStrategy = newStrategy

        case .adjustLearningRate(let factor):
            if factor > 1 {
                learningRate.grow()
            } else {
                learningRate.decay()
            }

        case .increaseExploration:
            explorationRate = min(0.8, explorationRate + 0.1)

        case .decreaseExploration:
            explorationRate = max(0.05, explorationRate - 0.1)

        case .rollbackToCheckpoint(let checkpoint):
            restoreCheckpoint(checkpoint)

        case .createCheckpoint:
            createCheckpoint(hyperparameters: [:])

        case .pauseOptimization(let duration):
            isPaused = true
            pauseEndTime = Date().addingTimeInterval(duration)

        case .resumeOptimization:
            isPaused = false
            pauseEndTime = nil
        }
    }

    // MARK: - Checkpoint Management

    /// Create a checkpoint with current state
    public func createCheckpoint(hyperparameters: [String: Double]) {
        let checkpoint = MetaCheckpoint(
            timestamp: Date(),
            strategy: currentStrategy,
            learningRate: learningRate.current,
            performanceMetrics: [
                "average": performanceWindow.average,
                "recentAverage": performanceWindow.recentAverage,
                "variance": performanceWindow.variance,
                "trend": performanceWindow.trend,
                "explorationRate": explorationRate
            ],
            hyperparameterSnapshot: hyperparameters
        )

        checkpoints.append(checkpoint)
        if checkpoints.count > maxCheckpoints {
            // Keep best checkpoints, not just oldest
            checkpoints.sort { ($0.performanceMetrics["average"] ?? 0) > ($1.performanceMetrics["average"] ?? 0) }
            checkpoints = Array(checkpoints.prefix(maxCheckpoints))
        }
    }

    /// Get hyperparameters from latest checkpoint
    public func latestCheckpointHyperparameters() -> [String: Double]? {
        checkpoints.last?.hyperparameterSnapshot
    }

    // MARK: - Statistics

    /// Get strategy performance statistics
    public func strategyStats() -> [OptimizationStrategy: [String: Any]] {
        var stats: [OptimizationStrategy: [String: Any]] = [:]
        for (strategy, perf) in strategyPerformance {
            stats[strategy] = [
                "successRate": perf.successRate,
                "totalAttempts": perf.totalAttempts,
                "averageImprovement": perf.averageImprovement,
                "consecutiveFailures": perf.consecutiveFailures
            ]
        }
        return stats
    }

    /// Get overall meta-learning statistics
    public func statistics() -> [String: Any] {
        [
            "currentStrategy": currentStrategy.rawValue,
            "learningRate": learningRate.current,
            "explorationRate": explorationRate,
            "performanceAverage": performanceWindow.average,
            "performanceTrend": performanceWindow.trend,
            "performanceVariance": performanceWindow.variance,
            "consecutiveDeclines": consecutiveDeclines,
            "stablePeriods": stablePeriodsCount,
            "checkpointCount": checkpoints.count,
            "decisionCount": decisionHistory.count,
            "isPaused": isPaused
        ]
    }

    /// Get recent decisions
    public func recentDecisions(count: Int = 10) -> [MetaDecision] {
        Array(decisionHistory.suffix(count))
    }

    // MARK: - Private Helpers

    private func findBestStrategy() -> OptimizationStrategy {
        // Use Thompson Sampling to select strategy
        var bestSample = -Double.infinity
        var bestStrategy = currentStrategy

        for (strategy, perf) in strategyPerformance {
            let sample = perf.sample()
            if sample > bestSample {
                bestSample = sample
                bestStrategy = strategy
            }
        }

        return bestStrategy
    }

    private func findBestCheckpoint() -> MetaCheckpoint? {
        checkpoints.max { ($0.performanceMetrics["average"] ?? 0) < ($1.performanceMetrics["average"] ?? 0) }
    }

    private func restoreCheckpoint(_ checkpoint: MetaCheckpoint) {
        currentStrategy = checkpoint.strategy
        learningRate.current = checkpoint.learningRate
        explorationRate = checkpoint.performanceMetrics["explorationRate"] ?? 0.3
        consecutiveDeclines = 0
        stablePeriodsCount = 0
    }

    private func shouldCreateCheckpoint() -> Bool {
        // Create checkpoint if:
        // 1. Performance is good (above baseline)
        // 2. System is stable
        // 3. Haven't created one recently

        guard performanceWindow.recentAverage > baselinePerformance else { return false }
        guard stablePeriodsCount >= 5 else { return false }

        if let lastCheckpoint = checkpoints.last {
            let timeSinceLastCheckpoint = Date().timeIntervalSince(lastCheckpoint.timestamp)
            guard timeSinceLastCheckpoint > 300 else { return false } // At least 5 minutes
        }

        return true
    }

    private func recordDecision(_ decision: MetaDecision) {
        decisionHistory.append(decision)
        if decisionHistory.count > maxDecisionHistory {
            decisionHistory.removeFirst(decisionHistory.count - maxDecisionHistory)
        }
    }

    // MARK: - Configuration

    /// Update learning rate configuration
    public func configureLearningRate(_ config: LearningRateConfig) {
        learningRate = config
    }

    /// Set exploration rate directly
    public func setExplorationRate(_ rate: Double) {
        explorationRate = max(0.01, min(1.0, rate))
    }

    /// Force switch to a specific strategy
    public func forceStrategy(_ strategy: OptimizationStrategy) {
        currentStrategy = strategy
    }

    // MARK: - Persistence

    /// Export state for persistence
    public func exportState() -> [String: Any] {
        var strategyData: [[String: Any]] = []
        for (strategy, perf) in strategyPerformance {
            strategyData.append([
                "strategy": strategy.rawValue,
                "successCount": perf.successCount,
                "failureCount": perf.failureCount,
                "totalReward": perf.totalReward,
                "averageImprovement": perf.averageImprovement,
                "alpha": perf.alpha,
                "beta": perf.beta
            ])
        }

        return [
            "currentStrategy": currentStrategy.rawValue,
            "learningRate": learningRate.current,
            "explorationRate": explorationRate,
            "baselinePerformance": baselinePerformance,
            "strategyPerformance": strategyData
        ]
    }

    /// Import state from persistence
    public func importState(_ state: [String: Any]) {
        if let strategyRaw = state["currentStrategy"] as? String,
           let strategy = OptimizationStrategy(rawValue: strategyRaw) {
            currentStrategy = strategy
        }

        if let rate = state["learningRate"] as? Double {
            learningRate.current = rate
        }

        if let exploration = state["explorationRate"] as? Double {
            explorationRate = exploration
        }

        if let baseline = state["baselinePerformance"] as? Double {
            baselinePerformance = baseline
        }

        if let strategyData = state["strategyPerformance"] as? [[String: Any]] {
            for data in strategyData {
                guard let strategyRaw = data["strategy"] as? String,
                      let strategy = OptimizationStrategy(rawValue: strategyRaw) else {
                    continue
                }

                var perf = StrategyPerformance(strategy: strategy)
                perf.successCount = data["successCount"] as? Int ?? 0
                perf.failureCount = data["failureCount"] as? Int ?? 0
                perf.totalReward = data["totalReward"] as? Double ?? 0
                perf.averageImprovement = data["averageImprovement"] as? Double ?? 0
                perf.alpha = data["alpha"] as? Double ?? 1.0
                perf.beta = data["beta"] as? Double ?? 1.0

                strategyPerformance[strategy] = perf
            }
        }
    }
}
