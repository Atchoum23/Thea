// SmartModelRouterLogicTests.swift
// Tests for SmartModelRouter service logic: routing strategies, capability filtering,
// cost estimation, complexity classification, scoring, and fallback behavior.

import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Intelligence/Routing/SmartModelRouter.swift)

private enum SMRCapability: String, Sendable, Hashable {
    case textGeneration, codeGeneration, reasoning, analysis, creative
    case vision, audio, functionCalling, structuredOutput, streaming
    case longContext, fastResponse, lowCost, highQuality
}

private struct SMRModelCapability: Sendable {
    let modelId: String
    let provider: String
    let contextWindow: Int
    let maxOutputTokens: Int
    let capabilities: Set<SMRCapability>
    let costPerInputToken: Double   // USD per 1M tokens
    let costPerOutputToken: Double  // USD per 1M tokens
    let averageLatency: TimeInterval
    let qualityScore: Float         // 0.0 - 1.0
    let isLocalModel: Bool
}

private enum SMRTaskComplexity: String, Sendable {
    case trivial, simple, moderate, complex, expert
}

private enum SMRRoutingStrategy: String, Sendable {
    case costOptimized, qualityOptimized, speedOptimized, balanced
    case cascadeFallback, planAndExecute, localFirst
}

private struct SMRRoutingDecision: Sendable {
    let taskType: SMRTaskComplexity
    let selectedModel: SMRModelCapability
    let alternativeModels: [SMRModelCapability]
    let estimatedCost: Double
    let estimatedLatency: TimeInterval
    let confidence: Float
    let reasoning: String
    let strategy: SMRRoutingStrategy
}

private struct SMRModelUsage: Sendable {
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalCost: Double = 0
    var requestCount: Int = 0
    var totalLatency: TimeInterval = 0
    var successCount: Int = 0
    var failureCount: Int = 0

    var averageLatency: TimeInterval {
        guard requestCount > 0 else { return 0 }
        return totalLatency / Double(requestCount)
    }

    var successRate: Float {
        guard requestCount > 0 else { return 0 }
        return Float(successCount) / Float(requestCount)
    }

    mutating func record(inputTokens: Int, outputTokens: Int, cost: Double, latency: TimeInterval, success: Bool) {
        totalInputTokens += inputTokens
        totalOutputTokens += outputTokens
        totalCost += cost
        requestCount += 1
        totalLatency += latency
        if success { successCount += 1 } else { failureCount += 1 }
    }
}

// MARK: - Router Logic (mirrors production SmartModelRouter+Core.swift)

// @unchecked Sendable: test helper class, single-threaded test context
private final class TestSmartModelRouter: @unchecked Sendable {
    var availableModels: [SMRModelCapability] = []
    var dailyBudget: Double = 10.0
    var dailySpent: Double = 0.0
    var defaultStrategy: SMRRoutingStrategy = .balanced
    var usageByModel: [String: SMRModelUsage] = [:]

    func registerModel(_ model: SMRModelCapability) {
        if !availableModels.contains(where: { $0.modelId == model.modelId }) {
            availableModels.append(model)
        }
    }

    func removeModel(modelId: String) {
        availableModels.removeAll { $0.modelId == modelId }
    }

