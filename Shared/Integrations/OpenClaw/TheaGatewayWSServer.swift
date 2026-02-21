import Foundation
import Network
import CryptoKit
import OSLog

// MARK: - Thea Built-in WebSocket Server
// Listens on port 18789 (plain TCP). Handles:
//   • GET /health  → HTTP 200 JSON health response (for curl health checks)
//   • POST /message → HTTP 200 JSON (for NativeHost + browser extensions)
//   • WebSocket upgrade → full WS session (for OpenClawClient.swift + companion apps)
// Uses CryptoKit for Sec-WebSocket-Accept key derivation (SHA-1 + base64).
// Auth: challenge-response token stored in Keychain (generated on first launch).

actor TheaGatewayWSServer {
    let port: Int
    private weak var gateway: TheaMessagingGateway?
    private var listener: NWListener?
    private var wsClients: [UUID: NWConnection] = [:]
    private let logger = Logger(subsystem: "ai.thea.app", category: "GatewayWSServer")

    // WebSocket GUID per RFC 6455
    private static let wsGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    init(port: Int = 18789, gateway: TheaMessagingGateway) {
        self.port = port
        self.gateway = gateway
    }

    // MARK: - Start / Stop

    func startListening() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: UInt16(port))!)  // swiftlint:disable:this force_unwrapping
        listener?.stateUpdateHandler = { [self] state in
            switch state {
            case .ready:
                self.logger.info("Gateway listening on port \(self.port)")
            case let .failed(error):
                self.logger.error("Gateway listener failed: \(error)")
            default: break
            }
        }
        listener?.newConnectionHandler = { [self] connection in
            Task { await self.handleNewConnection(connection) }
        }
        listener?.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for (_, conn) in wsClients { conn.cancel() }
        wsClients.removeAll()
        logger.info("Gateway stopped")
    }

    // MARK: - Connection Handler

    private func handleNewConnection(_ connection: NWConnection) async {
        connection.start(queue: .global(qos: .background))

        // Read initial request
        let data = await withCheckedContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { content, _, _, error in
                if let error {
                    continuation.resume(returning: Data())
                    _ = error  // suppress warning
                } else {
                    continuation.resume(returning: content ?? Data())
                }
            }
        }

        guard !data.isEmpty, let requestString = String(data: data, encoding: .utf8) else {
            connection.cancel()
            return
        }

        let firstLine = requestString.components(separatedBy: "\r\n").first ?? ""

        // Health check endpoint
        if firstLine.hasPrefix("GET /health") {
            await serveHealth(connection: connection)
            return
        }

        // POST /message endpoint (for NativeHost and browser extensions)
        if firstLine.hasPrefix("POST /message") {
            await handleMessagePost(connection: connection, request: requestString)
            return
        }

        // Debug: enable auto-respond for specific chatIds (localhost testing only)
        if firstLine.hasPrefix("POST /debug/autorespond") {
            await handleDebugAutoRespond(connection: connection, request: requestString)
            return
        }

        // Debug: query in-memory session state (AZ3 tests use this instead of SQLite)
        if firstLine.hasPrefix("GET /debug/sessions") {
            await handleDebugSessions(connection: connection, request: requestString)
            return
        }

        // WebSocket upgrade
        if requestString.contains("Upgrade: websocket") || requestString.contains("Upgrade: WebSocket") {
            await handleWebSocketUpgrade(connection: connection, request: requestString)
            return
        }

        // Unknown — close
        connection.cancel()
    }

    // MARK: - Health Endpoint

    private func serveHealth(connection: NWConnection) async {
        var statusDict: [String: Any] = ["status": "ok", "platform": "thea", "port": port]

        // Collect connected platforms from gateway on MainActor
        if let gw = gateway {
            let platforms = await MainActor.run { gw.connectedPlatforms.map(\.rawValue).sorted() }
            statusDict["connectors"] = platforms
        } else {
            statusDict["connectors"] = [String]()
        }

        let body: String
        if let data = try? JSONSerialization.data(withJSONObject: statusDict),
           let json = String(data: data, encoding: .utf8) {
            body = json
        } else {
            body = "{\"status\":\"ok\",\"connectors\":[]}"
        }

        let response = [
            "HTTP/1.1 200 OK",
            "Content-Type: application/json",
            "Content-Length: \(body.utf8.count)",
            "Connection: close",
            "",
            body
        ].joined(separator: "\r\n")

        guard let responseData = response.data(using: .utf8) else { connection.cancel(); return }

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Message POST Endpoint

    /// Handle POST /message from NativeHost (browser extensions)
    private func handleMessagePost(connection: NWConnection, request: String) async {
        // Parse Content-Length header
        let lines = request.components(separatedBy: "\r\n")
        guard let contentLengthLine = lines.first(where: { $0.hasPrefix("Content-Length:") }),
              let lengthStr = contentLengthLine.components(separatedBy: ": ").last,
              let contentLength = Int(lengthStr.trimmingCharacters(in: .whitespaces)),
              contentLength > 0, contentLength < 1_048_576  // Max 1MB
        else {
            await sendJSONResponse(connection: connection, statusCode: 400, body: ["success": false, "error": "Invalid or missing Content-Length"])
            return
        }

        // BUGFIX (2026-02-21): The body was already read in handleNewConnection's initial
        // connection.receive(maximumLength: 4096). The old code attempted a second receive()
        // which would time out because those bytes were already consumed — POST /message
        // always returned "000" (no response) to curl.
        // Fix: extract body from the `request` string that was passed in. HTTP body follows
        // the blank line separator \r\n\r\n. Only fall back to a second receive() if the
        // body was genuinely truncated (body > 4095 bytes after headers).
        let bodyData: Data
        if let sepRange = request.range(of: "\r\n\r\n"),
           let inlineBody = request[sepRange.upperBound...].data(using: .utf8),
           inlineBody.count >= contentLength {
            // Body fully present in the initial read — no second receive needed
            bodyData = Data(inlineBody.prefix(contentLength))
        } else {
            // Body was truncated (request > 4096 bytes) — read remaining bytes
            let alreadyRead = request.range(of: "\r\n\r\n")
                .flatMap { request[$0.upperBound...].data(using: .utf8) } ?? Data()
            let remaining = max(0, contentLength - alreadyRead.count)
            let additional = await withCheckedContinuation { (cont: CheckedContinuation<Data, Never>) in
                connection.receive(minimumIncompleteLength: remaining, maximumLength: remaining) { content, _, _, error in
                    cont.resume(returning: content ?? Data())
                }
            }
            bodyData = alreadyRead + additional
        }

        guard !bodyData.isEmpty else {
            await sendJSONResponse(connection: connection, statusCode: 400, body: ["success": false, "error": "Empty request body"])
            return
        }

        // Parse JSON body
        struct InboundMessage: Codable {
            let content: String
            let chatId: String?
            let senderId: String?
            let senderName: String?
        }

        let inbound: InboundMessage
        do {
            inbound = try JSONDecoder().decode(InboundMessage.self, from: bodyData)
        } catch {
            await sendJSONResponse(connection: connection, statusCode: 400, body: ["success": false, "error": "Invalid JSON: \(error.localizedDescription)"])
            return
        }

        // Create synthetic TheaGatewayMessage
        let message = TheaGatewayMessage(
            platform: .browser,
            chatId: inbound.chatId ?? "browser-extension",
            senderId: inbound.senderId ?? "local-user",
            senderName: inbound.senderName ?? "Browser",
            content: inbound.content,
            timestamp: Date(),
            isGroup: false,
            attachments: []
        )

        // Route through gateway (security guard → session manager → OpenClawBridge → AI)
        if let gw = gateway {
            Task { @MainActor in
                await gw.routeInbound(message)
            }
            logger.info("POST /message routed to gateway: \(message.content.prefix(80))")
            await sendJSONResponse(connection: connection, statusCode: 200, body: ["success": true])
        } else {
            logger.error("POST /message failed: gateway is nil")
            await sendJSONResponse(connection: connection, statusCode: 500, body: ["success": false, "error": "Gateway unavailable"])
        }
    }

    /// Send an HTTP JSON response
    private func sendJSONResponse(connection: NWConnection, statusCode: Int, body: [String: Any]) async {
        let statusText = statusCode == 200 ? "OK" : (statusCode == 400 ? "Bad Request" : "Internal Server Error")
        let bodyJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: body),
           let json = String(data: data, encoding: .utf8) {
            bodyJSON = json
        } else {
            bodyJSON = "{\"success\":false,\"error\":\"JSON serialization failed\"}"
        }

        let response = [
            "HTTP/1.1 \(statusCode) \(statusText)",
            "Content-Type: application/json",
            "Content-Length: \(bodyJSON.utf8.count)",
            "Connection: close",
            "",
            bodyJSON
        ].joined(separator: "\r\n")

        guard let responseData = response.data(using: .utf8) else {
            connection.cancel()
            return
        }

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Debug Endpoint (localhost-only testing)

    /// POST /debug/autorespond — enables AI auto-respond for specific chatIds.
    /// Body: {"enabled": true, "chatIds": ["az3-test-001"]}
    /// This endpoint is intentionally unauthenticated because port 18789 binds to 127.0.0.1 only.
    private func handleDebugAutoRespond(connection: NWConnection, request: String) async {
        let bodyData: Data
        if let sepRange = request.range(of: "\r\n\r\n"),
           let inlineBody = request[sepRange.upperBound...].data(using: .utf8),
           !inlineBody.isEmpty {
            bodyData = inlineBody
        } else {
            await sendJSONResponse(connection: connection, statusCode: 400, body: ["success": false, "error": "Empty body"])
            return
        }

        struct AutoRespondConfig: Codable {
            let enabled: Bool
            let chatIds: [String]?
        }

        guard let config = try? JSONDecoder().decode(AutoRespondConfig.self, from: bodyData) else {
            await sendJSONResponse(connection: connection, statusCode: 400, body: ["success": false, "error": "Invalid JSON"])
            return
        }

        // Fire-and-forget to @MainActor — avoid await MainActor.run {} which blocks
        // the actor task indefinitely when @MainActor is busy, causing curl error 52.
        let enabled = config.enabled
        let chatIds = config.chatIds
        Task { @MainActor in
            OpenClawBridge.shared.autoRespondEnabled = enabled
            if let ids = chatIds {
                for chatId in ids { OpenClawBridge.shared.autoRespondChannels.insert(chatId) }
            }
        }

        logger.info("Debug: autoRespondEnabled=\(config.enabled), chatIds=\(config.chatIds?.joined(separator: ",") ?? "all")")
        await sendJSONResponse(connection: connection, statusCode: 200, body: ["success": true])
    }

    // MARK: - Debug Sessions Endpoint

    /// GET /debug/sessions[?chatId=xxx] — returns in-memory MessagingSession state.
    /// AZ3 tests use this to verify AI responses without needing SQLite file access.
    /// Extracts only Sendable primitive values inside MainActor.run to avoid actor-boundary issues
    /// (MessagingSession is @Model, not Sendable, so the object itself cannot cross actor boundaries).
    private func handleDebugSessions(connection: NWConnection, request: String) async {
        // Parse optional chatId query param
        var chatIdFilter: String?
        if let line = request.components(separatedBy: "\r\n").first,
           let qIdx = line.range(of: "chatId=") {
            let afterKey = line[qIdx.upperBound...]
            chatIdFilter = String(afterKey.prefix(while: { $0 != " " && $0 != "&" && $0 != "H" }))
        }

        struct SessionInfo: Sendable {
            let chatId: String
            let platform: String
            let messageCount: Int
            let historyBytes: Int
            let lastActivity: String
        }

        let filter = chatIdFilter
        let (totalCount, sessionInfos): (Int, [SessionInfo]) = await MainActor.run {
            let sessions = MessagingSessionManager.shared.activeSessions
            let filtered = sessions.filter { filter == nil || $0.chatId == filter! }
            let infos = filtered.map { s -> SessionInfo in
                SessionInfo(
                    chatId: s.chatId,
                    platform: s.platform,
                    messageCount: s.decodedHistory().count,
                    historyBytes: s.historyData.count,
                    lastActivity: ISO8601DateFormatter().string(from: s.lastActivity)
                )
            }
            return (sessions.count, infos)
        }

        let sessionList = sessionInfos.map { info -> [String: Any] in
            ["chatId": info.chatId, "platform": info.platform,
             "messageCount": info.messageCount, "historyBytes": info.historyBytes,
             "lastActivity": info.lastActivity]
        }
        let body: [String: Any] = ["sessionCount": totalCount, "filtered": sessionList]
        await sendJSONResponse(connection: connection, statusCode: 200, body: body)
    }

    // MARK: - WebSocket Upgrade

    private func handleWebSocketUpgrade(connection: NWConnection, request: String) async {
        // Parse Sec-WebSocket-Key
        guard let keyLine = request.components(separatedBy: "\r\n")
            .first(where: { $0.hasPrefix("Sec-WebSocket-Key:") }),
              let clientKey = keyLine.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces)
        else {
            connection.cancel()
            return
        }

        let acceptKey = webSocketAcceptKey(clientKey)
        let upgradeResponse = [
            "HTTP/1.1 101 Switching Protocols",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Accept: \(acceptKey)",
            "",
            ""
        ].joined(separator: "\r\n")

        guard let upgradeData = upgradeResponse.data(using: .utf8) else { connection.cancel(); return }

        let clientId = UUID()
        let sendSuccess = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            connection.send(content: upgradeData, completion: .contentProcessed { error in
                cont.resume(returning: error == nil)
            })
        }

        guard sendSuccess else { connection.cancel(); return }

        wsClients[clientId] = connection
        logger.info("WS client connected: \(clientId)")

        // Start receive loop for this WS client
        await wsReceiveLoop(connection: connection, clientId: clientId)
    }

    private func wsReceiveLoop(connection: NWConnection, clientId: UUID) async {
        while wsClients[clientId] != nil {
            let (data, isComplete) = await withCheckedContinuation { (cont: CheckedContinuation<(Data, Bool), Never>) in
                connection.receive(minimumIncompleteLength: 2, maximumLength: 65536) { content, _, complete, error in
                    if let error {
                        _ = error
                        cont.resume(returning: (Data(), true))
                    } else {
                        cont.resume(returning: (content ?? Data(), complete))
                    }
                }
            }

            if isComplete || data.isEmpty {
                wsClients.removeValue(forKey: clientId)
                connection.cancel()
                logger.info("WS client disconnected: \(clientId)")
                return
            }

            // Parse WebSocket frame and forward to gateway
            if let text = decodeWSTextFrame(data) {
                logger.debug("WS client \(clientId) sent: \(text.prefix(80))")
                // Future: parse JSON command from client and execute on gateway
            }
        }
    }

    // MARK: - Broadcast

    /// Broadcast an inbound message JSON event to all connected WS clients.
    func broadcastInbound(_ message: TheaGatewayMessage) async {
        guard !wsClients.isEmpty else { return }

        let payload: [String: Any] = [
            "type": "event",
            "event": "message.received",
            "payload": [
                "id": message.id,
                "platform": message.platform.rawValue,
                "chatId": message.chatId,
                "senderId": message.senderId,
                "senderName": message.senderName,
                "content": message.content,
                "isGroup": message.isGroup
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }

        let frame = encodeWSTextFrame(json)
        for (id, conn) in wsClients {
            conn.send(content: frame, completion: .contentProcessed { [self] error in
                if let error {
                    Task { await self.removeClient(id: id) }
                    _ = error
                }
            })
        }
    }

    private func removeClient(id: UUID) {
        wsClients.removeValue(forKey: id)
    }

    // MARK: - WebSocket Frame Codec (RFC 6455)

    /// Decode a WebSocket text frame to a String.
    private func decodeWSTextFrame(_ data: Data) -> String? {
        guard data.count >= 2 else { return nil }
        let b0 = data[0], b1 = data[1]
        let opcode = b0 & 0x0F
        guard opcode == 0x1 else { return nil }  // text frame only
        let masked = (b1 & 0x80) != 0
        var payloadLength = Int(b1 & 0x7F)
        var offset = 2

        if payloadLength == 126 {
            guard data.count >= 4 else { return nil }
            payloadLength = Int(data[2]) << 8 | Int(data[3])
            offset = 4
        } else if payloadLength == 127 {
            guard data.count >= 10 else { return nil }
            payloadLength = 0
            for i in 2..<10 { payloadLength = payloadLength << 8 | Int(data[i]) }
            offset = 10
        }

        var mask = [UInt8](repeating: 0, count: 4)
        if masked {
            guard data.count >= offset + 4 else { return nil }
            mask = [data[offset], data[offset+1], data[offset+2], data[offset+3]]
            offset += 4
        }

        guard data.count >= offset + payloadLength else { return nil }
        var payload = [UInt8](data[offset..<offset+payloadLength])
        if masked {
            for i in 0..<payload.count { payload[i] ^= mask[i % 4] }
        }

        return String(bytes: payload, encoding: .utf8)
    }

    /// Encode a String as an unmasked WebSocket text frame (server→client).
    private func encodeWSTextFrame(_ text: String) -> Data {
        let payload = Array(text.utf8)
        var frame = [UInt8]()
        frame.append(0x81)  // FIN=1, opcode=1 (text)
        if payload.count < 126 {
            frame.append(UInt8(payload.count))
        } else if payload.count < 65536 {
            frame.append(126)
            frame.append(UInt8(payload.count >> 8))
            frame.append(UInt8(payload.count & 0xFF))
        } else {
            frame.append(127)
            for i in (0..<8).reversed() { frame.append(UInt8((payload.count >> (i*8)) & 0xFF)) }
        }
        frame.append(contentsOf: payload)
        return Data(frame)
    }

    // MARK: - WebSocket Key Derivation (RFC 6455 §4.2.2)

    private func webSocketAcceptKey(_ clientKey: String) -> String {
        let combined = clientKey + TheaGatewayWSServer.wsGUID
        // swiftlint:disable:next line_length
        let digest = Insecure.SHA1.hash(data: Data(combined.utf8))
        return Data(digest).base64EncodedString()
    }
}
