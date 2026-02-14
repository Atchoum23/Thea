@preconcurrency import SwiftData
@testable import TheaModels
import XCTest

/// Tests for Message branching, device origin, order index, metadata,
/// and MessageContent/MessageRole types.
@MainActor
final class MessageBranchingTests: XCTestCase {
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

    // MARK: - Message Branching

    func testCreateBranchSetsParentMessageId() {
        let original = Message(
            conversationID: UUID(),
            role: .user,
            content: .text("Original")
        )
        let branch = original.createBranch(
            newContent: .text("Edited"),
            branchIndex: 1
        )
        XCTAssertEqual(branch.parentMessageId, original.id)
    }

    func testCreateBranchSetsIsEdited() {
        let original = Message(
            conversationID: UUID(),
            role: .user,
            content: .text("Original")
        )
        let branch = original.createBranch(
            newContent: .text("Edited"),
            branchIndex: 1
        )
        XCTAssertTrue(branch.isEdited)
    }

    func testCreateBranchPreservesOriginalContent() {
        let original = Message(
            conversationID: UUID(),
            role: .user,
            content: .text("Original text")
        )
        let branch = original.createBranch(
            newContent: .text("New text"),
            branchIndex: 1
        )
        // Branch has new content
        XCTAssertEqual(branch.content.textValue, "New text")
        // Original content is preserved in originalContentData
        XCTAssertEqual(branch.originalContent?.textValue, "Original text")
    }

    func testCreateBranchPreservesConversationID() {
        let convID = UUID()
        let original = Message(
            conversationID: convID,
            role: .assistant,
            content: .text("Response")
        )
        let branch = original.createBranch(
            newContent: .text("Different response"),
            branchIndex: 2
        )
        XCTAssertEqual(branch.conversationID, convID)
    }

    func testCreateBranchPreservesRole() {
        let original = Message(
            conversationID: UUID(),
            role: .assistant,
            content: .text("Response")
        )
        let branch = original.createBranch(
            newContent: .text("Alt response"),
            branchIndex: 1
        )
        XCTAssertEqual(branch.messageRole, .assistant)
    }

    func testCreateBranchPreservesOrderIndex() {
        let original = Message(
            conversationID: UUID(),
            role: .user,
            content: .text("Msg"),
            orderIndex: 5
        )
        let branch = original.createBranch(
            newContent: .text("Alt"),
            branchIndex: 1
        )
        XCTAssertEqual(branch.orderIndex, 5)
    }

    func testCreateBranchPreservesDeviceInfo() {
        let original = Message(
            conversationID: UUID(),
            role: .user,
            content: .text("Msg"),
            deviceID: "device-1",
            deviceName: "Mac Studio",
            deviceType: "mac"
        )
        let branch = original.createBranch(
            newContent: .text("Alt"),
            branchIndex: 1
        )
        XCTAssertEqual(branch.deviceID, "device-1")
        XCTAssertEqual(branch.deviceName, "Mac Studio")
        XCTAssertEqual(branch.deviceType, "mac")
    }

    func testCreateBranchAssignsBranchIndex() {
        let original = Message(
            conversationID: UUID(),
            role: .user,
            content: .text("Msg")
        )
        let branch1 = original.createBranch(newContent: .text("B1"), branchIndex: 1)
        let branch2 = original.createBranch(newContent: .text("B2"), branchIndex: 2)
        XCTAssertEqual(branch1.branchIndex, 1)
        XCTAssertEqual(branch2.branchIndex, 2)
    }

    func testOriginalMessageHasBranchIndexZero() {
        let original = Message(
            conversationID: UUID(),
            role: .user,
            content: .text("Msg")
        )
        XCTAssertEqual(original.branchIndex, 0)
        XCTAssertFalse(original.isEdited)
        XCTAssertNil(original.parentMessageId)
    }

    // MARK: - Device Origin

    func testDeviceOriginFieldsNilByDefault() {
        let msg = Message(conversationID: UUID(), role: .user, content: .text("Hi"))
        XCTAssertNil(msg.deviceID)
        XCTAssertNil(msg.deviceName)
        XCTAssertNil(msg.deviceType)
    }