    func route(
        task: String,
        taskType: String,
        requiredCapabilities: Set<SMRCapability> = [],
        strategy: SMRRoutingStrategy? = nil,
        estimatedInputTokens: Int = 1000,
        maxCost: Double? = nil
    ) -> SMRRoutingDecision {
        let strategy = strategy ?? defaultStrategy
        let complexity = classifyComplexity(task: task, taskType: taskType)

        var candidates = availableModels.filter { model in
            requiredCapabilities.isSubset(of: model.capabilities)
        }

        if let maxCost = maxCost {
            candidates = candidates.filter { model in
                estimateCost(model: model, inputTokens: estimatedInputTokens, outputTokens: 1000) <= maxCost
            }
        }

        let remainingBudget = dailyBudget - dailySpent
        candidates = candidates.filter { model in
            estimateCost(model: model, inputTokens: estimatedInputTokens, outputTokens: 1000) <= remainingBudget
        }

        guard !candidates.isEmpty else {
            guard let fallbackModel = availableModels.min(by: { $0.costPerInputToken < $1.costPerInputToken }) ?? availableModels.first else {
                let emptyModel = SMRModelCapability(
                    modelId: "none", provider: "none", contextWindow: 0, maxOutputTokens: 0,
                    capabilities: [], costPerInputToken: 0, costPerOutputToken: 0,
                    averageLatency: 0, qualityScore: 0, isLocalModel: false
                )
                return SMRRoutingDecision(
                    taskType: complexity, selectedModel: emptyModel, alternativeModels: [],
                    estimatedCost: 0, estimatedLatency: 1.0, confidence: 0.0,
                    reasoning: "No models available", strategy: strategy
                )
            }
            return SMRRoutingDecision(
                taskType: complexity, selectedModel: fallbackModel, alternativeModels: [],
                estimatedCost: 0, estimatedLatency: 1.0, confidence: 0.3,
                reasoning: "Budget exhausted, using cheapest model", strategy: strategy
            )
        }

        let scoredCandidates = candidates.map { model -> (SMRModelCapability, Float) in
            let score = scoreModel(model: model, complexity: complexity, strategy: strategy, estimatedInputTokens: estimatedInputTokens)
            return (model, score)
        }.sorted { $0.1 > $1.1 }

        let best = scoredCandidates[0]
        let selected = best.0
        let alternatives = scoredCandidates.dropFirst().prefix(3).map { $0.0 }

        let estimatedCost = estimateCost(model: selected, inputTokens: estimatedInputTokens, outputTokens: 1000)

        return SMRRoutingDecision(
            taskType: complexity, selectedModel: selected, alternativeModels: Array(alternatives),
            estimatedCost: estimatedCost, estimatedLatency: selected.averageLatency,
            confidence: best.1, reasoning: "Selected \(selected.modelId)", strategy: strategy
        )
    }

    func classifyComplexity(task: String, taskType: String) -> SMRTaskComplexity {
        let lowercased = task.lowercased()

        if lowercased.contains("architect") || lowercased.contains("design system") ||
           lowercased.contains("research") && lowercased.contains("comprehensive") {
            return .expert
        }
        if lowercased.contains("implement") || lowercased.contains("refactor") ||
           lowercased.contains("analyze") && task.count > 200 {
            return .complex
        }
        if lowercased.contains("format") || lowercased.contains("fix typo") || task.count < 50 {
            return .simple
        }
        if lowercased.contains("what is") || lowercased.contains("define") {
            return .trivial
        }
        return .moderate
    }

    func scoreModel(
        model: SMRModelCapability,
        complexity: SMRTaskComplexity,
        strategy: SMRRoutingStrategy,
        estimatedInputTokens: Int
    ) -> Float {
        var score: Float = 0.5

        switch strategy {
        case .costOptimized:
            let maxCost = availableModels.map { $0.costPerInputToken }.max() ?? 1.0
            score = 1.0 - Float(model.costPerInputToken / maxCost)

        case .qualityOptimized:
            score = model.qualityScore

        case .speedOptimized:
            let maxLatency = availableModels.map { $0.averageLatency }.max() ?? 1.0
            score = 1.0 - Float(model.averageLatency / maxLatency)

        case .balanced:
            let maxCost = availableModels.map { $0.costPerInputToken }.max() ?? 1.0
            let maxLatency = availableModels.map { $0.averageLatency }.max() ?? 1.0
            let costScore = 1.0 - Float(model.costPerInputToken / maxCost)
            let latencyScore = 1.0 - Float(model.averageLatency / maxLatency)
            score = (model.qualityScore * 0.4 + costScore * 0.3 + latencyScore * 0.3)

        case .cascadeFallback, .planAndExecute:
            score = model.qualityScore

        case .localFirst:
            if model.isLocalModel {
                score = 0.8 + model.qualityScore * 0.2
            } else {
                score = model.qualityScore * 0.5
            }
        }

        switch complexity {
        case .trivial, .simple:
            if model.capabilities.contains(.lowCost) { score += 0.1 }
        case .complex, .expert:
            if model.capabilities.contains(.highQuality) || model.capabilities.contains(.reasoning) { score += 0.1 }
        case .moderate:
            break
        }

        return min(1.0, max(0.0, score))
    }

