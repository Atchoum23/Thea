// E6AgentEnhancementsTests.swift
// Tests for E6 Agent Delegation enhancements:
// - Cost estimation (per-model pricing, session cost calculation)
// - User feedback (rating, feedback stats)
// - Agent type feedback statistics

import Testing
import Foundation

// MARK: - Test Doubles

private enum TestAgentCostEstimator {
    static func costPerMillionTokens(modelId: String) -> (input: Double, output: Double) {
        let lower = modelId.lowercased()
        if lower.contains("opus") { return (15.0, 75.0) }
        if lower.contains("sonnet") { return (3.0, 15.0) }
        if lower.contains("haiku") { return (0.25, 1.25) }
        if lower.contains("gpt-4o-mini") { return (0.15, 0.60) }
        if lower.contains("gpt-4o") { return (2.50, 10.0) }
        if lower.contains("o1") || lower.contains("o3") { return (15.0, 60.0) }
        if lower.contains("gemini") { return (0.50, 1.50) }
        if lower.contains("deepseek") { return (0.27, 1.10) }
        if lower.contains("local") || lower.contains("mlx") { return (0.0, 0.0) }
        return (1.0, 3.0)
    }

    static func estimateCost(tokensUsed: Int, modelId: String?) -> Double {
        guard let modelId, tokensUsed > 0 else { return 0 }
        let (inputCost, outputCost) = costPerMillionTokens(modelId: modelId)
        let outputTokens = Double(tokensUsed) * 0.3
        let inputTokens = Double(tokensUsed) * 0.7
        return (inputTokens * inputCost + outputTokens * outputCost) / 1_000_000
    }
}

private enum TestFeedbackRating: String {
    case positive
    case negative

    var sfSymbol: String {
        switch self {
        case .positive: "hand.thumbsup.fill"
        case .negative: "hand.thumbsdown.fill"
        }
    }
}

private struct TestFeedbackStats {
    var positiveCount: Int = 0
    var negativeCount: Int = 0

    var totalCount: Int { positiveCount + negativeCount }

    var successRate: Double? {
        guard totalCount > 0 else { return nil }
        return Double(positiveCount) / Double(totalCount)
    }

    mutating func record(positive: Bool) {
        if positive {
            positiveCount += 1
        } else {
            negativeCount += 1
        }
    }
}

// MARK: - Cost Estimation Tests

@Suite("Agent Cost Per Model")
struct AgentCostPerModelTests {
    @Test("Claude Opus pricing")
    func opusPricing() {
        let (input, output) = TestAgentCostEstimator.costPerMillionTokens(modelId: "claude-opus-4-5")
        #expect(input == 15.0)
        #expect(output == 75.0)
    }

    @Test("Claude Sonnet pricing")
    func sonnetPricing() {
        let (input, output) = TestAgentCostEstimator.costPerMillionTokens(modelId: "claude-sonnet-4-5")
        #expect(input == 3.0)
        #expect(output == 15.0)
    }

    @Test("Claude Haiku pricing")
    func haikuPricing() {
        let (input, output) = TestAgentCostEstimator.costPerMillionTokens(modelId: "claude-haiku-4-5")
        #expect(input == 0.25)
        #expect(output == 1.25)
    }

    @Test("GPT-4o pricing")
    func gpt4oPricing() {
        let (input, output) = TestAgentCostEstimator.costPerMillionTokens(modelId: "gpt-4o")
        #expect(input == 2.50)
        #expect(output == 10.0)
    }

    @Test("GPT-4o-mini pricing")
    func gpt4oMiniPricing() {
        let (input, output) = TestAgentCostEstimator.costPerMillionTokens(modelId: "gpt-4o-mini")
        #expect(input == 0.15)
        #expect(output == 0.60)
    }

    @Test("Gemini pricing")
    func geminiPricing() {
        let (input, output) = TestAgentCostEstimator.costPerMillionTokens(modelId: "gemini-2.5-pro")
        #expect(input == 0.50)
        #expect(output == 1.50)
    }

