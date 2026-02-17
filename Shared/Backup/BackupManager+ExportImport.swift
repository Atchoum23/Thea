// BackupManager+ExportImport.swift
// Export and import methods for BackupManager

import Foundation

extension BackupManager {
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

        // Copy archive to backup directory
        let fileName = source.lastPathComponent
        let destPath = backupDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destPath.path) {
            try fileManager.removeItem(at: destPath)
        }
        try fileManager.copyItem(at: source, to: destPath)

        // Try to read metadata from the archive
        var backupName = source.deletingPathExtension().lastPathComponent
        var backupDate = Date()
        if let metadataURL = URL(string: tempDir.appendingPathComponent("metadata.json").path),
           FileManager.default.fileExists(atPath: metadataURL.path),
           let data = try? Data(contentsOf: metadataURL),
           let metadata = try? JSONDecoder().decode(BackupMetadata.self, from: data) {
            backupName = metadata.name
            backupDate = metadata.createdAt
            // Verify compatibility
            guard isCompatible(metadata: metadata) else {
                try? fileManager.removeItem(at: destPath)
                throw BackupError.incompatibleVersion(metadata.appVersion)
            }
        }

        let fileSize = (try? fileManager.attributesOfItem(atPath: destPath.path)[.size] as? Int64) ?? 0
        let backupInfo = BackupInfo(
            id: UUID().uuidString,
            name: backupName,
            type: .imported,
            createdAt: backupDate,
            size: fileSize,
            path: destPath
        )

        availableBackups.append(backupInfo)
        loadAvailableBackups()

        logger.info("Imported backup: \(backupInfo.name)")

        return backupInfo
    }
}
