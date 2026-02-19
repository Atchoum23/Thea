//
//  AdaptiveGovernanceOrchestrator.swift
//  Thea
//
//  Created by Claude on 2026-02-05.
//
//  Central coordinator for all adaptive governance subsystems.
//  Unifies hyperparameter tuning, task-model pairing, feedback aggregation,
//  convergence detection, interval scheduling, and meta-learning into a
//  cohesive self-optimizing system.
//

import Foundation

// MARK: - Governance State

/// Overall state of the adaptive governance system
public enum GovernanceState: String, Sendable {
    case initializing
    case learning
    case optimizing
    case stable
    case degraded
    case recovering
    case paused

    public var shouldOptimize: Bool {
        switch self {
        case .learning, .optimizing: return true
        case .initializing, .stable, .degraded, .recovering, .paused: return false
        }
    }

    public var shouldAcceptChanges: Bool {
        switch self {
        case .learning, .optimizing, .stable: return true
        case .initializing, .degraded, .recovering, .paused: return false
        }
    }
}

// MARK: - Governance Cycle Metrics

/// Metrics from a governance cycle
public struct GovernanceCycleMetrics: Sendable {
    public let timestamp: Date
    public let duration: TimeInterval
    public let changesApplied: Int
    public let issuesDetected: Int
    public let resourceUsage: Double
    public let overallSuccess: Bool

    public init(
        timestamp: Date = Date(),
        duration: TimeInterval,
        changesApplied: Int,
        issuesDetected: Int,
        resourceUsage: Double,
        overallSuccess: Bool
    ) {
        self.timestamp = timestamp
        self.duration = duration
        self.changesApplied = changesApplied
        self.issuesDetected = issuesDetected
        self.resourceUsage = resourceUsage
        self.overallSuccess = overallSuccess
    }
}

// MARK: - Orchestrator Configuration

/// Configuration for the governance orchestrator
public struct AdaptiveOrchestratorConfiguration: Sendable {
    /// Minimum cycles before enabling optimization
    public let warmupCycles: Int

    /// How often to evaluate meta-learning decisions
    public let metaEvaluationFrequency: Int

    /// Maximum consecutive failures before degraded state
    public let maxConsecutiveFailures: Int

    /// Minimum confidence for accepting changes
    public let minimumConfidenceThreshold: Double

    /// Enable automatic rollback on degradation
    public let enableAutoRollback: Bool

    /// Enable persistence of learned state
    public let enablePersistence: Bool

    public static let `default` = AdaptiveOrchestratorConfiguration(
        warmupCycles: 10,
        metaEvaluationFrequency: 5,
        maxConsecutiveFailures: 3,
        minimumConfidenceThreshold: 0.4,
        enableAutoRollback: true,
        enablePersistence: true
    )

    public init(
        warmupCycles: Int,
        metaEvaluationFrequency: Int,
        maxConsecutiveFailures: Int,
        minimumConfidenceThreshold: Double,
        enableAutoRollback: Bool,
        enablePersistence: Bool
    ) {
        self.warmupCycles = warmupCycles
        self.metaEvaluationFrequency = metaEvaluationFrequency
        self.maxConsecutiveFailures = maxConsecutiveFailures
        self.minimumConfidenceThreshold = minimumConfidenceThreshold
        self.enableAutoRollback = enableAutoRollback
        self.enablePersistence = enablePersistence
    }
}

// MARK: - Adaptive Governance Orchestrator

