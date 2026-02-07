import SwiftUI

// MARK: - macOS Settings View

/// Consolidated settings for macOS with progressive disclosure.
/// Tabs: General, AI & Models, Voice & Input, Sync & Privacy, Advanced
struct MacSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var voiceManager = VoiceActivationManager.shared
    @State private var handoffService = HandoffService.shared

    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case ai = "AI & Models"
        case voice = "Voice & Input"
        case syncPrivacy = "Sync & Privacy"
        case advanced = "Advanced"

        var icon: String {
            switch self {
            case .general: "gear"
            case .ai: "brain.head.profile"
            case .voice: "mic.fill"
            case .syncPrivacy: "lock.icloud.fill"
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
        .frame(width: 680, height: 520)
    }

    @ViewBuilder
    private func viewForTab(_ tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            generalSettings
        case .ai:
            aiSettings
        case .voice:
            voiceSettings
        case .syncPrivacy:
            syncPrivacySettings
        case .advanced:
            advancedSettings
        }
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
                    .onChange(of: settingsManager.fontSize) { _, newSize in
                        applyFontSizeToThemeConfig(newSize)
                    }
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

            Section("Window") {
                Toggle("Float Window on Top", isOn: $settingsManager.windowFloatOnTop)
                Toggle("Remember Window Position", isOn: $settingsManager.rememberWindowPosition)
            }

            Section("Behavior") {
                Toggle("Launch at Login", isOn: $settingsManager.launchAtLogin)
                Toggle("Show in Menu Bar", isOn: $settingsManager.showInMenuBar)
                Toggle("Enable Notifications", isOn: $settingsManager.notificationsEnabled)
                Toggle("Auto-Scroll to Latest", isOn: $settingsManager.autoScrollToBottom)
                Toggle("Show Sidebar on Launch", isOn: $settingsManager.showSidebarOnLaunch)
                Toggle("Restore Last Session", isOn: $settingsManager.restoreLastSession)
            }

            settingsFooter
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - AI & Models Settings

    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var googleKey: String = ""
    @State private var perplexityKey: String = ""
    @State private var groqKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var apiKeysLoaded: Bool = false

    private var aiSettings: some View {
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

                Text("API keys are stored securely in your Keychain.")
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
            }

            Section("Models") {
                ModelSettingsView()
            }

            Section("Integrations") {
                IntegrationsSettingsView()
            }

            settingsFooter
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { loadAPIKeysIfNeeded() }
    }

    // MARK: - Voice & Input Settings

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
                        Button("Test Wake Word") {
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
                                .font(.theaCaption1)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text("Voice features require microphone permission.")
                    .font(.theaCaption2)
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

            settingsFooter
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Sync & Privacy Settings

    private var syncPrivacySettings: some View {
        Form {
            Section("iCloud Sync") {
                Toggle("Enable iCloud Sync", isOn: $settingsManager.iCloudSyncEnabled)

                if settingsManager.iCloudSyncEnabled {
                    syncStatusRow("iCloud Status",
                                  isActive: cloudKitService.iCloudAvailable,
                                  activeText: "Connected",
                                  activeIcon: "checkmark.circle.fill",
                                  inactiveText: "Not Available",
                                  inactiveIcon: "exclamationmark.triangle.fill")

                    HStack {
                        Text("Sync Status:")
                            .font(.theaCaption1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(cloudKitService.syncStatus.description)
                            .font(.theaCaption1)
                            .foregroundStyle(.tertiary)
                    }

                    if let lastSync = cloudKitService.lastSyncDate {
                        HStack {
                            Text("Last Sync:")
                                .font(.theaCaption1)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(lastSync, style: .relative)
                                .font(.theaCaption1)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Button("Sync Now") {
                        Task { try? await cloudKitService.syncAll() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!cloudKitService.iCloudAvailable
                        || cloudKitService.syncStatus == .syncing)
                }
            }

            Section("Handoff") {
                Toggle("Enable Handoff", isOn: $settingsManager.handoffEnabled)

                syncStatusRow("Handoff Status",
                              isActive: handoffService.isEnabled,
                              activeText: "Active",
                              activeIcon: "hand.raised.fill",
                              inactiveText: "Disabled",
                              inactiveIcon: "hand.raised.slash")

                Text("Continue conversations seamlessly across Apple devices.")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Toggle("Analytics", isOn: $settingsManager.analyticsEnabled)
                Text("Help improve THEA by sharing anonymous usage data.")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
            }

            Section("Data Management") {
                Button("Export All Data") { exportAllData() }
                Button("Clear All Data", role: .destructive) { clearAllData() }
            }

            settingsFooter
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

            Section("Experimental") {
                Toggle("Enable Beta Features", isOn: $settingsManager.betaFeaturesEnabled)
                Text("Beta features may be unstable and are subject to change.")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
            }

            Section("Cache") {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text("~50 MB")
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                }
                Button("Clear Cache") { clearCache() }
            }

            settingsFooter
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Shared Components

    private var settingsFooter: some View {
        Section {
            Text("Changes are saved automatically.")
                .font(.theaCaption2)
                .foregroundStyle(.quaternary)
        }
    }

    private func syncStatusRow(
        _ label: String,
        isActive: Bool,
        activeText: String,
        activeIcon: String,
        inactiveText: String,
        inactiveIcon: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.theaCaption1)
                .foregroundStyle(.secondary)
            Spacer()
            Label(
                isActive ? activeText : inactiveText,
                systemImage: isActive ? activeIcon : inactiveIcon
            )
            .font(.theaCaption1)
            .foregroundStyle(isActive ? .green : .secondary)
        }
    }

    // MARK: - API Key Helpers

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

    private func apiKeyField(label: String, key: Binding<String>, provider: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)

            SecureField("API Key", text: key)
                .textFieldStyle(.roundedBorder)
                .onChange(of: key.wrappedValue) { _, newValue in
                    if !newValue.isEmpty {
                        settingsManager.setAPIKey(newValue, for: provider)
                    }
                }

            if !key.wrappedValue.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
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

    // MARK: - Font Size Scaling

    /// Adjusts themeConfig base font sizes when the user changes the font size picker.
    /// On macOS, `.dynamicTypeSize()` alone doesn't scale `Font.system(size:)` calls,
    /// so we explicitly adjust the stored base sizes.
    private func applyFontSizeToThemeConfig(_ size: String) {
        var config = AppConfiguration.shared.themeConfig
        let scale: CGFloat = switch size {
        case "small": 0.85
        case "large": 1.25
        default: 1.0  // "medium"
        }

        // Default sizes (from ThemeConfiguration defaults)
        config.displaySize = round(34 * scale)
        config.title1Size = round(28 * scale)
        config.title2Size = round(22 * scale)
        config.title3Size = round(20 * scale)
        config.headlineSize = round(17 * scale)
        config.bodySize = round(17 * scale)
        config.calloutSize = round(16 * scale)
        config.subheadSize = round(15 * scale)
        config.footnoteSize = round(13 * scale)
        config.caption1Size = round(12 * scale)
        config.caption2Size = round(11 * scale)
        config.codeSize = round(14 * scale)
        config.codeInlineSize = round(16 * scale)

        AppConfiguration.shared.themeConfig = config
    }
}
