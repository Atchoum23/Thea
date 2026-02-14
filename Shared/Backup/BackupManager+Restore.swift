// BackupManager+Restore.swift
// Restore methods for BackupManager

import Foundation

extension BackupManager {
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
}
