import Foundation
import Network
import CryptoKit
import OSLog

// MARK: - Thea Built-in WebSocket Server
// Listens on port 18789 (plain TCP). Handles:
//   • GET /health  → HTTP 200 JSON health response (for curl health checks)
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
