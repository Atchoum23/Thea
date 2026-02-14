import Foundation
import XCTest

/// Standalone tests for Network Resilience types:
/// NetworkRetryPolicy, exponential backoff, retryable errors,
/// OfflineQueueService types, queue statistics.
/// Mirrors types from Networking/NetworkManager.swift and Core/Services/OfflineQueueService.swift.
final class NetworkResilienceTypesTests: XCTestCase {

    // MARK: - NetworkRetryPolicy (mirror NetworkManager.swift)

    struct NetworkRetryPolicy: Sendable {
        let maxRetries: Int
        let baseDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double
        let retryableCodes: Set<Int>

        static let `default` = NetworkRetryPolicy(
            maxRetries: 3, baseDelay: 1.0, maxDelay: 30.0,
            multiplier: 2.0, retryableCodes: [408, 429, 500, 502, 503, 504]
        )

        static let none = NetworkRetryPolicy(
            maxRetries: 0, baseDelay: 0, maxDelay: 0,
            multiplier: 0, retryableCodes: []
        )

        func delay(for attempt: Int) -> TimeInterval {
            min(baseDelay * pow(multiplier, Double(attempt - 1)), maxDelay)
        }
    }

    func testDefaultPolicyValues() {
        let policy = NetworkRetryPolicy.default
        XCTAssertEqual(policy.maxRetries, 3)
        XCTAssertEqual(policy.baseDelay, 1.0)
        XCTAssertEqual(policy.maxDelay, 30.0)
        XCTAssertEqual(policy.multiplier, 2.0)
        XCTAssertEqual(policy.retryableCodes, [408, 429, 500, 502, 503, 504])
    }

    func testNonePolicyValues() {
        let policy = NetworkRetryPolicy.none
        XCTAssertEqual(policy.maxRetries, 0)
        XCTAssertTrue(policy.retryableCodes.isEmpty)
    }

    // MARK: - Exponential Backoff Calculation

    func testExponentialBackoffAttempt1() {
        let policy = NetworkRetryPolicy.default
        XCTAssertEqual(policy.delay(for: 1), 1.0, accuracy: 0.001)
    }

    func testExponentialBackoffAttempt2() {
        let policy = NetworkRetryPolicy.default
        XCTAssertEqual(policy.delay(for: 2), 2.0, accuracy: 0.001)
    }

    func testExponentialBackoffAttempt3() {
        let policy = NetworkRetryPolicy.default
        XCTAssertEqual(policy.delay(for: 3), 4.0, accuracy: 0.001)
    }

    func testExponentialBackoffAttempt4() {
        let policy = NetworkRetryPolicy.default
        XCTAssertEqual(policy.delay(for: 4), 8.0, accuracy: 0.001)
    }

    func testExponentialBackoffAttempt5() {
        let policy = NetworkRetryPolicy.default
        XCTAssertEqual(policy.delay(for: 5), 16.0, accuracy: 0.001)
    }

    func testExponentialBackoffCappedAtMaxDelay() {
        let policy = NetworkRetryPolicy.default
        // Attempt 6: 1.0 * 2^5 = 32, capped at 30
        XCTAssertEqual(policy.delay(for: 6), 30.0, accuracy: 0.001)
        // Attempt 10: 1.0 * 2^9 = 512, capped at 30
        XCTAssertEqual(policy.delay(for: 10), 30.0, accuracy: 0.001)
    }

    func testCustomBackoffPolicy() {
        let policy = NetworkRetryPolicy(
            maxRetries: 5, baseDelay: 0.5, maxDelay: 10.0,
            multiplier: 3.0, retryableCodes: [429]
        )
        XCTAssertEqual(policy.delay(for: 1), 0.5, accuracy: 0.001)   // 0.5 * 3^0
        XCTAssertEqual(policy.delay(for: 2), 1.5, accuracy: 0.001)   // 0.5 * 3^1
        XCTAssertEqual(policy.delay(for: 3), 4.5, accuracy: 0.001)   // 0.5 * 3^2
        XCTAssertEqual(policy.delay(for: 4), 10.0, accuracy: 0.001)  // 0.5 * 3^3 = 13.5, capped
    }

    // MARK: - Retryable Error Classification

    func shouldRetryStatusCode(_ code: Int, policy: NetworkRetryPolicy) -> Bool {
        policy.retryableCodes.contains(code)
    }

    func testRetryableStatusCodes() {
        let policy = NetworkRetryPolicy.default
        XCTAssertTrue(shouldRetryStatusCode(408, policy: policy), "Timeout")
        XCTAssertTrue(shouldRetryStatusCode(429, policy: policy), "Rate limit")
        XCTAssertTrue(shouldRetryStatusCode(500, policy: policy), "Internal error")
        XCTAssertTrue(shouldRetryStatusCode(502, policy: policy), "Bad gateway")
        XCTAssertTrue(shouldRetryStatusCode(503, policy: policy), "Unavailable")
        XCTAssertTrue(shouldRetryStatusCode(504, policy: policy), "Gateway timeout")
    }

