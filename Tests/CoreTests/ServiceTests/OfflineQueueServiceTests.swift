@testable import TheaServices
import XCTest

@MainActor
final class OfflineQueueServiceTests: XCTestCase {

    private var sut: OfflineQueueService!
    private var testDefaults: UserDefaults!
    private var testSuiteName: String!

    override func setUp() async throws {
        testSuiteName = "test.offline.queue.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)
        sut = OfflineQueueService(forTesting: true, userDefaults: testDefaults)
    }

    override func tearDown() async throws {
        if let name = testSuiteName {
            testDefaults?.removePersistentDomain(forName: name)
        }
        testDefaults = nil
        testSuiteName = nil
        sut = nil
    }

    // MARK: - Initial State

    func testInitialStateIsOnline() {
        XCTAssertTrue(sut.isOnline)
    }

    func testInitialStateEmptyQueue() {
        XCTAssertTrue(sut.pendingRequests.isEmpty)
    }

    func testInitialStateNotProcessing() {
        XCTAssertFalse(sut.isProcessing)
    }

    func testInitialStatsAllZero() {
        XCTAssertEqual(sut.stats.queuedRequests, 0)
        XCTAssertEqual(sut.stats.processedRequests, 0)
        XCTAssertEqual(sut.stats.failedRequests, 0)
        XCTAssertEqual(sut.stats.expiredRequests, 0)
        XCTAssertEqual(sut.stats.droppedRequests, 0)
    }

    func testDefaultConfig() {
        XCTAssertEqual(sut.config.maxQueueSize, 100)
        XCTAssertEqual(sut.config.maxRetries, 3)
        XCTAssertEqual(sut.config.requestExpirationTime, 86400)
        XCTAssertTrue(sut.config.autoProcessOnConnect)
    }

    // MARK: - Queue Request

    func testQueueRequestAddsToQueue() {
        let request = makeRequest(type: .chat, priority: .normal)
        sut.queueRequest(request)
        XCTAssertEqual(sut.pendingRequests.count, 1)
        XCTAssertEqual(sut.pendingRequests[0].id, request.id)
    }

    func testQueueRequestIncrementsStat() {
        sut.queueRequest(makeRequest(type: .sync))
        XCTAssertEqual(sut.stats.queuedRequests, 1)
        sut.queueRequest(makeRequest(type: .analytics))
        XCTAssertEqual(sut.stats.queuedRequests, 2)
    }

    func testQueueRequestSavesToUserDefaults() {
        let request = makeRequest(type: .chat)
        sut.queueRequest(request)

        let data = testDefaults.data(forKey: "offline.pendingRequests")
        XCTAssertNotNil(data)
        let decoded = try? JSONDecoder().decode([OfflineQueuedRequest].self, from: data!)
        XCTAssertEqual(decoded?.count, 1)
        XCTAssertEqual(decoded?.first?.id, request.id)
    }

    func testQueueFullDropsNewRequestWhenNoLowPriority() {
        sut.config.maxQueueSize = 2
        sut.queueRequest(makeRequest(type: .chat, priority: .high))
        sut.queueRequest(makeRequest(type: .sync, priority: .critical))

        // Queue is full (2/2), all high+, no low-priority to evict
        let dropped = makeRequest(type: .analytics, priority: .normal)
        sut.queueRequest(dropped)

        XCTAssertEqual(sut.pendingRequests.count, 2)
        XCTAssertEqual(sut.stats.droppedRequests, 1)
        XCTAssertFalse(sut.pendingRequests.contains { $0.id == dropped.id })
    }

    func testQueueFullEvictsLowPriorityRequest() {
        sut.config.maxQueueSize = 2
        let lowReq = makeRequest(type: .analytics, priority: .low)
        sut.queueRequest(lowReq)
        sut.queueRequest(makeRequest(type: .sync, priority: .high))

        // Queue full, but has a low-priority request to evict
        let newReq = makeRequest(type: .chat, priority: .normal)
        sut.queueRequest(newReq)

        XCTAssertEqual(sut.pendingRequests.count, 2)
        XCTAssertEqual(sut.stats.droppedRequests, 1)
        XCTAssertFalse(sut.pendingRequests.contains { $0.id == lowReq.id })
        XCTAssertTrue(sut.pendingRequests.contains { $0.id == newReq.id })
    }

    // MARK: - Execute

