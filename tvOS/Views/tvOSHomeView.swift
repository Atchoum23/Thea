// swiftlint:disable type_name
import SwiftUI

// MARK: - tvOS Home View (Standalone)

struct tvOSHomeView: View {
    @State private var selectedTab: Tab = .chat
    @State private var messages: [TVMessage] = []
    @State private var inputText: String = ""

    enum Tab: String, CaseIterable {
        case chat = "Chat"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .chat: "message.fill"
            case .settings: "gear"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                NavigationStack {
                    viewForTab(tab)
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func viewForTab(_ tab: Tab) -> some View {
        switch tab {
        case .chat:
            tvOSChatView(messages: $messages, inputText: $inputText)
        case .settings:
            tvOSSettingsView()
        }
    }
}

// MARK: - Chat View

struct tvOSChatView: View {
    @Binding var messages: [TVMessage]
    @Binding var inputText: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                placeholderView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            TVMessageRow(message: message)
                        }
                    }
                    .padding()
                }
            }

            inputBar
        }
        .navigationTitle("Thea")
    }

    private var placeholderView: some View {
        VStack(spacing: 32) {
            Image(systemName: "message.fill")
                .font(.system(size: 100))
                .foregroundStyle(.blue)

            Text("Welcome to THEA")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your AI Life Companion on Apple TV")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Start a conversation below")
                .font(.title3)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputBar: some View {
        HStack(spacing: 16) {
            TextField("Ask Thea...", text: $inputText)
                .font(.title3)
                .focused($isFocused)
                .onSubmit(sendMessage)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 44))
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = TVMessage(content: text, isUser: true)
        messages.append(userMessage)
        inputText = ""

        // Simulate AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = TVMessage(
                content: "This is a placeholder response. Full AI integration coming soon!",
                isUser: false
            )
            messages.append(response)
        }
    }
}

// MARK: - Message Row

struct TVMessageRow: View {
    let message: TVMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            Text(message.content)
                .padding()
                .background(message.isUser ? Color.blue : Color.gray.opacity(0.3))
                .foregroundStyle(message.isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 800, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser { Spacer() }
        }
    }
}

// MARK: - Settings View

struct tvOSSettingsView: View {
    @State private var config = TVOSSettingsConfig.load()

