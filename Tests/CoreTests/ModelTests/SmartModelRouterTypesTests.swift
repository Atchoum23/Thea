import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Intelligence/Routing/SmartModelRouter.swift)

private enum TestTaskComplexity: String, Sendable, CaseIterable, Codable {
    case trivial
    case simple
    case moderate
    case complex
    case expert

    var estimatedTokens: Int {
        switch self {
        case .trivial: return 100
        case .simple: return 500
        case .moderate: return 2000
        case .complex: return 8000
        case .expert: return 32000
        }
    }

    var requiresReasoning: Bool {
        switch self {
        case .trivial, .simple: return false
        case .moderate, .complex, .expert: return true
        }
    }
}

private enum TestRoutingStrategy: String, Sendable, CaseIterable {
    case costOptimized
    case qualityOptimized
    case speedOptimized
    case balanced
    case cascadeFallback
    case planAndExecute
    case localFirst

    var prefersCost: Bool {
        self == .costOptimized || self == .localFirst
    }

    var prefersQuality: Bool {
        self == .qualityOptimized || self == .planAndExecute
    }

    var prefersSpeed: Bool {
        self == .speedOptimized
    }
}

private enum TestCapability: String, Sendable, CaseIterable {
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

private struct TestModelCapability: Sendable, Identifiable {
    let id: String
    let modelId: String
    let provider: String
    let contextWindow: Int
    let maxOutputTokens: Int
    let capabilities: Set<TestCapability>
    let costPerInputToken: Double
    let costPerOutputToken: Double
    let averageLatency: TimeInterval
    let qualityScore: Float
    let isLocalModel: Bool

    init(
        modelId: String,
        provider: String,
        contextWindow: Int = 128_000,
        maxOutputTokens: Int = 4096,
        capabilities: Set<TestCapability> = [.textGeneration],
        costPerInputToken: Double = 0.001,
        costPerOutputToken: Double = 0.003,
        averageLatency: TimeInterval = 1.0,
        qualityScore: Float = 0.8,
        isLocalModel: Bool = false
    ) {
        self.id = modelId
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

    var estimatedCostForKTokens: Double {
        (costPerInputToken + costPerOutputToken) * 1000
    }
}

private struct TestRoutingDecision: Sendable {
    let taskType: TestTaskComplexity
    let selectedModel: TestModelCapability
    let alternativeModels: [TestModelCapability]
    let estimatedCost: Double
    let estimatedLatency: TimeInterval
    let confidence: Float
    let reasoning: String
    let strategy: TestRoutingStrategy
}

private enum TestBatchPriority: String, Sendable, CaseIterable {
    case low
    case normal
    case high
    case urgent

