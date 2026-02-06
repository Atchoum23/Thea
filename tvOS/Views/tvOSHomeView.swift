// swiftlint:disable type_name
import SwiftUI

// MARK: - tvOS Home View (10-Foot, Focus-Based)

/// tvOS home view designed for 10-foot viewing distance.
/// Hero card for current conversation, voice-first input,
/// focus-based navigation, large typography.
struct tvOSHomeView: View {
    @State private var selectedTab: Tab = .chat
    @State private var messages: [TVMessage] = []

    enum Tab: String, CaseIterable {
        case chat = "Chat"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .chat: "bubble.left.and.bubble.right.fill"
            case .settings: "gearshape"
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
            tvOSChatView(messages: $messages)
        case .settings:
            tvOSSettingsView()
        }
    }
}

// MARK: - Chat View (Hero Layout)

struct tvOSChatView: View {
    @Binding var messages: [TVMessage]
    @State private var isListening = false

    var body: some View {
        ScrollView {
            VStack(spacing: TheaSpacing.xxxl) {
                if messages.isEmpty {
                    heroWelcomeView
                } else {
                    heroConversationCard
                }

                voiceDictationButton

                if !messages.isEmpty {
                    conversationHistory
                }

                quickSuggestions
            }
            .padding(.horizontal, 80)
            .padding(.vertical, TheaSpacing.xxl)
        }
        .navigationTitle("Thea")
    }

    // MARK: - Hero Welcome

    private var heroWelcomeView: some View {
        VStack(spacing: TheaSpacing.xl) {
            Image(systemName: "sparkles")
                .font(.system(size: 80, weight: .medium))
                .foregroundStyle(Color.theaPrimaryDefault)
                .symbolEffect(.pulse, options: .repeating)

            Text("Welcome to Thea")
                .font(.system(size: 52, weight: .bold, design: .rounded))

            Text("Your AI Life Companion on Apple TV")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Hero Conversation Card

    private var heroConversationCard: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.lg) {
            // Last exchange
            if let lastUserMsg = messages.last(where: { $0.isUser }) {
                HStack(alignment: .top, spacing: TheaSpacing.lg) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)

                    Text(lastUserMsg.content)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if let lastResponse = messages.last(where: { !$0.isUser }) {
                HStack(alignment: .top, spacing: TheaSpacing.lg) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.theaPrimaryDefault)

                    Text(lastResponse.content)
                        .font(.title3)
                        .lineLimit(6)
                }
            }

            HStack {
                Spacer()
                Text(messages.last?.timestamp ?? Date(), style: .relative)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(TheaSpacing.xxl)
        .frame(maxWidth: 1000, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.xl))
        .focusable()
        #if os(tvOS)
        .hoverEffect(.highlight)
        #endif
    }

    // MARK: - Voice Dictation Button

    private var voiceDictationButton: some View {
        Button {
            toggleListening()
        } label: {
            HStack(spacing: TheaSpacing.lg) {
                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(isListening ? .red : Color.theaPrimaryDefault)
                    .symbolEffect(.variableColor, isActive: isListening)

                VStack(alignment: .leading, spacing: TheaSpacing.xxs) {
                    Text(isListening ? "Listening..." : "Press to Speak")
                        .font(.title2.bold())

                    Text(isListening ? "Release to send" : "Use Siri Remote or press to dictate")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(TheaSpacing.xl)
            .frame(maxWidth: 800)
            .background(isListening ? Color.red.opacity(0.15) : .ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.xl))
        }
        .buttonStyle(.plain)
        .focusable()
        #if os(tvOS)
        .hoverEffect(.highlight)
        #endif
    }

    // MARK: - Conversation History

    private var conversationHistory: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.md) {
            Text("Conversation")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, TheaSpacing.sm)

            LazyVStack(spacing: TheaSpacing.md) {
                ForEach(messages) { message in
                    TVMessageCard(message: message)
                }
            }
        }
    }

    // MARK: - Quick Suggestions

    private var quickSuggestions: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.lg) {
            Text(messages.isEmpty ? "Try asking" : "Suggestions")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, TheaSpacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TheaSpacing.lg) {
                    TVSuggestionCard(icon: "text.bubble", text: "Help me write something") {
                        sendMessage("Help me write an email")
                    }
                    TVSuggestionCard(icon: "lightbulb", text: "Brainstorm ideas") {
                        sendMessage("Give me creative project ideas")
                    }
                    TVSuggestionCard(icon: "globe", text: "Explain a topic") {
                        sendMessage("Explain a concept to me")
                    }
                    TVSuggestionCard(icon: "checklist", text: "Plan my day") {
                        sendMessage("Help me plan my day")
                    }
                }
                .padding(.horizontal, TheaSpacing.sm)
            }
        }
    }

    // MARK: - Actions

    private func toggleListening() {
        isListening.toggle()

        if !isListening {
            sendMessage("Hello, Thea!")
        }
    }

    private func sendMessage(_ text: String) {
        let userMessage = TVMessage(content: text, isUser: true)
        messages.append(userMessage)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = TVMessage(
                content: "I'd be happy to help you with that! Full AI integration coming soon.",
                isUser: false
            )
            messages.append(response)
        }
    }
}

// MARK: - TV Message Card

struct TVMessageCard: View {
    let message: TVMessage

    var body: some View {
        HStack(alignment: .top, spacing: TheaSpacing.lg) {
            Image(systemName: message.isUser ? "person.circle.fill" : "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(message.isUser ? .secondary : Color.theaPrimaryDefault)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: TheaSpacing.xs) {
                Text(message.isUser ? "You" : "Thea")
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)

                Text(message.content)
                    .font(.title3)
            }

            Spacer()
        }
        .padding(TheaSpacing.xl)
        .frame(maxWidth: 1000, alignment: .leading)
        .background(message.isUser ? Color.clear : .ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.lg))
        .focusable()
    }
}

// MARK: - TV Suggestion Card

struct TVSuggestionCard: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: TheaSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(Color.theaPrimaryDefault)

                Text(text)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 200, height: 140)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.lg))
        }
        .buttonStyle(.plain)
        .focusable()
        #if os(tvOS)
        .hoverEffect(.highlight)
        #endif
    }
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
        HStack(spacing: TheaSpacing.xl) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.md))

            VStack(alignment: .leading, spacing: TheaSpacing.xxs) {
                Text(title)
                    .font(.title3)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, TheaSpacing.sm)
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
                    .foregroundStyle(Color.theaPrimaryDefault)

                VStack(spacing: TheaSpacing.sm) {
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
                .padding(TheaSpacing.xl)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.lg))

                HStack(spacing: 40) {
                    tvOSFeatureCard(icon: "cpu", title: "Multi-Provider AI")
                    tvOSFeatureCard(icon: "mic.fill", title: "Voice Input")
                    tvOSFeatureCard(icon: "icloud.fill", title: "iCloud Sync")
                }

                Text("© 2026 THEA. All rights reserved.")
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
        VStack(spacing: TheaSpacing.xs) {
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
        VStack(spacing: TheaSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.theaPrimaryDefault)

            Text(title)
                .font(.callout)
                .multilineTextAlignment(.center)
        }
        .frame(width: 160)
        .padding(TheaSpacing.xl)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.lg))
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
