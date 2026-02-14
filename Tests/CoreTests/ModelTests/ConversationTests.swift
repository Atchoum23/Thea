@preconcurrency import SwiftData
@testable import TheaModels
import XCTest

@MainActor
final class ConversationTests: XCTestCase {
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
        let conversation = Conversation(title: "Test")
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

    // MARK: - Archive & Read State

    func testConversationArchiveDefaults() {
        let conversation = Conversation(title: "Test")
        XCTAssertFalse(conversation.isArchived)
        XCTAssertTrue(conversation.isRead)
        XCTAssertEqual(conversation.status, "idle")
        XCTAssertNil(conversation.lastModelUsed)
    }

    func testConversationArchiveToggle() {
        let conversation = Conversation(title: "Test")
        conversation.isArchived = true
        XCTAssertTrue(conversation.isArchived)
        conversation.isArchived = false
        XCTAssertFalse(conversation.isArchived)
    }

    func testConversationReadState() {
        let conversation = Conversation(title: "Test")
        XCTAssertTrue(conversation.isRead)
        XCTAssertFalse(conversation.hasUnreadMessages)

        conversation.markAsUnread()
        XCTAssertFalse(conversation.isRead)
        XCTAssertTrue(conversation.hasUnreadMessages)

        conversation.markAsViewed()
        XCTAssertTrue(conversation.isRead)
        XCTAssertFalse(conversation.hasUnreadMessages)
    }

    func testConversationStatus() {
        let conversation = Conversation(title: "Test")
        XCTAssertEqual(conversation.status, "idle")

        conversation.status = "generating"
        XCTAssertEqual(conversation.status, "generating")

        conversation.status = "error"
        XCTAssertEqual(conversation.status, "error")

        conversation.status = "queued"
        XCTAssertEqual(conversation.status, "queued")
    }

    func testConversationLastModelUsed() {
        let conversation = Conversation(title: "Test", lastModelUsed: "claude-opus-4-6")
        XCTAssertEqual(conversation.lastModelUsed, "claude-opus-4-6")
    }

    // MARK: - Metadata Extended

    func testMetadataDefaults() {
        let metadata = ConversationMetadata()
        XCTAssertEqual(metadata.totalTokens, 0)
        XCTAssertEqual(metadata.totalCost, 0)
        XCTAssertNil(metadata.preferredModel)
        XCTAssertTrue(metadata.tags.isEmpty)
        XCTAssertFalse(metadata.isMuted)
        XCTAssertNil(metadata.systemPrompt)
        XCTAssertNil(metadata.lastExportedAt)
        XCTAssertNil(metadata.preferredLanguage)
    }

    func testMetadataLanguage() {
        var metadata = ConversationMetadata()
        metadata.preferredLanguage = "fr-FR"
        XCTAssertEqual(metadata.preferredLanguage, "fr-FR")

        metadata.preferredLanguage = nil
        XCTAssertNil(metadata.preferredLanguage)
    }

    func testMetadataMuted() {
        var metadata = ConversationMetadata(isMuted: true)
        XCTAssertTrue(metadata.isMuted)
        metadata.isMuted = false
        XCTAssertFalse(metadata.isMuted)
    }

    func testMetadataSystemPrompt() {
        let metadata = ConversationMetadata(systemPrompt: "You are a helpful assistant")
        XCTAssertEqual(metadata.systemPrompt, "You are a helpful assistant")
    }

    func testMetadataCodable() throws {
        let original = ConversationMetadata(
            totalTokens: 500,
            totalCost: 0.15,
            preferredModel: "gpt-4o",
            tags: ["test", "coding"],
            isMuted: true,
            systemPrompt: "Be concise",
            preferredLanguage: "ja-JP"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConversationMetadata.self, from: data)

        XCTAssertEqual(decoded.totalTokens, 500)
        XCTAssertEqual(decoded.totalCost, 0.15)
        XCTAssertEqual(decoded.preferredModel, "gpt-4o")
        XCTAssertEqual(decoded.tags, ["test", "coding"])
        XCTAssertTrue(decoded.isMuted)
        XCTAssertEqual(decoded.systemPrompt, "Be concise")
        XCTAssertEqual(decoded.preferredLanguage, "ja-JP")
    }

    // MARK: - Cascade Delete

    func testDeleteConversationCascade() throws {
        let conversation = Conversation(title: "Test")
        let message1 = Message(conversationID: conversation.id, role: .user, content: .text("1"))
        let message2 = Message(conversationID: conversation.id, role: .assistant, content: .text("2"))

        // Establish the bidirectional relationship
        message1.conversation = conversation
        message2.conversation = conversation
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
