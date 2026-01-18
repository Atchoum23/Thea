@preconcurrency import SwiftData
import SwiftUI

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
            case .chat: return "message.fill"
            case .projects: return "folder.fill"
            case .knowledge: return "brain.head.profile"
            case .financial: return "dollarsign.circle.fill"
            case .settings: return "gear"
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
                projectManager.createProject(title: "New Project")
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

        // Request voice permissions if enabled
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
    @State private var selectedConversation: Conversation?

    var body: some View {
        Group {
            if chatManager.conversations.isEmpty {
                emptyStateView
            } else {
                conversationList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "message.fill")
                .font(.system(size: 64))
                .foregroundStyle(.theaPrimary)

            Text("No Conversations Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start a new conversation with THEA")
                .font(.body)
                .foregroundStyle(.secondary)

            Button {
                showingNewConversation = true
            } label: {
                Label("New Conversation", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.theaPrimary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    private var conversationList: some View {
        List {
            ForEach(chatManager.conversations) { conversation in
                NavigationLink(destination: iOSChatView(conversation: conversation)) {
                    iOSConversationRow(conversation: conversation)
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
                        conversation.isPinned.toggle()
                    } label: {
                        Label(
                            conversation.isPinned ? "Unpin" : "Pin",
                            systemImage: conversation.isPinned ? "pin.slash" : "pin"
                        )
                    }
                    .tint(.theaPrimary)
                }
            }
        }
        .listStyle(.plain)
    }
}

private struct iOSConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.theaPrimary)
                }
            }

            if let lastMessage = conversation.messages.last {
                Text(lastMessage.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(conversation.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
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
            inputArea
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.title)
                        .font(.headline)

                    if chatManager.isStreaming {
                        Text("Thinking...")
                            .font(.caption)
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
                LazyVStack(spacing: 16) {
                    ForEach(conversation.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: conversation.messages.count) { _, _ in
                if let lastMessage = conversation.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message THEA...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...6)
                    .focused($isInputFocused)
                    .disabled(chatManager.isStreaming)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: chatManager.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(messageText.isEmpty && !chatManager.isStreaming ? .secondary : .theaPrimary)
                }
                .disabled(messageText.isEmpty && !chatManager.isStreaming)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty || chatManager.isStreaming else { return }

        if chatManager.isStreaming {
            chatManager.cancelStreaming()
        } else {
            let text = messageText
            messageText = ""
            isInputFocused = false

            Task {
                try? await chatManager.sendMessage(text, in: conversation)
            }
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
            Form {
                Section("Conversation Title") {
                    TextField("Enter title...", text: $title)
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
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createConversation()
                    }
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
            title: title.isEmpty ? "New Conversation" : title,
            projectID: selectedProject?.id
        )
        chatManager.selectConversation(conversation)
        dismiss()
    }
}

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
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