    var body: some View {
        List {
            // MARK: - AI Settings
            Section("AI & Models") {
                NavigationLink {
                    tvOSAISettingsView()
                } label: {
                    tvOSSettingsRow(
                        icon: "cpu",
                        iconColor: .purple,
                        title: "AI Provider",
                        subtitle: config.defaultProvider
                    )
                }

                NavigationLink {
                    tvOSVoiceSettingsView()
                } label: {
                    tvOSSettingsRow(
                        icon: "waveform.circle.fill",
                        iconColor: .pink,
                        title: "Voice",
                        subtitle: "Remote voice input"
                    )
                }
            }

            // MARK: - Appearance
            Section("Appearance") {
                NavigationLink {
                    tvOSAppearanceSettingsView()
                } label: {
                    tvOSSettingsRow(
                        icon: "paintbrush.fill",
                        iconColor: .blue,
                        title: "Theme & Display",
                        subtitle: config.theme.capitalized
                    )
                }
            }

            // MARK: - Data & Sync
            Section("Data & Sync") {
                NavigationLink {
                    tvOSSyncSettingsView()
                } label: {
                    tvOSSettingsRow(
                        icon: "icloud.fill",
                        iconColor: .cyan,
                        title: "iCloud Sync",
                        subtitle: config.iCloudSyncEnabled ? "Enabled" : "Disabled"
                    )
                }
            }

            // MARK: - Privacy & Security
            Section("Privacy & Security") {
                NavigationLink {
                    tvOSPermissionsView()
                } label: {
                    tvOSSettingsRow(
                        icon: "hand.raised.fill",
                        iconColor: .red,
                        title: "Permissions",
                        subtitle: "App access"
                    )
                }

                NavigationLink {
                    tvOSPrivacySettingsView()
                } label: {
                    tvOSSettingsRow(
                        icon: "lock.shield.fill",
                        iconColor: .gray,
                        title: "Privacy",
                        subtitle: "Data & analytics"
                    )
                }
            }

            // MARK: - About
            Section("About") {
                NavigationLink {
                    tvOSAboutView()
                } label: {
                    tvOSSettingsRow(
                        icon: "info.circle.fill",
                        iconColor: .blue,
                        title: "About THEA",
                        subtitle: "Version 1.0.0"
                    )
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Settings Row Component

struct tvOSSettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - tvOS AI Settings

struct tvOSAISettingsView: View {
    @State private var config = TVOSSettingsConfig.load()

    private let availableProviders = ["OpenAI", "Anthropic", "Google", "Perplexity", "Groq"]

    var body: some View {
        List {
            Section("Default Provider") {
                Picker("Provider", selection: $config.defaultProvider) {
                    ForEach(availableProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }
                .onChange(of: config.defaultProvider) { _, _ in config.save() }
            }

            Section("Response") {
                Toggle("Stream Responses", isOn: $config.streamResponses)
                    .onChange(of: config.streamResponses) { _, _ in config.save() }

                Picker("Response Length", selection: $config.responseLength) {
                    Text("Concise").tag("concise")
                    Text("Normal").tag("normal")
                    Text("Detailed").tag("detailed")
                }
                .onChange(of: config.responseLength) { _, _ in config.save() }
            }

            Section("Behavior") {
                Toggle("Remember Context", isOn: $config.rememberContext)
                    .onChange(of: config.rememberContext) { _, _ in config.save() }

                Toggle("Suggest Follow-ups", isOn: $config.suggestFollowups)
                    .onChange(of: config.suggestFollowups) { _, _ in config.save() }
            }
        }
        .navigationTitle("AI Settings")
    }
}

// MARK: - tvOS Voice Settings

struct tvOSVoiceSettingsView: View {
    @State private var config = TVOSSettingsConfig.load()

    var body: some View {
        List {
            Section("Input") {
                Toggle("Voice Input via Remote", isOn: $config.voiceInputEnabled)
                    .onChange(of: config.voiceInputEnabled) { _, _ in config.save() }
            }

            Section("Output") {
                Toggle("Speak Responses", isOn: $config.speakResponses)
                    .onChange(of: config.speakResponses) { _, _ in config.save() }

                if config.speakResponses {
                    Picker("Voice", selection: $config.voiceType) {
                        Text("Default").tag("default")
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                    }
                    .onChange(of: config.voiceType) { _, _ in config.save() }

                    Picker("Speed", selection: $config.speechRate) {
                        Text("0.5x").tag(0.5)
                        Text("0.75x").tag(0.75)
                        Text("1.0x").tag(1.0)
                        Text("1.25x").tag(1.25)
                        Text("1.5x").tag(1.5)
                        Text("2.0x").tag(2.0)
                    }
                    .onChange(of: config.speechRate) { _, _ in config.save() }
                }
            }

            Section {
                Button("Test Voice") {
                    // Test voice
                }
            }
        }
        .navigationTitle("Voice")
    }
}

// MARK: - tvOS Appearance Settings

struct tvOSAppearanceSettingsView: View {
    @State private var config = TVOSSettingsConfig.load()

    var body: some View {
        List {
            Section("Theme") {
                Picker("Theme", selection: $config.theme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .onChange(of: config.theme) { _, _ in config.save() }
            }

            Section("Text") {
                Picker("Font Size", selection: $config.fontSize) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                    Text("Extra Large").tag("xlarge")
                }
                .onChange(of: config.fontSize) { _, _ in config.save() }

                Toggle("Bold Text", isOn: $config.boldText)
                    .onChange(of: config.boldText) { _, _ in config.save() }
            }

            Section("Animation") {
                Toggle("Reduce Motion", isOn: $config.reduceMotion)
                    .onChange(of: config.reduceMotion) { _, _ in config.save() }
            }
        }
        .navigationTitle("Appearance")
    }
}

// MARK: - tvOS Sync Settings

struct tvOSSyncSettingsView: View {
    @State private var config = TVOSSettingsConfig.load()

    var body: some View {
        List {
            Section {
                Toggle("iCloud Sync", isOn: $config.iCloudSyncEnabled)
                    .onChange(of: config.iCloudSyncEnabled) { _, _ in config.save() }
            } footer: {
                Text("Sync conversations and settings across your Apple devices")
            }

            if config.iCloudSyncEnabled {
                Section("What to Sync") {
                    Toggle("Conversations", isOn: $config.syncConversations)
                        .onChange(of: config.syncConversations) { _, _ in config.save() }

                    Toggle("Settings", isOn: $config.syncSettings)
                        .onChange(of: config.syncSettings) { _, _ in config.save() }

                    Toggle("Knowledge", isOn: $config.syncKnowledge)
                        .onChange(of: config.syncKnowledge) { _, _ in config.save() }
                }

                Section {
                    LabeledContent("Last Sync", value: "Just now")
                    LabeledContent("Devices", value: "3 connected")

                    Button("Sync Now") {
                        // Sync action
                    }
                }
            }
        }
        .navigationTitle("Sync")
    }
}

// MARK: - tvOS Privacy Settings

struct tvOSPrivacySettingsView: View {
    @State private var config = TVOSSettingsConfig.load()

    var body: some View {
        List {
            Section("Data Collection") {
                Toggle("Analytics", isOn: $config.analyticsEnabled)
                    .onChange(of: config.analyticsEnabled) { _, _ in config.save() }

                Toggle("Crash Reports", isOn: $config.crashReports)
                    .onChange(of: config.crashReports) { _, _ in config.save() }
            }

            Section("Data Retention") {
                Picker("Keep History", selection: $config.historyRetention) {
                    Text("7 Days").tag("7")
                    Text("30 Days").tag("30")
                    Text("90 Days").tag("90")
                    Text("Forever").tag("forever")
                }
                .onChange(of: config.historyRetention) { _, _ in config.save() }
            }

            Section("Danger Zone") {
                Button("Clear Conversation History", role: .destructive) {
                    // Clear history
                }

                Button("Reset All Settings", role: .destructive) {
                    // Reset settings
                }
            }
        }
        .navigationTitle("Privacy")
    }
}

// MARK: - tvOS Permissions View (Simplified)

struct tvOSPermissionsView: View {
    var body: some View {
        List {
            Section {
                Text("Manage permissions in the Settings app on your Apple TV.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Required Permissions") {
                tvOSSimplePermissionRow(name: "Microphone", icon: "mic.fill", description: "For voice input via Siri Remote")
                tvOSSimplePermissionRow(name: "Speech Recognition", icon: "waveform", description: "For voice commands")
            }

            Section("Optional Permissions") {
                tvOSSimplePermissionRow(name: "HomeKit", icon: "homekit", description: "For smart home control")
                tvOSSimplePermissionRow(name: "Apple Music", icon: "music.note", description: "For music playback")
            }

            Section {
                Text("To change permissions, go to Settings > Apps > THEA on your Apple TV.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("Permissions")
    }
}

private struct tvOSSimplePermissionRow: View {
    let name: String
    let icon: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title3)

                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - tvOS About View

struct tvOSAboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Logo
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 120))
                    .foregroundStyle(.blue)

                // Title
                VStack(spacing: 8) {
                    Text("THEA")
                        .font(.system(size: 60, weight: .bold))

                    Text("Your AI Life Companion")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                // Info
                HStack(spacing: 60) {
                    VStack(spacing: 8) {
                        Text("Version")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("1.0.0")
                            .font(.title3)
                            .fontWeight(.medium)
                    }

                    VStack(spacing: 8) {
                        Text("Build")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("2026.01.29")
                            .font(.title3)
                            .fontWeight(.medium)
                    }

                    VStack(spacing: 8) {
                        Text("Platform")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("tvOS")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)

                // Features
                VStack(spacing: 16) {
                    Text("Features")
                        .font(.title3)
                        .fontWeight(.semibold)

                    HStack(spacing: 40) {
                        tvOSFeatureCard(icon: "message.fill", title: "Multi-Provider AI")
                        tvOSFeatureCard(icon: "mic.fill", title: "Voice Input")
                        tvOSFeatureCard(icon: "icloud.fill", title: "iCloud Sync")
                    }
                }

                // Copyright
                Text("© 2026 THEA. All rights reserved.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .padding(60)
        }
        .navigationTitle("About")
    }
}

struct tvOSFeatureCard: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text(title)
                .font(.callout)
                .multilineTextAlignment(.center)
        }
        .frame(width: 150)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - tvOS Settings Configuration

struct TVOSSettingsConfig: Codable, Equatable {
    // AI
    var defaultProvider: String = "OpenAI"
    var streamResponses: Bool = true
    var responseLength: String = "normal"
    var rememberContext: Bool = true
    var suggestFollowups: Bool = true

    // Voice
    var voiceInputEnabled: Bool = true
    var speakResponses: Bool = false
    var voiceType: String = "default"
    var speechRate: Double = 1.0

    // Appearance
    var theme: String = "system"
    var fontSize: String = "medium"
    var boldText: Bool = false
    var reduceMotion: Bool = false

    // Sync
    var iCloudSyncEnabled: Bool = true
    var syncConversations: Bool = true
    var syncSettings: Bool = true
    var syncKnowledge: Bool = true

    // Privacy
    var analyticsEnabled: Bool = false
    var crashReports: Bool = true
    var historyRetention: String = "30"

    private static let storageKey = "TVOSSettingsConfig"

    static func load() -> TVOSSettingsConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(TVOSSettingsConfig.self, from: data) {
            return config
        }
        return TVOSSettingsConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Models

struct TVMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}

// MARK: - Preview

#Preview {
    tvOSHomeView()
}
// swiftlint:enable type_name
