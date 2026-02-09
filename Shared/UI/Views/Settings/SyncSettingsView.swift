// SyncSettingsView.swift
// Comprehensive sync settings for Thea
//
// Integrates with PreferenceSyncEngine for per-category sync scope management
// and CloudKitService for conversations/knowledge/projects sync.

import OSLog
import SwiftUI

struct SyncSettingsView: View {
    @State private var isReady = false

    var body: some View {
        if isReady {
            SyncSettingsContentView()
        } else {
            ProgressView("Loading sync settings…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    // Trigger singleton initialization off the view layout path.
                    // This lets SwiftUI render the ProgressView immediately while
                    // the heavy iCloud/CloudKit init happens in the background.
                    _ = CloudKitService.shared
                    _ = PreferenceSyncEngine.shared
                    #if os(macOS)
                    _ = AppUpdateService.shared
                    #endif
                    isReady = true
                }
        }
    }
}

private struct SyncSettingsContentView: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var syncEngine = PreferenceSyncEngine.shared
    #if os(macOS)
    @StateObject private var updateService = AppUpdateService.shared
    #endif
    @State private var settingsManager = SettingsManager.shared
    @State private var handoffService = HandoffService.shared
    @State private var showingDeviceList = false
    @State private var isSyncing = false
    @State private var lastSyncError: String?
    @State private var cachedDeviceProfile = DeviceProfile.current()
    #if os(macOS)
    @State private var isUpdating = false
    @State private var updateResult: UpdateResult?
    #endif

    // Data-level sync toggles (CloudKit)
    @AppStorage("sync.conversations") private var syncConversations = true
    @AppStorage("sync.knowledge") private var syncKnowledge = true
    @AppStorage("sync.projects") private var syncProjects = true
    @AppStorage("sync.favorites") private var syncFavorites = true
    @AppStorage("sync.backgroundEnabled") private var backgroundSyncEnabled = true
    @AppStorage("sync.overCellular") private var syncOverCellular = false

    var body: some View {
        Form {
            Section("Sync Overview") {
                syncOverview
            }

            Section("iCloud Sync") {
                iCloudSyncSection
            }

            Section {
                preferenceSyncScopeSection
            } header: {
                Text("Preference Sync Rules")
            } footer: {
                Text("Control how each settings category syncs across your devices. \"All Devices\" shares everywhere, \"Same Device Type\" shares only between similar devices (Mac ↔ Mac, iPhone ↔ iPad), and \"This Device Only\" keeps the setting local.")
            }

            Section("Data Sync") {
                dataSyncSection
            }

            Section("Connected Devices") {
                connectedDevicesSection
            }

            #if os(macOS)
            Section {
                deviceUpdatesSection
            } header: {
                Text("App Updates")
            } footer: {
                Text("Push Thea updates to your other Macs. When a new build is published, other devices receive a notification and can update automatically.")
            }
            #endif

            Section("Handoff") {
                handoffSection
            }

            Section("Advanced") {
                advancedSyncSection
            }

            Section {
                Button("Reset Sync Settings", role: .destructive) {
                    resetSyncSettings()
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .sheet(isPresented: $showingDeviceList) {
            deviceListSheet
        }
    }

    // MARK: - Sync Overview

    private var syncOverview: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            HStack(spacing: 16) {
                overviewCards
            }
            #else
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                overviewCards
            }
            #endif

            if let lastSync = syncEngine.lastSyncDate ?? cloudKitService.lastSyncDate {
                Divider()

                HStack {
                    Text("Last synced")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(lastSync, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var overviewCards: some View {
        overviewCard(
            title: "iCloud",
            value: syncEngine.isCloudAvailable ? "Connected" : "Unavailable",
            icon: "icloud.fill",
            color: syncEngine.isCloudAvailable ? .green : .red
        )

        overviewCard(
            title: "Status",
            value: cloudKitService.syncStatus.description,
            icon: statusIcon(for: cloudKitService.syncStatus),
            color: statusColor(for: cloudKitService.syncStatus)
        )

        overviewCard(
            title: "Devices",
            value: "\(syncEngine.registeredDevices.count)",
            icon: "laptopcomputer.and.iphone",
            color: syncEngine.registeredDevices.count > 1 ? .blue : .secondary
        )

        overviewCard(
            title: "This Device",
            value: TheaDeviceClass.current.displayName,
            icon: TheaDeviceClass.current.systemImage,
            color: .purple
        )
    }

    private func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private func statusIcon(for status: CloudSyncStatus) -> String {
        switch status {
        case .idle: "checkmark.circle.fill"
        case .syncing: "arrow.triangle.2.circlepath"
        case .error: "exclamationmark.triangle.fill"
        case .offline: "wifi.slash"
        }
    }

    private func statusColor(for status: CloudSyncStatus) -> Color {
        switch status {
        case .idle: .green
        case .syncing: .blue
        case .error: .red
        case .offline: .orange
        }
    }

    // MARK: - iCloud Sync Section

    private var iCloudSyncSection: some View {
        Group {
            Toggle("Enable iCloud Sync", isOn: $settingsManager.iCloudSyncEnabled)

            if settingsManager.iCloudSyncEnabled {
                HStack {
                    Text("iCloud Status")
                    Spacer()
                    if syncEngine.isCloudAvailable {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Not Available", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                HStack {
                    Text("Sync Status")
                    Spacer()
                    HStack(spacing: 4) {
                        if cloudKitService.syncStatus == .syncing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text(cloudKitService.syncStatus.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Button {
                        syncNow()
                    } label: {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isSyncing ? "Syncing…" : "Sync Now")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!syncEngine.isCloudAvailable || isSyncing)

                    Spacer()

                    if cloudKitService.pendingChanges > 0 {
                        Text("\(cloudKitService.pendingChanges) pending")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            if let error = lastSyncError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Text("Syncs conversations, settings, and knowledge across your Apple devices via iCloud.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Preference Sync Scope Section

    private var preferenceSyncScopeSection: some View {
        ForEach(SyncCategory.allCases, id: \.self) { category in
            categoryScopeRow(for: category)
        }
    }

    private func categoryScopeRow(for category: SyncCategory) -> some View {
        let currentScope = syncEngine.effectiveScope(for: category)
        let isDefault = syncEngine.scopeOverrides[category] == nil
        let descriptors = PreferenceRegistry.descriptors(for: category)

        return HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(scopeColor(for: currentScope))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if isDefault {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundStyle(.secondary)
                            .cornerRadius(3)
                    }
                }

                Text(descriptors.map(\.displayName).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Picker("", selection: Binding(
                get: { currentScope },
                set: { newScope in
                    if newScope == category.defaultScope {
                        syncEngine.scopeOverrides.removeValue(forKey: category)
                    } else {
                        syncEngine.scopeOverrides[category] = newScope
                    }
                }
            )) {
                ForEach(SyncScope.allCases, id: \.self) { scope in
                    Label(scope.displayName, systemImage: scope.icon)
                        .tag(scope)
                }
            }
            .pickerStyle(.menu)
            #if os(macOS)
            .frame(width: 180)
            #endif
        }
        .padding(.vertical, 2)
    }

    private func scopeColor(for scope: SyncScope) -> Color {
        switch scope {
        case .universal: .blue
        case .deviceClass: .orange
        case .deviceLocal: .secondary
        }
    }

    // MARK: - Data Sync Section (CloudKit)

    private var dataSyncSection: some View {
        Group {
            Toggle("Conversations", isOn: $syncConversations)
            Toggle("Knowledge Base", isOn: $syncKnowledge)
            Toggle("Projects", isOn: $syncProjects)
            Toggle("Favorite Models", isOn: $syncFavorites)

            Text("These control which data types sync via CloudKit. Preferences sync separately using the rules above.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Connected Devices Section

    private var connectedDevicesSection: some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Devices")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("\(syncEngine.registeredDevices.count) device\(syncEngine.registeredDevices.count == 1 ? "" : "s") registered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingDeviceList = true
                } label: {
                    Label("Manage", systemImage: "laptopcomputer.and.iphone")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            ForEach(syncEngine.registeredDevices.prefix(3)) { device in
                deviceRow(device)
            }

            if syncEngine.registeredDevices.count > 3 {
                Text("+ \(syncEngine.registeredDevices.count - 3) more device\(syncEngine.registeredDevices.count - 3 == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if syncEngine.registeredDevices.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("No devices registered yet. Open Thea on another device to see it here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func deviceRow(_ device: DeviceProfile) -> some View {
        let isCurrentDevice = device.id == cachedDeviceProfile.id

        return HStack(spacing: 12) {
            Image(systemName: device.deviceClass.systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.caption)
                        .fontWeight(.medium)

                    if isCurrentDevice {
                        Text("This device")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .cornerRadius(4)
                    }
                }

                Text("\(device.model) · \(device.deviceClass.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(device.lastActive, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Device Updates Section

    #if os(macOS)
    @ViewBuilder
    private var deviceUpdatesSection: some View {
        // Update availability banner
        if let update = updateService.availableUpdate {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

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

    private func publishCurrentBuild() async {
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

    private func currentCommitHash() async -> String {
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

    // MARK: - Handoff Section

    private var handoffSection: some View {
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

    private func requirementRow(icon: String, title: String, status: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.caption)

            Spacer()

            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(status ? .green : .red)
        }
    }

    // MARK: - Advanced Section

    private var advancedSyncSection: some View {
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

    private var deviceListSheet: some View {
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
    private var syncGroupInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Devices in the same sync group share \"Same Device Type\" preferences.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "desktopcomputer")
                Text("Mac ↔ Mac")
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: "iphone")
                Text("iPhone ↔ iPad")
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: "appletv")
                Text("Apple TV (standalone)")
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: "applewatch")
                Text("Apple Watch (standalone)")
                    .font(.caption)
            }
        }
    }

    // MARK: - Actions

    private func syncNow() {
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

    private func forceFullSync() {
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

    private func resetSyncSettings() {
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

private enum UpdateResult: Equatable {
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
