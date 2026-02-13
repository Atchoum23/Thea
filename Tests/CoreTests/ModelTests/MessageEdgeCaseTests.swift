@preconcurrency import SwiftData
@testable import TheaModels
import XCTest

@MainActor
final class MessageEdgeCaseTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        await MainActor.run {
            modelContainer = nil
            modelContext = nil
        }
    }

    // MARK: - Message Content Tests

    func testEmptyTextContent() {
        let message = Message(conversationID: UUID(), role: .user, content: .text(""))
        XCTAssertEqual(message.content.textValue, "")
    }

    func testVeryLongTextContent() {
        let longText = String(repeating: "a", count: 100_000)
        let message = Message(conversationID: UUID(), role: .assistant, content: .text(longText))
        XCTAssertEqual(message.content.textValue.count, 100_000)
    }

    func testUnicodeTextContent() {
        let unicode = "Hello 🌍 世界 مرحبا 🇫🇷 Ñoño"
        let message = Message(conversationID: UUID(), role: .user, content: .text(unicode))
        XCTAssertEqual(message.content.textValue, unicode)
    }

    func testMultilineTextContent() {
        let multiline = "Line 1\nLine 2\nLine 3\n\nLine 5"
        let message = Message(conversationID: UUID(), role: .user, content: .text(multiline))
        XCTAssertTrue(message.content.textValue.contains("\n"))
    }

    func testCodeBlockContent() {
        let code = """
        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```
        """
        let message = Message(conversationID: UUID(), role: .assistant, content: .text(code))
        XCTAssertTrue(message.content.textValue.contains("```swift"))
    }

    // MARK: - Multimodal Content Tests

    func testEmptyMultimodalParts() {
        let content = MessageContent.multimodal([])
        XCTAssertEqual(content.textValue, "")
    }

    func testSinglePartMultimodal() {
        let parts = [ContentPart(type: .text("Single part"))]
        let content = MessageContent.multimodal(parts)
        XCTAssertEqual(content.textValue, "Single part")
    }

    func testMultipleTextParts() {
        let parts = [
            ContentPart(type: .text("Part 1")),
            ContentPart(type: .text("Part 2")),
            ContentPart(type: .text("Part 3"))
        ]
        let content = MessageContent.multimodal(parts)
        XCTAssertTrue(content.textValue.contains("Part 1"))
        XCTAssertTrue(content.textValue.contains("Part 3"))
    }

    // MARK: - Message Metadata Tests

    func testMessageTimestamp() {
        let before = Date()
        let message = Message(conversationID: UUID(), role: .user, content: .text("Test"))
        let after = Date()

        XCTAssertGreaterThanOrEqual(message.timestamp, before)
        XCTAssertLessThanOrEqual(message.timestamp, after)
    }

    func testMessageModel() {
        let message = Message(conversationID: UUID(), role: .assistant, content: .text("Test"))
        message.model = "claude-3.5-sonnet"
        XCTAssertEqual(message.model, "claude-3.5-sonnet")
    }

    func testMessageModelNil() {
        let message = Message(conversationID: UUID(), role: .user, content: .text("Test"))
        XCTAssertNil(message.model)
    }

    // MARK: - Conversation Edge Cases

    func testConversationEmptyTitle() {
        let conversation = Conversation(title: "")
        XCTAssertEqual(conversation.title, "")
    }

    func testConversationSpecialCharactersTitle() {
        let title = "Test <script>alert('xss')</script>"
        let conversation = Conversation(title: title)
        XCTAssertEqual(conversation.title, title)
    }

    func testConversationArchive() {
        let conversation = Conversation(title: "Test")
        XCTAssertFalse(conversation.isArchived)
        conversation.isArchived = true
        XCTAssertTrue(conversation.isArchived)
    }

    func testConversationReadStatus() {
        let conversation = Conversation(title: "Test")
        XCTAssertTrue(conversation.isRead)
        conversation.isRead = false
        XCTAssertFalse(conversation.isRead)
    }

    func testConversationMultipleMessages() throws {
        let conversation = Conversation(title: "Multi")
        let conversationID = conversation.id

        for i in 0..<50 {
            let role: MessageRole = i % 2 == 0 ? .user : .assistant
            let message = Message(
                conversationID: conversationID,
                role: role,
                content: .text("Message \(i)")
            )
            message.conversation = conversation
            conversation.messages.append(message)
        }

        modelContext.insert(conversation)
        try modelContext.save()

        XCTAssertEqual(conversation.messages.count, 50)
    }

    // MARK: - Metadata Serialization Tests

    func testMetadataCodable() throws {
        var metadata = ConversationMetadata()
        metadata.totalTokens = 1500
        metadata.totalCost = 0.0025
        metadata.preferredModel = "claude-3-opus"
        metadata.tags = ["test", "coding"]
        metadata.systemPrompt = "You are a helpful assistant"
        metadata.preferredLanguage = "fr-FR"

        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(ConversationMetadata.self, from: data)

        XCTAssertEqual(decoded.totalTokens, 1500)
        XCTAssertEqual(decoded.totalCost, 0.0025)
        XCTAssertEqual(decoded.preferredModel, "claude-3-opus")
        XCTAssertEqual(decoded.tags, ["test", "coding"])
        XCTAssertEqual(decoded.systemPrompt, "You are a helpful assistant")
        XCTAssertEqual(decoded.preferredLanguage, "fr-FR")
    }

    func testMetadataDefaults() {
        let metadata = ConversationMetadata()
        XCTAssertEqual(metadata.totalTokens, 0)
        XCTAssertEqual(metadata.totalCost, 0)
        XCTAssertNil(metadata.preferredModel)
        XCTAssertTrue(metadata.tags.isEmpty)
        XCTAssertFalse(metadata.isMuted)
        XCTAssertNil(metadata.systemPrompt)
        XCTAssertNil(metadata.preferredLanguage)
    }
}
