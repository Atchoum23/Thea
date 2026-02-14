// SettingsCommonTypes.swift
// Common types used across settings views to avoid duplication and conflicts
// This file consolidates types that were previously defined in multiple settings views

import Foundation
import SwiftUI

// MARK: - Common Enums

/// Frequency options used across multiple settings
public enum SettingsFrequency: String, Codable, CaseIterable, Sendable {
    case realtime = "Real-time"
    case fiveMinutes = "5 minutes"
    case fifteenMinutes = "15 minutes"
    case hourly = "Hourly"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case manual = "Manual"

    public var displayName: String { rawValue }
}

/// Retention period options
public enum SettingsRetentionPeriod: String, Codable, CaseIterable, Sendable {
    case sevenDays = "7 days"
    case thirtyDays = "30 days"
    case ninetyDays = "90 days"
    case oneYear = "1 year"
    case forever = "Forever"

    public var displayName: String { rawValue }

    public var days: Int? {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        case .oneYear: return 365
        case .forever: return nil
        }
    }
}

/// Lock timeout options for security
public enum SettingsLockTimeout: String, Codable, CaseIterable, Sendable {
    case immediately = "Immediately"
    case oneMinute = "1 minute"
    case fiveMinutes = "5 minutes"
    case fifteenMinutes = "15 minutes"
    case thirtyMinutes = "30 minutes"
    case never = "Never"

    public var displayName: String { rawValue }

    public var seconds: Int? {
        switch self {
        case .immediately: return 0
        case .oneMinute: return 60
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1800
        case .never: return nil
        }
    }
}

/// Export format options
public enum SettingsExportFormat: String, Codable, CaseIterable, Sendable {
    case json = "JSON"
    case csv = "CSV"
    case encrypted = "Encrypted Archive"
    case markdown = "Markdown"

    public var displayName: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .encrypted: return "theabackup"
        case .markdown: return "md"
        }
    }
}

/// Log level for debugging
public enum SettingsLogLevel: String, Codable, CaseIterable, Sendable {
    case none = "None"
    case error = "Errors Only"
    case warning = "Warnings"
    case info = "Info"
    case debug = "Debug"
    case verbose = "Verbose"

    public var displayName: String { rawValue }

    public var icon: String {
        switch self {
        case .none: return "xmark.circle"
        case .error: return "exclamationmark.triangle"
        case .warning: return "exclamationmark.circle"
        case .info: return "info.circle"
        case .debug: return "ladybug"
        case .verbose: return "text.alignleft"
        }
    }

    public var color: Color {
        switch self {
        case .none: return .secondary
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .debug: return .purple
        case .verbose: return .gray
        }
    }
}

/// Proxy type for network settings
public enum SettingsProxyType: String, Codable, CaseIterable, Sendable {
    case http = "HTTP"
    case https = "HTTPS"
    case socks5 = "SOCKS5"

    public var displayName: String { rawValue }
}

/// Conflict resolution strategy
public enum SettingsConflictStrategy: String, Codable, CaseIterable, Sendable {
    case keepLocal = "Keep Local"
    case keepCloud = "Keep Cloud"
    case askEveryTime = "Ask Every Time"
    case keepMostRecent = "Keep Most Recent"

    public var displayName: String { rawValue }
}

/// Restore mode for backups
public enum SettingsRestoreMode: String, Codable, CaseIterable, Sendable {
    case replace = "Replace All"
    case merge = "Merge"
    case ask = "Ask Each Time"

    public var displayName: String { rawValue }
}

/// Storage location options
public enum SettingsStorageLocation: String, Codable, CaseIterable, Sendable {
    case local = "Local Storage"
    case iCloud = "iCloud"
    case both = "Local & iCloud"

    public var displayName: String { rawValue }

    public var icon: String {
        switch self {
        case .local: return "internaldrive"
        case .iCloud: return "icloud"
        case .both: return "externaldrive.badge.icloud"
        }
    }
}

// MARK: - Common Structs

/// HTTP header for custom network requests
public struct SettingsHTTPHeader: Identifiable, Equatable, Codable, Sendable {
    public var id = UUID()
    public var key: String
    public var value: String

    public init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

/// Generic log entry for various logging features
public struct SettingsLogEntry: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let level: SettingsLogLevel
    public let message: String
    public let timestamp: Date
    public let source: String?

    public init(id: UUID = UUID(), level: SettingsLogLevel, message: String, timestamp: Date = Date(), source: String? = nil) {
        self.id = id
        self.level = level
        self.message = message
        self.timestamp = timestamp
        self.source = source
    }
}

/// Content item for backup entries
public struct SettingsBackupContent: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var count: Int
    public var icon: String

    public init(id: UUID = UUID(), name: String, count: Int, icon: String) {
        self.id = id
        self.name = name
        self.count = count
        self.icon = icon
    }
}

// MARK: - Settings Section Header

/// Reusable section header with info button
public struct SettingsSectionHeader: View {
    let title: String
    let systemImage: String?
    let helpText: String?

    @State private var showingHelp = false

    public init(_ title: String, systemImage: String? = nil, helpText: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.helpText = helpText
    }

    public var body: some View {
        HStack {
            if let systemImage = systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }

            if helpText != nil {
                Spacer()
                Button {
                    showingHelp = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Help")
                .popover(isPresented: $showingHelp) {
                    if let helpText = helpText {
                        Text(helpText)
                            .font(.caption)
                            .padding()
                            .frame(maxWidth: 300)
                    }
                }
            }
        }
    }
}

// MARK: - Settings Row Styles

/// Standard settings row with label and value
public struct SettingsLabeledRow<Content: View>: View {
    let label: String
    let content: Content

    public init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    public var body: some View {
        HStack {
            Text(label)
            Spacer()
            content
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Settings Info Row

/// Row showing a label and info value
public struct SettingsInfoRow: View {
    let label: String
    let value: String
    let icon: String?

    public init(_ label: String, value: String, icon: String? = nil) {
        self.label = label
        self.value = value
        self.icon = icon
    }

    public var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
            }
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
