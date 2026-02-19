// AgentCommunicationBus.swift
// Thea V2
//
// Inter-agent communication system for parallel multi-agent execution
// Enables agents to share data, coordinate, and broadcast results

import Foundation
import OSLog

// MARK: - Agent Message

/// A message passed between agents
public struct BusAgentMessage: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let senderAgentId: UUID
    public let recipientAgentId: UUID?  // nil = broadcast to all
    public let messageType: BusAgentMessageType
    public let payload: BusAgentMessagePayload
    public let priority: BusMessagePriority
    public let correlationId: UUID?  // Links related messages

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        senderAgentId: UUID,
        recipientAgentId: UUID? = nil,
        messageType: BusAgentMessageType,
        payload: BusAgentMessagePayload,
        priority: BusMessagePriority = .normal,
        correlationId: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.senderAgentId = senderAgentId
        self.recipientAgentId = recipientAgentId
        self.messageType = messageType
        self.payload = payload
        self.priority = priority
        self.correlationId = correlationId
    }
}

/// Types of messages agents can send
public enum BusAgentMessageType: String, Codable, Sendable {
    case dataShare           // Sharing data/results with other agents
    case requestHelp         // Requesting assistance from another agent
    case provideHelp         // Responding to help request
    case statusUpdate        // Progress/status notification
    case coordinationRequest // Coordination between agents
    case taskHandoff         // Passing work to another agent
    case errorNotification   // Reporting an error
    case completionSignal    // Signaling task completion
    case dependencyMet       // Notifying that a dependency is satisfied
    case resourceRequest     // Requesting a shared resource
    case resourceGrant       // Granting resource access
}

/// Payload for agent messages
public enum BusAgentMessagePayload: Sendable {
    case text(String)
    case data([String: String])
    case result(AgentTaskResult)
    case error(AgentError)
    case dependency(DependencyInfo)
    case resource(ResourceInfo)

    public struct AgentTaskResult: Sendable {
        public let taskId: UUID
        public let output: String
        public let success: Bool
        public let metadata: [String: String]

        public init(taskId: UUID, output: String, success: Bool, metadata: [String: String] = [:]) {
            self.taskId = taskId
            self.output = output
            self.success = success
            self.metadata = metadata
        }
    }

    public struct AgentError: Sendable {
        public let code: String
        public let message: String
        public let isRecoverable: Bool

        public init(code: String, message: String, isRecoverable: Bool = true) {
            self.code = code
            self.message = message
            self.isRecoverable = isRecoverable
        }
    }

    public struct DependencyInfo: Sendable {
        public let dependencyId: UUID
        public let dependencyType: String
        public let value: String?

        public init(dependencyId: UUID, dependencyType: String, value: String? = nil) {
            self.dependencyId = dependencyId
            self.dependencyType = dependencyType
            self.value = value
        }
    }

    public struct ResourceInfo: Sendable {
        public let resourceId: String
        public let resourceType: String
        public let status: String

        public init(resourceId: String, resourceType: String, status: String) {
            self.resourceId = resourceId
            self.resourceType = resourceType
            self.status = status
        }
    }
}

/// Priority levels for bus messages
public enum BusMessagePriority: Int, Comparable, Sendable {
    case low = 0
    case normal = 50
    case high = 75
    case critical = 100

