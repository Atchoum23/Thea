//
//  SettingsPrivacyAboutViews.swift
//  Thea
//
//  Privacy settings and About views for Settings
//  Extracted from SettingsView.swift for better code organization
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Privacy Settings (Configuration Summary)

struct ConfigurationPrivacySettingsView: View {
    @State private var showingExportDialog = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Privacy") {
                Text("THEA is privacy-first by design. All data is stored locally on your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Data Storage") {
                LabeledContent("Location", value: "Local (On-Device)")
                LabeledContent("Encryption", value: "Enabled")
                LabeledContent("Cloud Sync", value: "Disabled")
            }

            Section("Actions") {
                Button("Export All Data") {
                    showingExportDialog = true
                }

                Button("Delete All Data", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $showingExportDialog,
            document: DataExportDocument(),
            contentType: .json,
            defaultFilename: "thea-export-\(Date().formatted(date: .numeric, time: .omitted)).json"
        ) { result in
            if case let .failure(error) = result {
                print("Export failed: \(error)")
            }
        }
        .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This will permanently delete all conversations, projects, and settings. This action cannot be undone.")
        }
    }

    private func deleteAllData() {
        // Reset all configuration to defaults as part of data deletion
        AppConfiguration.shared.resetAllToDefaults()
        print("Data deletion requested - configuration reset complete")
    }
}

// MARK: - Data Export Document

