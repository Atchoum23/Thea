//
//  BackupManagerTypes.swift
//  Thea
//
//  Supporting types for BackupManager
//

import Foundation

// MARK: - Types

public struct BackupInfo: Identifiable {
    public let id: String
    public let name: String
    public let type: BackupType
    public let createdAt: Date
    public let size: Int64
    public let path: URL

    public var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

public enum BackupType: String, Codable {
    case manual
    case automatic
    case preRestore
    case imported
}

public struct BackupMetadata: Codable {
    public let id: String
    public let name: String
    public let type: BackupType
    public let createdAt: Date
    public let appVersion: String
    public let osVersion: String
    public let deviceName: String
    public let items: [BackupItem]
    public let totalSize: Int64
}

public struct BackupItem: Codable {
    public let name: String
    public let type: ItemType
    public let size: Int64
    public let itemCount: Int

    public enum ItemType: String, Codable {
        case file
        case directory
    }
}

public struct RestoreOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let conversations = RestoreOptions(rawValue: 1 << 0)
    public static let agents = RestoreOptions(rawValue: 1 << 1)
    public static let artifacts = RestoreOptions(rawValue: 1 << 2)
    public static let memories = RestoreOptions(rawValue: 1 << 3)
    public static let settings = RestoreOptions(rawValue: 1 << 4)
    public static let tools = RestoreOptions(rawValue: 1 << 5)
    public static let templates = RestoreOptions(rawValue: 1 << 6)
    public static let overwrite = RestoreOptions(rawValue: 1 << 7)
    public static let createSafetyBackup = RestoreOptions(rawValue: 1 << 8)

    public static let all: RestoreOptions = [.conversations, .agents, .artifacts, .memories, .settings, .tools, .templates, .overwrite, .createSafetyBackup]
    public static let dataOnly: RestoreOptions = [.conversations, .agents, .artifacts, .memories]
}

public enum BackupError: Error, LocalizedError {
    case backupInProgress
    case restoreInProgress
    case invalidBackupFile
    case incompatibleVersion(String)
    case compressionFailed
    case decompressionFailed
    case fileNotFound

    public var errorDescription: String? {
        switch self {
        case .backupInProgress: "A backup is already in progress"
        case .restoreInProgress: "A restore is already in progress"
        case .invalidBackupFile: "Invalid backup file"
        case let .incompatibleVersion(version): "Incompatible backup version: \(version)"
        case .compressionFailed: "Failed to compress backup"
        case .decompressionFailed: "Failed to decompress backup"
        case .fileNotFound: "Backup file not found"
        }
    }
}

// MARK: - Archive Types

struct ArchiveContainer: Codable {
    var files: [ArchivedFile]
}

struct ArchivedFile: Codable {
    let path: String
    let data: Data
}

// MARK: - Notifications

public extension Notification.Name {
    static let backupRestoreCompleted = Notification.Name("thea.backup.restoreCompleted")
}