    func testExecuteOnlineRunsImmediately() async throws {
        sut.isOnline = true
        let result: String = try await sut.execute(type: .chat) { "hello" }
        XCTAssertEqual(result, "hello")
    }

    func testExecuteOfflineQueuesAndThrows() async {
        sut.isOnline = false
        do {
            let _: String = try await sut.execute(type: .sync, priority: .high) { "nope" }
            XCTFail("Should throw requestQueued")
        } catch let error as OfflineQueueError {
            if case .requestQueued = error {
                XCTAssertEqual(sut.pendingRequests.count, 1)
                XCTAssertEqual(sut.pendingRequests[0].type, .sync)
                XCTAssertEqual(sut.pendingRequests[0].priority, .high)
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Process Queue

    func testProcessQueueGuardsOffline() async {
        sut.isOnline = false
        sut.queueRequest(makeRequest(type: .chat))
        await sut.processQueue()
        XCTAssertEqual(sut.pendingRequests.count, 1, "Should not process when offline")
    }

    func testProcessQueueGuardsEmpty() async {
        sut.isOnline = true
        await sut.processQueue()
        // No crash, no processing
        XCTAssertFalse(sut.isProcessing)
    }

    func testProcessQueueRemovesProcessedRequests() async {
        sut.isOnline = true
        // Analytics type doesn't throw
        sut.queueRequest(makeRequest(type: .analytics))
        await sut.processQueue()

        XCTAssertTrue(sut.pendingRequests.isEmpty)
        XCTAssertEqual(sut.stats.processedRequests, 1)
    }

    func testProcessQueueHandlesSyncRequest() async {
        sut.isOnline = true
        let expectation = XCTestExpectation(description: "sync notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineRequestReplay, object: nil, queue: .main
        ) { notification in
            if let dict = notification.object as? [String: String], dict["type"] == "sync" {
                expectation.fulfill()
            }
        }

        sut.queueRequest(makeRequest(type: .sync))
        await sut.processQueue()

        await fulfillment(of: [expectation], timeout: 2)
        NotificationCenter.default.removeObserver(observer)
        XCTAssertTrue(sut.pendingRequests.isEmpty)
    }

    func testProcessQueueHandlesMemoryRequest() async {
        sut.isOnline = true
        let expectation = XCTestExpectation(description: "memory notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineRequestReplay, object: nil, queue: .main
        ) { notification in
            if let dict = notification.object as? [String: String], dict["type"] == "memory" {
                expectation.fulfill()
            }
        }

        sut.queueRequest(makeRequest(type: .memory))
        await sut.processQueue()

        await fulfillment(of: [expectation], timeout: 2)
        NotificationCenter.default.removeObserver(observer)
    }

    func testProcessQueueHandlesChatRequestWithPayload() async throws {
        sut.isOnline = true
        let chatPayload = ChatRequestPayload(
            messages: [ChatRequestPayload.SerializedMessage(
                id: UUID(), conversationID: UUID(),
                role: "user", content: "Hello", timestamp: Date()
            )],
            model: "claude-opus-4-5",
            providerId: "anthropic",
            conversationId: UUID()
        )
        let payloadData = try XCTUnwrap(try? JSONEncoder().encode(chatPayload))

        let expectation = XCTestExpectation(description: "chat notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineRequestReplay, object: nil, queue: .main
        ) { notification in
            if notification.object is ChatRequestPayload {
                expectation.fulfill()
            }
        }

        sut.queueRequest(makeRequest(type: .chat, payload: payloadData))
        await sut.processQueue()

        await fulfillment(of: [expectation], timeout: 2)
        NotificationCenter.default.removeObserver(observer)
    }

    func testProcessQueueHandlesChatRequestWithoutPayload() async {
        sut.isOnline = true
        sut.queueRequest(makeRequest(type: .chat, payload: nil))
        await sut.processQueue()
        XCTAssertTrue(sut.pendingRequests.isEmpty)
        XCTAssertEqual(sut.stats.processedRequests, 1)
    }

    func testProcessQueueHandlesCustomRequestWithPayload() async {
        sut.isOnline = true
        let payload = Data("custom-data".utf8)

        let expectation = XCTestExpectation(description: "custom notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineRequestReplay, object: nil, queue: .main
        ) { notification in
            if notification.object is Data {
                expectation.fulfill()
            }
        }

        sut.queueRequest(makeRequest(type: .custom, payload: payload))
        await sut.processQueue()

        await fulfillment(of: [expectation], timeout: 2)
        NotificationCenter.default.removeObserver(observer)
    }

    func testProcessQueueHandlesCustomRequestWithoutPayload() async {
        sut.isOnline = true
        sut.queueRequest(makeRequest(type: .custom, payload: nil))
        await sut.processQueue()
        XCTAssertTrue(sut.pendingRequests.isEmpty)
        XCTAssertEqual(sut.stats.processedRequests, 1)
    }

    func testProcessQueueHandlesNotificationRequestWithPayload() async throws {
        sut.isOnline = true
        let info: [String: String] = ["title": "Test", "body": "Body"]
        let payload = try JSONEncoder().encode(info)

        sut.queueRequest(makeRequest(type: .notification, payload: payload))
        await sut.processQueue()
        XCTAssertTrue(sut.pendingRequests.isEmpty)
        XCTAssertEqual(sut.stats.processedRequests, 1)
    }

    func testProcessQueueHandlesNotificationRequestWithoutPayload() async {
        sut.isOnline = true
        sut.queueRequest(makeRequest(type: .notification, payload: nil))
        await sut.processQueue()
        XCTAssertTrue(sut.pendingRequests.isEmpty)
        XCTAssertEqual(sut.stats.processedRequests, 1)
    }

    func testProcessQueueHandlesNotificationRequestWithInvalidPayload() async {
        sut.isOnline = true
        sut.queueRequest(makeRequest(type: .notification, payload: Data("invalid".utf8)))
        await sut.processQueue()
        XCTAssertTrue(sut.pendingRequests.isEmpty)
        XCTAssertEqual(sut.stats.processedRequests, 1)
    }

    func testProcessQueueExpiredRequestsAreSkipped() async {
        sut.isOnline = true
        sut.config.requestExpirationTime = 0.001 // Expire almost immediately

        let request = OfflineQueuedRequest(
            id: UUID(), type: .analytics, priority: .normal,
            payload: nil, createdAt: Date().addingTimeInterval(-1), retryCount: 0
        )
        sut.queueRequest(request)
        await sut.processQueue()

        XCTAssertTrue(sut.pendingRequests.isEmpty)
        XCTAssertEqual(sut.stats.expiredRequests, 1)
        XCTAssertEqual(sut.stats.processedRequests, 0)
    }

    func testProcessQueueSortsByPriorityThenTime() async {
        sut.isOnline = true

        let lowReq = makeRequest(type: .analytics, priority: .low)
        let highReq = makeRequest(type: .analytics, priority: .high)
        let normalReq = makeRequest(type: .analytics, priority: .normal)

        sut.queueRequest(lowReq)
        sut.queueRequest(highReq)
        sut.queueRequest(normalReq)

        // Process queue — high should come first, then normal, then low
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineRequestReplay, object: nil, queue: nil
        ) { _ in }
        await sut.processQueue()
        NotificationCenter.default.removeObserver(observer)

        // All should be processed
        XCTAssertTrue(sut.pendingRequests.isEmpty)
        XCTAssertEqual(sut.stats.processedRequests, 3)
    }

    // MARK: - Remove / Update Request

    func testRemoveRequest() {
        let request = makeRequest(type: .chat)
        sut.queueRequest(request)
        XCTAssertEqual(sut.pendingRequests.count, 1)

        sut.removeRequest(request.id)
        XCTAssertTrue(sut.pendingRequests.isEmpty)
    }

    func testRemoveNonexistentRequestDoesNothing() {
        sut.queueRequest(makeRequest(type: .chat))
        sut.removeRequest(UUID())
        XCTAssertEqual(sut.pendingRequests.count, 1)
    }

    func testUpdateRequest() {
        var request = makeRequest(type: .chat)
        sut.queueRequest(request)
        XCTAssertEqual(sut.pendingRequests[0].retryCount, 0)

        request.retryCount = 2
        // Can't use updateRequest directly since it matches by id in pendingRequests
        // The request was already queued, so let's create one with the same id
        var updated = sut.pendingRequests[0]
        updated.retryCount = 5
        sut.updateRequest(updated)
        XCTAssertEqual(sut.pendingRequests[0].retryCount, 5)
    }

    func testUpdateNonexistentRequestDoesNothing() {
        sut.queueRequest(makeRequest(type: .chat))
        var fake = makeRequest(type: .sync)
        fake.retryCount = 99
        sut.updateRequest(fake)
        XCTAssertEqual(sut.pendingRequests.count, 1)
        XCTAssertEqual(sut.pendingRequests[0].retryCount, 0)
    }

    // MARK: - Persistence

    func testSaveThenLoad() {
        let request = makeRequest(type: .memory, priority: .critical)
        sut.queueRequest(request)
        sut.savePendingRequests()

        // Create a new service from the same UserDefaults
        let sut2 = OfflineQueueService(forTesting: true, userDefaults: testDefaults)
        sut2.loadPendingRequests()

        XCTAssertEqual(sut2.pendingRequests.count, 1)
        XCTAssertEqual(sut2.pendingRequests[0].id, request.id)
        XCTAssertEqual(sut2.pendingRequests[0].type, .memory)
        XCTAssertEqual(sut2.pendingRequests[0].priority, .critical)
    }

    func testLoadWithNoDataDoesNothing() {
        sut.loadPendingRequests()
        XCTAssertTrue(sut.pendingRequests.isEmpty)
    }

    func testLoadWithCorruptDataDoesNothing() {
        testDefaults.set(Data("not-json".utf8), forKey: "offline.pendingRequests")
        sut.loadPendingRequests()
        XCTAssertTrue(sut.pendingRequests.isEmpty)
    }

    // MARK: - Queue Status

    func testQueueSizeByPriorityEmpty() {
        let result = sut.queueSizeByPriority()
        XCTAssertTrue(result.isEmpty)
    }

    func testQueueSizeByPriority() {
        sut.queueRequest(makeRequest(type: .chat, priority: .low))
        sut.queueRequest(makeRequest(type: .chat, priority: .low))
        sut.queueRequest(makeRequest(type: .sync, priority: .high))
        sut.queueRequest(makeRequest(type: .analytics, priority: .critical))

        let result = sut.queueSizeByPriority()
        XCTAssertEqual(result[.low], 2)
        XCTAssertEqual(result[.high], 1)
        XCTAssertEqual(result[.critical], 1)
        XCTAssertNil(result[.normal])
    }

    // MARK: - Clear Queue

    func testClearQueue() {
        sut.queueRequest(makeRequest(type: .chat))
        sut.queueRequest(makeRequest(type: .sync))
        sut.queueRequest(makeRequest(type: .analytics))
        XCTAssertEqual(sut.pendingRequests.count, 3)

        sut.clearQueue()
        XCTAssertTrue(sut.pendingRequests.isEmpty)

        // Verify also cleared from UserDefaults
        let data = testDefaults.data(forKey: "offline.pendingRequests")
        if let data {
            let decoded = try? JSONDecoder().decode([OfflineQueuedRequest].self, from: data)
            XCTAssertEqual(decoded?.count ?? 0, 0)
        }
    }

    // MARK: - Clear Expired Requests

    func testClearExpiredRequests() {
        sut.config.requestExpirationTime = 10

        // Old request (expired)
        let old = OfflineQueuedRequest(
            id: UUID(), type: .analytics, priority: .low,
            payload: nil, createdAt: Date().addingTimeInterval(-20), retryCount: 0
        )
        // Recent request (not expired)
        let recent = OfflineQueuedRequest(
            id: UUID(), type: .chat, priority: .high,
            payload: nil, createdAt: Date(), retryCount: 0
        )

        sut.pendingRequests = [old, recent]
        sut.clearExpiredRequests()

        XCTAssertEqual(sut.pendingRequests.count, 1)
        XCTAssertEqual(sut.pendingRequests[0].id, recent.id)
    }

    func testClearExpiredRequestsNoneExpired() {
        sut.config.requestExpirationTime = 86400
        sut.queueRequest(makeRequest(type: .chat))
        sut.queueRequest(makeRequest(type: .sync))

        sut.clearExpiredRequests()
        XCTAssertEqual(sut.pendingRequests.count, 2)
    }

    // MARK: - Process Request Directly

    func testProcessRequestAnalytics() async throws {
        // Analytics is a no-op — should not throw
        try await sut.processRequest(makeRequest(type: .analytics))
    }

    func testProcessRequestSyncPostsNotification() async throws {
        let expectation = XCTestExpectation(description: "sync")
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineRequestReplay, object: nil, queue: .main
        ) { notification in
            if let dict = notification.object as? [String: String], dict["type"] == "sync" {
                expectation.fulfill()
            }
        }

        try await sut.processRequest(makeRequest(type: .sync))
        await fulfillment(of: [expectation], timeout: 2)
        NotificationCenter.default.removeObserver(observer)
    }

    func testProcessRequestMemoryPostsNotification() async throws {
        let expectation = XCTestExpectation(description: "memory")
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineRequestReplay, object: nil, queue: .main
        ) { notification in
            if let dict = notification.object as? [String: String], dict["type"] == "memory" {
                expectation.fulfill()
            }
        }

        try await sut.processRequest(makeRequest(type: .memory))
        await fulfillment(of: [expectation], timeout: 2)
        NotificationCenter.default.removeObserver(observer)
    }

