// ChatServiceProtocol.swift
// Interface module - Protocol for chat operations
// Following 2025/2026 best practices: Abstract modules contain only interfaces

import Foundation

// MARK: - Chat Service Protocol

/// Protocol defining the core chat operations.
/// Managers and concrete implementations conform to this protocol.
/// This enables:
/// - Unit testing with mock implementations
/// - SwiftUI previews without real data
/// - Dependency injection
public protocol ChatServiceProtocol: Sendable {
    /// Creates a new conversation with the given title
    func createConversation(title: String) async throws -> UUID

    /// Deletes a conversation by its ID
    func deleteConversation(_ id: UUID) async throws

    /// Fetches all conversations
    func fetchConversations() async throws -> [ConversationSnapshot]

    /// Adds a message to a conversation
    func addMessage(_ message: MessageSnapshot, to conversationID: UUID) async throws

    /// Gets messages for a conversation
    func getMessages(for conversationID: UUID) async throws -> [MessageSnapshot]
}

// MARK: - Snapshot Types (Sendable value types for cross-boundary transfer)

/// A sendable snapshot of a conversation for interface boundaries
public struct ConversationSnapshot: Sendable, Identifiable, Codable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date
    public let isPinned: Bool
    public let messageCount: Int

    public init(
        id: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        isPinned: Bool = false,
        messageCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.messageCount = messageCount
    }
}

/// A sendable snapshot of a message for interface boundaries
public struct MessageSnapshot: Sendable, Identifiable, Codable {
    public let id: UUID
    public let conversationID: UUID
    public let role: MessageRoleSnapshot
    public let content: String
    public let timestamp: Date
    public let tokenCount: Int?

    public init(
        id: UUID,
        conversationID: UUID,
        role: MessageRoleSnapshot,
        content: String,
        timestamp: Date,
        tokenCount: Int? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.tokenCount = tokenCount
    }
}

/// Message role enum for interface layer
public enum MessageRoleSnapshot: String, Sendable, Codable {
    case user
    case assistant
    case system
}
