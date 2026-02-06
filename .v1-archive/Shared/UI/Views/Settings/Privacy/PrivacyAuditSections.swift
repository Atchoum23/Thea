//
//  PrivacyAuditSections.swift
//  Thea
//
//  Privacy audit and logging UI components for Privacy Settings
//  Extracted from PrivacySettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Privacy Audit Section

extension PrivacySettingsView {
    var privacyAuditSection: some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy Audit Log")
                        .font(.subheadline)

                    Text("\(privacyConfig.auditLogEntries.count) events recorded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingAuditLog = true
                } label: {
                    Label("View Log", systemImage: "list.bullet.rectangle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            Toggle("Enable Audit Logging", isOn: $privacyConfig.auditLoggingEnabled)

            Text("Track data access and modifications for security review")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Recent activity
            if !privacyConfig.auditLogEntries.isEmpty {
                Divider()

                Text("Recent Activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(privacyConfig.auditLogEntries.prefix(3), id: \.id) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: auditIcon(for: entry.type))
                            .foregroundStyle(auditColor(for: entry.type))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.description)
                                .font(.caption)

                            Text(entry.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    func auditIcon(for type: PrivacyAuditEventType) -> String {
        switch type {
        case .dataAccess: "eye.fill"
        case .dataExport: "square.and.arrow.up"
        case .dataDelete: "trash.fill"
        case .settingsChange: "gearshape.fill"
        case .login: "person.fill"
        case .syncEvent: "arrow.triangle.2.circlepath"
        }
    }

    func auditColor(for type: PrivacyAuditEventType) -> Color {
        switch type {
        case .dataAccess: .blue
        case .dataExport: .green
        case .dataDelete: .red
        case .settingsChange: .orange
        case .login: .purple
        case .syncEvent: .teal
        }
    }
}

// MARK: - Audit Log Sheet

extension PrivacySettingsView {
    var auditLogSheet: some View {
        NavigationStack {
            List {
                if privacyConfig.auditLogEntries.isEmpty {
                    Text("No audit events recorded")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(privacyConfig.auditLogEntries, id: \.id) { entry in
                        HStack(spacing: 12) {
                            Image(systemName: auditIcon(for: entry.type))
                                .foregroundStyle(auditColor(for: entry.type))
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.description)
                                    .font(.body)

                                HStack {
                                    Text(entry.timestamp, style: .date)
                                    Text(entry.timestamp, style: .time)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                if let details = entry.details {
                                    Text(details)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Privacy Audit Log")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingAuditLog = false
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear Log", role: .destructive) {
                        privacyConfig.auditLogEntries = []
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 600, height: 500)
        #endif
    }
}
