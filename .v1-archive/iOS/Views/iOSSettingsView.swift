// swiftlint:disable file_length type_name
import SwiftUI
import LocalAuthentication

// MARK: - iOS Settings View

struct iOSSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var voiceManager = VoiceActivationManager.shared
    @State private var migrationManager = MigrationManager.shared

    @State private var showingMigration = false
    @State private var showingAbout = false
    @State private var showingAPIKeys = false
    @State private var showingPermissions = false
    @State private var showingClearDataConfirmation = false

    var body: some View {
        Form {
            // MARK: - AI & Models Section
            Section {
                NavigationLink {
                    IOSAIProvidersSettingsView()
                } label: {
                    SettingsRow(
                        icon: "cloud.fill",
                        iconColor: .blue,
                        title: "AI Providers",
                        subtitle: "API keys, health, usage"
                    )
                }

                NavigationLink {
                    IOSModelsSettingsView()
                } label: {
                    SettingsRow(
                        icon: "cpu",
                        iconColor: .purple,
                        title: "Models",
                        subtitle: "Favorites, capabilities, comparison"
                    )
                }

                // Local Models - not available on iOS (MLX is macOS only)
                NavigationLink {
                    IOSLocalModelsUnavailableView()
                } label: {
                    SettingsRow(
                        icon: "desktopcomputer",
                        iconColor: .gray,
                        title: "Local Models",
                        subtitle: "macOS only"
                    )
                }

                NavigationLink {
                    IOSOrchestratorSettingsView()
                } label: {
                    SettingsRow(
                        icon: "gearshape.2.fill",
                        iconColor: .orange,
                        title: "Orchestrator",
                        subtitle: "Agent pool, routing rules"
                    )
                }
            } header: {
                Text("AI & Models")
            }

            // MARK: - Assistant Section
            Section {
                NavigationLink {
                    iOSVoiceSettingsView()
                } label: {
                    SettingsRow(
                        icon: "waveform.circle.fill",
                        iconColor: .pink,
                        title: "Voice",
                        subtitle: voiceManager.isEnabled ? "Enabled" : "Disabled"
                    )
                }

                NavigationLink {
                    IOSMemorySettingsView()
                } label: {
                    SettingsRow(
                        icon: "brain",
                        iconColor: .indigo,
                        title: "Memory",
                        subtitle: "Context, learning, recall"
                    )
                }

                NavigationLink {
                    IOSAutomationSettingsView()
                } label: {
                    SettingsRow(
                        icon: "bolt.fill",
                        iconColor: .yellow,
                        title: "Automation",
                        subtitle: "Workflows, execution modes"
                    )
                }
            } header: {
                Text("Assistant")
            }

            // MARK: - Integrations Section
            Section {
                NavigationLink {
                    IOSIntegrationsSettingsView()
                } label: {
                    SettingsRow(
                        icon: "square.grid.2x2.fill",
                        iconColor: .teal,
                        title: "Integrations",
                        subtitle: "Apps, services, MCP"
                    )
                }
            } header: {
                Text("Integrations")
            }

            // MARK: - Appearance Section
            Section {
                Picker("Theme", selection: $settingsManager.theme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.menu)

                Picker("Font Size", selection: $settingsManager.fontSize) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Appearance")
            }

            // MARK: - Data & Sync Section
            Section {
                NavigationLink {
                    IOSSyncSettingsView()
                } label: {
                    SettingsRow(
                        icon: "icloud.fill",
                        iconColor: .cyan,
                        title: "Sync",
                        subtitle: settingsManager.iCloudSyncEnabled ? "iCloud enabled" : "Off"
                    )
                }

                NavigationLink {
                    IOSBackupSettingsView()
                } label: {
                    SettingsRow(
                        icon: "arrow.clockwise.icloud.fill",
                        iconColor: .mint,
                        title: "Backup & Restore",
                        subtitle: "Manage backups"
                    )
                }

                Button {
                    showingMigration = true
                } label: {
                    SettingsRow(
                        icon: "arrow.down.doc.fill",
                        iconColor: .blue,
                        title: "Import Data",
                        subtitle: "From ChatGPT, Claude, Cursor"
                    )
                }
                .tint(.primary)
            } header: {
                Text("Data & Sync")
            }

            // MARK: - Privacy & Security Section
            Section {
                NavigationLink {
                    IOSPrivacySettingsView()
                } label: {
                    SettingsRow(
                        icon: "hand.raised.fill",
                        iconColor: .red,
                        title: "Privacy",
                        subtitle: "Data, retention, export"
                    )
                }

                Button {
                    showingPermissions = true
                } label: {
                    SettingsRow(
                        icon: "lock.shield.fill",
                        iconColor: .gray,
                        title: "Permissions",
                        subtitle: "Camera, microphone, photos"
                    )
                }
                .tint(.primary)
            } header: {
                Text("Privacy & Security")
            }

            // MARK: - Advanced Section
            Section {
                NavigationLink {
                    IOSAdvancedSettingsView()
                } label: {
                    SettingsRow(
                        icon: "wrench.and.screwdriver.fill",
                        iconColor: .gray,
                        title: "Advanced",
                        subtitle: "Network, logging, performance"
                    )
                }
            } header: {
                Text("Advanced")
            }

            // MARK: - Danger Zone Section
            Section {
                Button(role: .destructive) {
                    showingClearDataConfirmation = true
                } label: {
                    Label("Clear All Data", systemImage: "trash.fill")
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Permanently delete all conversations, projects, and settings")
            }

            // MARK: - About Section
            Section {
                Button {
                    showingAbout = true
                } label: {
                    SettingsRow(
                        icon: "info.circle.fill",
                        iconColor: .blue,
                        title: "About THEA",
                        subtitle: "Version 1.0.0"
                    )
                }
                .tint(.primary)
            } header: {
                Text("About")
            }
        }
        .sheet(isPresented: $showingMigration) {
            iOSMigrationView()
        }
        .sheet(isPresented: $showingAbout) {
            iOSAboutView()
        }
        .sheet(isPresented: $showingAPIKeys) {
            iOSAPIKeysView()
        }
        .sheet(isPresented: $showingPermissions) {
            IOSPermissionsView()
        }
        .confirmationDialog(
            "Clear All Data",
            isPresented: $showingClearDataConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Data", role: .destructive) {
                clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your conversations, projects, and settings. This action cannot be undone.")
        }
    }

    private func clearAllData() {
        ChatManager.shared.clearAllData()
        ProjectManager.shared.clearAllData()
        KnowledgeManager.shared.clearAllData()
        FinancialManager.shared.clearAllData()
        settingsManager.resetToDefaults()
    }
}

