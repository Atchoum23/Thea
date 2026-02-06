// SyncSettingsView.swift
// Comprehensive sync settings for Thea

import SwiftUI

struct SyncSettingsView: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var settingsManager = SettingsManager.shared
    @State private var handoffService = HandoffService.shared
    @State private var showingConflictHistory = false
    @State private var showingDeviceList = false
    @State private var syncPreferences = SyncPreferences.load()
    @State private var isSyncing = false
    @State private var lastSyncError: String?

    var body: some View {
        Form {
            // MARK: - Overview
            Section("Sync Overview") {
                syncOverview
            }

            // MARK: - iCloud Sync
            Section("iCloud Sync") {
                iCloudSyncSection
            }

            // MARK: - Selective Sync
            Section("Selective Sync") {
                selectiveSyncSection
            }

            // MARK: - Conflict Resolution
            Section("Conflict Resolution") {
                conflictResolutionSection
            }

            // MARK: - Connected Devices
            Section("Connected Devices") {
                connectedDevicesSection
            }

            // MARK: - Handoff
            Section("Handoff") {
                handoffSection
            }

            // MARK: - Sync History
            Section("Sync History") {
                syncHistorySection
            }

            // MARK: - Advanced
            Section("Advanced") {
                advancedSyncSection
            }

            // MARK: - Reset
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
        .onChange(of: syncPreferences) { _, _ in
            syncPreferences.save()
        }
        .sheet(isPresented: $showingConflictHistory) {
            conflictHistorySheet
        }
        .sheet(isPresented: $showingDeviceList) {
            deviceListSheet
        }
    }

    // MARK: - Sync Overview

    private var syncOverview: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            HStack(spacing: 16) {
                overviewCard(
                    title: "iCloud",
                    value: cloudKitService.iCloudAvailable ? "Connected" : "Unavailable",
                    icon: "icloud.fill",
                    color: cloudKitService.iCloudAvailable ? .green : .red
                )

                overviewCard(
                    title: "Status",
                    value: cloudKitService.syncStatus.description,
                    icon: statusIcon(for: cloudKitService.syncStatus),
                    color: statusColor(for: cloudKitService.syncStatus)
                )

                overviewCard(
                    title: "Handoff",
                    value: handoffService.isEnabled ? "Active" : "Disabled",
                    icon: "hand.raised.fill",
                    color: handoffService.isEnabled ? .blue : .secondary
                )

                overviewCard(
                    title: "Pending",
                    value: "\(cloudKitService.pendingChanges)",
                    icon: "arrow.triangle.2.circlepath",
                    color: cloudKitService.pendingChanges > 0 ? .orange : .green
                )
            }
            #else
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                overviewCard(
                    title: "iCloud",
                    value: cloudKitService.iCloudAvailable ? "Connected" : "Unavailable",
                    icon: "icloud.fill",
                    color: cloudKitService.iCloudAvailable ? .green : .red
                )

                overviewCard(
                    title: "Status",
                    value: cloudKitService.syncStatus.description,
                    icon: statusIcon(for: cloudKitService.syncStatus),
                    color: statusColor(for: cloudKitService.syncStatus)
                )

                overviewCard(
                    title: "Handoff",
                    value: handoffService.isEnabled ? "Active" : "Disabled",
                    icon: "hand.raised.fill",
                    color: handoffService.isEnabled ? .blue : .secondary
                )

                overviewCard(
                    title: "Pending",
                    value: "\(cloudKitService.pendingChanges)",
                    icon: "arrow.triangle.2.circlepath",
                    color: cloudKitService.pendingChanges > 0 ? .orange : .green
                )
            }
            #endif

            // Last sync info
            if let lastSync = cloudKitService.lastSyncDate {
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
                    if cloudKitService.iCloudAvailable {
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

                // Sync Now Button
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
                            Text(isSyncing ? "Syncing..." : "Sync Now")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!cloudKitService.iCloudAvailable || isSyncing)

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

    // MARK: - Selective Sync Section

    private var selectiveSyncSection: some View {
        Group {
            Toggle("Sync Conversations", isOn: $syncPreferences.syncConversations)

            Toggle("Sync Settings", isOn: $syncPreferences.syncSettings)

            Toggle("Sync Knowledge Base", isOn: $syncPreferences.syncKnowledge)

            Toggle("Sync Projects", isOn: $syncPreferences.syncProjects)

            Toggle("Sync Favorites", isOn: $syncPreferences.syncFavorites)

            Divider()

            // Data size indicators
            VStack(alignment: .leading, spacing: 8) {
                Text("Sync Data Usage")
                    .font(.subheadline)
                    .fontWeight(.medium)

                syncDataRow(title: "Conversations", size: syncPreferences.conversationsSize, enabled: syncPreferences.syncConversations)
                syncDataRow(title: "Settings", size: syncPreferences.settingsSize, enabled: syncPreferences.syncSettings)
                syncDataRow(title: "Knowledge", size: syncPreferences.knowledgeSize, enabled: syncPreferences.syncKnowledge)
                syncDataRow(title: "Projects", size: syncPreferences.projectsSize, enabled: syncPreferences.syncProjects)
            }

            Text("Disable sync for data types you don't need across devices to save iCloud storage.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func syncDataRow(title: String, size: String, enabled: Bool) -> some View {
        HStack {
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(enabled ? .green : .secondary)
                .frame(width: 20)

            Text(title)
                .font(.caption)

            Spacer()

            Text(size)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Conflict Resolution Section

    private var conflictResolutionSection: some View {
        Group {
            Picker("Default Resolution", selection: $syncPreferences.conflictStrategy) {
                Text("Keep Local").tag(SyncConflictStrategy.keepLocal)
                Text("Keep Cloud").tag(SyncConflictStrategy.keepCloud)
                Text("Ask Every Time").tag(SyncConflictStrategy.askEveryTime)
                Text("Keep Most Recent").tag(SyncConflictStrategy.keepMostRecent)
            }

            Text("How to handle conflicts when the same item is modified on multiple devices")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conflict History")
                        .font(.subheadline)

                    Text("\(syncPreferences.conflictCount) conflicts resolved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingConflictHistory = true
                } label: {
                    Label("View", systemImage: "list.bullet")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
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

                    Text("\(syncPreferences.connectedDevices.count) devices syncing")
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

            // Device preview
            ForEach(syncPreferences.connectedDevices.prefix(3), id: \.id) { device in
                HStack(spacing: 12) {
                    Image(systemName: deviceIcon(for: device.type))
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.caption)
                            .fontWeight(.medium)

                        Text("Last sync: \(device.lastSync, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if device.isCurrentDevice {
                        Text("This device")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .cornerRadius(4)
                    }
                }
            }

            if syncPreferences.connectedDevices.count > 3 {
                Text("+ \(syncPreferences.connectedDevices.count - 3) more devices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deviceIcon(for type: SyncDeviceType) -> String {
        switch type {
        case .mac: "desktopcomputer"
        case .iPhone: "iphone"
        case .iPad: "ipad"
        case .watch: "applewatch"
        case .tv: "appletv"
        }
    }

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

            Text("Continue conversations seamlessly across your Apple devices. Start on Mac, continue on iPhone or iPad.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Handoff Requirements
            VStack(alignment: .leading, spacing: 8) {
                Text("Requirements")
                    .font(.subheadline)
                    .fontWeight(.medium)

                requirementRow(
                    icon: "icloud",
                    title: "iCloud Account",
                    status: cloudKitService.iCloudAvailable
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

    // MARK: - Sync History Section

    private var syncHistorySection: some View {
        Group {
            ForEach(syncPreferences.recentSyncs.prefix(5), id: \.id) { syncEvent in
                HStack(spacing: 12) {
                    Image(systemName: syncEvent.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(syncEvent.success ? .green : .red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncEvent.type)
                            .font(.caption)
                            .fontWeight(.medium)

                        Text(syncEvent.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(syncEvent.itemsCount) items")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if syncPreferences.recentSyncs.isEmpty {
                Text("No recent sync activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Clear Sync History") {
                syncPreferences.recentSyncs = []
            }
            .font(.caption)
        }
    }

    // MARK: - Advanced Section

    private var advancedSyncSection: some View {
        Group {
            Toggle("Background Sync", isOn: $syncPreferences.backgroundSyncEnabled)

            Text("Sync data in the background when the app is not active")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Sync Over Cellular", isOn: $syncPreferences.syncOverCellular)

            Text("Allow syncing when not connected to Wi-Fi (may use mobile data)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Sync frequency
            Picker("Sync Frequency", selection: $syncPreferences.syncFrequency) {
                Text("Real-time").tag(SyncSettingsFrequency.realtime)
                Text("Every 5 minutes").tag(SyncSettingsFrequency.fiveMinutes)
                Text("Every 15 minutes").tag(SyncSettingsFrequency.fifteenMinutes)
                Text("Hourly").tag(SyncSettingsFrequency.hourly)
                Text("Manual only").tag(SyncSettingsFrequency.manual)
            }

            Divider()

            // Force full sync
            Button("Force Full Sync") {
                forceFullSync()
            }
            .buttonStyle(.bordered)

            Text("Re-syncs all data from iCloud. Use if you notice sync issues.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Conflict History Sheet

    private var conflictHistorySheet: some View {
        NavigationStack {
            List {
                if syncPreferences.conflictHistory.isEmpty {
                    Text("No conflicts recorded")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(syncPreferences.conflictHistory, id: \.id) { conflict in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)

                                Text(conflict.itemName)
                                    .font(.headline)

                                Spacer()

                                Text(conflict.timestamp, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Resolution: \(conflict.resolution)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Text("Local: \(conflict.localModified, style: .date)")
                                    .font(.caption2)

                                Spacer()

                                Text("Cloud: \(conflict.cloudModified, style: .date)")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Conflict History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingConflictHistory = false
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear All", role: .destructive) {
                        syncPreferences.conflictHistory = []
                        syncPreferences.conflictCount = 0
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 600, height: 500)
        #endif
    }

    // MARK: - Device List Sheet

    private var deviceListSheet: some View {
        NavigationStack {
            List {
                ForEach(syncPreferences.connectedDevices, id: \.id) { device in
                    HStack(spacing: 12) {
                        Image(systemName: deviceIcon(for: device.type))
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(device.name)
                                    .font(.headline)

                                if device.isCurrentDevice {
                                    Text("Current")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundStyle(.green)
                                        .cornerRadius(4)
                                }
                            }

                            Text(device.model)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Last sync: \(device.lastSync, style: .relative) ago")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Circle()
                                .fill(device.isOnline ? Color.green : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)

                            Text(device.isOnline ? "Online" : "Offline")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
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
        .frame(width: 500, height: 500)
        #endif
    }

    // MARK: - Actions

    private func syncNow() {
        isSyncing = true
        lastSyncError = nil

        Task {
            do {
                try await cloudKitService.syncAll()
                syncPreferences.recentSyncs.insert(
                    SyncActivityEvent(id: UUID(), type: "Manual Sync", timestamp: Date(), success: true, itemsCount: cloudKitService.pendingChanges),
                    at: 0
                )
            } catch {
                lastSyncError = error.localizedDescription
                syncPreferences.recentSyncs.insert(
                    SyncActivityEvent(id: UUID(), type: "Manual Sync", timestamp: Date(), success: false, itemsCount: 0),
                    at: 0
                )
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
                try await cloudKitService.syncAll()
                syncPreferences.recentSyncs.insert(
                    SyncActivityEvent(id: UUID(), type: "Full Sync", timestamp: Date(), success: true, itemsCount: 0),
                    at: 0
                )
            } catch {
                lastSyncError = error.localizedDescription
            }

            await MainActor.run {
                isSyncing = false
            }
        }
    }

    private func resetSyncSettings() {
        syncPreferences = SyncPreferences()
        syncPreferences.save()
    }
}

// MARK: - Supporting Types

private struct SyncPreferences: Equatable {
    // Selective sync
    var syncConversations = true
    var syncSettings = true
    var syncKnowledge = true
    var syncProjects = true
    var syncFavorites = true

    // Data sizes (mock data)
    var conversationsSize = "12.5 MB"
    var settingsSize = "45 KB"
    var knowledgeSize = "8.2 MB"
    var projectsSize = "1.3 MB"

    // Conflict resolution
    var conflictStrategy: SyncConflictStrategy = .keepMostRecent
    var conflictCount = 3
    var conflictHistory: [SyncConflictRecord] = [
        SyncConflictRecord(id: UUID(), itemName: "Meeting Notes", timestamp: Date().addingTimeInterval(-86400), localModified: Date().addingTimeInterval(-90000), cloudModified: Date().addingTimeInterval(-86400), resolution: "Kept cloud version")
    ]

    // Connected devices
    var connectedDevices: [SyncConnectedDevice] = [
        SyncConnectedDevice(id: UUID(), name: "MacBook Pro", model: "MacBook Pro 16\"", type: .mac, lastSync: Date().addingTimeInterval(-300), isCurrentDevice: true, isOnline: true),
        SyncConnectedDevice(id: UUID(), name: "iPhone", model: "iPhone 15 Pro", type: .iPhone, lastSync: Date().addingTimeInterval(-3600), isCurrentDevice: false, isOnline: true),
        SyncConnectedDevice(id: UUID(), name: "iPad Pro", model: "iPad Pro 12.9\"", type: .iPad, lastSync: Date().addingTimeInterval(-7200), isCurrentDevice: false, isOnline: false)
    ]

    // Sync history
    var recentSyncs: [SyncActivityEvent] = [
        SyncActivityEvent(id: UUID(), type: "Conversations", timestamp: Date().addingTimeInterval(-300), success: true, itemsCount: 5),
        SyncActivityEvent(id: UUID(), type: "Settings", timestamp: Date().addingTimeInterval(-600), success: true, itemsCount: 1),
        SyncActivityEvent(id: UUID(), type: "Knowledge", timestamp: Date().addingTimeInterval(-900), success: true, itemsCount: 12)
    ]

    // Advanced
    var backgroundSyncEnabled = true
    var syncOverCellular = false
    var syncFrequency: SyncSettingsFrequency = .realtime

    private static let storageKey = "com.thea.syncPreferences"

    static func load() -> SyncPreferences {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let prefs = try? JSONDecoder().decode(SyncPreferences.self, from: data)
        {
            return prefs
        }
        return SyncPreferences()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

extension SyncPreferences: Codable {}

private enum SyncConflictStrategy: String, Codable {
    case keepLocal
    case keepCloud
    case askEveryTime
    case keepMostRecent
}

private enum SyncSettingsFrequency: String, Codable {
    case realtime
    case fiveMinutes
    case fifteenMinutes
    case hourly
    case manual
}

private struct SyncConflictRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let itemName: String
    let timestamp: Date
    let localModified: Date
    let cloudModified: Date
    let resolution: String
}

private struct SyncConnectedDevice: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let model: String
    let type: SyncDeviceType
    let lastSync: Date
    let isCurrentDevice: Bool
    let isOnline: Bool
}

private enum SyncDeviceType: String, Codable {
    case mac
    case iPhone
    case iPad
    case watch
    case tv
}

private struct SyncActivityEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let type: String
    let timestamp: Date
    let success: Bool
    let itemsCount: Int
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
