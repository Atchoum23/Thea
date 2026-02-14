// BackupSettingsViewSections.swift
// Supporting types for BackupSettingsView

import SwiftUI

// MARK: - Backup Configuration

struct BackupConfiguration: Equatable, Codable {
    // Backups
    var backups: [BackupSettingsEntry] = [
        BackupSettingsEntry(
            id: UUID(),
            name: "Weekly Backup",
            date: Date().addingTimeInterval(-86400 * 3),
            size: "45.2 MB",
            type: .full,
            location: .iCloud,
            isAutoBackup: true,
            isEncrypted: true,
            isVerified: true,
            checksum: "abc123def456",
            contents: [
                BackupSettingsContent(name: "Conversations", count: 23, icon: "bubble.left.and.bubble.right"),
                BackupSettingsContent(name: "Settings", count: 1, icon: "gearshape"),
                BackupSettingsContent(name: "Knowledge", count: 156, icon: "brain"),
                BackupSettingsContent(name: "Projects", count: 5, icon: "folder")
            ]
        ),
        BackupSettingsEntry(
            id: UUID(),
            name: "Before Update",
            date: Date().addingTimeInterval(-86400 * 10),
            size: "38.7 MB",
            type: .manual,
            location: .local,
            isAutoBackup: false,
            isEncrypted: false,
            isVerified: true,
            checksum: "xyz789ghi012",
            contents: [
                BackupSettingsContent(name: "Conversations", count: 18, icon: "bubble.left.and.bubble.right"),
                BackupSettingsContent(name: "Settings", count: 1, icon: "gearshape")
            ]
        )
    ]

    var totalBackupSize = "83.9 MB"

    // Auto backup
    var autoBackupEnabled = true
    var backupFrequency: BackupSettingsFrequency = .weekly
    var maxBackupsToKeep = 5
    var onlyBackupOnWiFi = true
    var onlyBackupWhenCharging = false
    var nextScheduledBackup: Date? = Date().addingTimeInterval(86400 * 4)

    // Contents
    var backupConversations = true
    var backupSettings = true
    var backupKnowledge = true
    var backupProjects = true
    var backupAttachments = false

    // Location
    var backupLocation: BackupSettingsLocation = .iCloud
    var encryptCloudBackups = true
    var localStorageUsed = "38.7 MB"
    var cloudStorageUsed = "45.2 MB"

    // Restore
    var restoreMode: BackupSettingsRestoreMode = .ask
    var verifyIntegrity = true
    var createSafetyBackup = true

    private static let storageKey = "com.thea.backupConfiguration"

    static func load() -> BackupConfiguration {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(BackupConfiguration.self, from: data)
        {
            return config
        }
        return BackupConfiguration()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Backup Entry

struct BackupSettingsEntry: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var date: Date
    var size: String
    var type: BackupSettingsType
    var location: BackupSettingsLocation
    var isAutoBackup: Bool
    var isEncrypted: Bool
    var isVerified: Bool
    var checksum: String?
    var contents: [BackupSettingsContent]
}

struct BackupSettingsContent: Equatable, Codable {
    var name: String
    var count: Int
    var icon: String
}

// MARK: - Backup Enums

enum BackupSettingsType: String, Codable {
    case full
    case incremental
    case manual

    var displayName: String {
        switch self {
        case .full: "Full Backup"
        case .incremental: "Incremental"
        case .manual: "Manual"
        }
    }
}

enum BackupSettingsFrequency: String, Codable {
    case daily
    case weekly
    case monthly
}

enum BackupSettingsLocation: String, Codable {
    case local
    case iCloud
    case both

    var displayName: String {
        switch self {
        case .local: "Local Storage"
        case .iCloud: "iCloud"
        case .both: "Local & iCloud"
        }
    }
}

enum BackupSettingsRestoreMode: String, Codable {
    case replace
    case merge
    case ask
}

// MARK: - Backup Detail Sheet & Actions Extension

extension BackupSettingsView {

