//
//  ModelQualityBenchmark.swift
//  Thea
//
//  Tracks model quality over time using Exponential Moving Average (EMA)
//  Provides quality scores for model selection and evolution decisions
//
//  METRICS TRACKED:
//  - Success rate per task type
//  - Response latency
//  - User satisfaction (when available)
//  - Token throughput
//  - Error rates
//
//  CREATED: February 5, 2026
//

import Foundation
import OSLog

// MARK: - Model Quality Benchmark

// @unchecked Sendable: mutable state (modelMetrics dictionary) is accessed exclusively from
// a single owner on a serial queue; emaAlpha and thresholds are immutable after init
/// Tracks and analyzes model quality over time
final class ModelQualityBenchmark: @unchecked Sendable {
    private let logger = Logger(subsystem: "ai.thea.app", category: "ModelQualityBenchmark")

    // MARK: - State

    /// Quality metrics per model
    private var modelMetrics: [String: ModelQualityMetrics] = [:]

    /// EMA alpha for quality score updates (0.1 = slow adaptation, 0.3 = faster)
    // periphery:ignore - Reserved: emaAlpha property — reserved for future feature activation
    private let emaAlpha: Double = 0.2

    /// Minimum samples before quality score is considered reliable
    private let minSamplesForReliability = 5

    /// Persistence key
    private let metricsKey = "ModelQualityBenchmark.metrics"

    // MARK: - Initialization

    init() {
        loadPersistedState()
    }

    // MARK: - Recording

    /// Record quality observation for a model
    // periphery:ignore - Reserved: recordQuality(modelName:taskType:success:latency:userSatisfaction:tokensGenerated:) instance method — reserved for future feature activation
    func recordQuality(
        modelName: String,
        // periphery:ignore - Reserved: emaAlpha property reserved for future feature activation
        taskType: TaskType,
        success: Bool,
        latency: TimeInterval,
        userSatisfaction: Double? = nil,
        tokensGenerated: Int? = nil
    ) {
        // Initialize metrics if needed
        if modelMetrics[modelName] == nil {
            modelMetrics[modelName] = ModelQualityMetrics(modelName: modelName)
        }

        guard var metrics = modelMetrics[modelName] else { return }

        // Update overall metrics with EMA
        let successValue: Double = success ? 1.0 : 0.0

        // periphery:ignore - Reserved: recordQuality(modelName:taskType:success:latency:userSatisfaction:tokensGenerated:) instance method reserved for future feature activation
        if metrics.sampleCount == 0 {
            // First sample - initialize directly
            metrics.overallSuccessRate = successValue
            metrics.averageLatency = latency
            if let satisfaction = userSatisfaction {
                metrics.userSatisfactionScore = satisfaction
            }
        } else {
            // Apply EMA update
            metrics.overallSuccessRate = emaUpdate(
                current: metrics.overallSuccessRate,
                newValue: successValue
            )
            metrics.averageLatency = emaUpdate(
                current: metrics.averageLatency,
                newValue: latency
            )
            if let satisfaction = userSatisfaction {
                metrics.userSatisfactionScore = emaUpdate(
                    current: metrics.userSatisfactionScore ?? 0.5,
                    newValue: satisfaction
                )
            }
        }

        // Update per-task metrics
        if metrics.taskMetrics[taskType] == nil {
            metrics.taskMetrics[taskType] = TaskQualityMetrics()
        }
        metrics.taskMetrics[taskType]?.record(
            success: success,
            latency: latency,
            satisfaction: userSatisfaction,
            emaAlpha: emaAlpha
        )

        // Update token throughput if available
        if let tokens = tokensGenerated, latency > 0 {
            let tokensPerSecond = Double(tokens) / latency
            metrics.tokenThroughput = emaUpdate(
                current: metrics.tokenThroughput ?? tokensPerSecond,
                newValue: tokensPerSecond
            )
        }

        // Update timestamps and counts
        metrics.sampleCount += 1
        metrics.lastUpdated = Date()

        // Track quality trend
        metrics.updateQualityTrend()

        modelMetrics[modelName] = metrics

        // Persist periodically
        if metrics.sampleCount % 5 == 0 {
            persistState()
        }

        logger.debug("Quality recorded for \(modelName): success=\(success), latency=\(latency)s")
    }

    /// Apply EMA update formula
    // periphery:ignore - Reserved: emaUpdate(current:newValue:) instance method — reserved for future feature activation
    private func emaUpdate(current: Double, newValue: Double) -> Double {
        emaAlpha * newValue + (1 - emaAlpha) * current
    }