    func estimateCost(model: SMRModelCapability, inputTokens: Int, outputTokens: Int) -> Double {
        (Double(inputTokens) * model.costPerInputToken +
         Double(outputTokens) * model.costPerOutputToken) / 1_000_000
    }

    func recordUsage(modelId: String, inputTokens: Int, outputTokens: Int, latency: TimeInterval, success: Bool) {
        var usage = usageByModel[modelId] ?? SMRModelUsage()
        guard let model = availableModels.first(where: { $0.modelId == modelId }) else { return }
        let cost = (Double(inputTokens) * model.costPerInputToken + Double(outputTokens) * model.costPerOutputToken) / 1_000_000
        usage.record(inputTokens: inputTokens, outputTokens: outputTokens, cost: cost, latency: latency, success: success)
        usageByModel[modelId] = usage
        dailySpent += cost
    }

    var totalSpent: Double {
        usageByModel.values.map { $0.totalCost }.reduce(0, +)
    }

    var totalTokensUsed: Int {
        usageByModel.values.map { $0.totalInputTokens + $0.totalOutputTokens }.reduce(0, +)
    }
}

// MARK: - Test Fixtures

private func makeModel(
    id: String, provider: String = "test",
    capabilities: Set<SMRCapability> = [.textGeneration],
    costPerInput: Double = 1.0, costPerOutput: Double = 2.0,
    latency: TimeInterval = 1.0, quality: Float = 0.5,
    isLocal: Bool = false
) -> SMRModelCapability {
    SMRModelCapability(
        modelId: id, provider: provider, contextWindow: 128000, maxOutputTokens: 4096,
        capabilities: capabilities, costPerInputToken: costPerInput, costPerOutputToken: costPerOutput,
        averageLatency: latency, qualityScore: quality, isLocalModel: isLocal
    )
}

private func makeRouter(with models: [SMRModelCapability]) -> TestSmartModelRouter {
    let router = TestSmartModelRouter()
    for m in models { router.registerModel(m) }
    return router
}

// MARK: - Tests: Cost-Optimized Routing

@Suite("SmartModelRouter — Cost-Optimized Routing")
struct SMRCostOptimizedTests {
    @Test("Selects cheapest model when cost-optimized")
    func selectsCheapest() {
        let cheap = makeModel(id: "cheap", costPerInput: 0.5, costPerOutput: 1.0, quality: 0.3)
        let expensive = makeModel(id: "expensive", costPerInput: 10.0, costPerOutput: 20.0, quality: 0.9)
        let router = makeRouter(with: [expensive, cheap])

        let decision = router.route(task: "test task something moderate", taskType: "general", strategy: .costOptimized)
        #expect(decision.selectedModel.modelId == "cheap")
    }

    @Test("Cost estimate accounts for input and output tokens")
    func costEstimate() {
        let model = makeModel(id: "test", costPerInput: 3.0, costPerOutput: 15.0)
        let router = TestSmartModelRouter()
        let cost = router.estimateCost(model: model, inputTokens: 1000, outputTokens: 500)
        // (1000 * 3.0 + 500 * 15.0) / 1_000_000 = (3000 + 7500) / 1_000_000 = 0.0105
        #expect(abs(cost - 0.0105) < 0.0001)
    }

    @Test("Free model has zero cost estimate")
    func freeCost() {
        let model = makeModel(id: "free", costPerInput: 0.0, costPerOutput: 0.0)
        let router = TestSmartModelRouter()
        let cost = router.estimateCost(model: model, inputTokens: 10000, outputTokens: 5000)
        #expect(cost == 0.0)
    }

    @Test("MaxCost filter excludes expensive models")
    func maxCostFilter() {
        let cheap = makeModel(id: "cheap", costPerInput: 0.1, costPerOutput: 0.2)
        let expensive = makeModel(id: "expensive", costPerInput: 100.0, costPerOutput: 200.0, quality: 0.99)
        let router = makeRouter(with: [cheap, expensive])

        let decision = router.route(task: "test task something moderate", taskType: "general", strategy: .qualityOptimized, maxCost: 0.001)
        // Expensive model exceeds maxCost, so cheap is the only candidate
        #expect(decision.selectedModel.modelId == "cheap")
    }
}

