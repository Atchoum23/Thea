// AnalyticsLogicTests.swift
// Tests for analytics business logic: success rates, feature aggregation,
// event trimming, session timeout, batch sync, user property increment, data retention.
// Companion to AnalyticsTypesTests.swift.

import Foundation
import XCTest

// MARK: - Mirror Types (needed for logic tests)

private struct AnalyticsEvent: Identifiable, Codable {
    var id = UUID()
    let name: String
    let properties: [String: String]
    let timestamp: Date

    init(name: String, properties: [String: String] = [:], timestamp: Date = Date()) {
        self.name = name
        self.properties = properties
        self.timestamp = timestamp
    }
}

private struct DailyMetrics: Codable {
    let date: Date
    var chatCount: Int = 0
    var successfulChats: Int = 0
    var tokensUsed: Int = 0
    var tasksCompleted: Int = 0
    var searchCount: Int = 0
    var autonomousActions: Int = 0
    var approvedActions: Int = 0
    var featureUsage: [String: Int] = [:]
    var tasksByType: [String: Int] = [:]
}

// MARK: - Helper functions (mirror UsageAnalyticsService logic)

private func calculateSuccessRate(metrics: [DailyMetrics]) -> Double {
    let totalChats = metrics.reduce(0) { $0 + $1.chatCount }
    let successfulChats = metrics.reduce(0) { $0 + $1.successfulChats }
    guard totalChats > 0 else { return 1.0 }
    return Double(successfulChats) / Double(totalChats)
}

private func aggregateFeatureUsage(metrics: [DailyMetrics]) -> [String: Int] {
    var aggregated: [String: Int] = [:]
    for metric in metrics {
        for (feature, count) in metric.featureUsage {
            aggregated[feature, default: 0] += count
        }
    }
    return aggregated
}

// MARK: - Success Rate Calculation Tests

final class SuccessRateCalculationTests: XCTestCase {

    func testPerfectRate() {
        let metrics = [makeDailyMetrics(chats: 10, successful: 10)]
        XCTAssertEqual(calculateSuccessRate(metrics: metrics), 1.0, accuracy: 0.001)
    }

    func testZeroRate() {
        let metrics = [makeDailyMetrics(chats: 10, successful: 0)]
        XCTAssertEqual(calculateSuccessRate(metrics: metrics), 0.0, accuracy: 0.001)
    }

    func testPartialRate() {
        let metrics = [makeDailyMetrics(chats: 100, successful: 75)]
        XCTAssertEqual(calculateSuccessRate(metrics: metrics), 0.75, accuracy: 0.001)
    }

    func testZeroChatsFallsBackTo1() {
        let metrics = [makeDailyMetrics(chats: 0, successful: 0)]
        XCTAssertEqual(calculateSuccessRate(metrics: metrics), 1.0)
    }

    func testMultipleDaysAggregation() {
        let metrics = [
            makeDailyMetrics(chats: 10, successful: 8),
            makeDailyMetrics(chats: 20, successful: 18),
            makeDailyMetrics(chats: 30, successful: 24)
        ]
        let rate = calculateSuccessRate(metrics: metrics)
        XCTAssertEqual(rate, 50.0 / 60.0, accuracy: 0.001)
    }

    func testEmptyMetrics() {
        let rate = calculateSuccessRate(metrics: [])
        XCTAssertEqual(rate, 1.0)
    }

    private func makeDailyMetrics(chats: Int, successful: Int) -> DailyMetrics {
        var m = DailyMetrics(date: Date())
        m.chatCount = chats
        m.successfulChats = successful
        return m
    }
}

// MARK: - Feature Usage Aggregation Tests

final class FeatureUsageAggregationTests: XCTestCase {

    func testSingleDay() {
        var m = DailyMetrics(date: Date())
        m.featureUsage = ["chat": 5, "search": 3]
        let result = aggregateFeatureUsage(metrics: [m])
        XCTAssertEqual(result["chat"], 5)
        XCTAssertEqual(result["search"], 3)
    }

    func testMultipleDays() {
        var m1 = DailyMetrics(date: Date())
        m1.featureUsage = ["chat": 5, "search": 3]
        var m2 = DailyMetrics(date: Date().addingTimeInterval(-86400))
        m2.featureUsage = ["chat": 10, "voice": 2]
        let result = aggregateFeatureUsage(metrics: [m1, m2])
        XCTAssertEqual(result["chat"], 15)
        XCTAssertEqual(result["search"], 3)
        XCTAssertEqual(result["voice"], 2)
    }

