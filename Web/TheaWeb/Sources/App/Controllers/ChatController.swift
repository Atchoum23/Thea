// ChatController.swift
// TheaWeb - Chat/Conversation API controller with real persistence

import Vapor
import Fluent

/// Controller for chat/conversation endpoints
struct ChatController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let chat = routes.grouped("chat")

        chat.post("send", use: sendMessage)
        chat.get("conversations", use: listConversations)
        chat.post("conversations", use: createConversation)
        chat.get("conversations", ":id", use: getConversation)
        chat.delete("conversations", ":id", use: deleteConversation)
        chat.post("conversations", ":id", "share", use: shareConversation)
    }

    // MARK: - Send Message

    @Sendable
    func sendMessage(req: Request) async throws -> ChatResponse {
        let user = try req.auth.require(User.self)
        let input = try req.content.decode(ChatRequest.self)

        guard !input.message.isEmpty else {
            throw Abort(.badRequest, reason: "Message cannot be empty")
        }
        guard input.message.count <= 32_000 else {
            throw Abort(.badRequest, reason: "Message exceeds maximum length")
        }

        let conversation = try await findOrCreateConversation(for: user, input: input, on: req.db)

        // Save user message
        let messageCount = try await Message.query(on: req.db)
            .filter(\.$conversation.$id == conversation.id!)
            .count()
        let userMessage = Message(
            conversationID: conversation.id!,
            role: "user",
            content: input.message,
            orderIndex: messageCount
        )
        try await userMessage.save(on: req.db)

        // Forward to local Thea instance for AI response
        let theaResponse = try await forwardToThea(
            message: input.message,
            conversationId: conversation.id!,
            model: input.preferredModel,
            req: req
        )

        // Save assistant response and update conversation
        return try await saveAssistantResponse(
            theaResponse, conversation: conversation,
            messageCount: messageCount, on: req.db
        )
    }

    private func findOrCreateConversation(
        for user: User, input: ChatRequest, on database: Database
    ) async throws -> Conversation {
        if let convId = input.conversationId,
           let existing = try await Conversation.query(on: database)
            .filter(\.$id == convId)
            .filter(\.$user.$id == user.id!)
            .first() {
            return existing
        }
        let title = String(input.message.prefix(80))
        let conversation = Conversation(
            userID: user.id!,
            title: title,
            model: input.preferredModel ?? "claude-sonnet"
        )
        try await conversation.save(on: database)
        return conversation
    }

    private func saveAssistantResponse(
        _ theaResponse: TheaInternalResponse,
        conversation: Conversation,
        messageCount: Int,
        on database: Database
    ) async throws -> ChatResponse {
        let assistantMessage = Message(
            conversationID: conversation.id!,
            role: "assistant",
            content: theaResponse.response,
            model: theaResponse.model,
            tokensUsed: theaResponse.tokensUsed,
            orderIndex: messageCount + 1
        )
        try await assistantMessage.save(on: database)

        conversation.messageCount = messageCount + 2
        try await conversation.save(on: database)

        return ChatResponse(
            id: assistantMessage.id ?? UUID(),
            conversationId: conversation.id!,
            response: theaResponse.response,
            model: theaResponse.model,
            tokensUsed: theaResponse.tokensUsed,
            createdAt: Date(),
            suggestions: theaResponse.suggestions
        )
    }

    // MARK: - Create Conversation

    @Sendable
    func createConversation(req: Request) async throws -> ConversationSummary {
        let user = try req.auth.require(User.self)
        let input = try? req.content.decode(CreateConversationRequest.self)

        let conversation = Conversation(
            userID: user.id!,
            title: input?.title ?? "New Conversation",
            model: input?.model ?? "claude-sonnet",
            systemPrompt: input?.systemPrompt
        )
        try await conversation.save(on: req.db)

        return ConversationSummary(
            id: conversation.id!,
            title: conversation.title,
            lastMessage: "",
            messageCount: 0,
            model: conversation.model,
            createdAt: conversation.createdAt ?? Date(),
            updatedAt: conversation.updatedAt ?? Date()
        )
    }

    // MARK: - List Conversations

    @Sendable
    func listConversations(req: Request) async throws -> [ConversationSummary] {
        let user = try req.auth.require(User.self)

        let conversations = try await Conversation.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .sort(\.$updatedAt, .descending)
            .limit(100)
            .all()

        var summaries: [ConversationSummary] = []
        for conv in conversations {
            let lastMsg = try await Message.query(on: req.db)
                .filter(\.$conversation.$id == conv.id!)
                .sort(\.$orderIndex, .descending)
                .first()

            summaries.append(ConversationSummary(
                id: conv.id!,
                title: conv.title,
                lastMessage: String((lastMsg?.content ?? "").prefix(100)),
                messageCount: conv.messageCount,
                model: conv.model,
                createdAt: conv.createdAt ?? Date(),
                updatedAt: conv.updatedAt ?? Date()
            ))
        }
        return summaries
    }

    // MARK: - Get Conversation

    @Sendable
    func getConversation(req: Request) async throws -> ConversationDetail {
        let user = try req.auth.require(User.self)

        guard let conversationId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID")
        }

        guard let conversation = try await Conversation.query(on: req.db)
            .filter(\.$id == conversationId)
            .filter(\.$user.$id == user.id!)
            .first() else {
            throw Abort(.notFound, reason: "Conversation not found")
        }

        let messages = try await Message.query(on: req.db)
            .filter(\.$conversation.$id == conversationId)
            .sort(\.$orderIndex, .ascending)
            .all()

        let messageDTOs = messages.map { msg in
            MessageDTO(
                id: msg.id ?? UUID(),
                role: msg.role,
                content: msg.content,
                model: msg.model,
                tokensUsed: msg.tokensUsed,
                createdAt: msg.createdAt ?? Date()
            )
        }

        return ConversationDetail(
            id: conversation.id!,
            title: conversation.title,
            messages: messageDTOs,
            model: conversation.model,
            createdAt: conversation.createdAt ?? Date(),
            updatedAt: conversation.updatedAt ?? Date()
        )
    }

    // MARK: - Delete Conversation

    @Sendable
    func deleteConversation(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)

        guard let conversationId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID")
        }

        guard let conversation = try await Conversation.query(on: req.db)
            .filter(\.$id == conversationId)
            .filter(\.$user.$id == user.id!)
            .first() else {
            throw Abort(.notFound, reason: "Conversation not found")
        }

        try await conversation.delete(on: req.db)
        return .ok
    }

    // MARK: - Share Conversation

    @Sendable
    func shareConversation(req: Request) async throws -> ShareResponse {
        let user = try req.auth.require(User.self)

        guard let conversationId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID")
        }

        guard let conversation = try await Conversation.query(on: req.db)
            .filter(\.$id == conversationId)
            .filter(\.$user.$id == user.id!)
            .first() else {
            throw Abort(.notFound, reason: "Conversation not found")
        }

        let shareId = generateShareId()
        conversation.shareId = shareId
        conversation.shareExpiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60)
        try await conversation.save(on: req.db)

        return ShareResponse(
            shareUrl: "https://theathe.app/share/\(shareId)",
            expiresAt: conversation.shareExpiresAt!
        )
    }

    // MARK: - Private Helpers

    private func forwardToThea(
        message: String,
        conversationId: UUID,
        model: String?,
        req: Request
    ) async throws -> TheaInternalResponse {
        let theaURL = Environment.get("THEA_BACKEND_URL") ?? "http://localhost:8081"
        let uri = URI(string: "\(theaURL)/api/chat")

        let requestBody = TheaInternalRequest(
            message: message,
            conversationId: conversationId,
            preferredModel: model
        )

        let response = try await req.client.post(uri) { clientReq in
            try clientReq.content.encode(requestBody)
        }

        guard response.status == .ok else {
            req.logger.error("Thea backend returned: \(response.status)")
            throw Abort(.serviceUnavailable, reason: "Thea service temporarily unavailable")
        }

        return try response.content.decode(TheaInternalResponse.self)
    }

    private func generateShareId() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Request/Response Types

