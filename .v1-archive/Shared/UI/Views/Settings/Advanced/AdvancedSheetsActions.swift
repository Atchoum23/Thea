//
//  AdvancedSheetsActions.swift
//  Thea
//
//  Sheet views and action methods for AdvancedSettingsView
//  Extracted from AdvancedSettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Diagnostic Report Sheet

extension AdvancedSettingsView {
    var diagnosticReportSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Diagnostic Report")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Generated: \(Date(), style: .date) \(Date(), style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    Group {
                        Text("System Information")
                            .font(.headline)

                        Text("""
                        Device: \(advancedConfig.deviceModel)
                        OS: \(advancedConfig.osVersion)
                        App: \(advancedConfig.appVersion) (\(advancedConfig.buildNumber))
                        Memory: \(advancedConfig.totalMemory)
                        Storage: \(advancedConfig.freeStorage) free
                        """)
                        .font(.system(.body, design: .monospaced))
                    }

                    Divider()

                    Group {
                        Text("Configuration")
                            .font(.headline)

                        Text("""
                        Debug Mode: \(settingsManager.debugMode ? "Enabled" : "Disabled")
                        Beta Features: \(settingsManager.betaFeaturesEnabled ? "Enabled" : "Disabled")
                        Log Level: \(advancedConfig.logLevel.rawValue)
                        Cache Size: \(cacheSize)
                        """)
                        .font(.system(.body, design: .monospaced))
                    }

                    Divider()

                    Group {
                        Text("Recent Errors")
                            .font(.headline)

                        if advancedConfig.recentErrors.isEmpty {
                            Text("No recent errors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(advancedConfig.recentErrors, id: \.timestamp) { error in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(error.message)
                                        .font(.system(.body, design: .monospaced))

                                    Text(error.timestamp, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Diagnostic Report")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingDiagnosticReport = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: generateReportText())
                }
            }
        }
        #if os(macOS)
        .frame(width: 600, height: 600)
        #endif
    }
}

// MARK: - Log Viewer Sheet

extension AdvancedSettingsView {
    var logViewerSheet: some View {
        NavigationStack {
            List {
                ForEach(advancedConfig.logEntries.reversed(), id: \.timestamp) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: logLevelIcon(entry.level))
                                .foregroundStyle(logLevelColor(entry.level))

                            Text(entry.level.rawValue.uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(logLevelColor(entry.level))

                            Spacer()

                            Text(entry.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(entry.message)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3)

                        if let source = entry.source {
                            Text(source)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Log Viewer")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingLogViewer = false
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear", role: .destructive) {
                        clearLogs()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 700, height: 600)
        #endif
    }

    func logLevelIcon(_ level: AdvancedLogLevel) -> String {
        switch level {
        case .none: "circle"
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case .debug: "ladybug.fill"
        case .verbose: "text.alignleft"
        }
    }

    func logLevelColor(_ level: AdvancedLogLevel) -> Color {
        switch level {
        case .none: .secondary
        case .error: .red
        case .warning: .orange
        case .info: .blue
        case .debug: .purple
        case .verbose: .secondary
        }
    }
}

// MARK: - Actions

extension AdvancedSettingsView {
    func calculateCacheSize() {
        // Simulate cache calculation
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                cacheSize = "~\(Int.random(in: 20...150)) MB"
            }
        }
    }

    func calculateMemoryUsage() {
        // Simulate memory calculation
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                memoryUsage = "\(Int.random(in: 80...300)) MB"
            }
        }
    }

    func clearCache() {
        cacheSize = "0 MB"
        advancedConfig.apiCacheSize = "0 MB"
        advancedConfig.modelCacheSize = "0 MB"
        advancedConfig.imageCacheSize = "0 MB"
        advancedConfig.tempCacheSize = "0 MB"
    }

    func clearLogs() {
        advancedConfig.logEntries = []
        advancedConfig.logEntryCount = 0
    }

    func generateDiagnosticReport() {
        isGeneratingReport = true

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                isGeneratingReport = false
                showingDiagnosticReport = true
            }
        }
    }

    func generateReportText() -> String {
        """
        THEA DIAGNOSTIC REPORT
        Generated: \(Date())

        SYSTEM INFORMATION
        Device: \(advancedConfig.deviceModel)
        OS: \(advancedConfig.osVersion)
        App: \(advancedConfig.appVersion) (\(advancedConfig.buildNumber))
        Memory: \(advancedConfig.totalMemory)
        Storage: \(advancedConfig.freeStorage) free

        CONFIGURATION
        Debug Mode: \(settingsManager.debugMode ? "Enabled" : "Disabled")
        Beta Features: \(settingsManager.betaFeaturesEnabled ? "Enabled" : "Disabled")
        Log Level: \(advancedConfig.logLevel.rawValue)
        Cache Size: \(cacheSize)
        """
    }

    func copySystemInfo() {
        let info = generateReportText()
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
        #else
        UIPasteboard.general.string = info
        #endif
    }

    func resetAdvancedSettings() {
        advancedConfig = AdvancedSettingsConfiguration()
        advancedConfig.save()
    }
}
