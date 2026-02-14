import Foundation

// MARK: - ConversationExporter

/// Exports conversations in multiple formats: Markdown, JSON, plain text.
/// Pure serialization layer — no SwiftData queries, no file I/O.
struct ConversationExporter: Sendable {

    enum ExportFormat: String, CaseIterable, Sendable {
        case markdown
        case json
        case plainText
    }

    /// Lightweight representation for export (decoupled from SwiftData).
    struct ExportedConversation: Codable, Sendable {
        let id: UUID
        let title: String
        let createdAt: Date
        let updatedAt: Date
        let messages: [ExportedMessage]
        let tags: [String]
        let totalTokens: Int
        let modelUsed: String?
    }

    struct ExportedMessage: Codable, Sendable {
        let id: UUID
        let role: String // "user", "assistant", "system"
        let content: String
        let timestamp: Date
        let model: String?
        let tokenCount: Int?
        let deviceName: String?
    }

    // MARK: - Public API

    static func export(
        _ conversation: ExportedConversation,
        format: ExportFormat
    ) -> String {
        switch format {
        case .markdown:
            return exportMarkdown(conversation)
        case .json:
            return exportJSON(conversation)
        case .plainText:
            return exportPlainText(conversation)
        }
    }

    static func exportMultiple(
        _ conversations: [ExportedConversation],
        format: ExportFormat
    ) -> String {
        switch format {
        case .markdown:
            return conversations
                .map { exportMarkdown($0) }
                .joined(separator: "\n\n---\n\n")
        case .json:
            return exportJSONArray(conversations)
        case .plainText:
            return conversations
                .map { exportPlainText($0) }
                .joined(separator: "\n\n========================================\n\n")
        }
    }

    /// Suggested filename for the export.
    static func suggestedFilename(
        for conversation: ExportedConversation,
        format: ExportFormat
    ) -> String {
        let sanitized = conversation.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .prefix(50)

        let ext: String
        switch format {
        case .markdown: ext = "md"
        case .json: ext = "json"
        case .plainText: ext = "txt"
        }

        let dateStr = Self.formatDateCompact(conversation.createdAt)
        return "\(sanitized)_\(dateStr).\(ext)"
    }

    // MARK: - Markdown Export

    private static func exportMarkdown(_ conversation: ExportedConversation) -> String {
        var lines: [String] = []

        lines.append("# \(conversation.title)")
        lines.append("")
        lines.append("**Created:** \(formatDate(conversation.createdAt))")
        lines.append("**Last Updated:** \(formatDate(conversation.updatedAt))")

        if let model = conversation.modelUsed {
            lines.append("**Model:** \(model)")
        }
        if conversation.totalTokens > 0 {
            lines.append("**Total Tokens:** \(conversation.totalTokens)")
        }
        if !conversation.tags.isEmpty {
            lines.append("**Tags:** \(conversation.tags.joined(separator: ", "))")
        }

        lines.append("")
        lines.append("---")
        lines.append("")

        for message in conversation.messages {
            let roleName: String
            let roleIcon: String

            switch message.role {
            case "user":
                roleName = "User"
                roleIcon = "👤"
            case "assistant":
                roleName = "Assistant"
                roleIcon = "🤖"
            case "system":
                roleName = "System"
                roleIcon = "⚙️"
            default:
                roleName = message.role.capitalized
                roleIcon = "💬"
            }

            lines.append("### \(roleIcon) \(roleName)")

            if let device = message.deviceName {
                lines.append("*From: \(device)*")
            }

            lines.append("*\(formatDate(message.timestamp))*")

            if let model = message.model {
                lines.append("*Model: \(model)*")
            }

            lines.append("")
            lines.append(message.content)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - JSON Export

    private static func exportJSON(_ conversation: ExportedConversation) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(conversation),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    private static func exportJSONArray(_ conversations: [ExportedConversation]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(conversations),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return jsonString
    }

    // MARK: - Plain Text Export

    private static func exportPlainText(_ conversation: ExportedConversation) -> String {
        var lines: [String] = []

        lines.append("Conversation: \(conversation.title)")
        lines.append("Created: \(formatDate(conversation.createdAt))")
        lines.append("Updated: \(formatDate(conversation.updatedAt))")

        if let model = conversation.modelUsed {
            lines.append("Model: \(model)")
        }

        lines.append("")

        for message in conversation.messages {
            let roleName: String
            switch message.role {
            case "user": roleName = "User"
            case "assistant": roleName = "Assistant"
            case "system": roleName = "System"
            default: roleName = message.role.capitalized
            }

            lines.append("[\(formatDate(message.timestamp))] \(roleName):")
            lines.append(message.content)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func formatDateCompact(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
