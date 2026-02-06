//
//  AdvancedLoggingSection.swift
//  Thea
//
//  Logging UI section for AdvancedSettingsView
//  Extracted from AdvancedSettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Logging Section

extension AdvancedSettingsView {
    var loggingSection: some View {
        Group {
            Picker("Log Level", selection: $advancedConfig.logLevel) {
                Text("None").tag(AdvancedLogLevel.none)
                Text("Error").tag(AdvancedLogLevel.error)
                Text("Warning").tag(AdvancedLogLevel.warning)
                Text("Info").tag(AdvancedLogLevel.info)
                Text("Debug").tag(AdvancedLogLevel.debug)
                Text("Verbose").tag(AdvancedLogLevel.verbose)
            }

            Toggle("Log API Requests", isOn: $advancedConfig.logAPIRequests)

            Toggle("Log API Responses", isOn: $advancedConfig.logAPIResponses)

            Text("API logging may include sensitive data. Use with caution.")
                .font(.caption)
                .foregroundStyle(.orange)

            Toggle("Log to File", isOn: $advancedConfig.logToFile)

            if advancedConfig.logToFile {
                HStack {
                    Text("Log File Size")
                    Spacer()
                    Text("\(advancedConfig.logFileSize)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Max Log Files")
                    Spacer()
                    Stepper("\(advancedConfig.maxLogFiles)", value: $advancedConfig.maxLogFiles, in: 1 ... 10)
                }
            }

            Divider()

            HStack {
                Button {
                    showingLogViewer = true
                } label: {
                    Label("View Logs", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)

                Button {
                    clearLogs()
                } label: {
                    Label("Clear Logs", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }
}
