@testable import TheaServices
import XCTest

final class OfflineQueueTypesTests: XCTestCase {

    // MARK: - RequestPriority

    func testRequestPriorityOrdering() {
        XCTAssertTrue(RequestPriority.low < RequestPriority.normal)
        XCTAssertTrue(RequestPriority.normal < RequestPriority.high)
        XCTAssertTrue(RequestPriority.high < RequestPriority.critical)
    }

    func testRequestPriorityRawValues() {
        XCTAssertEqual(RequestPriority.low.rawValue, 0)
        XCTAssertEqual(RequestPriority.normal.rawValue, 1)
        XCTAssertEqual(RequestPriority.high.rawValue, 2)
        XCTAssertEqual(RequestPriority.critical.rawValue, 3)
    }

    func testRequestPrioritySorting() {
        let priorities: [RequestPriority] = [.normal, .critical, .low, .high]
        let sorted = priorities.sorted()
        XCTAssertEqual(sorted, [.low, .normal, .high, .critical])
    }

    func testRequestPriorityCodable() throws {
        let priority = RequestPriority.high
        let data = try JSONEncoder().encode(priority)
        let decoded = try JSONDecoder().decode(RequestPriority.self, from: data)
        XCTAssertEqual(decoded, priority)
    }

    // MARK: - RequestType

    func testRequestTypeCases() {
        let cases: [RequestType] = [.chat, .sync, .analytics, .notification, .memory, .custom]
        XCTAssertEqual(cases.count, 6)
    }

    func testRequestTypeCodableRoundtrip() throws {
        for type in [RequestType.chat, .sync, .analytics, .notification, .memory, .custom] {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(RequestType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    // MARK: - OfflineQueueConfig

    func testOfflineQueueConfigDefaults() {
        let config = OfflineQueueConfig()
        XCTAssertEqual(config.maxQueueSize, 100)
        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.requestExpirationTime, 86400)
        XCTAssertTrue(config.autoProcessOnConnect)
    }

    func testOfflineQueueConfigCustomValues() {
        var config = OfflineQueueConfig()
        config.maxQueueSize = 50
        config.maxRetries = 5
        config.requestExpirationTime = 3600
        config.autoProcessOnConnect = false

        XCTAssertEqual(config.maxQueueSize, 50)
        XCTAssertEqual(config.maxRetries, 5)
        XCTAssertEqual(config.requestExpirationTime, 3600)
        XCTAssertFalse(config.autoProcessOnConnect)
    }

    // MARK: - OfflineQueueStats

    func testOfflineQueueStatsDefaults() {
        let stats = OfflineQueueStats()
        XCTAssertEqual(stats.queuedRequests, 0)
        XCTAssertEqual(stats.processedRequests, 0)
        XCTAssertEqual(stats.failedRequests, 0)
        XCTAssertEqual(stats.expiredRequests, 0)
        XCTAssertEqual(stats.droppedRequests, 0)
    }

    func testOfflineQueueStatsSuccessRateNoRequests() {
        let stats = OfflineQueueStats()
        XCTAssertEqual(stats.successRate, 1.0)
    }

    func testOfflineQueueStatsSuccessRateAllSuccessful() {
        var stats = OfflineQueueStats()
        stats.processedRequests = 10
        stats.failedRequests = 0
        XCTAssertEqual(stats.successRate, 1.0)
    }

    func testOfflineQueueStatsSuccessRateAllFailed() {
        var stats = OfflineQueueStats()
        stats.processedRequests = 0
        stats.failedRequests = 5
        XCTAssertEqual(stats.successRate, 0.0)
    }

    func testOfflineQueueStatsSuccessRateMixed() {
        var stats = OfflineQueueStats()
        stats.processedRequests = 7
        stats.failedRequests = 3
        XCTAssertEqual(stats.successRate, 0.7, accuracy: 0.001)
    }

    // MARK: - OfflineQueueError

    func testOfflineQueueErrorDescriptions() {
        let id = UUID()
        XCTAssertNotNil(OfflineQueueError.requestQueued(id).errorDescription)
        XCTAssertTrue(OfflineQueueError.requestQueued(id).errorDescription!.contains(id.uuidString))

        XCTAssertEqual(OfflineQueueError.providerNotAvailable.errorDescription, "Provider not available")
        XCTAssertEqual(OfflineQueueError.requestExpired.errorDescription, "Request expired")
        XCTAssertEqual(OfflineQueueError.queueFull.errorDescription, "Queue is full")
    }

    // MARK: - OfflineQueuedRequest

    func testOfflineQueuedRequestCodable() throws {
        let request = OfflineQueuedRequest(
            id: UUID(),
            type: .chat,
            priority: .high,
            payload: "test".data(using: .utf8),
            createdAt: Date(),
            retryCount: 2
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(OfflineQueuedRequest.self, from: data)

        XCTAssertEqual(decoded.id, request.id)
        XCTAssertEqual(decoded.type, request.type)
        XCTAssertEqual(decoded.priority, request.priority)
        XCTAssertEqual(decoded.retryCount, request.retryCount)
        XCTAssertNotNil(decoded.payload)
    }

    func testOfflineQueuedRequestNilPayload() throws {
        let request = OfflineQueuedRequest(
            id: UUID(),
            type: .sync,
            priority: .low,
            payload: nil,
            createdAt: Date(),
            retryCount: 0
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(OfflineQueuedRequest.self, from: data)
        XCTAssertNil(decoded.payload)
    }

    // MARK: - ChatRequestPayload

    func testChatRequestPayloadCodable() throws {
        let payload = ChatRequestPayload(
            messages: [
                ChatRequestPayload.SerializedMessage(
                    id: UUID(),
                    conversationID: UUID(),
                    role: "user",
                    content: "Hello",
                    timestamp: Date()
                )
            ],
            model: "gpt-4",
            providerId: "openai",
            conversationId: UUID()
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ChatRequestPayload.self, from: data)

        XCTAssertEqual(decoded.messages.count, 1)
        XCTAssertEqual(decoded.model, "gpt-4")
        XCTAssertEqual(decoded.providerId, "openai")
        XCTAssertEqual(decoded.messages[0].role, "user")
        XCTAssertEqual(decoded.messages[0].content, "Hello")
    }
}
