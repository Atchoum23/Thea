// OfflineQueueService.swift
// Thea V2 - Offline Request Queue
//
// Queues requests when offline and processes them when connectivity returns
// Implements 2026 best practices for offline-first architecture

import Foundation
import Network
import OSLog

// MARK: - Offline Queue Service

/// Manages offline request queuing and synchronization
@MainActor
@Observable
public final class OfflineQueueService {
    public static let shared = OfflineQueueService()

    private let logger = Logger(subsystem: "app.thea.offline", category: "OfflineQueue")
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "app.thea.network.monitor")

    // MARK: - State

    /// Current network status
    public private(set) var isOnline: Bool = true

    /// Queue of pending requests
    public private(set) var pendingRequests: [QueuedRequest] = []

    /// Whether the queue is currently being processed
    public private(set) var isProcessing: Bool = false

    /// Statistics
    public private(set) var stats = OfflineQueueStats()

    // MARK: - Configuration

    public var config = OfflineQueueConfig()

    // MARK: - Initialization

    private init() {
        loadPendingRequests()
        startNetworkMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }

                let wasOnline = self.isOnline
                self.isOnline = path.status == .satisfied

                if !wasOnline && self.isOnline {
                    self.logger.info("Network restored - processing offline queue")
                    await self.processQueue()
                } else if wasOnline && !self.isOnline {
                    self.logger.info("Network lost - requests will be queued")
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Queue Management

    /// Queue a request for later execution
    public func queueRequest(_ request: QueuedRequest) {
        // Check if queue is full
        if pendingRequests.count >= config.maxQueueSize {
            // Remove oldest low-priority request
            if let oldestLowPriority = pendingRequests.first(where: { $0.priority == .low }) {
                pendingRequests.removeAll { $0.id == oldestLowPriority.id }
                stats.droppedRequests += 1
            } else {
                logger.warning("Queue full, dropping new request")
                stats.droppedRequests += 1
                return
            }
        }

        pendingRequests.append(request)
        savePendingRequests()
        stats.queuedRequests += 1
        logger.info("Queued request: \(request.type.rawValue)")
    }

    /// Execute a request, queuing if offline
    public func execute<T: Codable>(
        type: RequestType,
        priority: RequestPriority = .normal,
        execute: @escaping () async throws -> T
    ) async throws -> T {
        if isOnline {
            // Execute immediately
            return try await execute()
        }

        // Queue for later
        let request = QueuedRequest(
            id: UUID(),
            type: type,
            priority: priority,
            payload: nil,
            createdAt: Date(),
            retryCount: 0
        )

        queueRequest(request)
        throw OfflineQueueError.requestQueued(request.id)
    }

    /// Process all queued requests
    public func processQueue() async {
        guard isOnline && !isProcessing && !pendingRequests.isEmpty else { return }

        isProcessing = true
        defer { isProcessing = false }

        logger.info("Processing \(self.pendingRequests.count) queued requests")

        // Sort by priority and creation time
        let sortedRequests = pendingRequests.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority.rawValue > rhs.priority.rawValue
            }
            return lhs.createdAt < rhs.createdAt
        }

        for request in sortedRequests {
            // Check if request has expired
            if Date().timeIntervalSince(request.createdAt) > config.requestExpirationTime {
                removeRequest(request.id)
                stats.expiredRequests += 1
                continue
            }

            do {
                try await processRequest(request)
                removeRequest(request.id)
                stats.processedRequests += 1
            } catch {
                logger.warning("Failed to process queued request: \(error.localizedDescription)")

                // Retry logic
                if request.retryCount < config.maxRetries {
                    var updatedRequest = request
                    updatedRequest.retryCount += 1
                    updateRequest(updatedRequest)
                } else {
                    removeRequest(request.id)
                    stats.failedRequests += 1
                }
            }

            // Small delay between requests
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        savePendingRequests()
    }

    private func processRequest(_ request: QueuedRequest) async throws {
        logger.info("Processing request: \(request.type.rawValue)")

        switch request.type {
        case .chat:
            // Reconstruct and execute chat request
            if let payload = request.payload,
               let chatRequest = try? JSONDecoder().decode(ChatRequestPayload.self, from: payload)
            {
                let provider = ProviderRegistry.shared.getProvider(id: chatRequest.providerId)
                guard let provider else {
                    throw OfflineQueueError.providerNotAvailable
                }

                let messages = chatRequest.messages.map { msg in
                    AIMessage(
                        id: msg.id,
                        conversationID: msg.conversationID,
                        role: AIMessageRole(rawValue: msg.role) ?? .user,
                        content: .text(msg.content),
                        timestamp: msg.timestamp,
                        model: chatRequest.model
                    )
                }

                _ = try await provider.chat(
                    messages: messages,
                    model: chatRequest.model,
                    stream: false
                )
            }

        case .sync:
            // Trigger sync
            // This would integrate with sync services
            break

        case .analytics:
            // Send analytics
            break

        case .notification:
            // Resend notification
            break

        case .memory:
            // Sync memory
            break

        case .custom:
            // Custom request handling
            break
        }
    }

    private func removeRequest(_ id: UUID) {
        pendingRequests.removeAll { $0.id == id }
    }

    private func updateRequest(_ request: QueuedRequest) {
        if let index = pendingRequests.firstIndex(where: { $0.id == request.id }) {
            pendingRequests[index] = request
        }
    }

    // MARK: - Persistence

    private func loadPendingRequests() {
        guard let data = UserDefaults.standard.data(forKey: "offline.pendingRequests"),
              let requests = try? JSONDecoder().decode([QueuedRequest].self, from: data)
        else { return }

        pendingRequests = requests
        logger.info("Loaded \(requests.count) pending requests from storage")
    }

    private func savePendingRequests() {
        guard let data = try? JSONEncoder().encode(pendingRequests) else { return }
        UserDefaults.standard.set(data, forKey: "offline.pendingRequests")
    }

    // MARK: - Queue Status

    /// Get queue size by priority
    public func queueSizeByPriority() -> [RequestPriority: Int] {
        Dictionary(grouping: pendingRequests, by: \.priority)
            .mapValues(\.count)
    }

    /// Clear all pending requests
    public func clearQueue() {
        pendingRequests.removeAll()
        savePendingRequests()
        logger.info("Cleared offline queue")
    }

    /// Clear expired requests
    public func clearExpiredRequests() {
        let now = Date()
        pendingRequests.removeAll { request in
            now.timeIntervalSince(request.createdAt) > config.requestExpirationTime
        }
        savePendingRequests()
    }
}

