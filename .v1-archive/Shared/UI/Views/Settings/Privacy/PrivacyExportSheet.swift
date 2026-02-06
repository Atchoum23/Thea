//
//  PrivacyExportSheet.swift
//  Thea
//
//  Export options sheet for Privacy Settings
//  Extracted from PrivacySettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Export Options Sheet

extension PrivacySettingsView {
    var exportOptionsSheet: some View {
        NavigationStack {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $privacyConfig.exportFormat) {
                        Text("JSON").tag(PrivacyExportFormat.json)
                        Text("CSV").tag(PrivacyExportFormat.csv)
                        Text("Encrypted Archive").tag(PrivacyExportFormat.encrypted)
                    }
                    .pickerStyle(.inline)
                }

                Section("What to Export") {
                    Toggle("Conversations", isOn: $privacyConfig.exportConversations)
                    Toggle("Settings", isOn: $privacyConfig.exportSettings)
                    Toggle("Knowledge Base", isOn: $privacyConfig.exportKnowledge)
                    Toggle("Projects", isOn: $privacyConfig.exportProjects)
                }

                Section("Options") {
                    if privacyConfig.exportFormat == .encrypted {
                        Toggle("Include Encryption Key", isOn: $privacyConfig.includeEncryptionKey)

                        Text("The encryption key will be required to import this data later")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Include Attachments", isOn: $privacyConfig.includeAttachments)

                    Toggle("Include Metadata", isOn: $privacyConfig.includeMetadata)
                }

                Section {
                    Button {
                        startExport()
                        showingExportOptions = false
                    } label: {
                        HStack {
                            Spacer()
                            Text("Start Export")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Export Data")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingExportOptions = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
    }
}
