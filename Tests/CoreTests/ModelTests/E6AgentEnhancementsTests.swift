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

// MARK: - Agent Memory (Knowledge Graph Persistence) Tests

@Suite("Agent Memory KG Persistence")
struct AgentMemoryKGTests {
    /// Simulates the entity creation logic from persistSessionToKnowledgeGraph
    private func buildAgentEntity(
        agentType: String,
        taskDescription: String,
        resultSummary: String,
        tokensUsed: Int,
        confidence: Float,
        model: String,
        cost: String
    ) -> [String: String] {
        [
            "agentType": agentType,
            "taskDescription": taskDescription,
            "resultSummary": String(resultSummary.prefix(500)),
            "tokensUsed": "\(tokensUsed)",
            "confidence": String(format: "%.2f", confidence),
            "model": model,
            "completedAt": ISO8601DateFormatter().string(from: Date()),
            "cost": cost
        ]
    }

    @Test("Entity includes all required attributes")
    func entityAttributes() {
        let attrs = buildAgentEntity(
            agentType: "research",
            taskDescription: "Find Swift concurrency patterns",
            resultSummary: "Found 5 major patterns...",
            tokensUsed: 5432,
            confidence: 0.85,
            model: "claude-sonnet-4-5",
            cost: "$0.04"
        )
        #expect(attrs["agentType"] == "research")
        #expect(attrs["taskDescription"] == "Find Swift concurrency patterns")
        #expect(attrs["resultSummary"] == "Found 5 major patterns...")
        #expect(attrs["tokensUsed"] == "5432")
        #expect(attrs["confidence"] == "0.85")
        #expect(attrs["model"] == "claude-sonnet-4-5")
        #expect(attrs["cost"] == "$0.04")
        #expect(attrs["completedAt"] != nil)
    }

    @Test("Result summary truncated to 500 chars")
    func summaryTruncation() {
        let longSummary = String(repeating: "A", count: 1000)
        let attrs = buildAgentEntity(
            agentType: "explore",
            taskDescription: "Task",
            resultSummary: longSummary,
            tokensUsed: 100,
            confidence: 0.5,
            model: "haiku",
            cost: "Free"
        )
        #expect(attrs["resultSummary"]!.count == 500)
    }

    @Test("Empty summary produces empty string")
    func emptySummary() {
        let attrs = buildAgentEntity(
            agentType: "plan",
            taskDescription: "Task",
            resultSummary: "",
            tokensUsed: 0,
            confidence: 0.0,
            model: "local",
            cost: "Free"
        )
        #expect(attrs["resultSummary"]?.isEmpty == true)
    }

    @Test("Entity name format matches convention")
    func entityNameFormat() {
        let agentType = "research"
        let task = "Find Swift concurrency patterns for actor isolation"
        let name = "Agent: \(agentType) — \(task.prefix(60))"
        #expect(name.hasPrefix("Agent: research — "))
        #expect(name.count <= 80) // reasonable length
    }

    @Test("CompletedAt is valid ISO8601")
    func completedAtISO8601() {
        let attrs = buildAgentEntity(
            agentType: "debug",
            taskDescription: "Fix bug",
            resultSummary: "Fixed the issue",
            tokensUsed: 200,
            confidence: 0.9,
            model: "claude-opus-4-6",
            cost: "$0.15"
        )
        let dateStr = attrs["completedAt"]!
        let formatter = ISO8601DateFormatter()
        #expect(formatter.date(from: dateStr) != nil)
    }
}

// MARK: - Budget Tracking Tests

@Suite("Agent Budget Tracking")
struct AgentBudgetTrackingTests {
    @Test("No budget means never exceeded")
    func noBudget() {
        let budget = 0.0
        let cost = 100.0
        let exceeded = budget > 0 && cost >= budget
        #expect(!exceeded)
    }

    @Test("Under budget not exceeded")
    func underBudget() {
        let budget = 10.0
        let cost = 5.0
        let exceeded = budget > 0 && cost >= budget
        #expect(!exceeded)
    }

    @Test("At budget is exceeded")
    func atBudget() {
        let budget = 10.0
        let cost = 10.0
        let exceeded = budget > 0 && cost >= budget
        #expect(exceeded)
    }

    @Test("Over budget is exceeded")
    func overBudget() {
        let budget = 10.0
        let cost = 15.0
        let exceeded = budget > 0 && cost >= budget
        #expect(exceeded)
    }

    @Test("Cumulative cost tracks correctly")
    func cumulativeCost() {
        var cumulative = 0.0
        let sessionCosts = [0.05, 0.12, 0.03, 0.0, 0.08]
        for cost in sessionCosts {
            cumulative += cost
        }
        #expect(abs(cumulative - 0.28) < 0.001)
    }
}

// MARK: - Cost By Provider Aggregation Tests

@Suite("Agent Cost By Provider")
struct AgentCostByProviderTests {
    private func aggregateByProvider(_ sessions: [(provider: String, cost: Double)]) -> [(provider: String, cost: Double)] {
        var providerCosts: [String: Double] = [:]
        for session in sessions {
            providerCosts[session.provider, default: 0] += session.cost
        }
        return providerCosts.map { (provider: $0.key, cost: $0.value) }
            .sorted { $0.cost > $1.cost }
    }

    @Test("Empty sessions gives empty breakdown")
    func emptyBreakdown() {
        let result = aggregateByProvider([])
        #expect(result.isEmpty)
    }

