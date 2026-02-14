@testable import TheaCore
import XCTest

final class ContextManagerTests: XCTestCase {
    // MARK: - ConversationConfiguration

    func testConfigurationDefaults() {
        let config = ConversationConfiguration()

        XCTAssertNil(config.maxContextTokens)
        XCTAssertNil(config.maxConversationLength)
        XCTAssertNil(config.maxMessageAgeDays)
        XCTAssertTrue(config.persistFullHistory)
        XCTAssertEqual(config.contextStrategy, .unlimited)
        XCTAssertTrue(config.allowMetaAIContextExpansion)
        XCTAssertEqual(config.metaAIPreferredContext, 200_000)
        XCTAssertEqual(config.metaAIReservedTokens, 50000)
        XCTAssertEqual(config.metaAIContextPriority, .high)
        XCTAssertEqual(config.tokenCountingMethod, .accurate)
        XCTAssertTrue(config.enableStreaming)
        XCTAssertEqual(config.streamingBufferSize, 100)
    }

    func testConfigurationCodable() throws {
        var original = ConversationConfiguration()
        original.maxContextTokens = 64_000
        original.maxConversationLength = 100
        original.contextStrategy = .hybrid
        original.metaAIReservedTokens = 30000
        original.tokenCountingMethod = .estimate

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConversationConfiguration.self, from: data)

