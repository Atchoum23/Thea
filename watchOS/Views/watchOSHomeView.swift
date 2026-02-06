// swiftlint:disable type_name
import SwiftUI

// MARK: - watchOS Home View (Voice-First, Glanceable)

/// Voice-first watchOS experience.
/// Primary screen: large voice activation button.
/// NavigationStack for recent conversations and settings.
struct watchOSHomeView: View {
    @State private var messages: [WatchMessage] = []
    @State private var isListening = false
    @State private var showingConversations = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TheaSpacing.lg) {
                    voiceActivationCard
                    recentConversationsSection
                    quickActionsSection
                }
                .padding(.horizontal, TheaSpacing.sm)
            }
            .navigationTitle("Thea")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        watchOSSettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    // MARK: - Voice Activation Card

    private var voiceActivationCard: some View {
        Button {
            toggleListening()
        } label: {
            VStack(spacing: TheaSpacing.md) {
                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(isListening ? .red : Color.theaPrimaryDefault)
                    .symbolEffect(.variableColor, isActive: isListening)
                    .frame(width: 70, height: 70)

                Text(isListening ? "Listening..." : "Tap to speak")
                    .font(.body.bold())

                if !isListening {
                    Text("or say \"Hey Thea\"")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TheaSpacing.lg)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.lg))
    }

    // MARK: - Recent Conversations

    private var recentConversationsSection: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            if !messages.isEmpty {
                Text("Recent")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.leading, TheaSpacing.xxs)

                // Show last assistant message as a preview card
                if let lastResponse = messages.last(where: { !$0.isUser }) {
                    VStack(alignment: .leading, spacing: TheaSpacing.xs) {
                        HStack(spacing: TheaSpacing.xs) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(Color.theaPrimaryDefault)
                            Text("Thea")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(lastResponse.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Text(lastResponse.content)
                            .font(.body)
                            .lineLimit(3)

                        // Quick reply chips
                        HStack(spacing: TheaSpacing.xs) {
                            WatchQuickReply(text: "Tell me more") {
                                sendQuickReply("Tell me more")
                            }
                            WatchQuickReply(text: "Thanks") {
                                sendQuickReply("Thanks")
                            }
                        }
                    }
                    .padding(TheaSpacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.md))
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: TheaSpacing.sm) {
            WatchActionRow(icon: "text.bubble", label: "Compose") {
                sendQuickReply("Help me compose a message")
            }

            WatchActionRow(icon: "lightbulb", label: "Ideas") {
                sendQuickReply("Give me some ideas for today")
            }

            WatchActionRow(icon: "checklist", label: "Tasks") {
                sendQuickReply("What are my tasks for today?")
            }
        }
    }

    // MARK: - Actions

    private func toggleListening() {
        isListening.toggle()

        if !isListening {
            let userMessage = WatchMessage(content: "Hello, Thea!", isUser: true)
            messages.append(userMessage)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let response = WatchMessage(
                    content: "Hello! How can I help you today?",
                    isUser: false
                )
                messages.append(response)
            }
        }
    }

    private func sendQuickReply(_ text: String) {
        let userMessage = WatchMessage(content: text, isUser: true)
        messages.append(userMessage)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = WatchMessage(
                content: "I'll help you with that right away.",
                isUser: false
            )
            messages.append(response)
        }
    }
}

// MARK: - Quick Reply Button

private struct WatchQuickReply: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption2)
                .padding(.horizontal, TheaSpacing.sm)
                .padding(.vertical, TheaSpacing.xxs)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Watch Action Row

private struct WatchActionRow: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TheaSpacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.theaPrimaryDefault)
                    .frame(width: 28)

                Text(label)
                    .font(.body)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, TheaSpacing.sm)
            .padding(.horizontal, TheaSpacing.md)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.md))
    }
}

// MARK: - Settings View

struct watchOSSettingsView: View {
    @State private var config = WatchOSSettingsConfig.load()

    var body: some View {
        List {
            Section("Voice") {
                NavigationLink {
                    watchOSVoiceSettingsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Voice")
                                .font(.body)
                            Text(config.voiceEnabled ? "Enabled" : "Disabled")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "waveform.circle.fill")
                            .foregroundStyle(.pink)
                    }
                }
            }