    @Test("DeepSeek pricing")
    func deepseekPricing() {
        let (input, output) = TestAgentCostEstimator.costPerMillionTokens(modelId: "deepseek-chat")
        #expect(input == 0.27)
        #expect(output == 1.10)
    }

    @Test("Local model is free")
    func localFree() {
        let (input, output) = TestAgentCostEstimator.costPerMillionTokens(modelId: "local:llama-3-8b")
        #expect(input == 0.0)
        #expect(output == 0.0)
    }

    @Test("MLX model is free")
    func mlxFree() {
        let (input, output) = TestAgentCostEstimator.costPerMillionTokens(modelId: "mlx-community/qwen2")
        #expect(input == 0.0)
        #expect(output == 0.0)
    }

    @Test("Unknown model uses default pricing")
    func unknownDefault() {
        let (input, output) = TestAgentCostEstimator.costPerMillionTokens(modelId: "some-unknown-model")
        #expect(input == 1.0)
        #expect(output == 3.0)
    }

    @Test("O1 reasoning model pricing")
    func o1Pricing() {
        let (input, output) = TestAgentCostEstimator.costPerMillionTokens(modelId: "o1-preview")
        #expect(input == 15.0)
        #expect(output == 60.0)
    }
}

@Suite("Agent Session Cost Estimation")
struct AgentSessionCostTests {
    @Test("Zero tokens costs nothing")
    func zeroCost() {
        let cost = TestAgentCostEstimator.estimateCost(tokensUsed: 0, modelId: "claude-sonnet-4-5")
        #expect(cost == 0)
    }

    @Test("Nil model costs nothing")
    func nilModelCost() {
        let cost = TestAgentCostEstimator.estimateCost(tokensUsed: 1000, modelId: nil)
        #expect(cost == 0)
    }

    @Test("Sonnet 1000 tokens cost calculation")
    func sonnet1000Tokens() {
        let cost = TestAgentCostEstimator.estimateCost(tokensUsed: 1000, modelId: "claude-sonnet-4-5")
        // 700 input * $3/1M + 300 output * $15/1M = 0.0021 + 0.0045 = 0.0066
        #expect(cost > 0.006)
        #expect(cost < 0.007)
    }

    @Test("Haiku is cheaper than Sonnet")
    func haikuCheaperThanSonnet() {
        let haikuCost = TestAgentCostEstimator.estimateCost(tokensUsed: 5000, modelId: "claude-haiku-4-5")
        let sonnetCost = TestAgentCostEstimator.estimateCost(tokensUsed: 5000, modelId: "claude-sonnet-4-5")
        #expect(haikuCost < sonnetCost)
    }

    @Test("Opus is most expensive")
    func opusMostExpensive() {
        let opusCost = TestAgentCostEstimator.estimateCost(tokensUsed: 5000, modelId: "claude-opus-4-5")
        let sonnetCost = TestAgentCostEstimator.estimateCost(tokensUsed: 5000, modelId: "claude-sonnet-4-5")
        let haikuCost = TestAgentCostEstimator.estimateCost(tokensUsed: 5000, modelId: "claude-haiku-4-5")
        #expect(opusCost > sonnetCost)
        #expect(sonnetCost > haikuCost)
    }

    @Test("Local model is always free")
    func localAlwaysFree() {
        let cost = TestAgentCostEstimator.estimateCost(tokensUsed: 100_000, modelId: "local:llama-3.3-70b")
        #expect(cost == 0)
    }

    @Test("Large token count produces reasonable cost")
    func largeCost() {
        // 100K tokens with Opus: 70K * $15/1M + 30K * $75/1M = $1.05 + $2.25 = $3.30
        let cost = TestAgentCostEstimator.estimateCost(tokensUsed: 100_000, modelId: "claude-opus-4-5")
        #expect(cost > 3.0)
        #expect(cost < 4.0)
    }
}

