// ContextualMultiArmedBandit.swift
// Thea V2 - Contextual Multi-Armed Bandit for Task-Model Optimization
//
// Learns optimal task→model pairings using contextual bandits:
// - Thompson Sampling with context features
// - UCB (Upper Confidence Bound) for exploration guarantees
// - Learns from every interaction
// - Adapts to user behavior patterns
//
// "Absolutely Everything AI-Powered" - No fixed task-model mappings

import Foundation
import os.log

// MARK: - Context Features

/// Features that influence optimal model selection
public struct BanditContext: Hashable, Codable, Sendable {
    /// Task type being performed
    public let taskType: TaskCategory

    /// Time of day cluster (learned, not fixed hours)
    public let timeCluster: TimeCluster

    /// Current resource availability
    public let resourceTier: ResourceTier

    /// Recent task history (enables sequence prediction)
    public let recentTasks: [TaskCategory]

    /// Perceived urgency level
    public let urgency: UrgencyLevel

    /// Query complexity estimate
    public let complexity: BanditComplexityLevel

    public init(
        taskType: TaskCategory,
        timeCluster: TimeCluster = .unknown,
        resourceTier: ResourceTier = .standard,
        recentTasks: [TaskCategory] = [],
        urgency: UrgencyLevel = .normal,
        complexity: BanditComplexityLevel = .moderate
    ) {
        self.taskType = taskType
        self.timeCluster = timeCluster
        self.resourceTier = resourceTier
        self.recentTasks = Array(recentTasks.suffix(3))  // Keep last 3
        self.urgency = urgency
        self.complexity = complexity
    }

    /// Create context from current system state
    public static func current(taskType: TaskCategory, query: String? = nil) -> BanditContext {
        BanditContext(
            taskType: taskType,
            timeCluster: TimeCluster.current,
            resourceTier: ResourceTier.current,
            recentTasks: [],
            urgency: UrgencyLevel.detect(from: query),
            complexity: BanditComplexityLevel.estimate(from: query)
        )
    }
}

// MARK: - Task Categories

public enum TaskCategory: String, CaseIterable, Codable, Sendable {
    case codeGeneration
    case codeExplanation
    case debugging
    case refactoring
    case testing
    case documentation
    case creative
    case analysis
    case research
    case conversation
    case summarization
    case translation
    case math
    case reasoning
    case general

    public static func detect(from query: String) -> TaskCategory {
        let lowered = query.lowercased()

        // Code-related patterns
        if lowered.contains("write") && (lowered.contains("code") || lowered.contains("function") || lowered.contains("class")) {
            return .codeGeneration
        }
        if lowered.contains("explain") && (lowered.contains("code") || lowered.contains("function")) {
            return .codeExplanation
        }
        if lowered.contains("bug") || lowered.contains("fix") || lowered.contains("error") || lowered.contains("debug") {
            return .debugging
        }
        if lowered.contains("refactor") || lowered.contains("improve") || lowered.contains("optimize") {
            return .refactoring
        }
        if lowered.contains("test") || lowered.contains("spec") || lowered.contains("coverage") {
            return .testing
        }
        if lowered.contains("document") || lowered.contains("comment") || lowered.contains("readme") {
            return .documentation
        }

        // Creative patterns
        if lowered.contains("write") && (lowered.contains("story") || lowered.contains("poem") || lowered.contains("creative")) {
            return .creative
        }

        // Analysis patterns
        if lowered.contains("analyze") || lowered.contains("review") || lowered.contains("evaluate") {
            return .analysis
        }

        // Research patterns
        if lowered.contains("research") || lowered.contains("find") || lowered.contains("search") {
            return .research
        }

        // Summarization
        if lowered.contains("summarize") || lowered.contains("summary") || lowered.contains("tldr") {
            return .summarization
        }

        // Translation
        if lowered.contains("translate") || lowered.contains("translation") {
            return .translation
        }

        // Math
        if lowered.contains("calculate") || lowered.contains("math") || lowered.contains("equation") {
            return .math
        }

        // Reasoning
        if lowered.contains("why") || lowered.contains("reason") || lowered.contains("logic") || lowered.contains("think through") {
            return .reasoning
        }

        return .general
    }
}