// MARK: - Tests: Quality-Optimized Routing

@Suite("SmartModelRouter — Quality-Optimized Routing")
struct SMRQualityOptimizedTests {
    @Test("Selects highest quality model when quality-optimized")
    func selectsHighestQuality() {
        let low = makeModel(id: "low", costPerInput: 0.5, quality: 0.3)
        let high = makeModel(id: "high", costPerInput: 5.0, quality: 0.95)
        let mid = makeModel(id: "mid", costPerInput: 2.0, quality: 0.6)
        let router = makeRouter(with: [low, mid, high])

        let decision = router.route(task: "test task something moderate", taskType: "general", strategy: .qualityOptimized)
        #expect(decision.selectedModel.modelId == "high")
    }

    @Test("Quality score is used directly as score")
    func qualityScoreDirectly() {
        let model = makeModel(id: "test", quality: 0.85)
        let router = makeRouter(with: [model])
        let score = router.scoreModel(model: model, complexity: .moderate, strategy: .qualityOptimized, estimatedInputTokens: 1000)
        #expect(abs(score - 0.85) < 0.001)
    }
}

// MARK: - Tests: Speed-Optimized Routing

@Suite("SmartModelRouter — Speed-Optimized Routing")
struct SMRSpeedOptimizedTests {
    @Test("Selects fastest model when speed-optimized")
    func selectsFastest() {
        let slow = makeModel(id: "slow", latency: 5.0, quality: 0.9)
        let fast = makeModel(id: "fast", latency: 0.5, quality: 0.5)
        let router = makeRouter(with: [slow, fast])

        let decision = router.route(task: "test task something moderate", taskType: "general", strategy: .speedOptimized)
        #expect(decision.selectedModel.modelId == "fast")
    }

    @Test("Latency score: lower latency = higher score")
    func latencyScoring() {
        let fast = makeModel(id: "fast", latency: 0.1)
        let slow = makeModel(id: "slow", latency: 10.0)
        let router = makeRouter(with: [fast, slow])

        let fastScore = router.scoreModel(model: fast, complexity: .moderate, strategy: .speedOptimized, estimatedInputTokens: 1000)
        let slowScore = router.scoreModel(model: slow, complexity: .moderate, strategy: .speedOptimized, estimatedInputTokens: 1000)
        #expect(fastScore > slowScore)
    }
}

// MARK: - Tests: Balanced Routing

@Suite("SmartModelRouter — Balanced Routing")
struct SMRBalancedTests {
    @Test("Balanced strategy considers quality, cost, and speed")
    func balancedConsidersAll() {
        // A model that's great at everything should win
        let allAround = makeModel(id: "balanced", costPerInput: 1.0, latency: 1.0, quality: 0.8)
        // Great quality but expensive and slow
        let qualityOnly = makeModel(id: "quality", costPerInput: 100.0, latency: 10.0, quality: 0.95)
        let router = makeRouter(with: [allAround, qualityOnly])

        let decision = router.route(task: "test task something moderate", taskType: "general", strategy: .balanced)
        #expect(decision.selectedModel.modelId == "balanced")
    }

    @Test("Balanced score is weighted: 40% quality, 30% cost, 30% speed")
    func balancedWeights() {
        let m1 = makeModel(id: "m1", costPerInput: 5.0, latency: 5.0, quality: 0.8)
        let m2 = makeModel(id: "m2", costPerInput: 1.0, latency: 1.0, quality: 0.4)
        let router = makeRouter(with: [m1, m2])

        let s1 = router.scoreModel(model: m1, complexity: .moderate, strategy: .balanced, estimatedInputTokens: 1000)
        let s2 = router.scoreModel(model: m2, complexity: .moderate, strategy: .balanced, estimatedInputTokens: 1000)

        // m1: quality=0.8, costScore=1-5/5=0, latencyScore=1-5/5=0 => 0.8*0.4 + 0*0.3 + 0*0.3 = 0.32
        // m2: quality=0.4, costScore=1-1/5=0.8, latencyScore=1-1/5=0.8 => 0.4*0.4 + 0.8*0.3 + 0.8*0.3 = 0.16+0.24+0.24 = 0.64
        #expect(abs(s1 - 0.32) < 0.01)
        #expect(abs(s2 - 0.64) < 0.01)
        #expect(s2 > s1)
    }
}

