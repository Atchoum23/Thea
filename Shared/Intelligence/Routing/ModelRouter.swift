// ModelRouter.swift
// Thea V2
//
// Adaptive model routing that learns from outcomes with persistent memory

import Foundation
import OSLog

// MARK: - Model Router

/// Adaptive model router that learns from outcomes and optimizes for quality/cost/speed
/// Now integrates with MemoryManager for persistent learning across sessions
@MainActor
public final class ModelRouter: ObservableObject {
    public static let shared = ModelRouter()

    private let logger = Logger(subsystem: "com.thea.v2", category: "ModelRouter")

    // MARK: - Performance Tracking

    /// Performance history by model and task type
    @Published public private(set) var modelPerformance: [String: [TaskType: ModelTaskPerformance]] = [:]

    /// Recent routing decisions
    @Published public private(set) var routingHistory: [RoutingDecision] = []

    /// Learned model preferences from MemoryManager
    @Published public private(set) var learnedPreferences: [LearnedModelPreference] = []

    /// Contextual routing patterns learned over time
    @Published public private(set) var contextualPatterns: [ContextualRoutingPattern] = []

    // MARK: - Configuration

    /// Weight for quality vs cost vs speed (should sum to 1.0).
    /// Initialized from TheaConfig if available; defaults to 0.5/0.3/0.2.
    public var qualityWeight: Double = 0.5
    public var costWeight: Double = 0.3
    public var speedWeight: Double = 0.2

    /// Exploration rate for trying different models.
    /// Configurable via TheaConfig.ai; defaults to 0.1.
    public var explorationRate: Double = 0.1

    /// Enable adaptive routing based on learned performance (vs static rules)
    public var useAdaptiveRouting: Bool = true

    /// Use MemoryManager for persistent learning
    public var usePersistentLearning: Bool = true

    // MARK: - Initialization

    private init() {
        Task {
            await loadLearnedPreferences()
            await loadPerformanceFromMemory()
        }
    }

    // MARK: - Routing

