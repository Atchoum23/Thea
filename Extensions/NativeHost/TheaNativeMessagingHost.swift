// TheaNativeMessagingHost.swift
// Thea - AI-Powered Browser Extensions
//
// Native Messaging Host for Chrome/Brave browser communication
// Provides Safari-like iCloud integration (Passwords + Hide My Email)
//
// Installation:
// 1. Build this as a standalone macOS app/tool
// 2. Register native messaging manifest for Chrome/Brave
// 3. The extension communicates via stdin/stdout

import AuthenticationServices
import Foundation
import LocalAuthentication

// MARK: - Native Messaging Host

/// Native messaging host for Chrome/Brave to access iCloud services
/// Implements Chrome's Native Messaging protocol (JSON over stdio)
@MainActor
final class TheaNativeMessagingHost {
    // MARK: - Properties

    private let passwordsBridge = iCloudPasswordsBridge.shared
    private let hideMyEmailBridge = iCloudHideMyEmailBridge.shared

    private var isRunning = false
    private let inputHandle = FileHandle.standardInput
    private let outputHandle = FileHandle.standardOutput

    // MARK: - Message Types

    enum MessageType: String, Codable {
        // Connection
        case connect
        case disconnect
        case getStatus

        // Passwords
        case getCredentials
        case saveCredential
        case generatePassword
        case deleteCredential

        // Hide My Email (creates @icloud.com aliases, NOT @privaterelay.appleid.com)
        case createAlias
        case getAliases
        case deactivateAlias
        case reactivateAlias
        case deleteAlias
        case getAliasForDomain

        // Autofill
        case autofillCredential
        case autofillAlias

        // AI Chat (routes to Thea's TheaMessagingGateway port 18789)
        case chat
    }

    struct IncomingMessage: Codable {
        let type: MessageType
        let requestId: String
        let data: [String: AnyCodable]?
    }

    struct OutgoingMessage: Codable {
        let type: String
        let requestId: String
        let success: Bool
        let data: [String: AnyCodable]?
        let error: String?
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Main Loop

    func run() async {
        isRunning = true
        log("Thea Native Messaging Host started")

        while isRunning {
            do {
                if let message = try readMessage() {
                    let response = await handleMessage(message)
                    try writeMessage(response)
                }
            } catch {
                log("Error: \(error)")
                // Continue running despite errors
            }
        }
    }

    func stop() {
        isRunning = false
    }

    // MARK: - Message I/O (Chrome Native Messaging Protocol)

    /// Read a message from stdin (Chrome Native Messaging format)
    /// Format: 4-byte length prefix (little-endian) + JSON message
    private func readMessage() throws -> IncomingMessage? {
        // Read 4-byte length prefix
        let lengthData = inputHandle.readData(ofLength: 4)
        guard lengthData.count == 4 else {
            return nil // EOF or incomplete read
        }

        let length = lengthData.withUnsafeBytes { buffer in
            buffer.load(as: UInt32.self)
        }

        guard length > 0, length < 1_048_576 else { // Max 1MB
            throw NativeHostError.invalidMessageLength
        }

        // Read message body
        let messageData = inputHandle.readData(ofLength: Int(length))
        guard messageData.count == Int(length) else {
            throw NativeHostError.incompleteMessage
        }

        let decoder = JSONDecoder()
        return try decoder.decode(IncomingMessage.self, from: messageData)
    }

    /// Write a message to stdout (Chrome Native Messaging format)
    private func writeMessage(_ message: OutgoingMessage) throws {
        let encoder = JSONEncoder()
        let messageData = try encoder.encode(message)

        // Write 4-byte length prefix (little-endian)
        var length = UInt32(messageData.count)
        let lengthData = withUnsafeBytes(of: &length) { Data($0) }

        outputHandle.write(lengthData)
        outputHandle.write(messageData)
    }

    // MARK: - Message Handling

