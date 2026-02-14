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

// Preference Sync, Data Sync, Devices, Updates, Handoff, Advanced,
// Device List Sheet, Actions, and Preview are in SyncSettingsViewSections.swift