// MARK: - Settings Row Component

private struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - iOS AI Providers Settings View

struct IOSAIProvidersSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var showingAPIKeys = false

    // Provider health simulation
    @State private var providerHealth: [String: IOSProviderHealthStatus] = [
        "OpenAI": .healthy,
        "Anthropic": .healthy,
        "Google": .healthy,
        "Perplexity": .unknown,
        "Groq": .healthy,
        "OpenRouter": .unknown
    ]

    var body: some View {
        Form {
            // Quick Actions
            Section {
                Button {
                    showingAPIKeys = true
                } label: {
                    Label("Configure API Keys", systemImage: "key.fill")
                }

                Picker("Default Provider", selection: $settingsManager.defaultProvider) {
                    ForEach(settingsManager.availableProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }

                Toggle("Stream Responses", isOn: $settingsManager.streamResponses)
            } header: {
                Text("Configuration")
            }

            // Provider Status
            Section {
                ForEach(Array(providerHealth.keys.sorted()), id: \.self) { provider in
                    HStack {
                        Circle()
                            .fill(statusColor(for: providerHealth[provider] ?? .unknown))
                            .frame(width: 10, height: 10)

                        Text(provider)

                        Spacer()

                        Text(providerHealth[provider]?.rawValue ?? "Unknown")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Refresh Status") {
                    refreshProviderStatus()
                }
            } header: {
                Text("Provider Health")
            } footer: {
                Text("Shows the current availability of each AI provider")
            }

            // Usage Summary
            Section {
                LabeledContent("Tokens Today", value: "12,450")
                LabeledContent("Tokens This Month", value: "345,678")
                LabeledContent("Estimated Cost", value: "$4.52")
            } header: {
                Text("Usage")
            }
        }
        .navigationTitle("AI Providers")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAPIKeys) {
            iOSAPIKeysView()
        }
    }

    private func statusColor(for status: IOSProviderHealthStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .degraded: return .yellow
        case .down: return .red
        case .unknown: return .gray
        }
    }

    private func refreshProviderStatus() {
        Task {
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

private enum IOSProviderHealthStatus: String {
    case healthy = "Healthy"
    case degraded = "Degraded"
    case down = "Down"
    case unknown = "Unknown"
}

// MARK: - iOS Models Settings View

struct IOSModelsSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var selectedModel = "gpt-4o"
    @State private var favoriteModels: Set<String> = ["gpt-4o", "claude-3-5-sonnet"]

    private let availableModels = [
        ("gpt-4o", "OpenAI", "128K context"),
        ("gpt-4o-mini", "OpenAI", "128K context"),
        ("claude-3-5-sonnet", "Anthropic", "200K context"),
        ("claude-3-5-haiku", "Anthropic", "200K context"),
        ("gemini-1.5-pro", "Google", "1M context"),
        ("gemini-1.5-flash", "Google", "1M context"),
        ("llama-3.1-70b", "Groq", "128K context"),
        ("mixtral-8x7b", "Groq", "32K context")
    ]

    var body: some View {
        Form {
            // Default Model
            Section {
                Picker("Default Model", selection: $selectedModel) {
                    ForEach(availableModels, id: \.0) { model in
                        Text(model.0).tag(model.0)
                    }
                }
            } header: {
                Text("Default")
            }

            // Favorite Models
            Section {
                ForEach(availableModels, id: \.0) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.0)
                                .font(.body)
                            Text("\(model.1) • \(model.2)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            if favoriteModels.contains(model.0) {
                                favoriteModels.remove(model.0)
                            } else {
                                favoriteModels.insert(model.0)
                            }
                        } label: {
                            Image(systemName: favoriteModels.contains(model.0) ? "star.fill" : "star")
                                .foregroundStyle(favoriteModels.contains(model.0) ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Available Models")
            } footer: {
                Text("Tap the star to add models to favorites")
            }

            // Model Info
            Section {
                LabeledContent("Favorite Count", value: "\(favoriteModels.count)")
                LabeledContent("Available Models", value: "\(availableModels.count)")
            } header: {
                Text("Statistics")
            }
        }
        .navigationTitle("Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - iOS Local Models Unavailable View

struct IOSLocalModelsUnavailableView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "desktopcomputer")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("Local Models")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("On-device model inference using MLX is only available on macOS with Apple Silicon.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 8) {
                Text("Why macOS only?")
                    .font(.headline)

                Text("MLX leverages Apple Silicon's unified memory architecture for efficient local inference. iOS devices don't support the full MLX runtime.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding()
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 8) {
                Text("Alternative")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("Use cloud-based AI providers for full model access on iOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Local Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - iOS Orchestrator Settings View

struct IOSOrchestratorSettingsView: View {
    @State private var config = IOSOrchestratorConfig.load()

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Text("4")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Active Agents")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("12")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("Tasks Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("98%")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.purple)
                        Text("Success Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Overview")
            }

            // Configuration
            Section {
                Toggle("Enable Orchestration", isOn: $config.isEnabled)

                Stepper("Max Concurrent Tasks: \(config.maxConcurrentTasks)", value: $config.maxConcurrentTasks, in: 1...10)

                Stepper("Agent Timeout: \(config.agentTimeout)s", value: $config.agentTimeout, in: 30...300, step: 30)
            } header: {
                Text("Configuration")
            }

            // Routing
            Section {
                Toggle("Smart Routing", isOn: $config.smartRouting)

                Toggle("Auto Fallback", isOn: $config.autoFallback)

                Toggle("Cost Optimization", isOn: $config.costOptimization)
            } header: {
                Text("Routing")
            } footer: {
                Text("Smart routing automatically selects the best model for each task")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSOrchestratorConfig()
                }
            }
        }
        .navigationTitle("Orchestrator")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

private struct IOSOrchestratorConfig: Equatable, Codable {
    var isEnabled: Bool = true
    var maxConcurrentTasks: Int = 4
    var agentTimeout: Int = 60
    var smartRouting: Bool = true
    var autoFallback: Bool = true
    var costOptimization: Bool = false

    private static let storageKey = "iOSOrchestratorConfig"

    static func load() -> IOSOrchestratorConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSOrchestratorConfig.self, from: data) {
            return config
        }
        return IOSOrchestratorConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - iOS Voice Settings View

struct iOSVoiceSettingsView: View {
    @State private var voiceManager = VoiceActivationManager.shared
    @State private var customWakeWord = ""

    var body: some View {
        Form {
            Section {
                Toggle("Voice Activation", isOn: $voiceManager.isEnabled)
            } footer: {
                Text("Enable voice activation to use wake word detection")
            }

            if voiceManager.isEnabled {
                Section {
                    TextField("Wake Word", text: $customWakeWord)
                        .onSubmit {
                            voiceManager.wakeWord = customWakeWord
                        }
                } header: {
                    Text("Wake Word")
                } footer: {
                    Text("Say this phrase to activate THEA. Default is 'Hey Thea'")
                }

                Section {
                    Toggle("Conversation Mode", isOn: $voiceManager.conversationMode)
                } footer: {
                    Text("Keep listening after responding, allowing natural back-and-forth conversation")
                }

                Section {
                    if voiceManager.isListening {
                        HStack {
                            ProgressView()
                            Text("Listening...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Test Wake Word") {
                            testWakeWord()
                        }
                    }
                }
            }
        }
        .navigationTitle("Voice Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            customWakeWord = voiceManager.wakeWord
        }
    }

    func testWakeWord() {
        do {
            try voiceManager.startWakeWordDetection()
        } catch {
            print("Failed to start wake word detection: \(error)")
        }
    }
}

// MARK: - iOS Memory Settings View

struct IOSMemorySettingsView: View {
    @State private var config = IOSMemoryConfig.load()

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Text("1,234")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("Memories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("45")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Recent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Overview")
            }

            // Configuration
            Section {
                Toggle("Enable Memory", isOn: $config.isEnabled)

                Stepper("Short-term: \(config.shortTermCapacity)", value: $config.shortTermCapacity, in: 10...100, step: 10)

                Stepper("Long-term: \(config.longTermCapacity)", value: $config.longTermCapacity, in: 1000...50000, step: 1000)
            } header: {
                Text("Capacity")
            }

            // Learning
            Section {
                Toggle("Learn from Conversations", isOn: $config.learnFromConversations)

                Toggle("Remember Preferences", isOn: $config.rememberPreferences)

                Toggle("Context Awareness", isOn: $config.contextAwareness)
            } header: {
                Text("Learning")
            }

            // Management
            Section {
                Button("Clear Short-term Memory") {
                    // Clear action
                }

                Button("Clear All Memory", role: .destructive) {
                    // Clear all action
                }
            } header: {
                Text("Management")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSMemoryConfig()
                }
            }
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

private struct IOSMemoryConfig: Equatable, Codable {
    var isEnabled: Bool = true
    var shortTermCapacity: Int = 50
    var longTermCapacity: Int = 10000
    var learnFromConversations: Bool = true
    var rememberPreferences: Bool = true
    var contextAwareness: Bool = true

    private static let storageKey = "iOSMemoryConfig"

    static func load() -> IOSMemoryConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSMemoryConfig.self, from: data) {
            return config
        }
        return IOSMemoryConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - iOS Automation Settings View

struct IOSAutomationSettingsView: View {
    @State private var config = IOSAutomationConfig.load()

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Text("5")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("Workflows")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("23")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Runs Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Overview")
            }

            // Configuration
            Section {
                Toggle("Enable Automation", isOn: $config.isEnabled)

                Picker("Execution Mode", selection: $config.executionMode) {
                    Text("Safe").tag("safe")
                    Text("Normal").tag("normal")
                    Text("Aggressive").tag("aggressive")
                }
            } header: {
                Text("Configuration")
            }

            // Approvals
            Section {
                Toggle("Require Approval for Actions", isOn: $config.requireApproval)

                Toggle("Auto-run Scheduled Tasks", isOn: $config.autoRunScheduled)
            } header: {
                Text("Approvals")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSAutomationConfig()
                }
            }
        }
        .navigationTitle("Automation")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

private struct IOSAutomationConfig: Equatable, Codable {
    var isEnabled: Bool = true
    var executionMode: String = "normal"
    var requireApproval: Bool = true
    var autoRunScheduled: Bool = false

    private static let storageKey = "iOSAutomationConfig"

    static func load() -> IOSAutomationConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSAutomationConfig.self, from: data) {
            return config
        }
        return IOSAutomationConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - iOS Integrations Settings View

struct IOSIntegrationsSettingsView: View {
    @State private var config = IOSIntegrationsConfig.load()

    var body: some View {
        Form {
            // Health & Fitness
            Section {
                Toggle("Apple Health", isOn: $config.healthEnabled)
                Toggle("Apple Fitness", isOn: $config.fitnessEnabled)
            } header: {
                Text("Health & Fitness")
            }

            // Productivity
            Section {
                Toggle("Calendar", isOn: $config.calendarEnabled)
                Toggle("Reminders", isOn: $config.remindersEnabled)
                Toggle("Notes", isOn: $config.notesEnabled)
            } header: {
                Text("Productivity")
            }

            // Smart Home
            Section {
                Toggle("HomeKit", isOn: $config.homeKitEnabled)
            } header: {
                Text("Smart Home")
            }

            // Communication
            Section {
                Toggle("Contacts", isOn: $config.contactsEnabled)
            } header: {
                Text("Communication")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSIntegrationsConfig()
                }
            }
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

private struct IOSIntegrationsConfig: Equatable, Codable {
    var healthEnabled: Bool = false
    var fitnessEnabled: Bool = false
    var calendarEnabled: Bool = true
    var remindersEnabled: Bool = true
    var notesEnabled: Bool = false
    var homeKitEnabled: Bool = false
    var contactsEnabled: Bool = false

    private static let storageKey = "iOSIntegrationsConfig"

    static func load() -> IOSIntegrationsConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSIntegrationsConfig.self, from: data) {
            return config
        }
        return IOSIntegrationsConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - iOS Sync Settings View

struct IOSSyncSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var config = IOSSyncConfig.load()

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Image(systemName: settingsManager.iCloudSyncEnabled ? "checkmark.icloud.fill" : "xmark.icloud")
                            .font(.title)
                            .foregroundStyle(settingsManager.iCloudSyncEnabled ? .green : .red)
                        Text(settingsManager.iCloudSyncEnabled ? "Synced" : "Off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("2")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("Devices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Overview")
            }

            // iCloud Sync
            Section {
                Toggle("iCloud Sync", isOn: $settingsManager.iCloudSyncEnabled)
            } header: {
                Text("iCloud")
            } footer: {
                Text("Sync your conversations and settings across all your Apple devices")
            }

            // What to Sync
            Section {
                Toggle("Conversations", isOn: $config.syncConversations)
                Toggle("Settings", isOn: $config.syncSettings)
                Toggle("Knowledge", isOn: $config.syncKnowledge)
            } header: {
                Text("Sync Content")
            }

            // Conflict Resolution
            Section {
                Picker("Conflict Resolution", selection: $config.conflictResolution) {
                    Text("Keep Most Recent").tag("recent")
                    Text("Keep Local").tag("local")
                    Text("Keep Remote").tag("remote")
                }
            } header: {
                Text("Conflicts")
            }

            // Actions
            Section {
                Button("Sync Now") {
                    // Trigger sync
                }
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSSyncConfig()
                }
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

private struct IOSSyncConfig: Equatable, Codable {
    var syncConversations: Bool = true
    var syncSettings: Bool = true
    var syncKnowledge: Bool = true
    var conflictResolution: String = "recent"

    private static let storageKey = "iOSSyncConfig"

    static func load() -> IOSSyncConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSSyncConfig.self, from: data) {
            return config
        }
        return IOSSyncConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - iOS Backup Settings View

struct IOSBackupSettingsView: View {
    @State private var config = IOSBackupConfig.load()
    @State private var showingCreateBackup = false

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Text("3")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("Backups")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("1.2 GB")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Total Size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Overview")
            }

            // Quick Actions
            Section {
                Button {
                    showingCreateBackup = true
                } label: {
                    Label("Create Backup", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Actions")
            }

            // Auto Backup
            Section {
                Toggle("Auto Backup", isOn: $config.autoBackupEnabled)

                if config.autoBackupEnabled {
                    Picker("Frequency", selection: $config.backupFrequency) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }
                }
            } header: {
                Text("Automatic Backup")
            }

            // Backup Contents
            Section {
                Toggle("Conversations", isOn: $config.backupConversations)
                Toggle("Settings", isOn: $config.backupSettings)
                Toggle("Knowledge", isOn: $config.backupKnowledge)
            } header: {
                Text("What to Back Up")
            }

            // Storage
            Section {
                Picker("Storage Location", selection: $config.storageLocation) {
                    Text("iCloud").tag("icloud")
                    Text("Local").tag("local")
                }
            } header: {
                Text("Storage")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSBackupConfig()
                }
            }
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
        .alert("Create Backup", isPresented: $showingCreateBackup) {
            Button("Create") {
                // Create backup
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will create a new backup of your data.")
        }
    }
}

private struct IOSBackupConfig: Equatable, Codable {
    var autoBackupEnabled: Bool = true
    var backupFrequency: String = "weekly"
    var backupConversations: Bool = true
    var backupSettings: Bool = true
    var backupKnowledge: Bool = true
    var storageLocation: String = "icloud"

    private static let storageKey = "iOSBackupConfig"

    static func load() -> IOSBackupConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSBackupConfig.self, from: data) {
            return config
        }
        return IOSBackupConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - iOS Privacy Settings View

struct IOSPrivacySettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var config = IOSPrivacyConfig.load()
    @State private var showingExportOptions = false

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                        Text("Protected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("\(privacyScore)%")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(privacyScoreColor)
                        Text("Privacy Score")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Overview")
            }

            // Data Collection
            Section {
                Toggle("Analytics", isOn: $settingsManager.analyticsEnabled)
                Toggle("Crash Reports", isOn: $config.crashReportsEnabled)
            } header: {
                Text("Data Collection")
            } footer: {
                Text("Help improve THEA by sharing anonymous usage data")
            }

            // Data Retention
            Section {
                Picker("Keep History", selection: $config.dataRetention) {
                    Text("7 days").tag("7")
                    Text("30 days").tag("30")
                    Text("90 days").tag("90")
                    Text("Forever").tag("forever")
                }
            } header: {
                Text("Data Retention")
            }

            // Security
            Section {
                Toggle("Require Face ID", isOn: $config.requireBiometric)
                Toggle("Lock on Background", isOn: $config.lockOnBackground)
            } header: {
                Text("Security")
            }

            // Data Management
            Section {
                Button {
                    showingExportOptions = true
                } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }

                Button("Delete All Data", role: .destructive) {
                    // Delete action
                }
            } header: {
                Text("Data Management")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSPrivacyConfig()
                }
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
        .sheet(isPresented: $showingExportOptions) {
            IOSExportOptionsView()
        }
    }

    private var privacyScore: Int {
        var score = 70
        if !settingsManager.analyticsEnabled { score += 10 }
        if !config.crashReportsEnabled { score += 5 }
        if config.requireBiometric { score += 10 }
        if config.lockOnBackground { score += 5 }
        return min(score, 100)
    }

    private var privacyScoreColor: Color {
        if privacyScore >= 80 { return .green }
        if privacyScore >= 60 { return .yellow }
        return .red
    }
}

