import SwiftData
@testable import TheaCore
import XCTest

@MainActor
final class ChatManagerTests: XCTestCase {
    var chatManager: ChatManager!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)

        chatManager = ChatManager.shared
        chatManager.configure(modelContext: modelContext)
    }

    override func tearDown() {
        chatManager = nil
        modelContainer = nil
        modelContext = nil
    }

    func testCreateConversation() {
        let conversation = chatManager.createConversation(title: "Test")

        XCTAssertNotNil(conversation)
        XCTAssertEqual(conversation.title, "Test")
        XCTAssertTrue(conversation.messages.isEmpty)
    }

    func testCreateDefaultConversation() {
        let conversation = chatManager.createConversation()

        XCTAssertEqual(conversation.title, "New Conversation")
    }

    func testDeleteConversation() throws {
        let conversation = chatManager.createConversation()
        let conversationID = conversation.id

        chatManager.deleteConversation(conversation)

        let fetchDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationID }
        )
        let conversations = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(conversations.count, 0)
    }

    func testUpdateConversationTitle() {
        let conversation = chatManager.createConversation(title: "Old Title")

        chatManager.updateConversationTitle(conversation, title: "New Title")

        XCTAssertEqual(conversation.title, "New Title")
    }

    func testTogglePin() {
        let conversation = chatManager.createConversation()
        XCTAssertFalse(conversation.isPinned)

        chatManager.togglePin(conversation)
        XCTAssertTrue(conversation.isPinned)

        chatManager.togglePin(conversation)
        XCTAssertFalse(conversation.isPinned)
    }

    func testDeleteMessage() {
        let conversation = chatManager.createConversation()
        let message = Message(conversationID: conversation.id, role: .user, content: .text("Test"))
        conversation.messages.append(message)

        XCTAssertEqual(conversation.messages.count, 1)

        chatManager.deleteMessage(message, from: conversation)

        XCTAssertEqual(conversation.messages.count, 0)
    }

    func testActiveConversation() {
        let conversation = chatManager.createConversation()
        chatManager.activeConversation = conversation

        XCTAssertEqual(chatManager.activeConversation?.id, conversation.id)
    }

    func testStreamingState() {
        XCTAssertFalse(chatManager.isStreaming)

        chatManager.isStreaming = true
        XCTAssertTrue(chatManager.isStreaming)

        chatManager.isStreaming = false
        XCTAssertFalse(chatManager.isStreaming)
    }
}