// MARK: - Time Clusters

/// Learned time-of-day clusters (not fixed 8 periods)
public enum TimeCluster: String, CaseIterable, Codable, Sendable {
    case earlyMorning    // Typically 5-8 AM
    case morning         // Typically 8-12 PM
    case earlyAfternoon  // Typically 12-3 PM
    case lateAfternoon   // Typically 3-6 PM
    case evening         // Typically 6-9 PM
    case night           // Typically 9 PM - 12 AM
    case lateNight       // Typically 12-5 AM
    case unknown

    public static var current: TimeCluster {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<8: return .earlyMorning
        case 8..<12: return .morning
        case 12..<15: return .earlyAfternoon
        case 15..<18: return .lateAfternoon
        case 18..<21: return .evening
        case 21..<24: return .night
        case 0..<5: return .lateNight
        default: return .unknown
        }
    }
}

// MARK: - Resource Tiers

public enum ResourceTier: String, CaseIterable, Codable, Sendable {
    case constrained  // Limited resources
    case standard     // Normal operation
    case abundant     // Plenty of resources
    case maximum      // All resources available

    public static var current: ResourceTier {
        // This would integrate with DynamicResourceAllocator
        // For now, use a simple heuristic
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_000_000_000
        if memoryGB >= 64 { return .maximum }
        if memoryGB >= 32 { return .abundant }
        if memoryGB >= 16 { return .standard }
        return .constrained
    }
}

// MARK: - Urgency Levels

public enum UrgencyLevel: String, CaseIterable, Codable, Sendable {
    case low
    case normal
    case high
    case critical

    public static func detect(from query: String?) -> UrgencyLevel {
        guard let query = query?.lowercased() else { return .normal }

        if query.contains("urgent") || query.contains("asap") || query.contains("immediately") || query.contains("emergency") {
            return .critical
        }
        if query.contains("quick") || query.contains("fast") || query.contains("hurry") || query.contains("soon") {
            return .high
        }
        if query.contains("when you can") || query.contains("no rush") || query.contains("whenever") {
            return .low
        }
        return .normal
    }
}

// MARK: - Complexity Levels

public enum BanditComplexityLevel: String, CaseIterable, Codable, Sendable {
    case simple
    case moderate
    case complex
    case veryComplex

    public static func estimate(from query: String?) -> BanditComplexityLevel {
        guard let query = query else { return .moderate }

        // Length-based heuristic
        let words = query.split(separator: " ").count
        if words > 200 { return .veryComplex }
        if words > 100 { return .complex }
        if words > 30 { return .moderate }
        return .simple
    }
}

// MARK: - Model Arm

/// Represents a model choice in the bandit
public struct ModelArm: Hashable, Codable, Sendable {
    public let modelId: String
    public let modelFamily: String
    public let isLocal: Bool
    public let estimatedLatencyMs: Int
    public let estimatedQuality: Double  // 0-1

    public init(
        modelId: String,
        modelFamily: String,
        isLocal: Bool,
        estimatedLatencyMs: Int,
        estimatedQuality: Double
    ) {
        self.modelId = modelId
        self.modelFamily = modelFamily
        self.isLocal = isLocal
        self.estimatedLatencyMs = estimatedLatencyMs
        self.estimatedQuality = estimatedQuality
    }
}

// MARK: - Arm Statistics

/// Statistics for a model arm in a given context
public struct ArmStatistics: Codable, Sendable {
    public var successes: Double  // Beta distribution alpha - 1
    public var failures: Double   // Beta distribution beta - 1
    public var totalReward: Double
    public var pullCount: Int
    public var lastPulled: Date

    public init() {
        self.successes = 0
        self.failures = 0
        self.totalReward = 0
        self.pullCount = 0
        self.lastPulled = Date.distantPast
    }

