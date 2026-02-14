// SyncSettingsViewSections.swift
// Supporting sections and views for SyncSettingsView

import OSLog
import SwiftUI

// MARK: - Device Updates, Handoff, Advanced & Actions

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
