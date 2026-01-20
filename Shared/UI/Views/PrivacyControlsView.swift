//
//  PrivacyControlsView.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import SwiftUI

// MARK: - Privacy Controls View

/// Settings view for managing privacy and monitoring preferences
public struct PrivacyControlsView: View {
    @State private var privacyStatus: PrivacyStatus?
    @State private var monitoringConfig = MonitoringConfiguration()
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false

    public init() {}

    public var body: some View {
        Form {
            // Permissions Section
            Section {
                if let status = privacyStatus {
                    ForEach(PrivacyPermission.allCases, id: \.self) { permission in
                        PermissionRow(
                            permission: permission,
                            status: status.permissionStatuses[permission] ?? .unknown,
                            hasConsent: status.consentGiven.contains(permission)
                        )
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            } header: {
                Text("Privacy Permissions")
            } footer: {
                Text("These permissions are required for monitoring features to work.")
            }

            // Monitoring Options Section
            Section {
                ForEach(MonitorType.allCases, id: \.self) { type in
                    Toggle(isOn: binding(for: type)) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.displayName)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: type.icon)
                        }
                    }
                }
            } header: {
                Text("Monitoring Options")
            } footer: {
                Text("Choose which activities to monitor. All data is stored locally and encrypted.")
            }

            // Data Settings Section
            Section {
                Toggle("Encrypt Activity Logs", isOn: $monitoringConfig.encryptLogs)

                Stepper(
                    "Keep data for \(monitoringConfig.retentionDays) days",
                    value: $monitoringConfig.retentionDays,
                    in: 7...365
                )

                Toggle("Sync to iCloud", isOn: $monitoringConfig.syncToCloud)
                    .disabled(true) // Not yet implemented
            } header: {
                Text("Data Storage")
            }

            // Actions Section
            Section {
                Button {
                    Task {
                        await ActivityLogger.shared.cleanup()
                    }
                } label: {
                    Label("Clean Up Old Data", systemImage: "trash")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete All Activity Data", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Data Management")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Privacy & Monitoring")
        .task {
            await loadStatus()
        }
        .onChange(of: monitoringConfig) { _, newValue in
            Task {
                await MonitoringService.shared.updateConfiguration(newValue)
            }
        }
        .confirmationDialog(
            "Delete All Activity Data?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                Task {
                    await ActivityLogger.shared.deleteAllLogs()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all activity logs. This action cannot be undone.")
        }
    }

    // MARK: - Helpers

    private func loadStatus() async {
        privacyStatus = await PrivacyManager.shared.getPrivacyStatus()
        monitoringConfig = await MonitoringService.shared.getConfiguration()
        isLoading = false
    }

    private func binding(for type: MonitorType) -> Binding<Bool> {
        Binding(
            get: { monitoringConfig.enabledMonitors.contains(type) },
            set: { enabled in
                if enabled {
                    monitoringConfig.enabledMonitors.insert(type)
                } else {
                    monitoringConfig.enabledMonitors.remove(type)
                }
            }
        )
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let permission: PrivacyPermission
    let status: PermissionStatus
    let hasConsent: Bool

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(permission.displayName)
                    Text(permission.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: permission.icon)
                    .foregroundStyle(permission.isRequired ? .blue : .secondary)
            }

            Spacer()

            statusBadge
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if status != .granted {
                Task { @MainActor in
                    PrivacyManager.shared.openPrivacySettings(permission)
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            Text(status.displayName)
                .font(.caption)
        }
        .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        case .restricted, .unknown: return .secondary
        }
    }
}

// MARK: - Activity Stats View

public struct ActivityStatsView: View {
    @State private var stats: DailyActivityStats?
    @State private var selectedDate = Date()

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Date Picker
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()

            if let stats = stats {
                // Stats Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatCard(
                        title: "Screen Time",
                        value: stats.formattedScreenTime,
                        icon: "desktopcomputer"
                    )

                    StatCard(
                        title: "Idle Periods",
                        value: "\(stats.idlePeriods)",
                        icon: "moon.zzz"
                    )

                    StatCard(
                        title: "Activities",
                        value: "\(stats.entryCount)",
                        icon: "list.bullet"
                    )

                    StatCard(
                        title: "Top Apps",
                        value: "\(stats.appUsage.count)",
                        icon: "app"
                    )
                }

                // Top Apps List
                if !stats.topApps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Apps")
                            .font(.headline)

                        ForEach(stats.topApps, id: \.0) { app, duration in
                            HStack {
                                Text(app)
                                Spacer()
                                Text(formatDuration(duration))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar",
                    description: Text("No activity data for this date")
                )
            }
        }
        .padding()
        .task(id: selectedDate) {
            stats = await ActivityLogger.shared.getDailyStats(for: selectedDate)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Previews

#Preview("Privacy Controls") {
    NavigationStack {
        PrivacyControlsView()
    }
}

#Preview("Activity Stats") {
    ActivityStatsView()
}