    /// Thompson Sampling: sample from Beta(alpha, beta)
    public func thompsonSample() -> Double {
        let alpha = successes + 1
        let beta = failures + 1
        return sampleBetaDistribution(alpha: alpha, beta: beta)
    }

    /// UCB score for exploration
    public func ucbScore(totalPulls: Int, explorationBonus: Double) -> Double {
        guard pullCount > 0 else { return Double.infinity }  // Explore unpulled arms

        let mean = totalReward / Double(pullCount)
        let exploration = explorationBonus * sqrt(log(Double(totalPulls + 1)) / Double(pullCount))
        return mean + exploration
    }

    /// Update statistics with observed reward
    public mutating func update(reward: Double) {
        let clampedReward = max(0, min(1, reward))
        successes += clampedReward
        failures += (1 - clampedReward)
        totalReward += clampedReward
        pullCount += 1
        lastPulled = Date()
    }
}

// MARK: - Contextual Multi-Armed Bandit

/// Learns optimal task→model mappings using contextual bandits
@MainActor
public final class ContextualMultiArmedBandit: ObservableObject {
    public static let shared = ContextualMultiArmedBandit()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ContextualBandit")

    // MARK: - State

    /// Statistics for each (context, arm) pair
    /// Key: context hash, Value: arm statistics by model ID
    private var contextArmStats: [Int: [String: ArmStatistics]] = [:]

    /// Global arm statistics (context-independent fallback)
    private var globalArmStats: [String: ArmStatistics] = [:]

    /// Available arms (models)
    @Published public private(set) var availableArms: [ModelArm] = []

    /// Total number of pulls across all contexts
    @Published public private(set) var totalPulls: Int = 0

    // MARK: - Configuration

    /// Minimum pulls before using learned statistics
    public var minPullsForContext: Int = 5

    /// Weight for context-specific vs global statistics
    public var contextWeight: Double = 0.7

    /// Exploration bonus for UCB
    public var explorationBonus: Double {
        HyperparameterTuner.shared.getValue(.banditExplorationBonus)
    }

    // MARK: - Persistence

    private let persistenceKey = "ContextualMultiArmedBandit.state"

    // MARK: - Initialization

    private init() {
        loadState()
        logger.info("ContextualMultiArmedBandit initialized")
    }

    // MARK: - Arm Management

    /// Register available model arms
    public func registerArms(_ arms: [ModelArm]) {
        availableArms = arms

        // Initialize global stats for new arms
        for arm in arms {
            if globalArmStats[arm.modelId] == nil {
                globalArmStats[arm.modelId] = ArmStatistics()
            }
        }

        logger.debug("Registered \(arms.count) model arms")
    }

    /// Add a single arm
    public func addArm(_ arm: ModelArm) {
        if !availableArms.contains(arm) {
            availableArms.append(arm)
            globalArmStats[arm.modelId] = ArmStatistics()
        }
    }

    /// Remove an arm
    public func removeArm(modelId: String) {
        availableArms.removeAll { $0.modelId == modelId }
        globalArmStats.removeValue(forKey: modelId)
    }

    // MARK: - Selection

    /// Select best model for context using Thompson Sampling
    public func selectModel(context: BanditContext) -> ModelArm? {
        guard !availableArms.isEmpty else { return nil }

        var bestArm: ModelArm?
        var bestSample: Double = -1

        let contextKey = context.hashValue

        for arm in availableArms {
            let sample = thompsonSampleForArm(arm, contextKey: contextKey)

            // Apply urgency adjustment
            var adjustedSample = sample
            if context.urgency == .critical && arm.isLocal {
                adjustedSample *= 1.2  // Prefer local for urgent tasks
            }
            if context.urgency == .critical && arm.estimatedLatencyMs > 5000 {
                adjustedSample *= 0.7  // Penalize slow models for urgent tasks
            }

            // Apply complexity adjustment
            if context.complexity == .veryComplex && arm.estimatedQuality > 0.8 {
                adjustedSample *= 1.1  // Prefer high-quality for complex tasks
            }

            if adjustedSample > bestSample {
                bestSample = adjustedSample
                bestArm = arm
            }
        }

        if let selected = bestArm {
            logger.debug("Selected \(selected.modelId) for \(context.taskType.rawValue) (sample: \(bestSample, format: .fixed(precision: 3)))")
        }

        return bestArm
    }