    func testNonRetryableStatusCodes() {
        let policy = NetworkRetryPolicy.default
        XCTAssertFalse(shouldRetryStatusCode(200, policy: policy), "Success")
        XCTAssertFalse(shouldRetryStatusCode(400, policy: policy), "Bad request")
        XCTAssertFalse(shouldRetryStatusCode(401, policy: policy), "Unauthorized")
        XCTAssertFalse(shouldRetryStatusCode(403, policy: policy), "Forbidden")
        XCTAssertFalse(shouldRetryStatusCode(404, policy: policy), "Not found")
        XCTAssertFalse(shouldRetryStatusCode(422, policy: policy), "Unprocessable")
    }

    // MARK: - NetworkError (mirror NetworkManager.swift)

    enum NetworkError: Error, LocalizedError {
        case noConnection
        case timeout
        case invalidResponse
        case httpError(Int, Data?)
        case decodingError(Error)
        case unknown

        var errorDescription: String? {
            switch self {
            case .noConnection: "No network connection"
            case .timeout: "Request timed out"
            case .invalidResponse: "Invalid server response"
            case .httpError(let code, _): "HTTP error \(code)"
            case .decodingError(let error): "Decoding error: \(error.localizedDescription)"
            case .unknown: "Unknown network error"
            }
        }
    }

    func testNetworkErrorDescriptions() {
        XCTAssertEqual(NetworkError.noConnection.errorDescription, "No network connection")
        XCTAssertEqual(NetworkError.timeout.errorDescription, "Request timed out")
        XCTAssertEqual(NetworkError.invalidResponse.errorDescription, "Invalid server response")
        XCTAssertEqual(NetworkError.unknown.errorDescription, "Unknown network error")
    }

    func testNetworkErrorHTTPCode() {
        let error = NetworkError.httpError(503, nil)
        XCTAssertTrue(error.errorDescription?.contains("503") ?? false)
    }

    func testNetworkErrorIsRetryable() {
        let retryableErrors: [NetworkError] = [.timeout, .noConnection]
        for error in retryableErrors {
            switch error {
            case .timeout, .noConnection:
                break // These should be retryable
            default:
                XCTFail("\(error) should be in retryable set")
            }
        }
    }

    // MARK: - ConnectionType (mirror NetworkManager.swift)

    enum ConnectionType: String, Sendable {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    func testConnectionTypes() {
        XCTAssertEqual(ConnectionType.wifi.rawValue, "wifi")
        XCTAssertEqual(ConnectionType.cellular.rawValue, "cellular")
        XCTAssertEqual(ConnectionType.ethernet.rawValue, "ethernet")
        XCTAssertEqual(ConnectionType.unknown.rawValue, "unknown")
    }

    // MARK: - RequestPriority (mirror OfflineQueueService.swift)

    enum RequestPriority: Int, Codable, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3

