// swiftlint:disable type_name
import SwiftUI

// MARK: - watchOS Design Tokens (local to avoid Shared dependency)

private enum WatchSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
}

private enum WatchCornerRadius {
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
}

private extension Color {
    static let watchPrimary = Color(red: 0.96, green: 0.65, blue: 0.14) // TheaBrandColors.gold
}

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
                VStack(spacing: WatchSpacing.lg) {
                    voiceActivationCard
                    recentConversationsSection
                    quickActionsSection
                }
                .padding(.horizontal, WatchSpacing.sm)
            }
            .navigationTitle("Thea")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        watchOSSettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
    }

    // MARK: - Voice Activation Card

    private var voiceActivationCard: some View {
        Button {
            toggleListening()
        } label: {
            VStack(spacing: WatchSpacing.md) {
                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(isListening ? .red : Color.watchPrimary)
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
            .padding(.vertical, WatchSpacing.lg)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: WatchCornerRadius.lg))
        .accessibilityLabel(isListening ? "Stop listening" : "Tap to speak to Thea")
        .accessibilityHint(isListening ? "Stops voice input" : "Activates voice input")
    }

    // MARK: - Recent Conversations

    private var recentConversationsSection: some View {
        VStack(alignment: .leading, spacing: WatchSpacing.sm) {
            if !messages.isEmpty {
                Text("Recent")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.leading, WatchSpacing.xxs)

                // Show last assistant message as a preview card
                if let lastResponse = messages.last(where: { !$0.isUser }) {
                    VStack(alignment: .leading, spacing: WatchSpacing.xs) {
                        HStack(spacing: WatchSpacing.xs) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(Color.watchPrimary)
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
                        HStack(spacing: WatchSpacing.xs) {
                            WatchQuickReply(text: "Tell me more") {
                                sendQuickReply("Tell me more")
                            }
                            WatchQuickReply(text: "Thanks") {
                                sendQuickReply("Thanks")
                            }
                        }
                    }
                    .padding(WatchSpacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: WatchCornerRadius.md))
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: WatchSpacing.sm) {
            NavigationLink {
                WatchHealthView()
            } label: {
                WatchActionRowLabel(icon: "heart.fill", label: "Health", color: .red)
            }
            .buttonStyle(.plain)

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
                .padding(.horizontal, WatchSpacing.sm)
                .padding(.vertical, WatchSpacing.xxs)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick reply: \(text)")
    }
}

// MARK: - Watch Action Row

private struct WatchActionRow: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WatchSpacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.watchPrimary)
                    .frame(width: 28)

                Text(label)
                    .font(.body)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, WatchSpacing.sm)
            .padding(.horizontal, WatchSpacing.md)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: WatchCornerRadius.md))
        .accessibilityLabel(label)
        .accessibilityHint("Double tap to activate")
    }
}

// MARK: - Action Row Label (for NavigationLink)

/// Same visual style as WatchActionRow, but as a plain label for use inside NavigationLink.
private struct WatchActionRowLabel: View {
    let icon: String
    let label: String
    var color = Color.watchPrimary

    var body: some View {
        HStack(spacing: WatchSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)

            Text(label)
                .font(.body)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, WatchSpacing.sm)
        .padding(.horizontal, WatchSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: WatchCornerRadius.md))
        .accessibilityLabel(label)
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
                    .accessibilityValue(config.voiceEnabled ? "On" : "Off")
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
                        .accessibilityValue(config.conversationMode ? "On" : "Off")
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
                    .accessibilityValue(config.iCloudSyncEnabled ? "On" : "Off")
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
                    .accessibilityValue(config.analyticsEnabled ? "On" : "Off")
            }

            Section("Security") {
                Toggle("Passcode Lock", isOn: $config.requirePasscode)
                    .font(.body)
                    .onChange(of: config.requirePasscode) { _, _ in config.save() }
                    .accessibilityValue(config.requirePasscode ? "On" : "Off")
            }

            Section {
                Button("Clear Data", role: .destructive) {
                    // Clear data
                }
                .font(.body)
                .accessibilityHint("Permanently removes all local data")
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