// MARK: - Tests: Capability Filtering

@Suite("SmartModelRouter — Capability Filtering")
struct SMRCapabilityFilterTests {
    @Test("Only models with required capabilities are considered")
    func filtersCapabilities() {
        let textOnly = makeModel(id: "text", capabilities: [.textGeneration])
        let visionModel = makeModel(id: "vision", capabilities: [.textGeneration, .vision], quality: 0.5)
        let router = makeRouter(with: [textOnly, visionModel])

        let decision = router.route(
            task: "describe this image in moderate detail",
            taskType: "vision",
            requiredCapabilities: [.vision],
            strategy: .qualityOptimized
        )
        #expect(decision.selectedModel.modelId == "vision")
    }

    @Test("No matching capabilities falls back to cheapest")
    func noMatchFallback() {
        let text = makeModel(id: "text", capabilities: [.textGeneration], costPerInput: 1.0)
        let code = makeModel(id: "code", capabilities: [.codeGeneration], costPerInput: 2.0)
        let router = makeRouter(with: [text, code])

        let decision = router.route(
            task: "use audio capabilities for this moderate task",
            taskType: "audio",
            requiredCapabilities: [.audio]
        )
        // No model has audio, falls back to cheapest
        #expect(decision.selectedModel.modelId == "text")
        #expect(decision.confidence <= 0.3)
    }

    @Test("Multiple required capabilities narrows candidates")
    func multipleCapabilities() {
        let basic = makeModel(id: "basic", capabilities: [.textGeneration])
        let advanced = makeModel(id: "advanced", capabilities: [.textGeneration, .codeGeneration, .reasoning], quality: 0.8)
        let partial = makeModel(id: "partial", capabilities: [.textGeneration, .codeGeneration], quality: 0.9)
        let router = makeRouter(with: [basic, advanced, partial])

        let decision = router.route(
            task: "implement and reason about this moderate task",
            taskType: "code",
            requiredCapabilities: [.codeGeneration, .reasoning],
            strategy: .qualityOptimized
        )
        // Only "advanced" has both codeGeneration and reasoning
        #expect(decision.selectedModel.modelId == "advanced")
    }

    @Test("Empty required capabilities matches all models")
    func emptyCapabilities() {
        let m1 = makeModel(id: "m1", quality: 0.3)
        let m2 = makeModel(id: "m2", quality: 0.9)
        let router = makeRouter(with: [m1, m2])

        let decision = router.route(task: "anything moderate in scope", taskType: "general", requiredCapabilities: [], strategy: .qualityOptimized)
        #expect(decision.selectedModel.modelId == "m2")
    }
}

// MARK: - Tests: Fallback Behavior

@Suite("SmartModelRouter — Fallback Behavior")
struct SMRFallbackTests {
    @Test("No models available returns zero confidence empty decision")
    func noModelsAvailable() {
        let router = TestSmartModelRouter()
        let decision = router.route(task: "test moderate task something", taskType: "general")
        #expect(decision.selectedModel.modelId == "none")
        #expect(decision.confidence == 0.0)
        #expect(decision.reasoning.contains("No models available"))
    }

    @Test("Budget exhausted falls back to cheapest model")
    func budgetExhausted() {
        let cheap = makeModel(id: "cheap", costPerInput: 0.5, costPerOutput: 1.0)
        let mid = makeModel(id: "mid", costPerInput: 5.0, costPerOutput: 10.0, quality: 0.8)
        let router = makeRouter(with: [cheap, mid])
        router.dailyBudget = 10.0
        router.dailySpent = 9.99999 // Almost exhausted

        let decision = router.route(task: "test moderate task something", taskType: "general")
        #expect(decision.confidence <= 0.3)
        #expect(decision.reasoning.contains("Budget exhausted") || decision.selectedModel.modelId == "cheap")
    }

