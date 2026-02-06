//
//  AdvancedExpDiagSections.swift
//  Thea
//
//  Experimental and Diagnostics UI sections for AdvancedSettingsView
//  Extracted from AdvancedSettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Experimental Section

extension AdvancedSettingsView {
    var experimentalSection: some View {
        Group {
            Toggle("Enable Beta Features", isOn: $settingsManager.betaFeaturesEnabled)

            Text("Beta features may be unstable and are subject to change")
                .font(.caption)
                .foregroundStyle(.orange)

            Divider()

            Toggle("Experimental UI", isOn: $advancedConfig.experimentalUI)

            Toggle("Advanced Code Editor", isOn: $advancedConfig.advancedCodeEditor)

            Toggle("Multi-Model Conversations", isOn: $advancedConfig.multiModelConversations)

            Toggle("Parallel Processing", isOn: $advancedConfig.parallelProcessing)

            Text("Process multiple requests simultaneously")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Feature flags
            DisclosureGroup("Feature Flags") {
                ForEach(advancedConfig.featureFlags.sorted { $0.key < $1.key }, id: \.key) { key, value in
                    HStack {
                        Text(key)
                            .font(.caption)

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { value },
                            set: { advancedConfig.featureFlags[key] = $0 }
                        ))
                        .labelsHidden()
                    }
                }
            }
        }
    }
}

// MARK: - Diagnostics Section

extension AdvancedSettingsView {
    var diagnosticsSection: some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Diagnostic Report")
                        .font(.subheadline)

                    Text("Generate a detailed report for troubleshooting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    generateDiagnosticReport()
                } label: {
                    if isGeneratingReport {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Generate", systemImage: "doc.badge.gearshape")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingReport)
            }

            Divider()

            // System info
            VStack(alignment: .leading, spacing: 8) {
                Text("System Information")
                    .font(.subheadline)
                    .fontWeight(.medium)

                systemInfoRow(title: "Device", value: advancedConfig.deviceModel)
                systemInfoRow(title: "OS Version", value: advancedConfig.osVersion)
                systemInfoRow(title: "App Version", value: advancedConfig.appVersion)
                systemInfoRow(title: "Build", value: advancedConfig.buildNumber)
                systemInfoRow(title: "Free Storage", value: advancedConfig.freeStorage)
                systemInfoRow(title: "Total Memory", value: advancedConfig.totalMemory)
            }

            Divider()

            // Copy system info
            Button {
                copySystemInfo()
            } label: {
                Label("Copy System Info", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.bordered)
        }
    }

    func systemInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)

            Spacer()

            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
