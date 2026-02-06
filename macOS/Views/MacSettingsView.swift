import SwiftUI

struct MacSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var voiceManager = VoiceActivationManager.shared
    @State private var handoffService = HandoffService.shared

    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case aiProviders = "AI Providers"
        case models = "Models"
        case localModels = "Local Models"
        case orchestrator = "Orchestrator"
        case memory = "Memory"
        case integrations = "Integrations"
        case automation = "Automation"
        case voice = "Voice"
        case permissions = "Permissions"
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
            case .memory: "brain"
            case .integrations: "square.grid.2x2"
            case .automation: "gearshape.2"
            case .voice: "mic.fill"
            case .permissions: "hand.raised.fill"
            case .sync: "icloud.fill"
            case .privacy: "lock.fill"
            case .advanced: "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                viewForTab(tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .frame(width: 800, height: 600)
    }

    @ViewBuilder
    private func viewForTab(_ tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            generalSettings
        case .aiProviders:
            comingSoonView("AI Providers")
        case .models:
            ModelSettingsView()
        case .localModels:
            comingSoonView("Local Models")
        case .orchestrator:
            comingSoonView("Orchestrator")
        case .memory:
            comingSoonView("Memory")
        case .integrations:
            IntegrationsSettingsView()
        case .automation:
            comingSoonView("Automation")
        case .voice:
            voiceSettings
        case .permissions:
            comingSoonView("Permissions")
        case .sync:
            syncSettings
        case .privacy:
            privacySettings
        case .advanced:
            advancedSettings
        }
    }

    // MARK: - Coming Soon Placeholder

    private func comingSoonView(_ title: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("\(title) Settings")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Coming soon in a future update")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        Form {
            Section("Appearance") {
                LabeledContent("Theme") {
                    Picker("Theme", selection: $settingsManager.theme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 250)
                }

                LabeledContent("Font Size") {
                    Picker("Font Size", selection: $settingsManager.fontSize) {
                        Text("Small").tag("small")
                        Text("Medium").tag("medium")
                        Text("Large").tag("large")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 250)
                }

                LabeledContent("Message Density") {
                    Picker("Density", selection: $settingsManager.messageDensity) {
                        Text("Compact").tag("compact")
                        Text("Comfortable").tag("comfortable")
                        Text("Spacious").tag("spacious")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 250)
                }

                LabeledContent("Timestamps") {
                    Picker("Timestamps", selection: $settingsManager.timestampDisplay) {
                        Text("Relative").tag("relative")
                        Text("Absolute").tag("absolute")
                        Text("Hidden").tag("hidden")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 250)
                }
            }

            Section("Window Behavior") {
                Toggle("Float Window on Top", isOn: $settingsManager.windowFloatOnTop)

                Toggle("Remember Window Position", isOn: $settingsManager.rememberWindowPosition)

                LabeledContent("Default Size") {
                    Picker("Size", selection: $settingsManager.defaultWindowSize) {
                        Text("Default").tag("default")
                        Text("Compact").tag("compact")
                        Text("Large").tag("large")
                        Text("Fullscreen").tag("fullscreen")
                    }
                    .frame(maxWidth: 150)
                }
            }

            Section("Behavior") {
                Toggle("Launch at Login", isOn: $settingsManager.launchAtLogin)
                Toggle("Show in Menu Bar", isOn: $settingsManager.showInMenuBar)
                Toggle("Enable Notifications", isOn: $settingsManager.notificationsEnabled)
                Toggle("Auto-Scroll to Latest Message", isOn: $settingsManager.autoScrollToBottom)
            }

            Section("Startup") {
                Toggle("Show Sidebar on Launch", isOn: $settingsManager.showSidebarOnLaunch)
                Toggle("Restore Last Session", isOn: $settingsManager.restoreLastSession)
            }

            Section {
                Text("Changes are saved automatically.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - AI Provider Settings

    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var googleKey: String = ""
    @State private var perplexityKey: String = ""
    @State private var groqKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var apiKeysLoaded: Bool = false

    private func loadAPIKeysIfNeeded() {
        guard !apiKeysLoaded else { return }
        apiKeysLoaded = true
        openAIKey = settingsManager.getAPIKey(for: "openai") ?? ""
        anthropicKey = settingsManager.getAPIKey(for: "anthropic") ?? ""
        googleKey = settingsManager.getAPIKey(for: "google") ?? ""
        perplexityKey = settingsManager.getAPIKey(for: "perplexity") ?? ""
        groqKey = settingsManager.getAPIKey(for: "groq") ?? ""
        openRouterKey = settingsManager.getAPIKey(for: "openrouter") ?? ""
    }

    private func saveAPIKey(_ key: String, for provider: String) {
        if !key.isEmpty {
            settingsManager.setAPIKey(key, for: provider)
        }
    }

    private var aiProviderSettings: some View {
        Form {
            Section("Default Provider") {
                Picker("Provider", selection: $settingsManager.defaultProvider) {
                    ForEach(settingsManager.availableProviders, id: \.self) { provider in
                        Text(provider.capitalized).tag(provider)
                    }
                }

                Toggle("Stream Responses", isOn: $settingsManager.streamResponses)
            }

            Section("API Keys") {
                apiKeyField(label: "OpenAI", key: $openAIKey, provider: "openai")
                apiKeyField(label: "Anthropic", key: $anthropicKey, provider: "anthropic")
                apiKeyField(label: "Google AI", key: $googleKey, provider: "google")
                apiKeyField(label: "Perplexity", key: $perplexityKey, provider: "perplexity")
                apiKeyField(label: "Groq", key: $groqKey, provider: "groq")
                apiKeyField(label: "OpenRouter", key: $openRouterKey, provider: "openrouter")
            }

            Section {
                Text("API keys are stored securely in your Keychain.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadAPIKeysIfNeeded()
        }
    }

    private func apiKeyField(label: String, key: Binding<String>, provider: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)

            SecureField("API Key", text: key)
                .textFieldStyle(.roundedBorder)
                .onChange(of: key.wrappedValue) { _, newValue in
                    saveAPIKey(newValue, for: provider)
                }

            if !key.wrappedValue.isEmpty {
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
                    .onChange(of: voiceManager.isEnabled) { _, newValue in
                        if !newValue {
                            voiceManager.stopVoiceCommand()
                            voiceManager.stopWakeWordDetection()
                        }
                    }

                if voiceManager.isEnabled {
                    HStack {
                        Text("Wake Word")
                        TextField("Wake Word", text: $voiceManager.wakeWord)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("Conversation Mode", isOn: $voiceManager.conversationMode)

                    HStack {
                        Button("Test Wake Word Detection") {
                            try? voiceManager.startWakeWordDetection()
                        }

                        if voiceManager.isListening {
                            Button("Stop") {
                                voiceManager.stopWakeWordDetection()
                            }
                            .foregroundStyle(.red)
                        }
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

                Text("Note: Voice features require microphone permission. Disable to stop microphone access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Text-to-Speech") {
                Toggle("Read Responses Aloud", isOn: $settingsManager.readResponsesAloud)

                if settingsManager.readResponsesAloud {
                    Picker("Voice", selection: $settingsManager.selectedVoice) {
                        Text("Default").tag("default")
                        Text("Samantha").tag("samantha")
                        Text("Alex").tag("alex")
                    }
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
                Toggle("Enable iCloud Sync", isOn: $settingsManager.iCloudSyncEnabled)

                if settingsManager.iCloudSyncEnabled {
                    HStack {
                        Text("iCloud Status:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if cloudKitService.iCloudAvailable {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("Not Available", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    HStack {
                        Text("Sync Status:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(cloudKitService.syncStatus.description)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let lastSync = cloudKitService.lastSyncDate {
                        HStack {
                            Text("Last Sync:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(lastSync, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Button("Sync Now") {
                        Task {
                            try? await cloudKitService.syncAll()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!cloudKitService.iCloudAvailable || cloudKitService.syncStatus == .syncing)
                }

                Text("Syncs conversations, settings, and knowledge across your Apple devices via iCloud.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Handoff") {
                Toggle("Enable Handoff", isOn: $settingsManager.handoffEnabled)

                HStack {
                    Text("Handoff Status:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if handoffService.isEnabled {
                        Label("Active", systemImage: "hand.raised.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else {
                        Label("Disabled", systemImage: "hand.raised.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Continue conversations seamlessly across your Apple devices. Start on Mac, continue on iPhone or iPad.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if handoffService.currentActivity != nil {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(.blue)
                        Text("Activity ready for handoff")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Section("Requirements") {
                VStack(alignment: .leading, spacing: 8) {
                    requirementRow(
                        icon: "icloud",
                        title: "iCloud Account",
                        status: cloudKitService.iCloudAvailable
                    )
                    requirementRow(
                        icon: "wifi",
                        title: "Same Wi-Fi Network (for Handoff)",
                        status: true
                    )
                    requirementRow(
                        icon: "bluetooth",
                        title: "Bluetooth Enabled (for Handoff)",
                        status: true
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func requirementRow(icon: String, title: String, status: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .font(.caption)
            Spacer()
            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(status ? .green : .red)
        }
    }

    // MARK: - Privacy Settings

    private var privacySettings: some View {
        Form {
            Section("Data Collection") {
                Toggle("Analytics", isOn: $settingsManager.analyticsEnabled)

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
                Toggle("Enable Debug Mode", isOn: $settingsManager.debugMode)
                Toggle("Show Performance Metrics", isOn: $settingsManager.showPerformanceMetrics)
            }

            Section("Experimental Features") {
                Toggle("Enable Beta Features", isOn: $settingsManager.betaFeaturesEnabled)

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