    func testEmptyMetrics() {
        let result = aggregateFeatureUsage(metrics: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testNoFeatureUsage() {
        let m = DailyMetrics(date: Date())
        let result = aggregateFeatureUsage(metrics: [m])
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - Event Trimming Logic Tests

final class EventTrimmingLogicTests: XCTestCase {

    func testTrimsWhenOverMax() {
        let maxEventsInMemory = 1000
        var events = (0..<1050).map { AnalyticsEvent(name: "e\($0)") }
        if events.count > maxEventsInMemory {
            events.removeFirst(events.count - maxEventsInMemory)
        }
        XCTAssertEqual(events.count, 1000)
        XCTAssertEqual(events.first?.name, "e50")
    }

    func testNoTrimWhenUnderMax() {
        let maxEventsInMemory = 1000
        var events = (0..<500).map { AnalyticsEvent(name: "e\($0)") }
        if events.count > maxEventsInMemory {
            events.removeFirst(events.count - maxEventsInMemory)
        }
        XCTAssertEqual(events.count, 500)
    }

    func testTrimAtExactMax() {
        let maxEventsInMemory = 1000
        var events = (0..<1000).map { AnalyticsEvent(name: "e\($0)") }
        if events.count > maxEventsInMemory {
            events.removeFirst(events.count - maxEventsInMemory)
        }
        XCTAssertEqual(events.count, 1000)
    }
}

// MARK: - Session Timeout Logic Tests

final class SessionTimeoutLogicTests: XCTestCase {

    func testSessionTimedOut() {
        let sessionTimeout: TimeInterval = 30 * 60
        let lastActivityTime = Date().addingTimeInterval(-31 * 60)
        let isTimedOut = Date().timeIntervalSince(lastActivityTime) > sessionTimeout
        XCTAssertTrue(isTimedOut)
    }

    func testSessionNotTimedOut() {
        let sessionTimeout: TimeInterval = 30 * 60
        let lastActivityTime = Date().addingTimeInterval(-10 * 60)
        let isTimedOut = Date().timeIntervalSince(lastActivityTime) > sessionTimeout
        XCTAssertFalse(isTimedOut)
    }

    func testSessionExactlyAtTimeout() {
        let sessionTimeout: TimeInterval = 30 * 60
        let lastActivityTime = Date().addingTimeInterval(-30 * 60)
        let interval = Date().timeIntervalSince(lastActivityTime)
        // At exact boundary, slight time drift means >= will be true
        XCTAssertTrue(interval >= sessionTimeout)
    }
}

// MARK: - Batch Sync Logic Tests

final class BatchSyncLogicTests: XCTestCase {

    func testBatchSizeLimitsSync() {
        let batchSize = 50
        let events = (0..<200).map { AnalyticsEvent(name: "e\($0)") }
        let eventsToSync = Array(events.prefix(batchSize))
        XCTAssertEqual(eventsToSync.count, 50)
    }

    func testBatchSizeWithFewerEvents() {
        let batchSize = 50
        let events = (0..<10).map { AnalyticsEvent(name: "e\($0)") }
        let eventsToSync = Array(events.prefix(batchSize))
        XCTAssertEqual(eventsToSync.count, 10)
    }

    func testBatchRemovalMatchesBatchSize() {
        let batchSize = 50
        var events = (0..<200).map { AnalyticsEvent(name: "e\($0)") }
        let removeCount = min(batchSize, events.count)
        events.removeFirst(removeCount)
        XCTAssertEqual(events.count, 150)
    }
}

// MARK: - User Property Increment Tests

final class UserPropertyIncrementTests: XCTestCase {

    func testIncrementFromZero() {
        var userProperties: [String: Any] = [:]
        let key = "feature_chat_count"
        let current = (userProperties[key] as? Int) ?? 0
        userProperties[key] = current + 1
        XCTAssertEqual(userProperties[key] as? Int, 1)
    }

    func testIncrementExisting() {
        var userProperties: [String: Any] = ["count": 5]
        let current = (userProperties["count"] as? Int) ?? 0
        userProperties["count"] = current + 3
        XCTAssertEqual(userProperties["count"] as? Int, 8)
    }

    func testIncrementNonIntFallsToZero() {
        var userProperties: [String: Any] = ["count": "not_a_number"]
        let current = (userProperties["count"] as? Int) ?? 0
        userProperties["count"] = current + 1
        XCTAssertEqual(userProperties["count"] as? Int, 1)
    }
}

// MARK: - Data Retention Tests

final class DataRetentionTests: XCTestCase {

    func testCutoffDate90Days() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let oldDate = Calendar.current.date(byAdding: .day, value: -91, to: Date())!
        let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertTrue(oldDate < cutoff)
        XCTAssertTrue(recentDate >= cutoff)
    }

    func testFilterOldMetrics() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        var dailyMetrics: [Date: DailyMetrics] = [:]
        let old = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let recent = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        dailyMetrics[old] = DailyMetrics(date: old)
        dailyMetrics[recent] = DailyMetrics(date: recent)
        dailyMetrics = dailyMetrics.filter { $0.key >= cutoff }
        XCTAssertEqual(dailyMetrics.count, 1)
        XCTAssertNotNil(dailyMetrics[recent])
    }
}
