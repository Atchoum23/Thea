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
            case .chat: return "message.fill"
            case .voice: return "mic.fill"
            case .settings: return "gear"
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
    var body: some View {
        List {
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
            }

            Section("Voice") {
                NavigationLink("Wake Word") {
                    Text("Wake word settings coming soon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
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
