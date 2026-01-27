import SwiftUI

struct MacSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    @State private var selectedTab: SettingsTab = .general

    // Temporary state for Cancel/OK pattern
    @State private var tempDefaultProvider: String = ""
    @State private var tempStreamResponses: Bool = false
    @State private var tempTheme: String = ""
    @State private var tempFontSize: String = ""
    @State private var tempLaunchAtLogin: Bool = false
    @State private var tempShowInMenuBar: Bool = false
    @State private var tempNotificationsEnabled: Bool = false
    @State private var tempReadResponsesAloud: Bool = false
    @State private var tempSelectedVoice: String = ""
    @State private var tempiCloudSyncEnabled: Bool = false
    @State private var tempHandoffEnabled: Bool = false
    @State private var tempAnalyticsEnabled: Bool = false
    @State private var tempDebugMode: Bool = false
    @State private var tempShowPerformanceMetrics: Bool = false
    @State private var tempBetaFeaturesEnabled: Bool = false

    // API Keys (temporary)
    @State private var tempAPIKeys: [String: String] = [:]

    @State private var hasChanges: Bool = false

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case aiProviders = "AI Providers"
        case models = "Models"
        case localModels = "Local Models"
        case orchestrator = "Orchestrator"
        case selfExecution = "Self-Execution"
        case voice = "Voice"
        case sync = "Sync"
        case privacy = "Privacy"
        case advanced = "Advanced"

        var icon: String {
            switch self {
            case .general: "gear"
            case .aiProviders: "brain.head.profile"
            case .models: "cube.box"
            case .localModels: "cpu"
            case .orchestrator: "network"
            case .selfExecution: "bolt.fill"
            case .voice: "mic.fill"
            case .sync: "icloud.fill"
            case .privacy: "lock.fill"
            case .advanced: "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    viewForTab(tab)
                        .tabItem {
                            Label(tab.rawValue, systemImage: tab.icon)
                        }
                        .tag(tab)
                }
            }

            Divider()

            // Bottom bar with Cancel/OK buttons
            HStack {
                if hasChanges {
                    Text("You have unsaved changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("OK") {
                    saveAllSettings()
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 650, height: 550)
        .onAppear {
            loadCurrentSettings()
        }
    }

    // MARK: - Load/Save Settings

    private func loadCurrentSettings() {
        tempDefaultProvider = settingsManager.defaultProvider
        tempStreamResponses = settingsManager.streamResponses
        tempTheme = settingsManager.theme
        tempFontSize = settingsManager.fontSize
        tempLaunchAtLogin = settingsManager.launchAtLogin
        tempShowInMenuBar = settingsManager.showInMenuBar
        tempNotificationsEnabled = settingsManager.notificationsEnabled
        tempReadResponsesAloud = settingsManager.readResponsesAloud
        tempSelectedVoice = settingsManager.selectedVoice
        tempiCloudSyncEnabled = settingsManager.iCloudSyncEnabled
        tempHandoffEnabled = settingsManager.handoffEnabled
        tempAnalyticsEnabled = settingsManager.analyticsEnabled
        tempDebugMode = settingsManager.debugMode
        tempShowPerformanceMetrics = settingsManager.showPerformanceMetrics
        tempBetaFeaturesEnabled = settingsManager.betaFeaturesEnabled

        // Load API keys
        for provider in settingsManager.availableProviders {
            tempAPIKeys[provider] = settingsManager.getAPIKey(for: provider) ?? ""
        }

        hasChanges = false
    }

    private func saveAllSettings() {
        settingsManager.defaultProvider = tempDefaultProvider
        settingsManager.streamResponses = tempStreamResponses
        settingsManager.theme = tempTheme
        settingsManager.fontSize = tempFontSize
        settingsManager.launchAtLogin = tempLaunchAtLogin
        settingsManager.showInMenuBar = tempShowInMenuBar
        settingsManager.notificationsEnabled = tempNotificationsEnabled
        settingsManager.readResponsesAloud = tempReadResponsesAloud
        settingsManager.selectedVoice = tempSelectedVoice
        settingsManager.iCloudSyncEnabled = tempiCloudSyncEnabled
        settingsManager.handoffEnabled = tempHandoffEnabled
        settingsManager.analyticsEnabled = tempAnalyticsEnabled
        settingsManager.debugMode = tempDebugMode
        settingsManager.showPerformanceMetrics = tempShowPerformanceMetrics
        settingsManager.betaFeaturesEnabled = tempBetaFeaturesEnabled

        // Save API keys
        for (provider, key) in tempAPIKeys {
            if !key.isEmpty {
                settingsManager.setAPIKey(key, for: provider)
            }
        }

        UserDefaults.standard.synchronize()
        print("✅ All settings saved")
    }

    private func markChanged() {
        hasChanges = true
    }

    @ViewBuilder
    private func viewForTab(_ tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            generalSettings
        case .aiProviders:
            aiProviderSettings
        case .models:
            ModelSettingsView()
        case .localModels:
            LocalModelsSettingsView()
        case .orchestrator:
            OrchestratorSettingsView()
        case .selfExecution:
            SelfExecutionView()
        case .voice:
            voiceSettings
        case .sync:
            syncSettings
        case .privacy:
            privacySettings
        case .advanced:
            advancedSettings
        }
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $tempTheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .onChange(of: tempTheme) { _, _ in markChanged() }

                Picker("Font Size", selection: $tempFontSize) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }
                .pickerStyle(.segmented)
                .onChange(of: tempFontSize) { _, _ in markChanged() }
            }

            Section("Behavior") {
                Toggle("Launch at Login", isOn: $tempLaunchAtLogin)
                    .onChange(of: tempLaunchAtLogin) { _, _ in markChanged() }
                Toggle("Show in Menu Bar", isOn: $tempShowInMenuBar)
                    .onChange(of: tempShowInMenuBar) { _, _ in markChanged() }
                Toggle("Enable Notifications", isOn: $tempNotificationsEnabled)
                    .onChange(of: tempNotificationsEnabled) { _, _ in markChanged() }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - AI Provider Settings

    private var aiProviderSettings: some View {
        Form {
            Section("Default Provider") {
                Picker("Provider", selection: $tempDefaultProvider) {
                    ForEach(settingsManager.availableProviders, id: \.self) { provider in
                        Text(provider.capitalized).tag(provider)
                    }
                }
                .onChange(of: tempDefaultProvider) { _, _ in markChanged() }

                Toggle("Stream Responses", isOn: $tempStreamResponses)
                    .onChange(of: tempStreamResponses) { _, _ in markChanged() }
            }

            Section("API Keys") {
                apiKeyField(provider: "OpenAI", key: "openai")
                apiKeyField(provider: "Anthropic", key: "anthropic")
                apiKeyField(provider: "Google AI", key: "google")
                apiKeyField(provider: "Perplexity", key: "perplexity")
                apiKeyField(provider: "Groq", key: "groq")
                apiKeyField(provider: "OpenRouter", key: "openrouter")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func apiKeyField(provider: String, key: String) -> some View {
        HStack {
            Text(provider)
                .frame(width: 100, alignment: .leading)

            SecureField("API Key", text: Binding(
                get: { tempAPIKeys[key] ?? "" },
                set: { newValue in
                    tempAPIKeys[key] = newValue
                    markChanged()
                }
            ))
            .textFieldStyle(.roundedBorder)

            if let currentKey = tempAPIKeys[key], !currentKey.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Voice Settings

    private var voiceSettings: some View {
        Form {
            Section("Voice Activation") {
                Toggle("Enable Voice Activation", isOn: $voiceManager.isEnabled)

                if voiceManager.isEnabled {
                    HStack {
                        Text("Wake Word")
                        TextField("Wake Word", text: $voiceManager.wakeWord)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("Conversation Mode", isOn: $voiceManager.conversationMode)

                    Button("Test Wake Word Detection") {
                        try? voiceManager.startWakeWordDetection()
                    }

                    if voiceManager.isListening {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Listening for '\(voiceManager.wakeWord)'...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Text-to-Speech") {
                Toggle("Read Responses Aloud", isOn: $tempReadResponsesAloud)
                    .onChange(of: tempReadResponsesAloud) { _, _ in markChanged() }

                if tempReadResponsesAloud {
                    Picker("Voice", selection: $tempSelectedVoice) {
                        Text("Default").tag("default")
                        Text("Samantha").tag("samantha")
                        Text("Alex").tag("alex")
                    }
                    .onChange(of: tempSelectedVoice) { _, _ in markChanged() }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Sync Settings

    private var syncSettings: some View {
        Form {
            Section("iCloud Sync") {
                Toggle("Enable iCloud Sync", isOn: $tempiCloudSyncEnabled)
                    .onChange(of: tempiCloudSyncEnabled) { _, _ in markChanged() }

                if tempiCloudSyncEnabled {
                    Text("iCloud sync configuration requires CloudKit entitlements")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Status: Not configured")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Section("Handoff") {
                Toggle("Enable Handoff", isOn: $tempHandoffEnabled)
                    .onChange(of: tempHandoffEnabled) { _, _ in markChanged() }

                Text("Continue conversations seamlessly across your Apple devices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Privacy Settings

    private var privacySettings: some View {
        Form {
            Section("Data Collection") {
                Toggle("Analytics", isOn: $tempAnalyticsEnabled)
                    .onChange(of: tempAnalyticsEnabled) { _, _ in markChanged() }

                Text("Help improve THEA by sharing anonymous usage data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Data Management") {
                Button("Export All Data") {
                    exportAllData()
                }

                Button("Clear All Data") {
                    clearAllData()
                }
                .foregroundStyle(.red)
            }

            Section("Privacy Information") {
                Text("Your conversations are stored locally on your device and synced via iCloud when enabled. All data is encrypted end-to-end.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Advanced Settings

    private var advancedSettings: some View {
        Form {
            Section("Development") {
                Toggle("Enable Debug Mode", isOn: $tempDebugMode)
                    .onChange(of: tempDebugMode) { _, _ in markChanged() }
                Toggle("Show Performance Metrics", isOn: $tempShowPerformanceMetrics)
                    .onChange(of: tempShowPerformanceMetrics) { _, _ in markChanged() }
            }

            Section("Experimental Features") {
                Toggle("Enable Beta Features", isOn: $tempBetaFeaturesEnabled)
                    .onChange(of: tempBetaFeaturesEnabled) { _, _ in markChanged() }

                Text("Beta features may be unstable and are subject to change")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Cache") {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text("~50 MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Clear Cache") {
                    clearCache()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Actions

    private func exportAllData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "thea-export-\(Date().ISO8601Format()).json"
        panel.allowedContentTypes = [.json]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                print("Exporting data to: \(url)")
            }
        }
    }

    private func clearAllData() {
        let alert = NSAlert()
        alert.messageText = "Clear All Data?"
        alert.informativeText = "This will permanently delete all conversations, projects, and settings. This action cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear All Data")

        if alert.runModal() == .alertSecondButtonReturn {
            print("Clearing all data")
        }
    }

    private func clearCache() {
        print("Clearing cache")
    }
}
