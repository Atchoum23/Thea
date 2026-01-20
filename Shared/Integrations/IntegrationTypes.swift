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
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    public var color: String {
        switch self {
        case .low: return "#10B981"      // Green
        case .medium: return "#F59E0B"   // Amber
        case .high: return "#EF4444"     // Red
        case .urgent: return "#DC2626"   // Dark red
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
        case .improving: return "↗ Improving"
        case .stable: return "→ Stable"
        case .declining: return "↘ Declining"
        case .unknown: return "? Unknown"
        }
    }

    public var iconName: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        case .unknown: return "questionmark"
        }
    }

    public var color: String {
        switch self {
        case .improving: return "#10B981"  // Green
        case .stable: return "#6B7280"     // Gray
        case .declining: return "#EF4444"  // Red
        case .unknown: return "#9CA3AF"    // Light gray
        }
    }

    public var swiftUIColor: Color {
        Color(hex: color)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Start of the current day
    public var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of the current day
    public var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
            .addingTimeInterval(-1)
    }

    /// Start of the current week
    public var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components)!
    }

    /// Start of the current month
    public var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)!
    }

    /// Get a date N days ago
    public func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self)!
    }

    /// Get a date N days from now
    public func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self)!
    }

    /// Check if date is today
    public var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    public var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is in the current week
    public var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Check if date is in the current month
    public var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
}

// MARK: - DateInterval Extensions

extension DateInterval {
    /// Create a date interval for today
    public static var today: DateInterval {
        let now = Date()
        return DateInterval(start: now.startOfDay, end: now.endOfDay)
    }

    /// Create a date interval for yesterday
    public static var yesterday: DateInterval {
        let yesterday = Date().daysAgo(1)
        return DateInterval(start: yesterday.startOfDay, end: yesterday.endOfDay)
    }

    /// Create a date interval for the current week
    public static var thisWeek: DateInterval {
        let now = Date()
        let start = now.startOfWeek
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        return DateInterval(start: start, end: end)
    }

    /// Create a date interval for the current month
    public static var thisMonth: DateInterval {
        let now = Date()
        let start = now.startOfMonth
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }

    /// Create a date interval for the last N days
    public static func lastDays(_ count: Int) -> DateInterval {
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
        self.timestamp = Date()
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
            return "Permission denied. Please grant access in Settings."
        case .dataNotAvailable:
            return "Data is not available for the requested period."
        case .invalidConfiguration:
            return "Invalid configuration. Please check your settings."
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .serviceUnavailable:
            return "Service is temporarily unavailable. Please try again later."
        case .custom(let message):
            return message
        }
    }
}
