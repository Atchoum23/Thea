import SwiftUI

// MARK: - Window Resizable Helper

/// Invisible NSView that forces its host NSWindow to accept the `.resizable` style mask.
/// SwiftUI's `Settings` scene actively strips `.resizable` — we use KVO to re-inject
/// it every time the system removes it, ensuring the resize handle always appears.
private struct WindowResizableHelper: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        ResizableInjectorView()
    }

    func updateNSView(_: NSView, context _: Context) {}

    private class ResizableInjectorView: NSView {
        private var observation: NSKeyValueObservation?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else {
                observation = nil
                return
            }
            window.styleMask.insert(.resizable)

            observation = window.observe(\.styleMask, options: [.new]) { win, _ in
                DispatchQueue.main.async { @MainActor in
                    if !win.styleMask.contains(.resizable) {
                        win.styleMask.insert(.resizable)
                    }
                }
            }
        }

        deinit {
            observation?.invalidate()
        }
    }
}

// MARK: - Settings Category

/// Sidebar categories modeled after macOS System Settings.
enum SettingsCategory: String, CaseIterable, Identifiable {
    // Group 0: Core
    case general = "General"
    case aiModels = "AI & Models"

    // Group 1: Intelligence
    case providers = "Providers"
    case memory = "Memory"
    case agent = "Agent"
    case knowledge = "Knowledge"

    // Group 2: Input / Output
    case voiceInput = "Voice & Input"
    case codeIntelligence = "Code Intelligence"

    // Group 3: System
    case permissions = "Permissions"
    case sync = "Sync"
    case privacy = "Privacy"

    // Group 4: Customization
    case theme = "Theme"
    case advanced = "Advanced"

    // Group 5: Info
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gear"
        case .aiModels: "brain.head.profile"
        case .providers: "server.rack"
        case .memory: "memorychip"
        case .agent: "person.2.circle"
        case .knowledge: "books.vertical"
        case .voiceInput: "mic.fill"
        case .codeIntelligence: "chevron.left.forwardslash.chevron.right"
        case .permissions: "hand.raised.fill"
        case .sync: "icloud.fill"
        case .privacy: "lock.shield"
        case .theme: "paintpalette"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle"
        }
    }

    var group: Int {
        switch self {
        case .general, .aiModels: 0
        case .providers, .memory, .agent, .knowledge: 1
        case .voiceInput, .codeIntelligence: 2
        case .permissions, .sync, .privacy: 3
        case .theme, .advanced: 4
        case .about: 5
        }
    }

    /// Categories grouped for sidebar display with dividers between groups.
    static var grouped: [[SettingsCategory]] {
        let groups = Dictionary(grouping: allCases, by: \.group)
        return groups.keys.sorted().compactMap { groups[$0] }
    }
}

// MARK: - macOS Settings View

