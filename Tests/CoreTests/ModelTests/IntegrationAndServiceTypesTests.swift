// IntegrationAndServiceTypesTests.swift
// Tests for IntegrationTypes + common service types (standalone test doubles)

import Testing
import Foundation

// MARK: - Integration Type Test Doubles

private enum TestDataSource: String, Sendable, Codable, CaseIterable {
    case automatic, manual, healthKit, thirdParty, imported
}

private enum TestPriority: Int, Sendable, Codable, Comparable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    static func < (lhs: TestPriority, rhs: TestPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }

    var color: String {
        switch self {
        case .low: "#10B981"
        case .medium: "#F59E0B"
        case .high: "#EF4444"
        case .urgent: "#DC2626"
        }
    }
}

private enum TestTrend: String, Sendable, Codable, CaseIterable {
    case improving, stable, declining, unknown

    var displayName: String {
        switch self {
        case .improving: "↗ Improving"
        case .stable: "→ Stable"
        case .declining: "↘ Declining"
        case .unknown: "? Unknown"
        }
    }

    var iconName: String {
        switch self {
        case .improving: "arrow.up.right"
        case .stable: "arrow.right"
        case .declining: "arrow.down.right"
        case .unknown: "questionmark"
        }
    }

    var color: String {
        switch self {
        case .improving: "#10B981"
        case .stable: "#6B7280"
        case .declining: "#EF4444"
        case .unknown: "#9CA3AF"
        }
    }
}

private struct TestOperationResult: Sendable, Codable {
    let success: Bool
    let message: String?
    let timestamp: Date

    init(success: Bool, message: String? = nil) {
        self.success = success
        self.message = message
        self.timestamp = Date()
    }

    static var succeeded: TestOperationResult {
        TestOperationResult(success: true)
    }

    static func failure(_ message: String) -> TestOperationResult {
        TestOperationResult(success: false, message: message)
    }
}

private enum TestServiceIntegrationError: Error, Sendable {
    case authorizationDenied
    case dataNotAvailable
    case invalidConfiguration
    case networkError
    case serviceUnavailable
    case custom(String)

    var errorDescription: String {
        switch self {
        case .authorizationDenied: "Permission denied. Please grant access in Settings."
        case .dataNotAvailable: "Data is not available for the requested period."
        case .invalidConfiguration: "Invalid configuration. Please check your settings."
        case .networkError: "Network connection error. Please check your internet connection."
        case .serviceUnavailable: "Service is temporarily unavailable. Please try again later."
        case .custom(let message): message
        }
    }
}

// MARK: - DataSource Tests

@Suite("Data Source — Completeness")
struct DataSourceTests {
    @Test("All 5 data sources exist")
    func allCases() {
        #expect(TestDataSource.allCases.count == 5)
    }

    @Test("All sources have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestDataSource.allCases.map(\.rawValue))
        #expect(rawValues.count == 5)
    }

    @Test("DataSource is Codable")
    func codableRoundtrip() throws {
        for source in TestDataSource.allCases {
            let data = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(TestDataSource.self, from: data)
            #expect(decoded == source)
        }
    }
}

// MARK: - Priority Tests

@Suite("Priority — Ordering and Display")
struct PriorityTests {
    @Test("All 4 priorities exist")
    func allCases() {
        #expect(TestPriority.allCases.count == 4)
    }

    @Test("Priorities are ordered: low < medium < high < urgent")
    func ordering() {
        #expect(TestPriority.low < .medium)
        #expect(TestPriority.medium < .high)
        #expect(TestPriority.high < .urgent)
    }

    @Test("Low is not greater than urgent")
    func lowNotGreater() {
        #expect(!(TestPriority.low > .urgent))
    }

    @Test("Sorted priorities in ascending order")
    func sortedOrder() {
        let shuffled: [TestPriority] = [.urgent, .low, .high, .medium]
        let sorted = shuffled.sorted()
        #expect(sorted == [.low, .medium, .high, .urgent])
    }

    @Test("Display names are non-empty")
    func displayNames() {
        for priority in TestPriority.allCases {
            #expect(!priority.displayName.isEmpty)
        }
    }

    @Test("Low display name is 'Low'")
    func lowDisplay() {
        #expect(TestPriority.low.displayName == "Low")
    }

    @Test("Urgent display name is 'Urgent'")
    func urgentDisplay() {
        #expect(TestPriority.urgent.displayName == "Urgent")
    }

    @Test("All colors are hex format")
    func colorsHex() {
        for priority in TestPriority.allCases {
            #expect(priority.color.hasPrefix("#"))
            #expect(priority.color.count == 7)
        }
    }

    @Test("All priorities have unique colors")
    func uniqueColors() {
        let colors = Set(TestPriority.allCases.map(\.color))
        #expect(colors.count == 4)
    }

    @Test("Priority is Codable")
    func codableRoundtrip() throws {
        for priority in TestPriority.allCases {
            let data = try JSONEncoder().encode(priority)
            let decoded = try JSONDecoder().decode(TestPriority.self, from: data)
            #expect(decoded == priority)
        }
    }

    @Test("Raw values are 0, 1, 2, 3")
    func rawValues() {
        #expect(TestPriority.low.rawValue == 0)
        #expect(TestPriority.medium.rawValue == 1)
        #expect(TestPriority.high.rawValue == 2)
        #expect(TestPriority.urgent.rawValue == 3)
    }
}

// MARK: - Trend Tests

