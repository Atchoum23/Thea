@preconcurrency import SwiftData
@testable import Thea
import XCTest

@MainActor
final class ConversationTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() {
        modelContainer = nil
        modelContext = nil
    }

    func testConversationCreation() {
        let conversation = Conversation(title: "Test Conversation")

        XCTAssertNotNil(conversation.id)
        XCTAssertEqual(conversation.title, "Test Conversation")
        XCTAssertTrue(conversation.messages.isEmpty)
        XCTAssertFalse(conversation.isPinned)
        XCTAssertNil(conversation.projectID)
    }

    func testAddMessage() {
        let conversation = Conversation(title: "Test")
        let message = Message(
            conversationID: conversation.id,
            role: .user,
            content: .text("Hello")
        )

        conversation.messages.append(message)

        XCTAssertEqual(conversation.messages.count, 1)
        XCTAssertEqual(conversation.messages.first?.content.textValue, "Hello")
    }

    func testConversationPersistence() throws {
        let conversation = Conversation(title: "Persistent Test")
        modelContext.insert(conversation)
        try modelContext.save()

        let fetchDescriptor = FetchDescriptor<Conversation>()
        let conversations = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(conversations.count, 1)
        XCTAssertEqual(conversations.first?.title, "Persistent Test")
    }

    func testMessageRoles() {
        let userMessage = Message(conversationID: UUID(), role: .user, content: .text("Hi"))
        let assistantMessage = Message(conversationID: UUID(), role: .assistant, content: .text("Hello"))
        let systemMessage = Message(conversationID: UUID(), role: .system, content: .text("System"))

        XCTAssertEqual(userMessage.messageRole, .user)
        XCTAssertEqual(assistantMessage.messageRole, .assistant)
        XCTAssertEqual(systemMessage.messageRole, .system)
    }

    func testMultimodalContent() {
        let parts = [
            ContentPart(type: .text("Hello")),
            ContentPart(type: .text(" World"))
        ]
        let content = MessageContent.multimodal(parts)

        XCTAssertEqual(content.textValue, "Hello\n World")
    }

    func testConversationMetadata() {
        var conversation = Conversation(title: "Test")
        conversation.metadata.totalTokens = 100
        conversation.metadata.totalCost = 0.50
        conversation.metadata.preferredModel = "gpt-4o"
        conversation.metadata.tags = ["important", "work"]

        XCTAssertEqual(conversation.metadata.totalTokens, 100)
        XCTAssertEqual(conversation.metadata.totalCost, 0.50)
        XCTAssertEqual(conversation.metadata.preferredModel, "gpt-4o")
        XCTAssertEqual(conversation.metadata.tags.count, 2)
    }

    func testPinConversation() {
        let conversation = Conversation(title: "Test")
        XCTAssertFalse(conversation.isPinned)

        conversation.isPinned = true
        XCTAssertTrue(conversation.isPinned)
    }

    func testDeleteConversationCascade() throws {
        let conversation = Conversation(title: "Test")
        let message1 = Message(conversationID: conversation.id, role: .user, content: .text("1"))
        let message2 = Message(conversationID: conversation.id, role: .assistant, content: .text("2"))

        conversation.messages.append(contentsOf: [message1, message2])
        modelContext.insert(conversation)
        try modelContext.save()

        modelContext.delete(conversation)
        try modelContext.save()

        let fetchDescriptor = FetchDescriptor<Message>()
        let messages = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(messages.count, 0, "Messages should be deleted with conversation")
    }
}
