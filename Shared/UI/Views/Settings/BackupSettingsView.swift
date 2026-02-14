// BackupSettingsView.swift
// Comprehensive backup and restore settings for Thea

import SwiftUI

struct BackupSettingsView: View {
    @State private var backupConfig = BackupConfiguration.load()
    @State private var showingBackupDetail: BackupSettingsEntry?
    @State private var showingRestoreConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedBackup: BackupSettingsEntry?
    @State private var isCreatingBackup = false
    @State private var isRestoringBackup = false
    @State private var backupProgress: Double = 0
    @State private var restoreProgress: Double = 0

    var body: some View {
        Form {
            // MARK: - Overview
            Section("Backup Overview") {
                backupOverview
            }

            // MARK: - Quick Actions
            Section("Quick Actions") {
                quickActionsSection
            }

            // MARK: - Available Backups
            Section("Available Backups") {
                availableBackupsSection
            }

            // MARK: - Auto Backup
            Section("Automatic Backup") {
                autoBackupSection
            }

            // MARK: - Backup Contents
            Section("Backup Contents") {
                backupContentsSection
            }

            // MARK: - Backup Location
            Section("Backup Location") {
                backupLocationSection
            }

            // MARK: - Restore Options
            Section("Restore Options") {
                restoreOptionsSection
            }

            // MARK: - Reset
            Section {
                Button("Reset Backup Settings", role: .destructive) {
                    resetBackupSettings()
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .onChange(of: backupConfig) { _, _ in
            backupConfig.save()
        }
        .sheet(item: $showingBackupDetail) { backup in
            backupDetailSheet(backup)
        }
        .alert("Restore from Backup?", isPresented: $showingRestoreConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                if let backup = selectedBackup {
                    restoreFromBackup(backup)
                }
            }
        } message: {
            Text("This will replace your current data with the backup. This action cannot be undone.")
        }
        .alert("Delete Backup?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let backup = selectedBackup {
                    deleteBackup(backup)
                }
            }
        } message: {
            Text("This backup will be permanently deleted.")
        }
    }

    // MARK: - Backup Overview

    private var backupOverview: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            HStack(spacing: 16) {
                overviewCard(
                    title: "Backups",
                    value: "\(backupConfig.backups.count)",
                    icon: "arrow.clockwise.icloud.fill",
                    color: .blue
                )

                overviewCard(
                    title: "Auto Backup",
                    value: backupConfig.autoBackupEnabled ? "On" : "Off",
                    icon: "clock.arrow.circlepath",
                    color: backupConfig.autoBackupEnabled ? .green : .secondary
                )

                overviewCard(
                    title: "Total Size",
                    value: backupConfig.totalBackupSize,
                    icon: "externaldrive.fill",
                    color: .purple
                )

                overviewCard(
                    title: "Last Backup",
                    value: lastBackupText,
                    icon: "calendar",
                    color: .orange
                )
            }
            #else
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                overviewCard(
                    title: "Backups",
                    value: "\(backupConfig.backups.count)",
                    icon: "arrow.clockwise.icloud.fill",
                    color: .blue
                )

                overviewCard(
                    title: "Auto Backup",
                    value: backupConfig.autoBackupEnabled ? "On" : "Off",
                    icon: "clock.arrow.circlepath",
                    color: backupConfig.autoBackupEnabled ? .green : .secondary
                )

                overviewCard(
                    title: "Total Size",
                    value: backupConfig.totalBackupSize,
                    icon: "externaldrive.fill",
                    color: .purple
                )