            Section("Sync") {
                NavigationLink {
                    watchOSSyncSettingsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud Sync")
                                .font(.body)
                            Text(config.iCloudSyncEnabled ? "On" : "Off")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(.cyan)
                    }
                }
            }

            Section("Privacy") {
                NavigationLink {
                    watchOSPrivacySettingsView()
                } label: {
                    Label("Privacy", systemImage: "hand.raised.fill")
                        .font(.body)
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                    .font(.body)
                LabeledContent("Build", value: "2026.02")
                    .font(.body)
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - watchOS Voice Settings

struct watchOSVoiceSettingsView: View {
    @State private var config = WatchOSSettingsConfig.load()

    var body: some View {
        List {
            Section {
                Toggle("Voice Activation", isOn: $config.voiceEnabled)
                    .font(.body)
                    .onChange(of: config.voiceEnabled) { _, _ in config.save() }
            } footer: {
                Text("Use wake word to activate")
            }

            if config.voiceEnabled {
                Section("Wake Word") {
                    Text(config.wakeWord)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text("Say '\(config.wakeWord)' to start")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Section("Mode") {
                    Toggle("Conversation Mode", isOn: $config.conversationMode)
                        .font(.body)
                        .onChange(of: config.conversationMode) { _, _ in config.save() }
                }
            }
        }
        .navigationTitle("Voice")
    }
}

// MARK: - watchOS Sync Settings

struct watchOSSyncSettingsView: View {
    @State private var config = WatchOSSettingsConfig.load()

    var body: some View {
        List {
            Section {
                Toggle("iCloud Sync", isOn: $config.iCloudSyncEnabled)
                    .font(.body)
                    .onChange(of: config.iCloudSyncEnabled) { _, _ in config.save() }
            } footer: {
                Text("Sync with iPhone and Mac")
            }

            if config.iCloudSyncEnabled {
                Section("What to Sync") {
                    Toggle("Conversations", isOn: $config.syncConversations)
                        .font(.body)
                        .onChange(of: config.syncConversations) { _, _ in config.save() }

                    Toggle("Settings", isOn: $config.syncSettings)
                        .font(.body)
                        .onChange(of: config.syncSettings) { _, _ in config.save() }
                }

                Section {
                    Button("Sync Now") {
                        // Trigger sync
                    }
                    .font(.body)
                }
            }
        }
        .navigationTitle("Sync")
    }
}

// MARK: - watchOS Privacy Settings

struct watchOSPrivacySettingsView: View {
    @State private var config = WatchOSSettingsConfig.load()

    var body: some View {
        List {
            Section("Data") {
                Toggle("Analytics", isOn: $config.analyticsEnabled)
                    .font(.body)
                    .onChange(of: config.analyticsEnabled) { _, _ in config.save() }
            }

            Section("Security") {
                Toggle("Passcode Lock", isOn: $config.requirePasscode)
                    .font(.body)
                    .onChange(of: config.requirePasscode) { _, _ in config.save() }
            }

            Section {
                Button("Clear Data", role: .destructive) {
                    // Clear data
                }
                .font(.body)
            }
        }
        .navigationTitle("Privacy")
    }
}

// MARK: - watchOS Configuration

struct WatchOSSettingsConfig: Codable, Equatable {
    var voiceEnabled: Bool = false
    var wakeWord: String = "Hey Thea"
    var conversationMode: Bool = false

    var iCloudSyncEnabled: Bool = true
    var syncConversations: Bool = true
    var syncSettings: Bool = true

    var analyticsEnabled: Bool = false
    var requirePasscode: Bool = false

    private static let storageKey = "WatchOSSettingsConfig"

    static func load() -> WatchOSSettingsConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(WatchOSSettingsConfig.self, from: data) {
            return config
        }
        return WatchOSSettingsConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Models

struct WatchMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}

// MARK: - Preview

#Preview {
    watchOSHomeView()
}
// swiftlint:enable type_name
