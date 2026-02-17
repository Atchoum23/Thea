// Conversation.swift
// TheaWeb - Conversation and Message models for persistent chat storage

import Fluent
import Vapor

/// Persistent conversation model
// @unchecked Sendable: Fluent Model — thread safety managed by database layer
final class Conversation: Model, Content, @unchecked Sendable {
    static let schema = "conversations"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "title")
    var title: String

    @OptionalField(key: "system_prompt")
    var systemPrompt: String?

    @Field(key: "model")
    var model: String

    @Field(key: "message_count")
    var messageCount: Int

    @OptionalField(key: "share_id")
    var shareId: String?

    @OptionalField(key: "share_expires_at")
    var shareExpiresAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Children(for: \.$conversation)
    var messages: [Message]

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        title: String = "New Conversation",
        model: String = "claude-sonnet",
        systemPrompt: String? = nil
    ) {
        self.id = id
        self.$user.id = userID
        self.title = title
        self.model = model
        self.systemPrompt = systemPrompt
        self.messageCount = 0
    }
}

/// Chat message model
// @unchecked Sendable: Fluent Model — thread safety managed by database layer
final class Message: Model, Content, @unchecked Sendable {
    static let schema = "messages"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "conversation_id")
    var conversation: Conversation

    @Field(key: "role")
    var role: String

    @Field(key: "content")
    var content: String

    @OptionalField(key: "model")
    var model: String?

    @OptionalField(key: "tokens_used")
    var tokensUsed: Int?

    @Field(key: "order_index")
    var orderIndex: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        conversationID: UUID,
        role: String,
        content: String,
        model: String? = nil,
        tokensUsed: Int? = nil,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.$conversation.id = conversationID
        self.role = role
        self.content = content
        self.model = model
        self.tokensUsed = tokensUsed
        self.orderIndex = orderIndex
    }
}

// MARK: - Migrations

struct CreateConversation: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("conversations")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("title", .string, .required)
            .field("system_prompt", .string)
            .field("model", .string, .required)
            .field("message_count", .int, .required)
            .field("share_id", .string)
            .field("share_expires_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("conversations").delete()
    }
}

struct CreateMessage: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("messages")
            .id()
            .field("conversation_id", .uuid, .required, .references("conversations", "id", onDelete: .cascade))
            .field("role", .string, .required)
            .field("content", .string, .required)
            .field("model", .string)
            .field("tokens_used", .int)
            .field("order_index", .int, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("messages").delete()
    }
}
