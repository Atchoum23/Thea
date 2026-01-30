// ChatService.swift
// Service layer implementation - Concrete chat operations
// Following 2025/2026 best practices: Service pattern with protocol conformance

import Foundation
import SwiftData

// MARK: - Chat Service Implementation

/// Concrete implementation of ChatServiceProtocol for production use.
/// Handles all chat operations with SwiftData persistence.
@MainActor
public final class ChatService: ChatServiceProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - ChatServiceProtocol

    public func createConversation(title: String) async throws -> UUID {
        let conversation = Conversation(title: title)
        modelContext.insert(conversation)
        try modelContext.save()
        return conversation.id
    }

    public func deleteConversation(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<Conversation>()
        let conversations = try modelContext.fetch(descriptor)
        guard let conversation = conversations.first(where: { $0.id == id }) else {
            throw ChatServiceError.conversationNotFound
        }
        modelContext.delete(conversation)
        try modelContext.save()
    }

    public func fetchConversations() async throws -> [ConversationSnapshot] {
        var descriptor = FetchDescriptor<Conversation>()
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        let conversations = try modelContext.fetch(descriptor)
        return conversations.map { $0.toSnapshot() }
    }

    public func addMessage(_ message: MessageSnapshot, to conversationID: UUID) async throws {
        let descriptor = FetchDescriptor<Conversation>()
        let conversations = try modelContext.fetch(descriptor)
        guard let conversation = conversations.first(where: { $0.id == conversationID }) else {
            throw ChatServiceError.conversationNotFound
        }

        let role: MessageRole = switch message.role {
        case .user: .user
        case .assistant: .assistant
        case .system: .system
        }

        let newMessage = Message(
            conversationID: conversationID,
            role: role,
            content: .text(message.content),
            orderIndex: conversation.messages.count
        )
        conversation.messages.append(newMessage)
        modelContext.insert(newMessage)
        try modelContext.save()
    }

    public func getMessages(for conversationID: UUID) async throws -> [MessageSnapshot] {
        let descriptor = FetchDescriptor<Conversation>()
        let conversations = try modelContext.fetch(descriptor)
        guard let conversation = conversations.first(where: { $0.id == conversationID }) else {
            throw ChatServiceError.conversationNotFound
        }
        return conversation.messages.sorted { $0.orderIndex < $1.orderIndex }.map { $0.toSnapshot() }
    }
}

// MARK: - Chat Service Errors

public enum ChatServiceError: Error, Sendable {
    case conversationNotFound
    case messageNotFound
    case persistenceError(String)
}

// MARK: - Model Extensions for Snapshots

extension Conversation {
    func toSnapshot() -> ConversationSnapshot {
        ConversationSnapshot(
            id: id,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isPinned: isPinned,
            messageCount: messages.count
        )
    }
}

extension Message {
    func toSnapshot() -> MessageSnapshot {
        let roleSnapshot: MessageRoleSnapshot = switch messageRole {
        case .user: .user
        case .assistant: .assistant
        case .system: .system
        }

        let contentText: String = switch content {
        case .text(let text): text
        case .multimodal(let parts): parts.compactMap {
            if case .text(let t) = $0 { return t }
            return nil
        }.joined(separator: " ")
        }

        return MessageSnapshot(
            id: id,
            conversationID: conversationID,
            role: roleSnapshot,
            content: contentText,
            timestamp: timestamp,
            tokenCount: tokenCount
        )
    }
}
