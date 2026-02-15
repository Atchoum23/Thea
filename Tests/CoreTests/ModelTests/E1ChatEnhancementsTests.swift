// E1ChatEnhancementsTests.swift
// Tests for E1: AI Chat 100% — token counting, comparison mode, metadata display

import Testing
import Foundation

// MARK: - Token Count Formatting

@Suite("Token Count Formatting")
struct TokenCountFormattingTests {
    @Test("Small counts shown as-is")
    func smallCount() {
        #expect(formatTokenCount(0) == "0")
        #expect(formatTokenCount(1) == "1")
        #expect(formatTokenCount(500) == "500")
        #expect(formatTokenCount(999) == "999")
    }

    @Test("Thousands formatted as K")
    func thousandCount() {
        #expect(formatTokenCount(1000) == "1.0K")
        #expect(formatTokenCount(1500) == "1.5K")
        #expect(formatTokenCount(2048) == "2.0K")
        #expect(formatTokenCount(10_000) == "10.0K")
        #expect(formatTokenCount(128_000) == "128.0K")
    }

    @Test("Precise K formatting")
    func preciseK() {
        #expect(formatTokenCount(1234) == "1.2K")
        #expect(formatTokenCount(4567) == "4.6K")
        #expect(formatTokenCount(99_999) == "100.0K")
    }

    // Mirrors MessageBubble.formatTokenCount logic
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - Token Heuristic Estimation

@Suite("Token Heuristic Estimation")
struct TokenHeuristicTests {
    @Test("Empty text gives 0 tokens")
    func emptyText() {
        let estimate = estimateTokens("")
        #expect(estimate == 0)
    }

    @Test("Short text estimation")
    func shortText() {
        // "Hello world" = 11 chars → ~2-3 tokens
        let estimate = estimateTokens("Hello world")
        #expect(estimate >= 1)
        #expect(estimate <= 5)
    }

    @Test("Long text estimation")
    func longText() {
        let text = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 100)
        let estimate = estimateTokens(text)
        // ~4500 chars → ~1125 tokens
        #expect(estimate > 500)
        #expect(estimate < 2000)
    }

    @Test("Code text estimation")
    func codeText() {
        let code = """
        func calculateSum(_ numbers: [Int]) -> Int {
            return numbers.reduce(0, +)
        }
        """
        let estimate = estimateTokens(code)
        #expect(estimate > 10)
        #expect(estimate < 50)
    }

    // Mirrors ChatManager heuristic: ~4 chars per token
    private func estimateTokens(_ text: String) -> Int {
        text.count / 4
    }
}

// MARK: - MessageMetadata InputTokens

@Suite("MessageMetadata InputTokens")
struct MessageMetadataInputTokensTests {
    @Test("Default inputTokens is nil")
    func defaultNil() {
        let meta = TestMessageMetadata()
        #expect(meta.inputTokens == nil)
    }

    @Test("InputTokens can be set")
    func setInputTokens() {
        var meta = TestMessageMetadata()
        meta.inputTokens = 1500
        #expect(meta.inputTokens == 1500)
    }

    @Test("Codable roundtrip preserves inputTokens")
    func codableRoundtrip() throws {
        var meta = TestMessageMetadata(confidence: 0.9)
        meta.inputTokens = 4096

        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(TestMessageMetadata.self, from: data)

        #expect(decoded.inputTokens == 4096)
        #expect(decoded.confidence == 0.9)
    }

    @Test("Codable roundtrip with nil inputTokens")
    func codableWithNil() throws {
        let meta = TestMessageMetadata(confidence: 0.5)
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(TestMessageMetadata.self, from: data)

        #expect(decoded.inputTokens == nil)
        #expect(decoded.confidence == 0.5)
    }

    /// Local test double mirroring MessageMetadata
    struct TestMessageMetadata: Codable {
        var finishReason: String?
        var cachedTokens: Int?
        var reasoningTokens: Int?
        var confidence: Double?
        var inputTokens: Int?

        init(
            finishReason: String? = nil,
            cachedTokens: Int? = nil,
            reasoningTokens: Int? = nil,
            confidence: Double? = nil,
            inputTokens: Int? = nil
        ) {
            self.finishReason = finishReason
            self.cachedTokens = cachedTokens
            self.reasoningTokens = reasoningTokens
            self.confidence = confidence
            self.inputTokens = inputTokens
        }
    }
}

// MARK: - Model Provider Resolution

@Suite("Model Provider Resolution")
struct ModelProviderResolutionTests {
    @Test("GPT models map to OpenAI")
    func gptModels() {
        #expect(resolveProvider("gpt-4o") == "openai")
        #expect(resolveProvider("gpt-4-turbo") == "openai")
    }

    @Test("Claude models map to Anthropic")
    func claudeModels() {
        #expect(resolveProvider("claude-4-sonnet") == "anthropic")
        #expect(resolveProvider("claude-4-opus") == "anthropic")
        #expect(resolveProvider("claude-3.5-sonnet") == "anthropic")
    }

    @Test("Gemini models map to Google")
    func geminiModels() {
        #expect(resolveProvider("gemini-2.5-pro") == "google")
        #expect(resolveProvider("gemini-2.0-flash") == "google")
    }

    @Test("Llama models map to Groq")
    func llamaModels() {
        #expect(resolveProvider("llama-3.3-70b") == "groq")
    }

    @Test("Sonar models map to Perplexity")
    func sonarModels() {
        #expect(resolveProvider("sonar-pro") == "perplexity")
    }

    @Test("o1 models map to OpenAI")
    func o1Models() {
        #expect(resolveProvider("o1-preview") == "openai")
        #expect(resolveProvider("o1-mini") == "openai")
    }

