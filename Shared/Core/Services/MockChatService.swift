// MockChatService.swift
// Mock implementation for testing - No SwiftData dependency
// Following 2025/2026 best practices: In-memory mock for fast unit tests

import Foundation
import TheaInterfaces

// MARK: - Mock Chat Service

/// In-memory mock implementation of ChatServiceProtocol for testing.
/// No SwiftData dependency - enables fast unit tests in Swift Package.
public actor MockChatService: ChatServiceProtocol {
    public private(set) var conversations: [UUID: MockConversation] = [:]
    public private(set) var messages: [UUID: [MessageSnapshot]] = [:]

    public init() {}

    // MARK: - Test Helpers

    public func reset() {
        conversations.removeAll()
        messages.removeAll()
    }

    public var conversationCount: Int {
        conversations.count
    }

    public func getConversation(_ id: UUID) -> MockConversation? {
        conversations[id]
    }

    // MARK: - ChatServiceProtocol

    public func createConversation(title: String) async throws -> UUID {
        let id = UUID()
        let conversation = MockConversation(
            id: id,
            title: title,
            createdAt: Date(),
            updatedAt: Date()
        )
        conversations[id] = conversation
        messages[id] = []
        return id
    }

    public func deleteConversation(_ id: UUID) async throws {
        guard conversations[id] != nil else {
            throw MockChatServiceError.conversationNotFound
        }
        conversations.removeValue(forKey: id)
        messages.removeValue(forKey: id)
    }

    public func fetchConversations() async throws -> [ConversationSnapshot] {
        conversations.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { $0.toSnapshot(messageCount: messages[$0.id]?.count ?? 0) }
    }

    public func addMessage(_ message: MessageSnapshot, to conversationID: UUID) async throws {
        guard var conversation = conversations[conversationID] else {
            throw MockChatServiceError.conversationNotFound
        }

        var conversationMessages = messages[conversationID] ?? []
        conversationMessages.append(message)
        messages[conversationID] = conversationMessages

        conversation.updatedAt = Date()
        conversations[conversationID] = conversation
    }

    public func getMessages(for conversationID: UUID) async throws -> [MessageSnapshot] {
        guard conversations[conversationID] != nil else {
            throw MockChatServiceError.conversationNotFound
        }
        return messages[conversationID] ?? []
    }
}

// MARK: - Mock Conversation

public struct MockConversation: Sendable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }

    public func toSnapshot(messageCount: Int) -> ConversationSnapshot {
        ConversationSnapshot(
            id: id,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isPinned: isPinned,
            messageCount: messageCount
        )
    }
}

// MARK: - Mock Errors

public enum MockChatServiceError: Error, Sendable {
    case conversationNotFound
    case messageNotFound
}
