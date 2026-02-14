//
//  PermissionsSettingsView.swift
//  Thea
//
//  Permissions management matching macOS Privacy & Security layout
//

import SwiftUI

// MARK: - Permissions Settings View

struct PermissionsSettingsView: View {
    @State private var permissionsManager = PermissionsManager.shared
    @State private var isRefreshing = false
    @State private var showingRequestAlert = false
    @State private var requestAlertMessage = ""

    var body: some View {
        Form {
            headerSection
            permissionListSection
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        Text("System Permissions")
                            .font(.headline)
                    }

                    Text("Thea needs certain permissions to function fully. "
                         + "Grant or check status below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    refreshPermissions()
                } label: {
                    HStack(spacing: 4) {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .accessibilityHidden(true)
                        }
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshing)
            }
        }
    }

    // MARK: - Permission List Section

    private var permissionListSection: some View {
        ForEach(permissionsManager.availableCategories) { category in
            Section {
                ForEach(permissionsManager.permissions(for: category), id: \.id) { permission in
                    PermissionRowView(permission: permission) {
                        Task {
                            await handlePermissionAction(permission)
                        }
                    }
                }
            } header: {
                Text(category.rawValue)
            }
        }
    }

    // MARK: - Actions

    private func refreshPermissions() {
        isRefreshing = true
        Task {
            await permissionsManager.refreshAllPermissions()
            isRefreshing = false
        }
    }

    /// Unified action handler: requests permission programmatically if possible,
    /// otherwise opens the relevant System Settings pane.
    private func handlePermissionAction(_ permission: PermissionInfo) async {
        if permission.type.canRequestProgrammatically && permission.status == .notDetermined {
            let status = await permissionsManager.requestPermission(for: permission.type)
            if status == .denied {
                requestAlertMessage =
                    "\(permission.type.rawValue) was denied. "
                    + "You can change this in System Settings."
                showingRequestAlert = true
            }
        } else {
            // For denied, restricted, unknown, or non-requestable permissions:
            // open System Settings to the correct pane
            permissionsManager.openSettings(for: permission.type)
        }
    }
}

// MARK: - Permission Row View

private struct PermissionRowView: View {
    let permission: PermissionInfo
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Permission type icon
            Image(systemName: permission.type.icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24)
                .accessibilityHidden(true)

            // Permission info
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(permission.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Status badge
            Text(permission.status.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .cornerRadius(4)

            // Action button
            actionButton
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(permission.type.rawValue), \(permission.status.rawValue)")
    }

    @ViewBuilder
    private var actionButton: some View {
        if permission.canRequest {
            // Permission can be requested programmatically
            Button("Request") {
                onAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else if permission.status != .authorized && permission.status != .notAvailable {
            // Open System Settings for this permission
            Button {
                onAction()
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open in System Settings")
            .accessibilityLabel("Open in System Settings")
        }
    }

    private var iconColor: Color {
        switch permission.status {
        case .authorized: return .green
        case .denied: return .red
        case .restricted: return .orange
        default: return .secondary
        }
    }

    private var statusColor: Color {
        switch permission.status {
        case .authorized: return .green
        case .denied: return .red
        case .restricted: return .orange
        case .limited: return .yellow
        case .provisional: return .blue
        case .notDetermined: return .gray
        case .notAvailable: return .gray
        case .unknown: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    PermissionsSettingsView()
        .frame(width: 600, height: 800)
}
