// MockChatServiceTests.swift
// Tests for MockChatService - Fast unit tests without SwiftData

import Foundation
@testable import TheaServices
@testable import TheaInterfaces
import XCTest

final class MockChatServiceTests: XCTestCase {

    var chatService: MockChatService!

    override func setUp() async throws {
        chatService = MockChatService()
    }

    override func tearDown() async throws {
        await chatService.reset()
        chatService = nil
    }

    // MARK: - Conversation Tests

    func testCreateConversation() async throws {
        let id = try await chatService.createConversation(title: "Test Conversation")

        XCTAssertNotNil(id)
        let count = await chatService.conversationCount
        XCTAssertEqual(count, 1)
    }

    func testCreateMultipleConversations() async throws {
        _ = try await chatService.createConversation(title: "First")
        _ = try await chatService.createConversation(title: "Second")
        _ = try await chatService.createConversation(title: "Third")

        let count = await chatService.conversationCount
        XCTAssertEqual(count, 3)
    }

    func testFetchConversations() async throws {
        _ = try await chatService.createConversation(title: "Alpha")
        _ = try await chatService.createConversation(title: "Beta")

        let conversations = try await chatService.fetchConversations()

        XCTAssertEqual(conversations.count, 2)
        // Most recent first (by updatedAt)
        XCTAssertEqual(conversations.first?.title, "Beta")
    }

    func testDeleteConversation() async throws {
        let id = try await chatService.createConversation(title: "To Delete")

        try await chatService.deleteConversation(id)

        let count = await chatService.conversationCount
        XCTAssertEqual(count, 0)
    }

    func testDeleteNonexistentConversation() async {
        let fakeID = UUID()

        do {
            try await chatService.deleteConversation(fakeID)
            XCTFail("Should throw conversationNotFound")
        } catch MockChatServiceError.conversationNotFound {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Message Tests

    func testAddMessage() async throws {
        let conversationID = try await chatService.createConversation(title: "Chat")

        let message = MessageSnapshot(
            id: UUID(),
            conversationID: conversationID,
            role: .user,
            content: "Hello, world!",
            timestamp: Date()
        )

        try await chatService.addMessage(message, to: conversationID)

        let messages = try await chatService.getMessages(for: conversationID)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.content, "Hello, world!")
    }

    func testAddMultipleMessages() async throws {
        let conversationID = try await chatService.createConversation(title: "Chat")

        let userMessage = MessageSnapshot(
            id: UUID(),
            conversationID: conversationID,
            role: .user,
            content: "Hi there",
            timestamp: Date()
        )

        let assistantMessage = MessageSnapshot(
            id: UUID(),
            conversationID: conversationID,
            role: .assistant,
            content: "Hello! How can I help?",
            timestamp: Date()
        )

        try await chatService.addMessage(userMessage, to: conversationID)
        try await chatService.addMessage(assistantMessage, to: conversationID)

        let messages = try await chatService.getMessages(for: conversationID)
        XCTAssertEqual(messages.count, 2)
    }

    func testAddMessageUpdatesConversationTimestamp() async throws {
        let conversationID = try await chatService.createConversation(title: "Chat")

        let conversationsBefore = try await chatService.fetchConversations()
        let timestampBefore = conversationsBefore.first!.updatedAt

        // Small delay to ensure timestamp difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        let message = MessageSnapshot(
            id: UUID(),
            conversationID: conversationID,
            role: .user,
            content: "Message",
            timestamp: Date()
        )

        try await chatService.addMessage(message, to: conversationID)

        let conversationsAfter = try await chatService.fetchConversations()
        let timestampAfter = conversationsAfter.first!.updatedAt

        XCTAssertGreaterThan(timestampAfter, timestampBefore)
    }

    func testGetMessagesForNonexistentConversation() async {
        let fakeID = UUID()

        do {
            _ = try await chatService.getMessages(for: fakeID)
            XCTFail("Should throw conversationNotFound")
        } catch MockChatServiceError.conversationNotFound {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Reset Tests

    func testReset() async throws {
        _ = try await chatService.createConversation(title: "One")
        _ = try await chatService.createConversation(title: "Two")

        await chatService.reset()

        let count = await chatService.conversationCount
        XCTAssertEqual(count, 0)
    }
}
