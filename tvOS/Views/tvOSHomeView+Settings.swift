// swiftlint:disable type_name
import SwiftUI

// MARK: - tvOS Design Tokens (local to avoid Shared dependency)

enum TVSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum TVCornerRadius {
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
}

extension Color {
    static let tvPrimary = Color(red: 0.96, green: 0.65, blue: 0.14) // TheaBrandColors.gold
}

// MARK: - Settings View

struct tvOSSettingsView: View {
    @State private var config = TVOSSettingsConfig.load()

    var body: some View {
        List {
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

            Section("Privacy & Security") {
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

// MARK: - Settings Row

struct tvOSSettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: TVSpacing.xl) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: TVCornerRadius.md))

            VStack(alignment: .leading, spacing: TVSpacing.xs) {
                Text(title)
                    .font(.title3)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, TVSpacing.sm)
    }
}

// MARK: - AI Settings

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

// MARK: - Voice Settings

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
        }
        .navigationTitle("Voice")
    }
}

// MARK: - Appearance Settings

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

// MARK: - Sync Settings

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
                    Button("Sync Now") {
                        // Sync action
                    }
                }
            }
        }
        .navigationTitle("Sync")
    }
}

// MARK: - Privacy Settings

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

// MARK: - About View

struct tvOSAboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Image(systemName: "sparkles")
                    .font(.system(size: 100))
                    .foregroundStyle(Color.tvPrimary)

                VStack(spacing: TVSpacing.sm) {
                    Text("THEA")
                        .font(.system(size: 60, weight: .bold, design: .rounded))

                    Text("Your AI Life Companion")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 60) {
                    tvOSInfoPill(label: "Version", value: "1.0.0")
                    tvOSInfoPill(label: "Build", value: "2026.02")
                    tvOSInfoPill(label: "Platform", value: "tvOS")
                }
                .padding(TVSpacing.xl)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: TVCornerRadius.lg))

                HStack(spacing: 40) {
                    tvOSFeatureCard(icon: "cpu", title: "Multi-Provider AI")
                    tvOSFeatureCard(icon: "mic.fill", title: "Voice Input")
                    tvOSFeatureCard(icon: "icloud.fill", title: "iCloud Sync")
                }

                Text("2026 THEA. All rights reserved.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .padding(60)
        }
        .navigationTitle("About")
    }
}

private struct tvOSInfoPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: TVSpacing.xs) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.medium)
        }
    }
}

struct tvOSFeatureCard: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: TVSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.tvPrimary)

            Text(title)
                .font(.callout)
                .multilineTextAlignment(.center)
        }
        .frame(width: 160)
        .padding(TVSpacing.xl)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TVCornerRadius.lg))
        .focusable()
    }
}

// MARK: - tvOS Settings Configuration

struct TVOSSettingsConfig: Codable, Equatable {
    var defaultProvider: String = "OpenAI"
    var streamResponses: Bool = true
    var responseLength: String = "normal"
    var rememberContext: Bool = true
    var suggestFollowups: Bool = true

    var voiceInputEnabled: Bool = true
    var speakResponses: Bool = false
    var voiceType: String = "default"
    var speechRate: Double = 1.0

    var theme: String = "system"
    var fontSize: String = "medium"
    var boldText: Bool = false
    var reduceMotion: Bool = false

    var iCloudSyncEnabled: Bool = true
    var syncConversations: Bool = true
    var syncSettings: Bool = true
    var syncKnowledge: Bool = true

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
// swiftlint:enable type_name
