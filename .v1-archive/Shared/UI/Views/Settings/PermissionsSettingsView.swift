//
//  PermissionsSettingsView.swift
//  Thea
//
//  Comprehensive permissions management across all Apple platforms
//  Based on 2026 best practices
//

import SwiftUI

// MARK: - Permissions Settings View

struct PermissionsSettingsView: View {
    @State private var permissionsManager = PermissionsManager.shared
    @State private var expandedCategories: Set<PermissionCategory> = []
    @State private var isRefreshing = false
    @State private var showingRequestAlert = false
    @State private var requestAlertMessage = ""

    var body: some View {
        Form {
            overviewSection
            permissionCategoriesSection
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            // Expand all categories by default
            expandedCategories = Set(PermissionCategory.allCases)
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        Text("App Permissions")
                            .font(.headline)
                    }

                    Text("Manage what Thea can access on your device. All permissions respect your privacy choices.")
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
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshing)
            }

            // Permission summary
            HStack(spacing: 20) {
                PermissionStatView(
                    count: permissionsManager.allPermissions.filter { $0.status == .authorized }.count,
                    total: permissionsManager.allPermissions.count,
                    label: "Authorized",
                    color: .green
                )

                PermissionStatView(
                    count: permissionsManager.allPermissions.filter { $0.status == .denied }.count,
                    total: permissionsManager.allPermissions.count,
                    label: "Denied",
                    color: .red
                )

                PermissionStatView(
                    count: permissionsManager.allPermissions.filter { $0.status == .notDetermined }.count,
                    total: permissionsManager.allPermissions.count,
                    label: "Not Set",
                    color: .gray
                )
            }
            .padding(.vertical, 8)

            if let lastRefresh = permissionsManager.lastRefreshDate {
                Text("Last checked: \(lastRefresh, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } header: {
            Text("Overview")
        }
    }

    // MARK: - Permission Categories Section

    private var permissionCategoriesSection: some View {
        ForEach(permissionsManager.availableCategories) { category in
            Section {
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedCategories.contains(category) },
                    set: { isExpanded in
                        if isExpanded {
                            expandedCategories.insert(category)
                        } else {
                            expandedCategories.remove(category)
                        }
                    }
                )) {
                    ForEach(permissionsManager.permissions(for: category), id: \.id) { permission in
                        PermissionRowView(
                            permission: permission,
                            onRequest: {
                                Task {
                                    await requestPermission(permission.type)
                                }
                            },
                            onOpenSettings: {
                                permissionsManager.openSettings(for: permission.type)
                            }
                        )
                    }
                } label: {
                    categoryHeader(category)
                }
            }
        }
    }

    private func categoryHeader(_ category: PermissionCategory) -> some View {
        HStack {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(category.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            // Category summary badge
            let categoryPermissions = permissionsManager.permissions(for: category)
            let authorizedCount = categoryPermissions.filter { $0.status == .authorized }.count

            Text("\(authorizedCount)/\(categoryPermissions.count)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(authorizedCount == categoryPermissions.count ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .foregroundStyle(authorizedCount == categoryPermissions.count ? .green : .secondary)
                .cornerRadius(8)
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

    private func requestPermission(_ type: PermissionType) async {
        let status = await permissionsManager.requestPermission(for: type)

        if status == .denied {
            requestAlertMessage = "Permission was denied. You can change this in System Settings."
            showingRequestAlert = true
        }
    }
}

// MARK: - Permission Row View

private struct PermissionRowView: View {
    let permission: PermissionInfo
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: permission.status.icon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 24)

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
            if permission.canRequest {
                Button("Request") {
                    onRequest()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else if permission.canOpenSettings {
                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
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
        }
    }
}

// MARK: - Permission Stat View

private struct PermissionStatView: View {
    let count: Int
    let total: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Actions Section (macOS specific)

#if os(macOS)
    struct MacPermissionsQuickActionsView: View {
        @State private var permissionsManager = PermissionsManager.shared

        var body: some View {
            Section("Quick Actions") {
                HStack(spacing: 12) {
                    PermissionQuickActionButton(
                        title: "Privacy Settings",
                        icon: "hand.raised.fill"
                    )                        {
                            permissionsManager.openSystemSettings()
                        }

                    PermissionQuickActionButton(
                        title: "Accessibility",
                        icon: "accessibility"
                    )                        {
                            permissionsManager.openSettings(for: .accessibility)
                        }

                    PermissionQuickActionButton(
                        title: "Full Disk Access",
                        icon: "internaldrive"
                    )                        {
                            permissionsManager.openSettings(for: .fullDiskAccess)
                        }

                    PermissionQuickActionButton(
                        title: "Screen Recording",
                        icon: "rectangle.dashed.badge.record"
                    )                        {
                            permissionsManager.openSettings(for: .screenRecording)
                        }
                }
            }
        }
    }

    private struct PermissionQuickActionButton: View {
        let title: String
        let icon: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title2)
                    Text(title)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }
#endif

// MARK: - Preview

#Preview {
    PermissionsSettingsView()
        .frame(width: 600, height: 800)
}
