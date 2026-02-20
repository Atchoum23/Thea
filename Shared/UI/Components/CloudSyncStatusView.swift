//
//  CloudSyncStatusView.swift
//  Thea
//
//  Compact badge-style CloudKit sync status indicator.
//  Shows sync state with an icon + optional label.
//  Suitable for toolbar, navigation bar, or settings sidebar use.
//

import SwiftUI

// MARK: - CloudSyncStatusView

/// Badge-style sync status indicator that reflects CloudKitService.shared.syncStatus.
/// Displays an SF Symbol icon with colour-coded state (green = synced, blue = syncing,
/// red = error, orange = offline).  Tapping shows a popover with last-sync time and
/// a manual "Sync Now" button.
struct CloudSyncStatusView: View {
    @ObservedObject private var cloudKit = CloudKitService.shared

    /// When `true`, renders as `icon + text`; when `false`, icon only.
    var showLabel: Bool = false

    @State private var isShowingPopover = false
    @State private var isSyncingManually = false

    var body: some View {
        Button {
            isShowingPopover.toggle()
        } label: {
            HStack(spacing: 4) {
                syncIcon
                if showLabel {
                    Text(statusLabel)
                        .font(.theaCaption2)
                        .foregroundStyle(statusColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(statusLabel)
        .accessibilityLabel("CloudKit sync: \(statusLabel)")
        .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
            syncPopoverContent
        }
    }

    // MARK: - Popover Content

    private var syncPopoverContent: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.md) {
            // Header
            HStack(spacing: TheaSpacing.sm) {
                syncIcon
                Text("iCloud Sync")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Status rows
            statusRow(icon: "info.circle", label: "Status", value: statusLabel)

            if let lastSync = cloudKit.lastSyncDate {
                statusRow(icon: "clock", label: "Last sync", value: lastSync.formatted(.relative(presentation: .named)))
            }

            if cloudKit.pendingChanges > 0 {
                statusRow(
                    icon: "tray.full",
                    label: "Pending",
                    value: "\(cloudKit.pendingChanges) change\(cloudKit.pendingChanges == 1 ? "" : "s")"
                )
            }

            statusRow(
                icon: "icloud",
                label: "iCloud",
                value: cloudKit.iCloudAvailable ? "Available" : "Not signed in"
            )

            Divider()

            // Sync Now button
            Button {
                Task {
                    isSyncingManually = true
                    defer { isSyncingManually = false }
                    try? await cloudKit.syncAll()
                }
            } label: {
                Label(
                    isSyncingManually ? "Syncing…" : "Sync Now",
                    systemImage: isSyncingManually ? "arrow.triangle.2.circlepath" : "arrow.triangle.2.circlepath"
                )
                .font(.theaCaption2)
                .symbolEffect(.rotate.byLayer, options: .repeating, value: isSyncingManually)
            }
            .disabled(!cloudKit.iCloudAvailable || !cloudKit.syncEnabled || isSyncingManually)
            .frame(maxWidth: .infinity)
            #if os(macOS)
            .buttonStyle(.borderedProminent)
            #else
            .buttonStyle(.bordered)
            #endif
        }
        .padding(TheaSpacing.lg)
        .frame(minWidth: 220)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var syncIcon: some View {
        Group {
            switch cloudKit.syncStatus {
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .symbolEffect(.rotate.byLayer, options: .repeating)
            default:
                Image(systemName: statusIconName)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(statusColor)
    }

    private func statusRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: TheaSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.theaCaption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.theaCaption2)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Status Properties

    private var statusLabel: String {
        guard cloudKit.syncEnabled else { return "Sync Off" }
        guard cloudKit.iCloudAvailable else { return "No iCloud" }
        switch cloudKit.syncStatus {
        case .idle:          return "Synced"
        case .syncing:       return "Syncing…"
        case .error(let m):  return m.isEmpty ? "Sync Error" : m
        case .offline:       return "Offline"
        }
    }

    private var statusIconName: String {
        guard cloudKit.syncEnabled, cloudKit.iCloudAvailable else { return "icloud.slash" }
        switch cloudKit.syncStatus {
        case .idle:    return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .error:   return "exclamationmark.icloud"
        case .offline: return "icloud.slash"
        }
    }

    private var statusColor: Color {
        guard cloudKit.syncEnabled, cloudKit.iCloudAvailable else { return .secondary }
        switch cloudKit.syncStatus {
        case .idle:    return .green
        case .syncing: return .blue
        case .error:   return .red
        case .offline: return .orange
        }
    }
}

// MARK: - Preview

#Preview("CloudSyncStatusView") {
    HStack(spacing: 20) {
        CloudSyncStatusView()
        CloudSyncStatusView(showLabel: true)
    }
    .padding()
}
