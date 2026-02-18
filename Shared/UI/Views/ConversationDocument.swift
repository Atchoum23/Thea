import SwiftUI
import UniformTypeIdentifiers

// MARK: - Conversation Document (for export)
// @unchecked Sendable: Conversation SwiftData model is not Sendable across contexts; this document
// is created on the main actor and only accessed from FileDocument protocol callbacks on main thread

struct ConversationDocument: FileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.json] }

    let conversation: Conversation

    init(conversation: Conversation) {
        self.conversation = conversation
    }

    init(configuration _: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme, userInfo: [
            NSLocalizedDescriptionKey: "Reading conversation files is not supported. This document type is for export only."
        ])
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        let exportData = ExportedConversation(
            title: conversation.title,
            messages: conversation.messages.sorted { $0.orderIndex < $1.orderIndex }.map { message in
                ExportedMessage(
                    role: message.role,
                    content: message.content.textValue,
                    timestamp: message.timestamp
                )
            },
            createdAt: conversation.createdAt
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(exportData)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct ExportedConversation: Codable {
    let title: String
    let messages: [ExportedMessage]
    let createdAt: Date
}

struct ExportedMessage: Codable {
    let role: String
    let content: String
    let timestamp: Date
}
