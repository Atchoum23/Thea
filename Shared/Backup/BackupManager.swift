// BackupManager.swift
// Comprehensive backup and restore system

import Combine
import Compression
import Foundation
import OSLog
#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Backup Manager

/// Manages app data backup and restoration
@MainActor
public final class BackupManager: ObservableObject {
    public static let shared = BackupManager()

    let logger = Logger(subsystem: "com.thea.app", category: "Backup")
    let fileManager = FileManager.default

    // MARK: - Published State

    @Published public private(set) var isBackingUp = false
    @Published public var isRestoring = false
    @Published public private(set) var backupProgress: Double = 0
    @Published public var restoreProgress: Double = 0
    @Published public var availableBackups: [BackupInfo] = []
    @Published public private(set) var lastBackupDate: Date?
    @Published public private(set) var autoBackupEnabled = true

    // MARK: - Configuration

    private let backupDirectoryName = "Backups"
    private let maxBackupCount = 10
    private let autoBackupInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    // MARK: - Directories

    var backupDirectory: URL {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if documents not available
            return FileManager.default.temporaryDirectory.appendingPathComponent(backupDirectoryName)
        }
        return documentsURL.appendingPathComponent(backupDirectoryName)
    }

    var dataDirectory: URL {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory
            return FileManager.default.temporaryDirectory
        }
        return appSupportURL
    }

    // MARK: - Initialization

    private init() {
        createBackupDirectoryIfNeeded()
        loadSettings()
        loadAvailableBackups()
        scheduleAutoBackup()
    }

    private func createBackupDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: backupDirectory.path) {
            try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        }
    }

    private func loadSettings() {
        autoBackupEnabled = UserDefaults.standard.bool(forKey: "backup.autoEnabled")
        if UserDefaults.standard.object(forKey: "backup.autoEnabled") == nil {
            autoBackupEnabled = true
        }
        lastBackupDate = UserDefaults.standard.object(forKey: "backup.lastDate") as? Date
    }

    // MARK: - Auto Backup

    private func scheduleAutoBackup() {
        guard autoBackupEnabled else { return }

        Task {
            while true {
                try? await Task.sleep(for: .seconds(autoBackupInterval))

                if autoBackupEnabled {
                    if let lastDate = lastBackupDate {
                        let timeSinceLastBackup = Date().timeIntervalSince(lastDate)
                        if timeSinceLastBackup >= autoBackupInterval {
                            _ = try? await createBackup(type: .automatic)
                        }
                    } else {
                        _ = try? await createBackup(type: .automatic)
                    }
                }
            }
        }
    }

    /// Enable or disable automatic backups
    public func setAutoBackupEnabled(_ enabled: Bool) {
        autoBackupEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "backup.autoEnabled")
    }

    // MARK: - Create Backup

    /// Create a new backup
    public func createBackup(type: BackupType = .manual, name: String? = nil) async throws -> BackupInfo {
        guard !isBackingUp else {
            throw BackupError.backupInProgress
        }

        isBackingUp = true
        backupProgress = 0

        defer {
            isBackingUp = false
            backupProgress = 1.0
        }

        logger.info("Starting backup (type: \(type.rawValue))")

        let backupId = UUID().uuidString
        let timestamp = Date()
        let backupName = name ?? generateBackupName(type: type, date: timestamp)

        // Create temporary directory for backup contents
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(backupId)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Backup data categories and user defaults
        let (includedItems, totalSize) = try backupDataCategories(to: tempDir)

        // Create metadata, compress, and finalize
        let backupInfo = try await finalizeBackup(
            id: backupId,
            name: backupName,
            type: type,
            timestamp: timestamp,
            tempDir: tempDir,
            items: includedItems,
            totalSize: totalSize
        )

        logger.info("Backup created: \(backupName) (\(backupInfo.size) bytes)")

        return backupInfo
    }

    // MARK: - Backup Data Categories

    private func backupDataCategories(to tempDir: URL) throws -> ([BackupItem], Int64) {
        var includedItems: [BackupItem] = []
        var totalSize: Int64 = 0

        let categories: [(name: String, path: String, priority: Int)] = [
            ("conversations", "Conversations", 1),
            ("agents", "Agents", 1),
            ("artifacts", "Artifacts", 2),
            ("memories", "Memories", 1),
            ("settings", "Settings", 1),
            ("preferences", "Preferences", 2),
            ("tools", "Tools", 3),
            ("templates", "Templates", 3)
        ]

        for (index, category) in categories.enumerated() {
            backupProgress = Double(index) / Double(categories.count) * 0.8

            let sourcePath = dataDirectory.appendingPathComponent(category.path)
            if fileManager.fileExists(atPath: sourcePath.path) {
                let destPath = tempDir.appendingPathComponent(category.name)

                do {
                    try fileManager.copyItem(at: sourcePath, to: destPath)

                    let size = try getDirectorySize(destPath)
                    totalSize += size

                    try includedItems.append(BackupItem(
                        name: category.name,
                        type: .directory,
                        size: size,
                        itemCount: countItems(in: destPath)
                    ))

                    logger.debug("Backed up \(category.name): \(size) bytes")
                } catch {
                    logger.warning("Failed to backup \(category.name): \(error.localizedDescription)")
                }
            }
        }

        // Backup UserDefaults
        backupProgress = 0.85
        let userDefaultsData = backupUserDefaults()
        let userDefaultsPath = tempDir.appendingPathComponent("userDefaults.plist")
        try userDefaultsData.write(to: userDefaultsPath)
        totalSize += Int64(userDefaultsData.count)
        includedItems.append(BackupItem(
            name: "userDefaults",
            type: .file,
            size: Int64(userDefaultsData.count),
            itemCount: 1
        ))

        return (includedItems, totalSize)
    }

    // MARK: - Finalize Backup

    private func finalizeBackup(
        id backupId: String,
        name backupName: String,
        type: BackupType,
        timestamp: Date,
        tempDir: URL,
        items: [BackupItem],
        totalSize: Int64
    ) async throws -> BackupInfo {
        let metadata = BackupMetadata(
            id: backupId,
            name: backupName,
            type: type,
            createdAt: timestamp,
            appVersion: getAppVersion(),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceName: getDeviceName(),
            items: items,
            totalSize: totalSize
        )

        let metadataPath = tempDir.appendingPathComponent("metadata.json")
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataPath)

        backupProgress = 0.9
        let backupFileName = "\(backupId).theabackup"
        let backupPath = backupDirectory.appendingPathComponent(backupFileName)

        try await compressDirectory(tempDir, to: backupPath)

        let backupInfo = try BackupInfo(
            id: backupId,
            name: backupName,
            type: type,
            createdAt: timestamp,
            size: fileManager.attributesOfItem(atPath: backupPath.path)[.size] as? Int64 ?? 0,
            path: backupPath
        )

        availableBackups.insert(backupInfo, at: 0)
        lastBackupDate = timestamp
        UserDefaults.standard.set(timestamp, forKey: "backup.lastDate")

        await cleanupOldBackups()

        return backupInfo
    }

    // MARK: - Delete Backup

    /// Delete a backup
    public func deleteBackup(_ backup: BackupInfo) throws {
        try fileManager.removeItem(at: backup.path)
        availableBackups.removeAll { $0.id == backup.id }
        logger.info("Deleted backup: \(backup.name)")
    }

    /// Delete all backups
    public func deleteAllBackups() throws {
        for backup in availableBackups {
            try? fileManager.removeItem(at: backup.path)
        }
        availableBackups.removeAll()
        logger.info("Deleted all backups")
    }

    // MARK: - Helpers

    func loadAvailableBackups() {
        guard let contents = try? fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return
        }

        availableBackups = contents
            .filter { $0.pathExtension == "theabackup" }
            .compactMap { url -> BackupInfo? in
                let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                let modDate = attributes?[.modificationDate] as? Date ?? Date()
                let size = attributes?[.size] as? Int64 ?? 0

                return BackupInfo(
                    id: url.deletingPathExtension().lastPathComponent,
                    name: url.deletingPathExtension().lastPathComponent,
                    type: .manual,
                    createdAt: modDate,
                    size: size,
                    path: url
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func generateBackupName(type: BackupType, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: date)
        return "\(type.rawValue)_\(dateString)"
    }

    private func cleanupOldBackups() async {
        // Keep only automatic backups within limit
        let autoBackups = availableBackups.filter { $0.type == .automatic }
        if autoBackups.count > maxBackupCount {
            let toDelete = autoBackups.suffix(from: maxBackupCount)
            for backup in toDelete {
                try? deleteBackup(backup)
            }
        }
    }

    private func getDirectorySize(_ url: URL) throws -> Int64 {
        var size: Int64 = 0
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            size += attributes[.size] as? Int64 ?? 0
        }

        return size
    }

    private func countItems(in url: URL) throws -> Int {
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        return contents.count
    }

    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private func getDeviceName() -> String {
        #if os(macOS)
            return Host.current().localizedName ?? "Mac"
        #else
            return UIDevice.current.name
        #endif
    }

    func isCompatible(metadata: BackupMetadata) -> Bool {
        // Check major version compatibility
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let currentMajor = currentVersion.split(separator: ".").first.flatMap { Int($0) } ?? 1
        let backupMajor = metadata.appVersion.split(separator: ".").first.flatMap { Int($0) } ?? 1

        // Accept same major version or one major version back
        guard abs(currentMajor - backupMajor) <= 1 else { return false }

        // Verify backup has valid items
        guard !metadata.items.isEmpty else { return false }

        return true
    }

    // MARK: - UserDefaults Backup

    private func backupUserDefaults() -> Data {
        let defaults = UserDefaults.standard
        let keys = [
            "thea.preferredLanguage",
            "thea.theme",
            "thea.aiProvider",
            "thea.model",
            "analytics.enabled",
            "backup.autoEnabled"
            // Add more keys as needed
        ]

        var dict: [String: Any] = [:]
        for key in keys {
            if let value = defaults.object(forKey: key) {
                dict[key] = value
            }
        }

        return (try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)) ?? Data()
    }

    func restoreUserDefaults(from path: URL) throws {
        let data = try Data(contentsOf: path)
        guard let dict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return
        }

        let defaults = UserDefaults.standard
        for (key, value) in dict {
            defaults.set(value, forKey: key)
        }
    }
}

// Supporting types are in BackupManagerTypes.swift
// Restore methods are in BackupManager+Restore.swift
// Export/Import methods are in BackupManager+ExportImport.swift
// Compression methods are in BackupManager+Compression.swift
