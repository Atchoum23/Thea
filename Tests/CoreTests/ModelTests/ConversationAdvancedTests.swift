@preconcurrency import SwiftData
@testable import TheaModels
import XCTest

/// Advanced tests for Conversation: status transitions, metadata, read/unread,
/// pin/archive, message ordering, and persistence edge cases.
@MainActor
final class ConversationAdvancedTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Status Transitions

    func testDefaultStatusIsIdle() {
        let conv = Conversation(title: "Test")
        XCTAssertEqual(conv.status, "idle")
    }

    func testStatusTransitionToGenerating() {
        let conv = Conversation(title: "Test")
        conv.status = "generating"
        XCTAssertEqual(conv.status, "generating")
    }

    func testStatusTransitionToError() {
        let conv = Conversation(title: "Test")
        conv.status = "error"
        XCTAssertEqual(conv.status, "error")
    }

    func testStatusTransitionToQueued() {
        let conv = Conversation(title: "Test")
        conv.status = "queued"
        XCTAssertEqual(conv.status, "queued")
    }

    // MARK: - Read / Unread

    func testMarkAsViewed() {
        let conv = Conversation(title: "Test")
        conv.isRead = false
        XCTAssertTrue(conv.hasUnreadMessages)
        conv.markAsViewed()
        XCTAssertTrue(conv.isRead)
        XCTAssertFalse(conv.hasUnreadMessages)
    }

    func testMarkAsUnread() {
        let conv = Conversation(title: "Test")
        XCTAssertTrue(conv.isRead)
        conv.markAsUnread()
        XCTAssertFalse(conv.isRead)
        XCTAssertTrue(conv.hasUnreadMessages)
    }

    func testHasUnreadMessagesReflectsIsRead() {
        let conv = Conversation(title: "Test")
        XCTAssertFalse(conv.hasUnreadMessages) // isRead=true by default
        conv.isRead = false
        XCTAssertTrue(conv.hasUnreadMessages)
    }

    // MARK: - Pin / Archive

    func testPinToggle() {
        let conv = Conversation(title: "Test")
        XCTAssertFalse(conv.isPinned)
        conv.isPinned = true
        XCTAssertTrue(conv.isPinned)
        conv.isPinned = false
        XCTAssertFalse(conv.isPinned)
    }

    func testArchiveToggle() {
        let conv = Conversation(title: "Test")
        XCTAssertFalse(conv.isArchived)
        conv.isArchived = true
        XCTAssertTrue(conv.isArchived)
    }

    // MARK: - Project Association

    func testProjectIDNilByDefault() {
        let conv = Conversation(title: "Test")
        XCTAssertNil(conv.projectID)
    }

    func testProjectIDSet() {
        let projectID = UUID()
        let conv = Conversation(title: "Test", projectID: projectID)
        XCTAssertEqual(conv.projectID, projectID)
    }

    // MARK: - Last Model Used

    func testLastModelUsedNilByDefault() {
        let conv = Conversation(title: "Test")
        XCTAssertNil(conv.lastModelUsed)
    }

    func testLastModelUsedSet() {
        let conv = Conversation(title: "Test", lastModelUsed: "claude-4-opus")
        XCTAssertEqual(conv.lastModelUsed, "claude-4-opus")
    }

    // MARK: - ConversationMetadata

    func testMetadataTokenAccumulation() {
        var meta = ConversationMetadata()
        meta.totalTokens = 500
        meta.totalTokens += 300
        XCTAssertEqual(meta.totalTokens, 800)
    }

    func testMetadataCostAccumulation() {
        var meta = ConversationMetadata()
        meta.totalCost = Decimal(string: "0.025")!
        meta.totalCost += Decimal(string: "0.015")!
        XCTAssertEqual(meta.totalCost, Decimal(string: "0.040"))
    }

    func testMetadataTags() {
        var meta = ConversationMetadata()
        meta.tags = ["coding", "swift"]
        meta.tags.append("test")
        XCTAssertEqual(meta.tags, ["coding", "swift", "test"])
    }

    func testMetadataEmptyTags() {
        let meta = ConversationMetadata()
        XCTAssertTrue(meta.tags.isEmpty)
    }

    func testMetadataSystemPrompt() {
        var meta = ConversationMetadata()
        meta.systemPrompt = "You are a helpful coding assistant"
        XCTAssertEqual(meta.systemPrompt, "You are a helpful coding assistant")
    }

    func testMetadataPreferredLanguage() {
        var meta = ConversationMetadata()
        meta.preferredLanguage = "fr-FR"
        XCTAssertEqual(meta.preferredLanguage, "fr-FR")
    }

    func testMetadataIsMuted() {
        var meta = ConversationMetadata()
        XCTAssertFalse(meta.isMuted)
        meta.isMuted = true
        XCTAssertTrue(meta.isMuted)
    }

    func testMetadataLastExportedAt() {
        var meta = ConversationMetadata()
        XCTAssertNil(meta.lastExportedAt)
        let date = Date()
        meta.lastExportedAt = date
        XCTAssertEqual(meta.lastExportedAt, date)
    }

    func testMetadataCodableRoundtrip() throws {
        let meta = ConversationMetadata(
            totalTokens: 1234,
            totalCost: Decimal(string: "0.567")!,
            preferredModel: "gpt-4o",
            tags: ["test", "coding"],
            isMuted: true,
            systemPrompt: "Be brief",
            lastExportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            preferredLanguage: "en-US"
        )
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(ConversationMetadata.self, from: data)

        XCTAssertEqual(decoded.totalTokens, 1234)
        XCTAssertEqual(decoded.totalCost, Decimal(string: "0.567"))
        XCTAssertEqual(decoded.preferredModel, "gpt-4o")
        XCTAssertEqual(decoded.tags, ["test", "coding"])
        XCTAssertTrue(decoded.isMuted)
        XCTAssertEqual(decoded.systemPrompt, "Be brief")
        XCTAssertNotNil(decoded.lastExportedAt)
        XCTAssertEqual(decoded.preferredLanguage, "en-US")
    }

    // MARK: - Message Ordering Within Conversation

    func testMessagesOrderedByOrderIndex() throws {
        let conv = Conversation(title: "Ordering Test")
        modelContext.insert(conv)

        for i in (0..<5).reversed() {
            let msg = Message(
                conversationID: conv.id,
                role: i % 2 == 0 ? .user : .assistant,
                content: .text("Message \(i)"),
                orderIndex: i
            )
            msg.conversation = conv
            conv.messages.append(msg)
            modelContext.insert(msg)
        }
        try modelContext.save()

        let sorted = conv.messages.sorted { $0.orderIndex < $1.orderIndex }
        for (idx, msg) in sorted.enumerated() {
            XCTAssertEqual(msg.orderIndex, idx)
        }
    }

    // MARK: - Conversation Creation Timestamps

    func testTimestampsSetAtCreation() {
        let before = Date()
        let conv = Conversation(title: "Timestamp Test")
        let after = Date()

        XCTAssertGreaterThanOrEqual(conv.createdAt, before)
        XCTAssertLessThanOrEqual(conv.createdAt, after)
        XCTAssertGreaterThanOrEqual(conv.updatedAt, before)
    }

    func testUpdatedAtCanBeModified() {
        let conv = Conversation(title: "Test")
        let newDate = Date(timeIntervalSince1970: 2_000_000_000)
        conv.updatedAt = newDate
        XCTAssertEqual(conv.updatedAt, newDate)
    }

    // MARK: - Persistence

    func testConversationPersistsWithMessages() throws {
        let conv = Conversation(
            title: "Persist Test",
            isPinned: true,
            isArchived: false,
            lastModelUsed: "claude-4"
        )
        modelContext.insert(conv)

        let msg = Message(
            conversationID: conv.id,
            role: .user,
            content: .text("Hello"),
            orderIndex: 0
        )
        msg.conversation = conv
        conv.messages.append(msg)
        modelContext.insert(msg)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<Conversation>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Persist Test")
        XCTAssertTrue(fetched[0].isPinned)
        XCTAssertEqual(fetched[0].lastModelUsed, "claude-4")
        XCTAssertEqual(fetched[0].messages.count, 1)
    }

    func testDeleteConversationCascadesMessages() throws {
        let conv = Conversation(title: "Cascade Test")
        modelContext.insert(conv)

        for i in 0..<3 {
            let msg = Message(
                conversationID: conv.id,
                role: .user,
                content: .text("Msg \(i)"),
                orderIndex: i
            )
            msg.conversation = conv
            conv.messages.append(msg)
            modelContext.insert(msg)
        }
        try modelContext.save()

        modelContext.delete(conv)
        try modelContext.save()

        let conversations = try modelContext.fetch(FetchDescriptor<Conversation>())
        XCTAssertEqual(conversations.count, 0)

        let messages = try modelContext.fetch(FetchDescriptor<Message>())
        XCTAssertEqual(messages.count, 0, "Messages should be cascaded-deleted with conversation")
    }

    // MARK: - Edge Cases

    func testVeryLongTitle() {
        let longTitle = String(repeating: "A", count: 10_000)
        let conv = Conversation(title: longTitle)
        XCTAssertEqual(conv.title, longTitle)
    }

    func testEmptyTitle() {
        let conv = Conversation(title: "")
        XCTAssertEqual(conv.title, "")
    }

    func testUnicodeTitleAndSystemPrompt() {
        let meta = ConversationMetadata(systemPrompt: "Réponds en français 🇫🇷")
        let conv = Conversation(title: "Test 日本語 🌍", metadata: meta)
        XCTAssertEqual(conv.title, "Test 日本語 🌍")
    }
}
