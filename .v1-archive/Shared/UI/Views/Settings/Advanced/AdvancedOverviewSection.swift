//
//  AdvancedOverviewSection.swift
//  Thea
//
//  System overview UI section for AdvancedSettingsView
//  Extracted from AdvancedSettingsView.swift for better code organization
//

import SwiftUI

// MARK: - System Overview Section

extension AdvancedSettingsView {
    var systemOverview: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            HStack(spacing: 16) {
                overviewCard(
                    title: "Debug Mode",
                    value: settingsManager.debugMode ? "On" : "Off",
                    icon: "ladybug.fill",
                    color: settingsManager.debugMode ? .orange : .secondary
                )

                overviewCard(
                    title: "Memory",
                    value: memoryUsage,
                    icon: "memorychip",
                    color: .blue
                )

                overviewCard(
                    title: "Cache",
                    value: cacheSize,
                    icon: "internaldrive",
                    color: .purple
                )

                overviewCard(
                    title: "Logs",
                    value: "\(advancedConfig.logEntryCount)",
                    icon: "doc.text",
                    color: .green
                )
            }
            #else
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                overviewCard(
                    title: "Debug Mode",
                    value: settingsManager.debugMode ? "On" : "Off",
                    icon: "ladybug.fill",
                    color: settingsManager.debugMode ? .orange : .secondary
                )

                overviewCard(
                    title: "Memory",
                    value: memoryUsage,
                    icon: "memorychip",
                    color: .blue
                )

                overviewCard(
                    title: "Cache",
                    value: cacheSize,
                    icon: "internaldrive",
                    color: .purple
                )

                overviewCard(
                    title: "Logs",
                    value: "\(advancedConfig.logEntryCount)",
                    icon: "doc.text",
                    color: .green
                )
            }
            #endif

            // Version info
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thea \(advancedConfig.appVersion)")
                        .font(.caption)
                        .fontWeight(.medium)

                    Text("Build \(advancedConfig.buildNumber)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(advancedConfig.platform)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
