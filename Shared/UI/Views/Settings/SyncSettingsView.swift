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

struct SyncSettingsContentView: View {
    @StateObject var cloudKitService = CloudKitService.shared
    @StateObject var syncEngine = PreferenceSyncEngine.shared
    #if os(macOS)
    @StateObject var updateService = AppUpdateService.shared
    #endif
    @State var settingsManager = SettingsManager.shared
    @State var handoffService = HandoffService.shared
    @State var showingDeviceList = false
    @State var isSyncing = false
    @State var lastSyncError: String?
    @State var cachedDeviceProfile = DeviceProfile.current()
    #if os(macOS)
    @State var isUpdating = false
    @State var updateResult: SyncUpdateResult?
    #endif

    // Data-level sync toggles (CloudKit)
    @AppStorage("sync.conversations") var syncConversations = true
    @AppStorage("sync.knowledge") var syncKnowledge = true
    @AppStorage("sync.projects") var syncProjects = true
    @AppStorage("sync.favorites") var syncFavorites = true
    @AppStorage("sync.backgroundEnabled") var backgroundSyncEnabled = true
    @AppStorage("sync.overCellular") var syncOverCellular = false

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
                .accessibilityHidden(true)

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
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
                        .accessibilityHidden(true)

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

}

// MARK: - Preference Sync, Data Sync & Connected Devices

extension SyncSettingsContentView {

    var preferenceSyncScopeSection: some View {
        ForEach(SyncCategory.allCases, id: \.self) { category in
            categoryScopeRow(for: category)
        }
    }

    func categoryScopeRow(for category: SyncCategory) -> some View {
        let currentScope = syncEngine.effectiveScope(for: category)
        let isDefault = syncEngine.scopeOverrides[category] == nil
        let descriptors = PreferenceRegistry.descriptors(for: category)

        return HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(scopeColor(for: currentScope))
                .frame(width: 28)
                .accessibilityHidden(true)

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

    func scopeColor(for scope: SyncScope) -> Color {
        switch scope {
        case .universal: .blue
        case .deviceClass: .orange
        case .deviceLocal: .secondary
        }
    }

    var dataSyncSection: some View {
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

    var connectedDevicesSection: some View {
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
                        .accessibilityHidden(true)
                    Text("No devices registered yet. Open Thea on another device to see it here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    func deviceRow(_ device: DeviceProfile) -> some View {
        let isCurrentDevice = device.id == cachedDeviceProfile.id

        return HStack(spacing: 12) {
            Image(systemName: device.deviceClass.systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
                .accessibilityHidden(true)

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
}

// Device Updates, Handoff, Advanced, Device List Sheet, Actions,
// and Preview are in SyncSettingsViewSections.swift
