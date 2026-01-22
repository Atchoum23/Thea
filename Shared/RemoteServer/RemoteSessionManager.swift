//
//  RemoteSessionManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
import Network
import Combine

// MARK: - Remote Session Manager

/// Manages active remote client sessions
@MainActor
public class RemoteSessionManager: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var activeSessions: [RemoteSession] = []
    @Published public private(set) var sessionHistory: [SessionRecord] = []

    // MARK: - Configuration

    public var maxSessions: Int = 5
    public var sessionTimeout: TimeInterval = 3600 // 1 hour
    public var heartbeatInterval: TimeInterval = 30

    // MARK: - Session Storage

    private var sessions: [String: RemoteSession] = [:]
    private var sessionTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Initialization

    public init() {
        // Load session history
        loadSessionHistory()
    }

    // MARK: - Session Lifecycle

    /// Create a new session for a connection
    public func createSession(for connection: NWConnection) async -> RemoteSession {
        let session = RemoteSession(connection: connection)
        sessions[session.id] = session
        activeSessions = Array(sessions.values)

        // Start session tasks
        startSessionTasks(for: session)

        // Record in history
        recordSessionStart(session)

        return session
    }

    /// Authenticate a session and grant permissions
    public func authenticateSession(_ sessionId: String, permissions: Set<RemotePermission>) async {
        guard var session = sessions[sessionId] else { return }

        session.isAuthenticated = true
        session.permissions = permissions
        session.authenticatedAt = Date()

        sessions[sessionId] = session
        activeSessions = Array(sessions.values)
    }

    /// Terminate a session
    public func terminateSession(_ sessionId: String, reason: String) async {
        guard let session = sessions[sessionId] else { return }

        // Cancel tasks
        sessionTasks[sessionId]?.cancel()
        sessionTasks.removeValue(forKey: sessionId)

        // Close connection
        session.connection.cancel()

        // Remove from active
        sessions.removeValue(forKey: sessionId)
        activeSessions = Array(sessions.values)

        // Record in history
        recordSessionEnd(session, reason: reason)
    }

    /// Disconnect all sessions
    public func disconnectAll(reason: String) async {
        let sessionIds = Array(sessions.keys)
        for sessionId in sessionIds {
            await terminateSession(sessionId, reason: reason)
        }
    }

    // MARK: - Session Tasks

    private func startSessionTasks(for session: RemoteSession) {
        let task = Task {
            await runSessionLoop(session)
        }
        sessionTasks[session.id] = task
    }

    private func runSessionLoop(_ session: RemoteSession) async {
        var lastActivity = Date()

        while !Task.isCancelled {
            // Check timeout
            if Date().timeIntervalSince(lastActivity) > sessionTimeout {
                await terminateSession(session.id, reason: "Session timeout")
                return
            }

            // Wait for heartbeat interval
            try? await Task.sleep(nanoseconds: UInt64(heartbeatInterval * 1_000_000_000))

            // Update activity timestamp if connection is alive
            if sessions[session.id] != nil {
                lastActivity = Date()
            } else {
                return
            }
        }
    }

    // MARK: - Session History

    private func recordSessionStart(_ session: RemoteSession) {
        let record = SessionRecord(
            id: session.id,
            clientName: session.client.name,
            clientIP: session.client.ipAddress,
            startTime: Date(),
            endTime: nil,
            endReason: nil,
            permissions: session.permissions
        )

        sessionHistory.insert(record, at: 0)

        // Keep only recent history
        if sessionHistory.count > 100 {
            sessionHistory = Array(sessionHistory.prefix(100))
        }

        saveSessionHistory()
    }

    private func recordSessionEnd(_ session: RemoteSession, reason: String) {
        if let index = sessionHistory.firstIndex(where: { $0.id == session.id }) {
            sessionHistory[index].endTime = Date()
            sessionHistory[index].endReason = reason
        }

        saveSessionHistory()
    }

    private func loadSessionHistory() {
        if let data = UserDefaults.standard.data(forKey: "thea.remote.sessionhistory"),
           let history = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            sessionHistory = history
        }
    }

    private func saveSessionHistory() {
        if let data = try? JSONEncoder().encode(sessionHistory) {
            UserDefaults.standard.set(data, forKey: "thea.remote.sessionhistory")
        }
    }

    // MARK: - Session Query

    /// Get session by ID
    public func session(forId id: String) -> RemoteSession? {
        sessions[id]
    }

    /// Get sessions for a client
    public func sessions(forClient clientId: String) -> [RemoteSession] {
        sessions.values.filter { $0.client.id == clientId }
    }

    /// Count active sessions
    public var activeSessionCount: Int {
        sessions.count
    }
}

// MARK: - Remote Session

public struct RemoteSession: Identifiable, @unchecked Sendable {
    public let id: String
    public let connection: NWConnection
    public let createdAt: Date
    public var isAuthenticated: Bool
    public var authenticatedAt: Date?
    public var permissions: Set<RemotePermission>
    public var sessionKey: Data?
    public let client: RemoteClient

    // Message handling
    public var messageStream: AsyncStream<RemoteMessage> {
        AsyncStream { continuation in
            Task {
                await receiveMessages(continuation: continuation)
            }
        }
    }

    public init(connection: NWConnection) {
        self.id = UUID().uuidString
        self.connection = connection
        self.createdAt = Date()
        self.isAuthenticated = false
        self.permissions = []

        // Extract client info from connection
        var ipAddress = "unknown"
        var deviceType: RemoteClient.DeviceType = .unknown

        switch connection.endpoint {
        case .hostPort(let host, _):
            ipAddress = "\(host)"
        default:
            break
        }

        self.client = RemoteClient(
            id: UUID().uuidString,
            name: "Unknown",
            deviceType: deviceType,
            ipAddress: ipAddress,
            connectedAt: Date(),
            lastActivityAt: Date(),
            permissions: []
        )
    }

    // MARK: - Permission Check

    public func hasPermission(for permission: RemotePermission) -> Bool {
        permissions.contains(permission)
    }

    // MARK: - Message Sending

    public func send(message: RemoteMessage) async throws {
        let data = try message.encode()

        // Add length prefix
        var length = UInt32(data.count).bigEndian
        var framedData = Data(bytes: &length, count: 4)
        framedData.append(data)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: framedData, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    // MARK: - Message Receiving

    public func receiveWithTimeout(timeout: TimeInterval) async throws -> RemoteMessage {
        try await withThrowingTaskGroup(of: RemoteMessage.self) { group in
            group.addTask {
                try await self.receiveMessage()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw RemoteServerError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func receiveMessage() async throws -> RemoteMessage {
        // First receive length prefix
        let lengthData = try await receiveData(length: 4)
        let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

        // Then receive message
        let messageData = try await receiveData(length: Int(length))
        return try RemoteMessage.decode(from: messageData)
    }

    private func receiveData(length: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { content, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = content {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: RemoteServerError.connectionFailed("Connection closed"))
                }
            }
        }
    }

    private func receiveMessages(continuation: AsyncStream<RemoteMessage>.Continuation) async {
        while true {
            do {
                let message = try await receiveMessage()
                continuation.yield(message)
            } catch {
                continuation.finish()
                return
            }
        }
    }
}

// MARK: - Session Record

public struct SessionRecord: Identifiable, Codable, Sendable {
    public let id: String
    public let clientName: String
    public let clientIP: String
    public let startTime: Date
    public var endTime: Date?
    public var endReason: String?
    public let permissions: Set<RemotePermission>

    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    public var isActive: Bool {
        endTime == nil
    }
}
