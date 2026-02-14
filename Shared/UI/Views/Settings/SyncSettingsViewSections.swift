// SyncSettingsViewSections.swift
// Supporting sections and views for SyncSettingsView

import OSLog
import SwiftUI

// MARK: - Device Updates Section

extension SyncSettingsContentView {

    #if os(macOS)
    @ViewBuilder
    var deviceUpdatesSection: some View {
        // Update availability banner
        if let update = updateService.availableUpdate {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Update Available")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("v\(update.version) (build \(update.build)) from \(update.sourceDevice)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(update.publishedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    Task {
                        isUpdating = true
                        let success = await updateService.performUpdate()
                        updateResult = success ? .success : .failure
                        isUpdating = false
                    }
                } label: {
                    if isUpdating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Update Now", systemImage: "arrow.down.to.line")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)
            }
            .padding(.vertical, 4)
        }

        // Update result feedback
        if let result = updateResult {
            HStack {
                Image(systemName: result == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result == .success ? .green : .red)
                    .accessibilityHidden(true)
                Text(result == .success
                    ? "Update installed. Restart Thea to use the new version."
                    : "Update failed. Check ~/Library/Logs/thea-sync-stderr.log for details.")
                    .font(.caption)
            }
        }

        // Auto-update toggle
        Toggle("Auto-update when available", isOn: $updateService.autoUpdateEnabled)

        // Check for updates
        HStack {
            Button {
                Task {
                    await updateService.checkForUpdates()
                }
            } label: {
                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(updateService.isCheckingForUpdate)

            Spacer()

            if updateService.isCheckingForUpdate {
                ProgressView()
                    .controlSize(.small)
            } else if let lastChecked = updateService.lastChecked {
                Text("Last checked \(lastChecked, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }

        // Push update to other devices
        if updateService.availableUpdate == nil {
            Button {
                Task {
                    await publishCurrentBuild()
                }
            } label: {
                Label("Push This Build to Other Devices", systemImage: "square.and.arrow.up")
            }
            .help("Notify other Macs that this build is available for installation")
        }

        // Update history
        if !updateService.updateHistory.isEmpty {
            DisclosureGroup("Update History") {
                ForEach(updateService.updateHistory.prefix(5)) { update in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("v\(update.version) (build \(update.build))")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("From \(update.sourceDevice)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if let installed = update.installedAt {
                                Text("Installed")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text(installed, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text(update.publishedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    func publishCurrentBuild() async {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let deviceName = cachedDeviceProfile.name

        // Get current git commit hash (runs on background thread)
        let commitHash = await currentCommitHash()

        do {
            try await updateService.publishUpdate(
                version: version,
                build: build,
                commitHash: commitHash,
                sourceDevice: deviceName
            )
        } catch {
            // Silently log — the user will see the error via the update banner next time
            Logger(subsystem: "app.thea", category: "AppUpdate")
                .error("Failed to publish update: \(error.localizedDescription)")
        }
    }

    func currentCommitHash() async -> String {
        let bundleURL = Bundle.main.bundleURL
        return await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["rev-parse", "--short", "HEAD"]
            process.currentDirectoryURL = bundleURL

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
            } catch {
                return "unknown"
            }
        }.value
    }
    #endif
}

// MARK: - Handoff, Advanced & Actions

extension SyncSettingsContentView {

    // MARK: - Handoff Section

    var handoffSection: some View {
        Group {
            Toggle("Enable Handoff", isOn: $settingsManager.handoffEnabled)

            HStack {
                Text("Handoff Status")
                Spacer()
                if handoffService.isEnabled {
                    Label("Active", systemImage: "hand.raised.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Label("Disabled", systemImage: "hand.raised.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if handoffService.currentActivity != nil {
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                    Text("Activity ready for handoff")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Text("Continue conversations seamlessly across your Apple devices.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Requirements")
                    .font(.subheadline)
                    .fontWeight(.medium)

                requirementRow(
                    icon: "icloud",
                    title: "iCloud Account",
                    status: syncEngine.isCloudAvailable
                )

                requirementRow(
                    icon: "wifi",
                    title: "Same Wi-Fi Network",
                    status: true
                )

                requirementRow(
                    icon: "bluetooth",
                    title: "Bluetooth Enabled",
                    status: true
                )
            }
        }
    }

    func requirementRow(icon: String, title: String, status: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(title)
                .font(.caption)

            Spacer()

            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(status ? .green : .red)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(status ? "met" : "not met")")
    }

    // MARK: - Advanced Section

    var advancedSyncSection: some View {
        Group {
            Toggle("Background Sync", isOn: $backgroundSyncEnabled)

            Text("Sync data in the background when the app is not active")
                .font(.caption)
                .foregroundStyle(.secondary)

            #if os(iOS)
            Toggle("Sync Over Cellular", isOn: $syncOverCellular)

            Text("Allow syncing when not connected to Wi-Fi (may use mobile data)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
            #endif

            Button("Force Full Sync") {
                forceFullSync()
            }
            .buttonStyle(.bordered)

            Text("Re-syncs all preferences and data from iCloud. Use if you notice sync issues.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Reset Category Overrides") {
                syncEngine.scopeOverrides = [:]
            }
            .font(.caption)

            Text("Revert all sync scope settings to their recommended defaults.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Device List Sheet

    var deviceListSheet: some View {
        NavigationStack {
            List {
                if syncEngine.registeredDevices.isEmpty {
                    Text("No devices registered")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(syncEngine.registeredDevices) { device in
                        let isCurrentDevice = device.id == cachedDeviceProfile.id

                        HStack(spacing: 12) {
                            Image(systemName: device.deviceClass.systemImage)
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .frame(width: 40)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(device.name)
                                        .font(.headline)

                                    if isCurrentDevice {
                                        Text("Current")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.2))
                                            .foregroundStyle(.green)
                                            .cornerRadius(4)
                                    }
                                }

                                Text("\(device.model) · \(device.deviceClass.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("OS: \(device.osVersion)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)

                                Text("Last active: \(device.lastActive, style: .relative) ago")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Sync Groups") {
                    syncGroupInfo
                }
            }
            .navigationTitle("Connected Devices")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingDeviceList = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 550, height: 550)
        #endif
    }

    @ViewBuilder
    var syncGroupInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Devices in the same sync group share \"Same Device Type\" preferences.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "desktopcomputer")
                    .accessibilityHidden(true)
                Text("Mac <-> Mac")
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: "iphone")
                    .accessibilityHidden(true)
                Text("iPhone <-> iPad")
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: "appletv")
                    .accessibilityHidden(true)
                Text("Apple TV (standalone)")
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: "applewatch")
                    .accessibilityHidden(true)
                Text("Apple Watch (standalone)")
                    .font(.caption)
            }
        }
    }

    // MARK: - Actions

    func syncNow() {
        isSyncing = true
        lastSyncError = nil

        Task {
            do {
                syncEngine.forceSync()
                try await cloudKitService.syncAll()
            } catch {
                await MainActor.run {
                    lastSyncError = error.localizedDescription
                }
            }

            await MainActor.run {
                isSyncing = false
            }
        }
    }

    func forceFullSync() {
        isSyncing = true
        lastSyncError = nil

        Task {
            do {
                syncEngine.forceSync()
                try await cloudKitService.syncAll()
            } catch {
                await MainActor.run {
                    lastSyncError = error.localizedDescription
                }
            }

            await MainActor.run {
                isSyncing = false
            }
        }
    }

    func resetSyncSettings() {
        syncEngine.scopeOverrides = [:]
        syncConversations = true
        syncKnowledge = true
        syncProjects = true
        syncFavorites = true
        backgroundSyncEnabled = true
        syncOverCellular = false
    }
}

// MARK: - Update Result

enum SyncUpdateResult: Equatable {
    case success
    case failure
}

// MARK: - Preview

#if os(macOS)
#Preview {
    SyncSettingsView()
        .frame(width: 700, height: 900)
}
#else
#Preview {
    NavigationStack {
        SyncSettingsView()
            .navigationTitle("Sync")
    }
}
#endif