    @Test("Alternatives are provided up to 3")
    func alternativesProvided() {
        let models = (1...5).map { i in
            makeModel(id: "model\(i)", quality: Float(i) * 0.15)
        }
        let router = makeRouter(with: models)
        let decision = router.route(task: "test moderate task something", taskType: "general", strategy: .qualityOptimized)
        #expect(decision.alternativeModels.count <= 3)
    }

    @Test("Single model returns it with no alternatives")
    func singleModel() {
        let model = makeModel(id: "only")
        let router = makeRouter(with: [model])
        let decision = router.route(task: "test moderate task something", taskType: "general")
        #expect(decision.selectedModel.modelId == "only")
        #expect(decision.alternativeModels.isEmpty)
    }
}

// MARK: - Tests: Complexity Classification

@Suite("SmartModelRouter — Complexity Classification")
struct SMRComplexityTests {
    @Test("Architecture tasks are expert")
    func architectExpert() {
        let router = TestSmartModelRouter()
        #expect(router.classifyComplexity(task: "architect a new system", taskType: "design") == .expert)
    }

    @Test("Design system tasks are expert")
    func designSystemExpert() {
        let router = TestSmartModelRouter()
        #expect(router.classifyComplexity(task: "design system for the app", taskType: "design") == .expert)
    }

    @Test("Comprehensive research is expert")
    func comprehensiveResearchExpert() {
        let router = TestSmartModelRouter()
        #expect(router.classifyComplexity(task: "comprehensive research on AI safety", taskType: "research") == .expert)
    }

    @Test("Implementation tasks are complex")
    func implementComplex() {
        let router = TestSmartModelRouter()
        #expect(router.classifyComplexity(task: "implement the new authentication module", taskType: "code") == .complex)
    }

    @Test("Refactor tasks are complex")
    func refactorComplex() {
        let router = TestSmartModelRouter()
        #expect(router.classifyComplexity(task: "refactor the database layer", taskType: "code") == .complex)
    }

    @Test("Format tasks are simple")
    func formatSimple() {
        let router = TestSmartModelRouter()
        #expect(router.classifyComplexity(task: "format this code", taskType: "code") == .simple)
    }

    @Test("Fix typo tasks are simple")
    func fixTypoSimple() {
        let router = TestSmartModelRouter()
        #expect(router.classifyComplexity(task: "fix typo in the readme", taskType: "edit") == .simple)
    }

    @Test("Short tasks are simple")
    func shortTaskSimple() {
        let router = TestSmartModelRouter()
        #expect(router.classifyComplexity(task: "hello", taskType: "chat") == .simple)
    }

    @Test("Definition queries are trivial")
    func defineTrivial() {
        let router = TestSmartModelRouter()
        #expect(router.classifyComplexity(task: "define polymorphism in detail for me please", taskType: "info") == .trivial)
    }

    @Test("What-is queries are trivial")
    func whatIsTrivial() {
        let router = TestSmartModelRouter()
        #expect(router.classifyComplexity(task: "what is a closure in Swift programming language here", taskType: "info") == .trivial)
    }

    @Test("Generic moderate-length tasks are moderate")
    func genericModerate() {
        let router = TestSmartModelRouter()
        let task = "explain the differences between synchronous and asynchronous programming patterns in modern applications"
        #expect(router.classifyComplexity(task: task, taskType: "general") == .moderate)
    }
}

// MARK: - Tests: Local-First Strategy

@Suite("SmartModelRouter — Local-First Strategy")
struct SMRLocalFirstTests {
    @Test("Local models get higher score in local-first mode")
    func localModelPreferred() {
        let local = makeModel(id: "local", quality: 0.6, isLocal: true)
        let cloud = makeModel(id: "cloud", quality: 0.9, isLocal: false)
        let router = makeRouter(with: [local, cloud])

        let decision = router.route(task: "test moderate task something", taskType: "general", strategy: .localFirst)
        #expect(decision.selectedModel.modelId == "local")
    }

    @Test("Local model score formula: 0.8 + quality * 0.2")
    func localScoreFormula() {
        let local = makeModel(id: "local", quality: 0.5, isLocal: true)
        let router = makeRouter(with: [local])
        let score = router.scoreModel(model: local, complexity: .moderate, strategy: .localFirst, estimatedInputTokens: 1000)
        // 0.8 + 0.5 * 0.2 = 0.9
        #expect(abs(score - 0.9) < 0.001)
    }