    /// Select using UCB for guaranteed exploration
    public func selectModelUCB(context: BanditContext) -> ModelArm? {
        guard !availableArms.isEmpty else { return nil }

        var bestArm: ModelArm?
        var bestScore: Double = -1

        let contextKey = context.hashValue

        for arm in availableArms {
            let score = ucbScoreForArm(arm, contextKey: contextKey)

            if score > bestScore {
                bestScore = score
                bestArm = arm
            }
        }

        return bestArm
    }

    /// Get selection probabilities for all arms (for debugging/visualization)
    public func getSelectionProbabilities(context: BanditContext, samples: Int = 1000) -> [String: Double] {
        var counts: [String: Int] = [:]
        for arm in availableArms {
            counts[arm.modelId] = 0
        }

        // Monte Carlo estimation of selection probabilities
        for _ in 0..<samples {
            var bestId: String?
            var bestSample: Double = -1

            let contextKey = context.hashValue

            for arm in availableArms {
                let sample = thompsonSampleForArm(arm, contextKey: contextKey)
                if sample > bestSample {
                    bestSample = sample
                    bestId = arm.modelId
                }
            }

            if let id = bestId {
                counts[id, default: 0] += 1
            }
        }

        var probabilities: [String: Double] = [:]
        for (id, count) in counts {
            probabilities[id] = Double(count) / Double(samples)
        }

        return probabilities
    }

    // MARK: - Thompson Sampling Helpers

    private func thompsonSampleForArm(_ arm: ModelArm, contextKey: Int) -> Double {
        // Get context-specific stats
        let contextStats = contextArmStats[contextKey]?[arm.modelId]

        // Get global stats
        let globalStats = globalArmStats[arm.modelId] ?? ArmStatistics()

        // Blend based on context experience
        if let ctxStats = contextStats, ctxStats.pullCount >= minPullsForContext {
            // Weighted blend of context and global
            let ctxSample = ctxStats.thompsonSample()
            let globalSample = globalStats.thompsonSample()
            return contextWeight * ctxSample + (1 - contextWeight) * globalSample
        } else {
            // Fall back to global
            return globalStats.thompsonSample()
        }
    }

    private func ucbScoreForArm(_ arm: ModelArm, contextKey: Int) -> Double {
        let contextStats = contextArmStats[contextKey]?[arm.modelId]
        let globalStats = globalArmStats[arm.modelId] ?? ArmStatistics()

        if let ctxStats = contextStats, ctxStats.pullCount >= minPullsForContext {
            return ctxStats.ucbScore(totalPulls: totalPulls, explorationBonus: explorationBonus)
        } else {
            return globalStats.ucbScore(totalPulls: totalPulls, explorationBonus: explorationBonus)
        }
    }

    // MARK: - Reward Update

    /// Record reward for a model selection
    public func recordReward(
        modelId: String,
        context: BanditContext,
        reward: Double
    ) {
        let contextKey = context.hashValue
        let clampedReward = max(0, min(1, reward))

        // Update context-specific stats
        if contextArmStats[contextKey] == nil {
            contextArmStats[contextKey] = [:]
        }
        if contextArmStats[contextKey]![modelId] == nil {
            contextArmStats[contextKey]![modelId] = ArmStatistics()
        }
        contextArmStats[contextKey]![modelId]!.update(reward: clampedReward)

        // Update global stats
        if globalArmStats[modelId] == nil {
            globalArmStats[modelId] = ArmStatistics()
        }
        globalArmStats[modelId]!.update(reward: clampedReward)

        totalPulls += 1

        // Persist periodically
        if totalPulls % 50 == 0 {
            saveState()
        }

        logger.debug("Recorded reward \(clampedReward, format: .fixed(precision: 2)) for \(modelId) in context \(context.taskType.rawValue)")
    }

