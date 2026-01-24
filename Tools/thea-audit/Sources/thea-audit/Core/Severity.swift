// Severity.swift
// Severity levels for security findings

import ArgumentParser
import Foundation

/// Severity level for a security finding
enum Severity: String, Codable, CaseIterable, Comparable, Sendable, ExpressibleByArgument {
    case critical
    case high
    case medium
    case low

    /// Numeric value for comparison (higher = more severe)
    var numericValue: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    /// Display color for terminal output
    var color: String {
        switch self {
        case .critical: return "\u{001B}[31m"  // Red
        case .high: return "\u{001B}[33m"       // Yellow
        case .medium: return "\u{001B}[34m"     // Blue
        case .low: return "\u{001B}[32m"        // Green
        }
    }

    /// Reset color
    static let resetColor = "\u{001B}[0m"

    /// Emoji indicator
    var emoji: String {
        switch self {
        case .critical: return "🔴"
        case .high: return "🟠"
        case .medium: return "🟡"
        case .low: return "🟢"
        }
    }

    /// CVSS-like score range
    var cvssRange: String {
        switch self {
        case .critical: return "9.0 - 10.0"
        case .high: return "7.0 - 8.9"
        case .medium: return "4.0 - 6.9"
        case .low: return "0.1 - 3.9"
        }
    }

    /// Description of severity level
    var severityDescription: String {
        switch self {
        case .critical:
            return "Immediate action required. Vulnerability can be exploited trivially with severe impact."
        case .high:
            return "High priority fix required. Significant security risk that should be addressed promptly."
        case .medium:
            return "Should be fixed in normal development cycle. Moderate security concern."
        case .low:
            return "Low priority. Minor security improvement or best practice recommendation."
        }
    }

    // MARK: - Comparable

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.numericValue < rhs.numericValue
    }
}

// MARK: - Severity Extensions

extension Severity {
    /// Check if this severity meets or exceeds a minimum threshold
    func meetsMinimum(_ minimum: Severity) -> Bool {
        self >= minimum
    }

    /// Markdown badge for this severity
    var markdownBadge: String {
        switch self {
        case .critical:
            return "![Critical](https://img.shields.io/badge/severity-critical-red)"
        case .high:
            return "![High](https://img.shields.io/badge/severity-high-orange)"
        case .medium:
            return "![Medium](https://img.shields.io/badge/severity-medium-yellow)"
        case .low:
            return "![Low](https://img.shields.io/badge/severity-low-green)"
        }
    }
}