// MARK: - Feedback Rating Tests

@Suite("Agent Feedback Rating")
struct AgentFeedbackRatingTests {
    @Test("Positive rating symbol")
    func positiveSymbol() {
        let rating = TestFeedbackRating.positive
        #expect(rating.sfSymbol == "hand.thumbsup.fill")
        #expect(rating.rawValue == "positive")
    }

    @Test("Negative rating symbol")
    func negativeSymbol() {
        let rating = TestFeedbackRating.negative
        #expect(rating.sfSymbol == "hand.thumbsdown.fill")
        #expect(rating.rawValue == "negative")
    }
}

// MARK: - Feedback Stats Tests

@Suite("Agent Feedback Statistics")
struct AgentFeedbackStatsTests {
    @Test("Empty stats has nil success rate")
    func emptyStats() {
        let stats = TestFeedbackStats()
        #expect(stats.totalCount == 0)
        #expect(stats.successRate == nil)
    }

    @Test("All positive gives 100% success rate")
    func allPositive() {
        var stats = TestFeedbackStats()
        stats.record(positive: true)
        stats.record(positive: true)
        stats.record(positive: true)
        #expect(stats.totalCount == 3)
        #expect(stats.positiveCount == 3)
        #expect(stats.negativeCount == 0)
        #expect(stats.successRate == 1.0)
    }

    @Test("All negative gives 0% success rate")
    func allNegative() {
        var stats = TestFeedbackStats()
        stats.record(positive: false)
        stats.record(positive: false)
        #expect(stats.totalCount == 2)
        #expect(stats.positiveCount == 0)
        #expect(stats.negativeCount == 2)
        #expect(stats.successRate == 0.0)
    }

    @Test("Mixed feedback gives correct rate")
    func mixedFeedback() {
        var stats = TestFeedbackStats()
        stats.record(positive: true)
        stats.record(positive: true)
        stats.record(positive: false)
        stats.record(positive: true)
        #expect(stats.totalCount == 4)
        #expect(stats.positiveCount == 3)
        #expect(stats.negativeCount == 1)
        #expect(stats.successRate! == 0.75)
    }

    @Test("Single positive gives 100%")
    func singlePositive() {
        var stats = TestFeedbackStats()
        stats.record(positive: true)
        #expect(stats.totalCount == 1)
        #expect(stats.successRate == 1.0)
    }

    @Test("Single negative gives 0%")
    func singleNegative() {
        var stats = TestFeedbackStats()
        stats.record(positive: false)
        #expect(stats.totalCount == 1)
        #expect(stats.successRate == 0.0)
    }

    @Test("50/50 feedback gives 50%")
    func fiftyFifty() {
        var stats = TestFeedbackStats()
        for _ in 0..<10 { stats.record(positive: true) }
        for _ in 0..<10 { stats.record(positive: false) }
        #expect(stats.totalCount == 20)
        #expect(stats.successRate == 0.5)
    }
}

// MARK: - Cost Formatting Tests

@Suite("Agent Cost Formatting")
struct AgentCostFormattingTests {
    private func formatCost(_ cost: Double) -> String {
        if cost == 0 { return "Free" }
        if cost < 0.01 { return "<$0.01" }
        return String(format: "$%.2f", cost)
    }

    @Test("Zero cost shows Free")
    func zeroCostFree() {
        #expect(formatCost(0) == "Free")
    }

    @Test("Sub-cent shows <$0.01")
    func subCentDisplay() {
        #expect(formatCost(0.005) == "<$0.01")
    }

    @Test("Normal cost shows dollar amount")
    func normalCostDisplay() {
        #expect(formatCost(1.50) == "$1.50")
    }

    @Test("Large cost formats correctly")
    func largeCostFormat() {
        #expect(formatCost(10.00) == "$10.00")
    }

    @Test("Exact penny shows correctly")
    func exactPenny() {
        #expect(formatCost(0.01) == "$0.01")
    }
}
