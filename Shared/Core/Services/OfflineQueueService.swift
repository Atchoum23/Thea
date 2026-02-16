// OfflineQueueService.swift
// Thea V2 - Offline Request Queue
//
// Queues requests when offline and processes them when connectivity returns
// Implements 2026 best practices for offline-first architecture

import Foundation
import Network
import OSLog
import UserNotifications

// MARK: - Offline Queue Service

/// Manages offline request queuing and synchronization
@MainActor
@Observable
public final class OfflineQueueService {
    public static let shared = OfflineQueueService()

    private let logger = Logger(subsystem: "app.thea.offline", category: "OfflineQueue")
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "app.thea.network.monitor")
    let userDefaults: UserDefaults

    // MARK: - State

    /// Current network status
    public internal(set) var isOnline: Bool = true

    /// Queue of pending requests
    public internal(set) var pendingRequests: [OfflineQueuedRequest] = []

    /// Whether the queue is currently being processed
    public internal(set) var isProcessing: Bool = false

    /// Statistics
    public internal(set) var stats = OfflineQueueStats()

    // MARK: - Configuration

    public var config = OfflineQueueConfig()

    // MARK: - Initialization

    private init() {
        self.userDefaults = .standard
        loadPendingRequests()
        startNetworkMonitoring()
    }

    /// Internal init for testing — skips network monitoring and UserDefaults loading
    init(forTesting: Bool, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // Do not start network monitor or load from UserDefaults
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
    public func queueRequest(_ request: OfflineQueuedRequest) {
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
        let request = OfflineQueuedRequest(
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

    func processRequest(_ request: OfflineQueuedRequest) async throws {
        logger.info("Processing request: \(request.type.rawValue)")

        switch request.type {
        case .chat:
            // Chat requests are handled by the ChatManager when replayed
            // The payload contains serialized messages that can be restored
            if let payload = request.payload,
               let chatRequest = try? JSONDecoder().decode(ChatRequestPayload.self, from: payload)
            {
                // Post notification for ChatManager to handle
                NotificationCenter.default.post(
                    name: .offlineRequestReplay,
                    object: chatRequest
                )
            }

        case .sync:
            // Trigger sync via notification (CloudKitService observes this)
            NotificationCenter.default.post(name: .offlineRequestReplay, object: ["type": "sync"])

        case .analytics:
            // Analytics events are non-critical; log and discard
            logger.info("Replaying analytics event (no-op)")

        case .notification:
            // Re-post local notification from payload
            if let payload = request.payload,
               let info = try? JSONDecoder().decode([String: String].self, from: payload),
               let title = info["title"],
               let body = info["body"]
            {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let notifRequest = UNNotificationRequest(
                    identifier: request.id.uuidString,
                    content: content,
                    trigger: trigger
                )
                try? await UNUserNotificationCenter.current().add(notifRequest)
            }

        case .memory:
            // Trigger memory sync via notification
            NotificationCenter.default.post(name: .offlineRequestReplay, object: ["type": "memory"])

        case .custom:
            // Custom requests post a generic notification for app-level handling
            if let payload = request.payload {
                NotificationCenter.default.post(
                    name: .offlineRequestReplay,
                    object: payload
                )
            }
        }
    }

    func removeRequest(_ id: UUID) {
        pendingRequests.removeAll { $0.id == id }
    }

    func updateRequest(_ request: OfflineQueuedRequest) {
        if let index = pendingRequests.firstIndex(where: { $0.id == request.id }) {
            pendingRequests[index] = request
        }
    }

    // MARK: - Persistence

    func loadPendingRequests() {
        guard let data = userDefaults.data(forKey: "offline.pendingRequests"),
              let requests = try? JSONDecoder().decode([OfflineQueuedRequest].self, from: data)
        else { return }

        pendingRequests = requests
        logger.info("Loaded \(requests.count) pending requests from storage")
    }

    func savePendingRequests() {
        guard let data = try? JSONEncoder().encode(pendingRequests) else { return }
        userDefaults.set(data, forKey: "offline.pendingRequests")
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
public struct OfflineQueuedRequest: Identifiable, Codable, Sendable {
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

// MARK: - Notifications

public extension Notification.Name {
    static let offlineRequestReplay = Notification.Name("thea.offline.requestReplay")
}
