import Foundation
@preconcurrency import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var projectID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]

    @Attribute(.ephemeral) var metadata: ConversationMetadata

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        projectID: UUID? = nil,
        messages: [Message] = [],
        metadata: ConversationMetadata = ConversationMetadata()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.projectID = projectID
        self.messages = messages
        self.metadata = metadata
    }
}

// MARK: - Conversation Metadata

struct ConversationMetadata: Codable, Sendable {
    var totalTokens: Int
    var totalCost: Decimal
    var preferredModel: String?
    var tags: [String]

    init(
        totalTokens: Int = 0,
        totalCost: Decimal = 0,
        preferredModel: String? = nil,
        tags: [String] = []
    ) {
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.preferredModel = preferredModel
        self.tags = tags
    }
}

// MARK: - Identifiable

extension Conversation: Identifiable {}
