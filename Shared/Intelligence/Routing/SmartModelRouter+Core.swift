// SmartModelRouter+Core.swift
// Thea
//
// SmartModelRouter class implementation.

import Foundation
import os.log

// MARK: - Smart Model Router

/// Intelligent model routing engine
@MainActor
public final class SmartModelRouter: ObservableObject {
    public static let shared = SmartModelRouter()

    private let logger = Logger(subsystem: "com.thea.routing", category: "SmartRouter")
    private let storageURL: URL

    @Published public private(set) var availableModels: [RouterModelCapability] = []
    @Published public private(set) var usageByModel: [String: ModelUsage] = [:]
    @Published public private(set) var dailyBudget: Double = 10.0  // USD
    @Published public private(set) var dailySpent: Double = 0.0
    @Published public private(set) var defaultStrategy: RoutingStrategy = .balanced

    // Pending batch requests
    private var pendingBatches: [BatchRequest] = []
    private var batchTimer: Timer?

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = documentsPath.appendingPathComponent("thea_model_usage.json")
        setupDefaultModels()
        loadUsage()
    }

    // MARK: - Model Registration

    public func registerModel(_ model: RouterModelCapability) {
        if !availableModels.contains(where: { $0.modelId == model.modelId }) {
            availableModels.append(model)
            logger.info("Registered model: \(model.modelId)")
        }
    }

    public func removeModel(modelId: String) {
        availableModels.removeAll { $0.modelId == modelId }
    }

    // MARK: - Routing

    /// Route a task to the optimal model
    public func route(
        task: String,
        taskType: String,
        requiredCapabilities: Set<RouterModelCapability.Capability> = [],
        strategy: RoutingStrategy? = nil,
        estimatedInputTokens: Int = 1000,
        maxCost: Double? = nil
    ) -> SmartRoutingDecision {
        let strategy = strategy ?? defaultStrategy
        let complexity = classifyComplexity(task: task, taskType: taskType)

        // Filter models by required capabilities
        var candidates = availableModels.filter { model in
            requiredCapabilities.isSubset(of: model.capabilities)
        }

        // Filter by budget if specified
        if let maxCost = maxCost {
            candidates = candidates.filter { model in
                estimateCost(model: model, inputTokens: estimatedInputTokens, outputTokens: 1000) <= maxCost
            }
        }

        // Check daily budget
        let remainingBudget = dailyBudget - dailySpent
        candidates = candidates.filter { model in
            estimateCost(model: model, inputTokens: estimatedInputTokens, outputTokens: 1000) <= remainingBudget
        }

        guard !candidates.isEmpty else {
            // Fallback to cheapest available
            guard let fallbackModel = availableModels.min(by: { $0.costPerInputToken < $1.costPerInputToken }) ?? availableModels.first else {
                // No models configured — return empty decision with zero confidence
                return SmartRoutingDecision(
                    taskType: complexity,
                    selectedModel: RouterModelCapability(modelId: "none", provider: "none", contextWindow: 0, maxOutputTokens: 0, capabilities: [], costPerInputToken: 0, costPerOutputToken: 0, averageLatency: 0, qualityScore: 0),
                    estimatedCost: 0,
                    estimatedLatency: 1.0,
                    confidence: 0.0,
                    reasoning: "No models available",
                    strategy: strategy
                )
            }
            return SmartRoutingDecision(
                taskType: complexity,
                selectedModel: fallbackModel,
                estimatedCost: 0,
                estimatedLatency: 1.0,
                confidence: 0.3,
                reasoning: "Budget exhausted, using cheapest model",
                strategy: strategy
            )
        }

        // Score and rank candidates
        let scoredCandidates = candidates.map { model -> (RouterModelCapability, Float) in
            let score = scoreModel(
                model: model,
                complexity: complexity,
                strategy: strategy,
                estimatedInputTokens: estimatedInputTokens
            )
            return (model, score)
        }.sorted { $0.1 > $1.1 }

        // Safe access — candidates is non-empty so scoredCandidates is non-empty
        let best = scoredCandidates[0]
        let selected = best.0
        let alternatives = scoredCandidates.dropFirst().prefix(3).map { $0.0 }

        let estimatedCost = estimateCost(model: selected, inputTokens: estimatedInputTokens, outputTokens: 1000)
        let estimatedLatency = selected.averageLatency

        return SmartRoutingDecision(
            taskType: complexity,
            selectedModel: selected,
            alternativeModels: Array(alternatives),
            estimatedCost: estimatedCost,
            estimatedLatency: estimatedLatency,
            confidence: best.1,
            reasoning: generateReasoning(strategy: strategy, model: selected, complexity: complexity),
            strategy: strategy
        )
    }

    // MARK: - Plan and Execute

    /// Get configuration for plan-and-execute pattern
    public func getPlanExecuteConfig(taskComplexity: TaskComplexity) -> PlanExecuteConfig? {
        // Get best reasoning model for planning
        let planningCandidates = availableModels.filter {
            $0.capabilities.contains(.reasoning) && $0.qualityScore >= 0.8
        }.sorted { $0.qualityScore > $1.qualityScore }

        // Get cheapest capable model for execution
        let executionCandidates = availableModels.filter {
            $0.capabilities.contains(.textGeneration)
        }.sorted { $0.costPerInputToken < $1.costPerInputToken }

        guard let planningModel = planningCandidates.first,
              let executionModel = executionCandidates.first else {
            return nil
        }

        // For complex tasks, add verification
        let verificationModel: RouterModelCapability?
        if taskComplexity == .complex || taskComplexity == .expert {
            verificationModel = availableModels.first {
                $0.qualityScore >= 0.7 && $0.costPerInputToken < planningModel.costPerInputToken
            }
        } else {
            verificationModel = nil
        }

        return PlanExecuteConfig(
            planningModel: planningModel,
            executionModel: executionModel,
            verificationModel: verificationModel,
            maxExecutionSteps: taskComplexity == .expert ? 15 : 10
        )
    }

    // MARK: - Cascade Fallback

    /// Get configuration for cascade fallback
    public func getCascadeConfig(requiredCapabilities: Set<RouterModelCapability.Capability> = []) -> CascadeConfig {
        // Sort models by cost (cheapest first)
        let candidates = availableModels
            .filter { requiredCapabilities.isSubset(of: $0.capabilities) }
            .sorted { $0.costPerInputToken < $1.costPerInputToken }

        return CascadeConfig(
            models: candidates,
            confidenceThreshold: 0.7,
            maxAttempts: min(3, candidates.count)
        )
    }

    // MARK: - Batch Optimization

    /// Queue requests for batch processing
    public func queueForBatch(_ request: BatchRequest.SingleRequest) {
        if pendingBatches.isEmpty {
            pendingBatches.append(BatchRequest(requests: [request]))
            scheduleBatchProcessing()
        } else {
            // Add to existing batch
            var lastBatch = pendingBatches.removeLast()
            let newRequests = lastBatch.requests + [request]
            lastBatch = BatchRequest(
                id: lastBatch.id,
                requests: newRequests,
                priority: lastBatch.priority,
                deadline: lastBatch.deadline
            )
            pendingBatches.append(lastBatch)
        }

        // If batch is large enough, process immediately
        if let batch = pendingBatches.last, batch.requests.count >= 20 {
            Task {
                await processPendingBatches()
            }
        }
    }

    /// Process pending batch requests
    public func processPendingBatches() async {
        guard !pendingBatches.isEmpty else { return }

        let batches = pendingBatches
        pendingBatches.removeAll()

        for batch in batches {
            // Group by task type for optimal model selection
            let groupedByType = Dictionary(grouping: batch.requests) { $0.taskType }

            for (taskType, requests) in groupedByType {
                // Select model for batch
                let decision = route(
                    task: "batch processing",
                    taskType: taskType,
                    strategy: .costOptimized,
                    estimatedInputTokens: requests.map { $0.prompt.count / 4 }.reduce(0, +)
                )

                logger.info("Processing batch of \(requests.count) \(taskType) requests with \(decision.selectedModel.modelId)")
            }
        }
    }

    private func scheduleBatchProcessing() {
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.processPendingBatches()
            }
        }
    }

    // MARK: - Usage Recording

    /// Record usage for a model
    public func recordUsage(
        modelId: String,
        inputTokens: Int,
        outputTokens: Int,
        latency: TimeInterval,
        success: Bool
    ) {
        var usage = usageByModel[modelId] ?? ModelUsage()

        guard let model = availableModels.first(where: { $0.modelId == modelId }) else { return }

        let cost = (Double(inputTokens) * model.costPerInputToken +
                   Double(outputTokens) * model.costPerOutputToken) / 1_000_000

        usage.record(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cost: cost,
            latency: latency,
            success: success
        )

        usageByModel[modelId] = usage
        dailySpent += cost

        saveUsage()

        logger.debug("Recorded usage for \(modelId): \(inputTokens) in, \(outputTokens) out, $\(String(format: "%.4f", cost))")
    }

    /// Reset daily spending (call at midnight)
    public func resetDailySpending() {
        dailySpent = 0
        logger.info("Reset daily spending")
    }

    // MARK: - Statistics

    public var totalSpent: Double {
        usageByModel.values.map { $0.totalCost }.reduce(0, +)
    }

    public var totalTokensUsed: Int {
        usageByModel.values.map { $0.totalInputTokens + $0.totalOutputTokens }.reduce(0, +)
    }

    public var averageSuccessRate: Float {
        let rates = usageByModel.values.map { $0.successRate }
        guard !rates.isEmpty else { return 0 }
        return rates.reduce(0, +) / Float(rates.count)
    }

    // MARK: - Private Helpers

    private func classifyComplexity(task: String, taskType: String) -> TaskComplexity {
        let lowercased = task.lowercased()

        // Expert tasks
        if lowercased.contains("architect") || lowercased.contains("design system") ||
           lowercased.contains("research") && lowercased.contains("comprehensive") {
            return .expert
        }

        // Complex tasks
        if lowercased.contains("implement") || lowercased.contains("refactor") ||
           lowercased.contains("analyze") && task.count > 200 {
            return .complex
        }

        // Simple tasks
        if lowercased.contains("format") || lowercased.contains("fix typo") ||
           task.count < 50 {
            return .simple
        }

        // Trivial tasks
        if lowercased.contains("what is") || lowercased.contains("define") {
            return .trivial
        }

        return .moderate
    }

    private func scoreModel(
        model: RouterModelCapability,
        complexity: TaskComplexity,
        strategy: RoutingStrategy,
        estimatedInputTokens: Int
    ) -> Float {
        var score: Float = 0.5

        switch strategy {
        case .costOptimized:
            // Lower cost = higher score
            let maxCost = availableModels.map { $0.costPerInputToken }.max() ?? 1.0
            score = 1.0 - Float(model.costPerInputToken / maxCost)

        case .qualityOptimized:
            score = model.qualityScore

        case .speedOptimized:
            // Lower latency = higher score
            let maxLatency = availableModels.map { $0.averageLatency }.max() ?? 1.0
            score = 1.0 - Float(model.averageLatency / maxLatency)

        case .balanced:
            // Balance all factors
            let maxCost = availableModels.map { $0.costPerInputToken }.max() ?? 1.0
            let maxLatency = availableModels.map { $0.averageLatency }.max() ?? 1.0

            let costScore = 1.0 - Float(model.costPerInputToken / maxCost)
            let latencyScore = 1.0 - Float(model.averageLatency / maxLatency)

            score = (model.qualityScore * 0.4 + costScore * 0.3 + latencyScore * 0.3)

        case .cascadeFallback, .planAndExecute:
            // These are handled separately
            score = model.qualityScore

        case .localFirst:
            if model.isLocalModel {
                score = 0.8 + model.qualityScore * 0.2
            } else {
                score = model.qualityScore * 0.5
            }
        }

        // Adjust for complexity match
        switch complexity {
        case .trivial, .simple:
            if model.capabilities.contains(.lowCost) {
                score += 0.1
            }
        case .complex, .expert:
            if model.capabilities.contains(.highQuality) || model.capabilities.contains(.reasoning) {
                score += 0.1
            }
        case .moderate:
            break
        }

        return min(1.0, max(0.0, score))
    }

    private func estimateCost(model: RouterModelCapability, inputTokens: Int, outputTokens: Int) -> Double {
        (Double(inputTokens) * model.costPerInputToken +
         Double(outputTokens) * model.costPerOutputToken) / 1_000_000
    }

    private func generateReasoning(
        strategy: RoutingStrategy,
        model: RouterModelCapability,
        complexity: TaskComplexity
    ) -> String {
        switch strategy {
        case .costOptimized:
            return "Selected \(model.modelId) for lowest cost ($\(String(format: "%.2f", model.costPerInputToken))/1M tokens)"
        case .qualityOptimized:
            return "Selected \(model.modelId) for highest quality (score: \(String(format: "%.1f", model.qualityScore * 100))%)"
        case .speedOptimized:
            return "Selected \(model.modelId) for fastest response (\(String(format: "%.1f", model.averageLatency))s average)"
        case .balanced:
            return "Selected \(model.modelId) as best balance of quality, cost, and speed for \(complexity.rawValue) task"
        case .cascadeFallback:
            return "Using cascade fallback starting with \(model.modelId)"
        case .planAndExecute:
            return "Using plan-and-execute pattern with \(model.modelId)"
        case .localFirst:
            let locality = model.isLocalModel ? "local" : "remote"
            return "Selected \(model.modelId) (\(locality) model)"
        }
    }

    // setupDefaultModels() is in SmartModelRouter+ModelCatalog.swift

    // MARK: - Persistence

    private func loadUsage() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            let state = try JSONDecoder().decode(UsageState.self, from: data)
            self.usageByModel = state.usageByModel
            self.dailySpent = state.dailySpent
            logger.info("Loaded model usage: $\(String(format: "%.2f", self.totalSpent)) total spent")
        } catch {
            logger.error("Failed to load usage: \(error.localizedDescription)")
        }
    }

    private func saveUsage() {
        do {
            let state = UsageState(usageByModel: usageByModel, dailySpent: dailySpent)
            let data = try JSONEncoder().encode(state)
            try data.write(to: storageURL)
        } catch {
            logger.error("Failed to save usage: \(error.localizedDescription)")
        }
    }
}

private struct UsageState: Codable {
    let usageByModel: [String: ModelUsage]
    let dailySpent: Double
}
