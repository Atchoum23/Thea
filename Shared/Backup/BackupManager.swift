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

    private let logger = Logger(subsystem: "com.thea.app", category: "Backup")
    private let fileManager = FileManager.default

    // MARK: - Published State

    @Published public private(set) var isBackingUp = false
    @Published public private(set) var isRestoring = false
    @Published public private(set) var backupProgress: Double = 0
    @Published public private(set) var restoreProgress: Double = 0
    @Published public private(set) var availableBackups: [BackupInfo] = []
    @Published public private(set) var lastBackupDate: Date?
    @Published public private(set) var autoBackupEnabled = true

    // MARK: - Configuration

    private let backupDirectoryName = "Backups"
    private let maxBackupCount = 10
    private let autoBackupInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    // MARK: - Directories

    private var backupDirectory: URL {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if documents not available
            return FileManager.default.temporaryDirectory.appendingPathComponent(backupDirectoryName)
        }
        return documentsURL.appendingPathComponent(backupDirectoryName)
    }

    private var dataDirectory: URL {
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
                try? await Task.sleep(nanoseconds: UInt64(autoBackupInterval * 1_000_000_000))

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

        // Generate backup metadata
        let backupId = UUID().uuidString
        let timestamp = Date()
        let backupName = name ?? generateBackupName(type: type, date: timestamp)

        // Create temporary directory for backup contents
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(backupId)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        var includedItems: [BackupItem] = []
        var totalSize: Int64 = 0

        // Backup data categories
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

        // Create metadata
        let metadata = BackupMetadata(
            id: backupId,
            name: backupName,
            type: type,
            createdAt: timestamp,
            appVersion: getAppVersion(),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceName: getDeviceName(),
            items: includedItems,
            totalSize: totalSize
        )

        // Write metadata
        let metadataPath = tempDir.appendingPathComponent("metadata.json")
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataPath)

        // Compress backup
        backupProgress = 0.9
        let backupFileName = "\(backupId).theabackup"
        let backupPath = backupDirectory.appendingPathComponent(backupFileName)

        try await compressDirectory(tempDir, to: backupPath)

        // Update state
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

        // Clean up old backups
        await cleanupOldBackups()

        logger.info("Backup created: \(backupName) (\(backupInfo.size) bytes)")

        return backupInfo
    }

    // MARK: - Restore Backup

    /// Restore from a backup
    public func restoreBackup(_ backup: BackupInfo, options: RestoreOptions = .all) async throws {
        guard !isRestoring else {
            throw BackupError.restoreInProgress
        }

        isRestoring = true
        restoreProgress = 0

        defer {
            isRestoring = false
            restoreProgress = 1.0
        }

        logger.info("Starting restore from: \(backup.name)")

        // Create temporary directory for extraction
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Decompress backup
        restoreProgress = 0.1
        try await decompressArchive(backup.path, to: tempDir)

        // Verify metadata
        restoreProgress = 0.2
        let metadataPath = tempDir.appendingPathComponent("metadata.json")
        let metadataData = try Data(contentsOf: metadataPath)
        let metadata = try JSONDecoder().decode(BackupMetadata.self, from: metadataData)

        // Verify compatibility
        guard isCompatible(metadata: metadata) else {
            throw BackupError.incompatibleVersion(metadata.appVersion)
        }

        // Backup current data before restore (safety measure)
        if options.contains(.createSafetyBackup) {
            restoreProgress = 0.3
            _ = try? await createBackup(type: .preRestore, name: "Pre-restore safety backup")
        }

        // Restore data categories
        let categories: [String] = [
            "conversations",
            "agents",
            "artifacts",
            "memories",
            "settings",
            "preferences",
            "tools",
            "templates"
        ]

        for (index, category) in categories.enumerated() {
            restoreProgress = 0.4 + (Double(index) / Double(categories.count) * 0.4)

            // Check if this category should be restored
            guard shouldRestore(category: category, options: options) else {
                continue
            }

            let sourcePath = tempDir.appendingPathComponent(category)
            guard fileManager.fileExists(atPath: sourcePath.path) else {
                continue
            }

            let destPath = dataDirectory.appendingPathComponent(category.capitalized)

            // Remove existing data
            if options.contains(.overwrite), fileManager.fileExists(atPath: destPath.path) {
                try fileManager.removeItem(at: destPath)
            }

            // Copy restored data
            if !fileManager.fileExists(atPath: destPath.path) {
                try fileManager.copyItem(at: sourcePath, to: destPath)
                logger.debug("Restored \(category)")
            }
        }

        // Restore UserDefaults
        if options.contains(.settings) {
            restoreProgress = 0.85
            let userDefaultsPath = tempDir.appendingPathComponent("userDefaults.plist")
            if fileManager.fileExists(atPath: userDefaultsPath.path) {
                try restoreUserDefaults(from: userDefaultsPath)
            }
        }

        restoreProgress = 0.95

        // Notify app to reload data
        NotificationCenter.default.post(name: .backupRestoreCompleted, object: nil)

        logger.info("Restore completed from: \(backup.name)")
    }

    private func shouldRestore(category: String, options: RestoreOptions) -> Bool {
        switch category {
        case "conversations": options.contains(.conversations)
        case "agents": options.contains(.agents)
        case "artifacts": options.contains(.artifacts)
        case "memories": options.contains(.memories)
        case "settings", "preferences": options.contains(.settings)
        case "tools": options.contains(.tools)
        case "templates": options.contains(.templates)
        default: false
        }
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

    // MARK: - Export/Import

    /// Export backup to external location
    public func exportBackup(_ backup: BackupInfo, to destination: URL) throws {
        try fileManager.copyItem(at: backup.path, to: destination)
        logger.info("Exported backup to: \(destination.path)")
    }

    /// Import backup from external location
    public func importBackup(from source: URL) throws -> BackupInfo {
        // Validate file
        guard source.pathExtension == "theabackup" else {
            throw BackupError.invalidBackupFile
        }

        // Extract metadata
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Decompress to read metadata
        Task {
            try await decompressArchive(source, to: tempDir)
        }

        // For now, just copy the file
        let fileName = source.lastPathComponent
        let destPath = backupDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destPath.path) {
            try fileManager.removeItem(at: destPath)
        }

        try fileManager.copyItem(at: source, to: destPath)

        // Create backup info
        let backupInfo = try BackupInfo(
            id: UUID().uuidString,
            name: source.deletingPathExtension().lastPathComponent,
            type: .imported,
            createdAt: Date(),
            size: fileManager.attributesOfItem(atPath: destPath.path)[.size] as? Int64 ?? 0,
            path: destPath
        )

        availableBackups.append(backupInfo)
        loadAvailableBackups()

        logger.info("Imported backup: \(backupInfo.name)")

        return backupInfo
    }

    // MARK: - Helpers

    private func loadAvailableBackups() {
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

    private func isCompatible(metadata _: BackupMetadata) -> Bool {
        // For now, accept all backups
        // In production, check version compatibility
        true
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

    private func restoreUserDefaults(from path: URL) throws {
        let data = try Data(contentsOf: path)
        guard let dict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return
        }

        let defaults = UserDefaults.standard
        for (key, value) in dict {
            defaults.set(value, forKey: key)
        }
    }

    // MARK: - Compression

    private func compressDirectory(_ source: URL, to destination: URL) async throws {
        // Create tar-like archive then compress with LZMA
        let archiveData = try createArchive(from: source)
        let compressedData = try compress(archiveData)
        try compressedData.write(to: destination)
    }

    private func decompressArchive(_ source: URL, to destination: URL) async throws {
        let compressedData = try Data(contentsOf: source)
        let archiveData = try decompress(compressedData)
        try extractArchive(archiveData, to: destination)
    }

    private func createArchive(from directory: URL) throws -> Data {
        // Simple archive format: JSON manifest + file contents
        var archive = ArchiveContainer(files: [])

        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            let relativePath = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")
            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if !isDirectory {
                let data = try Data(contentsOf: fileURL)
                archive.files.append(ArchivedFile(path: relativePath, data: data))
            }
        }

        return try JSONEncoder().encode(archive)
    }

    private func extractArchive(_ data: Data, to directory: URL) throws {
        let archive = try JSONDecoder().decode(ArchiveContainer.self, from: data)

        for file in archive.files {
            let filePath = directory.appendingPathComponent(file.path)
            let parentDir = filePath.deletingLastPathComponent()

            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try file.data.write(to: filePath)
        }
    }

    private func compress(_ data: Data) throws -> Data {
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        defer { destinationBuffer.deallocate() }

        let compressedSize = data.withUnsafeBytes { sourcePtr in
            compression_encode_buffer(
                destinationBuffer,
                data.count,
                sourcePtr.bindMemory(to: UInt8.self).baseAddress!,
                data.count,
                nil,
                COMPRESSION_LZMA
            )
        }

        guard compressedSize > 0 else {
            throw BackupError.compressionFailed
        }

        return Data(bytes: destinationBuffer, count: compressedSize)
    }

    private func decompress(_ data: Data) throws -> Data {
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count * 10) // Estimate
        defer { destinationBuffer.deallocate() }

        let decompressedSize = data.withUnsafeBytes { sourcePtr in
            compression_decode_buffer(
                destinationBuffer,
                data.count * 10,
                sourcePtr.bindMemory(to: UInt8.self).baseAddress!,
                data.count,
                nil,
                COMPRESSION_LZMA
            )
        }

        guard decompressedSize > 0 else {
            throw BackupError.decompressionFailed
        }

        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
}

// Supporting types are in BackupManagerTypes.swift