    @Test("Cloud model score formula in local-first: quality * 0.5")
    func cloudScoreInLocalFirst() {
        let cloud = makeModel(id: "cloud", quality: 0.8, isLocal: false)
        let router = makeRouter(with: [cloud])
        let score = router.scoreModel(model: cloud, complexity: .moderate, strategy: .localFirst, estimatedInputTokens: 1000)
        // 0.8 * 0.5 = 0.4
        #expect(abs(score - 0.4) < 0.001)
    }
}

// MARK: - Tests: Complexity Bonus

@Suite("SmartModelRouter — Complexity Score Adjustments")
struct SMRComplexityBonusTests {
    @Test("Low-cost capability gets bonus for trivial tasks")
    func lowCostBonusTrivial() {
        let model = makeModel(id: "cheap", capabilities: [.textGeneration, .lowCost], quality: 0.5)
        let router = makeRouter(with: [model])
        let score = router.scoreModel(model: model, complexity: .trivial, strategy: .qualityOptimized, estimatedInputTokens: 1000)
        // quality 0.5 + 0.1 bonus = 0.6
        #expect(abs(score - 0.6) < 0.001)
    }

    @Test("Reasoning capability gets bonus for expert tasks")
    func reasoningBonusExpert() {
        let model = makeModel(id: "smart", capabilities: [.textGeneration, .reasoning], quality: 0.8)
        let router = makeRouter(with: [model])
        let score = router.scoreModel(model: model, complexity: .expert, strategy: .qualityOptimized, estimatedInputTokens: 1000)
        // quality 0.8 + 0.1 bonus = 0.9
        #expect(abs(score - 0.9) < 0.001)
    }

    @Test("No bonus for moderate tasks")
    func noBonusModerate() {
        let model = makeModel(id: "test", capabilities: [.textGeneration, .lowCost, .highQuality, .reasoning], quality: 0.5)
        let router = makeRouter(with: [model])
        let score = router.scoreModel(model: model, complexity: .moderate, strategy: .qualityOptimized, estimatedInputTokens: 1000)
        #expect(abs(score - 0.5) < 0.001)
    }

    @Test("Score is clamped to 0.0-1.0")
    func scoreClamped() {
        let model = makeModel(id: "perfect", capabilities: [.textGeneration, .highQuality, .reasoning], quality: 0.99)
        let router = makeRouter(with: [model])
        let score = router.scoreModel(model: model, complexity: .expert, strategy: .qualityOptimized, estimatedInputTokens: 1000)
        // 0.99 + 0.1 = 1.09 => clamped to 1.0
        #expect(score <= 1.0)
    }
}

// MARK: - Tests: Usage Tracking

@Suite("SmartModelRouter — Usage Tracking")
struct SMRUsageTests {
    @Test("Recording usage updates model stats")
    func recordsUsage() {
        let model = makeModel(id: "test", costPerInput: 3.0, costPerOutput: 15.0)
        let router = makeRouter(with: [model])
        router.recordUsage(modelId: "test", inputTokens: 1000, outputTokens: 500, latency: 1.5, success: true)

        let usage = router.usageByModel["test"]!
        #expect(usage.totalInputTokens == 1000)
        #expect(usage.totalOutputTokens == 500)
        #expect(usage.requestCount == 1)
        #expect(usage.successCount == 1)
        #expect(abs(usage.totalLatency - 1.5) < 0.001)
    }

    @Test("Usage average latency calculated correctly")
    func averageLatency() {
        let model = makeModel(id: "test", costPerInput: 1.0, costPerOutput: 1.0)
        let router = makeRouter(with: [model])
        router.recordUsage(modelId: "test", inputTokens: 100, outputTokens: 50, latency: 1.0, success: true)
        router.recordUsage(modelId: "test", inputTokens: 100, outputTokens: 50, latency: 3.0, success: true)

        let usage = router.usageByModel["test"]!
        #expect(abs(usage.averageLatency - 2.0) < 0.001)
    }

