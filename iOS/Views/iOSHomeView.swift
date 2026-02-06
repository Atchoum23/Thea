@preconcurrency import SwiftData
import SwiftUI

// MARK: - iOS Home View

@MainActor
struct iOSHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var chatManager = ChatManager.shared
    @State private var projectManager = ProjectManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    @State private var selectedTab: Tab = .chat
    @State private var showingNewConversation = false
    @State private var showingVoiceSettings = false

    enum Tab: String, CaseIterable, Identifiable {
        case chat = "Chat"
        case projects = "Projects"
        case knowledge = "Knowledge"
        case financial = "Financial"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .chat: "bubble.left.and.bubble.right.fill"
            case .projects: "folder.fill"
            case .knowledge: "books.vertical.fill"
            case .financial: "chart.pie.fill"
            case .settings: "gearshape"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                NavigationStack {
                    viewForTab(tab)
                        .navigationTitle(tab.rawValue)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                toolbarButtonForTab(tab)
                            }
                        }
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .sheet(isPresented: $showingNewConversation) {
            iOSNewConversationView()
        }
        .sheet(isPresented: $showingVoiceSettings) {
            iOSVoiceSettingsView()
        }
        .onAppear {
            setupManagers()
        }
    }

    @ViewBuilder
    private func viewForTab(_ tab: Tab) -> some View {
        switch tab {
        case .chat:
            iOSChatListView(showingNewConversation: $showingNewConversation)
        case .projects:
            iOSProjectsView()
        case .knowledge:
            iOSKnowledgeView()
        case .financial:
            iOSFinancialView()
        case .settings:
            iOSSettingsView()
        }
    }

    @ViewBuilder
    private func toolbarButtonForTab(_ tab: Tab) -> some View {
        switch tab {
        case .chat:
            Button {
                showingNewConversation = true
            } label: {
                Image(systemName: "square.and.pencil")
            }
        case .projects:
            Button {
                _ = projectManager.createProject(title: "New Project")
            } label: {
                Image(systemName: "plus")
            }
        case .knowledge:
            Button {
                showingVoiceSettings = true
            } label: {
                Image(systemName: voiceManager.isEnabled ? "mic.fill" : "mic.slash.fill")
                    .foregroundStyle(voiceManager.isEnabled ? .theaPrimary : .secondary)
            }
        case .financial, .settings:
            EmptyView()
        }
    }

    private func setupManagers() {
        chatManager.setModelContext(modelContext)
        projectManager.setModelContext(modelContext)

        if voiceManager.isEnabled {
            Task {
                try? await voiceManager.requestPermissions()
                try? voiceManager.startWakeWordDetection()
            }
        }
    }
}

// MARK: - Chat List View

struct iOSChatListView: View {
    @Binding var showingNewConversation: Bool
    @State private var chatManager = ChatManager.shared
    @State private var searchText = ""

