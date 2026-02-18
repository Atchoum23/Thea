// BackupSettingsView.swift
// Comprehensive backup and restore settings for Thea
// Supporting types in BackupSettingsViewSections.swift

import SwiftUI

struct BackupSettingsView: View {
    @State var backupConfig = BackupConfiguration.load()
    @State var showingBackupDetail: BackupSettingsEntry?
    @State var showingRestoreConfirmation = false
    @State var showingDeleteConfirmation = false
    @State var selectedBackup: BackupSettingsEntry?
    @State var isCreatingBackup = false
    @State var isRestoringBackup = false
    @State var backupProgress: Double = 0
    @State var restoreProgress: Double = 0
    @State var errorMessage: String?
    @State var showError = false

    var body: some View {
        Form {
            Section("Backup Overview") { backupOverview }
            Section("Quick Actions") { quickActionsSection }
            Section("Available Backups") { availableBackupsSection }
            Section("Automatic Backup") { autoBackupSection }
            Section("Backup Contents") { backupContentsSection }
            Section("Backup Location") { backupLocationSection }
            Section("Restore Options") { restoreOptionsSection }
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
        .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK") { }
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Backup Overview

    private var backupOverview: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            HStack(spacing: 16) {
                overviewCard(title: "Backups", value: "\(backupConfig.backups.count)", icon: "arrow.clockwise.icloud.fill", color: .blue)
                overviewCard(title: "Auto Backup", value: backupConfig.autoBackupEnabled ? "On" : "Off", icon: "clock.arrow.circlepath", color: backupConfig.autoBackupEnabled ? .green : .secondary)
                overviewCard(title: "Total Size", value: backupConfig.totalBackupSize, icon: "externaldrive.fill", color: .purple)
                overviewCard(title: "Last Backup", value: lastBackupText, icon: "calendar", color: .orange)
            }
            #else
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                overviewCard(title: "Backups", value: "\(backupConfig.backups.count)", icon: "arrow.clockwise.icloud.fill", color: .blue)
                overviewCard(title: "Auto Backup", value: backupConfig.autoBackupEnabled ? "On" : "Off", icon: "clock.arrow.circlepath", color: backupConfig.autoBackupEnabled ? .green : .secondary)
                overviewCard(title: "Total Size", value: backupConfig.totalBackupSize, icon: "externaldrive.fill", color: .purple)
                overviewCard(title: "Last Backup", value: lastBackupText, icon: "calendar", color: .orange)
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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Backup").font(.subheadline).fontWeight(.medium)
                    Text("Create a new backup of your data now").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    createBackup()
                } label: {
                    if isCreatingBackup {
                        ProgressView().scaleEffect(0.8)
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
                    Text("Creating backup... \(Int(backupProgress * 100))%").font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            if !backupConfig.backups.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Restore").font(.subheadline).fontWeight(.medium)
                        Text("Restore from most recent backup").font(.caption).foregroundStyle(.secondary)
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
                        Text("Restoring... \(Int(restoreProgress * 100))%").font(.caption).foregroundStyle(.secondary)
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
                    Image(systemName: "arrow.clockwise.icloud").font(.largeTitle).foregroundStyle(.secondary)
                    Text("No backups yet").font(.subheadline).foregroundStyle(.secondary)
                    Text("Create your first backup to protect your data").font(.caption).foregroundStyle(.tertiary)
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
            Image(systemName: backupTypeIcon(backup.type))
                .font(.title2)
                .foregroundStyle(backupTypeColor(backup.type))
                .frame(width: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(backup.name).font(.subheadline).fontWeight(.medium)
                    if backup.isAutoBackup {
                        Text("Auto")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                }
                HStack {
                    Text(backup.date, style: .date)
                    Text(backup.date, style: .time)
                }
                .font(.caption).foregroundStyle(.secondary)
                Text(backup.size).font(.caption2).foregroundStyle(.tertiary)
            }

            Spacer()

            Menu {
                Button { showingBackupDetail = backup } label: {
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
                Image(systemName: "ellipsis.circle").font(.title2).foregroundStyle(.secondary)
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
}

// MARK: - Settings Sections Extension

extension BackupSettingsView {

    var autoBackupSection: some View {
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

                Text("Older backups will be automatically deleted").font(.caption).foregroundStyle(.secondary)

                Divider()

                Toggle("Only on Wi-Fi", isOn: $backupConfig.onlyBackupOnWiFi)
                Toggle("Only When Charging", isOn: $backupConfig.onlyBackupWhenCharging)

                if let nextBackup = backupConfig.nextScheduledBackup {
                    HStack {
                        Text("Next Backup")
                        Spacer()
                        Text(nextBackup, style: .relative).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    var backupContentsSection: some View {
        Group {
            Toggle("Conversations", isOn: $backupConfig.backupConversations)
            Toggle("Settings", isOn: $backupConfig.backupSettings)
            Toggle("Knowledge Base", isOn: $backupConfig.backupKnowledge)
            Toggle("Projects", isOn: $backupConfig.backupProjects)
            Toggle("Attachments", isOn: $backupConfig.backupAttachments)

            if backupConfig.backupAttachments {
                Text("Including attachments significantly increases backup size")
                    .font(.caption).foregroundStyle(.orange)
            }

            Divider()

            HStack {
                Text("Estimated Backup Size")
                Spacer()
                Text(calculateEstimatedSize()).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    func calculateEstimatedSize() -> String {
        var size: Double = 0
        if backupConfig.backupConversations { size += 15 }
        if backupConfig.backupSettings { size += 0.5 }
        if backupConfig.backupKnowledge { size += 8 }
        if backupConfig.backupProjects { size += 5 }
        if backupConfig.backupAttachments { size += 50 }
        return String(format: "~%.1f MB", size)
    }

    var backupLocationSection: some View {
        Group {
            Picker("Backup Location", selection: $backupConfig.backupLocation) {
                Text("Local Storage").tag(BackupSettingsLocation.local)
                Text("iCloud").tag(BackupSettingsLocation.iCloud)
                Text("Both").tag(BackupSettingsLocation.both)
            }

            switch backupConfig.backupLocation {
            case .local:
                Text("Backups are stored on this device only").font(.caption).foregroundStyle(.secondary)
            case .iCloud:
                Text("Backups are stored in iCloud and accessible from all devices").font(.caption).foregroundStyle(.secondary)
            case .both:
                Text("Backups are stored both locally and in iCloud for maximum safety").font(.caption).foregroundStyle(.secondary)
            }

            if backupConfig.backupLocation == .iCloud || backupConfig.backupLocation == .both {
                Toggle("Encrypt iCloud Backups", isOn: $backupConfig.encryptCloudBackups)
                Text("Encrypted backups require a password to restore").font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Storage Usage").font(.subheadline).fontWeight(.medium)
                HStack {
                    Text("Local Backups").font(.caption)
                    Spacer()
                    Text(backupConfig.localStorageUsed).font(.caption).foregroundStyle(.secondary)
                }
                if backupConfig.backupLocation == .iCloud || backupConfig.backupLocation == .both {
                    HStack {
                        Text("iCloud Backups").font(.caption)
                        Spacer()
                        Text(backupConfig.cloudStorageUsed).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    var restoreOptionsSection: some View {
        Group {
            Picker("Restore Mode", selection: $backupConfig.restoreMode) {
                Text("Replace All").tag(BackupSettingsRestoreMode.replace)
                Text("Merge").tag(BackupSettingsRestoreMode.merge)
                Text("Ask Each Time").tag(BackupSettingsRestoreMode.ask)
            }

            switch backupConfig.restoreMode {
            case .replace:
                Text("Current data will be completely replaced with backup data").font(.caption).foregroundStyle(.secondary)
            case .merge:
                Text("Backup data will be merged with current data").font(.caption).foregroundStyle(.secondary)
            case .ask:
                Text("You'll be asked how to handle conflicts during restore").font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Verify Backup Integrity", isOn: $backupConfig.verifyIntegrity)
            Text("Check backup files for corruption before restoring").font(.caption).foregroundStyle(.secondary)

            Toggle("Create Safety Backup Before Restore", isOn: $backupConfig.createSafetyBackup)
            Text("Automatically backup current data before restoring").font(.caption).foregroundStyle(.secondary)
        }
    }
}