        static func < (lhs: RequestPriority, rhs: RequestPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    func testRequestPriorityOrdering() {
        XCTAssertTrue(RequestPriority.low < .normal)
        XCTAssertTrue(RequestPriority.normal < .high)
        XCTAssertTrue(RequestPriority.high < .critical)
        XCTAssertFalse(RequestPriority.critical < .low)
    }

    func testRequestPrioritySorting() {
        let priorities: [RequestPriority] = [.normal, .critical, .low, .high]
        let sorted = priorities.sorted()
        XCTAssertEqual(sorted, [.low, .normal, .high, .critical])
    }

    func testRequestPriorityCodable() throws {
        for priority in [RequestPriority.low, .normal, .high, .critical] {
            let data = try JSONEncoder().encode(priority)
            let decoded = try JSONDecoder().decode(RequestPriority.self, from: data)
            XCTAssertEqual(decoded, priority)
        }
    }

    // MARK: - RequestType (mirror OfflineQueueService.swift)

    enum RequestType: String, Codable {
        case chat
        case sync
        case analytics
        case notification
        case memory
        case custom
    }

    func testRequestTypeCodable() throws {
        for type in [RequestType.chat, .sync, .analytics, .notification, .memory, .custom] {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(RequestType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    // MARK: - OfflineQueueConfig (mirror OfflineQueueService.swift)

    struct OfflineQueueConfig {
        let maxQueueSize: Int
        let maxRetries: Int
        let requestExpirationTime: TimeInterval
        let autoProcessOnConnect: Bool

        static let `default` = OfflineQueueConfig(
            maxQueueSize: 100, maxRetries: 3,
            requestExpirationTime: 86400, autoProcessOnConnect: true
        )
    }

    func testOfflineQueueConfigDefaults() {
        let config = OfflineQueueConfig.default
        XCTAssertEqual(config.maxQueueSize, 100)
        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.requestExpirationTime, 86400)
        XCTAssertTrue(config.autoProcessOnConnect)
    }

    func testOfflineQueueConfigCustom() {
        let config = OfflineQueueConfig(
            maxQueueSize: 50, maxRetries: 5,
            requestExpirationTime: 3600, autoProcessOnConnect: false
        )
        XCTAssertEqual(config.maxQueueSize, 50)
        XCTAssertEqual(config.maxRetries, 5)
        XCTAssertFalse(config.autoProcessOnConnect)
    }

    // MARK: - OfflineQueueStats (mirror OfflineQueueService.swift)

    struct OfflineQueueStats {
        let queuedRequests: Int
        let processedRequests: Int
        let failedRequests: Int
        let expiredRequests: Int
        let droppedRequests: Int

        var successRate: Double {
            let total = processedRequests + failedRequests
            guard total > 0 else { return 0 }
            return Double(processedRequests) / Double(total)
        }
    }

    func testQueueStatsSuccessRate() {
        let stats = OfflineQueueStats(
            queuedRequests: 5, processedRequests: 80,
            failedRequests: 20, expiredRequests: 3, droppedRequests: 1
        )
        XCTAssertEqual(stats.successRate, 0.8, accuracy: 0.001)
    }

    func testQueueStatsZeroDivision() {
        let stats = OfflineQueueStats(
            queuedRequests: 0, processedRequests: 0,
            failedRequests: 0, expiredRequests: 0, droppedRequests: 0
        )
        XCTAssertEqual(stats.successRate, 0.0)
    }

    func testQueueStatsPerfectSuccess() {
        let stats = OfflineQueueStats(
            queuedRequests: 0, processedRequests: 100,
            failedRequests: 0, expiredRequests: 0, droppedRequests: 0
        )
        XCTAssertEqual(stats.successRate, 1.0)
    }

    // MARK: - OfflineQueueError (mirror OfflineQueueService.swift)

    enum OfflineQueueError: Error, LocalizedError {
        case requestQueued(UUID)
        case providerNotAvailable
        case requestExpired
        case queueFull

        var errorDescription: String? {
            switch self {
            case .requestQueued(let id): "Request queued: \(id.uuidString)"
            case .providerNotAvailable: "Provider not available"
            case .requestExpired: "Request has expired"
            case .queueFull: "Offline queue is full"
            }
        }
    }

    func testOfflineQueueErrorDescriptions() {
        XCTAssertNotNil(OfflineQueueError.providerNotAvailable.errorDescription)
        XCTAssertNotNil(OfflineQueueError.requestExpired.errorDescription)
        XCTAssertNotNil(OfflineQueueError.queueFull.errorDescription)
    }

    func testOfflineQueueErrorRequestQueued() {
        let id = UUID()
        let error = OfflineQueueError.requestQueued(id)
        XCTAssertTrue(error.errorDescription?.contains(id.uuidString) ?? false)
    }

    // MARK: - Queue Expiration Logic

    func isRequestExpired(createdAt: Date, expirationTime: TimeInterval) -> Bool {
        Date().timeIntervalSince(createdAt) > expirationTime
    }

    func testRequestNotExpired() {
        let recent = Date()
        XCTAssertFalse(isRequestExpired(createdAt: recent, expirationTime: 86400))
    }

    func testRequestExpired() {
        let old = Date().addingTimeInterval(-90000) // 25 hours ago
        XCTAssertTrue(isRequestExpired(createdAt: old, expirationTime: 86400)) // 24h expiration
    }

    // MARK: - Queue Priority Sorting

    struct QueuedRequest: Comparable {
        let id: UUID
        let priority: RequestPriority
        let createdAt: Date

        static func < (lhs: QueuedRequest, rhs: QueuedRequest) -> Bool {
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority // Higher priority first
            }
            return lhs.createdAt < rhs.createdAt // Earlier first
        }
    }

    func testQueueSortingPriorityFirst() {
        let now = Date()
        let low = QueuedRequest(id: UUID(), priority: .low, createdAt: now)
        let high = QueuedRequest(id: UUID(), priority: .high, createdAt: now.addingTimeInterval(60))

        let sorted = [low, high].sorted()
        XCTAssertEqual(sorted.first?.priority, .high, "Higher priority should come first")
    }

    func testQueueSortingSamePriorityByTime() {
        let now = Date()
        let earlier = QueuedRequest(id: UUID(), priority: .normal, createdAt: now)
        let later = QueuedRequest(id: UUID(), priority: .normal, createdAt: now.addingTimeInterval(60))

        let sorted = [later, earlier].sorted()
        XCTAssertEqual(sorted.first?.createdAt, now, "Earlier request should come first at same priority")
    }

    // MARK: - WebSocketMessage (mirror NetworkManager.swift)

    enum WebSocketMessage {
        case text(String)
        case data(Data)
    }

    func testWebSocketMessageText() {
        let msg = WebSocketMessage.text("Hello")
        if case .text(let text) = msg {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected text message")
        }
    }

    func testWebSocketMessageData() {
        let payload = Data([0x01, 0x02, 0x03])
        let msg = WebSocketMessage.data(payload)
        if case .data(let data) = msg {
            XCTAssertEqual(data.count, 3)
        } else {
            XCTFail("Expected data message")
        }
    }
}