/// Consolidated macOS settings with a System Settings-style sidebar/detail layout.
struct MacSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    // Sidebar state
    @State private var selectedCategory: SettingsCategory? = .general
    @State private var searchText: String = ""

    // AI & Models state
    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var googleKey: String = ""
    @State private var perplexityKey: String = ""
    @State private var groqKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var apiKeysLoaded: Bool = false
    @State private var localModelConfig = AppConfiguration.shared.localModelConfig

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
            settingsSidebar
        } detail: {
            settingsDetail
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        .toolbar(removing: .sidebarToggle)
        .frame(
            minWidth: 780, idealWidth: 920, maxWidth: .infinity,
            minHeight: 500, idealHeight: 640, maxHeight: .infinity
        )
        .background(WindowResizableHelper())
        .textSelection(.enabled)
    }

    // MARK: - Sidebar

    private var settingsSidebar: some View {
        List(selection: $selectedCategory) {
            ForEach(Array(filteredGroups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    Divider()
                }
                ForEach(group) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
    }

    private var filteredGroups: [[SettingsCategory]] {
        if searchText.isEmpty {
            return SettingsCategory.grouped
        }
        let query = searchText.lowercased()
        let filtered = SettingsCategory.allCases.filter {
            $0.rawValue.lowercased().contains(query)
        }
        return filtered.isEmpty ? [] : [filtered]
    }

    // MARK: - Detail View Router

    @ViewBuilder
    private var settingsDetail: some View {
        if let category = selectedCategory {
            detailContent(for: category)
                .id(category)
        } else {
            Text("Select a category")
                .font(.theaTitle3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func detailContent(for category: SettingsCategory) -> some View {
        switch category {
        case .general:
            generalSettings
        case .aiModels:
            aiSettings
        case .providers:
            providersSettings
        case .memory:
            MemoryConfigurationView()
        case .agent:
            AgentConfigurationView()
        case .knowledge:
            KnowledgeScannerConfigurationView()
        case .voiceInput:
            voiceInputSettings
        case .codeIntelligence:
            CodeIntelligenceConfigurationView()
        case .permissions:
            PermissionsSettingsView()
        case .sync:
            SyncSettingsView()
        case .privacy:
            ConfigurationPrivacySettingsView()
        case .theme:
            ThemeConfigurationView()
        case .advanced:
            advancedSettings
        case .about:
            AboutView()
        }
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        Form {
            Section("Appearance") {
                let pickerWidth: CGFloat = 280

                LabeledContent("Theme") {
                    Picker("Theme", selection: $settingsManager.theme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: pickerWidth)
                }

                LabeledContent("Font Size") {
                    Picker("Font Size", selection: $settingsManager.fontSize) {
                        Text("Small").tag("small")
                        Text("Medium").tag("medium")
                        Text("Large").tag("large")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: pickerWidth)
                    .onChange(of: settingsManager.fontSize) { _, newSize in
                        AppConfiguration.applyFontSize(newSize)
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
                    .frame(width: pickerWidth)
                }

                LabeledContent("Timestamps") {
                    Picker("Timestamps", selection: $settingsManager.timestampDisplay) {
                        Text("Relative").tag("relative")
                        Text("Absolute").tag("absolute")
                        Text("Hidden").tag("hidden")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: pickerWidth)
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
        }
        .formStyle(.grouped)
    }

    // MARK: - AI & Models Settings

    private var aiSettings: some View {
        Form {
            Section("Provider & Routing") {
                Picker("Default Provider", selection: $settingsManager.defaultProvider) {
                    ForEach(settingsManager.availableProviders, id: \.self) { provider in
                        Text(provider.capitalized).tag(provider)
                    }
                }

                Toggle("Stream Responses", isOn: $settingsManager.streamResponses)

                Text("Model selection, temperature, tokens, and timeout are managed automatically by the Meta-AI orchestrator.")
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
            }

            Section("Local Models") {
                LabeledContent("Ollama URL") {
                    TextField("http://localhost:11434", text: $localModelConfig.ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                }

                LabeledContent("MLX Models Dir") {
                    HStack(spacing: 6) {
                        TextField("~/.cache/huggingface/hub", text: $localModelConfig.mlxModelsDirectory)
                            .textFieldStyle(.roundedBorder)
                            .truncationMode(.head)
                            .help(localModelConfig.mlxModelsDirectory)

                        Button {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.directoryURL = URL(
                                fileURLWithPath: (localModelConfig.mlxModelsDirectory as NSString)
                                    .expandingTildeInPath
                            )
                            if panel.runModal() == .OK, let url = panel.url {
                                localModelConfig.mlxModelsDirectory = url.path
                            }
                        } label: {
                            Image(systemName: "folder")
                        }
                        .help("Choose Folder…")
                    }
                    .frame(maxWidth: 320)
                }

                let localCount = ProviderRegistry.shared.getAvailableLocalModels().count
                LabeledContent("Discovered Models", value: "\(localCount)")
            }
            .onChange(of: localModelConfig) { _, newValue in
                AppConfiguration.shared.localModelConfig = newValue
            }

            Section("API Keys") {
                apiKeyField(label: "OpenAI", key: $openAIKey, provider: "openai")
                apiKeyField(label: "Anthropic", key: $anthropicKey, provider: "anthropic")
                apiKeyField(label: "Google AI", key: $googleKey, provider: "google")
                apiKeyField(label: "Perplexity", key: $perplexityKey, provider: "perplexity")
                apiKeyField(label: "Groq", key: $groqKey, provider: "groq")
                apiKeyField(label: "OpenRouter", key: $openRouterKey, provider: "openrouter")

                Text("Stored securely in your Keychain.")
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .onAppear { loadAPIKeysIfNeeded() }
    }

    // MARK: - Providers Settings (drill-down)

    private var providersSettings: some View {
        NavigationStack {
            Form {
                Section("AI Providers") {
                    NavigationLink("API Endpoints & Timeouts") {
                        ProviderConfigurationView()
                    }

                    NavigationLink("API Key Validation Models") {
                        APIValidationConfigurationView()
                    }

                    NavigationLink("External APIs") {
                        ExternalAPIsConfigurationView()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Providers")
        }
    }

    // MARK: - Voice & Input Settings (with drill-down)

    private var voiceInputSettings: some View {
        NavigationStack {
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

                Section("Advanced Voice Configuration") {
                    NavigationLink("Recognition & Synthesis Settings") {
                        VoiceConfigurationView()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Voice & Input")
        }
    }

    // MARK: - Advanced Settings

    private var advancedSettings: some View {
        Form {
            Section("Execution Safety") {
                Toggle("Allow File Creation", isOn: $settingsManager.allowFileCreation)
                Toggle("Allow File Editing", isOn: $settingsManager.allowFileEditing)
                Toggle("Allow Code Execution", isOn: $settingsManager.allowCodeExecution)
                Toggle("Allow External API Calls", isOn: $settingsManager.allowExternalAPICalls)
                Toggle("Require Approval for Destructive Actions", isOn: $settingsManager.requireDestructiveApproval)
                Toggle("Enable Rollback", isOn: $settingsManager.enableRollback)
                Toggle("Create Backups Before Changes", isOn: $settingsManager.createBackups)
                Stepper("Max Concurrent Tasks: \(settingsManager.maxConcurrentTasks)",
                        value: $settingsManager.maxConcurrentTasks, in: 1 ... 10)
            }

            Section("Development") {
                Toggle("Enable Debug Mode", isOn: $settingsManager.debugMode)
                Toggle("Show Performance Metrics", isOn: $settingsManager.showPerformanceMetrics)
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

            Section("Reset") {
                Button("Reset All Settings to Defaults", role: .destructive) {
                    settingsManager.resetToDefaults()
                }
                Button("Reset All Configuration to Defaults", role: .destructive) {
                    AppConfiguration.shared.resetAllToDefaults()
                }
            }
        }
        .formStyle(.grouped)
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

}