    func testDeviceOriginFieldsSetExplicitly() {
        let msg = Message(
            conversationID: UUID(),
            role: .user,
            content: .text("Hi"),
            deviceID: "abc-123",
            deviceName: "iPhone 16",
            deviceType: "iPhone"
        )
        XCTAssertEqual(msg.deviceID, "abc-123")
        XCTAssertEqual(msg.deviceName, "iPhone 16")
        XCTAssertEqual(msg.deviceType, "iPhone")
    }

    // MARK: - Order Index

    func testOrderIndexDefaultsToZero() {
        let msg = Message(conversationID: UUID(), role: .user, content: .text("Hi"))
        XCTAssertEqual(msg.orderIndex, 0)
    }

    func testOrderIndexExplicitValue() {
        let msg = Message(
            conversationID: UUID(),
            role: .user,
            content: .text("Hi"),
            orderIndex: 42
        )
        XCTAssertEqual(msg.orderIndex, 42)
    }

    func testMessagesSortableByOrderIndex() {
        let convID = UUID()
        let m1 = Message(conversationID: convID, role: .user, content: .text("First"), orderIndex: 0)
        let m2 = Message(conversationID: convID, role: .assistant, content: .text("Second"), orderIndex: 1)
        let m3 = Message(conversationID: convID, role: .user, content: .text("Third"), orderIndex: 2)

        let sorted = [m3, m1, m2].sorted { $0.orderIndex < $1.orderIndex }
        XCTAssertEqual(sorted[0].orderIndex, 0)
        XCTAssertEqual(sorted[1].orderIndex, 1)
        XCTAssertEqual(sorted[2].orderIndex, 2)
    }

    // MARK: - MessageRole

