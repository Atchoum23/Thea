// AnalyticsTypesTests.swift
// Tests for AnalyticsEvent, AnalyticsExport, AnyCodable, AnalyticsTimer,
// DailyMetrics, ModelUsageStats, AnalyticsSessionStats, UsageInsight, UsageSummary.
// Mirrors types from Shared/Analytics/AnalyticsManager.swift and UsageAnalyticsService.swift.

import Foundation
import XCTest

// MARK: - Mirror Types

private struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unable to decode value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encode(String(describing: value))
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}

private struct AnalyticsEvent: Identifiable, Codable {
    var id = UUID()
    let name: String
    let properties: [String: AnyCodable]
    let timestamp: Date

    init(name: String, properties: [String: Any], timestamp: Date) {
        self.name = name
        self.properties = properties.mapValues { AnyCodable($0) }
        self.timestamp = timestamp
    }
}

private struct AnalyticsExport: Codable {
    let events: [AnalyticsEvent]
    let userProperties: [String: AnyCodable]
    let sessionProperties: [String: AnyCodable]
    let exportTime: Date

    init(
        events: [AnalyticsEvent], userProperties: [String: Any],
        sessionProperties: [String: Any], exportTime: Date
    ) {
        self.events = events
        self.userProperties = userProperties.mapValues { AnyCodable($0) }
        self.sessionProperties = sessionProperties.mapValues { AnyCodable($0) }
        self.exportTime = exportTime
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

private struct ModelUsageStats: Codable {
    let model: String
    var totalRequests: Int = 0
    var successfulRequests: Int = 0
    var totalTokensIn: Int = 0
    var totalTokensOut: Int = 0
    var totalLatencyMs: Int = 0

    var successRate: Double {
        guard totalRequests > 0 else { return 1.0 }
        return Double(successfulRequests) / Double(totalRequests)
    }

    var averageLatencyMs: Int {
        guard totalRequests > 0 else { return 0 }
        return totalLatencyMs / totalRequests
    }

    var averageTokens: Int {
        guard totalRequests > 0 else { return 0 }
        return (totalTokensIn + totalTokensOut) / totalRequests
    }
}

private struct AnalyticsSessionStats: Codable {
    var totalSessions: Int = 0
    var totalSessionTime: TimeInterval = 0
    var averageSessionDuration: TimeInterval = 0
}

private enum InsightType: String, Codable {
    case topFeatures, modelPerformance, usageTrend
    case autonomyStats, sessionStats, recommendation
}

// MARK: - Helper: success rate calculation (mirrors UsageAnalyticsService)

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

// MARK: - AnyCodable Tests

final class AnyCodableTests: XCTestCase {

    func testEncodeString() throws {
        let value = AnyCodable("hello")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? String, "hello")
    }

    func testEncodeInt() throws {
        let value = AnyCodable(42)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? Int, 42)
    }

    func testEncodeDouble() throws {
        let value = AnyCodable(3.14)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        let doubleValue = try XCTUnwrap(decoded.value as? Double)
        XCTAssertEqual(doubleValue, 3.14, accuracy: 0.001)
    }

    func testEncodeBool() throws {
        let value = AnyCodable(true)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? Bool, true)
    }

    func testEncodeNull() throws {
        let value = AnyCodable(NSNull())
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertTrue(decoded.value is NSNull)
    }

    func testEncodeArray() throws {
        let value = AnyCodable([1, 2, 3])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        let arr = decoded.value as? [Any]
        XCTAssertEqual(arr?.count, 3)
    }

    func testEncodeDictionary() throws {
        let value = AnyCodable(["key": "value"])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        let dict = decoded.value as? [String: Any]
        XCTAssertEqual(dict?["key"] as? String, "value")
    }

    func testEncodeUnknownTypeUsesDescription() throws {
        // Non-standard types fall back to String(describing:)
        let value = AnyCodable(Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertTrue(decoded.value is String)
    }
}

// MARK: - AnalyticsEvent Tests