    @Test("Success rate tracks correctly")
    func successRate() {
        let model = makeModel(id: "test", costPerInput: 1.0, costPerOutput: 1.0)
        let router = makeRouter(with: [model])
        router.recordUsage(modelId: "test", inputTokens: 100, outputTokens: 50, latency: 1.0, success: true)
        router.recordUsage(modelId: "test", inputTokens: 100, outputTokens: 50, latency: 1.0, success: false)
        router.recordUsage(modelId: "test", inputTokens: 100, outputTokens: 50, latency: 1.0, success: true)

        let usage = router.usageByModel["test"]!
        // 2 out of 3 = 0.667
        #expect(abs(usage.successRate - 2.0 / 3.0) < 0.01)
    }

    @Test("Daily spent accumulates across records")
    func dailySpentAccumulates() {
        let model = makeModel(id: "test", costPerInput: 3.0, costPerOutput: 15.0)
        let router = makeRouter(with: [model])
        router.recordUsage(modelId: "test", inputTokens: 1000, outputTokens: 500, latency: 1.0, success: true)
        router.recordUsage(modelId: "test", inputTokens: 1000, outputTokens: 500, latency: 1.0, success: true)
        // Each call cost: (1000*3 + 500*15) / 1M = 10500 / 1M = 0.0105
        #expect(abs(router.dailySpent - 0.021) < 0.001)
    }

    @Test("Empty usage gives zero stats")
    func emptyUsage() {
        var usage = SMRModelUsage()
        #expect(usage.averageLatency == 0)
        #expect(usage.successRate == 0)
        #expect(usage.totalCost == 0)
        #expect(usage.requestCount == 0)
    }

    @Test("Total spent across all models")
    func totalSpent() {
        let m1 = makeModel(id: "m1", costPerInput: 1.0, costPerOutput: 1.0)
        let m2 = makeModel(id: "m2", costPerInput: 2.0, costPerOutput: 2.0)
        let router = makeRouter(with: [m1, m2])
        router.recordUsage(modelId: "m1", inputTokens: 1000, outputTokens: 1000, latency: 1.0, success: true)
        router.recordUsage(modelId: "m2", inputTokens: 1000, outputTokens: 1000, latency: 1.0, success: true)
        // m1: (1000+1000)/1M = 0.002, m2: (2000+2000)/1M = 0.004
        #expect(abs(router.totalSpent - 0.006) < 0.001)
    }

    @Test("Total tokens used across all models")
    func totalTokens() {
        let m1 = makeModel(id: "m1", costPerInput: 1.0, costPerOutput: 1.0)
        let router = makeRouter(with: [m1])
        router.recordUsage(modelId: "m1", inputTokens: 500, outputTokens: 200, latency: 1.0, success: true)
        router.recordUsage(modelId: "m1", inputTokens: 300, outputTokens: 100, latency: 1.0, success: true)
        #expect(router.totalTokensUsed == 1100) // 500+200+300+100
    }
}

// MARK: - Tests: Model Registration

@Suite("SmartModelRouter — Model Registration")
struct SMRRegistrationTests {
    @Test("Register adds model")
    func registerAdds() {
        let router = TestSmartModelRouter()
        let model = makeModel(id: "test")
        router.registerModel(model)
        #expect(router.availableModels.count == 1)
    }

    @Test("Duplicate registration is ignored")
    func duplicateIgnored() {
        let router = TestSmartModelRouter()
        let model = makeModel(id: "test")
        router.registerModel(model)
        router.registerModel(model)
        #expect(router.availableModels.count == 1)
    }

    @Test("Remove model reduces count")
    func removeReduces() {
        let router = TestSmartModelRouter()
        router.registerModel(makeModel(id: "a"))
        router.registerModel(makeModel(id: "b"))
        router.removeModel(modelId: "a")
        #expect(router.availableModels.count == 1)
        #expect(router.availableModels[0].modelId == "b")
    }

    @Test("Remove nonexistent model does nothing")
    func removeNonexistent() {
        let router = TestSmartModelRouter()
        router.registerModel(makeModel(id: "a"))
        router.removeModel(modelId: "z")
        #expect(router.availableModels.count == 1)
    }
}
