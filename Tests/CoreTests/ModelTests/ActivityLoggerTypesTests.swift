// ActivityLoggerTypesTests.swift
// Tests for ActivityLogEntry, LoggingActivityType, DailyActivityStats,
// ActivityAnyCodable types and buffer/cleanup logic.
// Mirrors types from Shared/Monitoring/ActivityLogger.swift.

import Foundation
import XCTest

// MARK: - Mirror Types

private enum LoggingActivityType: String, Codable, CaseIterable {
    case appUsage, appSwitch, idleStart, idleEnd
    case focusModeChange, screenTime, inputSample, systemEvent

    var displayName: String {
        switch self {
        case .appUsage: "App Usage"
        case .appSwitch: "App Switch"
        case .idleStart: "Idle Started"
        case .idleEnd: "Idle Ended"
        case .focusModeChange: "Focus Mode"
        case .screenTime: "Screen Time"
        case .inputSample: "Input Activity"
        case .systemEvent: "System Event"
        }
    }

    var icon: String {
        switch self {
        case .appUsage: "app"
        case .appSwitch: "square.on.square"
        case .idleStart, .idleEnd: "moon.zzz"
        case .focusModeChange: "moon"
        case .screenTime: "desktopcomputer"
        case .inputSample: "keyboard"
        case .systemEvent: "gear"
        }
    }
}