    // MARK: - Querying

    /// Get overall quality score for a model (0-1)
    func getQualityScore(for modelName: String) -> Double {
        guard let metrics = modelMetrics[modelName], metrics.sampleCount >= minSamplesForReliability else {
            return 0.5 // Default neutral score for unknown/unreliable models
        }

        return metrics.compositeQualityScore
    }

    /// Get quality score for a specific task type
    // periphery:ignore - Reserved: getTaskQualityScore(for:taskType:) instance method — reserved for future feature activation
    func getTaskQualityScore(for modelName: String, taskType: TaskType) -> Double {
        // periphery:ignore - Reserved: emaUpdate(current:newValue:) instance method reserved for future feature activation
        guard let metrics = modelMetrics[modelName],
              let taskMetrics = metrics.taskMetrics[taskType],
              taskMetrics.sampleCount >= 3 else {
            return 0.5 // Default score
        }

        return taskMetrics.qualityScore
    }

    /// Get quality trend for a model (positive = improving, negative = degrading)
    func getQualityTrend(for modelName: String) -> Double {
        guard let metrics = modelMetrics[modelName] else {
            return 0.0
        }
        return metrics.qualityTrend
    // periphery:ignore - Reserved: getTaskQualityScore(for:taskType:) instance method reserved for future feature activation
    }

    /// Get detailed metrics for a model
    // periphery:ignore - Reserved: getDetailedMetrics(for:) instance method — reserved for future feature activation
    func getDetailedMetrics(for modelName: String) -> ModelQualityMetrics? {
        modelMetrics[modelName]
    }

    /// Get all models sorted by quality
    // periphery:ignore - Reserved: getModelsByQuality() instance method — reserved for future feature activation
    func getModelsByQuality() -> [(name: String, score: Double)] {
        modelMetrics.map { (name: $0.key, score: $0.value.compositeQualityScore) }
            .sorted { $0.score > $1.score }
    }

    /// Get best model for a specific task type
    // periphery:ignore - Reserved: getBestModelForTask(_:) instance method — reserved for future feature activation
    func getBestModelForTask(_ taskType: TaskType) -> String? {
        var bestModel: String?
        var bestScore: Double = 0

        // periphery:ignore - Reserved: getDetailedMetrics(for:) instance method reserved for future feature activation
        for (modelName, metrics) in modelMetrics {
            if let taskMetrics = metrics.taskMetrics[taskType],
               taskMetrics.sampleCount >= 3,
               taskMetrics.qualityScore > bestScore {
                // periphery:ignore - Reserved: getModelsByQuality() instance method reserved for future feature activation
                bestScore = taskMetrics.qualityScore
                bestModel = modelName
            }
        }

        // periphery:ignore - Reserved: getBestModelForTask(_:) instance method reserved for future feature activation
        return bestModel
    }

    // MARK: - Comparison

    /// Compare quality between two models
    // periphery:ignore - Reserved: compareModels(_:_:) instance method — reserved for future feature activation
    func compareModels(_ model1: String, _ model2: String) -> ModelComparison {
        let metrics1 = modelMetrics[model1]
        let metrics2 = modelMetrics[model2]

        let score1 = metrics1?.compositeQualityScore ?? 0.5
        let score2 = metrics2?.compositeQualityScore ?? 0.5

        let difference = score1 - score2
        let winner: String?

        if abs(difference) < 0.05 {
            winner = nil // Too close to call
        // periphery:ignore - Reserved: compareModels(_:_:) instance method reserved for future feature activation
        } else {
            winner = difference > 0 ? model1 : model2
        }

        return ModelComparison(
            model1: model1,
            model2: model2,
            score1: score1,
            score2: score2,
            difference: abs(difference),
            winner: winner,
            metrics1: metrics1,
            metrics2: metrics2
        )
    }

    // MARK: - Reliability

    /// Check if we have enough data for reliable quality assessment
    // periphery:ignore - Reserved: isQualityReliable(for:) instance method — reserved for future feature activation
    func isQualityReliable(for modelName: String) -> Bool {
        guard let metrics = modelMetrics[modelName] else { return false }
        return metrics.sampleCount >= minSamplesForReliability
    }

