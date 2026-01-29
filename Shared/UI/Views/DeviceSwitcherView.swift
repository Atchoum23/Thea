//
//  DeviceSwitcherView.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import SwiftUI

// MARK: - Device Switcher View

/// View for managing and switching between connected devices
public struct DeviceSwitcherView: View {
    @State private var devices: [DeviceInfo] = []
    @State private var currentDevice: DeviceInfo?
    @State private var syncStatus: SyncStatus?
    @State private var showSyncSettings = false
    @State private var isLoading = true

    public init() {}

    public var body: some View {
        List {
            // Current Device Section
            if let current = currentDevice {
                Section("This Device") {
                    DeviceRow(device: current, isCurrent: true)
                }
            }

            // Other Devices Section
            Section("Other Devices") {
                if otherDevices.isEmpty {
                    ContentUnavailableView(
                        "No Other Devices",
                        systemImage: "iphone.and.arrow.forward",
                        description: Text("Sign in to iCloud on other devices to see them here.")
                    )
                } else {
                    ForEach(otherDevices) { device in
                        DeviceRow(device: device, isCurrent: false)
                    }
                }
            }

            // Sync Status Section
            Section("Sync Status") {
                if let status = syncStatus {
                    SyncStatusRow(status: status)
                } else {
                    ProgressView()
                }
            }

            // Settings Section
            Section {
                Button {
                    showSyncSettings = true
                } label: {
                    Label("Sync Settings", systemImage: "gear")
                }

                Button {
                    Task {
                        await refreshDevices()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .navigationTitle("Devices")
        .task {
            await loadData()
        }
        .refreshable {
            await refreshDevices()
        }
        .sheet(isPresented: $showSyncSettings) {
            DeviceSyncSettingsSheet()
        }
    }

    // MARK: - Computed Properties

    private var otherDevices: [DeviceInfo] {
        guard let current = currentDevice else { return devices }
        return devices.filter { $0.id != current.id }
    }

    // MARK: - Data Loading

    private func loadData() async {
        await MainActor.run {
            currentDevice = DeviceRegistry.shared.currentDevice
            devices = DeviceRegistry.shared.registeredDevices
        }

        syncStatus = await CrossDeviceService.shared.getStatus()
        isLoading = false
    }

    private func refreshDevices() async {
        await MainActor.run {
            DeviceRegistry.shared.updatePresence()
            devices = DeviceRegistry.shared.registeredDevices
        }

        do {
            try await CrossDeviceService.shared.performFullSync()
        } catch {
            // Handle error silently
        }

        syncStatus = await CrossDeviceService.shared.getStatus()
    }
}

// MARK: - Device Row

private struct DeviceRow: View {
    let device: DeviceInfo
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Device Icon
            Image(systemName: device.type.icon)
                .font(.title2)
                .foregroundStyle(device.isOnline ? .blue : .secondary)
                .frame(width: 40)

            // Device Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(device.name)
                        .fontWeight(isCurrent ? .semibold : .regular)

                    if isCurrent {
                        Text("(This Device)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Text(device.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("v\(device.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status
            VStack(alignment: .trailing, spacing: 2) {
                Circle()
                    .fill(device.isOnline ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(device.isOnline ? "Online" : device.formattedLastSeen)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sync Status Row

private struct SyncStatusRow: View {
    let status: SyncStatus

    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.statusDescription)

                if let lastSync = status.lastSyncTime {
                    Text("Last synced: \(lastSync, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if status.pendingChanges > 0 {
                Text("\(status.pendingChanges) pending")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var statusIcon: String {
        if status.isReady {
            "checkmark.circle.fill"
        } else if status.isEnabled {
            "exclamationmark.circle.fill"
        } else {
            "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        if status.isReady {
            .green
        } else if status.isEnabled {
            .orange
        } else {
            .red
        }
    }
}

// MARK: - Device Sync Settings Sheet

private struct DeviceSyncSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config = CrossDeviceSyncConfiguration()
    @State private var handoffConfig = HandoffConfiguration()

    var body: some View {
        NavigationStack {
            Form {
                // Sync Options
                Section("Sync") {
                    Toggle("Enable Auto Sync", isOn: $config.autoSyncEnabled)
                    Toggle("Sync Conversations", isOn: $config.syncConversations)
                    Toggle("Sync Projects", isOn: $config.syncProjects)
                    Toggle("Sync Settings", isOn: $config.syncSettings)
                }

                // Conflict Resolution
                Section("Conflict Resolution") {
                    Picker("When conflicts occur", selection: $config.conflictResolution) {
                        ForEach(ConflictResolutionStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                }

                // Handoff
                Section("Handoff") {
                    Toggle("Enable Handoff", isOn: $handoffConfig.handoffEnabled)
                    Toggle("Conversations", isOn: $handoffConfig.allowConversationHandoff)
                        .disabled(!handoffConfig.handoffEnabled)
                    Toggle("Projects", isOn: $handoffConfig.allowProjectHandoff)
                        .disabled(!handoffConfig.handoffEnabled)
                    Toggle("Searches", isOn: $handoffConfig.allowSearchHandoff)
                        .disabled(!handoffConfig.handoffEnabled)
                }
            }
            .navigationTitle("Sync Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .task {
                await loadSettings()
            }
        }
    }

    private func loadSettings() async {
        config = await CrossDeviceService.shared.getConfiguration()
        handoffConfig = await MainActor.run {
            HandoffService.shared.getConfiguration()
        }
    }

    private func saveSettings() {
        Task {
            await CrossDeviceService.shared.updateConfiguration(config)
            await MainActor.run {
                HandoffService.shared.updateConfiguration(handoffConfig)
            }
        }
    }
}

// MARK: - Previews

#Preview("Device Switcher") {
    NavigationStack {
        DeviceSwitcherView()
    }
}
