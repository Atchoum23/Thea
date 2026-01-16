import Foundation
import SwiftUI

// MARK: - Number Formatting

extension Double {
    /// Formats the number with specified decimal places
    public func formatted(decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }

    /// Formats as percentage with specified decimal places
    public func formattedAsPercentage(decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f%%", self)
    }

    /// Rounds to specified decimal places
    public func rounded(toPlaces places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}

extension Int {
    /// Formats with thousands separators
    public var formattedWithSeparators: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Duration Formatting

public struct DurationFormatter {
    /// Formats minutes as "Xh Ym"
    public static func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours == 0 {
            return "\(mins)m"
        } else if mins == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(mins)m"
        }
    }

    /// Formats seconds as "Xm Ys"
    public static func formatSeconds(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60

        if minutes == 0 {
            return "\(secs)s"
        } else if secs == 0 {
            return "\(minutes)m"
        } else {
            return "\(minutes)m \(secs)s"
        }
    }

    /// Formats time interval as human-readable string
    public static func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours == 0 {
            return "\(minutes) min"
        } else if minutes == 0 {
            return "\(hours) hr"
        } else {
            return "\(hours) hr \(minutes) min"
        }
    }
}

// MARK: - Color Extensions

// MARK: - Statistical Utilities

public struct Statistics {
    /// Calculates the mean (average) of an array of doubles
    public static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Calculates the median of an array of doubles
    public static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let count = sorted.count

        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        } else {
            return sorted[count / 2]
        }
    }

    /// Calculates the standard deviation
    public static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }

        let avg = mean(values)
        let squaredDifferences = values.map { pow($0 - avg, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count - 1)

        return sqrt(variance)
    }

    /// Calculates the percentile (0-100) value from array
    public static func percentile(_ values: [Double], percentile: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        guard percentile >= 0 && percentile <= 100 else { return 0 }

        let sorted = values.sorted()
        let index = (percentile / 100.0) * Double(sorted.count - 1)
        let lowerIndex = Int(floor(index))
        let upperIndex = Int(ceil(index))

        if lowerIndex == upperIndex {
            return sorted[lowerIndex]
        }

        let weight = index - Double(lowerIndex)
        return sorted[lowerIndex] * (1 - weight) + sorted[upperIndex] * weight
    }

    /// Calculates min and max values
    public static func range(_ values: [Double]) -> (min: Double, max: Double) {
        guard !values.isEmpty else { return (0, 0) }
        return (values.min() ?? 0, values.max() ?? 0)
    }
}

// MARK: - Validation Utilities

public struct Validator {
    /// Validates email format
    public static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// Validates phone number (basic US format)
    public static func isValidPhone(_ phone: String) -> Bool {
        let phoneRegex = "^[0-9]{10}$|^\\([0-9]{3}\\) [0-9]{3}-[0-9]{4}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }

    /// Validates that a value is within a range
    public static func isInRange<T: Comparable>(_ value: T, min: T, max: T) -> Bool {
        value >= min && value <= max
    }

    /// Validates that a string is not empty or whitespace only
    public static func isNonEmpty(_ string: String) -> Bool {
        !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Data Export Utilities

public struct DataExporter {
    /// Exports data to CSV format
    public static func toCSV<T>(_ data: [T], headers: [String], rowMapper: (T) -> [String]) -> String {
        var csv = headers.joined(separator: ",") + "\n"

        for item in data {
            let row = rowMapper(item).map { field in
                // Escape commas and quotes
                if field.contains(",") || field.contains("\"") {
                    return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return field
            }
            csv += row.joined(separator: ",") + "\n"
        }

        return csv
    }

    /// Exports data to JSON format
    public static func toJSON<T: Encodable>(_ data: [T]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(data) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
}

// MARK: - Trend Analysis

public struct TrendAnalyzer {
    /// Analyzes trend direction from array of values
    public static func analyzeTrend(_ values: [Double]) -> Trend {
        guard values.count >= 2 else { return .unknown }

        let firstHalf = Array(values.prefix(values.count / 2))
        let secondHalf = Array(values.suffix(values.count / 2))

        let firstAvg = Statistics.mean(firstHalf)
        let secondAvg = Statistics.mean(secondHalf)

        let change = ((secondAvg - firstAvg) / firstAvg) * 100

        if change > 5 {
            return .improving
        } else if change < -5 {
            return .declining
        } else {
            return .stable
        }
    }

    /// Calculates percentage change between two values
    public static func percentageChange(from old: Double, to new: Double) -> Double {
        guard old != 0 else { return 0 }
        return ((new - old) / abs(old)) * 100
    }

    /// Detects anomalies using standard deviation
    public static func detectAnomalies(_ values: [Double], threshold: Double = 2.0) -> [Int] {
        guard values.count > 2 else { return [] }

        let mean = Statistics.mean(values)
        let stdDev = Statistics.standardDeviation(values)

        return values.enumerated().compactMap { index, value in
            let zScore = abs(value - mean) / stdDev
            return zScore > threshold ? index : nil
        }
    }
}


// MARK: - Notification Helpers

public struct NotificationHelper {
    /// Creates a notification content with standard formatting
    public static func createNotification(
        title: String,
        body: String,
        identifier: String,
        categoryIdentifier: String? = nil
    ) -> (title: String, body: String, identifier: String, categoryIdentifier: String?) {
        (title, body, identifier, categoryIdentifier)
    }

    /// Formats a reminder notification for health goals
    public static func formatGoalReminder(goalTitle: String, progress: Double) -> String {
        if progress >= 0.75 {
            return "You're almost there! \(Int((1.0 - progress) * 100))% left to complete '\(goalTitle)'"
        } else if progress >= 0.5 {
            return "Halfway to your goal '\(goalTitle)'! Keep going!"
        } else {
            return "Don't forget to work on '\(goalTitle)' today"
        }
    }
}

// MARK: - Caching Utilities

public actor CacheManager<Key: Hashable, Value> {
    private var cache: [Key: (value: Value, timestamp: Date)] = [:]
    private let maxAge: TimeInterval

    public init(maxAge: TimeInterval = 300) { // 5 minutes default
        self.maxAge = maxAge
    }

    public func get(_ key: Key) -> Value? {
        guard let cached = cache[key] else { return nil }

        // Check if expired
        if Date().timeIntervalSince(cached.timestamp) > maxAge {
            cache.removeValue(forKey: key)
            return nil
        }

        return cached.value
    }

    public func set(_ key: Key, value: Value) {
        cache[key] = (value, Date())
    }

    public func clear() {
        cache.removeAll()
    }

    public func clearExpired() {
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.timestamp) <= maxAge }
    }
}

// MARK: - Debounce Helper

public actor Debouncer {
    private var task: Task<Void, Never>?
    private let duration: TimeInterval

    public init(duration: TimeInterval = 0.3) {
        self.duration = duration
    }

    public func debounce(_ action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled {
                await action()
            }
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}
