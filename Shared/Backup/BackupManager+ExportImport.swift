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
}