final class AnalyticsEventTests: XCTestCase {

    func testCreation() {
        let event = AnalyticsEvent(name: "test_event", properties: ["key": "value"], timestamp: Date())
        XCTAssertEqual(event.name, "test_event")
        XCTAssertEqual(event.properties.count, 1)
        XCTAssertNotNil(event.id)
    }

    func testEmptyProperties() {
        let event = AnalyticsEvent(name: "empty", properties: [:], timestamp: Date())
        XCTAssertTrue(event.properties.isEmpty)
    }

    func testMultiplePropertyTypes() {
        let event = AnalyticsEvent(name: "mixed", properties: [
            "string": "hello",
            "number": 42,
            "bool": true,
            "double": 3.14
        ], timestamp: Date())
        XCTAssertEqual(event.properties.count, 4)
    }

    func testCodableRoundTrip() throws {
        let event = AnalyticsEvent(name: "test", properties: ["key": "value"], timestamp: Date())
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(AnalyticsEvent.self, from: data)
        XCTAssertEqual(decoded.name, "test")
        XCTAssertEqual(decoded.properties.count, 1)
    }

    func testIdentifiable() {
        let event1 = AnalyticsEvent(name: "a", properties: [:], timestamp: Date())
        let event2 = AnalyticsEvent(name: "a", properties: [:], timestamp: Date())
        XCTAssertNotEqual(event1.id, event2.id)
    }

    func testPropertyMergePreservesExisting() {
        // Mirrors: eventProperties.merge(sessionProperties) { current, _ in current }
        var eventProps: [String: Any] = ["user_key": "user_value"]
        let sessionProps: [String: Any] = ["session_id": "abc", "user_key": "session_value"]
        eventProps.merge(sessionProps) { current, _ in current }
        XCTAssertEqual(eventProps["user_key"] as? String, "user_value") // kept user's
        XCTAssertEqual(eventProps["session_id"] as? String, "abc") // added session's
    }
}

// MARK: - AnalyticsExport Tests

final class AnalyticsExportTests: XCTestCase {

    func testCreation() {
        let events = [
            AnalyticsEvent(name: "e1", properties: [:], timestamp: Date()),
            AnalyticsEvent(name: "e2", properties: [:], timestamp: Date())
        ]
        let export = AnalyticsExport(
            events: events,
            userProperties: ["user": "value"],
            sessionProperties: ["session": "value"],
            exportTime: Date()
        )
        XCTAssertEqual(export.events.count, 2)
        XCTAssertEqual(export.userProperties.count, 1)
        XCTAssertEqual(export.sessionProperties.count, 1)
    }

    func testCodableRoundTrip() throws {
        let export = AnalyticsExport(
            events: [AnalyticsEvent(name: "test", properties: ["k": "v"], timestamp: Date())],
            userProperties: ["prop": 42],
            sessionProperties: ["sid": "abc"],
            exportTime: Date()
        )
        let data = try JSONEncoder().encode(export)
        let decoded = try JSONDecoder().decode(AnalyticsExport.self, from: data)
        XCTAssertEqual(decoded.events.count, 1)
        XCTAssertEqual(decoded.events.first?.name, "test")
    }

    func testEmptyExport() throws {
        let export = AnalyticsExport(
            events: [], userProperties: [:], sessionProperties: [:], exportTime: Date()
        )
        let data = try JSONEncoder().encode(export)
        let decoded = try JSONDecoder().decode(AnalyticsExport.self, from: data)
        XCTAssertTrue(decoded.events.isEmpty)
    }
}

// MARK: - DailyMetrics Tests

final class DailyMetricsTests: XCTestCase {

    func testDefaults() {
        let metrics = DailyMetrics(date: Date())
        XCTAssertEqual(metrics.chatCount, 0)
        XCTAssertEqual(metrics.successfulChats, 0)
        XCTAssertEqual(metrics.tokensUsed, 0)
        XCTAssertEqual(metrics.tasksCompleted, 0)
        XCTAssertEqual(metrics.searchCount, 0)
        XCTAssertEqual(metrics.autonomousActions, 0)
        XCTAssertEqual(metrics.approvedActions, 0)
        XCTAssertTrue(metrics.featureUsage.isEmpty)
        XCTAssertTrue(metrics.tasksByType.isEmpty)
    }