    private func handleMessage(_ message: IncomingMessage) async -> OutgoingMessage {
        log("Handling message: \(message.type)")

        do {
            switch message.type {
            // Connection
            case .connect:
                return try await handleConnect(message)
            case .disconnect:
                return try await handleDisconnect(message)
            case .getStatus:
                return try await handleGetStatus(message)
            // Passwords
            case .getCredentials:
                return try await handleGetCredentials(message)
            case .saveCredential:
                return try await handleSaveCredential(message)
            case .generatePassword:
                return try await handleGeneratePassword(message)
            case .deleteCredential:
                return try await handleDeleteCredential(message)
            // Hide My Email
            case .createAlias:
                return try await handleCreateAlias(message)
            case .getAliases:
                return try await handleGetAliases(message)
            case .deactivateAlias:
                return try await handleDeactivateAlias(message)
            case .reactivateAlias:
                return try await handleReactivateAlias(message)
            case .deleteAlias:
                return try await handleDeleteAlias(message)
            case .getAliasForDomain:
                return try await handleGetAliasForDomain(message)
            // Autofill helpers
            case .autofillCredential:
                return try await handleAutofillCredential(message)
            case .autofillAlias:
                return try await handleAutofillAlias(message)
            // AI Chat
            case .chat:
                return try await handleChat(message)
            }
        } catch {
            return OutgoingMessage(
                type: message.type.rawValue,
                requestId: message.requestId,
                success: false,
                data: nil,
                error: error.localizedDescription
            )
        }
    }

    // MARK: - Connection Handlers

    private func handleConnect(_ message: IncomingMessage) async throws -> OutgoingMessage {
        // Connect to both services
        try await passwordsBridge.connect()
        try await hideMyEmailBridge.connect()

        return OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: [
                "passwordsConnected": AnyCodable(passwordsBridge.isConnected),
                "hideMyEmailConnected": AnyCodable(hideMyEmailBridge.isConnected),
                "requiresReauth": AnyCodable(false)
            ],
            error: nil
        )
    }

