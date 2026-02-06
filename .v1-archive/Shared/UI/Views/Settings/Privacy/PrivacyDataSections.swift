//
//  PrivacyDataSections.swift
//  Thea
//
//  Data collection, retention, and management UI components for Privacy Settings
//  Extracted from PrivacySettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Data Collection Section

extension PrivacySettingsView {
    var dataCollectionSection: some View {
        Group {
            Toggle("Analytics", isOn: $settingsManager.analyticsEnabled)

            Text("Help improve Thea by sharing anonymous usage data")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Crash Reports", isOn: $privacyConfig.crashReportsEnabled)

            Text("Automatically send crash reports to help fix issues")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Usage Statistics", isOn: $privacyConfig.usageStatisticsEnabled)

            Text("Collect anonymous feature usage to improve the app")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // What we collect
            DisclosureGroup("What We Collect") {
                VStack(alignment: .leading, spacing: 8) {
                    collectionItem(icon: "checkmark.circle.fill", text: "App version and OS version", collected: true)
                    collectionItem(icon: "checkmark.circle.fill", text: "Feature usage counts", collected: settingsManager.analyticsEnabled)
                    collectionItem(icon: "checkmark.circle.fill", text: "Crash logs", collected: privacyConfig.crashReportsEnabled)
                    collectionItem(icon: "xmark.circle.fill", text: "Conversation content", collected: false)
                    collectionItem(icon: "xmark.circle.fill", text: "Personal information", collected: false)
                    collectionItem(icon: "xmark.circle.fill", text: "Location data", collected: false)
                }
                .padding(.vertical, 4)
            }
        }
    }

    func collectionItem(icon: String, text: String, collected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(collected ? .orange : .green)
                .frame(width: 20)

            Text(text)
                .font(.caption)

            Spacer()

            Text(collected ? "Collected" : "Never collected")
                .font(.caption2)
                .foregroundStyle(collected ? .orange : .green)
        }
    }
}

// MARK: - Data Retention Section

extension PrivacySettingsView {
    var dataRetentionSection: some View {
        Group {
            Picker("Retention Period", selection: $privacyConfig.retentionPeriod) {
                Text("7 Days").tag(PrivacyRetentionPeriod.sevenDays)
                Text("30 Days").tag(PrivacyRetentionPeriod.thirtyDays)
                Text("90 Days").tag(PrivacyRetentionPeriod.ninetyDays)
                Text("1 Year").tag(PrivacyRetentionPeriod.oneYear)
                Text("Forever").tag(PrivacyRetentionPeriod.forever)
            }

            Text("Automatically delete conversations older than this period")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Auto-Delete Empty Conversations", isOn: $privacyConfig.autoDeleteEmptyConversations)

            Toggle("Delete Attachments with Conversations", isOn: $privacyConfig.deleteAttachmentsWithConversations)

            Divider()

            // Storage used
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage Used")
                        .font(.subheadline)

                    Text("\(privacyConfig.storageUsed) used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clean Up") {
                    cleanUpStorage()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Data Management Section

extension PrivacySettingsView {
    var dataManagementSection: some View {
        Group {
            // Export
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Your Data")
                        .font(.subheadline)

                    Text("Download all your data in a portable format")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingExportOptions = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }

            if isExporting {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: exportProgress)
                    Text("Exporting... \(Int(exportProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Delete
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delete All Data")
                        .font(.subheadline)

                    Text("Permanently remove all conversations and settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }

            Text("This action cannot be undone. Make sure to export your data first if needed.")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
