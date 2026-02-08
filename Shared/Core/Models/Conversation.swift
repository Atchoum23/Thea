import Foundation
@preconcurrency import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool = false
    var projectID: UUID?
    var isArchived: Bool = false
    var isRead: Bool = true
    var status: String = "idle" // "idle" | "generating" | "error" | "queued"
    var lastModelUsed: String?

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
        isArchived: Bool = false,
        isRead: Bool = true,
        status: String = "idle",
        lastModelUsed: String? = nil,
        messages: [Message] = [],
        metadata: ConversationMetadata = ConversationMetadata()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.projectID = projectID
        self.isArchived = isArchived
        self.isRead = isRead
        self.status = status
        self.lastModelUsed = lastModelUsed
        self.messages = messages
        self.metadata = metadata
    }

    // MARK: - Convenience

    var hasUnreadMessages: Bool { !isRead }

    func markAsViewed() {
        isRead = true
    }

    func markAsUnread() {
        isRead = false
    }
}

// MARK: - Conversation Metadata

struct ConversationMetadata: Codable, Sendable {
    var totalTokens: Int
    var totalCost: Decimal
    var preferredModel: String?
    var tags: [String]
    var isMuted: Bool
    var systemPrompt: String?
    var lastExportedAt: Date?

    init(
        totalTokens: Int = 0,
        totalCost: Decimal = 0,
        preferredModel: String? = nil,
        tags: [String] = [],
        isMuted: Bool = false,
        systemPrompt: String? = nil,
        lastExportedAt: Date? = nil
    ) {
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.preferredModel = preferredModel
        self.tags = tags
        self.isMuted = isMuted
        self.systemPrompt = systemPrompt
        self.lastExportedAt = lastExportedAt
    }
}

// MARK: - Identifiable

extension Conversation: Identifiable {}