    func testMutation() {
        var metrics = DailyMetrics(date: Date())
        metrics.chatCount = 10
        metrics.successfulChats = 8
        metrics.tokensUsed = 5000
        metrics.tasksCompleted = 3
        metrics.searchCount = 2
        metrics.featureUsage["chat"] = 10
        metrics.tasksByType["coding"] = 3
        XCTAssertEqual(metrics.chatCount, 10)
        XCTAssertEqual(metrics.successfulChats, 8)
        XCTAssertEqual(metrics.tokensUsed, 5000)
        XCTAssertEqual(metrics.featureUsage["chat"], 10)
    }

    func testCodableRoundTrip() throws {
        var metrics = DailyMetrics(date: Date())
        metrics.chatCount = 5
        metrics.featureUsage["search"] = 3
        metrics.tasksByType["research"] = 2
        let data = try JSONEncoder().encode(metrics)
        let decoded = try JSONDecoder().decode(DailyMetrics.self, from: data)
        XCTAssertEqual(decoded.chatCount, 5)
        XCTAssertEqual(decoded.featureUsage["search"], 3)
        XCTAssertEqual(decoded.tasksByType["research"], 2)
    }

    func testApprovalRate() {
        var metrics = DailyMetrics(date: Date())
        metrics.autonomousActions = 100
        metrics.approvedActions = 75
        let rate = Double(metrics.approvedActions) / Double(metrics.autonomousActions) * 100
        XCTAssertEqual(rate, 75.0, accuracy: 0.001)
    }

    func testApprovalRateZeroDivision() {
        let metrics = DailyMetrics(date: Date())
        // With 0 autonomousActions, callers should check > 0 before dividing
        XCTAssertEqual(metrics.autonomousActions, 0)
    }
}

// MARK: - ModelUsageStats Tests

final class ModelUsageStatsTests: XCTestCase {

    func testDefaults() {
        let stats = ModelUsageStats(model: "claude-opus-4-5-20250120")
        XCTAssertEqual(stats.model, "claude-opus-4-5-20250120")
        XCTAssertEqual(stats.totalRequests, 0)
        XCTAssertEqual(stats.successfulRequests, 0)
        XCTAssertEqual(stats.totalTokensIn, 0)
        XCTAssertEqual(stats.totalTokensOut, 0)
        XCTAssertEqual(stats.totalLatencyMs, 0)
    }

    func testSuccessRate() {
        var stats = ModelUsageStats(model: "gpt-4o")
        stats.totalRequests = 100
        stats.successfulRequests = 95
        XCTAssertEqual(stats.successRate, 0.95, accuracy: 0.001)
    }

    func testSuccessRateZeroRequests() {
        let stats = ModelUsageStats(model: "test")
        XCTAssertEqual(stats.successRate, 1.0) // Default to 100%
    }

    func testSuccessRateAllFailed() {
        var stats = ModelUsageStats(model: "test")
        stats.totalRequests = 10
        stats.successfulRequests = 0
        XCTAssertEqual(stats.successRate, 0.0, accuracy: 0.001)
    }

    func testAverageLatency() {
        var stats = ModelUsageStats(model: "test")
        stats.totalRequests = 4
        stats.totalLatencyMs = 1000
        XCTAssertEqual(stats.averageLatencyMs, 250)
    }

    func testAverageLatencyZeroRequests() {
        let stats = ModelUsageStats(model: "test")
        XCTAssertEqual(stats.averageLatencyMs, 0)
    }

    func testAverageTokens() {
        var stats = ModelUsageStats(model: "test")
        stats.totalRequests = 5
        stats.totalTokensIn = 500
        stats.totalTokensOut = 1000
        XCTAssertEqual(stats.averageTokens, 300) // (500+1000)/5
    }

