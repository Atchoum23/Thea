//
//  SyncStatusIndicator.swift
//  Thea
//
//  Always-visible sync status badge for toolbar display.
//  Shows sync state, active transport, and conflict alerts.
//

import SwiftUI

/// Compact sync status indicator for use in toolbar or navigation bar.
/// Shows current sync state with transport type info on hover/tap.
struct SyncStatusIndicator: View {
    @ObservedObject private var cloudKit = CloudKitService.shared

    var body: some View {
        Menu {
            Section("Sync Status") {
                Label(statusText, systemImage: statusIcon)

                if let lastSync = cloudKit.lastSyncDate {
                    Label("Last sync: \(lastSync, style: .relative) ago", systemImage: "clock")
                }

                if cloudKit.pendingChanges > 0 {
                    Label("\(cloudKit.pendingChanges) pending changes", systemImage: "tray.full")
                }
            }

            Section("Transport") {
                Label(transportText, systemImage: transportIcon)
            }

            Divider()

            Button {
                Task {
                    try? await cloudKit.syncAll()
                }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!cloudKit.syncEnabled || !cloudKit.iCloudAvailable)
        } label: {
            Image(systemName: statusIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(statusColor)
                .font(.body)
                .accessibilityLabel("Sync status: \(statusText)")
        }
    }

    // MARK: - Status Properties

    private var statusText: String {
        guard cloudKit.syncEnabled else { return "Sync Disabled" }
        guard cloudKit.iCloudAvailable else { return "iCloud Unavailable" }

        switch cloudKit.syncStatus {
        case .idle: return "Synced"
        case .syncing: return "Syncing..."
        case .error(let msg): return "Error: \(msg)"
        case .offline: return "Offline"
        }
    }

    private var statusIcon: String {
        guard cloudKit.syncEnabled else { return "icloud.slash" }
        guard cloudKit.iCloudAvailable else { return "icloud.slash" }

        switch cloudKit.syncStatus {
        case .idle: return "checkmark.icloud.fill"
        case .syncing: return "arrow.triangle.2.circlepath.icloud.fill"
        case .error: return "exclamationmark.icloud.fill"
        case .offline: return "icloud.slash"
        }
    }

    private var statusColor: Color {
        guard cloudKit.syncEnabled, cloudKit.iCloudAvailable else { return .secondary }

        switch cloudKit.syncStatus {
        case .idle: return .green
        case .syncing: return .blue
        case .error: return .red
        case .offline: return .orange
        }
    }

    private var transportText: String {
        if !cloudKit.syncEnabled || !cloudKit.iCloudAvailable {
            return "Not connected"
        }
        return "iCloud (CloudKit)"
    }

    private var transportIcon: String {
        if !cloudKit.syncEnabled || !cloudKit.iCloudAvailable {
            return "wifi.slash"
        }
        return "icloud"
    }
}
