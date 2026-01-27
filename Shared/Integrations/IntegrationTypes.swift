import Foundation
import SwiftUI

// MARK: - Core Protocols

/// Protocol for services that provide data from external sources
public protocol DataProvider: Actor, Sendable {
    associatedtype DataType: Sendable

    /// Fetch data for a specific date range
    func fetchData(for dateRange: DateInterval) async throws -> [DataType]

    /// Refresh all data
    func refreshData() async throws
}

/// Protocol for trackable data items
public protocol Trackable: Sendable {
    var id: UUID { get }
    var timestamp: Date { get }
    var source: DataSource { get }
}

// MARK: - Common Enums

/// Source of data tracking
public enum DataSource: String, Sendable, Codable {
    case automatic
    case manual
    case healthKit
    case thirdParty
    case imported
}

/// Priority levels for tasks and items
public enum Priority: Int, Sendable, Codable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    public static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }

    public var color: String {
        switch self {
        case .low: "#10B981" // Green
        case .medium: "#F59E0B" // Amber
        case .high: "#EF4444" // Red
        case .urgent: "#DC2626" // Dark red
        }
    }

    public var swiftUIColor: Color {
        Color(hex: color)
    }
}

/// Trend direction for metrics
public enum Trend: Sendable, Codable {
    case improving
    case stable
    case declining
    case unknown

    public var displayName: String {
        switch self {
        case .improving: "↗ Improving"
        case .stable: "→ Stable"
        case .declining: "↘ Declining"
        case .unknown: "? Unknown"
        }
    }

    public var iconName: String {
        switch self {
        case .improving: "arrow.up.right"
        case .stable: "arrow.right"
        case .declining: "arrow.down.right"
        case .unknown: "questionmark"
        }
    }

    public var color: String {
        switch self {
        case .improving: "#10B981" // Green
        case .stable: "#6B7280" // Gray
        case .declining: "#EF4444" // Red
        case .unknown: "#9CA3AF" // Light gray
        }
    }

    public var swiftUIColor: Color {
        Color(hex: color)
    }
}

// MARK: - Date Extensions

public extension Date {
    /// Start of the current day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of the current day
    var endOfDay: Date {
        (Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400))
            .addingTimeInterval(-1)
    }

    /// Start of the current week
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? calendar.startOfDay(for: self)
    }

    /// Start of the current month
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? calendar.startOfDay(for: self)
    }

    /// Get a date N days ago
    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? addingTimeInterval(Double(-days) * 86400)
    }

    /// Get a date N days from now
    func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? addingTimeInterval(Double(days) * 86400)
    }

    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is in the current week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Check if date is in the current month
    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
}

// MARK: - DateInterval Extensions

public extension DateInterval {
    /// Create a date interval for today
    static var today: DateInterval {
        let now = Date()
        return DateInterval(start: now.startOfDay, end: now.endOfDay)
    }

    /// Create a date interval for yesterday
    static var yesterday: DateInterval {
        let yesterday = Date().daysAgo(1)
        return DateInterval(start: yesterday.startOfDay, end: yesterday.endOfDay)
    }

    /// Create a date interval for the current week
    static var thisWeek: DateInterval {
        let now = Date()
        let start = now.startOfWeek
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86400)
        return DateInterval(start: start, end: end)
    }

    /// Create a date interval for the current month
    static var thisMonth: DateInterval {
        let now = Date()
        let start = now.startOfMonth
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start.addingTimeInterval(30 * 86400)
        return DateInterval(start: start, end: end)
    }

    /// Create a date interval for the last N days
    static func lastDays(_ count: Int) -> DateInterval {
        let now = Date()
        let start = now.daysAgo(count).startOfDay
        return DateInterval(start: start, end: now)
    }
}

// MARK: - Common Result Types

/// Result with success/failure and optional message
public struct OperationResult: Sendable, Codable {
    public let success: Bool
    public let message: String?
    public let timestamp: Date

    public init(success: Bool, message: String? = nil) {
        self.success = success
        self.message = message
        timestamp = Date()
    }

    public static var success: OperationResult {
        OperationResult(success: true)
    }

    public static func failure(_ message: String) -> OperationResult {
        OperationResult(success: false, message: message)
    }
}

/// Generic error for service integrations
public enum ServiceIntegrationError: Error, Sendable, LocalizedError {
    case authorizationDenied
    case dataNotAvailable
    case invalidConfiguration
    case networkError
    case serviceUnavailable
    case custom(String)

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            "Permission denied. Please grant access in Settings."
        case .dataNotAvailable:
            "Data is not available for the requested period."
        case .invalidConfiguration:
            "Invalid configuration. Please check your settings."
        case .networkError:
            "Network connection error. Please check your internet connection."
        case .serviceUnavailable:
            "Service is temporarily unavailable. Please try again later."
        case let .custom(message):
            message
        }
    }
}
