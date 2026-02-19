import Foundation
import OSLog

// MARK: - Matrix Connector
// Matrix homeserver via Client-Server API v3 (/sync long-polling).
// No external dependencies — pure URLSession.
// Credentials: serverUrl (e.g. "https://matrix.org") + apiKey (access token).
// Register/login via: curl -X POST "https://matrix.org/_matrix/client/v3/login"

actor MatrixConnector: MessagingPlatformConnector {
    let platform: MessagingPlatform = .matrix
    private(set) var isConnected = false
    var credentials: MessagingCredentials

    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private var syncTask: Task<Void, Never>?
    private var nextBatch: String?
    private let logger = Logger(subsystem: "ai.thea.app", category: "MatrixConnector")

    init(credentials: MessagingCredentials) {
        self.credentials = credentials
    }

    // MARK: - Connect

    func connect() async throws {
        guard let server = credentials.serverUrl, !server.isEmpty,
              let token = credentials.apiKey, !token.isEmpty
        else {
            throw MessagingError.missingCredentials(platform: .matrix, field: "serverUrl + apiKey (access token)")
        }

        // Verify credentials via whoami
        var req = URLRequest(url: URL(string: "\(server)/_matrix/client/v3/account/whoami")!)  // swiftlint:disable:this force_unwrapping
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw MessagingError.authenticationFailed(platform: .matrix)
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let userId = json["user_id"] as? String {
                logger.info("Matrix connected as \(userId)")
            }
        } catch let err as MessagingError {
            throw err
        } catch {
            throw MessagingError.authenticationFailed(platform: .matrix)
        }

        isConnected = true
        syncTask = Task { [server, token] in await syncLoop(server: server, token: token) }
    }

    // MARK: - Sync Loop (/sync long-polling)

    private func syncLoop(server: String, token: String) async {
        while !Task.isCancelled && isConnected {
            var urlStr = "\(server)/_matrix/client/v3/sync?timeout=30000&filter=%7B%22room%22:%7B%22timeline%22:%7B%22limit%22:10%7D%7D%7D"
            if let batch = nextBatch {
                urlStr += "&since=\(batch)"
            }

            guard let url = URL(string: urlStr) else {
                try? await Task.sleep(for: .seconds(5))
                continue
            }

            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.timeoutInterval = 35  // Longer than Matrix's 30s long-poll timeout

            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }

                nextBatch = json["next_batch"] as? String

                // Process room timeline events
                if let rooms = (json["rooms"] as? [String: Any])?["join"] as? [String: [String: Any]] {
                    for (roomId, room) in rooms {
                        await processRoomTimeline(room: room, roomId: roomId)
                    }
                }
            } catch {
                logger.error("Matrix sync error: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func processRoomTimeline(room: [String: Any], roomId: String) async {
        guard let timeline = room["timeline"] as? [String: Any],
              let events = timeline["events"] as? [[String: Any]]
        else { return }

        for event in events {
            guard (event["type"] as? String) == "m.room.message",
                  let content = event["content"] as? [String: Any],
                  (content["msgtype"] as? String) == "m.text",
                  let body = content["body"] as? String, !body.isEmpty,
                  let sender = event["sender"] as? String
            else { continue }

            // Skip our own messages (need to know our user_id — for now skip @thea* senders)
            guard !sender.lowercased().contains("thea") else { continue }

            await messageHandler?(TheaGatewayMessage(
                id: event["event_id"] as? String ?? UUID().uuidString,
                platform: .matrix,
                chatId: roomId,
                senderId: sender,
                senderName: sender,  // Could resolve display name via /profile API
                content: body,
                timestamp: {
                    if let ts = event["origin_server_ts"] as? Double {
                        return Date(timeIntervalSince1970: ts / 1000)
                    }
                    return Date()
                }(),
                isGroup: true  // All Matrix rooms are considered group contexts
            ))
        }
    }

    // MARK: - Send

    func send(_ message: OutboundMessagingMessage) async throws {
        guard let server = credentials.serverUrl, let token = credentials.apiKey else {
            throw MessagingError.notConnected(platform: .matrix)
        }

        let txnId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        // swiftlint:disable:next line_length
        guard let url = URL(string: "\(server)/_matrix/client/v3/rooms/\(message.chatId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? message.chatId)/send/m.room.message/\(txnId)") else {
            throw MessagingError.sendFailed(platform: .matrix, underlying: "Invalid room ID for URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "msgtype": "m.text",
            "body": message.content
        ])

        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode > 299 {
            throw MessagingError.sendFailed(platform: .matrix, underlying: "HTTP \(http.statusCode)")
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        syncTask?.cancel()
        syncTask = nil
        isConnected = false
        logger.info("Disconnected from Matrix")
    }

    func setMessageHandler(_ handler: @escaping @Sendable (TheaGatewayMessage) async -> Void) {
        messageHandler = handler
    }
}
