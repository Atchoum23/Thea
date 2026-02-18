//
//  SyncStatusIndicator.swift
//  Thea
//
//  Always-visible sync status badge for toolbar display.
//  Shows sync state, active transport, and conflict alerts.
//

import SwiftUI

/// Compact sync status indicator for use in toolbar or navigation bar.
/// Shows current sync state with transport type from SmartTransportManager.
struct SyncStatusIndicator: View {
    @ObservedObject private var cloudKit = CloudKitService.shared

    @State private var activeTransport: TheaTransport = .cloudKit
    @State private var transportSummary: [(transport: TheaTransport, available: Bool, latency: Double?, active: Bool)] = []
    @State private var isProbing = false
    @State private var syncErrorMessage: String?
    @State private var showSyncError = false

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

            Section("Transport: \(activeTransport.displayName)") {
                ForEach(transportSummary, id: \.transport) { item in
                    Label {
                        Text(transportLabel(for: item))
                    } icon: {
                        Image(systemName: item.transport.sfSymbol)
                    }
                }
            }

            Divider()

            Button {
                Task {
                    isProbing = true
                    defer { isProbing = false }
                    await refreshTransportInfo()
                }
            } label: {
                Label(isProbing ? "Probing..." : "Probe Transports", systemImage: "antenna.radiowaves.left.and.right")
            }
            .disabled(isProbing)

            Button {
                Task {
                    do {
                        try await cloudKit.syncAll()
                    } catch {
                        syncErrorMessage = "Sync failed: \(error.localizedDescription)"
                        showSyncError = true
                    }
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
        .task {
            await refreshTransportInfo()
        }
        .alert("Sync Error", isPresented: $showSyncError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncErrorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Transport Refresh

    private func refreshTransportInfo() async {
        let transport = await SmartTransportManager.shared.probeAndSelect()
        let summary = await SmartTransportManager.shared.transportSummary()
        await MainActor.run {
            activeTransport = transport
            transportSummary = summary
        }
    }

    private func transportLabel(for item: (transport: TheaTransport, available: Bool, latency: Double?, active: Bool)) -> String {
        var label = item.transport.displayName
        if item.active {
            label += " (active)"
        }
        if let latency = item.latency {
            label += " — \(String(format: "%.0f", latency))ms"
        }
        if !item.available {
            label += " — unavailable"
        }
        return label
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
        case .idle: return activeTransport == .cloudKit ? "checkmark.icloud.fill" : "checkmark.circle.fill"
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
}
