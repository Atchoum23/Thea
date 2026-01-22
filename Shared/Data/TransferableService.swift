//
//  TransferableService.swift
//  Thea
//
//  Transferable representations for drag & drop and sharing
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Conversation Transferable

public struct TransferableConversation: Codable, Transferable, Sendable {
    public let id: UUID
    public let title: String
    public let messages: [TransferableMessage]
    public let createdAt: Date
    public let aiModel: String

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .theaConversation)

        DataRepresentation(exportedContentType: .json) { conversation in
            try JSONEncoder().encode(conversation)
        }

        DataRepresentation(exportedContentType: .plainText) { conversation in
            conversation.asPlainText().data(using: .utf8) ?? Data()
        }

        FileRepresentation(exportedContentType: .theaConversation) { conversation in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(conversation.title).theaconv")
            let data = try JSONEncoder().encode(conversation)
            try data.write(to: url)
            return SentTransferredFile(url)
        }
    }

    public func asPlainText() -> String {
        var text = "# \(title)\n"
        text += "Model: \(aiModel)\n"
        text += "Created: \(createdAt.formatted())\n\n"

        for message in messages {
            let role = message.isUser ? "User" : "Assistant"
            text += "**\(role):**\n\(message.content)\n\n"
        }

        return text
    }

    public func asMarkdown() -> String {
        var markdown = "# \(title)\n\n"
        markdown += "> Model: \(aiModel) | Created: \(createdAt.formatted())\n\n"

        for message in messages {
            if message.isUser {
                markdown += "## 👤 User\n\n\(message.content)\n\n"
            } else {
                markdown += "## 🤖 Thea\n\n\(message.content)\n\n"
            }
        }

        return markdown
    }
}

public struct TransferableMessage: Codable, Sendable {
    public let id: UUID
    public let content: String
    public let isUser: Bool
    public let timestamp: Date

    public init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

// MARK: - Code Snippet Transferable

public struct TransferableCodeSnippet: Codable, Transferable, Sendable {
    public let id: UUID
    public let code: String
    public let language: String
    public let filename: String?
    public let description: String?

    public init(
        id: UUID = UUID(),
        code: String,
        language: String,
        filename: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.code = code
        self.language = language
        self.filename = filename
        self.description = description
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .theaCodeSnippet)

        DataRepresentation(exportedContentType: .sourceCode) { snippet in
            snippet.code.data(using: .utf8) ?? Data()
        }

        DataRepresentation(exportedContentType: .plainText) { snippet in
            snippet.code.data(using: .utf8) ?? Data()
        }

        FileRepresentation(exportedContentType: .sourceCode) { snippet in
            let ext = snippet.fileExtension
            let name = snippet.filename ?? "snippet"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(name).\(ext)")
            try snippet.code.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }

    public var fileExtension: String {
        switch language.lowercased() {
        case "swift": return "swift"
        case "python": return "py"
        case "javascript", "js": return "js"
        case "typescript", "ts": return "ts"
        case "rust": return "rs"
        case "go": return "go"
        case "java": return "java"
        case "kotlin": return "kt"
        case "c": return "c"
        case "cpp", "c++": return "cpp"
        case "csharp", "c#": return "cs"
        case "ruby": return "rb"
        case "php": return "php"
        case "html": return "html"
        case "css": return "css"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "sql": return "sql"
        case "shell", "bash": return "sh"
        default: return "txt"
        }
    }
}

// MARK: - Knowledge Item Transferable

public struct TransferableKnowledgeItem: Codable, Transferable, Sendable {
    public let id: UUID
    public let title: String
    public let content: String
    public let category: String
    public let tags: [String]
    public let source: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        category: String,
        tags: [String] = [],
        source: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.tags = tags
        self.source = source
        self.createdAt = createdAt
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .theaKnowledge)

        DataRepresentation(exportedContentType: .plainText) { item in
            item.asPlainText().data(using: .utf8) ?? Data()
        }

        DataRepresentation(exportedContentType: .json) { item in
            try JSONEncoder().encode(item)
        }
    }

    public func asPlainText() -> String {
        var text = "# \(title)\n\n"
        text += "Category: \(category)\n"
        if !tags.isEmpty {
            text += "Tags: \(tags.joined(separator: ", "))\n"
        }
        if let source = source {
            text += "Source: \(source)\n"
        }
        text += "\n\(content)"
        return text
    }
}

// MARK: - Project Transferable

public struct TransferableProject: Codable, Transferable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let path: String
    public let languages: [String]
    public let files: [TransferableFile]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        path: String,
        languages: [String],
        files: [TransferableFile] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.path = path
        self.languages = languages
        self.files = files
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .theaProject)

        DataRepresentation(exportedContentType: .json) { project in
            try JSONEncoder().encode(project)
        }
    }
}

public struct TransferableFile: Codable, Sendable {
    public let name: String
    public let path: String
    public let content: String?
    public let language: String?

