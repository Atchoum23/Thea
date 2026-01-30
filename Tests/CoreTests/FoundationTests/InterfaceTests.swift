// InterfaceTests.swift
// Tests for the TheaInterfaces module

import Foundation
@testable import TheaInterfaces
import XCTest

final class InterfaceTests: XCTestCase {

    // MARK: - ChatServiceProtocol Tests

    func testConversationSnapshotCreation() {
        let snapshot = ConversationSnapshot(
            id: UUID(),
            title: "Test Conversation",
            createdAt: Date(),
            updatedAt: Date(),
            isPinned: true,
            messageCount: 5
        )

        XCTAssertEqual(snapshot.title, "Test Conversation")
        XCTAssertTrue(snapshot.isPinned)
        XCTAssertEqual(snapshot.messageCount, 5)
    }

    func testMessageSnapshotCreation() {
        let conversationID = UUID()
        let snapshot = MessageSnapshot(
            id: UUID(),
            conversationID: conversationID,
            role: .user,
            content: "Hello, World!",
            timestamp: Date(),
            tokenCount: 3
        )

        XCTAssertEqual(snapshot.conversationID, conversationID)
        XCTAssertEqual(snapshot.role, .user)
        XCTAssertEqual(snapshot.content, "Hello, World!")
        XCTAssertEqual(snapshot.tokenCount, 3)
    }

    func testMessageRoleSnapshot() {
        XCTAssertEqual(MessageRoleSnapshot.user.rawValue, "user")
        XCTAssertEqual(MessageRoleSnapshot.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRoleSnapshot.system.rawValue, "system")
    }

    // MARK: - ProjectServiceProtocol Tests

    func testProjectSnapshotCreation() {
        let snapshot = ProjectSnapshot(
            id: UUID(),
            title: "My Project",
            description: "A test project",
            createdAt: Date(),
            updatedAt: Date(),
            conversationCount: 10,
            rootPath: "/path/to/project"
        )

        XCTAssertEqual(snapshot.title, "My Project")
        XCTAssertEqual(snapshot.description, "A test project")
        XCTAssertEqual(snapshot.conversationCount, 10)
        XCTAssertEqual(snapshot.rootPath, "/path/to/project")
    }

    // MARK: - Codable Conformance Tests

    func testConversationSnapshotCodable() throws {
        let original = ConversationSnapshot(
            id: UUID(),
            title: "Test",
            createdAt: Date(),
            updatedAt: Date()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConversationSnapshot.self, from: encoded)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.title, decoded.title)
    }

    func testMessageSnapshotCodable() throws {
        let original = MessageSnapshot(
            id: UUID(),
            conversationID: UUID(),
            role: .assistant,
            content: "Test content",
            timestamp: Date()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MessageSnapshot.self, from: encoded)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.content, decoded.content)
    }

    func testProjectSnapshotCodable() throws {
        let original = ProjectSnapshot(
            id: UUID(),
            title: "Test Project",
            createdAt: Date(),
            updatedAt: Date()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProjectSnapshot.self, from: encoded)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.title, decoded.title)
    }

    // MARK: - TaskType Tests

    func testTaskTypeSnapshotAllCases() {
        // Verify all cases are accounted for
        XCTAssertEqual(TaskTypeSnapshot.allCases.count, 17)
    }

    func testTaskTypeSnapshotDisplayNames() {
        XCTAssertEqual(TaskTypeSnapshot.simpleQA.displayName, "Simple Q&A")
        XCTAssertEqual(TaskTypeSnapshot.codeGeneration.displayName, "Code Generation")
        XCTAssertEqual(TaskTypeSnapshot.complexReasoning.displayName, "Complex Reasoning")
        XCTAssertEqual(TaskTypeSnapshot.mathLogic.displayName, "Math & Logic")
    }

    func testTaskTypeSnapshotIcons() {
        XCTAssertEqual(TaskTypeSnapshot.simpleQA.icon, "questionmark.circle")
        XCTAssertEqual(TaskTypeSnapshot.codeGeneration.icon, "chevron.left.forwardslash.chevron.right")
        XCTAssertEqual(TaskTypeSnapshot.debugging.icon, "ant")
    }

    func testTaskTypeSnapshotCodable() throws {
        let original = TaskTypeSnapshot.codeGeneration

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TaskTypeSnapshot.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    func testTaskContextSnapshotCreation() {
        let context = TaskContextSnapshot(
            instruction: "Write a function",
            metadata: ["key": "value"],
            retryCount: 2,
            previousError: "Syntax error",
            verificationIssues: ["Issue 1"]
        )

        XCTAssertEqual(context.instruction, "Write a function")
        XCTAssertEqual(context.metadata["key"], "value")
        XCTAssertEqual(context.retryCount, 2)
        XCTAssertEqual(context.previousError, "Syntax error")
        XCTAssertEqual(context.verificationIssues.count, 1)
    }

    func testTaskContextSnapshotCodable() throws {
        let original = TaskContextSnapshot(
            instruction: "Test instruction",
            metadata: ["test": "data"],
            retryCount: 1
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TaskContextSnapshot.self, from: encoded)

        XCTAssertEqual(original.instruction, decoded.instruction)
        XCTAssertEqual(original.retryCount, decoded.retryCount)
    }

    func testSubtaskResultSnapshotCreation() {
        let result = SubtaskResultSnapshot(
            step: 1,
            output: "Success output",
            success: true,
            executionTime: 1.5
        )

        XCTAssertEqual(result.step, 1)
        XCTAssertEqual(result.output, "Success output")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.executionTime, 1.5)
    }

    func testSubtaskResultSnapshotCodable() throws {
        let original = SubtaskResultSnapshot(
            step: 2,
            output: "Test output",
            success: false,
            executionTime: 2.0
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SubtaskResultSnapshot.self, from: encoded)

        XCTAssertEqual(original.step, decoded.step)
        XCTAssertEqual(original.success, decoded.success)
    }
}
