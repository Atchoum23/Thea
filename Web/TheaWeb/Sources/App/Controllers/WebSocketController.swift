// WebSocketController.swift
// TheaWeb - Real-time WebSocket handler for streaming chat responses

import Vapor
import Fluent

/// Manages WebSocket connections for real-time chat streaming
actor WebSocketManager {
    static let shared = WebSocketManager()

    private var connections: [UUID: WebSocket] = [:]

    func add(userId: UUID, socket: WebSocket) {
        connections[userId] = socket
    }

    func remove(userId: UUID) {
        connections.removeValue(forKey: userId)
    }

    func send(to userId: UUID, message: WebSocketMessage) async {
        guard let socket = connections[userId] else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try await socket.send(raw: data, opcode: .text)
        } catch {
            connections.removeValue(forKey: userId)
        }
    }

    func broadcast(_ message: WebSocketMessage) async {
        let data: Data
        do {
            data = try JSONEncoder().encode(message)
        } catch {
            return
        }
        for (userId, socket) in connections {
            do {
                try await socket.send(raw: data, opcode: .text)
            } catch {
                connections.removeValue(forKey: userId)
            }
        }
    }

    var connectionCount: Int {
        connections.count
    }
}

/// WebSocket message types
struct WebSocketMessage: Codable, Sendable {
    let type: String
    let conversationId: UUID?
    let content: String?
    let title: String?
    let model: String?
    let suggestions: [String]?
    let data: [String: String]?

    static func streamStart(conversationId: UUID) -> WebSocketMessage {
        WebSocketMessage(
            type: "stream_start",
            conversationId: conversationId,
            content: nil, title: nil, model: nil, suggestions: nil, data: nil
        )
    }

    static func streamChunk(content: String) -> WebSocketMessage {
        WebSocketMessage(
            type: "stream_chunk",
            conversationId: nil,
            content: content, title: nil, model: nil, suggestions: nil, data: nil
        )
    }

    static func streamEnd(model: String, suggestions: [String]?) -> WebSocketMessage {
        WebSocketMessage(
            type: "stream_end",
            conversationId: nil,
            content: nil, title: nil, model: model, suggestions: suggestions, data: nil
        )
    }

    static func notification(title: String, content: String) -> WebSocketMessage {
        WebSocketMessage(
            type: "notification",
            conversationId: nil,
            content: content, title: title, model: nil, suggestions: nil, data: nil
        )
    }

    static func conversationUpdated() -> WebSocketMessage {
        WebSocketMessage(
            type: "conversation_updated",
            conversationId: nil,
            content: nil, title: nil, model: nil, suggestions: nil, data: nil
        )
    }

    static func dashboardUpdate(data: [String: String]) -> WebSocketMessage {
        WebSocketMessage(
            type: "dashboard_update",
            conversationId: nil,
            content: nil, title: nil, model: nil, suggestions: nil, data: data
        )
    }
}

/// Registers WebSocket upgrade route
struct WebSocketController {
    static func register(on app: Application) {
        app.webSocket("api", "v1", "ws") { req, socket async in
            // Authenticate via query parameter token
            guard let token = req.query[String.self, at: "token"] else {
                try? await socket.close(code: .policyViolation)
                return
            }

            // Validate token
            guard let session = try? await authenticateToken(token, on: req.db) else {
                try? await socket.close(code: .policyViolation)
                return
            }

            let userId = session.$user.id
            await WebSocketManager.shared.add(userId: userId, socket: socket)
            req.logger.info("WebSocket connected for user: \(userId)")

            // Handle incoming messages
            socket.onText { _, text async in
                do {
                    let msg = try JSONDecoder().decode(WSClientMessage.self, from: Data(text.utf8))
                    await handleClientMessage(msg, userId: userId, req: req)
                } catch {
                    req.logger.warning("Invalid WS message: \(error)")
                }
            }

            socket.onClose.whenComplete { _ in
                Task {
                    await WebSocketManager.shared.remove(userId: userId)
                    req.logger.info("WebSocket disconnected for user: \(userId)")
                }
            }
        }
    }

    private static func authenticateToken(_ token: String, on database: Database) async throws -> Session? {
        let tokenHash = SHA256Helper.hash(token)
        return try await Session.query(on: database)
            .filter(\.$tokenHash == tokenHash)
            .filter(\.$isValid == true)
            .with(\.$user)
            .first()
    }

    private static func handleClientMessage(_ msg: WSClientMessage, userId: UUID, req: Request) async {
        switch msg.type {
        case "ping":
            await WebSocketManager.shared.send(
                to: userId,
                message: WebSocketMessage(
                    type: "pong",
                    conversationId: nil,
                    content: nil, title: nil, model: nil, suggestions: nil, data: nil
                )
            )
        case "subscribe_dashboard":
            // Client wants dashboard updates
            req.logger.debug("User \(userId) subscribed to dashboard updates")
        default:
            break
        }
    }
}

/// Client-to-server WebSocket message
struct WSClientMessage: Codable, Sendable {
    let type: String
    let data: [String: String]?
}

// SHA256 helper using Vapor's built-in crypto
import Crypto

enum SHA256Helper {
    static func hash(_ input: String) -> String {
        let digest = Crypto.SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
