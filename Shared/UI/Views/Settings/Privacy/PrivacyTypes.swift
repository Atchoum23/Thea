//
//  PrivacyTypes.swift
//  Thea
//
//  Supporting types for Privacy Settings views
//  Extracted from PrivacySettingsView.swift for better code organization
//

import Foundation

// MARK: - Privacy Settings Configuration

struct PrivacySettingsConfiguration: Equatable, Codable {
    // Data Collection
    var crashReportsEnabled = true
    var usageStatisticsEnabled = false

    // Data Retention
    var retentionPeriod: PrivacyRetentionPeriod = .forever
    var autoDeleteEmptyConversations = false
    var deleteAttachmentsWithConversations = true
    var storageUsed = "127.3 MB"

    // Security
    var encryptionEnabled = true
    var biometricLockEnabled = false
    var lockTimeout: PrivacyLockTimeout = .immediately
    var hidePreviewsInNotifications = false
    var clearClipboardAfterPaste = false
    var secureKeyboard = false

    // Audit
    var auditLoggingEnabled = true
    var auditLogEntries: [PrivacyAuditLogEntry] = [
        PrivacyAuditLogEntry(id: UUID(), type: .login, description: "App opened", timestamp: Date().addingTimeInterval(-3600), details: nil),
        PrivacyAuditLogEntry(id: UUID(), type: .dataAccess, description: "Conversations accessed", timestamp: Date().addingTimeInterval(-7200), details: "5 conversations viewed"),
        PrivacyAuditLogEntry(id: UUID(), type: .settingsChange, description: "Settings modified", timestamp: Date().addingTimeInterval(-86400), details: "Privacy settings updated")
    ]

    // Export
    var exportFormat: PrivacyExportFormat = .json
    var exportConversations = true
    var exportSettings = true
    var exportKnowledge = true
    var exportProjects = true
    var includeEncryptionKey = false
    var includeAttachments = true
    var includeMetadata = true

    private static let storageKey = "com.thea.privacyConfiguration"

    static func load() -> PrivacySettingsConfiguration {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(PrivacySettingsConfiguration.self, from: data) // Safe: corrupt UserDefaults → return default configuration (fallback below)
        {
            return config
        }
        return PrivacySettingsConfiguration()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { // Safe: encode failure → settings not persisted this save; in-memory state intact
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Retention Period

enum PrivacyRetentionPeriod: String, Codable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case oneYear
    case forever
}

// MARK: - Lock Timeout

enum PrivacyLockTimeout: String, Codable {
    case immediately
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
}

// MARK: - Biometric Type

enum PrivacyBiometricType {
    case faceID
    case touchID
    case none

    var displayName: String {
        switch self {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .none: "Biometric"
        }
    }
}

// MARK: - Export Format

enum PrivacyExportFormat: String, Codable {
    case json
    case csv
    case encrypted
}

// MARK: - Audit Event Type

enum PrivacyAuditEventType: String, Codable {
    case dataAccess
    case dataExport
    case dataDelete
    case settingsChange
    case login
    case syncEvent
}

// MARK: - Audit Log Entry

struct PrivacyAuditLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let type: PrivacyAuditEventType
    let description: String
    let timestamp: Date
    let details: String?
}