private struct IOSPrivacyConfig: Equatable, Codable {
    var crashReportsEnabled: Bool = true
    var dataRetention: String = "30"
    var requireBiometric: Bool = false
    var lockOnBackground: Bool = false

    private static let storageKey = "iOSPrivacyConfig"

    static func load() -> IOSPrivacyConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSPrivacyConfig.self, from: data) {
            return config
        }
        return IOSPrivacyConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

struct IOSExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        // Export JSON
                        dismiss()
                    } label: {
                        Label("Export as JSON", systemImage: "curlybraces")
                    }

                    Button {
                        // Export archive
                        dismiss()
                    } label: {
                        Label("Export as Archive", systemImage: "archivebox")
                    }
                } header: {
                    Text("Format")
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - iOS Advanced Settings View

struct IOSAdvancedSettingsView: View {
    @State private var config = IOSAdvancedConfig.load()

    var body: some View {
        Form {
            // Developer
            Section {
                Toggle("Debug Mode", isOn: $config.debugMode)
                Toggle("Verbose Logging", isOn: $config.verboseLogging)
            } header: {
                Text("Developer")
            }

            // Network
            Section {
                Toggle("Use Cellular Data", isOn: $config.useCellularData)
                Stepper("Timeout: \(config.networkTimeout)s", value: $config.networkTimeout, in: 10...120, step: 10)
            } header: {
                Text("Network")
            }

            // Performance
            Section {
                Toggle("Background Refresh", isOn: $config.backgroundRefresh)
                Toggle("Prefetch Content", isOn: $config.prefetchContent)
            } header: {
                Text("Performance")
            }

            // Cache
            Section {
                LabeledContent("Cache Size", value: "125 MB")

                Button("Clear Cache") {
                    // Clear cache
                }
            } header: {
                Text("Cache")
            }

            // Diagnostics
            Section {
                Button("Generate Diagnostic Report") {
                    // Generate report
                }

                Button("Send Feedback") {
                    // Send feedback
                }
            } header: {
                Text("Diagnostics")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSAdvancedConfig()
                }
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

private struct IOSAdvancedConfig: Equatable, Codable {
    var debugMode: Bool = false
    var verboseLogging: Bool = false
    var useCellularData: Bool = true
    var networkTimeout: Int = 30
    var backgroundRefresh: Bool = true
    var prefetchContent: Bool = true

    private static let storageKey = "iOSAdvancedConfig"

    static func load() -> IOSAdvancedConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSAdvancedConfig.self, from: data) {
            return config
        }
        return IOSAdvancedConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - API Keys View

struct iOSAPIKeysView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settingsManager = SettingsManager.shared

    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var googleKey = ""
    @State private var perplexityKey = ""
    @State private var groqKey = ""
    @State private var openRouterKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $openAIKey)
                } header: {
                    Text("OpenAI")
                } footer: {
                    Text("Get your API key from platform.openai.com")
                }

                Section {
                    SecureField("API Key", text: $anthropicKey)
                } header: {
                    Text("Anthropic")
                } footer: {
                    Text("Get your API key from console.anthropic.com")
                }

                Section {
                    SecureField("API Key", text: $googleKey)
                } header: {
                    Text("Google AI")
                } footer: {
                    Text("Get your API key from makersuite.google.com")
                }

                Section {
                    SecureField("API Key", text: $perplexityKey)
                } header: {
                    Text("Perplexity")
                } footer: {
                    Text("Get your API key from perplexity.ai")
                }

                Section {
                    SecureField("API Key", text: $groqKey)
                } header: {
                    Text("Groq")
                } footer: {
                    Text("Get your API key from console.groq.com")
                }

                Section {
                    SecureField("API Key", text: $openRouterKey)
                } header: {
                    Text("OpenRouter")
                } footer: {
                    Text("Get your API key from openrouter.ai")
                }
            }
            .navigationTitle("API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAPIKeys()
                    }
                }
            }
            .onAppear {
                loadAPIKeys()
            }
        }
    }

    private func loadAPIKeys() {
        openAIKey = settingsManager.getAPIKey(for: "openai") ?? ""
        anthropicKey = settingsManager.getAPIKey(for: "anthropic") ?? ""
        googleKey = settingsManager.getAPIKey(for: "google") ?? ""
        perplexityKey = settingsManager.getAPIKey(for: "perplexity") ?? ""
        groqKey = settingsManager.getAPIKey(for: "groq") ?? ""
        openRouterKey = settingsManager.getAPIKey(for: "openrouter") ?? ""
    }

    private func saveAPIKeys() {
        if !openAIKey.isEmpty {
            settingsManager.setAPIKey(openAIKey, for: "openai")
        }
        if !anthropicKey.isEmpty {
            settingsManager.setAPIKey(anthropicKey, for: "anthropic")
        }
        if !googleKey.isEmpty {
            settingsManager.setAPIKey(googleKey, for: "google")
        }
        if !perplexityKey.isEmpty {
            settingsManager.setAPIKey(perplexityKey, for: "perplexity")
        }
        if !groqKey.isEmpty {
            settingsManager.setAPIKey(groqKey, for: "groq")
        }
        if !openRouterKey.isEmpty {
            settingsManager.setAPIKey(openRouterKey, for: "openrouter")
        }
        dismiss()
    }
}