    var queueOrder: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }
}

// MARK: - Routing Logic (standalone, testable)

private func selectBestModel(
    for complexity: TestTaskComplexity,
    strategy: TestRoutingStrategy,
    availableModels: [TestModelCapability],
    requiredCapabilities: Set<TestCapability> = []
) -> TestModelCapability? {
    var candidates = availableModels
    if !requiredCapabilities.isEmpty {
        candidates = candidates.filter { model in
            requiredCapabilities.isSubset(of: model.capabilities)
        }
    }
    guard !candidates.isEmpty else { return nil }

    switch strategy {
    case .costOptimized:
        return candidates.min { $0.estimatedCostForKTokens < $1.estimatedCostForKTokens }
    case .qualityOptimized:
        return candidates.max { $0.qualityScore < $1.qualityScore }
    case .speedOptimized:
        return candidates.min { $0.averageLatency < $1.averageLatency }
    case .balanced:
        // Weighted score: quality 0.4, cost 0.3, speed 0.3
        return candidates.max { a, b in
            let scoreA = Double(a.qualityScore) * 0.4 - a.estimatedCostForKTokens * 0.3 - a.averageLatency * 0.3
            let scoreB = Double(b.qualityScore) * 0.4 - b.estimatedCostForKTokens * 0.3 - b.averageLatency * 0.3
            return scoreA < scoreB
        }
    case .localFirst:
        return candidates.first { $0.isLocalModel } ?? candidates.min { $0.estimatedCostForKTokens < $1.estimatedCostForKTokens }
    case .cascadeFallback:
        // Start with cheapest, fall back to better models
        return candidates.min { $0.estimatedCostForKTokens < $1.estimatedCostForKTokens }
    case .planAndExecute:
        // Pick highest quality for planning
        return candidates.max { $0.qualityScore < $1.qualityScore }
    }
}

private func estimateCost(model: TestModelCapability, inputTokens: Int, outputTokens: Int) -> Double {
    Double(inputTokens) * model.costPerInputToken / 1_000_000 +
    Double(outputTokens) * model.costPerOutputToken / 1_000_000
}

private func meetsContextRequirements(model: TestModelCapability, estimatedTokens: Int) -> Bool {
    model.contextWindow >= estimatedTokens
}

// MARK: - Test Data

private let testModels: [TestModelCapability] = [
    TestModelCapability(
        modelId: "claude-opus-4-6",
        provider: "anthropic",
        contextWindow: 200_000,
        maxOutputTokens: 32_000,
        capabilities: [.textGeneration, .codeGeneration, .reasoning, .analysis, .vision, .functionCalling, .highQuality],
        costPerInputToken: 0.015,
        costPerOutputToken: 0.075,
        averageLatency: 3.0,
        qualityScore: 0.98
    ),
    TestModelCapability(
        modelId: "claude-haiku-4-5",
        provider: "anthropic",
        contextWindow: 200_000,
        maxOutputTokens: 8192,
        capabilities: [.textGeneration, .codeGeneration, .fastResponse, .lowCost],
        costPerInputToken: 0.0008,
        costPerOutputToken: 0.004,
        averageLatency: 0.5,
        qualityScore: 0.75
    ),
    TestModelCapability(
        modelId: "llama-3.3-70b",
        provider: "local",
        contextWindow: 128_000,
        maxOutputTokens: 4096,
        capabilities: [.textGeneration, .codeGeneration, .reasoning],
        costPerInputToken: 0,
        costPerOutputToken: 0,
        averageLatency: 2.0,
        qualityScore: 0.82,
        isLocalModel: true
    ),
    TestModelCapability(
        modelId: "gemini-2.5-pro",
        provider: "google",
        contextWindow: 1_000_000,
        maxOutputTokens: 65_536,
        capabilities: [.textGeneration, .codeGeneration, .reasoning, .vision, .longContext, .highQuality],
        costPerInputToken: 0.00125,
        costPerOutputToken: 0.005,
        averageLatency: 2.5,
        qualityScore: 0.95
    )
]

// MARK: - Tests

@Suite("TaskComplexity Enum")
struct TaskComplexityTests {
    @Test("All 5 levels exist")
    func allCases() {
        #expect(TestTaskComplexity.allCases.count == 5)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = TestTaskComplexity.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Estimated tokens increase with complexity")
    func tokensIncrease() {
        let tokens = TestTaskComplexity.allCases.map(\.estimatedTokens)
        for i in 1..<tokens.count {
            #expect(tokens[i] > tokens[i - 1])
        }
    }

    @Test("Reasoning requirement")
    func reasoning() {
        #expect(!TestTaskComplexity.trivial.requiresReasoning)
        #expect(!TestTaskComplexity.simple.requiresReasoning)
        #expect(TestTaskComplexity.moderate.requiresReasoning)
        #expect(TestTaskComplexity.complex.requiresReasoning)
        #expect(TestTaskComplexity.expert.requiresReasoning)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for c in TestTaskComplexity.allCases {
            let data = try JSONEncoder().encode(c)
            let decoded = try JSONDecoder().decode(TestTaskComplexity.self, from: data)
            #expect(decoded == c)
        }
    }
}

@Suite("RoutingStrategy Enum")
struct RoutingStrategyTests {
    @Test("All 7 strategies exist")
    func allCases() {
        #expect(TestRoutingStrategy.allCases.count == 7)
    }

    @Test("Cost preference")
    func costPreference() {
        #expect(TestRoutingStrategy.costOptimized.prefersCost)
        #expect(TestRoutingStrategy.localFirst.prefersCost)
        #expect(!TestRoutingStrategy.qualityOptimized.prefersCost)
    }

    @Test("Quality preference")
    func qualityPreference() {
        #expect(TestRoutingStrategy.qualityOptimized.prefersQuality)
        #expect(TestRoutingStrategy.planAndExecute.prefersQuality)
        #expect(!TestRoutingStrategy.costOptimized.prefersQuality)
    }