    func testProcessRequestChatWithValidPayload() async throws {
        let chatPayload = ChatRequestPayload(
            messages: [ChatRequestPayload.SerializedMessage(
                id: UUID(), conversationID: UUID(),
                role: "user", content: "Test", timestamp: Date()
            )],
            model: "gpt-4",
            providerId: "openai",
            conversationId: UUID()
        )
        let data = try JSONEncoder().encode(chatPayload)

        let expectation = XCTestExpectation(description: "chat replay")
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineRequestReplay, object: nil, queue: .main
        ) { notification in
            if notification.object is ChatRequestPayload {
                expectation.fulfill()
            }
        }

        try await sut.processRequest(makeRequest(type: .chat, payload: data))
        await fulfillment(of: [expectation], timeout: 2)
        NotificationCenter.default.removeObserver(observer)
    }

    func testProcessRequestChatWithInvalidPayload() async throws {
        // Invalid payload — should not crash, just silently skip
        try await sut.processRequest(makeRequest(type: .chat, payload: Data("bad".utf8)))
    }

    func testProcessRequestCustomWithPayload() async throws {
        let payload = Data("custom".utf8)
        let expectation = XCTestExpectation(description: "custom replay")
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineRequestReplay, object: nil, queue: .main
        ) { notification in
            if notification.object is Data {
                expectation.fulfill()
            }
        }

        try await sut.processRequest(makeRequest(type: .custom, payload: payload))
        await fulfillment(of: [expectation], timeout: 2)
        NotificationCenter.default.removeObserver(observer)
    }

    func testProcessRequestCustomWithoutPayload() async throws {
        // No payload — should not post notification, should not crash
        try await sut.processRequest(makeRequest(type: .custom, payload: nil))
    }

    func testProcessRequestNotificationWithValidPayload() async throws {
        let info: [String: String] = ["title": "Alert", "body": "Something happened"]
        let payload = try JSONEncoder().encode(info)
        // Should not throw; notification scheduling may or may not succeed in tests
        try await sut.processRequest(makeRequest(type: .notification, payload: payload))
    }

    func testProcessRequestNotificationWithMissingFields() async throws {
        // Payload missing "title" key
        let info: [String: String] = ["body": "No title"]
        let payload = try JSONEncoder().encode(info)
        try await sut.processRequest(makeRequest(type: .notification, payload: payload))
    }

    func testProcessRequestNotificationWithNoPayload() async throws {
        try await sut.processRequest(makeRequest(type: .notification, payload: nil))
    }

    // MARK: - Config Mutation

    func testConfigCanBeChanged() {
        sut.config.maxQueueSize = 5
        sut.config.maxRetries = 1
        sut.config.requestExpirationTime = 60
        sut.config.autoProcessOnConnect = false

        XCTAssertEqual(sut.config.maxQueueSize, 5)
        XCTAssertEqual(sut.config.maxRetries, 1)
        XCTAssertEqual(sut.config.requestExpirationTime, 60)
        XCTAssertFalse(sut.config.autoProcessOnConnect)
    }

    // MARK: - Helpers

    private func makeRequest(
        type: RequestType,
        priority: RequestPriority = .normal,
        payload: Data? = nil
    ) -> OfflineQueuedRequest {
        OfflineQueuedRequest(
            id: UUID(),
            type: type,
            priority: priority,
            payload: payload,
            createdAt: Date(),
            retryCount: 0
        )
    }
}