    func testMessageRoleRawValues() {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRole.system.rawValue, "system")
    }

    func testMessageRoleFromRawValue() {
        XCTAssertEqual(MessageRole(rawValue: "user"), .user)
        XCTAssertEqual(MessageRole(rawValue: "assistant"), .assistant)
        XCTAssertEqual(MessageRole(rawValue: "system"), .system)
        XCTAssertNil(MessageRole(rawValue: "invalid"))
    }

    func testMessageRoleCodable() throws {
        for role in [MessageRole.user, .assistant, .system] {
            let data = try JSONEncoder().encode(role)
            let decoded = try JSONDecoder().decode(MessageRole.self, from: data)
            XCTAssertEqual(decoded, role)
        }
    }

    func testMessageRoleFromStoredString() {
        let msg = Message(conversationID: UUID(), role: .system, content: .text("System prompt"))
        XCTAssertEqual(msg.role, "system")
        XCTAssertEqual(msg.messageRole, .system)
    }

    func testInvalidRoleStringDefaultsToUser() {
        let msg = Message(conversationID: UUID(), role: .user, content: .text("Test"))
        // Manually set invalid role string
        msg.role = "invalid_role"
        XCTAssertEqual(msg.messageRole, .user, "Invalid role should default to .user")
    }

    // MARK: - MessageContent

    func testMessageContentTextValue() {
        let content = MessageContent.text("Hello world")
        XCTAssertEqual(content.textValue, "Hello world")
    }

    func testMessageContentMultimodalTextExtraction() {
        let parts = [
            ContentPart(type: .text("Part A")),
            ContentPart(type: .image(Data([1, 2, 3]))),
            ContentPart(type: .text("Part B")),
            ContentPart(type: .file("/path/to/file"))
        ]
        let content = MessageContent.multimodal(parts)
        XCTAssertEqual(content.textValue, "Part A\nPart B")
    }

    func testMessageContentMultimodalNoTextParts() {
        let parts = [
            ContentPart(type: .image(Data([1, 2, 3]))),
            ContentPart(type: .file("/path/to/file"))
        ]
        let content = MessageContent.multimodal(parts)
        XCTAssertEqual(content.textValue, "")
    }

    func testMessageContentCodableText() throws {
        let content = MessageContent.text("Test message")
        let data = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(MessageContent.self, from: data)
        XCTAssertEqual(decoded.textValue, "Test message")
    }

    func testMessageContentCodableMultimodal() throws {
        let parts = [
            ContentPart(type: .text("Hello")),
            ContentPart(type: .file("/test.txt"))
        ]
        let content = MessageContent.multimodal(parts)
        let data = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(MessageContent.self, from: data)
        XCTAssertEqual(decoded.textValue, "Hello")
    }

    // MARK: - MessageMetadata

    func testMessageMetadataDefaults() {
        let meta = MessageMetadata()
        XCTAssertNil(meta.finishReason)
        XCTAssertNil(meta.systemFingerprint)
        XCTAssertNil(meta.cachedTokens)
        XCTAssertNil(meta.reasoningTokens)
        XCTAssertNil(meta.respondingDeviceID)
        XCTAssertNil(meta.respondingDeviceName)
        XCTAssertNil(meta.respondingDeviceType)
        XCTAssertNil(meta.confidence)
    }

    func testMessageMetadataWithValues() {
        let meta = MessageMetadata(
            finishReason: "stop",
            systemFingerprint: "fp_abc123",
            cachedTokens: 500,
            reasoningTokens: 1200,
            respondingDeviceID: "dev-1",
            respondingDeviceName: "Mac Studio",
            respondingDeviceType: "mac",
            confidence: 0.85
        )
        XCTAssertEqual(meta.finishReason, "stop")
        XCTAssertEqual(meta.systemFingerprint, "fp_abc123")
        XCTAssertEqual(meta.cachedTokens, 500)
        XCTAssertEqual(meta.reasoningTokens, 1200)
        XCTAssertEqual(meta.confidence, 0.85)
    }

    func testMessageMetadataCodable() throws {
        let meta = MessageMetadata(
            finishReason: "stop",
            cachedTokens: 100,
            confidence: 0.95
        )
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(MessageMetadata.self, from: data)
        XCTAssertEqual(decoded.finishReason, "stop")
        XCTAssertEqual(decoded.cachedTokens, 100)
        XCTAssertEqual(decoded.confidence, 0.95)
    }

    func testMessageWithMetadata() {
        let meta = MessageMetadata(finishReason: "stop", confidence: 0.9)
        let msg = Message(
            conversationID: UUID(),
            role: .assistant,
            content: .text("Response"),
            metadata: meta
        )
        XCTAssertEqual(msg.metadata?.finishReason, "stop")
        XCTAssertEqual(msg.metadata?.confidence, 0.9)
    }

    func testMessageWithoutMetadata() {
        let msg = Message(
            conversationID: UUID(),
            role: .user,
            content: .text("Hi")
        )
        XCTAssertNil(msg.metadata)
    }

    // MARK: - Persistence

    func testMessagePersistsInSwiftData() throws {
        let conv = Conversation(title: "Test")
        modelContext.insert(conv)

        let msg = Message(
            conversationID: conv.id,
            role: .user,
            content: .text("Persisted message"),
            orderIndex: 1,
            deviceID: "dev-1",
            deviceName: "MacBook Air",
            deviceType: "mac"
        )
        msg.conversation = conv
        conv.messages.append(msg)
        modelContext.insert(msg)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<Message>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].content.textValue, "Persisted message")
        XCTAssertEqual(fetched[0].orderIndex, 1)
        XCTAssertEqual(fetched[0].deviceID, "dev-1")
    }

    func testBranchedMessagePersists() throws {
        let conv = Conversation(title: "Branch Test")
        modelContext.insert(conv)

        let original = Message(
            conversationID: conv.id,
            role: .user,
            content: .text("Original"),
            orderIndex: 0
        )
        modelContext.insert(original)

        let branch = original.createBranch(newContent: .text("Edited"), branchIndex: 1)
        modelContext.insert(branch)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<Message>())
        XCTAssertEqual(fetched.count, 2)

        let branchedMsg = fetched.first { $0.isEdited }
        XCTAssertNotNil(branchedMsg)
        XCTAssertEqual(branchedMsg?.parentMessageId, original.id)
        XCTAssertEqual(branchedMsg?.branchIndex, 1)
        XCTAssertEqual(branchedMsg?.originalContent?.textValue, "Original")
    }
}
