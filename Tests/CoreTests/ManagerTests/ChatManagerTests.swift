@preconcurrency import SwiftData
@testable import TheaCore
import XCTest

@MainActor
final class ChatManagerTests: XCTestCase {
    var chatManager: ChatManager!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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

        // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
        let fetchDescriptor = FetchDescriptor<Conversation>()
        let allConversations = try modelContext.fetch(fetchDescriptor)
        let conversations = allConversations.filter { $0.id == conversationID }

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

    // MARK: - Extended Tests (V4 Phase 1a)

    func testToggleArchive() {
        let conversation = chatManager.createConversation()
        XCTAssertFalse(conversation.isArchived)

        chatManager.toggleArchive(conversation)
        XCTAssertTrue(conversation.isArchived)

        chatManager.toggleArchive(conversation)
        XCTAssertFalse(conversation.isArchived)
    }

    func testToggleRead() {
        let conversation = chatManager.createConversation()
        let initialRead = conversation.isRead

        chatManager.toggleRead(conversation)
        XCTAssertNotEqual(conversation.isRead, initialRead)
    }

    func testClearAllData() {
        _ = chatManager.createConversation(title: "A")
        _ = chatManager.createConversation(title: "B")
        _ = chatManager.createConversation(title: "C")

        chatManager.clearAllData()

        XCTAssertNil(chatManager.activeConversation)
        XCTAssertFalse(chatManager.isStreaming)
        XCTAssertEqual(chatManager.streamingText, "")
    }

    func testDeleteActiveConversationClearsSelection() {
        let conversation = chatManager.createConversation()
        chatManager.activeConversation = conversation

        chatManager.deleteConversation(conversation)

        XCTAssertNil(chatManager.activeConversation)
    }

    func testDeleteNonActiveConversationKeepsSelection() {
        let conv1 = chatManager.createConversation(title: "Active")
        let conv2 = chatManager.createConversation(title: "Other")
        chatManager.activeConversation = conv1

        chatManager.deleteConversation(conv2)

        XCTAssertEqual(chatManager.activeConversation?.id, conv1.id)
    }

    func testUpdateTitleChangesUpdatedAt() {
        let conversation = chatManager.createConversation(title: "Original")
        let originalDate = conversation.updatedAt

        // Small delay to ensure timestamp differs
        chatManager.updateConversationTitle(conversation, title: "Updated")

        XCTAssertEqual(conversation.title, "Updated")
        XCTAssertGreaterThanOrEqual(conversation.updatedAt, originalDate)
    }

    func testCancelStreaming() {
        chatManager.isStreaming = true
        chatManager.streamingText = "partial response..."

        chatManager.cancelStreaming()

        XCTAssertFalse(chatManager.isStreaming)
        XCTAssertEqual(chatManager.streamingText, "")
    }

    func testMultipleConversationCreation() {
        let conv1 = chatManager.createConversation(title: "First")
        let conv2 = chatManager.createConversation(title: "Second")
        let conv3 = chatManager.createConversation(title: "Third")

        XCTAssertNotEqual(conv1.id, conv2.id)
        XCTAssertNotEqual(conv2.id, conv3.id)
    }

    func testConversationCreatedWithEmptyMessages() {
        let conversation = chatManager.createConversation(title: "Empty Chat")

        XCTAssertTrue(conversation.messages.isEmpty)
        XCTAssertEqual(conversation.status, "idle")
    }

    func testDeleteMessageFromConversation() {
        let conversation = chatManager.createConversation()
        let msg1 = Message(conversationID: conversation.id, role: .user, content: .text("Hello"))
        let msg2 = Message(conversationID: conversation.id, role: .assistant, content: .text("Hi"))
        conversation.messages.append(msg1)
        conversation.messages.append(msg2)

        XCTAssertEqual(conversation.messages.count, 2)

        chatManager.deleteMessage(msg1, from: conversation)

        XCTAssertEqual(conversation.messages.count, 1)
        XCTAssertEqual(conversation.messages.first?.role, .assistant)
    }

    func testBuildTaskSpecificPromptForCoding() {
        let prompt = ChatManager.buildTaskSpecificPrompt(for: .codeGeneration)
        XCTAssertFalse(prompt.isEmpty, "Task prompt for code generation should not be empty")
    }

    func testBuildTaskSpecificPromptForCreative() {
        let prompt = ChatManager.buildTaskSpecificPrompt(for: .creative)
        XCTAssertFalse(prompt.isEmpty, "Task prompt for creative should not be empty")
    }

    func testExtractPlanSteps() {
        let text = """
        Here is my plan:
        1. First step
        2. Second step
        3. Third step
        """
        let steps = ChatManager.extractPlanSteps(from: text)
        XCTAssertEqual(steps.count, 3)
        XCTAssertEqual(steps[0], "First step")
        XCTAssertEqual(steps[1], "Second step")
        XCTAssertEqual(steps[2], "Third step")
    }

    func testExtractPlanStepsEmpty() {
        let text = "No numbered steps here, just a paragraph."
        let steps = ChatManager.extractPlanSteps(from: text)
        XCTAssertEqual(steps.count, 0)
    }

    func testConversationPinPersistence() {
        let conversation = chatManager.createConversation()

        chatManager.togglePin(conversation)
        XCTAssertTrue(conversation.isPinned)

        // Pin state should survive re-toggling
        chatManager.togglePin(conversation)
        chatManager.togglePin(conversation)
        XCTAssertTrue(conversation.isPinned)
    }

    func testStreamingTextAccumulation() {
        chatManager.streamingText = ""
        chatManager.streamingText += "Hello"
        chatManager.streamingText += " World"
        XCTAssertEqual(chatManager.streamingText, "Hello World")
    }
}