    /// Get confidence level for quality score (0-1)
    // periphery:ignore - Reserved: getConfidenceLevel(for:) instance method — reserved for future feature activation
    func getConfidenceLevel(for modelName: String) -> Double {
        guard let metrics = modelMetrics[modelName] else { return 0.0 }

        // Confidence increases with sample count, capped at 100 samples
        let sampleConfidence = min(1.0, Double(metrics.sampleCount) / 100.0)

// periphery:ignore - Reserved: isQualityReliable(for:) instance method reserved for future feature activation

        // Confidence also depends on recency of data
        let daysSinceUpdate = Date().timeIntervalSince(metrics.lastUpdated) / (24 * 3600)
        let recencyConfidence = max(0.0, 1.0 - (daysSinceUpdate / 30.0)) // Decays over 30 days

        // periphery:ignore - Reserved: getConfidenceLevel(for:) instance method reserved for future feature activation
        return (sampleConfidence * 0.7) + (recencyConfidence * 0.3)
    }

    // MARK: - Benchmarking

    /// Run a comparison benchmark between installed models (for a task type)
    // periphery:ignore - Reserved: benchmarkReport(for:) instance method — reserved for future feature activation
    func benchmarkReport(for taskType: TaskType) -> BenchmarkReport {
        var entries: [BenchmarkEntry] = []

        for (modelName, metrics) in modelMetrics {
            let taskScore = metrics.taskMetrics[taskType]?.qualityScore ?? 0.5
            let overallScore = metrics.compositeQualityScore
            let latency = metrics.taskMetrics[taskType]?.averageLatency ?? metrics.averageLatency

            entries.append(BenchmarkEntry(
                // periphery:ignore - Reserved: benchmarkReport(for:) instance method reserved for future feature activation
                modelName: modelName,
                taskScore: taskScore,
                overallScore: overallScore,
                averageLatency: latency,
                sampleCount: metrics.taskMetrics[taskType]?.sampleCount ?? 0,
                isReliable: (metrics.taskMetrics[taskType]?.sampleCount ?? 0) >= 3
            ))
        }

        entries.sort { $0.taskScore > $1.taskScore }

        return BenchmarkReport(
            taskType: taskType,
            entries: entries,
            generatedAt: Date()
        )
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        if let data = UserDefaults.standard.data(forKey: metricsKey) {
            do {
                let decoded = try JSONDecoder().decode([String: ModelQualityMetrics].self, from: data)
                modelMetrics = decoded
                logger.debug("Loaded quality metrics for \(decoded.count) models")
            } catch {
                logger.error("Failed to decode ModelQualityMetrics: \(error.localizedDescription)")
            }
        }
    }

    private func persistState() {
        do {
            let data = try JSONEncoder().encode(modelMetrics)
            UserDefaults.standard.set(data, forKey: metricsKey)
        } catch {
            logger.error("Failed to encode ModelQualityMetrics: \(error.localizedDescription)")
        }
    }

// periphery:ignore - Reserved: persistState() instance method reserved for future feature activation

    /// Clear all quality data
    func reset() {
        modelMetrics.removeAll()
        persistState()
        logger.info("Quality benchmark data reset")
    }
}

// periphery:ignore - Reserved: reset() instance method reserved for future feature activation
// MARK: - Model Quality Metrics

/// Quality metrics for a single model
struct ModelQualityMetrics: Codable, Sendable {
    let modelName: String

    // Overall metrics (EMA)
    var overallSuccessRate: Double = 0.5
    var averageLatency: TimeInterval = 0.0
    var userSatisfactionScore: Double?
    var tokenThroughput: Double?

    // Per-task metrics
    var taskMetrics: [TaskType: TaskQualityMetrics] = [:]

    // Meta
    var sampleCount: Int = 0
    var lastUpdated = Date()

    // Quality trend tracking
    var qualityHistory: [Double] = []
    var qualityTrend: Double = 0.0

    /// Composite quality score (0-1)
    var compositeQualityScore: Double {
        // Weight factors
        let successWeight = 0.4
        let latencyWeight = 0.2
        let satisfactionWeight = 0.3
        let throughputWeight = 0.1

        var score = overallSuccessRate * successWeight

        // Latency score (lower is better, normalize to 0-1 with 5s as baseline)
        let latencyScore = max(0, 1.0 - (averageLatency / 5.0))
        score += latencyScore * latencyWeight

        // User satisfaction (if available)
        if let satisfaction = userSatisfactionScore {
            score += satisfaction * satisfactionWeight
        } else {
            // Redistribute weight if no satisfaction data
            score += overallSuccessRate * satisfactionWeight
        }

        // Throughput score (normalized with 50 t/s as baseline)
        if let throughput = tokenThroughput {
            let throughputScore = min(1.0, throughput / 50.0)
            score += throughputScore * throughputWeight
        } else {
            score += 0.5 * throughputWeight
        }

        return min(1.0, max(0.0, score))
    }

