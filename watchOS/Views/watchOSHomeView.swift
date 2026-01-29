// swiftlint:disable type_name
import SwiftUI

// MARK: - watchOS Home View (Standalone)

struct watchOSHomeView: View {
    @State private var selectedTab: Tab = .chat
    @State private var messages: [WatchMessage] = []
    @State private var inputText: String = ""
    @State private var isListening = false

    enum Tab: String, CaseIterable {
        case chat = "Chat"
        case voice = "Voice"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .chat: "message.fill"
            case .voice: "mic.fill"
            case .settings: "gear"
            }
        }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    viewForTab(tab)
                        .tag(tab)
                }
            }
            .tabViewStyle(.verticalPage)
        }
    }

    @ViewBuilder
    private func viewForTab(_ tab: Tab) -> some View {
        switch tab {
        case .chat:
            watchOSChatView(messages: $messages, inputText: $inputText)
        case .voice:
            watchOSVoiceView(isListening: $isListening, messages: $messages)
        case .settings:
            watchOSSettingsView()
        }
    }
}

// MARK: - Chat View

struct watchOSChatView: View {
    @Binding var messages: [WatchMessage]
    @Binding var inputText: String

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                placeholderView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { message in
                                WatchMessageRow(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Thea")
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Welcome to THEA")
                .font(.headline)

            Text("Tap Voice to start")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Message Row

struct WatchMessageRow: View {
    let message: WatchMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 8)
            }

            Text(message.content)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(message.isUser ? Color.blue : Color.gray.opacity(0.3))
                .foregroundStyle(message.isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if !message.isUser {
                Spacer(minLength: 8)
            }
        }
    }
}

// MARK: - Voice View

struct watchOSVoiceView: View {
    @Binding var isListening: Bool
    @Binding var messages: [WatchMessage]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.system(size: 50))
                .foregroundStyle(isListening ? .red : .blue)
                .symbolEffect(.variableColor, isActive: isListening)

            if isListening {
                Text("Listening...")
                    .font(.headline)
            } else {
                Text("Tap to speak")
                    .font(.headline)

                Text("Say 'Hey Thea'")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                toggleListening()
            } label: {
                Text(isListening ? "Stop" : "Start")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isListening ? .red : .blue)
        }
        .padding()
        .navigationTitle("Voice")
    }

    private func toggleListening() {
        isListening.toggle()

        if !isListening {
            // Simulate voice input completion
            let userMessage = WatchMessage(content: "Hello, Thea!", isUser: true)
            messages.append(userMessage)

            // Simulate response
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let response = WatchMessage(
                    content: "Hello! How can I help you today?",
                    isUser: false
                )
                messages.append(response)
            }
        }
    }
}

// MARK: - Settings View

struct watchOSSettingsView: View {
    @State private var config = WatchOSSettingsConfig.load()

    var body: some View {
        List {
            // MARK: - Voice Settings
            Section("Voice") {
                NavigationLink {
                    watchOSVoiceSettingsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Voice")
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

            // MARK: - Sync Settings
            Section("Sync") {
                NavigationLink {
                    watchOSSyncSettingsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud Sync")
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

            // MARK: - Privacy Settings
            Section("Privacy") {
                NavigationLink {
                    watchOSPrivacySettingsView()
                } label: {
                    Label("Privacy", systemImage: "hand.raised.fill")
                }
            }

            // MARK: - About
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "2026.01.29")
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
                    .onChange(of: config.voiceEnabled) { _, _ in config.save() }
            } footer: {
                Text("Use wake word to activate")
            }

            if config.voiceEnabled {
                Section("Wake Word") {
                    Text(config.wakeWord)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Say '\(config.wakeWord)' to start")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Section("Mode") {
                    Toggle("Conversation Mode", isOn: $config.conversationMode)
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
                    .onChange(of: config.iCloudSyncEnabled) { _, _ in config.save() }
            } footer: {
                Text("Sync with iPhone and Mac")
            }

            if config.iCloudSyncEnabled {
                Section("What to Sync") {
                    Toggle("Conversations", isOn: $config.syncConversations)
                        .onChange(of: config.syncConversations) { _, _ in config.save() }

                    Toggle("Settings", isOn: $config.syncSettings)
                        .onChange(of: config.syncSettings) { _, _ in config.save() }
                }

                Section {
                    Button("Sync Now") {
                        // Trigger sync
                    }
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
                    .onChange(of: config.analyticsEnabled) { _, _ in config.save() }
            }

            Section("Security") {
                Toggle("Passcode Lock", isOn: $config.requirePasscode)
                    .onChange(of: config.requirePasscode) { _, _ in config.save() }
            }

            Section {
                Button("Clear Data", role: .destructive) {
                    // Clear data
                }
            }
        }
        .navigationTitle("Privacy")
    }
}

// MARK: - watchOS Configuration Type

struct WatchOSSettingsConfig: Codable, Equatable {
    // Voice
    var voiceEnabled: Bool = false
    var wakeWord: String = "Hey Thea"
    var conversationMode: Bool = false

    // Sync
    var iCloudSyncEnabled: Bool = true
    var syncConversations: Bool = true
    var syncSettings: Bool = true

    // Privacy
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

// MARK: - watchOS Permissions View (Simplified for watchOS)

struct watchOSPermissionsView: View {
    var body: some View {
        List {
            Section {
                Text("Manage permissions in the Watch app on your iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Required Permissions") {
                watchOSSimplePermissionRow(name: "Microphone", icon: "mic.fill", description: "For voice input")
                watchOSSimplePermissionRow(name: "Speech Recognition", icon: "waveform", description: "For voice commands")
            }

            Section("Optional Permissions") {
                watchOSSimplePermissionRow(name: "Health", icon: "heart.fill", description: "For health data")
                watchOSSimplePermissionRow(name: "Location", icon: "location.fill", description: "For location context")
            }

            Section {
                Text("To change permissions, open Settings on your iPhone, then go to Privacy.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("Permissions")
    }
}

private struct watchOSSimplePermissionRow: View {
    let name: String
    let icon: String
    let description: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption)

                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