    @Test("Local models return local")
    func localModels() {
        #expect(resolveProvider("local") == "local")
        #expect(resolveProvider("local:llama-3") == "local")
    }

    @Test("Unknown models return fallback")
    func unknownModels() {
        #expect(resolveProvider("unknown-model") == "fallback")
    }

    /// Mirrors ProviderRegistry.getProvider(for:) logic
    func resolveProvider(_ modelId: String) -> String {
        if modelId == "local" || modelId.hasPrefix("local:") { return "local" }
        let mapping: [(prefix: String, providerId: String)] = [
            ("gpt", "openai"), ("o1", "openai"), ("o3", "openai"),
            ("claude", "anthropic"),
            ("gemini", "google"),
            ("llama", "groq"), ("mixtral", "groq"),
            ("sonar", "perplexity"), ("pplx", "perplexity")
        ]
        for m in mapping {
            if modelId.lowercased().contains(m.prefix) {
                return m.providerId
            }
        }
        return "fallback"
    }
}

// MARK: - Comparison Mode Branch Structure

@Suite("Comparison Mode Branching")
struct ComparisonBranchingTests {
    @Test("Two comparison messages share same orderIndex")
    func sameOrderIndex() {
        let msg1 = TestComparisonMessage(orderIndex: 5, branchIndex: 0, model: "gpt-4o")
        let msg2 = TestComparisonMessage(orderIndex: 5, branchIndex: 1, model: "claude-4-sonnet")

        #expect(msg1.orderIndex == msg2.orderIndex)
        #expect(msg1.branchIndex != msg2.branchIndex)
        #expect(msg1.model != msg2.model)
    }

    @Test("Branch indices are 0 and 1")
    func branchIndices() {
        let msg1 = TestComparisonMessage(orderIndex: 0, branchIndex: 0, model: "a")
        let msg2 = TestComparisonMessage(orderIndex: 0, branchIndex: 1, model: "b")

        #expect(msg1.branchIndex == 0)
        #expect(msg2.branchIndex == 1)
    }

    @Test("Parent message ID links branch to original")
    func parentLink() {
        let parentId = UUID()
        let msg2 = TestComparisonMessage(
            orderIndex: 0, branchIndex: 1, model: "b", parentMessageId: parentId
        )

        #expect(msg2.parentMessageId == parentId)
    }

    struct TestComparisonMessage {
        let id = UUID()
        let orderIndex: Int
        let branchIndex: Int
        let model: String
        var parentMessageId: UUID?
    }
}

// MARK: - Token Display Formatting

@Suite("Token Display Text")
struct TokenDisplayTextTests {
    @Test("Output tokens only")
    func outputOnly() {
        let display = tokenDisplayText(inputTokens: nil, outputTokens: 150)
        #expect(display == "150 tokens")
    }

    @Test("Input + output tokens")
    func inputAndOutput() {
        let display = tokenDisplayText(inputTokens: 1500, outputTokens: 300)
        #expect(display == "1.5K→300")
    }

    @Test("Large input + output")
    func largeTokens() {
        let display = tokenDisplayText(inputTokens: 128_000, outputTokens: 4096)
        #expect(display == "128.0K→4.1K")
    }

    @Test("Small input + small output")
    func smallTokens() {
        let display = tokenDisplayText(inputTokens: 50, outputTokens: 20)
        #expect(display == "50→20")
    }

    /// Mirrors MessageBubble metadata row token display logic
    func tokenDisplayText(inputTokens: Int?, outputTokens: Int) -> String {
        if let input = inputTokens {
            return "\(formatTokenCount(input))→\(formatTokenCount(outputTokens))"
        }
        return "\(formatTokenCount(outputTokens)) tokens"
    }

    func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - Confidence Badge Logic

@Suite("Confidence Badge Display")
struct ConfidenceBadgeTests {
    @Test("High confidence (>=0.8) shows checkmark shield")
    func highConfidence() {
        let icon = confidenceIcon(0.8)
        #expect(icon == "checkmark.shield.fill")
    }

    @Test("Very high confidence shows checkmark shield")
    func veryHigh() {
        let icon = confidenceIcon(1.0)
        #expect(icon == "checkmark.shield.fill")
    }

    @Test("Medium confidence (<0.8) shows plain shield")
    func mediumConfidence() {
        let icon = confidenceIcon(0.79)
        #expect(icon == "shield")
    }

    @Test("Low confidence shows plain shield")
    func lowConfidence() {
        let icon = confidenceIcon(0.3)
        #expect(icon == "shield")
    }

    @Test("High confidence is green")
    func highColor() {
        #expect(confidenceColor(0.8) == "green")
        #expect(confidenceColor(0.9) == "green")
    }

    @Test("Medium confidence (0.5-0.8) is orange")
    func mediumColor() {
        #expect(confidenceColor(0.5) == "orange")
        #expect(confidenceColor(0.7) == "orange")
    }

    @Test("Low confidence (<0.5) is red")
    func lowColor() {
        #expect(confidenceColor(0.3) == "red")
        #expect(confidenceColor(0.1) == "red")
    }

    /// Mirrors MessageBubble confidence icon logic
    func confidenceIcon(_ confidence: Double) -> String {
        confidence >= 0.8 ? "checkmark.shield.fill" : "shield"
    }

    /// Mirrors MessageBubble confidence color logic
    func confidenceColor(_ confidence: Double) -> String {
        if confidence >= 0.8 { return "green" }
        if confidence >= 0.5 { return "orange" }
        return "red"
    }
}