// MARK: - Supporting Types

/// A request queued for later execution
public struct QueuedRequest: Identifiable, Codable, Sendable {
    public let id: UUID
    public let type: RequestType
    public let priority: RequestPriority
    public let payload: Data?
    public let createdAt: Date
    public var retryCount: Int
}

/// Types of requests that can be queued
public enum RequestType: String, Codable, Sendable {
    case chat
    case sync
    case analytics
    case notification
    case memory
    case custom
}

/// Priority levels for queued requests
public enum RequestPriority: Int, Codable, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: RequestPriority, rhs: RequestPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Payload for chat requests
public struct ChatRequestPayload: Codable, Sendable {
    public let messages: [SerializedMessage]
    public let model: String
    public let providerId: String
    public let conversationId: UUID

    public struct SerializedMessage: Codable, Sendable {
        public let id: UUID
        public let conversationID: UUID
        public let role: String  // "user", "assistant", "system"
        public let content: String
        public let timestamp: Date
    }
}

/// Configuration for offline queue
public struct OfflineQueueConfig: Sendable {
    /// Maximum number of requests to queue
    public var maxQueueSize: Int = 100

    /// Maximum retries per request
    public var maxRetries: Int = 3

    /// Request expiration time (24 hours)
    public var requestExpirationTime: TimeInterval = 86400

    /// Whether to auto-process queue when online
    public var autoProcessOnConnect: Bool = true

    public init() {}
}

/// Statistics for offline queue
public struct OfflineQueueStats: Sendable {
    public var queuedRequests: Int = 0
    public var processedRequests: Int = 0
    public var failedRequests: Int = 0
    public var expiredRequests: Int = 0
    public var droppedRequests: Int = 0

    public var successRate: Double {
        let total = processedRequests + failedRequests
        guard total > 0 else { return 1.0 }
        return Double(processedRequests) / Double(total)
    }
}

/// Errors for offline queue
public enum OfflineQueueError: LocalizedError {
    case requestQueued(UUID)
    case providerNotAvailable
    case requestExpired
    case queueFull

    public var errorDescription: String? {
        switch self {
        case .requestQueued(let id):
            "Request queued for later: \(id)"
        case .providerNotAvailable:
            "Provider not available"
        case .requestExpired:
            "Request expired"
        case .queueFull:
            "Queue is full"
        }
    }
}
