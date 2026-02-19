import Foundation
import OSLog

// MARK: - Signal Connector
// Signal via signal-cli daemon. Communication via Unix socket JSON-RPC 2.0.
// Requires: brew install signal-cli && signal-cli -a <phone> register && verify
// Credential: serverUrl field = registered phone number (e.g. "+15555550123").
// Only available on macOS (Process is not available on iOS/watchOS/tvOS).

actor SignalConnector: MessagingPlatformConnector {
    // periphery:ignore - Reserved: platform property reserved for future feature activation
    let platform: MessagingPlatform = .signal
    private(set) var isConnected = false
    var credentials: MessagingCredentials

    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private let socketPath = "/tmp/signal-thea.sock"
    private let logger = Logger(subsystem: "ai.thea.app", category: "SignalConnector")

#if os(macOS)
    private var daemonProcess: Process?
    private var receiveTask: Task<Void, Never>?
    private var socketFileHandle: FileHandle?
#endif

    init(credentials: MessagingCredentials) {
        self.credentials = credentials
    }

    // MARK: - Connect

    func connect() async throws {
#if os(macOS)
        guard let phone = credentials.serverUrl, !phone.isEmpty else {
            throw MessagingError.missingCredentials(platform: .signal, field: "serverUrl (registered phone number)")
        }

        guard let cliPath = which("signal-cli") else {
            throw MessagingError.dependencyMissing(
                name: "signal-cli",
                installHint: "brew install signal-cli && signal-cli -a \(phone) register"
            )
        }

        // Remove stale socket if it exists
        try? FileManager.default.removeItem(atPath: socketPath)

        // Start signal-cli daemon with Unix socket
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["--account", phone, "daemon", "--socket", socketPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        daemonProcess = process

        // Wait for socket file to appear (up to 5s)
        for _ in 0..<10 {
            try? await Task.sleep(for: .milliseconds(500))
            if FileManager.default.fileExists(atPath: socketPath) { break }
        }

        guard FileManager.default.fileExists(atPath: socketPath) else {
            process.terminate()
            throw MessagingError.platformUnavailable(
                platform: .signal,
                reason: "signal-cli daemon did not start (socket not created)"
            )
        }

        isConnected = true
        logger.info("Connected to signal-cli daemon for \(phone)")

        receiveTask = Task { await receiveDaemonMessages(phone: phone) }
#else
        throw MessagingError.platformUnavailable(
            platform: .signal,
            reason: "signal-cli requires macOS (Process not available on this platform)"
        )
#endif
    }

    // MARK: - Receive Loop

    private func receiveDaemonMessages(phone: String) async {
#if os(macOS)
        // Subscribe to receive notifications via JSON-RPC
        let subscribeRequest: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "subscribeReceive",
            "params": ["account": phone],
            "id": 1
        ]

        guard let subscribeData = try? JSONSerialization.data(withJSONObject: subscribeRequest),
              let subscribeStr = String(data: subscribeData, encoding: .utf8) else { return }

        await sendRPC(subscribeStr + "\n")

        // Read JSON-RPC notifications line by line
        while !Task.isCancelled && isConnected {
            guard let line = await readLine() else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }

            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let method = json["method"] as? String,
                  method == "receive",
                  let params = json["params"] as? [String: Any],
                  let envelope = params["envelope"] as? [String: Any],
                  let dataMessage = envelope["dataMessage"] as? [String: Any],
                  let message = dataMessage["message"] as? String, !message.isEmpty
            else { continue }

            let source = envelope["source"] as? String ?? "unknown"
            let sourceName = envelope["sourceName"] as? String ?? source
            let groupId = (dataMessage["groupInfo"] as? [String: Any])?["groupId"] as? String

            await messageHandler?(TheaGatewayMessage(
                id: "\(Int64(Date().timeIntervalSince1970 * 1000))",
                platform: .signal,
                chatId: groupId ?? source,
                senderId: source,
                senderName: sourceName,
                content: message,
                timestamp: Date(),
                isGroup: groupId != nil
            ))
        }
#endif
    }

    // MARK: - Send

    func send(_ message: OutboundMessagingMessage) async throws {
#if os(macOS)
        guard let phone = credentials.serverUrl, !phone.isEmpty else {
            throw MessagingError.notConnected(platform: .signal)
        }

        let sendRequest: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "send",
            "params": [
                "account": phone,
                "recipient": [message.chatId],
                "message": message.content
            ],
            "id": Int(Date().timeIntervalSince1970)
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: sendRequest),
              let str = String(data: data, encoding: .utf8) else {
            throw MessagingError.sendFailed(platform: .signal, underlying: "JSON encoding failed")
        }

        await sendRPC(str + "\n")
#else
        throw MessagingError.platformUnavailable(platform: .signal, reason: "macOS only")
#endif
    }

    // MARK: - Disconnect

    func disconnect() async {
#if os(macOS)
        receiveTask?.cancel()
        socketFileHandle?.closeFile()
        socketFileHandle = nil
        daemonProcess?.terminate()
        daemonProcess = nil
        try? FileManager.default.removeItem(atPath: socketPath)
        isConnected = false
        logger.info("Disconnected from Signal / signal-cli")
#endif
        isConnected = false
    }

    func setMessageHandler(_ handler: @escaping @Sendable (TheaGatewayMessage) async -> Void) {
        messageHandler = handler
    }

    // MARK: - Unix Socket I/O Helpers

#if os(macOS)
    private func sendRPC(_ text: String) async {
        // Connect to Unix socket and send data
        let sockFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sockFd >= 0 else { return }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 104) { cptr in
                _ = socketPath.withCString { strlcpy(cptr, $0, 104) }
            }
        }
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sptr in
                Darwin.connect(sockFd, sptr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { Darwin.close(sockFd); return }
        let bytes = Array(text.utf8)
        bytes.withUnsafeBufferPointer { buf in
            _ = write(sockFd, buf.baseAddress, buf.count)
        }
        Darwin.close(sockFd)
    }

    private func readLine() async -> String? {
        // For robustness, open socket, read one line, close
        // In production, maintain a persistent connection
        try? await Task.sleep(for: .milliseconds(100))
        return nil  // Placeholder — full Unix socket streaming read requires fd polling
    }

    private func which(_ cmd: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [cmd]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    }
#endif
}