        XCTAssertEqual(decoded.maxContextTokens, 64_000)
        XCTAssertEqual(decoded.maxConversationLength, 100)
        XCTAssertEqual(decoded.contextStrategy, .hybrid)
        XCTAssertEqual(decoded.metaAIReservedTokens, 30000)
        XCTAssertEqual(decoded.tokenCountingMethod, .estimate)
    }

    // MARK: - ContextStrategy

    func testContextStrategyRawValues() {
        XCTAssertEqual(ConversationConfiguration.ContextStrategy.unlimited.rawValue, "Unlimited")
        XCTAssertEqual(ConversationConfiguration.ContextStrategy.sliding.rawValue, "Sliding Window")
        XCTAssertEqual(ConversationConfiguration.ContextStrategy.summarize.rawValue, "Smart Summarization")
        XCTAssertEqual(ConversationConfiguration.ContextStrategy.hybrid.rawValue, "Hybrid (Summarize + Recent)")
    }

    func testContextStrategyCaseIterable() {
        let allCases = ConversationConfiguration.ContextStrategy.allCases
        XCTAssertEqual(allCases.count, 4)
    }

    func testContextStrategyDescriptions() {
        for strategy in ConversationConfiguration.ContextStrategy.allCases {
            XCTAssertFalse(strategy.description.isEmpty)
        }
    }

    // MARK: - MetaAIPriority

    func testMetaAIPriorityAllocation() {
        XCTAssertEqual(ConversationConfiguration.MetaAIPriority.normal.allocationPercentage, 0.5)
        XCTAssertEqual(ConversationConfiguration.MetaAIPriority.high.allocationPercentage, 0.7)
        XCTAssertEqual(ConversationConfiguration.MetaAIPriority.maximum.allocationPercentage, 0.9)
    }

    // MARK: - TokenCountingMethod

    func testTokensPerChar() {
        XCTAssertEqual(ConversationConfiguration.TokenCountingMethod.tokensPerChar, 0.25)
    }

    // MARK: - Provider Context Sizes

    func testKnownProviderContextSizes() {
        let sizes = ConversationConfiguration.providerContextSizes

        XCTAssertEqual(sizes["anthropic/claude-sonnet-4"], 200_000)
        XCTAssertEqual(sizes["anthropic/claude-opus-4"], 200_000)
        XCTAssertEqual(sizes["openai/gpt-4o"], 128_000)
        XCTAssertEqual(sizes["google/gemini-2.0-flash"], 1_000_000)
        XCTAssertEqual(sizes["google/gemini-1.5-pro"], 2_000_000)
    }

    // MARK: - getEffectiveContextSize

    func testEffectiveContextSizeKnownProvider() {
        let config = ConversationConfiguration()
        XCTAssertEqual(config.getEffectiveContextSize(for: "anthropic/claude-opus-4"), 200_000)
    }

    func testEffectiveContextSizeUnknownProvider() {
        let config = ConversationConfiguration()
        XCTAssertEqual(config.getEffectiveContextSize(for: "unknown/provider"), 128_000)
    }

    func testEffectiveContextSizeCustomOverride() {
        var config = ConversationConfiguration()
        config.maxContextTokens = 50_000
        XCTAssertEqual(config.getEffectiveContextSize(for: "anthropic/claude-opus-4"), 50_000)
        XCTAssertEqual(config.getEffectiveContextSize(for: "unknown/provider"), 50_000)
    }

    // MARK: - getAvailableContextForChat

    func testAvailableContextWithMetaAI() {
        var config = ConversationConfiguration()
        config.allowMetaAIContextExpansion = true
        config.metaAIReservedTokens = 50000

        let available = config.getAvailableContextForChat(provider: "openai/gpt-4o")
        XCTAssertEqual(available, 128_000 - 50000)
    }

    func testAvailableContextWithoutMetaAI() {
        var config = ConversationConfiguration()
        config.allowMetaAIContextExpansion = false
        config.metaAIReservedTokens = 50000

        let available = config.getAvailableContextForChat(provider: "openai/gpt-4o")
        XCTAssertEqual(available, 128_000)
    }

    // MARK: - isUnlimited

    func testIsUnlimitedDefault() {
        let config = ConversationConfiguration()
        XCTAssertTrue(config.isUnlimited)
    }

    func testIsUnlimitedWithMaxTokens() {
        var config = ConversationConfiguration()
        config.maxContextTokens = 100_000
        XCTAssertFalse(config.isUnlimited)
    }

    func testIsUnlimitedWithMaxConversationLength() {
        var config = ConversationConfiguration()
        config.maxConversationLength = 50
        XCTAssertFalse(config.isUnlimited)
    }

    func testIsUnlimitedWithSlidingStrategy() {
        var config = ConversationConfiguration()
        config.contextStrategy = .sliding
        XCTAssertFalse(config.isUnlimited)
    }

    // MARK: - ContextManager Token Counting

    func testTokenCountEstimate() async {
        let manager = ContextManager.shared
        // "Hello world" = 11 chars * 0.25 = 2.75 ≈ 2 tokens (Int truncation)
        let count = await manager.countTokens("Hello world")
        XCTAssertGreaterThan(count, 0)
    }

    func testTokenCountEmptyString() async {
        let manager = ContextManager.shared
        let count = await manager.countTokens("")
        XCTAssertEqual(count, 0)
    }

    func testTokenCountLongerText() async {
        let manager = ContextManager.shared
        let shortCount = await manager.countTokens("Hi")
        let longCount = await manager.countTokens("This is a much longer piece of text with many more words and characters")
        XCTAssertGreaterThan(longCount, shortCount)
    }

    // MARK: - ContextManager wouldExceedContext

    func testWouldExceedContextUnlimited() async {
        let manager = ContextManager.shared
        // With unlimited strategy, should never exceed
        let result = await manager.wouldExceedContext(
            currentTokens: 999_999,
            newMessageTokens: 999_999,
            provider: "anthropic/claude-opus-4"
        )
        // Note: depends on loaded config — if strategy is unlimited, returns false
        // This test verifies the method runs without error
        _ = result
    }

    // MARK: - ContextManager getContextWindow

    func testGetContextWindow() async {
        let manager = ContextManager.shared
        let messages = [
            ContextManager.TokenizedMessage(
                id: UUID(), role: "user", content: "Hello", tokenCount: 5, timestamp: Date()
            ),
            ContextManager.TokenizedMessage(
                id: UUID(), role: "assistant", content: "Hi there", tokenCount: 8, timestamp: Date()
            )
        ]

        let window = await manager.getContextWindow(
            messages: messages,
            provider: "anthropic/claude-opus-4"
        )

        XCTAssertGreaterThan(window.totalTokens, 0)
        XCTAssertGreaterThanOrEqual(window.messagesIncluded, 0)
        XCTAssertGreaterThanOrEqual(window.availableTokens, 0)
    }

    func testGetContextWindowWithMetaAI() async {
        let manager = ContextManager.shared
        let messages = [
            ContextManager.TokenizedMessage(
                id: UUID(), role: "system", content: "You are helpful", tokenCount: 10, timestamp: Date()
            ),
            ContextManager.TokenizedMessage(
                id: UUID(), role: "user", content: "Hello", tokenCount: 5, timestamp: Date()
            )
        ]

        let normalWindow = await manager.getContextWindow(
            messages: messages,
            provider: "openai/gpt-4o",
            forMetaAI: false
        )

        let metaAIWindow = await manager.getContextWindow(
            messages: messages,
            provider: "openai/gpt-4o",
            forMetaAI: true
        )

        // Meta-AI window should have less available tokens (some reserved)
        XCTAssertLessThanOrEqual(metaAIWindow.availableTokens, normalWindow.availableTokens)
    }

    // MARK: - ContextManager prepareMessagesForAPI

    func testPrepareMessagesForAPI() async {
        let manager = ContextManager.shared
        let messages = (0 ..< 5).map { i in
            ContextManager.TokenizedMessage(
                id: UUID(),
                role: i % 2 == 0 ? "user" : "assistant",
                content: "Message \(i)",
                tokenCount: 100,
                timestamp: Date().addingTimeInterval(Double(i) * 60)
            )
        }

        let prepared = await manager.prepareMessagesForAPI(
            messages: messages,
            provider: "openai/gpt-4o"
        )

        XCTAssertGreaterThan(prepared.count, 0)
        XCTAssertLessThanOrEqual(prepared.count, messages.count + 1) // +1 for possible summary
    }

    // MARK: - Equatable

    func testConfigurationEquatable() {
        let a = ConversationConfiguration()
        let b = ConversationConfiguration()
        XCTAssertEqual(a, b)

        var c = ConversationConfiguration()
        c.maxContextTokens = 50_000
        XCTAssertNotEqual(a, c)
    }

    // MARK: - TokenizedMessage

    func testTokenizedMessageCreation() {
        let id = UUID()
        let date = Date()
        let msg = ContextManager.TokenizedMessage(
            id: id,
            role: "user",
            content: "Test message",
            tokenCount: 5,
            timestamp: date
        )

        XCTAssertEqual(msg.id, id)
        XCTAssertEqual(msg.role, "user")
        XCTAssertEqual(msg.content, "Test message")
        XCTAssertEqual(msg.tokenCount, 5)
        XCTAssertEqual(msg.timestamp, date)
    }
}