    /// Route a query to the optimal model based on task type and learned performance
    public func route(
        classification: ClassificationResult,
        context: RoutingContext = RoutingContext()
    ) -> RoutingDecision {
        let startTime = Date()

        // Get candidate models
        let candidates = getCandidateModels(for: classification.taskType)

        guard !candidates.isEmpty else {
            logger.warning("No candidate models for task type \(classification.taskType.rawValue)")
            return fallbackDecision(for: classification, context: context)
        }

        // Should we explore or exploit?
        let shouldExplore = Double.random(in: 0...1) < explorationRate

        let selectedModel: AIModel
        let reason: String

        if shouldExplore, let random = candidates.randomElement() {
            // Exploration: try a random candidate
            selectedModel = random
            reason = "Exploration: trying alternative model"
            logger.debug("Exploration: selected \(selectedModel.id)")
        } else {
            // Exploitation: use best performing model
            let scored = scoreModels(candidates, for: classification.taskType, context: context)
            if let best = scored.first {
                selectedModel = best.model
                reason = "Best score: \(String(format: "%.2f", best.score))"
                logger.debug("Exploitation: selected \(selectedModel.id) with score \(best.score)")
            } else {
                // Fallback to first candidate if scoring returns empty
                selectedModel = candidates[0]
                reason = "Fallback: scoring returned no results"
                logger.warning("scoreModels returned empty, falling back to first candidate")
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        let decision = RoutingDecision(
            model: selectedModel,
            provider: selectedModel.provider,
            taskType: classification.taskType,
            confidence: classification.confidence,
            reason: reason,
            alternatives: candidates.filter { $0.id != selectedModel.id },
            timestamp: Date()
        )

        // Record decision
        routingHistory.append(decision)
        if routingHistory.count > 500 {
            routingHistory.removeFirst(100)
        }

        // Log event
        EventBus.shared.logAction(
            .routing,
            target: selectedModel.id,
            parameters: [
                "taskType": classification.taskType.rawValue,
                "reason": reason,
                "candidates": String(candidates.count)
            ],
            success: true,
            duration: duration
        )

        return decision
    }

    // MARK: - Dynamic Model Updates

    /// Dynamically registered models from online sources.
    /// When populated, these override the static `AIModel.allKnownModels`.
    private var dynamicModels: [AIModel]?

    /// Update the available model list from DynamicModelRegistry.
    public func updateAvailableModels(_ models: [AIModel]) {
        dynamicModels = models
        logger.info("ModelRouter updated with \(models.count) dynamic models")
    }

}

// MARK: - Candidate Selection

extension ModelRouter {

    // MARK: - Candidate Selection

    private func getCandidateModels(for taskType: TaskType) -> [AIModel] {
        let allModels = dynamicModels ?? AIModel.allKnownModels

        // Filter local models by hardware capability — skip models that won't fit in RAM
        let capabilityService = SystemCapabilityService.shared
        let memoryFiltered = allModels.filter { model in
            capabilityService.canRunLocalModel(model)
        }

        // Filter by required capabilities
        let requiredCapabilities = taskType.preferredCapabilities

        let suitable = memoryFiltered.filter { model in
            !requiredCapabilities.isDisjoint(with: model.capabilities)
        }

        // If we have suitable models, use them; otherwise fall back to all memory-filtered models
        return suitable.isEmpty ? memoryFiltered : suitable
    }

    // MARK: - Scoring

    private func scoreModels(
        _ models: [AIModel],
        for taskType: TaskType,
        context: RoutingContext
    ) -> [(model: AIModel, score: Double)] {
        var scored: [(model: AIModel, score: Double)] = []

        // Adjust weights based on user's current behavioral state
        let behavioralContext = BehavioralFingerprint.shared.currentContext()
        var adjustedQualityWeight = qualityWeight
        let adjustedCostWeight = costWeight
        var adjustedSpeedWeight = speedWeight

        // When user is in deep work (low receptivity), favor speed over quality
        if behavioralContext.receptivity < 0.3 {
            adjustedSpeedWeight += 0.1
            adjustedQualityWeight -= 0.1
        }
        // When user is idle/receptive, favor quality
        if behavioralContext.receptivity > 0.7 {
            adjustedQualityWeight += 0.1
            adjustedSpeedWeight -= 0.1
        }

        for model in models {
            let qualityScore = calculateQualityScore(model, for: taskType)
            let costScore = calculateCostScore(model, context: context)
            let speedScore = calculateSpeedScore(model, for: taskType)

            let totalScore = (adjustedQualityWeight * qualityScore) +
                            (adjustedCostWeight * costScore) +
                            (adjustedSpeedWeight * speedScore)

            scored.append((model, totalScore))
        }

        return scored.sorted { $0.score > $1.score }
    }

    private func calculateQualityScore(_ model: AIModel, for taskType: TaskType) -> Double {
        var score = 0.5

        // Priority 1: Check learned preferences from MemoryManager
        if let learnedPref = learnedPreferences.first(where: {
            $0.modelId == model.id && $0.taskType == taskType
        }) {
            // Weight learned score by sample count confidence
            let sampleConfidence = min(1.0, Double(learnedPref.sampleCount) / 20.0)
            score = (learnedPref.preferenceScore * sampleConfidence) + (score * (1 - sampleConfidence))
            logger.debug("Using learned preference for \(model.id)/\(taskType.rawValue): \(score)")
        }

        // Priority 2: Check in-session performance tracking
        if let taskPerf = modelPerformance[model.id]?[taskType] {
            let sessionScore = taskPerf.successRate
            // Blend session performance with learned preferences
            score = (score + sessionScore) / 2.0
        }

        // Priority 3: Check contextual patterns
        let relevantPatterns = contextualPatterns.filter { $0.modelId == model.id }
        if !relevantPatterns.isEmpty {
            let patternBonus = relevantPatterns
                .map { $0.confidence * 0.1 }
                .reduce(0, +)
            score += min(0.2, patternBonus)
        }

        // Fallback: estimate based on model characteristics if no learned data
        if learnedPreferences.isEmpty && modelPerformance[model.id] == nil {
            // Flagship models get bonus
            if model.contextWindow >= 100_000 {
                score += 0.2
            }

            // Reasoning capability bonus for complex tasks
            if taskType.benefitsFromReasoning && model.capabilities.contains(.reasoning) {
                score += 0.2
            }

            // Code capability bonus for code tasks
            if [.codeGeneration, .debugging, .codeRefactoring].contains(taskType) &&
               model.capabilities.contains(.codeGeneration) {
                score += 0.15
            }
        }

        return min(1.0, max(0.0, score))
    }

    private func calculateCostScore(_ model: AIModel, context: RoutingContext) -> Double {
        // Lower cost = higher score. Cost scoring uses 2026 pricing model:
        // Most providers now offer tiered pricing — input tokens much cheaper than output.
        // Flagship models (Opus, o1) ~$15-75/M output; mid-tier (Sonnet, GPT-4o) ~$3-15/M;
        // Budget (Haiku, Flash, mini) <$1/M. Local models cost $0 (speed-only score).
        guard let inputCost = model.inputCostPer1K,
              let outputCost = model.outputCostPer1K else {
            // Use historical average if available, otherwise neutral
            if let perf = modelPerformance[model.id],
               let anyPerf = perf.values.first,
               anyPerf.totalCost > 0 {
                let avgCost = NSDecimalNumber(decimal: anyPerf.averageCost).doubleValue
                return max(0.1, min(1.0, 1.0 / (1.0 + (avgCost * 100))))
            }
            return 0.5
        }

        // Estimate total cost for expected token usage
        let expectedInputTokens = context.estimatedInputTokens ?? 1000
        let expectedOutputTokens = context.estimatedOutputTokens ?? 500

        let estimatedCost = (Decimal(expectedInputTokens) / 1000 * inputCost) +
                           (Decimal(expectedOutputTokens) / 1000 * outputCost)

        // Convert to score (inverse relationship with cost)
        // $0.001 = 1.0, $0.01 = 0.5, $0.1 = 0.1
        let costDouble = NSDecimalNumber(decimal: estimatedCost).doubleValue
        let score = 1.0 / (1.0 + (costDouble * 100))

        return max(0.1, min(1.0, score))
    }

    private func calculateSpeedScore(_ model: AIModel, for taskType: TaskType) -> Double {
        // Check historical latency
        if let taskPerf = modelPerformance[model.id]?[taskType] {
            let avgLatency = taskPerf.averageLatency
            // <1s = 1.0, 5s = 0.5, >10s = 0.2
            if avgLatency < 1.0 { return 1.0 }
            if avgLatency < 5.0 { return 0.7 }
            if avgLatency < 10.0 { return 0.5 }
            return 0.2
        }

        // Estimate based on model characteristics
        if model.isLocal { return 0.9 } // Local models are fast
        if model.id.contains("mini") || model.id.contains("flash") { return 0.85 }
        if model.capabilities.contains(.reasoning) { return 0.4 } // Reasoning models are slower

        return 0.6
    }

    // MARK: - Fallback

    private func fallbackDecision(
        for classification: ClassificationResult,
        context _context: RoutingContext
    ) -> RoutingDecision {
        // Use default model from config
        let defaultModel = TheaConfig.shared.ai.defaultModel
        let defaultProvider = TheaConfig.shared.ai.defaultProvider

        // Try to find the default model
        let allModels = dynamicModels ?? AIModel.allKnownModels
        if let found = allModels.first(where: { $0.id == defaultModel }) {
            return RoutingDecision(
                model: found,
                provider: defaultProvider,
                taskType: classification.taskType,
                confidence: 0.5,
                reason: "Fallback to default model",
                alternatives: [],
                timestamp: Date()
            )
        }

        // Last resort: create a minimal model reference from user defaults
        let fallbackModel = AIModel(
            id: defaultModel,
            name: "Default Model",
            provider: defaultProvider
        )

        return RoutingDecision(
            model: fallbackModel,
            provider: defaultProvider,
            taskType: classification.taskType,
            confidence: 0.3,
            reason: "Fallback to default configured model — no registered models matched",
            alternatives: [],
            timestamp: Date()
        )
    }

    // MARK: - Learning

    /// Record the outcome of a routing decision for learning
    public func recordOutcome(
        for decision: RoutingDecision,
        success: Bool,
        quality: Double? = nil,
        latency: TimeInterval,
        tokens: Int,
        cost: Decimal
    ) {
        let modelId = decision.model.id
        let taskType = decision.taskType

        // Initialize if needed
        if modelPerformance[modelId] == nil {
            modelPerformance[modelId] = [:]
        }

        if modelPerformance[modelId]?[taskType] == nil {
            modelPerformance[modelId]?[taskType] = ModelTaskPerformance(modelId: modelId, taskType: taskType)
        }

        // Update performance
        modelPerformance[modelId]?[taskType]?.recordOutcome(
            success: success,
            quality: quality,
            latency: latency,
            tokens: tokens,
            cost: cost
        )

        // Log learning event
        EventBus.shared.logLearning(
            type: success ? .patternDetected : .errorFixed,
            data: [
                "model": modelId,
                "taskType": taskType.rawValue,
                "success": String(success),
                "latency": String(format: "%.2f", latency)
            ],
            improvement: success ? 0.01 : -0.01
        )

        logger.debug("Recorded outcome for \(modelId)/\(taskType.rawValue): success=\(success)")

        // Persist to MemoryManager for long-term learning
        if usePersistentLearning {
            Task {
                await storeRoutingOutcomeToMemory(
                    decision: decision,
                    success: success,
                    quality: quality,
                    latency: latency,
                    tokens: tokens,
                    cost: cost
                )
            }
        }
    }

    // MARK: - Persistent Learning via MemoryManager

    /// Load learned model preferences from MemoryManager
    private func loadLearnedPreferences() async {
        // Retrieve procedural memories for routing patterns
        guard let bestProcedure = await MemoryManager.shared.retrieveBestProcedure(for: "model_routing") else {
            logger.debug("No existing routing procedures found in memory")
            return
        }

        // Parse learned preferences from key-value format
        let components = bestProcedure.value.components(separatedBy: ";")
        var preferences: [LearnedModelPreference] = []

        for component in components {
            let parts = component.components(separatedBy: ":")
            if parts.count >= 3,
               let taskType = TaskType(rawValue: parts[0]),
               let score = Double(parts[2]) {
                let modelId = parts[1]
                let preference = LearnedModelPreference(
                    modelId: modelId,
                    taskType: taskType,
                    preferenceScore: score,
                    sampleCount: 10,
                    lastUpdated: bestProcedure.timestamp
                )
                preferences.append(preference)
            }
        }

        self.learnedPreferences = preferences
        logger.info("Loaded \(preferences.count) learned model preferences from memory")
    }

    /// Load historical performance data from MemoryManager
    private func loadPerformanceFromMemory() async {
        // Retrieve semantic memories for model performance
        let memories = await MemoryManager.shared.retrieveSemanticMemories(
            category: .modelPerformance,
            limit: 100
        )

        for memory in memories {
            // Parse key format: "modelId|taskType"
            let keyParts = memory.key.components(separatedBy: "|")
            guard keyParts.count >= 2,
                  let taskType = TaskType(rawValue: keyParts[1]) else {
                continue
            }

            let modelId = keyParts[0]

            // Initialize if needed
            if self.modelPerformance[modelId] == nil {
                self.modelPerformance[modelId] = [:]
            }

            if self.modelPerformance[modelId]?[taskType] == nil {
                self.modelPerformance[modelId]?[taskType] = ModelTaskPerformance(modelId: modelId, taskType: taskType)
            }

            // Parse value format: "successRate|avgLatency|sampleCount"
            let valueParts = memory.value.components(separatedBy: "|")
            if valueParts.count >= 3,
               let successRate = Double(valueParts[0]),
               let avgLatency = Double(valueParts[1]),
               let sampleCount = Int(valueParts[2]) {
                let successCount = Int(Double(sampleCount) * successRate)
                self.modelPerformance[modelId]?[taskType]?.successCount = successCount
                self.modelPerformance[modelId]?[taskType]?.failureCount = sampleCount - successCount
                self.modelPerformance[modelId]?[taskType]?.totalLatency = avgLatency * Double(sampleCount)
            }
        }

        logger.info("Loaded performance data for \(self.modelPerformance.count) models from memory")
    }

    /// Store routing outcome to MemoryManager for persistent learning
    private func storeRoutingOutcomeToMemory(
        decision: RoutingDecision,
        success: Bool,
        quality: Double?,
        latency: TimeInterval,
        tokens: Int,
        cost: Decimal
    ) async {
        let modelId = decision.model.id
        let taskType = decision.taskType

        // Store as semantic memory (factual knowledge about model performance)
        // Key format: "modelId|taskType"
        // Value format: "successRate|avgLatency|sampleCount"
        let perf = self.modelPerformance[modelId]?[taskType]
        let successRate = perf?.successRate ?? (success ? 1.0 : 0.0)
        let avgLatency = perf?.averageLatency ?? latency
        let sampleCount = (perf?.successCount ?? 0) + (perf?.failureCount ?? 0) + 1

        await MemoryManager.shared.storeSemanticMemory(
            category: .modelPerformance,
            key: "\(modelId)|\(taskType.rawValue)",
            value: "\(String(format: "%.3f", successRate))|\(String(format: "%.3f", avgLatency))|\(sampleCount)",
            confidence: quality ?? (success ? 0.8 : 0.3),
            source: .inferred
        )

        // If this is a significant learning (many samples), store as procedural memory
        if let perf = self.modelPerformance[modelId]?[taskType],
           (perf.successCount + perf.failureCount) % 10 == 0 {
            await storeProcedureMemoryForModel(modelId: modelId, taskType: taskType, performance: perf)
        }

        // Detect and store contextual patterns
        await detectAndStoreContextualPatterns(decision: decision, success: success)
    }

    /// Store aggregated model preference as procedural memory
    private func storeProcedureMemoryForModel(
        modelId: String,
        taskType: TaskType,
        performance: ModelTaskPerformance
    ) async {
        let score = performance.successRate
        let sampleCount = performance.successCount + performance.failureCount

        // Build procedure string from all learned preferences
        var procedureValue = learnedPreferences.map { pref in
            "\(pref.taskType.rawValue):\(pref.modelId):\(String(format: "%.3f", pref.preferenceScore))"
        }.joined(separator: ";")

        // Add or update current preference
        let currentPrefKey = "\(taskType.rawValue):\(modelId)"
        if !procedureValue.contains(currentPrefKey) {
            if !procedureValue.isEmpty { procedureValue += ";" }
            procedureValue += "\(taskType.rawValue):\(modelId):\(String(format: "%.3f", score))"
        }

        await MemoryManager.shared.storeProceduralMemory(
            taskType: "model_routing",
            procedure: procedureValue,
            successRate: score,
            averageDuration: performance.averageLatency
        )

        // Update local preferences cache
        if let index = learnedPreferences.firstIndex(where: { $0.modelId == modelId && $0.taskType == taskType }) {
            learnedPreferences[index] = LearnedModelPreference(
                modelId: modelId,
                taskType: taskType,
                preferenceScore: score,
                sampleCount: sampleCount,
                lastUpdated: Date()
            )
        } else {
            learnedPreferences.append(LearnedModelPreference(
                modelId: modelId,
                taskType: taskType,
                preferenceScore: score,
                sampleCount: sampleCount,
                lastUpdated: Date()
            ))
        }

        logger.debug("Stored procedural memory for \(modelId)/\(taskType.rawValue)")
    }

    /// Detect contextual patterns in routing decisions
    private func detectAndStoreContextualPatterns(
        decision: RoutingDecision,
        success: Bool
    ) async {
        // Analyze recent routing history for patterns
        let recentDecisions = routingHistory.suffix(20)

        // Pattern 1: Time-of-day preferences
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 6..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<22: timeOfDay = "evening"
        default: timeOfDay = "night"
        }

        // Pattern 2: Task sequence patterns
        let recentTaskTypes = recentDecisions.suffix(3).map { $0.taskType }
        if recentTaskTypes.count >= 2 {
            let taskSequence = recentTaskTypes.map { $0.rawValue }.joined(separator: " → ")

            // Check if this sequence consistently succeeds with certain models
            let sequenceSuccesses = recentDecisions.filter { d in
                d.model.id == decision.model.id
            }

            if sequenceSuccesses.count >= 3 {
                let pattern = ContextualRoutingPattern(
                    id: UUID(),
                    patternType: .taskSequence,
                    description: "Task sequence '\(taskSequence)' works well with \(decision.model.id)",
                    modelId: decision.model.id,
                    context: [
                        "taskSequence": taskSequence,
                        "timeOfDay": timeOfDay,
                        "successRate": String(format: "%.2f", Double(sequenceSuccesses.count) / Double(recentDecisions.count))
                    ],
                    confidence: min(0.9, 0.5 + (Double(sequenceSuccesses.count) * 0.1)),
                    sampleCount: sequenceSuccesses.count,
                    lastSeen: Date()
                )

                // Store if not duplicate
                if !contextualPatterns.contains(where: { $0.description == pattern.description }) {
                    contextualPatterns.append(pattern)

                    // Store pattern as user preference
                    await MemoryManager.shared.learnPreference(
                        category: .modelSelection,
                        preference: pattern.description,
                        strength: pattern.confidence
                    )
                }
            }
        }
    }

    /// Get routing insights from learned patterns
    public func getRoutingInsights() -> RoutingInsights {
        let topModels = learnedPreferences
            .sorted { $0.preferenceScore > $1.preferenceScore }
            .prefix(5)
            .map { ($0.modelId, $0.taskType, $0.preferenceScore) }

        let recentPatterns = contextualPatterns
            .sorted { $0.lastSeen > $1.lastSeen }
            .prefix(10)

        let totalSamples = modelPerformance.values
            .flatMap(\.values)
            .reduce(0) { $0 + $1.successCount + $1.failureCount }

        return RoutingInsights(
            topPerformingModels: topModels.map { "\($0.0) for \($0.1.rawValue): \(String(format: "%.0f%%", $0.2 * 100))" },
            recentPatterns: Array(recentPatterns),
            totalRoutingDecisions: routingHistory.count,
            totalLearningSamples: totalSamples,
            explorationRate: explorationRate,
            adaptiveRoutingEnabled: useAdaptiveRouting
        )
    }

    // MARK: - Statistics

    /// Returns the performance statistics for the given model across all task types, or `nil` if no data has been recorded.
    public func getModelStatistics(for modelId: String) -> [TaskType: ModelTaskPerformance]? {
        modelPerformance[modelId]
    }

    /// Returns the highest-scoring model for the given task type using the current routing weights and context, or `nil` if no candidates are available.
    public func getBestModel(for taskType: TaskType) -> AIModel? {
        let candidates = getCandidateModels(for: taskType)
        let scored = scoreModels(candidates, for: taskType, context: RoutingContext())
        return scored.first?.model
    }

    // MARK: - Reset

    /// Resets all accumulated model performance tracking data and clears the routing history.
    public func resetPerformanceData() {
        modelPerformance.removeAll()
        routingHistory.removeAll()
        logger.info("Reset model performance data")
    }
}