    @Test("Speed preference")
    func speedPreference() {
        #expect(TestRoutingStrategy.speedOptimized.prefersSpeed)
        #expect(!TestRoutingStrategy.qualityOptimized.prefersSpeed)
    }
}

@Suite("Capability Enum")
struct CapabilityTests {
    @Test("All 14 capabilities exist")
    func allCases() {
        #expect(TestCapability.allCases.count == 14)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = TestCapability.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

@Suite("ModelCapability Struct")
struct ModelCapabilityTests {
    @Test("Creation with defaults")
    func creation() {
        let model = TestModelCapability(modelId: "test-model", provider: "test")
        #expect(model.modelId == "test-model")
        #expect(model.provider == "test")
        #expect(!model.isLocalModel)
    }

    @Test("Local model flag")
    func localModel() {
        let model = TestModelCapability(modelId: "local", provider: "mlx", isLocalModel: true)
        #expect(model.isLocalModel)
    }

    @Test("Estimated cost calculation")
    func estimatedCost() {
        let model = TestModelCapability(
            modelId: "test",
            provider: "test",
            costPerInputToken: 0.001,
            costPerOutputToken: 0.003
        )
        #expect(model.estimatedCostForKTokens == 4.0) // (0.001 + 0.003) * 1000
    }

    @Test("Local model has zero cost")
    func localZeroCost() {
        let model = TestModelCapability(
            modelId: "local",
            provider: "mlx",
            costPerInputToken: 0,
            costPerOutputToken: 0,
            isLocalModel: true
        )
        #expect(model.estimatedCostForKTokens == 0)
    }
}

@Suite("BatchPriority Enum")
struct BatchPriorityTests {
    @Test("All 4 priorities exist")
    func allCases() {
        #expect(TestBatchPriority.allCases.count == 4)
    }

    @Test("Queue order increases")
    func queueOrder() {
        let orders = TestBatchPriority.allCases.map(\.queueOrder)
        for i in 1..<orders.count {
            #expect(orders[i] > orders[i - 1])
        }
    }
}

@Suite("Model Selection — Cost Optimized")
struct CostOptimizedSelectionTests {
    @Test("Selects cheapest model")
    func selectsCheapest() {
        let selected = selectBestModel(for: .simple, strategy: .costOptimized, availableModels: testModels)
        #expect(selected?.modelId == "llama-3.3-70b") // Zero cost
    }

    @Test("Filters by required capabilities")
    func filtersByCapabilities() {
        let selected = selectBestModel(
            for: .simple,
            strategy: .costOptimized,
            availableModels: testModels,
            requiredCapabilities: [.vision]
        )
        // llama doesn't have vision, so should pick from others
        #expect(selected?.capabilities.contains(.vision) == true)
    }

    @Test("Returns nil when no models match")
    func noMatch() {
        let selected = selectBestModel(
            for: .simple,
            strategy: .costOptimized,
            availableModels: testModels,
            requiredCapabilities: [.audio]
        )
        #expect(selected == nil)
    }
}

@Suite("Model Selection — Quality Optimized")
struct QualityOptimizedSelectionTests {
    @Test("Selects highest quality")
    func selectsHighestQuality() {
        let selected = selectBestModel(for: .complex, strategy: .qualityOptimized, availableModels: testModels)
        #expect(selected?.modelId == "claude-opus-4-6") // 0.98 quality
    }
}

@Suite("Model Selection — Speed Optimized")
struct SpeedOptimizedSelectionTests {
    @Test("Selects fastest model")
    func selectsFastest() {
        let selected = selectBestModel(for: .trivial, strategy: .speedOptimized, availableModels: testModels)
        #expect(selected?.modelId == "claude-haiku-4-5") // 0.5s latency
    }
}

@Suite("Model Selection — Local First")
struct LocalFirstSelectionTests {
    @Test("Prefers local model when available")
    func prefersLocal() {
        let selected = selectBestModel(for: .simple, strategy: .localFirst, availableModels: testModels)
        #expect(selected?.isLocalModel == true)
        #expect(selected?.modelId == "llama-3.3-70b")
    }

    @Test("Falls back to cloud when no local available")
    func fallsBackToCloud() {
        let cloudOnly = testModels.filter { !$0.isLocalModel }
        let selected = selectBestModel(for: .simple, strategy: .localFirst, availableModels: cloudOnly)
        #expect(selected != nil)
        #expect(selected?.isLocalModel == false)
    }
}

@Suite("Cost Estimation")
struct CostEstimationTests {
    @Test("Cost calculation correct")
    func costCalculation() {
        let model = testModels[0] // opus: 0.015 input, 0.075 output
        let cost = estimateCost(model: model, inputTokens: 1000, outputTokens: 500)
        let expected = 1000 * 0.015 / 1_000_000 + 500 * 0.075 / 1_000_000
        #expect(abs(cost - expected) < 0.000001)
    }

    @Test("Local model zero cost")
    func localZeroCost() {
        let local = testModels[2] // llama: 0 cost
        let cost = estimateCost(model: local, inputTokens: 10000, outputTokens: 5000)
        #expect(cost == 0)
    }
}

@Suite("Context Requirements")
struct ContextRequirementsTests {
    @Test("Model meets requirements")
    func meetsRequirements() {
        let model = testModels[0] // 200K context
        #expect(meetsContextRequirements(model: model, estimatedTokens: 100_000))
    }

    @Test("Model does not meet requirements")
    func doesNotMeet() {
        let model = testModels[2] // 128K context
        #expect(!meetsContextRequirements(model: model, estimatedTokens: 200_000))
    }

    @Test("Gemini handles million-token context")
    func longContext() {
        let gemini = testModels[3] // 1M context
        #expect(meetsContextRequirements(model: gemini, estimatedTokens: 500_000))
    }
}

@Suite("Empty Model List")
struct EmptyModelListTests {
    @Test("All strategies return nil for empty list")
    func emptyList() {
        for strategy in TestRoutingStrategy.allCases {
            let selected = selectBestModel(for: .simple, strategy: strategy, availableModels: [])
            #expect(selected == nil, "Strategy \(strategy.rawValue) should return nil for empty list")
        }
    }
}