    /// Update quality trend based on recent scores
    mutating func updateQualityTrend() {
        let currentScore = compositeQualityScore
        qualityHistory.append(currentScore)

        // Keep last 20 scores
        if qualityHistory.count > 20 {
            // periphery:ignore - Reserved: updateQualityTrend() instance method reserved for future feature activation
            qualityHistory.removeFirst(qualityHistory.count - 20)
        }

        // Calculate trend (simple linear regression slope)
        guard qualityHistory.count >= 5 else {
            qualityTrend = 0.0
            return
        }

        let n = Double(qualityHistory.count)
        let indices = (0..<qualityHistory.count).map(Double.init)

        let sumX = indices.reduce(0, +)
        let sumY = qualityHistory.reduce(0, +)
        let sumXY = zip(indices, qualityHistory).map(*).reduce(0, +)
        let sumX2 = indices.map { $0 * $0 }.reduce(0, +)

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        qualityTrend = slope * 10 // Scale for visibility
    }
}

/// Quality metrics for a specific task type
struct TaskQualityMetrics: Codable, Sendable {
    var successRate: Double = 0.5
    var averageLatency: TimeInterval = 0.0
    var userSatisfaction: Double?
    var sampleCount: Int = 0

    var qualityScore: Double {
        let latencyScore = max(0, 1.0 - (averageLatency / 5.0))
        var score = (successRate * 0.5) + (latencyScore * 0.3)

        if let satisfaction = userSatisfaction {
            score += satisfaction * 0.2
        } else {
            score += successRate * 0.2
        }

        return min(1.0, max(0.0, score))
    }

    // periphery:ignore - Reserved: record(success:latency:satisfaction:emaAlpha:) instance method — reserved for future feature activation
    mutating func record(
        success: Bool,
        latency: TimeInterval,
        satisfaction: Double?,
        emaAlpha: Double
    // periphery:ignore - Reserved: record(success:latency:satisfaction:emaAlpha:) instance method reserved for future feature activation
    ) {
        let successValue: Double = success ? 1.0 : 0.0

        if sampleCount == 0 {
            successRate = successValue
            averageLatency = latency
            userSatisfaction = satisfaction
        } else {
            successRate = emaAlpha * successValue + (1 - emaAlpha) * successRate
            averageLatency = emaAlpha * latency + (1 - emaAlpha) * averageLatency
            if let s = satisfaction {
                userSatisfaction = emaAlpha * s + (1 - emaAlpha) * (userSatisfaction ?? 0.5)
            }
        }

        sampleCount += 1
    }
}

// MARK: - Comparison Types

/// Comparison result between two models
// periphery:ignore - Reserved: ModelComparison type — reserved for future feature activation
struct ModelComparison: Sendable {
    let model1: String
    let model2: String
    let score1: Double
    // periphery:ignore - Reserved: ModelComparison type reserved for future feature activation
    let score2: Double
    let difference: Double
    let winner: String?
    let metrics1: ModelQualityMetrics?
    let metrics2: ModelQualityMetrics?

    var summary: String {
        if let winner = winner {
            return "\(winner) is better by \(Int(difference * 100))%"
        }
        return "Models are roughly equivalent"
    }
}

/// Benchmark report for a task type
// periphery:ignore - Reserved: BenchmarkReport type — reserved for future feature activation
struct BenchmarkReport: Sendable {
    let taskType: TaskType
    let entries: [BenchmarkEntry]
    // periphery:ignore - Reserved: BenchmarkReport type reserved for future feature activation
    let generatedAt: Date

    var bestModel: String? {
        entries.first { $0.isReliable }?.modelName
    }
}

/// Individual benchmark entry
struct BenchmarkEntry: Sendable {
    let modelName: String
    let taskScore: Double
    // periphery:ignore - Reserved: overallScore property — reserved for future feature activation
    let overallScore: Double
    let averageLatency: TimeInterval
    // periphery:ignore - Reserved: overallScore property reserved for future feature activation
    let sampleCount: Int
    // periphery:ignore - Reserved: sampleCount property reserved for future feature activation
    let isReliable: Bool

    // periphery:ignore - Reserved: formattedLatency property reserved for future feature activation
    var formattedLatency: String {
        String(format: "%.2fs", averageLatency)
    }
}