@Suite("Trend — Display Properties")
struct TrendTests {
    @Test("All 4 trends exist")
    func allCases() {
        #expect(TestTrend.allCases.count == 4)
    }

    @Test("Display names contain direction indicator")
    func displayNamesIndicator() {
        #expect(TestTrend.improving.displayName.contains("↗"))
        #expect(TestTrend.stable.displayName.contains("→"))
        #expect(TestTrend.declining.displayName.contains("↘"))
        #expect(TestTrend.unknown.displayName.contains("?"))
    }

    @Test("Icon names are SF Symbols")
    func iconNames() {
        #expect(TestTrend.improving.iconName == "arrow.up.right")
        #expect(TestTrend.stable.iconName == "arrow.right")
        #expect(TestTrend.declining.iconName == "arrow.down.right")
        #expect(TestTrend.unknown.iconName == "questionmark")
    }

    @Test("All icon names are unique")
    func uniqueIcons() {
        let icons = Set(TestTrend.allCases.map(\.iconName))
        #expect(icons.count == 4)
    }

    @Test("All colors are hex format")
    func colorsHex() {
        for trend in TestTrend.allCases {
            #expect(trend.color.hasPrefix("#"))
            #expect(trend.color.count == 7)
        }
    }

    @Test("Improving is green, declining is red")
    func semanticColors() {
        #expect(TestTrend.improving.color == "#10B981")
        #expect(TestTrend.declining.color == "#EF4444")
    }

    @Test("Trend is Codable")
    func codableRoundtrip() throws {
        for trend in TestTrend.allCases {
            let data = try JSONEncoder().encode(trend)
            let decoded = try JSONDecoder().decode(TestTrend.self, from: data)
            #expect(decoded == trend)
        }
    }
}

// MARK: - Operation Result Tests

@Suite("Operation Result — Success/Failure")
struct OperationResultTests {
    @Test("Success result")
    func success() {
        let result = TestOperationResult.succeeded
        #expect(result.success)
        #expect(result.message == nil)
    }

    @Test("Failure result with message")
    func failure() {
        let result = TestOperationResult.failure("Connection timeout")
        #expect(!result.success)
        #expect(result.message == "Connection timeout")
    }

    @Test("Result has timestamp")
    func hasTimestamp() {
        let before = Date()
        let result = TestOperationResult(success: true)
        let after = Date()
        #expect(result.timestamp >= before)
        #expect(result.timestamp <= after)
    }

    @Test("Custom message on success")
    func successWithMessage() {
        let result = TestOperationResult(success: true, message: "Synced 42 items")
        #expect(result.success)
        #expect(result.message == "Synced 42 items")
    }

    @Test("Result Codable roundtrip")
    func codableRoundtrip() throws {
        let result = TestOperationResult(success: false, message: "Error occurred")
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TestOperationResult.self, from: data)
        #expect(decoded.success == false)
        #expect(decoded.message == "Error occurred")
    }
}

// MARK: - Service Integration Error Tests

@Suite("Service Integration Error — Descriptions")
struct ServiceIntegrationErrorTests {
    @Test("All errors have non-empty descriptions")
    func nonEmptyDescriptions() {
        let errors: [TestServiceIntegrationError] = [
            .authorizationDenied, .dataNotAvailable, .invalidConfiguration,
            .networkError, .serviceUnavailable, .custom("Test error")
        ]
        for error in errors {
            #expect(!error.errorDescription.isEmpty)
        }
    }

    @Test("Authorization denied mentions Settings")
    func authDenied() {
        #expect(TestServiceIntegrationError.authorizationDenied.errorDescription.contains("Settings"))
    }

    @Test("Network error mentions internet")
    func networkError() {
        #expect(TestServiceIntegrationError.networkError.errorDescription.contains("internet"))
    }

    @Test("Custom error preserves message")
    func customError() {
        let error = TestServiceIntegrationError.custom("Custom failure message")
        #expect(error.errorDescription == "Custom failure message")
    }

    @Test("Service unavailable mentions 'try again'")
    func serviceUnavailable() {
        #expect(TestServiceIntegrationError.serviceUnavailable.errorDescription.contains("try again"))
    }
}

// MARK: - Date Utility Logic Tests (Pure Calendar)

@Suite("Date Utilities — Calendar Helpers")
struct DateUtilityTests {
    @Test("Calendar startOfDay returns midnight")
    func startOfDay() {
        let start = Calendar.current.startOfDay(for: Date())
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: start)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("Calendar isDateInToday for now returns true")
    func todayIsToday() {
        #expect(Calendar.current.isDateInToday(Date()))
    }

    @Test("Calendar isDateInToday for yesterday returns false")
    func yesterdayNotToday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(!Calendar.current.isDateInToday(yesterday))
    }

    @Test("Calendar isDateInYesterday for yesterday returns true")
    func yesterdayIsYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(Calendar.current.isDateInYesterday(yesterday))
    }

    @Test("Adding negative days gives earlier date")
    func daysAgo() {
        let now = Date()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        #expect(threeDaysAgo < now)
        let diff = now.timeIntervalSince(threeDaysAgo)
        #expect(abs(diff - 259200) < 3600) // Within 1 hour for DST
    }

    @Test("Adding positive days gives later date")
    func daysFromNow() {
        let now = Date()
        let later = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        #expect(later > now)
    }

    @Test("Start of month is day 1")
    func startOfMonth() {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        let start = Calendar.current.date(from: components)!
        let day = Calendar.current.component(.day, from: start)
        #expect(day == 1)
    }
}
