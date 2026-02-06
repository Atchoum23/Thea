// SmartModelRouter.swift
// Thea V2
//
// Intelligent model routing with cost optimization and capability matching
// Implements Plan-and-Execute pattern, cascade fallback, and batch optimization

import Foundation
import OSLog

// MARK: - Model Capability

/// Capabilities of an AI model
public struct RouterModelCapability: Sendable {
    public let modelId: String
    public let provider: String
    public let contextWindow: Int
    public let maxOutputTokens: Int
    public let capabilities: Set<Capability>
    public let costPerInputToken: Double   // USD per 1M tokens
    public let costPerOutputToken: Double  // USD per 1M tokens
    public let averageLatency: TimeInterval // seconds
    public let qualityScore: Float          // 0.0 - 1.0
    public let isLocalModel: Bool

    public init(
        modelId: String,
        provider: String,
        contextWindow: Int,
        maxOutputTokens: Int,
        capabilities: Set<Capability>,
        costPerInputToken: Double,
        costPerOutputToken: Double,
        averageLatency: TimeInterval,
        qualityScore: Float,
        isLocalModel: Bool = false
    ) {
        self.modelId = modelId
        self.provider = provider
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.capabilities = capabilities
        self.costPerInputToken = costPerInputToken
        self.costPerOutputToken = costPerOutputToken
        self.averageLatency = averageLatency
        self.qualityScore = qualityScore
        self.isLocalModel = isLocalModel
    }

    public enum Capability: String, Sendable {
        case textGeneration
        case codeGeneration
        case reasoning
        case analysis
        case creative
        case vision
        case audio
        case functionCalling
        case structuredOutput
        case streaming
        case longContext
        case fastResponse
        case lowCost
        case highQuality
    }
}

// MARK: - Routing Decision

/// A model routing decision
public struct SmartRoutingDecision: Sendable {
    public let taskId: UUID
    public let taskType: TaskComplexity
    public let selectedModel: RouterModelCapability
    public let alternativeModels: [RouterModelCapability]
    public let estimatedCost: Double
    public let estimatedLatency: TimeInterval
    public let confidence: Float
    public let reasoning: String
    public let strategy: RoutingStrategy

    public init(
        taskId: UUID = UUID(),
        taskType: TaskComplexity,
        selectedModel: RouterModelCapability,
        alternativeModels: [RouterModelCapability] = [],
        estimatedCost: Double,
        estimatedLatency: TimeInterval,
        confidence: Float,
        reasoning: String,
        strategy: RoutingStrategy
    ) {
        self.taskId = taskId
        self.taskType = taskType
        self.selectedModel = selectedModel
        self.alternativeModels = alternativeModels
        self.estimatedCost = estimatedCost
        self.estimatedLatency = estimatedLatency
        self.confidence = confidence
        self.reasoning = reasoning
        self.strategy = strategy
    }
}

public enum TaskComplexity: String, Codable, Sendable {
    case trivial     // Simple lookup, formatting
    case simple      // Basic Q&A, short generation
    case moderate    // Standard coding, analysis
    case complex     // Multi-step reasoning, architecture
    case expert      // Novel problems, deep research
}

public enum RoutingStrategy: String, Sendable {
    case costOptimized      // Minimize cost
    case qualityOptimized   // Maximize quality
    case speedOptimized     // Minimize latency
    case balanced           // Balance all factors
    case cascadeFallback    // Try cheap first, escalate
    case planAndExecute     // Expensive plans, cheap executes
    case localFirst         // Prefer local models
}

// MARK: - Plan and Execute

/// Plan-and-Execute pattern configuration
public struct PlanExecuteConfig: Sendable {
    public let planningModel: RouterModelCapability
    public let executionModel: RouterModelCapability
    public let verificationModel: RouterModelCapability?
    public let maxExecutionSteps: Int

    public init(
        planningModel: RouterModelCapability,
        executionModel: RouterModelCapability,
        verificationModel: RouterModelCapability? = nil,
        maxExecutionSteps: Int = 10
    ) {
        self.planningModel = planningModel
        self.executionModel = executionModel
        self.verificationModel = verificationModel
        self.maxExecutionSteps = maxExecutionSteps
    }
}

// MARK: - Cascade Config

/// Cascade fallback configuration
public struct CascadeConfig: Sendable {
    public let models: [RouterModelCapability]  // Ordered from cheapest to most expensive
    public let confidenceThreshold: Float  // Confidence needed to accept result
    public let maxAttempts: Int

    public init(
        models: [RouterModelCapability],
        confidenceThreshold: Float = 0.7,
        maxAttempts: Int = 3
    ) {
        self.models = models
        self.confidenceThreshold = confidenceThreshold
        self.maxAttempts = maxAttempts
    }
}

// MARK: - Batch Request

/// A batch of requests for batch optimization
public struct BatchRequest: Identifiable, Sendable {
    public let id: UUID
    public let requests: [SingleRequest]
    public let priority: BatchPriority
    public let deadline: Date?

    public init(
        id: UUID = UUID(),
        requests: [SingleRequest],
        priority: BatchPriority = .normal,
        deadline: Date? = nil
    ) {
        self.id = id
        self.requests = requests
        self.priority = priority
        self.deadline = deadline
    }

    public struct SingleRequest: Identifiable, Sendable {
        public let id: UUID
        public let prompt: String
        public let taskType: String
        public let maxTokens: Int

        public init(
            id: UUID = UUID(),
            prompt: String,
            taskType: String,
            maxTokens: Int = 1000
        ) {
            self.id = id
            self.prompt = prompt
            self.taskType = taskType
            self.maxTokens = maxTokens
        }
    }

