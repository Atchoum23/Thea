import SwiftUI

struct iOSPermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var permissionsManager = PermissionsManager.shared
    @State private var expandedCategories: Set<PermissionCategory> = Set(PermissionCategory.allCases)
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            List {
                overviewSection

                ForEach(permissionsManager.availableCategories) { category in
                    Section {
                        ForEach(permissionsManager.permissions(for: category), id: \.id) { permission in
                            iOSPermissionRow(
                                permission: permission,
                                onRequest: {
                                    Task {
                                        _ = await permissionsManager.requestPermission(for: permission.type)
                                    }
                                },
                                onOpenSettings: {
                                    permissionsManager.openSystemSettings()
                                }
                            )
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            }
            .refreshable {
                await permissionsManager.refreshAllPermissions()
            }
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var overviewSection: some View {
        Section {
            HStack(spacing: 16) {
                VStack {
                    Text("\(permissionsManager.allPermissions.filter { $0.status == .authorized }.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("Granted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text("\(permissionsManager.allPermissions.filter { $0.status == .denied }.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                    Text("Denied")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text("\(permissionsManager.allPermissions.filter { $0.status == .notDetermined }.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.gray)
                    Text("Not Set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)

            Button {
                permissionsManager.openSystemSettings()
            } label: {
                Label("Open Settings", systemImage: "gear")
            }
        } footer: {
            if let lastRefresh = permissionsManager.lastRefreshDate {
                Text("Last updated \(lastRefresh, style: .relative) ago. Pull to refresh.")
            }
        }
    }
}

struct iOSPermissionRow: View {
    let permission: PermissionInfo
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: permission.status.icon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.type.rawValue)
                    .font(.subheadline)

                Text(permission.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if permission.canRequest {
                Button("Allow", action: onRequest)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else if permission.canOpenSettings {
                Button(action: onOpenSettings) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text(permission.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch permission.status {
        case .authorized: .green
        case .denied: .red
        case .restricted: .orange
        case .limited: .yellow
        case .provisional: .blue
        case .notDetermined, .notAvailable, .unknown: .gray
        }
    }
}