    func testAverageTokensZeroRequests() {
        let stats = ModelUsageStats(model: "test")
        XCTAssertEqual(stats.averageTokens, 0)
    }

    func testCodableRoundTrip() throws {
        var stats = ModelUsageStats(model: "claude-4")
        stats.totalRequests = 50
        stats.successfulRequests = 48
        stats.totalTokensIn = 10000
        stats.totalTokensOut = 15000
        stats.totalLatencyMs = 25000
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(ModelUsageStats.self, from: data)
        XCTAssertEqual(decoded.model, "claude-4")
        XCTAssertEqual(decoded.totalRequests, 50)
        XCTAssertEqual(decoded.successRate, 0.96, accuracy: 0.001)
    }

    func testModelAccumulation() {
        var stats = ModelUsageStats(model: "test")
        // Simulate 3 requests
        for i in 1...3 {
            stats.totalRequests += 1
            stats.totalTokensIn += 100 * i
            stats.totalTokensOut += 200 * i
            stats.totalLatencyMs += 50 * i
            stats.successfulRequests += 1
        }
        XCTAssertEqual(stats.totalRequests, 3)
        XCTAssertEqual(stats.totalTokensIn, 600)  // 100+200+300
        XCTAssertEqual(stats.totalTokensOut, 1200) // 200+400+600
        XCTAssertEqual(stats.averageTokens, 600)   // 1800/3
        XCTAssertEqual(stats.averageLatencyMs, 100) // 300/3
    }
}

// MARK: - AnalyticsSessionStats Tests

final class AnalyticsSessionStatsTests: XCTestCase {

    func testDefaults() {
        let stats = AnalyticsSessionStats()
        XCTAssertEqual(stats.totalSessions, 0)
        XCTAssertEqual(stats.totalSessionTime, 0.0, accuracy: 0.001)
        XCTAssertEqual(stats.averageSessionDuration, 0.0, accuracy: 0.001)
    }

    func testSessionAccumulation() {
        var stats = AnalyticsSessionStats()
        // Session 1: 10 minutes
        stats.totalSessions += 1
        stats.totalSessionTime += 600
        stats.averageSessionDuration = stats.totalSessionTime / Double(stats.totalSessions)
        XCTAssertEqual(stats.averageSessionDuration, 600.0, accuracy: 0.001)

        // Session 2: 20 minutes
        stats.totalSessions += 1
        stats.totalSessionTime += 1200
        stats.averageSessionDuration = stats.totalSessionTime / Double(stats.totalSessions)
        XCTAssertEqual(stats.averageSessionDuration, 900.0, accuracy: 0.001) // (600+1200)/2
    }

    func testCodableRoundTrip() throws {
        var stats = AnalyticsSessionStats()
        stats.totalSessions = 10
        stats.totalSessionTime = 36000
        stats.averageSessionDuration = 3600
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(AnalyticsSessionStats.self, from: data)
        XCTAssertEqual(decoded.totalSessions, 10)
        XCTAssertEqual(decoded.totalSessionTime, 36000, accuracy: 0.001)
    }
}

// MARK: - InsightType Tests

final class InsightTypeTests: XCTestCase {

    func testAllCases() {
        let types: [InsightType] = [
            .topFeatures, .modelPerformance, .usageTrend,
            .autonomyStats, .sessionStats, .recommendation
        ]
        XCTAssertEqual(types.count, 6)
    }

    func testUniqueRawValues() {
        let types: [InsightType] = [
            .topFeatures, .modelPerformance, .usageTrend,
            .autonomyStats, .sessionStats, .recommendation
        ]
        let rawValues = types.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    func testCodableRoundTrip() throws {
        let type = InsightType.topFeatures
        let data = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(InsightType.self, from: data)
        XCTAssertEqual(decoded, type)
    }
}

// Logic tests (success rate, aggregation, trimming, timeout, etc.) in AnalyticsLogicTests.swift