    public static func < (lhs: BusMessagePriority, rhs: BusMessagePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Agent Communication Bus

/// Central communication hub for inter-agent messaging
/// Implements publish-subscribe pattern with filtering and history
public actor AgentCommunicationBus {
    public static let shared = AgentCommunicationBus()

    private let logger = Logger(subsystem: "com.thea.agents", category: "CommunicationBus")

    // MARK: - State

    /// Registered agent subscriptions
    private var subscriptions: [UUID: AgentSubscription] = [:]

    /// Message history (bounded)
    private var messageHistory: [BusAgentMessage] = []
    private let maxHistorySize = 1000

    /// Pending messages for offline agents
    private var pendingMessages: [UUID: [BusAgentMessage]] = [:]
    private let maxPendingPerAgent = 100

    /// Active correlation groups
    private var correlationGroups: [UUID: [BusAgentMessage]] = [:]

    /// Message streams for real-time delivery
    private var messageContinuations: [UUID: AsyncStream<BusAgentMessage>.Continuation] = [:]

    private init() {}

    // MARK: - Subscription Management

    /// Register an agent to receive messages
    public func register(
        agentId: UUID,
        filter: BusAgentMessageFilter = .all
    ) -> AsyncStream<BusAgentMessage> {
        logger.info("Registering agent \(agentId.uuidString.prefix(8)) with filter: \(filter.description)")

        // Create stream for this agent
        let (stream, continuation) = AsyncStream<BusAgentMessage>.makeStream()
        messageContinuations[agentId] = continuation

        // Create subscription
        let subscription = AgentSubscription(
            agentId: agentId,
            filter: filter,
            registeredAt: Date()
        )
        subscriptions[agentId] = subscription

        // Deliver any pending messages
        if let pending = pendingMessages[agentId] {
            for message in pending {
                if filter.matches(message) {
                    continuation.yield(message)
                }
            }
            pendingMessages[agentId] = nil
        }

        return stream
    }

    /// Unregister an agent
    public func unregister(agentId: UUID) {
        logger.info("Unregistering agent \(agentId.uuidString.prefix(8))")

        subscriptions.removeValue(forKey: agentId)
        messageContinuations[agentId]?.finish()
        messageContinuations.removeValue(forKey: agentId)
    }

    // MARK: - Message Sending

    /// Send a message through the bus
    public func send(_ message: BusAgentMessage) {
        // Add to history
        messageHistory.append(message)
        if messageHistory.count > maxHistorySize {
            messageHistory.removeFirst(messageHistory.count - maxHistorySize)
        }

        // Track correlation group
        if let correlationId = message.correlationId {
            var group = correlationGroups[correlationId] ?? []
            group.append(message)
            correlationGroups[correlationId] = group
        }

        // Deliver to recipients
        if let recipientId = message.recipientAgentId {
            // Direct message
            deliverToAgent(message, agentId: recipientId)
        } else {
            // Broadcast
            for (agentId, subscription) in subscriptions {
                if agentId != message.senderAgentId && subscription.filter.matches(message) {
                    deliverToAgent(message, agentId: agentId)
                }
            }
        }

        logger.debug("Message sent: \(message.messageType.rawValue) from \(message.senderAgentId.uuidString.prefix(8))")
    }

    /// Deliver message to specific agent
    private func deliverToAgent(_ message: BusAgentMessage, agentId: UUID) {
        if let continuation = messageContinuations[agentId] {
            continuation.yield(message)
        } else {
            // Agent offline, queue for later
            var pending = pendingMessages[agentId] ?? []
            pending.append(message)
            if pending.count > maxPendingPerAgent {
                pending.removeFirst(pending.count - maxPendingPerAgent)
            }
            pendingMessages[agentId] = pending
        }
    }

    // MARK: - Convenience Senders

    /// Share data with other agents
    public func shareData(
        from senderAgentId: UUID,
        to recipientAgentId: UUID? = nil,
        data: [String: String],
        correlationId: UUID? = nil
    ) {
        let message = BusAgentMessage(
            senderAgentId: senderAgentId,
            recipientAgentId: recipientAgentId,
            messageType: .dataShare,
            payload: .data(data),
            correlationId: correlationId
        )
        send(message)
    }

    /// Broadcast task result
    public func broadcastResult(
        from senderAgentId: UUID,
        taskId: UUID,
        output: String,
        success: Bool,
        metadata: [String: String] = [:],
        correlationId: UUID? = nil
    ) {
        let result = BusAgentMessagePayload.AgentTaskResult(
            taskId: taskId,
            output: output,
            success: success,
            metadata: metadata
        )
        let message = BusAgentMessage(
            senderAgentId: senderAgentId,
            messageType: .completionSignal,
            payload: .result(result),
            priority: .high,
            correlationId: correlationId
        )
        send(message)
    }

    /// Signal that a dependency has been met
    public func signalDependencyMet(
        from senderAgentId: UUID,
        dependencyId: UUID,
        dependencyType: String,
        value: String? = nil,
        correlationId: UUID? = nil
    ) {
        let info = BusAgentMessagePayload.DependencyInfo(
            dependencyId: dependencyId,
            dependencyType: dependencyType,
            value: value
        )
        let message = BusAgentMessage(
            senderAgentId: senderAgentId,
            messageType: .dependencyMet,
            payload: .dependency(info),
            priority: .high,
            correlationId: correlationId
        )
        send(message)
    }

    /// Request help from another agent
    public func requestHelp(
        from senderAgentId: UUID,
        to recipientAgentId: UUID,
        description: String,
        correlationId: UUID? = nil
    ) {
        let message = BusAgentMessage(
            senderAgentId: senderAgentId,
            recipientAgentId: recipientAgentId,
            messageType: .requestHelp,
            payload: .text(description),
            priority: .normal,
            correlationId: correlationId
        )
        send(message)
    }

    /// Broadcast error notification
    public func broadcastError(
        from senderAgentId: UUID,
        code: String,
        errorMessage: String,
        isRecoverable: Bool = true,
        correlationId: UUID? = nil
    ) {
        let error = BusAgentMessagePayload.AgentError(
            code: code,
            message: errorMessage,
            isRecoverable: isRecoverable
        )
        let message = BusAgentMessage(
            senderAgentId: senderAgentId,
            messageType: .errorNotification,
            payload: .error(error),
            priority: isRecoverable ? .high : .critical,
            correlationId: correlationId
        )
        send(message)
    }

    // MARK: - Query Methods

    /// Get message history for a correlation group
    public func getCorrelationGroup(_ correlationId: UUID) -> [BusAgentMessage] {
        correlationGroups[correlationId] ?? []
    }

    /// Get recent messages matching a filter
    public func getRecentMessages(
        filter: BusAgentMessageFilter = .all,
        limit: Int = 100
    ) -> [BusAgentMessage] {
        messageHistory
            .filter { filter.matches($0) }
            .suffix(limit)
            .reversed()  // Most recent first
    }

    /// Get count of pending messages for an agent
    public func pendingMessageCount(for agentId: UUID) -> Int {
        pendingMessages[agentId]?.count ?? 0
    }

    /// Get all registered agent IDs
    public var registeredAgentIds: [UUID] {
        Array(subscriptions.keys)
    }

    /// Get subscription count
    public var subscriptionCount: Int {
        subscriptions.count
    }

    // MARK: - Cleanup

    /// Clear old correlation groups
    public func cleanupCorrelationGroups(olderThan cutoff: Date) {
        var toRemove: [UUID] = []
        for (id, messages) in correlationGroups {
            if let lastMessage = messages.last, lastMessage.timestamp < cutoff {
                toRemove.append(id)
            }
        }
        for id in toRemove {
            correlationGroups.removeValue(forKey: id)
        }
        logger.info("Cleaned up \(toRemove.count) correlation groups")
    }

    /// Clear all state (for testing)
    public func reset() {
        subscriptions.removeAll()
        messageHistory.removeAll()
        pendingMessages.removeAll()
        correlationGroups.removeAll()
        for continuation in messageContinuations.values {
            continuation.finish()
        }
        messageContinuations.removeAll()
    }
}

// MARK: - Agent Subscription

/// Represents an agent's subscription to the bus
struct AgentSubscription: Sendable {
    // periphery:ignore - Reserved: agentId property — reserved for future feature activation
    let agentId: UUID
    // periphery:ignore - Reserved: agentId property reserved for future feature activation
    let filter: BusAgentMessageFilter
    // periphery:ignore - Reserved: registeredAt property reserved for future feature activation
    let registeredAt: Date
}

// MARK: - Message Filter

/// Filter for selecting which messages an agent receives
public struct BusAgentMessageFilter: Sendable {
    public let messageTypes: Set<BusAgentMessageType>?
    public let priorities: Set<BusMessagePriority>?
    public let senderIds: Set<UUID>?
    public let excludeSenderIds: Set<UUID>?

    public init(
        messageTypes: Set<BusAgentMessageType>? = nil,
        priorities: Set<BusMessagePriority>? = nil,
        senderIds: Set<UUID>? = nil,
        excludeSenderIds: Set<UUID>? = nil
    ) {
        self.messageTypes = messageTypes
        self.priorities = priorities
        self.senderIds = senderIds
        self.excludeSenderIds = excludeSenderIds
    }

    /// Match all messages
    public static let all = BusAgentMessageFilter()

    /// Match only high priority messages
    public static let highPriority = BusAgentMessageFilter(
        priorities: [.high, .critical]
    )

    /// Match only data sharing messages
    public static let dataOnly = BusAgentMessageFilter(
        messageTypes: [.dataShare, .completionSignal]
    )

    /// Match coordination messages
    public static let coordination = BusAgentMessageFilter(
        messageTypes: [.coordinationRequest, .taskHandoff, .dependencyMet, .resourceRequest, .resourceGrant]
    )

    /// Check if a message matches this filter
    public func matches(_ message: BusAgentMessage) -> Bool {
        // Check message type
        if let types = messageTypes, !types.contains(message.messageType) {
            return false
        }

        // Check priority
        if let priorities = priorities, !priorities.contains(message.priority) {
            return false
        }

        // Check sender whitelist
        if let senders = senderIds, !senders.contains(message.senderAgentId) {
            return false
        }

        // Check sender blacklist
        if let excludes = excludeSenderIds, excludes.contains(message.senderAgentId) {
            return false
        }

        return true
    }

    public var description: String {
        var parts: [String] = []
        if let types = messageTypes {
            parts.append("types:\(types.map(\.rawValue).joined(separator: ","))")
        }
        if let priorities = priorities {
            parts.append("priorities:\(priorities.map { String($0.rawValue) }.joined(separator: ","))")
        }
        if senderIds != nil {
            parts.append("whitelist")
        }
        if excludeSenderIds != nil {
            parts.append("blacklist")
        }
        return parts.isEmpty ? "all" : parts.joined(separator: " ")
    }
}
