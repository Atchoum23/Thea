// AgentCommunication.swift
import Foundation

/// Inter-agent communication protocol for message passing, context sharing, and coordination.
/// Enables agents to collaborate by sharing information and results.
@MainActor
@Observable
public final class AgentCommunication {
    public static let shared = AgentCommunication()

    // MARK: - State

    private(set) var messageQueue: [AgentMessage] = []
    private(set) var sharedContext: [String: Any] = [:]
    private(set) var subscriptions: [UUID: Set<MessageType>] = [:]

    private let maxQueueSize = 1000
    private let messageRetentionSeconds: TimeInterval = 3600 // 1 hour

    private init() {
        // Start cleanup timer
        startCleanupTimer()
    }

    // MARK: - Message Passing

    /// Send a message from one agent to another (or broadcast)
    public func send(
        from senderID: UUID,
        to recipientID: UUID?,
        type: MessageType,
        payload: MessagePayload
    ) {
        let message = AgentMessage(
            id: UUID(),
            senderID: senderID,
            recipientID: recipientID,
            type: type,
            payload: payload,
            timestamp: Date()
        )

        // Add to queue
        messageQueue.append(message)

        // Trim queue if too large
        if messageQueue.count > maxQueueSize {
            messageQueue.removeFirst(messageQueue.count - maxQueueSize)
        }

        print("[AgentCommunication] Message sent: \(type.rawValue) from \(senderID)")
    }

    /// Receive messages for a specific agent
    public func receive(for agentID: UUID, since: Date? = nil) -> [AgentMessage] {
        let cutoffDate = since ?? Date.distantPast

        return messageQueue.filter { message in
            // Check if message is for this agent (direct or broadcast)
            let isRecipient = message.recipientID == agentID || message.recipientID == nil

            // Check if agent is subscribed to this message type
            let isSubscribed = subscriptions[agentID]?.contains(message.type) ?? false

            // Check timestamp
            let isRecent = message.timestamp >= cutoffDate

            return isRecipient && isSubscribed && isRecent
        }
    }

    /// Get all messages of a specific type
    public func getMessages(ofType type: MessageType) -> [AgentMessage] {
        return messageQueue.filter { $0.type == type }
    }

    /// Get latest message from an agent
    public func getLatestMessage(from senderID: UUID, type: MessageType? = nil) -> AgentMessage? {
        var messages = messageQueue.filter { $0.senderID == senderID }

        if let type = type {
            messages = messages.filter { $0.type == type }
        }

        return messages.sorted { $0.timestamp > $1.timestamp }.first
    }

    // MARK: - Subscriptions

    /// Subscribe an agent to specific message types
    public func subscribe(_ agentID: UUID, to types: [MessageType]) {
        if subscriptions[agentID] == nil {
            subscriptions[agentID] = Set()
        }

        for type in types {
            subscriptions[agentID]?.insert(type)
        }

        print("[AgentCommunication] Agent \(agentID) subscribed to: \(types.map { $0.rawValue }.joined(separator: ", "))")
    }

    /// Unsubscribe an agent from specific message types
    public func unsubscribe(_ agentID: UUID, from types: [MessageType]) {
        for type in types {
            subscriptions[agentID]?.remove(type)
        }
    }

    /// Unsubscribe an agent from all message types
    public func unsubscribeAll(_ agentID: UUID) {
        subscriptions.removeValue(forKey: agentID)
    }

    // MARK: - Shared Context

    /// Store value in shared context
    public func setContext<T>(_ key: String, value: T) {
        sharedContext[key] = value
        print("[AgentCommunication] Context updated: \(key)")

        // Broadcast context update
        send(
            from: UUID(), // System
            to: nil, // Broadcast
            type: .contextUpdate,
            payload: .text("Context key '\(key)' updated")
        )
    }

    /// Retrieve value from shared context
    public func getContext<T>(_ key: String) -> T? {
        return sharedContext[key] as? T
    }

    /// Remove value from shared context
    public func removeContext(_ key: String) {
        sharedContext.removeValue(forKey: key)
    }

    /// Clear all shared context
    public func clearContext() {
        sharedContext.removeAll()
        print("[AgentCommunication] Shared context cleared")
    }

    // MARK: - Coordination Primitives

