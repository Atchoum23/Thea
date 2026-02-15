//
//  NotificationIntelligenceSettingsView.swift
//  Thea
//
//  G2: Settings UI for Cross-Device Notification Intelligence
//  Per-app toggles, auto-action configuration, sync settings.
//
//  Copyright 2026. All rights reserved.
//

import SwiftUI

// MARK: - Notification Intelligence Settings View

struct NotificationIntelligenceSettingsView: View {
    @StateObject private var service = NotificationIntelligenceService.shared

    var body: some View {
        Form {
            // Master toggle
            masterSection

            if service.isEnabled {
                // Auto-action settings
                autoActionSection

                // Sync settings
                syncSection

                // Statistics
                statisticsSection

                // Per-app settings
                perAppSection

                // Recent classified notifications
                recentSection
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Notification Intelligence")
    }

    // MARK: - Master Toggle

    private var masterSection: some View {
        Section {
            Toggle("Enable Notification Intelligence", isOn: Binding(
                get: { service.isEnabled },
                set: { newValue in
                    if newValue {
                        Task { await service.enable() }
                    } else {
                        service.disable()
                    }
                }
            ))

            if service.isEnabled {
                Label(
                    "Thea reads and classifies notifications to suggest actions and sync state across devices.",
                    systemImage: "bell.badge"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Notification Intelligence")
        }
    }

    // MARK: - Auto-Action

    private var autoActionSection: some View {
        Section {
            Toggle("Auto-Action on Notifications", isOn: $service.autoActionEnabled)

            if service.autoActionEnabled {
                VStack(alignment: .leading, spacing: TheaSpacing.xs) {
                    Text("Confidence Threshold: \(Int(service.autoActionConfidenceThreshold * 100))%")
                        .font(.subheadline)
                    Slider(
                        value: $service.autoActionConfidenceThreshold,
                        in: 0.5...1.0,
                        step: 0.05
                    )
                }

                Label(
                    "Only actions above this confidence level will execute without approval.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Auto-Actions")
        } footer: {
            Text("When enabled, Thea automatically acts on notifications that meet the confidence threshold (e.g., logging deliveries, preparing meeting briefings).")
        }
    }

    // MARK: - Sync

    private var syncSection: some View {
        Section {
            Toggle("Sync Notification State", isOn: $service.syncNotificationState)

            if service.syncNotificationState {
                HStack {
                    Text("Synced Clearances")
                    Spacer()
                    Text("\(service.syncedClearances.count)")
                        .foregroundStyle(.secondary)
                }

                Button("Refresh Sync") {
                    Task { await service.fetchSyncedClearances() }
                }
            }
        } header: {
            Text("Cross-Device Sync")
        } footer: {
            Text("When enabled, clearing a notification on one device also clears it on all other devices via iCloud.")
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        Section {
            let stats = service.statistics

            HStack {
                StatCard(title: "Classified", value: "\(stats.totalClassified)", icon: "tray.full.fill", color: .blue)
                StatCard(title: "Cleared", value: "\(stats.totalCleared)", icon: "checkmark.circle.fill", color: .green)
                StatCard(title: "Actioned", value: "\(stats.totalActioned)", icon: "bolt.fill", color: .orange)
            }

            if !stats.byUrgency.isEmpty {
                VStack(alignment: .leading, spacing: TheaSpacing.xs) {
                    Text("By Urgency")
                        .font(.subheadline.bold())
                    ForEach(NotificationUrgency.allCases.reversed(), id: \.self) { urgency in
                        if let count = stats.byUrgency[urgency], count > 0 {
                            HStack {
                                Image(systemName: urgency.icon)
                                    .foregroundStyle(urgencyColor(urgency))
                                Text(urgency.displayName)
                                Spacer()
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Statistics")
        }
    }

    // MARK: - Per-App Settings

    private var perAppSection: some View {
        Section {
            if service.perAppSettings.isEmpty {
                Text("No app-specific settings configured yet.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(Array(service.perAppSettings.keys.sorted()), id: \.self) { appId in
                    if let settings = service.perAppSettings[appId] {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(appDisplayName(appId))
                                    .font(.body)
                                Text(appId)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !settings.enabled {
                                Text("Muted")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            if settings.autoActionsEnabled {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Per-App Settings")
        } footer: {
            Text("App-specific settings are created automatically as notifications are classified.")
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        Section {
            let recent = Array(service.classifiedNotifications.suffix(10).reversed())
            if recent.isEmpty {
                Text("No notifications classified yet.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(recent) { notif in
                    HStack(spacing: TheaSpacing.sm) {
                        Image(systemName: notif.urgency.icon)
                            .foregroundStyle(urgencyColor(notif.urgency))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(notif.title ?? appDisplayName(notif.appIdentifier))
                                .font(.subheadline)
                                .lineLimit(1)
                            if let body = notif.body {
                                Text(body)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Image(systemName: notif.category.icon)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notif.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if notif.isCleared {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                }
            }
        } header: {
            Text("Recent Notifications")
        }
    }

    // MARK: - Helpers

    private func urgencyColor(_ urgency: NotificationUrgency) -> Color {
        switch urgency {
        case .critical: return Color.theaError
        case .high: return Color.theaWarning
        case .medium: return Color.theaPrimaryDefault
        case .low: return .secondary
        }
    }

    private func appDisplayName(_ bundleId: String) -> String {
        let components = bundleId.components(separatedBy: ".")
        return components.last?.capitalized ?? bundleId
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: TheaSpacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(TheaSpacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.md))
    }
}