                overviewCard(
                    title: "Last Backup",
                    value: lastBackupText,
                    icon: "calendar",
                    color: .orange
                )
            }
            #endif
        }
    }

    private func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    private var lastBackupText: String {
        if let lastBackup = backupConfig.backups.first {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: lastBackup.date, relativeTo: Date())
        }
        return "Never"
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        Group {
            // Create Backup
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Backup")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Create a new backup of your data now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    createBackup()
                } label: {
                    if isCreatingBackup {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Backup Now", systemImage: "plus.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreatingBackup)
            }

            if isCreatingBackup {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: backupProgress)

                    Text("Creating backup... \(Int(backupProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Restore
            if !backupConfig.backups.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Restore")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Restore from most recent backup")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        if let latest = backupConfig.backups.first {
                            selectedBackup = latest
                            showingRestoreConfirmation = true
                        }
                    } label: {
                        Label("Restore", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRestoringBackup)
                }

                if isRestoringBackup {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: restoreProgress)

                        Text("Restoring... \(Int(restoreProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Available Backups Section

    private var availableBackupsSection: some View {
        Group {
            if backupConfig.backups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.icloud")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("No backups yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Create your first backup to protect your data")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(backupConfig.backups) { backup in
                    backupRow(backup)
                }
            }
        }
    }

    private func backupRow(_ backup: BackupSettingsEntry) -> some View {
        HStack(spacing: 12) {
            // Backup type icon
            Image(systemName: backupTypeIcon(backup.type))
                .font(.title2)
                .foregroundStyle(backupTypeColor(backup.type))
                .frame(width: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(backup.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if backup.isAutoBackup {
                        Text("Auto")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                }

                HStack {
                    Text(backup.date, style: .date)
                    Text(backup.date, style: .time)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(backup.size)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Actions
            Menu {
                Button {
                    showingBackupDetail = backup
                } label: {
                    Label("View Details", systemImage: "info.circle")
                }

                Button {
                    selectedBackup = backup
                    showingRestoreConfirmation = true
                } label: {
                    Label("Restore", systemImage: "arrow.counterclockwise")
                }

                Divider()

                Button(role: .destructive) {
                    selectedBackup = backup
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Backup actions for \(backup.name)")
        }
        .padding(.vertical, 4)
    }

    private func backupTypeIcon(_ type: BackupSettingsType) -> String {
        switch type {
        case .full: "arrow.clockwise.icloud.fill"
        case .incremental: "arrow.triangle.2.circlepath"
        case .manual: "hand.tap.fill"
        }
    }

    private func backupTypeColor(_ type: BackupSettingsType) -> Color {
        switch type {
        case .full: .blue
        case .incremental: .green
        case .manual: .orange
        }
    }

    // MARK: - Auto Backup Section

    private var autoBackupSection: some View {
        Group {
            Toggle("Enable Automatic Backup", isOn: $backupConfig.autoBackupEnabled)

            if backupConfig.autoBackupEnabled {
                Picker("Backup Frequency", selection: $backupConfig.backupFrequency) {
                    Text("Daily").tag(BackupSettingsFrequency.daily)
                    Text("Weekly").tag(BackupSettingsFrequency.weekly)
                    Text("Monthly").tag(BackupSettingsFrequency.monthly)
                }

                HStack {
                    Text("Keep Backups")
                    Spacer()
                    Stepper("\(backupConfig.maxBackupsToKeep)", value: $backupConfig.maxBackupsToKeep, in: 1 ... 30)
                }

                Text("Older backups will be automatically deleted")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Toggle("Only on Wi-Fi", isOn: $backupConfig.onlyBackupOnWiFi)

                Toggle("Only When Charging", isOn: $backupConfig.onlyBackupWhenCharging)

                if let nextBackup = backupConfig.nextScheduledBackup {
                    HStack {
                        Text("Next Backup")
                        Spacer()
                        Text(nextBackup, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Backup Contents Section

    private var backupContentsSection: some View {
        Group {
            Toggle("Conversations", isOn: $backupConfig.backupConversations)

            Toggle("Settings", isOn: $backupConfig.backupSettings)

            Toggle("Knowledge Base", isOn: $backupConfig.backupKnowledge)

            Toggle("Projects", isOn: $backupConfig.backupProjects)

            Toggle("Attachments", isOn: $backupConfig.backupAttachments)

            if backupConfig.backupAttachments {
                Text("Including attachments significantly increases backup size")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            // Estimated size
            HStack {
                Text("Estimated Backup Size")
                Spacer()
                Text(calculateEstimatedSize())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func calculateEstimatedSize() -> String {
        var size: Double = 0
        if backupConfig.backupConversations { size += 15 }
        if backupConfig.backupSettings { size += 0.5 }
        if backupConfig.backupKnowledge { size += 8 }
        if backupConfig.backupProjects { size += 5 }
        if backupConfig.backupAttachments { size += 50 }
        return String(format: "~%.1f MB", size)
    }

    // MARK: - Backup Location Section

    private var backupLocationSection: some View {
        Group {
            Picker("Backup Location", selection: $backupConfig.backupLocation) {
                Text("Local Storage").tag(BackupSettingsLocation.local)
                Text("iCloud").tag(BackupSettingsLocation.iCloud)
                Text("Both").tag(BackupSettingsLocation.both)
            }

            switch backupConfig.backupLocation {
            case .local:
                Text("Backups are stored on this device only")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .iCloud:
                Text("Backups are stored in iCloud and accessible from all devices")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .both:
                Text("Backups are stored both locally and in iCloud for maximum safety")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if backupConfig.backupLocation == .iCloud || backupConfig.backupLocation == .both {
                Toggle("Encrypt iCloud Backups", isOn: $backupConfig.encryptCloudBackups)

                Text("Encrypted backups require a password to restore")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Storage info
            VStack(alignment: .leading, spacing: 8) {
                Text("Storage Usage")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text("Local Backups")
                        .font(.caption)
                    Spacer()
                    Text(backupConfig.localStorageUsed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if backupConfig.backupLocation == .iCloud || backupConfig.backupLocation == .both {
                    HStack {
                        Text("iCloud Backups")
                            .font(.caption)
                        Spacer()
                        Text(backupConfig.cloudStorageUsed)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Restore Options Section

    private var restoreOptionsSection: some View {
        Group {
            Picker("Restore Mode", selection: $backupConfig.restoreMode) {
                Text("Replace All").tag(BackupSettingsRestoreMode.replace)
                Text("Merge").tag(BackupSettingsRestoreMode.merge)
                Text("Ask Each Time").tag(BackupSettingsRestoreMode.ask)
            }

            switch backupConfig.restoreMode {
            case .replace:
                Text("Current data will be completely replaced with backup data")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .merge:
                Text("Backup data will be merged with current data")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .ask:
                Text("You'll be asked how to handle conflicts during restore")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Verify Backup Integrity", isOn: $backupConfig.verifyIntegrity)

            Text("Check backup files for corruption before restoring")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Create Safety Backup Before Restore", isOn: $backupConfig.createSafetyBackup)

            Text("Automatically backup current data before restoring")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Backup Detail Sheet

    private func backupDetailSheet(_ backup: BackupSettingsEntry) -> some View {
        NavigationStack {
            Form {
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

    // MARK: - Actions

    private func createBackup() {
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

    private func restoreFromBackup(_ _backup: BackupSettingsEntry) {
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

    private func deleteBackup(_ backup: BackupSettingsEntry) {
        backupConfig.backups.removeAll { $0.id == backup.id }
    }

    private func resetBackupSettings() {
        backupConfig = BackupConfiguration()
        backupConfig.save()
    }
}

// MARK: - Supporting Types

private struct BackupConfiguration: Equatable, Codable {
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

private struct BackupSettingsEntry: Identifiable, Equatable, Codable {
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

private struct BackupSettingsContent: Equatable, Codable {
    var name: String
    var count: Int
    var icon: String
}

private enum BackupSettingsType: String, Codable {
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

private enum BackupSettingsFrequency: String, Codable {
    case daily
    case weekly
    case monthly
}

private enum BackupSettingsLocation: String, Codable {
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

private enum BackupSettingsRestoreMode: String, Codable {
    case replace
    case merge
    case ask
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