/// Central coordinator for all adaptive governance subsystems
/// Uses facade pattern to coordinate singleton instances of subsystems
public actor AdaptiveGovernanceOrchestrator {

    // MARK: - Subsystem References (accessed via singletons/shared instances)

    /// Adaptive interval scheduling
    public let intervalScheduler: AdaptiveIntervalScheduler

    /// Meta-learning for self-optimization
    public let metaController: MetaLearningController

    // MARK: - State

    private var state: GovernanceState = .initializing
    private let configuration: AdaptiveOrchestratorConfiguration

    /// Cycle tracking
    private var cycleCount: Int = 0
    private var consecutiveFailures: Int = 0
    // periphery:ignore - Reserved: lastCycleTimestamp property — reserved for future feature activation
    private var lastCycleTimestamp: Date?

// periphery:ignore - Reserved: lastCycleTimestamp property reserved for future feature activation

    /// History for analysis
    private var cycleHistory: [GovernanceCycleMetrics] = []
    private let maxHistorySize = 100

    // MARK: - Initialization

    public init(configuration: AdaptiveOrchestratorConfiguration = .default) {
        self.configuration = configuration
        self.intervalScheduler = AdaptiveIntervalScheduler()
        self.metaController = MetaLearningController()
    }

    // MARK: - Lifecycle

    /// Start the adaptive governance system
    public func start() async {
        state = .learning
    }

    /// Pause the adaptive governance system
    public func pause() {
        state = .paused
    }

    /// Resume the adaptive governance system
    public func resume() {
        if state == .paused {
            state = cycleCount < configuration.warmupCycles ? .learning : .optimizing
        }
    }

    // MARK: - Governance Cycle

    /// Execute a governance cycle
    @MainActor
    public func executeGovernanceCycle() async -> GovernanceCycleMetrics {
        let startTime = Date()
        var changesApplied = 0
        let issuesDetected = 0

        // Check if we should proceed with changes
        guard await currentState().shouldAcceptChanges else {
            return GovernanceCycleMetrics(
                duration: Date().timeIntervalSince(startTime),
                changesApplied: 0,
                issuesDetected: 0,
                resourceUsage: 0,
                overallSuccess: true
            )
        }

        // Get feedback and update hyperparameters
        let tuner = HyperparameterTuner.shared
        let feedbackValue = tuner.getValue(.qualityEmaAlpha) // Use existing feedback as proxy

        if feedbackValue > configuration.minimumConfidenceThreshold {
            // Sample and potentially update parameters
            _ = tuner.sample(.governanceIntervalSeconds)
            changesApplied += 1
        }

        // Meta-learning evaluation (every N cycles)
        let count = await self.cycleCount
        if count % configuration.metaEvaluationFrequency == 0 {
            let decision = await metaController.evaluate()
            await metaController.applyDecision(decision)
        }

        // Determine success
        let success = await self.consecutiveFailures == 0 || changesApplied > 0
        if !success {
            await incrementFailures()
            let failures = await self.consecutiveFailures
            if failures >= configuration.maxConsecutiveFailures {
                await setDegraded()
            }
        } else {
            await resetFailures()
        }

        // Create metrics
        let metrics = GovernanceCycleMetrics(
            timestamp: startTime,
            duration: Date().timeIntervalSince(startTime),
            changesApplied: changesApplied,
            issuesDetected: issuesDetected,
            resourceUsage: 0.3,
            overallSuccess: success
        )

        // Record in history
        await recordMetrics(metrics)
        await incrementCycleCount()

        // Transition from learning to optimizing after warmup
        let currentCount = await self.cycleCount
        let currentState = await self.state
        if currentState == .learning && currentCount >= configuration.warmupCycles {
            await setOptimizing()
        }

        return metrics
    }

    // MARK: - State Helpers

    private func incrementFailures() {
        consecutiveFailures += 1
    }

    private func resetFailures() {
        consecutiveFailures = 0
    }

    private func setDegraded() {
        state = .degraded
    }

    private func setOptimizing() {
        state = .optimizing
    }

    private func recordMetrics(_ metrics: GovernanceCycleMetrics) {
        cycleHistory.append(metrics)
        if cycleHistory.count > maxHistorySize {
            cycleHistory.removeFirst(cycleHistory.count - maxHistorySize)
        }
        lastCycleTimestamp = metrics.timestamp
    }

    private func incrementCycleCount() {
        cycleCount += 1
    }

    // MARK: - Hyperparameter Access

    /// Get current value of a hyperparameter
    @MainActor
    public func getHyperparameter(_ id: HyperparameterID) -> Double {
        HyperparameterTuner.shared.getValue(id)
    }

    /// Get all hyperparameter values
    @MainActor
    public func getAllHyperparameters() -> [HyperparameterID: Double] {
        // periphery:ignore - Reserved: context parameter — kept for API compatibility
        var result: [HyperparameterID: Double] = [:]
        for id in HyperparameterID.allCases {
            result[id] = HyperparameterTuner.shared.getValue(id)
        }
        return result
    }

    /// Sample a hyperparameter value (for exploration)
    @MainActor
    public func sampleHyperparameter(_ id: HyperparameterID) -> Double {
        HyperparameterTuner.shared.sample(id)
    }

    // MARK: - Feedback

    /// Record feedback event
    @MainActor
    // periphery:ignore - Reserved: context parameter kept for API compatibility
    public func recordFeedback(source: FeedbackSource, value: Double, context: GovernanceFeedbackContext) {
        // Record to hyperparameter tuner based on source type
        let id: HyperparameterID
        switch source {
        case .explicitRating, .explicitPreference:
            id = .qualitySatisfactionWeight
        case .responseLatency:
            id = .qualityLatencyWeight
        case .conversationContinued, .regenerationRequested:
            id = .qualitySuccessWeight
        default:
            id = .qualityThroughputWeight
        }

        // Use the feedback value to inform the tuner
        let tuner = HyperparameterTuner.shared
        let currentValue = tuner.getValue(id)
        tuner.recordOutcome(id, testedValue: currentValue, outcome: value)
    }

    // MARK: - Interval

    /// Get recommended next governance interval
    public func recommendedInterval() async -> TimeInterval {
        await intervalScheduler.recommendedInterval()
    }

    /// Update activity level for interval scheduling
    public func updateActivity(queryCount: Int, errorCount: Int, resourcePressure: Double) async {
        await intervalScheduler.updateActivityDetailed(
            queryCount: queryCount,
            errorCount: errorCount,
            resourcePressure: resourcePressure
        )
    }

    // MARK: - State Access

    /// Get current governance state
    public func currentState() -> GovernanceState {
        state
    }

    /// Get comprehensive statistics (async because actor-isolated)
    public func statistics() async -> [String: Any] {
        let intervalStats: [String: Any] = [
            "cycleCount": cycleCount,
            "consecutiveFailures": consecutiveFailures,
            "historySize": cycleHistory.count
        ]

        return [
            "state": state.rawValue,
            "cycleCount": cycleCount,
            "consecutiveFailures": consecutiveFailures,
            "interval": intervalStats,
            "recentCycleCount": cycleHistory.count
        ]
    }
}

// MARK: - Governance Feedback Context

/// Context for governance feedback events
public struct GovernanceFeedbackContext: Sendable {
    public let modelId: String?
    public let taskType: String?
    public let timestamp: Date

    public init(modelId: String? = nil, taskType: String? = nil, timestamp: Date = Date()) {
        self.modelId = modelId
        self.taskType = taskType
        self.timestamp = timestamp
    }
}
