import Combine
import Foundation
import os.log
@preconcurrency import SwiftData

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

private let chatLogger = Logger(subsystem: "ai.thea.app", category: "ChatManager")

@MainActor
final class ChatManager: ObservableObject {
    static let shared = ChatManager()

    @Published var activeConversation: Conversation?
    @Published var isStreaming: Bool = false
    @Published var streamingText: String = ""
    @Published var conversations: [Conversation] = []
    @Published var messageQueue: [(text: String, conversation: Conversation)] = []

    /// Agent execution state for the current conversation
    @Published var agentState = AgentExecutionState()

    var modelContext: ModelContext?

    private init() {}

    /// Save model context with error logging instead of silent `try?`
    func saveContext(operation: String = #function) {
        do {
            try modelContext?.save()
        } catch {
            chatLogger.error("❌ Save failed in \(operation): \(error.localizedDescription)")
        }
    }

    // MARK: - Setup

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        loadConversations()
    }

    func configure(modelContext: ModelContext) {
        setModelContext(modelContext)
    }

    // MARK: - Conversation Management

    func loadConversations() {
        guard let context = modelContext else { return }
        var descriptor = FetchDescriptor<Conversation>()
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        do {
            conversations = try context.fetch(descriptor)
        } catch {
            chatLogger.error("❌ Failed to load conversations: \(error.localizedDescription)")
            conversations = []
        }
    }

    func selectConversation(_ conversation: Conversation) {
        activeConversation = conversation
    }

    func createConversation(title: String = "New Conversation") -> Conversation {
        let conversation = Conversation(title: title)
        modelContext?.insert(conversation)
        saveContext()
        conversations.insert(conversation, at: 0)
        return conversation
    }

    func deleteConversation(_ conversation: Conversation) {
        modelContext?.delete(conversation)
        saveContext()
        conversations.removeAll { $0.id == conversation.id }

        if activeConversation?.id == conversation.id {
            activeConversation = nil
        }
    }

    func clearAllData() {
        guard let context = modelContext else { return }

        for conversation in conversations {
            context.delete(conversation)
        }
        do {
            try context.save()
        } catch {
            chatLogger.error("❌ clearAllData save failed: \(error.localizedDescription)")
        }

        conversations.removeAll()
        activeConversation = nil
        isStreaming = false
        streamingText = ""
    }

    func updateConversationTitle(_ conversation: Conversation, title: String) {
        conversation.title = title
        conversation.updatedAt = Date()
        saveContext()
    }

    func togglePin(_ conversation: Conversation) {
        conversation.isPinned.toggle()
        saveContext()
    }

    func toggleArchive(_ conversation: Conversation) {
        conversation.isArchived.toggle()
        saveContext()
    }

    func toggleRead(_ conversation: Conversation) {
        if conversation.isRead {
            conversation.markAsUnread()
        } else {
            conversation.markAsViewed()
        }
        saveContext()
    }

    // MARK: - Auto Title Generation

    /// Generates a short title from the first user message when conversation still has the default title.
    func autoGenerateTitle(for conversation: Conversation) {
        guard conversation.title == "New Conversation" else { return }

        guard let firstUserMessage = conversation.messages
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .first(where: { $0.messageRole == .user })
        else { return }

        let text = firstUserMessage.content.textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let title: String
        let sentenceEnd = text.firstIndex { ".!?".contains($0) }
        if let sentenceEnd, text.distance(from: text.startIndex, to: sentenceEnd) < 60 {
            title = String(text[...sentenceEnd])
        } else if text.count <= 50 {
            title = text
        } else {
            let truncated = String(text.prefix(50))
            if let lastSpace = truncated.lastIndex(of: " ") {
                title = String(truncated[..<lastSpace]) + "…"
            } else {
                title = truncated + "…"
            }
        }

        conversation.title = title
        chatLogger.debug("📝 Auto-generated title: '\(title)'")
    }

    // MARK: - Foreground App Context Injection

    #if os(macOS)
    /// Injects foreground app context into a user message if app pairing is enabled
    /// Returns the modified message with context, or the original message if pairing disabled
    func injectForegroundAppContext(into message: String) -> String {
        guard ForegroundAppMonitor.shared.isPairingEnabled else {
            return message
        }

        guard let context = ForegroundAppMonitor.shared.appContext else {
            // No context available yet
            return message
        }

        let contextBlock = """
        <foreground_app_context>
        \(context.formatForPrompt())
        </foreground_app_context>

        """

        let enhancedMessage = contextBlock + message

        chatLogger.debug("📱 Injected foreground app context for \(context.appName)")

        return enhancedMessage
    }
    #else
    /// No-op on non-macOS platforms (app pairing is macOS-only)
    func injectForegroundAppContext(into message: String) -> String {
        message
    }
    #endif
}

// MARK: - AI Message (for provider communication)

struct AIMessage: Sendable {
    let id: UUID
    let conversationID: UUID
    let role: MessageRole
    let content: MessageContent
    let timestamp: Date
    let model: String
    var tokenCount: Int?
    var metadata: MessageMetadata?

    init(
        id: UUID,
        conversationID: UUID,
        role: MessageRole,
        content: MessageContent,
        timestamp: Date,
        model: String,
        tokenCount: Int? = nil,
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.model = model
        self.tokenCount = tokenCount
        self.metadata = metadata
    }
}

// MARK: - Errors

enum ChatError: Error, LocalizedError {
    case noModelContext
    case noUserMessage
    case providerNotAvailable
    case invalidAPIKey

    var errorDescription: String? {
        switch self {
        case .noModelContext:
            "Model context not available"
        case .noUserMessage:
            "No user message found"
        case .providerNotAvailable:
            "AI provider not available"
        case .invalidAPIKey:
            "Invalid API key"
        }
    }
}
