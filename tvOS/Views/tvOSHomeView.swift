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
            case .chat: return "message.fill"
            case .settings: return "gear"
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
    var body: some View {
        List {
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
            }

            Section("AI") {
                NavigationLink("AI Settings") {
                    Text("AI Settings coming soon")
                }
            }
        }
        .navigationTitle("Settings")
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
