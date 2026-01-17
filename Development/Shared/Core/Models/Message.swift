import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var conversationID: UUID
    var role: String // "user", "assistant", "system"
    var contentData: Data // Encoded MessageContent
    var timestamp: Date
    var model: String?
    var tokenCount: Int?
    var metadataData: Data? // Encoded MessageMetadata

    var conversation: Conversation?

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: MessageRole,
        content: MessageContent,
        timestamp: Date = Date(),
        model: String? = nil,
        tokenCount: Int? = nil,
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role.rawValue
        self.contentData = (try? JSONEncoder().encode(content)) ?? Data()
        self.timestamp = timestamp
        self.model = model
        self.tokenCount = tokenCount
        self.metadataData = metadata.flatMap { try? JSONEncoder().encode($0) }
    }

    // Computed properties for easy access
    var messageRole: MessageRole {
        MessageRole(rawValue: role) ?? .user
    }

    var content: MessageContent {
        (try? JSONDecoder().decode(MessageContent.self, from: contentData)) ?? .text("")
    }

    var metadata: MessageMetadata? {
        guard let data = metadataData else { return nil }
        return try? JSONDecoder().decode(MessageMetadata.self, from: data)
    }
}

// MARK: - Message Role

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

// MARK: - Message Content

enum MessageContent: Codable, Sendable {
    case text(String)
    case multimodal([ContentPart])

    var textValue: String {
        switch self {
        case .text(let string):
            return string
        case .multimodal(let parts):
            return parts.compactMap { part in
                if case .text(let text) = part.type {
                    return text
                }
                return nil
            }.joined(separator: "\n")
        }
    }
}

struct ContentPart: Codable, Sendable {
    enum PartType: Codable, Sendable {
        case text(String)
        case image(Data)
        case file(String) // File path
    }
    let type: PartType
}

// MARK: - Message Metadata

struct MessageMetadata: Codable, Sendable {
    var finishReason: String?
    var systemFingerprint: String?
    var cachedTokens: Int?
    var reasoningTokens: Int?

    init(
        finishReason: String? = nil,
        systemFingerprint: String? = nil,
        cachedTokens: Int? = nil,
        reasoningTokens: Int? = nil
    ) {
        self.finishReason = finishReason
        self.systemFingerprint = systemFingerprint
        self.cachedTokens = cachedTokens
        self.reasoningTokens = reasoningTokens
    }
}

// MARK: - Identifiable

extension Message: Identifiable {}