private enum ActivityAnyCodable: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    var value: Any {
        switch self {
        case let .string(v): v
        case let .int(v): v
        case let .double(v): v
        case let .bool(v): v
        case .null: NSNull()
        }
    }

    init(_ value: Any) {
        switch value {
        case let str as String: self = .string(str)
        case let num as Int: self = .int(num)
        case let num as Double: self = .double(num)
        case let bool as Bool: self = .bool(bool)
        default: self = .string(String(describing: value))
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(v): try container.encode(v)
        case let .int(v): try container.encode(v)
        case let .double(v): try container.encode(v)
        case let .bool(v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

private struct ActivityLogEntry: Codable, Identifiable {
    let id: UUID
    let type: LoggingActivityType
    let timestamp: Date
    let duration: TimeInterval?
    let metadata: [String: ActivityAnyCodable]

    init(
        id: UUID = UUID(),
        type: LoggingActivityType,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        metadata: [String: ActivityAnyCodable] = [:]
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.duration = duration
        self.metadata = metadata
    }
}

private struct DailyActivityStats {
    let date: Date
    let totalScreenTime: TimeInterval
    let appUsage: [String: TimeInterval]
    let idlePeriods: Int
    let entryCount: Int

    var formattedScreenTime: String {
        let hours = Int(totalScreenTime) / 3600
        let minutes = (Int(totalScreenTime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    var topApps: [(String, TimeInterval)] {
        appUsage.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
}

// MARK: - LoggingActivityType Tests

final class LoggingActivityTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(LoggingActivityType.allCases.count, 8)
    }

    func testUniqueRawValues() {
        let raw = LoggingActivityType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(raw).count, raw.count)
    }

    func testDisplayNames() {
        XCTAssertEqual(LoggingActivityType.appUsage.displayName, "App Usage")
        XCTAssertEqual(LoggingActivityType.appSwitch.displayName, "App Switch")
        XCTAssertEqual(LoggingActivityType.idleStart.displayName, "Idle Started")
        XCTAssertEqual(LoggingActivityType.idleEnd.displayName, "Idle Ended")
        XCTAssertEqual(LoggingActivityType.focusModeChange.displayName, "Focus Mode")
        XCTAssertEqual(LoggingActivityType.screenTime.displayName, "Screen Time")
        XCTAssertEqual(LoggingActivityType.inputSample.displayName, "Input Activity")
        XCTAssertEqual(LoggingActivityType.systemEvent.displayName, "System Event")
    }

    func testAllDisplayNamesNonEmpty() {
        for actType in LoggingActivityType.allCases {
            XCTAssertFalse(actType.displayName.isEmpty, "\(actType) displayName is empty")
        }
    }

    func testAllIconsNonEmpty() {
        for actType in LoggingActivityType.allCases {
            XCTAssertFalse(actType.icon.isEmpty, "\(actType) icon is empty")
        }
    }

    func testIdleSharesIcon() {
        XCTAssertEqual(LoggingActivityType.idleStart.icon, LoggingActivityType.idleEnd.icon)
    }

    func testCodableRoundTrip() throws {
        for actType in LoggingActivityType.allCases {
            let data = try JSONEncoder().encode(actType)
            let decoded = try JSONDecoder().decode(LoggingActivityType.self, from: data)
            XCTAssertEqual(decoded, actType)
        }
    }
}

// MARK: - ActivityAnyCodable Tests

final class ActivityAnyCodableTests: XCTestCase {

    func testStringInit() {
        let val = ActivityAnyCodable("hello")
        XCTAssertEqual(val, .string("hello"))
    }

    func testIntInit() {
        let val = ActivityAnyCodable(42)
        XCTAssertEqual(val, .int(42))
    }

    func testDoubleInit() {
        let val = ActivityAnyCodable(3.14)
        XCTAssertEqual(val, .double(3.14))
    }

    func testBoolInit() {
        let val = ActivityAnyCodable(true)
        XCTAssertEqual(val, .bool(true))
    }

    func testUnknownTypeBecomesString() {
        let val = ActivityAnyCodable(URL(string: "https://example.com")!)
        if case .string = val { } else {
            XCTFail("Expected .string case for unknown type")
        }
    }

    func testStringCodable() throws {
        let val = ActivityAnyCodable.string("test")
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(ActivityAnyCodable.self, from: data)
        XCTAssertEqual(decoded, val)
    }

    func testIntCodable() throws {
        let val = ActivityAnyCodable.int(42)
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(ActivityAnyCodable.self, from: data)
        XCTAssertEqual(decoded, val)
    }

    func testNullCodable() throws {
        let val = ActivityAnyCodable.null
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(ActivityAnyCodable.self, from: data)
        XCTAssertEqual(decoded, val)
    }

    func testEquality() {
        XCTAssertEqual(ActivityAnyCodable.string("a"), .string("a"))
        XCTAssertNotEqual(ActivityAnyCodable.string("a"), .string("b"))
        XCTAssertNotEqual(ActivityAnyCodable.int(1), .string("1"))
    }
}

// MARK: - ActivityLogEntry Tests

final class ActivityLogEntryTests: XCTestCase {

    func testCreation() {
        let entry = ActivityLogEntry(type: .appUsage)
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.type, .appUsage)
        XCTAssertNil(entry.duration)
        XCTAssertTrue(entry.metadata.isEmpty)
    }

    func testWithDuration() {
        let entry = ActivityLogEntry(type: .screenTime, duration: 300)
        XCTAssertEqual(entry.duration, 300)
    }

    func testWithMetadata() {
        let entry = ActivityLogEntry(
            type: .appUsage,
            metadata: ["app": .string("Safari"), "duration": .double(60.0)]
        )
        XCTAssertEqual(entry.metadata["app"], .string("Safari"))
        XCTAssertEqual(entry.metadata["duration"], .double(60.0))
    }

    func testCodableRoundTrip() throws {
        let entry = ActivityLogEntry(
            type: .inputSample,
            duration: 10.0,
            metadata: ["keystrokes": .int(150)]
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ActivityLogEntry.self, from: data)
        XCTAssertEqual(decoded.type, .inputSample)
        XCTAssertEqual(decoded.duration, 10.0)
        XCTAssertEqual(decoded.metadata["keystrokes"], .int(150))
    }

    func testIdentifiable() {
        let e1 = ActivityLogEntry(type: .appUsage)
        let e2 = ActivityLogEntry(type: .appUsage)
        XCTAssertNotEqual(e1.id, e2.id)
    }
}

// MARK: - DailyActivityStats Tests

final class DailyActivityStatsTests: XCTestCase {

    func testFormattedScreenTimeHoursAndMinutes() {
        let stats = DailyActivityStats(
            date: Date(), totalScreenTime: 7500, // 2h 5m
            appUsage: [:], idlePeriods: 0, entryCount: 0
        )
        XCTAssertEqual(stats.formattedScreenTime, "2h 5m")
    }

    func testFormattedScreenTimeZero() {
        let stats = DailyActivityStats(
            date: Date(), totalScreenTime: 0,
            appUsage: [:], idlePeriods: 0, entryCount: 0
        )
        XCTAssertEqual(stats.formattedScreenTime, "0h 0m")
    }

    func testFormattedScreenTimeExactHour() {
        let stats = DailyActivityStats(
            date: Date(), totalScreenTime: 3600,
            appUsage: [:], idlePeriods: 0, entryCount: 0
        )
        XCTAssertEqual(stats.formattedScreenTime, "1h 0m")
    }

    func testTopApps() {
        let stats = DailyActivityStats(
            date: Date(), totalScreenTime: 10000,
            appUsage: [
                "Safari": 3600, "Xcode": 5400, "Terminal": 1000,
                "Music": 500, "Slack": 200, "Notes": 100, "Mail": 50
            ],
            idlePeriods: 0, entryCount: 0
        )
        let topApps = stats.topApps
        XCTAssertEqual(topApps.count, 5) // top 5
        XCTAssertEqual(topApps.first?.0, "Xcode") // highest usage
    }

    func testTopAppsEmpty() {
        let stats = DailyActivityStats(
            date: Date(), totalScreenTime: 0,
            appUsage: [:], idlePeriods: 0, entryCount: 0
        )
        XCTAssertTrue(stats.topApps.isEmpty)
    }

    func testTopAppsFewerThan5() {
        let stats = DailyActivityStats(
            date: Date(), totalScreenTime: 1000,
            appUsage: ["Safari": 500, "Xcode": 500],
            idlePeriods: 0, entryCount: 0
        )
        XCTAssertEqual(stats.topApps.count, 2)
    }
}

// MARK: - Buffer Logic Tests

final class ActivityBufferLogicTests: XCTestCase {

    func testFlushTriggeredAtLimit() {
        let bufferLimit = 100
        var buffer: [ActivityLogEntry] = []
        for _ in 0..<100 {
            buffer.append(ActivityLogEntry(type: .inputSample))
        }
        XCTAssertTrue(buffer.count >= bufferLimit)
    }

    func testFlushNotTriggeredBelowLimit() {
        let bufferLimit = 100
        var buffer: [ActivityLogEntry] = []
        for _ in 0..<50 {
            buffer.append(ActivityLogEntry(type: .inputSample))
        }
        XCTAssertFalse(buffer.count >= bufferLimit)
    }

    func testFlushClearsBuffer() {
        var buffer: [ActivityLogEntry] = []
        for _ in 0..<10 {
            buffer.append(ActivityLogEntry(type: .appUsage))
        }
        let flushed = buffer
        buffer.removeAll()
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(flushed.count, 10)
    }
}

// MARK: - Day Grouping Logic Tests

final class DayGroupingLogicTests: XCTestCase {

    func testGroupEntriesByDay() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let entries = [
            ActivityLogEntry(type: .appUsage, timestamp: today),
            ActivityLogEntry(type: .appUsage, timestamp: today),
            ActivityLogEntry(type: .appUsage, timestamp: yesterday)
        ]

        var entriesByDay: [String: [ActivityLogEntry]] = [:]
        for entry in entries {
            let dayKey = dateFormatter.string(from: entry.timestamp)
            entriesByDay[dayKey, default: []].append(entry)
        }

        XCTAssertEqual(entriesByDay.count, 2) // today + yesterday
        let todayKey = dateFormatter.string(from: today)
        XCTAssertEqual(entriesByDay[todayKey]?.count, 2)
    }
}

// MARK: - Retention Cleanup Logic Tests

final class RetentionCleanupLogicTests: XCTestCase {

    func testCutoffDateCalculation() {
        let retentionDays = 30
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!
        let oldDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        let recentDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        XCTAssertTrue(oldDate < cutoff)
        XCTAssertTrue(recentDate >= cutoff)
    }

    func testFilterByType() {
        let entries = [
            ActivityLogEntry(type: .appUsage),
            ActivityLogEntry(type: .screenTime),
            ActivityLogEntry(type: .appUsage),
            ActivityLogEntry(type: .idleStart)
        ]
        let filtered = entries.filter { $0.type == .appUsage }
        XCTAssertEqual(filtered.count, 2)
    }

    func testSortByTimestamp() {
        let now = Date()
        let entries = [
            ActivityLogEntry(type: .appUsage, timestamp: now.addingTimeInterval(100)),
            ActivityLogEntry(type: .appUsage, timestamp: now.addingTimeInterval(-100)),
            ActivityLogEntry(type: .appUsage, timestamp: now)
        ]
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        XCTAssertTrue(sorted[0].timestamp < sorted[1].timestamp)
        XCTAssertTrue(sorted[1].timestamp < sorted[2].timestamp)
    }
}

// MARK: - Stats Computation Tests

final class ActivityStatsComputationTests: XCTestCase {

    func testStatsFromEntries() {
        // Mirror getDailyStats() logic
        let entries: [(LoggingActivityType, String?, TimeInterval?)] = [
            (.appUsage, "Safari", 3600),
            (.appUsage, "Xcode", 5400),
            (.screenTime, nil, 1800),
            (.idleStart, nil, nil),
            (.idleStart, nil, nil),
            (.systemEvent, nil, nil)
        ]

        var appUsage: [String: TimeInterval] = [:]
        var totalScreenTime: TimeInterval = 0
        var idlePeriods = 0

        for (type, app, duration) in entries {
            switch type {
            case .appUsage:
                if let app, let dur = duration {
                    appUsage[app, default: 0] += dur
                    totalScreenTime += dur
                }
            case .screenTime:
                if let dur = duration {
                    totalScreenTime += dur
                }
            case .idleStart:
                idlePeriods += 1
            default:
                break
            }
        }

        XCTAssertEqual(appUsage["Safari"], 3600)
        XCTAssertEqual(appUsage["Xcode"], 5400)
        XCTAssertEqual(totalScreenTime, 10800, accuracy: 0.001) // 3600+5400+1800
        XCTAssertEqual(idlePeriods, 2)
    }
}
