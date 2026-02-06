@preconcurrency import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var chatManager = ChatManager.shared
    @StateObject private var projectManager = ProjectManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    @State private var selectedItem: NavigationItem? = .chat
    @State private var selectedConversation: Conversation?
    @State private var selectedProject: Project?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var hasAutoCreatedConversation = false

    enum NavigationItem: String, CaseIterable, Identifiable {
        case chat = "Chat"
        case projects = "Projects"
        case knowledge = "Knowledge"
        case financial = "Financial"
        case code = "Code"
        case migration = "Migration"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .chat: "message.fill"
            case .projects: "folder.fill"
            case .knowledge: "brain.head.profile"
            case .financial: "dollarsign.circle.fill"
            case .code: "chevron.left.forwardslash.chevron.right"
            case .migration: "arrow.down.doc.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            sidebarContent
        } content: {
            // List
            listContent
        } detail: {
            // Detail
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(colorSchemeForTheme)
        .dynamicTypeSize(dynamicTypeSizeForFontSize)
        .onAppear {
            setupManagers()
            // Auto-create a new conversation when window opens (per user request)
            autoCreateConversationIfNeeded()
        }
        // NOTE: Removed custom sidebar toggle button - NavigationSplitView provides native toggle
    }

    private var sidebarContent: some View {
        List(NavigationItem.allCases, selection: $selectedItem) { item in
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.icon)
            }
        }
        .navigationTitle("THEA")
        .frame(minWidth: 200)
    }

    @ViewBuilder
    private var listContent: some View {
        switch selectedItem {
        case .chat:
            chatListView
        case .projects:
            projectsListView
        case .knowledge:
            macOSKnowledgeView()
        case .financial:
            macOSFinancialView()
        case .code:
            macOSCodeView()
        case .migration:
            macOSMigrationView()
        case .none:
            Text("Select a section")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let conversation = selectedConversation {
            macOSChatDetailView(conversation: conversation)
        } else if let project = selectedProject {
            macOSProjectDetailView(project: project)
        } else {
            placeholderView
        }
    }

    private var chatListView: some View {
        List(chatManager.conversations, selection: $selectedConversation) { conversation in
            NavigationLink(value: conversation) {
                ConversationRow(conversation: conversation)
            }
        }
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNewConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .frame(minWidth: 250)
    }

    private var projectsListView: some View {
        List(projectManager.projects, selection: $selectedProject) { project in
            NavigationLink(value: project) {
                ContentProjectRow(project: project)
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNewProject()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .frame(minWidth: 250)
    }

    private var placeholderView: some View {
        VStack(spacing: 32) {
            Image(systemName: selectedItem?.icon ?? "brain.head.profile")
                .font(.system(size: 80))
                .foregroundStyle(Color.theaPrimaryDefault)

            VStack(spacing: 12) {
                Text("Welcome to THEA")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your AI Life Companion")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            if selectedItem == .chat {
                Button {
                    createNewConversation()
                } label: {
                    Label("New Conversation", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.theaPrimaryDefault)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createNewConversation() {
        let conversation = chatManager.createConversation(title: "New Conversation")
        selectedConversation = conversation
    }

    private func createNewProject() {
        let project = projectManager.createProject(title: "New Project")
        selectedProject = project
    }

    // Sidebar toggle is now handled directly via columnVisibility binding

    // Convert theme setting to ColorScheme
    private var colorSchemeForTheme: ColorScheme? {
        switch settingsManager.theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil  // "system" uses nil to follow system setting
        }
    }

    // Convert font size setting to DynamicTypeSize
    private var dynamicTypeSizeForFontSize: DynamicTypeSize {
        switch settingsManager.fontSize {
        case "small": return .small
        case "large": return .xxxLarge
        default: return .medium  // "medium"
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

    /// Auto-create a new conversation when window opens directly to chat
    /// This implements the user-requested behavior: "New Thea windows open directly to new conversation view"
    private func autoCreateConversationIfNeeded() {
        // Only auto-create once per window and only if in chat mode with no selection
        guard !hasAutoCreatedConversation,
              selectedItem == .chat,
              selectedConversation == nil else { return }

        // Small delay to ensure managers are initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if selectedConversation == nil {
                hasAutoCreatedConversation = true
                createNewConversation()
            }
        }
    }
}

// MARK: - Chat Detail View

struct macOSChatDetailView: View {
    let conversation: Conversation

    @Environment(\.modelContext) private var modelContext
    @StateObject private var chatManager = ChatManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    // Use @Query to properly observe message changes
    @Query private var allMessages: [Message]

    @State private var messageText = ""
    @State private var isListeningForVoice = false
    @FocusState private var isInputFocused: Bool

    // Filter messages for this conversation
    private var messages: [Message] {
        allMessages
            .filter { $0.conversationID == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }

    init(conversation: Conversation) {
        self.conversation = conversation
        // Initialize query - fetch all messages (we filter in computed property)
        _allMessages = Query(sort: \Message.timestamp)
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            inputArea
        }
        .navigationTitle(conversation.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
            isInputFocused = true
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty && !chatManager.isStreaming {
                    // Welcome placeholder shown when conversation is empty
                    welcomePlaceholder
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        // Show streaming response with indicator
                        if chatManager.isStreaming {
                            StreamingMessageView(
                                streamingText: chatManager.streamingText,
                                status: chatManager.streamingText.isEmpty ? .thinking : .generating
                            )
                            .id("streaming")
                        }
                    }
                    .padding(20)
                }
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatManager.streamingText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    /// Welcome placeholder displayed above the input field when conversation has no messages
    private var welcomePlaceholder: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(Color.theaPrimaryDefault)

            VStack(spacing: 8) {
                Text("Welcome to THEA")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Your AI Life Companion")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("Ask me anything, or try one of these:")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            // Suggestion chips
            HStack(spacing: 12) {
                WelcomeSuggestionChip(text: "Help me plan my day", icon: "calendar")
                WelcomeSuggestionChip(text: "Explain a concept", icon: "lightbulb")
                WelcomeSuggestionChip(text: "Write some code", icon: "chevron.left.forwardslash.chevron.right")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if chatManager.isStreaming {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let lastMessage = messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message THEA...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1 ... 8)
                .focused($isInputFocused)
                .disabled(chatManager.isStreaming)
                .onKeyPress(.return) {
                    // Send on Return (without Shift)
                    if !messageText.isEmpty, !chatManager.isStreaming {
                        sendMessage()
                        return .handled
                    }
                    return .ignored
                }

            Button {
                if chatManager.isStreaming {
                    chatManager.cancelStreaming()
                } else {
                    sendMessage()
                }
            } label: {
                Image(systemName: chatManager.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        messageText.isEmpty && !chatManager.isStreaming
                            ? Color.secondary
                            : Color.theaPrimary
                    )
            }
            .buttonStyle(.plain)
            .disabled(messageText.isEmpty && !chatManager.isStreaming)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""

        Task {
            do {
                try await chatManager.sendMessage(text, in: conversation)
            } catch {
                print("❌ Failed to send message: \(error)")
                // Restore the message if sending failed
                messageText = text
            }
        }
    }

    private func handleVoiceInput() {
        if isListeningForVoice {
            try? voiceManager.startVoiceCommand()
            voiceManager.onTranscriptionComplete = { (transcription: String) in
                messageText = transcription
                isListeningForVoice = false
            }
        } else {
            voiceManager.stopVoiceCommand()
        }
    }
}

// MARK: - Project Detail View

struct macOSProjectDetailView: View {
    let project: Project

    @StateObject private var projectManager = ProjectManager.shared

    @State private var isEditing = false
    @State private var editedTitle: String
    @State private var editedInstructions: String

    init(project: Project) {
        self.project = project
        _editedTitle = State(initialValue: project.title)
        _editedInstructions = State(initialValue: project.customInstructions)
    }

    var body: some View {
        Form {
            if isEditing {
                Section("Project Details") {
                    TextField("Title", text: $editedTitle)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Instructions")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $editedInstructions)
                            .frame(minHeight: 200)
                            .font(.body)
                    }
                }
            } else {
                Section("Project Details") {
                    LabeledContent("Title", value: project.title)
                    LabeledContent("Created", value: project.createdAt, format: .dateTime)
                    LabeledContent("Conversations", value: "\(project.conversations.count)")
                    LabeledContent("Files", value: "\(project.files.count)")

                    if !project.customInstructions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Instructions")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(project.customInstructions)
                                .font(.body)
                        }
                    }
                }
            }

            Section("Conversations") {
                ForEach(project.conversations) { conversation in
                    NavigationLink(destination: macOSChatDetailView(conversation: conversation)) {
                        ConversationRow(conversation: conversation)
                    }
                }
            }

            Section("Files") {
                ForEach(project.files) { file in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(Color.theaPrimaryDefault)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.body)

                            Text("\(file.size) bytes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(project.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveChanges()
                    }
                    isEditing.toggle()
                }
            }
        }
    }

    private func saveChanges() {
        project.title = editedTitle
        project.customInstructions = editedInstructions
        project.updatedAt = Date()
    }
}

// MARK: - Placeholder Views (to be implemented)

struct macOSKnowledgeView: View {
    var body: some View {
        Text("Knowledge View - macOS")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct macOSFinancialView: View {
    var body: some View {
        Text("Financial View - macOS")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct macOSCodeView: View {
    var body: some View {
        Text("Code Intelligence View - macOS")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct macOSMigrationView: View {
    var body: some View {
        Text("Migration View - macOS")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

struct ContentProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)

                Text(project.title)
                    .font(.body)
                    .lineLimit(1)
            }

            HStack {
                Text("\(project.conversations.count) conversations")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(project.files.count) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Suggestion Chip

/// A tappable suggestion chip for the welcome placeholder
struct WelcomeSuggestionChip: View {
    let text: String
    let icon: String

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))

            Text(text)
                .font(.callout)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isHovering ? Color.theaPrimaryDefault.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
        .foregroundStyle(isHovering ? Color.theaPrimaryDefault : .primary)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.theaPrimaryDefault.opacity(isHovering ? 0.5 : 0.2), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