    private func handleDisconnect(_ message: IncomingMessage) async throws -> OutgoingMessage {
        passwordsBridge.disconnect()
        hideMyEmailBridge.disconnect()

        return OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: nil,
            error: nil
        )
    }

    private func handleGetStatus(_ message: IncomingMessage) async throws -> OutgoingMessage {
        OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: [
                "passwordsConnected": AnyCodable(passwordsBridge.isConnected),
                "passwordsAuthenticated": AnyCodable(passwordsBridge.isAuthenticated),
                "hideMyEmailConnected": AnyCodable(hideMyEmailBridge.isConnected),
                "hideMyEmailAuthenticated": AnyCodable(hideMyEmailBridge.isAuthenticated),
                "lastPasswordsSync": AnyCodable(passwordsBridge.lastSyncTime?.ISO8601Format()),
                "lastHideMyEmailSync": AnyCodable(hideMyEmailBridge.lastSyncTime?.ISO8601Format())
            ],
            error: nil
        )
    }

    // MARK: - Password Handlers

    private func handleGetCredentials(_ message: IncomingMessage) async throws -> OutgoingMessage {
        guard let domain = message.data?["domain"]?.value as? String else {
            throw NativeHostError.missingParameter("domain")
        }

        let credentials = try await passwordsBridge.getCredentials(for: domain)

        let credentialDicts: [[String: AnyCodable]] = credentials.map { cred in
            [
                "id": AnyCodable(cred.id),
                "username": AnyCodable(cred.username),
                "password": AnyCodable(cred.password),
                "domain": AnyCodable(cred.domain),
                "createdAt": AnyCodable(cred.createdAt.ISO8601Format()),
                "modifiedAt": AnyCodable(cred.modifiedAt.ISO8601Format())
            ]
        }

        return OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: ["credentials": AnyCodable(credentialDicts)],
            error: nil
        )
    }

    private func handleSaveCredential(_ message: IncomingMessage) async throws -> OutgoingMessage {
        guard let username = message.data?["username"]?.value as? String,
              let password = message.data?["password"]?.value as? String,
              let domain = message.data?["domain"]?.value as? String
        else {
            throw NativeHostError.missingParameter("username, password, or domain")
        }

        let notes = message.data?["notes"]?.value as? String

        try await passwordsBridge.saveCredential(
            username: username,
            password: password,
            domain: domain,
            notes: notes
        )

        return OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: ["saved": AnyCodable(true)],
            error: nil
        )
    }

    private func handleGeneratePassword(_ message: IncomingMessage) async throws -> OutgoingMessage {
        let password = passwordsBridge.generateStrongPassword()

        return OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: ["password": AnyCodable(password)],
            error: nil
        )
    }

    private func handleDeleteCredential(_ message: IncomingMessage) async throws -> OutgoingMessage {
        guard let domain = message.data?["domain"]?.value as? String,
              let username = message.data?["username"]?.value as? String
        else {
            throw NativeHostError.missingParameter("domain or username")
        }

        try await passwordsBridge.deleteCredential(domain: domain, username: username)

        return OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: ["deleted": AnyCodable(true)],
            error: nil
        )
    }

    // MARK: - Hide My Email Handlers

    private func handleCreateAlias(_ message: IncomingMessage) async throws -> OutgoingMessage {
        guard let domain = message.data?["domain"]?.value as? String else {
            throw NativeHostError.missingParameter("domain")
        }

        let label = message.data?["label"]?.value as? String

        let alias = try await hideMyEmailBridge.createAlias(for: domain, label: label)

        return OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: [
                "id": AnyCodable(alias.id),
                "email": AnyCodable(alias.email),
                "label": AnyCodable(alias.label),
                "domain": AnyCodable(alias.domain),
                "isActive": AnyCodable(alias.isActive),
                "createdAt": AnyCodable(alias.createdAt.ISO8601Format())
            ],
            error: nil
        )
    }

    private func handleGetAliases(_ message: IncomingMessage) async throws -> OutgoingMessage {
        try await hideMyEmailBridge.fetchAliases()

        let aliasDicts: [[String: AnyCodable]] = hideMyEmailBridge.aliases.map { alias in
            [
                "id": AnyCodable(alias.id),
                "email": AnyCodable(alias.email),
                "label": AnyCodable(alias.label),
                "domain": AnyCodable(alias.domain),
                "isActive": AnyCodable(alias.isActive),
                "createdAt": AnyCodable(alias.createdAt.ISO8601Format()),
                "messagesReceived": AnyCodable(alias.messagesReceived)
            ]
        }

        return OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: ["aliases": AnyCodable(aliasDicts)],
            error: nil
        )
    }

    private func handleDeactivateAlias(_ message: IncomingMessage) async throws -> OutgoingMessage {
        guard let aliasId = message.data?["aliasId"]?.value as? String else {
            throw NativeHostError.missingParameter("aliasId")
        }

        try await hideMyEmailBridge.deactivateAlias(aliasId)

        return OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: ["deactivated": AnyCodable(true)],
            error: nil
        )
    }

    private func handleReactivateAlias(_ message: IncomingMessage) async throws -> OutgoingMessage {
        guard let aliasId = message.data?["aliasId"]?.value as? String else {
            throw NativeHostError.missingParameter("aliasId")
        }

        try await hideMyEmailBridge.reactivateAlias(aliasId)

        return OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: ["reactivated": AnyCodable(true)],
            error: nil
        )
    }

    private func handleDeleteAlias(_ message: IncomingMessage) async throws -> OutgoingMessage {
        guard let aliasId = message.data?["aliasId"]?.value as? String else {
            throw NativeHostError.missingParameter("aliasId")
        }

        try await hideMyEmailBridge.deleteAlias(aliasId)

        return OutgoingMessage(
            type: message.type.rawValue,
            requestId: message.requestId,
            success: true,
            data: ["deleted": AnyCodable(true)],
            error: nil
        )
    }

    private func handleGetAliasForDomain(_ message: IncomingMessage) async throws -> OutgoingMessage {
        guard let domain = message.data?["domain"]?.value as? String else {
            throw NativeHostError.missingParameter("domain")
        }

        if let alias = hideMyEmailBridge.getAlias(for: domain) {
            return OutgoingMessage(
                type: message.type.rawValue,
                requestId: message.requestId,
                success: true,
                data: [
                    "found": AnyCodable(true),
                    "email": AnyCodable(alias.email),
                    "label": AnyCodable(alias.label)
                ],
                error: nil
            )
        } else {
            return OutgoingMessage(
                type: message.type.rawValue,
                requestId: message.requestId,
                success: true,
                data: ["found": AnyCodable(false)],
                error: nil
            )
        }
    }

    // MARK: - Autofill Helpers

    private func handleAutofillCredential(_ message: IncomingMessage) async throws -> OutgoingMessage {
        guard let domain = message.data?["domain"]?.value as? String else {
            throw NativeHostError.missingParameter("domain")
        }

        let credentials = try await passwordsBridge.getCredentials(for: domain)

        if let credential = credentials.first {
            return OutgoingMessage(
                type: message.type.rawValue,
                requestId: message.requestId,
                success: true,
                data: [
                    "found": AnyCodable(true),
                    "username": AnyCodable(credential.username),
                    "password": AnyCodable(credential.password)
                ],
                error: nil
            )
        } else {
            return OutgoingMessage(
                type: message.type.rawValue,
                requestId: message.requestId,
                success: true,
                data: ["found": AnyCodable(false)],
                error: nil
            )
        }
    }

    private func handleAutofillAlias(_ message: IncomingMessage) async throws -> OutgoingMessage {
        guard let domain = message.data?["domain"]?.value as? String else {
            throw NativeHostError.missingParameter("domain")
        }

        // Check if alias exists, otherwise create one
        if let alias = hideMyEmailBridge.getAlias(for: domain) {
            return OutgoingMessage(
                type: message.type.rawValue,
                requestId: message.requestId,
                success: true,
                data: [
                    "email": AnyCodable(alias.email),
                    "isNew": AnyCodable(false)
                ],
                error: nil
            )
        } else {
            let alias = try await hideMyEmailBridge.createAlias(for: domain)
            return OutgoingMessage(
                type: message.type.rawValue,
                requestId: message.requestId,
                success: true,
                data: [
                    "email": AnyCodable(alias.email),
                    "isNew": AnyCodable(true)
                ],
                error: nil
            )
        }
    }

    // MARK: - AI Chat Handler

    private func handleChat(_ message: IncomingMessage) async throws -> OutgoingMessage {
        guard let content = message.data?["content"]?.value as? String else {
            throw NativeHostError.missingParameter("content")
        }

        // Forward to Thea's TheaMessagingGateway on port 18789
        let url = URL(string: "http://localhost:18789/message")!  // swiftlint:disable:this force_unwrapping
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "content": content,
            "chatId": message.data?["chatId"]?.value as? String ?? "browser-extension",
            "senderId": message.data?["senderId"]?.value as? String ?? "local-user",
            "senderName": message.data?["senderName"]?.value as? String ?? "Browser"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        // Send POST request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NativeHostError.invalidData
        }

        if httpResponse.statusCode == 200 {
            return OutgoingMessage(
                type: message.type.rawValue,
                requestId: message.requestId,
                success: true,
                data: ["forwarded": AnyCodable(true)],
                error: nil
            )
        } else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NativeHostError.invalidData
        }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        FileHandle.standardError.write("[\(timestamp)] Thea: \(message)\n".data(using: .utf8)!)
    }
}

// MARK: - Errors

enum NativeHostError: Error, LocalizedError {
    case invalidMessageLength
    case incompleteMessage
    case missingParameter(String)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidMessageLength:
            "Invalid message length"
        case .incompleteMessage:
            "Incomplete message received"
        case let .missingParameter(param):
            "Missing required parameter: \(param)"
        case .invalidData:
            "Invalid data format"
        }
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        case nil:
            try container.encodeNil()
        default:
            if let optional = value as Any?, case Optional<Any>.none = optional {
                try container.encodeNil()
            } else {
                try container.encode(String(describing: value))
            }
        }
    }
}

// MARK: - Main Entry Point

@main
struct TheaNativeMessagingHostApp {
    static func main() async {
        let host = await TheaNativeMessagingHost()
        await host.run()
    }
}