    public init(name: String, path: String, content: String? = nil, language: String? = nil) {
        self.name = name
        self.path = path
        self.content = content
        self.language = language
    }
}

// MARK: - AI Response Transferable

public struct TransferableAIResponse: Codable, Transferable, Sendable {
    public let id: UUID
    public let prompt: String
    public let response: String
    public let model: String
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        prompt: String,
        response: String,
        model: String,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.prompt = prompt
        self.response = response
        self.model = model
        self.timestamp = timestamp
        self.metadata = metadata
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .theaResponse)

        DataRepresentation(exportedContentType: .plainText) { response in
            response.response.data(using: .utf8) ?? Data()
        }

        DataRepresentation(exportedContentType: .json) { response in
            try JSONEncoder().encode(response)
        }
    }
}

// MARK: - Image with AI Analysis Transferable

public struct TransferableAnalyzedImage: Transferable, Sendable {
    public let imageData: Data
    public let analysis: String
    public let tags: [String]
    public let contentType: UTType

    public init(
        imageData: Data,
        analysis: String,
        tags: [String] = [],
        contentType: UTType = .png
    ) {
        self.imageData = imageData
        self.analysis = analysis
        self.tags = tags
        self.contentType = contentType
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.imageData
        }

        DataRepresentation(exportedContentType: .jpeg) { item in
            item.imageData
        }

        ProxyRepresentation { item in
            item.analysis
        }
    }
}

// MARK: - Custom UTTypes

extension UTType {
    public static var theaConversation: UTType {
        UTType(exportedAs: "app.thea.conversation")
    }

    public static var theaCodeSnippet: UTType {
        UTType(exportedAs: "app.thea.code-snippet")
    }

    public static var theaKnowledge: UTType {
        UTType(exportedAs: "app.thea.knowledge")
    }

    public static var theaProject: UTType {
        UTType(exportedAs: "app.thea.project")
    }

    public static var theaResponse: UTType {
        UTType(exportedAs: "app.thea.response")
    }
}

// MARK: - Drop Delegate

public struct TheaDropDelegate: DropDelegate {
    let onDrop: ([NSItemProvider]) -> Bool

    public init(onDrop: @escaping ([NSItemProvider]) -> Bool) {
        self.onDrop = onDrop
    }

    public func performDrop(info: DropInfo) -> Bool {
        return onDrop(info.itemProviders(for: [.text, .url, .fileURL, .image, .json]))
    }

    public func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.text, .url, .fileURL, .image, .json, .theaConversation])
    }
}

// MARK: - SwiftUI Extensions

public extension View {
    /// Make a view draggable with a conversation
    func draggable(conversation: TransferableConversation) -> some View {
        self.draggable(conversation)
    }

    /// Make a view draggable with a code snippet
    func draggable(codeSnippet: TransferableCodeSnippet) -> some View {
        self.draggable(codeSnippet)
    }

    /// Make a view draggable with a knowledge item
    func draggable(knowledge: TransferableKnowledgeItem) -> some View {
        self.draggable(knowledge)
    }

    /// Add drop support for Thea content types
    func theaDropDestination(
        onConversation: @escaping (TransferableConversation) -> Void = { _ in },
        onCode: @escaping (TransferableCodeSnippet) -> Void = { _ in },
        onKnowledge: @escaping (TransferableKnowledgeItem) -> Void = { _ in },
        onText: @escaping (String) -> Void = { _ in },
        onURL: @escaping (URL) -> Void = { _ in }
    ) -> some View {
        self
            .dropDestination(for: TransferableConversation.self) { items, _ in
                items.forEach { onConversation($0) }
                return !items.isEmpty
            }
            .dropDestination(for: TransferableCodeSnippet.self) { items, _ in
                items.forEach { onCode($0) }
                return !items.isEmpty
            }
            .dropDestination(for: TransferableKnowledgeItem.self) { items, _ in
                items.forEach { onKnowledge($0) }
                return !items.isEmpty
            }
            .dropDestination(for: String.self) { items, _ in
                items.forEach { onText($0) }
                return !items.isEmpty
            }
            .dropDestination(for: URL.self) { items, _ in
                items.forEach { onURL($0) }
                return !items.isEmpty
            }
    }
}

// MARK: - Share Link Extensions

public extension TransferableConversation {
    var sharePreview: SharePreview<String, Image> {
        SharePreview(title, image: Image(systemName: "bubble.left.and.bubble.right.fill"))
    }
}

public extension TransferableCodeSnippet {
    var sharePreview: SharePreview<String, Image> {
        SharePreview(filename ?? "Code Snippet", image: Image(systemName: "chevron.left.forwardslash.chevron.right"))
    }
}

public extension TransferableKnowledgeItem {
    var sharePreview: SharePreview<String, Image> {
        SharePreview(title, image: Image(systemName: "book.fill"))
    }
}
