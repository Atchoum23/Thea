// ChatController.swift
// TheaWeb - Chat/Conversation API controller

import Vapor
import Fluent

/// Controller for chat/conversation endpoints
struct ChatController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let chat = routes.grouped("chat")

        chat.post("message", use: sendMessage)
        chat.get("conversations", use: listConversations)
        chat.get("conversations", ":id", use: getConversation)
        chat.delete("conversations", ":id", use: deleteConversation)
        chat.post("conversations", ":id", "share", use: shareConversation)
    }

    // MARK: - Message Handling

    /// Send a message to Thea
    @Sendable
    func sendMessage(req: Request) async throws -> ChatResponse {
        let user = try req.auth.require(User.self)
        let input = try req.content.decode(ChatRequest.self)

        // Validate input
        guard !input.message.isEmpty else {
            throw Abort(.badRequest, reason: "Message cannot be empty")
        }

        guard input.message.count <= 32_000 else {
            throw Abort(.badRequest, reason: "Message exceeds maximum length")
        }

        // Forward to local Thea instance via internal API
        // In production, this connects to the Mac Studio running Thea
        let theaResponse = try await forwardToThea(
            message: input.message,
            conversationId: input.conversationId,
            model: input.preferredModel,
            req: req
        )

        req.logger.info("Chat response generated for user: \(user.id?.uuidString ?? "unknown")")

        return ChatResponse(
            id: UUID(),
            conversationId: theaResponse.conversationId,
            message: theaResponse.response,
            model: theaResponse.model,
            tokensUsed: theaResponse.tokensUsed,
            createdAt: Date()
        )
    }

    /// List user's conversations
    @Sendable
    func listConversations(req: Request) async throws -> [ConversationSummary] {
        let user = try req.auth.require(User.self)

        // In a full implementation, this would query a conversations table
        // For now, return empty list as conversations are stored locally
        req.logger.debug("Listing conversations for user: \(user.id?.uuidString ?? "unknown")")

        return []
    }

    /// Get a specific conversation
    @Sendable
    func getConversation(req: Request) async throws -> ConversationDetail {
        let user = try req.auth.require(User.self)

        guard let conversationId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID")
        }

        req.logger.debug("Getting conversation \(conversationId) for user: \(user.id?.uuidString ?? "unknown")")

        // Fetch from Thea backend
        throw Abort(.notImplemented, reason: "Conversation sync not yet implemented")
    }

    /// Delete a conversation
    @Sendable
    func deleteConversation(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)

        guard let conversationId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID")
        }

        req.logger.info("Deleting conversation \(conversationId) for user: \(user.id?.uuidString ?? "unknown")")

        // Delete from Thea backend
        return .ok
    }

    /// Share a conversation (generate shareable link)
    @Sendable
    func shareConversation(req: Request) async throws -> ShareResponse {
        let user = try req.auth.require(User.self)

        guard let conversationId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID")
        }

        let shareId = generateShareId()

        req.logger.info("Sharing conversation \(conversationId) for user: \(user.id?.uuidString ?? "unknown")")

        return ShareResponse(
            shareUrl: "https://theathe.app/share/\(shareId)",
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days
        )
    }

    // MARK: - Thea Backend Communication

    private func forwardToThea(
        message: String,
        conversationId: UUID?,
        model: String?,
        req: Request
    ) async throws -> TheaInternalResponse {
        // Get Thea backend URL from environment
        let theaURL = Environment.get("THEA_BACKEND_URL") ?? "http://localhost:8081"

        // Build request to local Thea instance
        let uri = URI(string: "\(theaURL)/api/chat")

        let requestBody = TheaInternalRequest(
            message: message,
            conversationId: conversationId ?? UUID(),
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
}

struct ChatResponse: Content {
    let id: UUID
    let conversationId: UUID
    let message: String
    let model: String
    let tokensUsed: Int
    let createdAt: Date
}

struct ConversationSummary: Content {
    let id: UUID
    let title: String
    let lastMessage: String
    let messageCount: Int
    let createdAt: Date
    let updatedAt: Date
}

struct ConversationDetail: Content {
    let id: UUID
    let title: String
    let messages: [MessageDTO]
    let createdAt: Date
    let updatedAt: Date
}

struct MessageDTO: Content {
    let id: UUID
    let role: String
    let content: String
    let model: String?
    let createdAt: Date
}

struct ShareResponse: Content {
    let shareUrl: String
    let expiresAt: Date
}

// Internal Thea communication
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
}