    var body: some View {
        Group {
            if chatManager.conversations.isEmpty {
                WelcomeView { prompt in
                    let conversation = chatManager.createConversation(title: "New Conversation")
                    chatManager.selectConversation(conversation)
                    NotificationCenter.default.post(
                        name: Notification.Name.newConversation,
                        object: prompt
                    )
                }
            } else {
                conversationList
            }
        }
        .searchable(text: $searchText, prompt: "Search conversations")
    }

    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            chatManager.conversations
        } else {
            chatManager.conversations.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var conversationList: some View {
        List {
            // Pinned
            let pinned = filteredConversations.filter(\.isPinned)
            if !pinned.isEmpty {
                Section("Pinned") {
                    ForEach(pinned) { conversation in
                        NavigationLink(destination: iOSChatView(conversation: conversation)) {
                            IOSConversationRow(conversation: conversation)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                chatManager.deleteConversation(conversation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                ChatManager.shared.togglePin(conversation)
                            } label: {
                                Label("Unpin", systemImage: "pin.slash")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }

            // Recent
            let recent = filteredConversations.filter { !$0.isPinned }
            if !recent.isEmpty {
                Section("Recent") {
                    ForEach(recent) { conversation in
                        NavigationLink(destination: iOSChatView(conversation: conversation)) {
                            IOSConversationRow(conversation: conversation)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                chatManager.deleteConversation(conversation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                ChatManager.shared.togglePin(conversation)
                            } label: {
                                Label("Pin", systemImage: "pin")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Conversation Row

private struct IOSConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.xs) {
            HStack {
                Text(conversation.title)
                    .font(.theaBody)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                if conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.theaPrimary)
                }
            }

            if let lastMessage = conversation.messages.last {
                Text(lastMessage.content.textValue)
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(conversation.updatedAt, style: .relative)
                .font(.theaCaption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, TheaSpacing.xxs)
    }
}

// MARK: - Chat View

struct iOSChatView: View {
    let conversation: Conversation

    @State private var chatManager = ChatManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    @State private var messageText = ""
    @State private var isListeningForVoice = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            ChatInputView(
                text: $messageText,
                isStreaming: chatManager.isStreaming
            ) {
                if chatManager.isStreaming {
                    chatManager.cancelStreaming()
                } else {
                    sendMessage()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.title)
                        .font(.theaBody)
                        .fontWeight(.semibold)

                    if chatManager.isStreaming {
                        Text("Thinking...")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isListeningForVoice.toggle()
                    handleVoiceInput()
                } label: {
                    Image(systemName: isListeningForVoice ? "mic.fill" : "mic")
                        .foregroundStyle(isListeningForVoice ? .red : .theaPrimary)
                        .symbolEffect(.bounce, value: isListeningForVoice)
                }
            }
        }
        .onAppear {
            chatManager.selectConversation(conversation)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if conversation.messages.isEmpty && !chatManager.isStreaming {
                    WelcomeView { prompt in
                        messageText = prompt
                        sendMessage()
                    }
                } else {
                    LazyVStack(spacing: TheaSpacing.md) {
                        ForEach(conversation.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if chatManager.isStreaming {
                            StreamingMessageView(
                                streamingText: chatManager.streamingText,
                                status: chatManager.streamingText.isEmpty ? .thinking : .generating
                            )
                            .id("streaming")
                        }
                    }
                    .padding(.horizontal, TheaSpacing.lg)
                    .padding(.vertical, TheaSpacing.md)
                }
            }
            .onChange(of: conversation.messages.count) { _, _ in
                if let lastMessage = conversation.messages.last {
                    withAnimation(TheaAnimation.smooth) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatManager.streamingText) { _, _ in
                withAnimation(TheaAnimation.smooth) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isInputFocused = false

        Task {
            try? await chatManager.sendMessage(text, in: conversation)
        }
    }

    private func handleVoiceInput() {
        if isListeningForVoice {
            try? voiceManager.startVoiceCommand()
            voiceManager.onTranscriptionComplete = { transcription in
                messageText = transcription
                isListeningForVoice = false
            }
        } else {
            voiceManager.stopVoiceCommand()
        }
    }
}

// MARK: - New Conversation View

struct iOSNewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var chatManager = ChatManager.shared
    @State private var projectManager = ProjectManager.shared

    @State private var title = ""
    @State private var selectedProject: Project?
    @State private var showingProjectPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: TheaSpacing.xxl) {
                // Suggestion chips for quick start
                SuggestionChipGrid { item in
                    let conversation = chatManager.createConversation(title: item.text)
                    chatManager.selectConversation(conversation)
                    NotificationCenter.default.post(
                        name: Notification.Name.newConversation,
                        object: item.prompt
                    )
                    dismiss()
                }
                .padding(.horizontal, TheaSpacing.lg)

                Divider()

                // Manual title entry
                Form {
                    Section("Or start with a title") {
                        TextField("Conversation title...", text: $title)
                    }

                    Section("Project (Optional)") {
                        Button {
                            showingProjectPicker = true
                        } label: {
                            HStack {
                                Text(selectedProject?.title ?? "None")
                                    .foregroundStyle(selectedProject == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createConversation() }
                        .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingProjectPicker) {
                ProjectPickerView(selectedProject: $selectedProject)
            }
        }
    }

    private func createConversation() {
        let conversation = chatManager.createConversation(
            title: title.isEmpty ? "New Conversation" : title
        )
        chatManager.selectConversation(conversation)
        dismiss()
    }
}

// MARK: - Project Picker

struct ProjectPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedProject: Project?
    @State private var projectManager = ProjectManager.shared

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedProject = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("None")
                        Spacer()
                        if selectedProject == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.theaPrimary)
                        }
                    }
                }

                ForEach(projectManager.projects) { project in
                    Button {
                        selectedProject = project
                        dismiss()
                    } label: {
                        HStack {
                            Text(project.title)
                            Spacer()
                            if selectedProject?.id == project.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.theaPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