    @Test("Single provider aggregation")
    func singleProvider() {
        let sessions: [(provider: String, cost: Double)] = [
            ("anthropic", 0.05),
            ("anthropic", 0.10),
            ("anthropic", 0.03)
        ]
        let result = aggregateByProvider(sessions)
        #expect(result.count == 1)
        #expect(result[0].provider == "anthropic")
        #expect(abs(result[0].cost - 0.18) < 0.001)
    }

    @Test("Multi-provider sorted by cost descending")
    func multiProviderSorted() {
        let sessions: [(provider: String, cost: Double)] = [
            ("anthropic", 0.05),
            ("openai", 0.20),
            ("google", 0.02),
            ("openai", 0.10)
        ]
        let result = aggregateByProvider(sessions)
        #expect(result.count == 3)
        #expect(result[0].provider == "openai") // $0.30 total
        #expect(result[1].provider == "anthropic") // $0.05 total
        #expect(result[2].provider == "google") // $0.02 total
    }

    @Test("Free local sessions show zero cost")
    func freeLocalSessions() {
        let sessions: [(provider: String, cost: Double)] = [
            ("local", 0.0),
            ("local", 0.0)
        ]
        let result = aggregateByProvider(sessions)
        #expect(result.count == 1)
        #expect(result[0].cost == 0.0)
    }
}

// MARK: - Feedback With Comment Tests

@Suite("Agent Feedback With Comments")
struct AgentFeedbackCommentTests {
    @Test("Feedback records comment")
    func feedbackWithComment() {
        var rating: TestFeedbackRating?
        var comment: String?

        rating = .positive
        comment = "Very helpful analysis"

        #expect(rating == .positive)
        #expect(comment == "Very helpful analysis")
    }

    @Test("Feedback without comment")
    func feedbackWithoutComment() {
        var rating: TestFeedbackRating?
        var comment: String?

        rating = .negative
        comment = nil

        #expect(rating == .negative)
        #expect(comment == nil)
    }

    @Test("Empty string comment treated as nil")
    func emptyComment() {
        let comment = ""
        let effectiveComment = comment.isEmpty ? nil : comment
        #expect(effectiveComment == nil)
    }

    @Test("Feedback updates stats and records comment")
    func feedbackUpdatesStatsAndComment() {
        var stats = TestFeedbackStats()
        var comments: [String] = []

        stats.record(positive: true)
        comments.append("Great work")

        stats.record(positive: false)
        comments.append("Incomplete response")

        #expect(stats.totalCount == 2)
        #expect(stats.positiveCount == 1)
        #expect(stats.negativeCount == 1)
        #expect(comments.count == 2)
        #expect(comments[0] == "Great work")
    }
}

// MARK: - Agent Type Stats Aggregation Tests

@Suite("Agent Type Stats Aggregation")
struct AgentTypeStatsAggregationTests {
    private struct TypeStat {
        let type: String
        let successRate: Double?
        let total: Int
    }

    private func computeStats(sessions: [(type: String, rating: String?)]) -> [TypeStat] {
        var stats: [String: (positive: Int, total: Int)] = [:]
        for session in sessions where session.rating != nil {
            var current = stats[session.type] ?? (positive: 0, total: 0)
            current.total += 1
            if session.rating == "positive" { current.positive += 1 }
            stats[session.type] = current
        }
        return stats.map { type, counts in
            TypeStat(
                type: type,
                successRate: counts.total > 0 ? Double(counts.positive) / Double(counts.total) : nil,
                total: counts.total
            )
        }
        .sorted { $0.total > $1.total }
    }

    @Test("No rated sessions gives empty stats")
    func noRatedSessions() {
        let sessions: [(type: String, rating: String?)] = [
            ("research", nil),
            ("explore", nil)
        ]
        let stats = computeStats(sessions: sessions)
        #expect(stats.isEmpty)
    }

    @Test("Single type all positive")
    func singleTypeAllPositive() {
        let sessions: [(type: String, rating: String?)] = [
            ("research", "positive"),
            ("research", "positive"),
            ("research", "positive")
        ]
        let stats = computeStats(sessions: sessions)
        #expect(stats.count == 1)
        #expect(stats[0].type == "research")
        #expect(stats[0].successRate == 1.0)
        #expect(stats[0].total == 3)
    }

    @Test("Multiple types sorted by total descending")
    func multipleTypesSorted() {
        let sessions: [(type: String, rating: String?)] = [
            ("research", "positive"),
            ("explore", "positive"),
            ("explore", "negative"),
            ("explore", "positive"),
            ("debug", "negative"),
            ("research", "positive")
        ]
        let stats = computeStats(sessions: sessions)
        #expect(stats.count == 3)
        #expect(stats[0].type == "explore") // 3 ratings
        #expect(stats[1].type == "research") // 2 ratings
        #expect(stats[2].type == "debug") // 1 rating
    }

    @Test("Unrated sessions excluded from stats")
    func unratedExcluded() {
        let sessions: [(type: String, rating: String?)] = [
            ("research", "positive"),
            ("research", nil),
            ("research", nil),
            ("explore", "negative")
        ]
        let stats = computeStats(sessions: sessions)
        let researchStat = stats.first { $0.type == "research" }
        #expect(researchStat?.total == 1) // only the rated one
        #expect(researchStat?.successRate == 1.0)
    }

    @Test("Mixed feedback gives correct percentages")
    func mixedFeedbackPercentages() {
        let sessions: [(type: String, rating: String?)] = [
            ("research", "positive"),
            ("research", "negative"),
            ("research", "positive"),
            ("research", "positive")
        ]
        let stats = computeStats(sessions: sessions)
        #expect(stats[0].successRate == 0.75)
        #expect(stats[0].total == 4)
    }
}
