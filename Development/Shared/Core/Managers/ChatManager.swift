import Foundation
import SwiftData
import Combine

@MainActor
final class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    @Published var activeConversation: Conversation?
    @Published var isStreaming: Bool = false
    @Published var streamingText: String = ""
    @Published private(set) var conversations: [Conversation] = []
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    // MARK: - Setup
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadConversations()
    }
    
    func configure(modelContext: ModelContext) {
        setModelContext(modelContext)
    }
    
    // MARK: - Conversation Management
    
    func loadConversations() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        conversations = (try? context.fetch(descriptor)) ?? []
    }
    
    func selectConversation(_ conversation: Conversation) {
        activeConversation = conversation
    }
    
    func createConversation(title: String = "New Conversation") -> Conversation {
        let conversation = Conversation(title: title)
        modelContext?.insert(conversation)
        try? modelContext?.save()
        conversations.insert(conversation, at: 0)
        return conversation
    }
    
    func deleteConversation(_ conversation: Conversation) {
        modelContext?.delete(conversation)
        try? modelContext?.save()
        conversations.removeAll { $0.id == conversation.id }
        
        if activeConversation?.id == conversation.id {
            activeConversation = nil
        }
    }
    
    func updateConversationTitle(_ conversation: Conversation, title: String) {
        conversation.title = title
        conversation.updatedAt = Date()
        try? modelContext?.save()
    }
    
    func togglePin(_ conversation: Conversation) {
        conversation.isPinned.toggle()
        try? modelContext?.save()
    }
    
    // MARK: - Message Management
    
    func sendMessage(_ text: String, in conversation: Conversation) async throws {
        guard let context = modelContext else {
            throw ChatError.noModelContext
        }
        
        // Get active provider
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            throw ChatError.providerNotAvailable
        }
        
        let model = AppConfiguration.shared.providerConfig.defaultModel
        
        // Create user message
        let userMessage = Message(
            conversationID: conversation.id,
            role: .user,
            content: .text(text)
        )
        conversation.messages.append(userMessage)
        context.insert(userMessage)
        try context.save()
        
        // Prepare messages for API
        let apiMessages = conversation.messages.map { msg in
            AIMessage(
                id: msg.id,
                conversationID: msg.conversationID,
                role: msg.messageRole,
                content: msg.content,
                timestamp: msg.timestamp,
                model: msg.model ?? model
            )
        }
        
        // Stream response
        isStreaming = true
        streamingText = ""
        
        let assistantMessage = Message(
            conversationID: conversation.id,
            role: .assistant,
            content: .text("")
        )
        assistantMessage.model = model
        conversation.messages.append(assistantMessage)
        context.insert(assistantMessage)
        
        do {
            let responseStream = try await provider.chat(
                messages: apiMessages,
                model: model,
                stream: true
            )
            
            for try await chunk in responseStream {
                switch chunk.type {
                case .delta(let text):
                    streamingText += text
                    assistantMessage.contentData = try JSONEncoder().encode(MessageContent.text(streamingText))
                    
                case .complete(let finalMessage):
                    assistantMessage.contentData = try JSONEncoder().encode(finalMessage.content)
                    assistantMessage.tokenCount = finalMessage.tokenCount
                    if let metadata = finalMessage.metadata {
                        assistantMessage.metadataData = try? JSONEncoder().encode(metadata)
                    }
                    
                case .error(let error):
                    throw error
                }
            }
            
            conversation.updatedAt = Date()
            try context.save()
            
        } catch {
            context.delete(assistantMessage)
            conversation.messages.removeLast()
            throw error
        }
        
        isStreaming = false
        streamingText = ""
    }
    
    func cancelStreaming() {
        // Cancel ongoing streaming
        isStreaming = false
        streamingText = ""
    }
    
    func deleteMessage(_ message: Message, from conversation: Conversation) {
        modelContext?.delete(message)
        try? modelContext?.save()
    }
    
    func regenerateLastMessage(in conversation: Conversation) async throws {
        if let lastMessage = conversation.messages.last,
           lastMessage.messageRole == .assistant {
            deleteMessage(lastMessage, from: conversation)
        }
        
        guard let lastUserMessage = conversation.messages.last(where: { $0.messageRole == .user }) else {
            throw ChatError.noUserMessage
        }
        
        try await sendMessage(lastUserMessage.content.textValue, in: conversation)
    }
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
            return "Model context not available"
        case .noUserMessage:
            return "No user message found"
        case .providerNotAvailable:
            return "AI provider not available"
        case .invalidAPIKey:
            return "Invalid API key"
        }
    }
}