    /// Calculate reward from interaction outcome
    public static func calculateReward(
        latencyMs: Int,
        userRating: Double?,
        wasRegenerated: Bool,
        wasEdited: Bool,
        errorOccurred: Bool
    ) -> Double {
        if errorOccurred { return 0.0 }

        var reward = 0.5  // Base reward

        // Latency component (target: <3s)
        let latencyReward = max(0, 1.0 - Double(latencyMs) / 10000.0)
        reward += latencyReward * 0.2

        // User rating component
        if let rating = userRating {
            reward += (rating - 0.5) * 0.4  // Shift from [0,1] to [-0.5,0.5] contribution
        }

        // Regeneration penalty
        if wasRegenerated {
            reward -= 0.2
        }

        // Edit penalty (user fixed the response)
        if wasEdited {
            reward -= 0.1
        }

        return max(0, min(1, reward))
    }

    // MARK: - Analytics

    /// Get best model for each task type
    public func getBestModels() -> [TaskCategory: String] {
        var best: [TaskCategory: String] = [:]

        for taskType in TaskCategory.allCases {
            let context = BanditContext(taskType: taskType)
            if let arm = selectModel(context: context) {
                best[taskType] = arm.modelId
            }
        }

        return best
    }

    /// Get statistics for a specific arm
    public func getArmStats(modelId: String) -> (global: ArmStatistics?, contextCount: Int) {
        let global = globalArmStats[modelId]
        let contextCount = contextArmStats.values.filter { $0[modelId] != nil }.count
        return (global, contextCount)
    }

    /// Get exploration rate (proportion of non-optimal selections)
    // periphery:ignore - Reserved: recentWindow parameter kept for API compatibility
    public func getExplorationRate(recentWindow: Int = 100) -> Double {
        // This would require tracking recent selections
        // For now, return estimated rate based on statistics
        guard totalPulls > 0 else { return 1.0 }

        let avgPullsPerArm = Double(totalPulls) / Double(max(1, availableArms.count))
        let explorationEstimate = min(1.0, 10.0 / avgPullsPerArm)

        return explorationEstimate
    }

    // MARK: - Persistence

    private func saveState() {
        let state = BanditState(
            contextArmStats: contextArmStats,
            globalArmStats: globalArmStats,
            totalPulls: totalPulls
        )

        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            logger.error("Failed to encode BanditState: \(error.localizedDescription)")
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        let state: BanditState
        do {
            state = try JSONDecoder().decode(BanditState.self, from: data)
        } catch {
            logger.error("Failed to decode BanditState: \(error.localizedDescription)")
            return
        }

        self.contextArmStats = state.contextArmStats
        self.globalArmStats = state.globalArmStats
        self.totalPulls = state.totalPulls

        logger.info("Loaded bandit state: \(self.totalPulls) total pulls")
    }

    private struct BanditState: Codable {
        let contextArmStats: [Int: [String: ArmStatistics]]
        let globalArmStats: [String: ArmStatistics]
        let totalPulls: Int
    }

    // MARK: - Reset

    /// Reset all statistics
    public func resetAll() {
        contextArmStats = [:]
        globalArmStats = [:]
        totalPulls = 0
        saveState()
        logger.warning("Reset all bandit statistics")
    }

    /// Reset statistics for a specific context
    public func resetContext(_ context: BanditContext) {
        contextArmStats.removeValue(forKey: context.hashValue)
    }
}

// MARK: - Beta Distribution Sampling

private func sampleBetaDistribution(alpha: Double, beta: Double) -> Double {
    let x = sampleGammaDistribution(shape: alpha)
    let y = sampleGammaDistribution(shape: beta)
    guard x + y > 0 else { return 0.5 }
    return x / (x + y)
}

private func sampleGammaDistribution(shape: Double) -> Double {
    guard shape >= 1 else {
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

private func sampleStandardNormal() -> Double {
    let u1 = Double.random(in: 0..<1)
    let u2 = Double.random(in: 0..<1)
    return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
}
