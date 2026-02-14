import SwiftUI

// MARK: - tvOS Home View (10-Foot, Focus-Based)

/// tvOS home view designed for 10-foot viewing distance.
/// Hero card for current conversation, voice-first input,
/// focus-based navigation, large typography.
struct tvOSHomeView: View {
    @State private var selectedTab: Tab = .chat
    @State private var messages: [TVMessage] = []
    @State private var isWaitingForResponse = false
    @State private var inputText = ""

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
            VStack(spacing: TVSpacing.xxxl) {
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
            .padding(.vertical, TVSpacing.xxl)
        }
        .navigationTitle("Thea")
    }

    // MARK: - Hero Welcome

    private var heroWelcomeView: some View {
        VStack(spacing: TVSpacing.xl) {
            Image(systemName: "sparkles")
                .font(.system(size: 80, weight: .medium))
                .foregroundStyle(Color.tvPrimary)
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
        VStack(alignment: .leading, spacing: TVSpacing.lg) {
            if let lastUserMsg = messages.last(where: { $0.isUser }) {
                HStack(alignment: .top, spacing: TVSpacing.lg) {
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
                HStack(alignment: .top, spacing: TVSpacing.lg) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.tvPrimary)

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
        .padding(TVSpacing.xxl)
        .frame(maxWidth: 1000, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TVCornerRadius.xl))
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
            HStack(spacing: TVSpacing.lg) {
                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(isListening ? .red : Color.tvPrimary)
                    .symbolEffect(.variableColor, isActive: isListening)

                VStack(alignment: .leading, spacing: TVSpacing.xs) {
                    Text(isListening ? "Listening..." : "Press to Speak")
                        .font(.title2.bold())

                    Text(isListening ? "Release to send" : "Use Siri Remote or press to dictate")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(TVSpacing.xl)
            .frame(maxWidth: 800)
            .background(isListening ? AnyShapeStyle(Color.red.opacity(0.15)) : AnyShapeStyle(.ultraThinMaterial))
            .clipShape(RoundedRectangle(cornerRadius: TVCornerRadius.xl))
        }
        .buttonStyle(.plain)
        .focusable()
        #if os(tvOS)
        .hoverEffect(.highlight)
        #endif
    }

    // MARK: - Conversation History

    private var conversationHistory: some View {
        VStack(alignment: .leading, spacing: TVSpacing.md) {
            Text("Conversation")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, TVSpacing.sm)

            LazyVStack(spacing: TVSpacing.md) {
                ForEach(messages) { message in
                    TVMessageCard(message: message)
                }
            }
        }
    }

    // MARK: - Quick Suggestions

    private var quickSuggestions: some View {
        VStack(alignment: .leading, spacing: TVSpacing.lg) {
            Text(messages.isEmpty ? "Try asking" : "Suggestions")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, TVSpacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TVSpacing.lg) {
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
                .padding(.horizontal, TVSpacing.sm)
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
        isWaitingForResponse = true

        Task { @MainActor in
            defer { isWaitingForResponse = false }

            guard let provider = ProviderRegistry.shared.getCloudProvider() else {
                let response = TVMessage(
                    content: "No AI provider configured. Please set up an API key in Settings on your Mac or iPhone.",
                    isUser: false
                )
                messages.append(response)
                return
            }

            let model = SettingsManager.shared.defaultModel.isEmpty
                ? "claude-sonnet-4-5-20250929"
                : SettingsManager.shared.defaultModel

            let aiMessages: [AIMessage] = messages.map { msg in
                AIMessage(
                    id: UUID(),
                    conversationID: UUID(),
                    role: msg.isUser ? .user : .assistant,
                    content: .text(msg.content),
                    timestamp: Date(),
                    model: model
                )
            }

            do {
                let stream = try await provider.chat(
                    messages: aiMessages,
                    model: model,
                    stream: false
                )

                var responseText = ""
                for try await chunk in stream {
                    switch chunk.type {
                    case .delta(let text):
                        responseText += text
                    case .complete(let msg):
                        responseText = msg.content.textValue
                    case .error:
                        break
                    }
                }

                if responseText.isEmpty {
                    responseText = "I wasn't able to generate a response. Please try again."
                }

                let response = TVMessage(content: responseText, isUser: false)
                messages.append(response)
            } catch {
                let response = TVMessage(
                    content: "Something went wrong: \(error.localizedDescription). Please try again.",
                    isUser: false
                )
                messages.append(response)
            }
        }
    }
}

// MARK: - TV Message Card

struct TVMessageCard: View {
    let message: TVMessage

    var body: some View {
        HStack(alignment: .top, spacing: TVSpacing.lg) {
            Image(systemName: message.isUser ? "person.circle.fill" : "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(message.isUser ? .secondary : Color.tvPrimary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: TVSpacing.xs) {
                Text(message.isUser ? "You" : "Thea")
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)

                Text(message.content)
                    .font(.title3)
            }

            Spacer()
        }
        .padding(TVSpacing.xl)
        .frame(maxWidth: 1000, alignment: .leading)
        .background(message.isUser ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.ultraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: TVCornerRadius.lg))
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
            VStack(spacing: TVSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(Color.tvPrimary)

                Text(text)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 200, height: 140)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: TVCornerRadius.lg))
        }
        .buttonStyle(.plain)
        .focusable()
        #if os(tvOS)
        .hoverEffect(.highlight)
        #endif
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