    public enum BatchPriority: Int, Sendable {
        case low = 0
        case normal = 50
        case high = 100
    }
}

// MARK: - Usage Tracking

/// Track model usage for cost monitoring
public struct ModelUsage: Codable, Sendable {
    public var totalInputTokens: Int
    public var totalOutputTokens: Int
    public var totalCost: Double
    public var requestCount: Int
    public var totalLatency: TimeInterval
    public var successCount: Int
    public var failureCount: Int

    public init() {
        self.totalInputTokens = 0
        self.totalOutputTokens = 0
        self.totalCost = 0
        self.requestCount = 0
        self.totalLatency = 0
        self.successCount = 0
        self.failureCount = 0
    }

    public var averageLatency: TimeInterval {
        guard requestCount > 0 else { return 0 }
        return totalLatency / Double(requestCount)
    }

    public var successRate: Float {
        guard requestCount > 0 else { return 0 }
        return Float(successCount) / Float(requestCount)
    }

    public mutating func record(
        inputTokens: Int,
        outputTokens: Int,
        cost: Double,
        latency: TimeInterval,
        success: Bool
    ) {
        totalInputTokens += inputTokens
        totalOutputTokens += outputTokens
        totalCost += cost
        requestCount += 1
        totalLatency += latency
        if success {
            successCount += 1
        } else {
            failureCount += 1
        }
    }
}

// MARK: - Smart Model Router

/// Intelligent model routing engine
@MainActor
public final class SmartModelRouter: ObservableObject, Sendable {
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
            let cheapest = availableModels.min { $0.costPerInputToken < $1.costPerInputToken }
            return SmartRoutingDecision(
                taskType: complexity,
                selectedModel: cheapest ?? availableModels.first!,
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

        let selected = scoredCandidates.first!.0
        let alternatives = scoredCandidates.dropFirst().prefix(3).map { $0.0 }

        let estimatedCost = estimateCost(model: selected, inputTokens: estimatedInputTokens, outputTokens: 1000)
        let estimatedLatency = selected.averageLatency

        return SmartRoutingDecision(
            taskType: complexity,
            selectedModel: selected,
            alternativeModels: Array(alternatives),
            estimatedCost: estimatedCost,
            estimatedLatency: estimatedLatency,
            confidence: scoredCandidates.first!.1,
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

    private func setupDefaultModels() {
        // Claude models
        registerModel(RouterModelCapability(
            modelId: "claude-opus-4",
            provider: "anthropic",
            contextWindow: 200000,
            maxOutputTokens: 32000,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .creative, .vision, .functionCalling, .structuredOutput, .streaming, .longContext, .highQuality],
            costPerInputToken: 15.0,
            costPerOutputToken: 75.0,
            averageLatency: 3.0,
            qualityScore: 0.95
        ))

        registerModel(RouterModelCapability(
            modelId: "claude-sonnet-4",
            provider: "anthropic",
            contextWindow: 200000,
            maxOutputTokens: 64000,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .creative, .vision, .functionCalling, .structuredOutput, .streaming, .longContext],
            costPerInputToken: 3.0,
            costPerOutputToken: 15.0,
            averageLatency: 1.5,
            qualityScore: 0.85
        ))

        registerModel(RouterModelCapability(
            modelId: "claude-haiku-3.5",
            provider: "anthropic",
            contextWindow: 200000,
            maxOutputTokens: 8192,
            capabilities: [.textGeneration, .codeGeneration, .analysis, .functionCalling, .streaming, .longContext, .fastResponse, .lowCost],
            costPerInputToken: 0.25,
            costPerOutputToken: 1.25,
            averageLatency: 0.5,
            qualityScore: 0.70
        ))

        // OpenAI models
        registerModel(RouterModelCapability(
            modelId: "gpt-4o",
            provider: "openai",
            contextWindow: 128000,
            maxOutputTokens: 16384,
            capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .creative, .vision, .audio, .functionCalling, .structuredOutput, .streaming],
            costPerInputToken: 2.5,
            costPerOutputToken: 10.0,
            averageLatency: 1.2,
            qualityScore: 0.88
        ))

        registerModel(RouterModelCapability(
            modelId: "gpt-4o-mini",
            provider: "openai",
            contextWindow: 128000,
            maxOutputTokens: 16384,
            capabilities: [.textGeneration, .codeGeneration, .analysis, .vision, .functionCalling, .streaming, .fastResponse, .lowCost],
            costPerInputToken: 0.15,
            costPerOutputToken: 0.60,
            averageLatency: 0.4,
            qualityScore: 0.72
        ))

        // Gemini models
        registerModel(RouterModelCapability(
            modelId: "gemini-2.0-flash",
            provider: "google",
            contextWindow: 1000000,
            maxOutputTokens: 8192,
            capabilities: [.textGeneration, .codeGeneration, .analysis, .vision, .audio, .functionCalling, .streaming, .longContext, .fastResponse, .lowCost],
            costPerInputToken: 0.075,
            costPerOutputToken: 0.30,
            averageLatency: 0.3,
            qualityScore: 0.75
        ))

        // Local models placeholder
        registerModel(RouterModelCapability(
            modelId: "local-llama",
            provider: "local",
            contextWindow: 8192,
            maxOutputTokens: 4096,
            capabilities: [.textGeneration, .codeGeneration, .analysis, .streaming],
            costPerInputToken: 0,
            costPerOutputToken: 0,
            averageLatency: 2.0,
            qualityScore: 0.60,
            isLocalModel: true
        ))
    }

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