struct ChatRequest: Content {
    let message: String
    let conversationId: UUID?
    let preferredModel: String?
    let familySafe: Bool?
}

struct CreateConversationRequest: Content {
    let title: String?
    let model: String?
    let systemPrompt: String?
}

struct ChatResponse: Content {
    let id: UUID
    let conversationId: UUID
    let response: String
    let model: String
    let tokensUsed: Int
    let createdAt: Date
    let suggestions: [String]?
}

struct ConversationSummary: Content {
    let id: UUID
    let title: String
    let lastMessage: String
    let messageCount: Int
    let model: String
    let createdAt: Date
    let updatedAt: Date
}

struct ConversationDetail: Content {
    let id: UUID
    let title: String
    let messages: [MessageDTO]
    let model: String
    let createdAt: Date
    let updatedAt: Date
}

struct MessageDTO: Content {
    let id: UUID
    let role: String
    let content: String
    let model: String?
    let tokensUsed: Int?
    let createdAt: Date
}

struct ShareResponse: Content {
    let shareUrl: String
    let expiresAt: Date
}

struct TheaInternalRequest: Content {
    let message: String
    let conversationId: UUID
    let preferredModel: String?
}

struct TheaInternalResponse: Content {
    let response: String
    let conversationId: UUID
    let model: String
    let tokensUsed: Int
    let suggestions: [String]?
}
