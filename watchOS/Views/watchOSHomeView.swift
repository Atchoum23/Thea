import SwiftData
import SwiftUI

struct watchOSHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var chatManager = ChatManager.shared
    @StateObject private var voiceManager = VoiceActivationManager.shared

    @State private var selectedTab: Tab = .chat
    @State private var showingNewChat = false

    enum Tab: String, CaseIterable {
        case chat = "Chat"
        case voice = "Voice"
        case recent = "Recent"

        var icon: String {
            switch self {
            case .chat: return "message.fill"
            case .voice: return "mic.fill"
            case .recent: return "clock.fill"
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
        .sheet(isPresented: $showingNewChat) {
            watchOSNewChatView()
        }
        .onAppear {
            chatManager.setModelContext(modelContext)
        }
    }

    @ViewBuilder
    private func viewForTab(_ tab: Tab) -> some View {
        switch tab {
        case .chat:
            watchOSChatListView(showingNewChat: $showingNewChat)
        case .voice:
            watchOSVoiceView()
        case .recent:
            watchOSRecentView()
        }
    }
}

// MARK: - Chat List View

struct watchOSChatListView: View {
    @Binding var showingNewChat: Bool
    @StateObject private var chatManager = ChatManager.shared

    var body: some View {
        VStack(spacing: 0) {
            if chatManager.conversations.isEmpty {
                emptyStateView
            } else {
                conversationList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 40))
                .foregroundStyle(.theaPrimary)

            Text("No Chats")
                .font(.headline)

            Button {
                showingNewChat = true
            } label: {
                Label("New Chat", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var conversationList: some View {
        List {
            ForEach(chatManager.conversations.prefix(10)) { conversation in
                NavigationLink(destination: watchOSChatView(conversation: conversation)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conversation.title)
                            .font(.headline)
                            .lineLimit(1)

                        if let lastMessage = conversation.messages.last {
                            Text(lastMessage.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                showingNewChat = true
            } label: {
                Label("New Chat", systemImage: "plus.circle.fill")
                    .foregroundStyle(.theaPrimary)
            }
        }
    }
}

// MARK: - Chat View

struct watchOSChatView: View {
    let conversation: Conversation

    @StateObject private var chatManager = ChatManager.shared
    @State private var isListeningForVoice = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(conversation.messages) { message in
                        watchOSMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
            .onChange(of: conversation.messages.count) { _, _ in
                if let lastMessage = conversation.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    isListeningForVoice.toggle()
                    handleVoiceInput()
                } label: {
                    Image(systemName: isListeningForVoice ? "mic.fill" : "mic")
                        .foregroundStyle(isListeningForVoice ? .red : .theaPrimary)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            chatManager.selectConversation(conversation)
        }
    }

    private func handleVoiceInput() {
        if isListeningForVoice {
            try? VoiceActivationManager.shared.startVoiceCommand()
            VoiceActivationManager.shared.onTranscriptionComplete = { transcription in
                isListeningForVoice = false
                Task {
                    try? await chatManager.sendMessage(transcription, in: conversation)
                }
            }
        } else {
            VoiceActivationManager.shared.stopVoiceCommand()
        }
    }
}

struct watchOSMessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.messageRole == .user {
                Spacer(minLength: 20)
            }

            VStack(alignment: message.messageRole == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(backgroundColor)
                    .foregroundStyle(message.messageRole == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.messageRole == .assistant {
                Spacer(minLength: 20)
            }
        }
    }

    private var backgroundColor: Color {
        switch message.messageRole {
        case .user:
            return .theaPrimary
        case .assistant:
            return Color(.systemGray5)
        case .system:
            return Color(.systemGray4)
        }
    }
}

// MARK: - Voice View

struct watchOSVoiceView: View {
    @StateObject private var voiceManager = VoiceActivationManager.shared
    @StateObject private var chatManager = ChatManager.shared

    @State private var isListening = false
    @State private var transcribedText = ""

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.system(size: 60))
                .foregroundStyle(isListening ? .red : .theaPrimary)
                .symbolEffect(.variableColor, isActive: isListening)

            if isListening {
                Text("Listening...")
                    .font(.headline)

                if !transcribedText.isEmpty {
                    Text(transcribedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                Text("Tap to speak")
                    .font(.headline)

                Text("Say '\(voiceManager.wakeWord)' to activate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                toggleListening()
            } label: {
                Text(isListening ? "Stop" : "Start")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isListening ? .red : .theaPrimary)
        }
        .padding()
    }

    private func toggleListening() {
        if isListening {
            voiceManager.stopVoiceCommand()
            isListening = false
        } else {
            try? voiceManager.startVoiceCommand()
            isListening = true

            voiceManager.onTranscriptionComplete = { transcription in
                transcribedText = transcription
                isListening = false

                Task {
                    let conversation = chatManager.conversations.first ?? chatManager.createConversation(title: "Voice Chat")
                    try? await chatManager.sendMessage(transcription, in: conversation)
                }
            }
        }
    }
}

// MARK: - Recent View

struct watchOSRecentView: View {
    @StateObject private var chatManager = ChatManager.shared

    var body: some View {
        List {
            ForEach(recentConversations) { conversation in
                NavigationLink(destination: watchOSChatView(conversation: conversation)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conversation.title)
                            .font(.headline)
                            .lineLimit(1)

                        Text(conversation.updatedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Recent")
    }

    private var recentConversations: [Conversation] {
        chatManager.conversations
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - New Chat View

struct watchOSNewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatManager = ChatManager.shared

    @State private var title = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Chat title", text: $title)
                    .textFieldStyle(.roundedBorder)

                Button("Create") {
                    createChat()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func createChat() {
        chatManager.createConversation(title: title.isEmpty ? "New Chat" : title)
        dismiss()
    }
}