    /// Request help from another agent
    public func requestHelp(
        from requesterID: UUID,
        capability: AgentCapability,
        task: String
    ) -> UUID {
        let messageID = UUID()

        send(
            from: requesterID,
            to: nil, // Broadcast to find capable agent
            type: .helpRequest,
            payload: .structured([
                "messageID": messageID.uuidString,
                "capability": capability.rawValue,
                "task": task
            ])
        )

        return messageID
    }

    /// Respond to a help request
    public func respondToHelp(
        from responderID: UUID,
        requestID: UUID,
        accepted: Bool,
        message: String
    ) {
        send(
            from: responderID,
            to: nil,
            type: .helpResponse,
            payload: .structured([
                "requestID": requestID.uuidString,
                "accepted": String(accepted),
                "message": message
            ])
        )
    }

    /// Share result with other agents
    public func shareResult(
        from agentID: UUID,
        result: String,
        metadata: [String: String] = [:]
    ) {
        send(
            from: agentID,
            to: nil, // Broadcast
            type: .resultSharing,
            payload: .structured([
                "result": result,
                "metadata": metadata
            ] as [String : Any])
        )
    }

    /// Broadcast event to all agents
    public func broadcastEvent(
        from agentID: UUID,
        event: AgentEvent,
        data: [String: Any] = [:]
    ) {
        send(
            from: agentID,
            to: nil,
            type: .event,
            payload: .structured([
                "event": event.rawValue,
                "data": data
            ] as [String : Any])
        )
    }

    // MARK: - Cleanup

    private func startCleanupTimer() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes

                cleanupOldMessages()
            }
        }
    }

    private func cleanupOldMessages() {
        let cutoffDate = Date().addingTimeInterval(-messageRetentionSeconds)
        let beforeCount = messageQueue.count

        messageQueue.removeAll { $0.timestamp < cutoffDate }

        let removedCount = beforeCount - messageQueue.count
        if removedCount > 0 {
            print("[AgentCommunication] Cleaned up \(removedCount) old messages")
        }
    }

    /// Clear all messages
    public func clearMessages() {
        messageQueue.removeAll()
        print("[AgentCommunication] Message queue cleared")
    }

    // MARK: - Statistics

    /// Get communication statistics
    public func getStats() -> CommunicationStats {
        return CommunicationStats(
            totalMessages: messageQueue.count,
            messagesByType: Dictionary(grouping: messageQueue, by: { $0.type })
                .mapValues { $0.count },
            activeAgents: Set(messageQueue.map { $0.senderID }).count,
            subscribedAgents: subscriptions.count,
            contextKeys: sharedContext.count
        )
    }
}

// MARK: - Supporting Types

/// Agent message
public struct AgentMessage: Identifiable {
    public let id: UUID
    public let senderID: UUID
    public let recipientID: UUID? // nil = broadcast
    public let type: MessageType
    public let payload: MessagePayload
    public let timestamp: Date

    /// Check if message is a broadcast
    public var isBroadcast: Bool {
        return recipientID == nil
    }
}

/// Message types
public enum MessageType: String, Codable, CaseIterable, Hashable {
    case taskAssignment
    case taskResult
    case helpRequest
    case helpResponse
    case contextUpdate
    case resultSharing
    case event
    case coordination
    case error
    case status

    public var displayName: String {
        switch self {
        case .taskAssignment: return "Task Assignment"
        case .taskResult: return "Task Result"
        case .helpRequest: return "Help Request"
        case .helpResponse: return "Help Response"
        case .contextUpdate: return "Context Update"
        case .resultSharing: return "Result Sharing"
        case .event: return "Event"
        case .coordination: return "Coordination"
        case .error: return "Error"
        case .status: return "Status"
        }
    }
}

/// Message payload types
public enum MessagePayload {
    case text(String)
    case structured([String: Any])
    case binary(Data)

    /// Extract text content
    public var text: String? {
        switch self {
        case .text(let content):
            return content
        case .structured(let dict):
            return dict.description
        case .binary:
            return nil
        }
    }

    /// Extract structured data
    public var structured: [String: Any]? {
        switch self {
        case .structured(let dict):
            return dict
        default:
            return nil
        }
    }
}

/// Agent events
public enum AgentEvent: String, Codable {
    case started
    case completed
    case failed
    case paused
    case resumed
    case cancelled

    public var displayName: String {
        return rawValue.capitalized
    }
}

/// Communication statistics
public struct CommunicationStats {
    public let totalMessages: Int
    public let messagesByType: [MessageType: Int]
    public let activeAgents: Int
    public let subscribedAgents: Int
    public let contextKeys: Int
}