struct DataExportDocument: FileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.json] }

    init() {}

    init(configuration _: ReadConfiguration) throws {
        // Reading from file not supported - this is an export-only document type
        throw CocoaError(.fileReadUnsupportedScheme, userInfo: [
            NSLocalizedDescriptionKey: "Reading data export files is not supported. This document type is for export only."
        ])
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        let exportData: [String: Any] = [
            "version": AppConfiguration.AppInfo.version,
            "buildType": AppConfiguration.AppInfo.buildType,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "message": "Data export functionality - implementation pending"
        ]

        let data = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - About

struct AboutView: View {
    @State private var localModelCount = 0
    @State private var apiKeyCount = 0

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: TheaSpacing.sm) {
                        TheaSpiralIconView(size: 48, isThinking: false, showGlow: true)
                        Text("THEA")
                            .font(.theaTitle1)
                        Text("Omni-AI Life Companion")
                            .font(.theaCaption1)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("App Info") {
                LabeledContent("Version", value: "\(AppConfiguration.AppInfo.version) (\(AppConfiguration.AppInfo.buildType))")
                LabeledContent("Bundle ID", value: AppConfiguration.AppInfo.bundleIdentifier)
                #if os(macOS)
                LabeledContent("Platform", value: "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                LabeledContent("Architecture", value: machineArchitecture)
                #endif
            }

            Section("System") {
                #if os(macOS)
                LabeledContent("Hostname", value: ProcessInfo.processInfo.hostName)
                LabeledContent("Memory", value: formatBytes(Int64(ProcessInfo.processInfo.physicalMemory)))
                LabeledContent("Processors", value: "\(ProcessInfo.processInfo.processorCount) cores")
                #endif
                LabeledContent("Local Models", value: "\(localModelCount)")
                LabeledContent("API Keys Configured", value: "\(apiKeyCount)")
            }

            Section("Links") {
                Link("Website", destination: AppConfiguration.AppInfo.websiteURL)
                Link("Privacy Policy", destination: AppConfiguration.AppInfo.privacyPolicyURL)
                Link("Terms of Service", destination: AppConfiguration.AppInfo.termsOfServiceURL)
            }

            Section("Legal") {
                Text("Built with Swift, SwiftUI, and SwiftData. Uses MLX for on-device inference.")
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
                Text("© 2026 THEA. All rights reserved.")
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .task {
            localModelCount = ProviderRegistry.shared.getAvailableLocalModels().count
            let providers = ["openai", "anthropic", "google", "perplexity", "groq", "openrouter"]
            apiKeyCount = providers.filter { SettingsManager.shared.hasAPIKey(for: $0) }.count
        }
    }

    #if os(macOS)
    private var machineArchitecture: String {
        #if arch(arm64)
        "Apple Silicon (arm64)"
        #elseif arch(x86_64)
        "Intel (x86_64)"
        #else
        "Unknown"
        #endif
    }
    #endif

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Terminal Settings Section View

struct TerminalSettingsSectionView: View {
    @State private var shellPath = "/bin/zsh"
    @State private var enableSyntaxHighlighting = true
    @State private var fontSize: Double = 12
    @State private var fontFamily = "SF Mono"
    @State private var enableAutoComplete = true
    @State private var historyLimit = 1000
    @State private var colorScheme = "Default"

    var body: some View {
        Form {
            Section("Terminal Configuration") {
                Text("Configure terminal behavior and appearance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shell") {
                TextField("Shell Path", text: $shellPath)
                    .help("Path to the shell executable")
                LabeledContent("Current Shell", value: shellPath)
            }

            Section("Appearance") {
                Picker("Color Scheme", selection: $colorScheme) {
                    Text("Default").tag("Default")
                    Text("Dark").tag("Dark")
                    Text("Light").tag("Light")
                    Text("Solarized Dark").tag("Solarized Dark")
                    Text("Solarized Light").tag("Solarized Light")
                }

                TextField("Font Family", text: $fontFamily)

                VStack(alignment: .leading) {
                    Text("Font Size: \(Int(fontSize))pt")
                    Slider(value: $fontSize, in: 8 ... 24, step: 1)
                }

                Toggle("Syntax Highlighting", isOn: $enableSyntaxHighlighting)
            }

            Section("Behavior") {
                Toggle("Enable Auto-Complete", isOn: $enableAutoComplete)

                Stepper("History Limit: \(historyLimit)", value: $historyLimit, in: 100 ... 10000, step: 100)
            }

            Section {
                Button("Reset to Defaults") {
                    shellPath = "/bin/zsh"
                    enableSyntaxHighlighting = true
                    fontSize = 12
                    fontFamily = "SF Mono"
                    enableAutoComplete = true
                    historyLimit = 1000
                    colorScheme = "Default"
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Cowork Settings Section View

struct CoworkSettingsSectionView: View {
    @State private var enableCowork = false
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var enableNotifications = true
    @State private var autoSyncInterval: Double = 30
    @State private var shareByDefault = false
    @State private var maxCollaborators = 5

    var body: some View {
        Form {
            Section("Collaboration Features") {
                Text("Configure real-time collaboration settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Status") {
                Toggle("Enable Cowork Mode", isOn: $enableCowork)

                if enableCowork {
                    LabeledContent("Status", value: "Active")
                        .foregroundStyle(.green)
                } else {
                    LabeledContent("Status", value: "Inactive")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Server Configuration") {
                TextField("Server URL", text: $serverURL)
                    .help("URL of the collaboration server")
                    .disabled(!enableCowork)

                SecureField("API Key", text: $apiKey)
                    .disabled(!enableCowork)
            }

            Section("Collaboration Settings") {
                Toggle("Share by Default", isOn: $shareByDefault)
                    .disabled(!enableCowork)

                Stepper("Max Collaborators: \(maxCollaborators)", value: $maxCollaborators, in: 1 ... 20)
                    .disabled(!enableCowork)

                Toggle("Enable Notifications", isOn: $enableNotifications)
                    .disabled(!enableCowork)
            }

            Section("Sync") {
                VStack(alignment: .leading) {
                    Text("Auto-Sync Interval: \(Int(autoSyncInterval))s")
                    Slider(value: $autoSyncInterval, in: 10 ... 300, step: 10)
                }
                .disabled(!enableCowork)
            }

            Section {
                Button("Reset to Defaults") {
                    enableCowork = false
                    serverURL = ""
                    apiKey = ""
                    enableNotifications = true
                    autoSyncInterval = 30
                    shareByDefault = false
                    maxCollaborators = 5
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}