    func backupDetailSheet(_ backup: BackupSettingsEntry) -> some View {
        NavigationStack {
            Form {
                backupInfoSection(backup)
                backupContentsSection(backup)
                backupVerificationSection(backup)
                backupActionsSection(backup)
            }
            .navigationTitle("Backup Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingBackupDetail = nil
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
    }

    @ViewBuilder
    private func backupInfoSection(_ backup: BackupSettingsEntry) -> some View {
        Section("Backup Information") {
            LabeledContent("Name", value: backup.name)
            LabeledContent("Date", value: backup.date, format: .dateTime)
            LabeledContent("Size", value: backup.size)
            LabeledContent("Type", value: backup.type.displayName)
            LabeledContent("Location", value: backup.location.displayName)

            if backup.isEncrypted {
                HStack {
                    Text("Encrypted")
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }

    @ViewBuilder
    private func backupContentsSection(_ backup: BackupSettingsEntry) -> some View {
        Section("Contents") {
            ForEach(backup.contents, id: \.name) { item in
                HStack {
                    Image(systemName: item.icon)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    Text(item.name)

                    Spacer()

                    Text("\(item.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item.name): \(item.count) items")
            }
        }
    }

    @ViewBuilder
    private func backupVerificationSection(_ backup: BackupSettingsEntry) -> some View {
        Section("Verification") {
            HStack {
                Text("Integrity Check")
                Spacer()
                if backup.isVerified {
                    Label("Passed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Not Verified", systemImage: "questionmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if let checksum = backup.checksum {
                LabeledContent("Checksum", value: String(checksum.prefix(16)) + "...")
            }
        }
    }

    @ViewBuilder
    private func backupActionsSection(_ backup: BackupSettingsEntry) -> some View {
        Section {
            Button {
                showingBackupDetail = nil
                selectedBackup = backup
                showingRestoreConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("Restore This Backup", systemImage: "arrow.counterclockwise")
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)

            Button(role: .destructive) {
                showingBackupDetail = nil
                selectedBackup = backup
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("Delete Backup", systemImage: "trash")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    func createBackup() {
        isCreatingBackup = true
        backupProgress = 0

        Task {
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    backupProgress = Double(i) / 10.0
                }
            }

            await MainActor.run {
                let newBackup = BackupSettingsEntry(
                    id: UUID(),
                    name: "Backup \(Date().formatted(date: .abbreviated, time: .shortened))",
                    date: Date(),
                    size: calculateEstimatedSize(),
                    type: .manual,
                    location: backupConfig.backupLocation,
                    isAutoBackup: false,
                    isEncrypted: backupConfig.encryptCloudBackups,
                    isVerified: true,
                    checksum: UUID().uuidString,
                    contents: [
                        BackupSettingsContent(name: "Conversations", count: 15, icon: "bubble.left.and.bubble.right"),
                        BackupSettingsContent(name: "Settings", count: 1, icon: "gearshape"),
                        BackupSettingsContent(name: "Knowledge", count: 42, icon: "brain")
                    ]
                )

                backupConfig.backups.insert(newBackup, at: 0)
                isCreatingBackup = false
            }
        }
    }

    func restoreFromBackup(_ _backup: BackupSettingsEntry) {
        isRestoringBackup = true
        restoreProgress = 0

        Task {
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 400_000_000)
                await MainActor.run {
                    restoreProgress = Double(i) / 10.0
                }
            }

            await MainActor.run {
                isRestoringBackup = false
            }
        }
    }

    func deleteBackup(_ backup: BackupSettingsEntry) {
        backupConfig.backups.removeAll { $0.id == backup.id }
    }

    func resetBackupSettings() {
        backupConfig = BackupConfiguration()
        backupConfig.save()
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    BackupSettingsView()
        .frame(width: 700, height: 900)
}
#else
#Preview {
    NavigationStack {
        BackupSettingsView()
            .navigationTitle("Backup")
    }
}
#endif