// MARK: - Migration View

struct iOSMigrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var migrationManager = MigrationManager.shared

    @State private var selectedSource: IOSMigrationSourceType?
    @State private var showingFilePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(IOSMigrationSourceType.allCases, id: \.self) { source in
                        Button {
                            selectedSource = source
                            showingFilePicker = true
                        } label: {
                            HStack {
                                Image(systemName: source.icon)
                                    .font(.title2)
                                    .foregroundStyle(.theaPrimary)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.displayName)
                                        .font(.headline)

                                    Text(source.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Available Sources")
                } footer: {
                    Text("Import your conversations from other AI apps")
                }

                if migrationManager.isMigrating {
                    Section("Migration Progress") {
                        VStack(spacing: 12) {
                            ProgressView(value: migrationManager.migrationProgress)

                            HStack {
                                Text(migrationManager.migrationStatus)
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(migrationManager.migrationProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(migrationManager.isMigrating)
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                if let source = selectedSource {
                    iOSMigrationImportView(source: source)
                }
            }
        }
    }
}

// Migration source enumeration
enum IOSMigrationSourceType: String, CaseIterable {
    case chatGPT
    case claude
    case cursor

    var displayName: String {
        switch self {
        case .chatGPT: "ChatGPT"
        case .claude: "Claude"
        case .cursor: "Cursor"
        }
    }

    var description: String {
        switch self {
        case .chatGPT: "Import from ChatGPT export"
        case .claude: "Import from Claude conversations"
        case .cursor: "Import from Cursor AI"
        }
    }

    var icon: String {
        switch self {
        case .chatGPT: "bubble.left.and.bubble.right.fill"
        case .claude: "brain.head.profile"
        case .cursor: "cursorarrow.click.2"
        }
    }
}

struct iOSMigrationImportView: View {
    @Environment(\.dismiss) private var dismiss
    let source: IOSMigrationSourceType

    @State private var migrationManager = MigrationManager.shared
    @State private var selectedURL: URL?
    @State private var isImporting = false
    @State private var importComplete = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: source.icon)
                            .font(.largeTitle)
                            .foregroundStyle(.theaPrimary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.displayName)
                                .font(.headline)

                            Text(source.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Source")
                }

                Section {
                    Button {
                        selectedURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                    } label: {
                        HStack {
                            Text(selectedURL?.lastPathComponent ?? "Select Export File...")
                                .foregroundStyle(selectedURL == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "doc.badge.plus")
                        }
                    }
                } header: {
                    Text("Export File")
                } footer: {
                    Text("Select the exported JSON file from \(source.displayName)")
                }

                if migrationManager.isMigrating {
                    Section("Migration Progress") {
                        VStack(spacing: 12) {
                            ProgressView(value: migrationManager.migrationProgress)

                            HStack {
                                Text(migrationManager.migrationStatus)
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(migrationManager.migrationProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if importComplete {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title)

                            Text("Import Complete")
                                .font(.headline)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)

                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if migrationManager.isMigrating {
                            migrationManager.cancelMigration()
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(importComplete ? "Done" : "Import") {
                        if importComplete {
                            dismiss()
                        } else {
                            startImport()
                        }
                    }
                    .disabled(isImporting || selectedURL == nil)
                }
            }
        }
    }

    private func startImport() {
        guard let url = selectedURL else { return }

        isImporting = true
        errorMessage = nil

        Task {
            do {
                switch source {
                case .chatGPT:
                    try await migrationManager.migrateFromChatGPT(exportPath: url)
                case .claude:
                    try await migrationManager.migrateFromClaude(exportPath: url)
                case .cursor:
                    try await migrationManager.migrateFromNexus(path: url)
                }
                importComplete = true
                isImporting = false
            } catch {
                isImporting = false
                errorMessage = error.localizedDescription
                print("Import failed: \(error)")
            }
        }
    }
}

// MARK: - About View

struct iOSAboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundStyle(.theaPrimary)

                    VStack(spacing: 8) {
                        Text("THEA")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Your AI Life Companion")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 16) {
                        InfoRow(label: "Version", value: "1.0.0")
                        InfoRow(label: "Build", value: "2026.01.29")
                        InfoRow(label: "Platform", value: "iOS")
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 16) {
                        Text("Features")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        FeatureRow(icon: "message.fill", title: "Multi-Provider AI", description: "Support for OpenAI, Anthropic, Google, and more")
                        FeatureRow(icon: "mic.fill", title: "Voice Activation", description: "Hands-free interaction with wake word")
                        FeatureRow(icon: "brain.head.profile", title: "Knowledge Base", description: "Semantic search across your entire Mac")
                        FeatureRow(icon: "dollarsign.circle.fill", title: "Financial Insights", description: "AI-powered budget recommendations")
                        FeatureRow(icon: "terminal.fill", title: "Code Intelligence", description: "Multi-file context and Git integration")
                        FeatureRow(icon: "arrow.down.doc.fill", title: "Easy Migration", description: "Import from Claude, ChatGPT, Cursor")
                    }

                    VStack(spacing: 12) {
                        Text("Made with ❤️ for teathe.app")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("© 2026 THEA. All rights reserved.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.theaPrimary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - iOS Permissions View

struct IOSPermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var permissionsManager = PermissionsManager.shared
    @State private var expandedCategories: Set<PermissionCategory> = Set(PermissionCategory.allCases)
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            List {
                overviewSection

                ForEach(permissionsManager.availableCategories) { category in
                    Section {
                        ForEach(permissionsManager.permissions(for: category), id: \.id) { permission in
                            IOSPermissionRow(
                                permission: permission,
                                onRequest: {
                                    Task {
                                        _ = await permissionsManager.requestPermission(for: permission.type)
                                    }
                                },
                                onOpenSettings: {
                                    permissionsManager.openSystemSettings()
                                }
                            )
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            }
            .refreshable {
                await permissionsManager.refreshAllPermissions()
            }
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var overviewSection: some View {
        Section {
            HStack(spacing: 16) {
                VStack {
                    Text("\(permissionsManager.allPermissions.filter { $0.status == .authorized }.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("Granted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text("\(permissionsManager.allPermissions.filter { $0.status == .denied }.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                    Text("Denied")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text("\(permissionsManager.allPermissions.filter { $0.status == .notDetermined }.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.gray)
                    Text("Not Set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)

            Button {
                permissionsManager.openSystemSettings()
            } label: {
                Label("Open Settings", systemImage: "gear")
            }
        } footer: {
            if let lastRefresh = permissionsManager.lastRefreshDate {
                Text("Last updated \(lastRefresh, style: .relative) ago. Pull to refresh.")
            }
        }
    }
}

private struct IOSPermissionRow: View {
    let permission: PermissionInfo
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: permission.status.icon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.type.rawValue)
                    .font(.subheadline)

                Text(permission.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if permission.canRequest {
                Button("Allow", action: onRequest)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else if permission.canOpenSettings {
                Button(action: onOpenSettings) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text(permission.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch permission.status {
        case .authorized: .green
        case .denied: .red
        case .restricted: .orange
        case .limited: .yellow
        case .provisional: .blue
        case .notDetermined, .notAvailable: .gray
        }
    }
}
// swiftlint:enable file_length type_name
