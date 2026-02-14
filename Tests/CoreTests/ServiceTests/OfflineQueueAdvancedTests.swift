@testable import TheaServices
import XCTest

final class OfflineQueueAdvancedTests: XCTestCase {

    // MARK: - Request Priority Edge Cases

    func testRequestPriorityEquality() {
        XCTAssertEqual(RequestPriority.critical, RequestPriority.critical)
        XCTAssertNotEqual(RequestPriority.low, RequestPriority.high)
    }

    func testRequestPriorityNotGreaterThanSelf() {
        let a = RequestPriority.normal
        let b = RequestPriority.normal
        XCTAssertFalse(a > b)
    }

    func testRequestPriorityRangeComparisons() {
        XCTAssertTrue(RequestPriority.low < RequestPriority.critical)
        XCTAssertFalse(RequestPriority.critical < RequestPriority.low)
    }

    // MARK: - OfflineQueueStats Edge Cases

    func testSuccessRateWithOnlyQueued() {
        var stats = OfflineQueueStats()
        stats.queuedRequests = 10
        // No processed or failed
        XCTAssertEqual(stats.successRate, 1.0)
    }

    func testSuccessRateHalfFailed() {
        var stats = OfflineQueueStats()
        stats.processedRequests = 5
        stats.failedRequests = 5
        XCTAssertEqual(stats.successRate, 0.5, accuracy: 0.001)
    }

    func testStatsTracksDropped() {
        var stats = OfflineQueueStats()
        stats.droppedRequests = 3
        stats.expiredRequests = 2
        XCTAssertEqual(stats.droppedRequests, 3)
        XCTAssertEqual(stats.expiredRequests, 2)
    }

    // MARK: - Request Creation Patterns

    func testChatRequestCreation() {
        let id = UUID()
        let request = OfflineQueuedRequest(
            id: id,
            type: .chat,
            priority: .critical,
            payload: nil,
            createdAt: Date(),
            retryCount: 0
        )
        XCTAssertEqual(request.id, id)
        XCTAssertEqual(request.type, .chat)
        XCTAssertEqual(request.priority, .critical)
        XCTAssertEqual(request.retryCount, 0)
    }

    func testSyncRequestCreation() {
        let request = OfflineQueuedRequest(
            id: UUID(),
            type: .sync,
            priority: .normal,
            payload: nil,
            createdAt: Date(),
            retryCount: 0
        )
        XCTAssertEqual(request.type, .sync)
        XCTAssertEqual(request.priority, .normal)
    }

    func testRequestRetryIncrement() {
        var request = OfflineQueuedRequest(
            id: UUID(),
            type: .analytics,
            priority: .low,
            payload: nil,
            createdAt: Date(),
            retryCount: 0
        )
        request.retryCount += 1
        XCTAssertEqual(request.retryCount, 1)
        request.retryCount += 1
        XCTAssertEqual(request.retryCount, 2)
    }

    // MARK: - Config Validation

    func testConfigMaxRetriesRange() {
        var config = OfflineQueueConfig()
        config.maxRetries = 0
        XCTAssertEqual(config.maxRetries, 0)
        config.maxRetries = 100
        XCTAssertEqual(config.maxRetries, 100)
    }

    func testConfigExpirationTimeRange() {
        var config = OfflineQueueConfig()
        config.requestExpirationTime = 60 // 1 minute
        XCTAssertEqual(config.requestExpirationTime, 60)
        config.requestExpirationTime = 604800 // 1 week
        XCTAssertEqual(config.requestExpirationTime, 604800)
    }

    // MARK: - Serialized Message Tests

    func testSerializedMessageRoundTrip() throws {
        let original = ChatRequestPayload.SerializedMessage(
            id: UUID(),
            conversationID: UUID(),
            role: "system",
            content: "You are a helpful assistant",
            timestamp: Date()
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatRequestPayload.SerializedMessage.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.role, "system")
        XCTAssertEqual(decoded.content, "You are a helpful assistant")
    }

    func testChatRequestPayloadMultipleMessages() throws {
        let convID = UUID()
        let payload = ChatRequestPayload(
            messages: [
                ChatRequestPayload.SerializedMessage(
                    id: UUID(), conversationID: convID,
                    role: "system", content: "System prompt", timestamp: Date()
                ),
                ChatRequestPayload.SerializedMessage(
                    id: UUID(), conversationID: convID,
                    role: "user", content: "Hello", timestamp: Date()
                ),
                ChatRequestPayload.SerializedMessage(
                    id: UUID(), conversationID: convID,
                    role: "assistant", content: "Hi there!", timestamp: Date()
                )
            ],
            model: "claude-opus-4-5",
            providerId: "anthropic",
            conversationId: convID
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ChatRequestPayload.self, from: data)
        XCTAssertEqual(decoded.messages.count, 3)
        XCTAssertEqual(decoded.messages[0].role, "system")
        XCTAssertEqual(decoded.messages[1].role, "user")
        XCTAssertEqual(decoded.messages[2].role, "assistant")
        XCTAssertEqual(decoded.conversationId, convID)
    }

    func testChatRequestPayloadEmptyMessages() throws {
        let payload = ChatRequestPayload(
            messages: [],
            model: "gpt-4o",
            providerId: "openai",
            conversationId: UUID()
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ChatRequestPayload.self, from: data)
        XCTAssertTrue(decoded.messages.isEmpty)
    }

    // MARK: - Error Identifiability

    func testOfflineQueueErrorQueuedContainsID() {
        let id = UUID()
        let error = OfflineQueueError.requestQueued(id)
        guard let description = error.errorDescription else {
            XCTFail("Error should have description")
            return
        }
        XCTAssertTrue(description.contains(id.uuidString))
    }

    func testAllRequestTypesEncodable() throws {
        let types: [RequestType] = [.chat, .sync, .analytics, .notification, .memory, .custom]
        for type in types {
            let data = try JSONEncoder().encode(type)
            XCTAssertFalse(data.isEmpty, "\(type) should encode to non-empty data")
        }
    }
}
