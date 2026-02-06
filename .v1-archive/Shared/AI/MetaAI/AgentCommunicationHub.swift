import Foundation
import OSLog

// MARK: - Agent Communication Protocol

// Standardized communication between agents in the orchestration system

actor AgentCommunicationHub {
    static let shared = AgentCommunicationHub()

    private let logger = Logger(subsystem: "com.thea.metaai", category: "AgentComm")

    private var messageQueue: [HubAgentMessage] = []
    private var subscribers: [UUID: MessageHandler] = [:]
    private var messageHistory: [UUID: [HubAgentMessage]] = [:]

    typealias MessageHandler = @Sendable (HubAgentMessage) async -> Void

    private init() {}

    // MARK: - Message Passing

    func sendMessage(_ message: HubAgentMessage) async {
        logger.info("Message sent: from=\(message.fromAgent.uuidString) to=\(message.toAgent?.uuidString ?? "broadcast") type=\(message.type.rawValue)")

        // Add to history
        messageHistory[message.fromAgent, default: []].append(message)

        // Add to queue
        messageQueue.append(message)

        // Deliver to specific recipient or broadcast
        if let toAgent = message.toAgent {
            await deliverToAgent(toAgent, message: message)
        } else {
            await broadcast(message)
        }
    }

    func subscribe(agentId: UUID, handler: @escaping MessageHandler) {
        subscribers[agentId] = handler
        logger.info("Agent \(agentId.uuidString) subscribed to messages")
    }

    func unsubscribe(agentId: UUID) {
        subscribers.removeValue(forKey: agentId)
        logger.info("Agent \(agentId.uuidString) unsubscribed from messages")
    }

    func getMessageHistory(for agentId: UUID) async -> [HubAgentMessage] {
        messageHistory[agentId] ?? []
    }

    func clearHistory(for agentId: UUID) async {
        messageHistory.removeValue(forKey: agentId)
    }

    // MARK: - Private Delivery

    private func deliverToAgent(_ agentId: UUID, message: HubAgentMessage) async {
        guard let handler = subscribers[agentId] else {
            logger.warning("No subscriber for agent \(agentId.uuidString)")
            return
        }

        await handler(message)
    }

    private func broadcast(_ message: HubAgentMessage) async {
        logger.info("Broadcasting message from \(message.fromAgent.uuidString) to \(self.subscribers.count) subscribers")

        for (agentId, handler) in subscribers {
            if agentId != message.fromAgent {
                await handler(message)
            }
        }
    }
}

// MARK: - Agent Message

struct HubAgentMessage: Identifiable, Sendable {
    let id: UUID
    let fromAgent: UUID
    let toAgent: UUID?
    let type: MessageType
    let payload: HubMessagePayload
    let timestamp: Date
    let priority: MessagePriority

    init(
        id: UUID = UUID(),
        fromAgent: UUID,
        toAgent: UUID? = nil,
        type: MessageType,
        payload: HubMessagePayload,
        timestamp: Date = Date(),
        priority: MessagePriority = .normal
    ) {
        self.id = id
        self.fromAgent = fromAgent
        self.toAgent = toAgent
        self.type = type
        self.payload = payload
        self.timestamp = timestamp
        self.priority = priority
    }

    enum MessageType: String, Sendable {
        case taskRequest
        case taskResponse
        case statusUpdate
        case dataShare
        case errorReport
        case coordination
        case query
        case acknowledgment
    }

    enum MessagePriority: Int, Sendable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3
    }
}

// MARK: - Message Payload

enum HubMessagePayload: Sendable {
    case task(TaskRequest)
    case result(HubTaskResult)
    case status(AgentStatusUpdate)
    case data(Data)
    case error(AgentErrorInfo)
    case text(String)
    case custom([String: String])
}

struct TaskRequest: Sendable {
    let taskId: UUID
    let taskType: String
    let parameters: [String: String]
    let deadline: Date?
}

struct HubTaskResult: Sendable {
    let taskId: UUID
    let success: Bool
    let output: String
    let metadata: [String: String]
}

struct AgentStatusUpdate: Sendable {
    let status: String
    let progress: Double
    let details: String?
}

struct AgentErrorInfo: Sendable {
    let code: String
    let message: String
    let severity: ErrorSeverity

    enum ErrorSeverity: String, Sendable {
        case warning
        case error
        case critical
    }
}

// MARK: - Request-Response Pattern

actor AgentRequestResponse {
    static let shared = AgentRequestResponse()

    private var pendingRequests: [UUID: CheckedContinuation<HubAgentMessage, Error>] = [:]
    private let timeout: TimeInterval = 30.0

    private init() {}

    func sendRequest(
        from: UUID,
        to: UUID,
        type: HubAgentMessage.MessageType,
        payload: HubMessagePayload
    ) async throws -> HubAgentMessage {
        let requestId = UUID()

        let request = HubAgentMessage(
            id: requestId,
            fromAgent: from,
            toAgent: to,
            type: type,
            payload: payload
        )

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[requestId] = continuation

            Task {
                await AgentCommunicationHub.shared.sendMessage(request)

                // Setup timeout
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))

                if let pending = pendingRequests[requestId] {
                    pendingRequests.removeValue(forKey: requestId)
                    pending.resume(throwing: AgentError.timeout)
                }
            }
        }
    }

    func respondToRequest(requestId: UUID, response: HubAgentMessage) async {
        if let continuation = pendingRequests.removeValue(forKey: requestId) {
            continuation.resume(returning: response)
        }
    }
}

enum AgentError: Error, LocalizedError {
    case timeout
    case agentNotFound
    case invalidResponse
    case communicationFailed

    var errorDescription: String? {
        switch self {
        case .timeout: "Request timed out"
        case .agentNotFound: "Agent not found"
        case .invalidResponse: "Invalid response from agent"
        case .communicationFailed: "Agent communication failed"
        }
    }
}
