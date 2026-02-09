@preconcurrency import SwiftData
import SwiftUI

/// iPad-optimized home view using three-column NavigationSplitView
/// Uses shared components (WelcomeView, ChatInputView, StreamingMessageView, ConversationRow)
/// and design tokens for consistent styling.
@MainActor
struct IPadHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var chatManager = ChatManager.shared
    @State private var projectManager = ProjectManager.shared
    @State private var knowledgeManager = KnowledgeManager.shared
    @State private var financialManager = FinancialManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    @State private var selectedSection: SidebarSection? = .chat
    @State private var selectedConversation: Conversation?
    @State private var selectedProject: Project?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @State private var showingNewConversation = false
    @State private var showingNewProject = false

    enum SidebarSection: String, CaseIterable, Identifiable {
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

        var accentColor: Color {
            switch self {
            case .chat: Color.theaPrimaryDefault
            case .projects: .blue
            case .knowledge: .purple
            case .financial: .green
            case .settings: .gray
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } content: {
            listContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingNewConversation) {
            iOSNewConversationView()
        }
        .sheet(isPresented: $showingNewProject) {
            IPadNewProjectView()
        }
        .onAppear {
            setupManagers()
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(SidebarSection.allCases, selection: $selectedSection) { section in
            NavigationLink(value: section) {
                Label {
                    Text(section.rawValue)
                        .font(.theaBody)
                } icon: {
                    Image(systemName: section.icon)
                        .foregroundStyle(section.accentColor)
                }
            }
            .listRowInsets(EdgeInsets(
                top: TheaSpacing.sm,
                leading: TheaSpacing.md,
                bottom: TheaSpacing.sm,
                trailing: TheaSpacing.md
            ))
        }
        .navigationTitle("THEA")
        .listStyle(.sidebar)
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        switch selectedSection {
        case .chat:
            iPadChatListContent
        case .projects:
            iPadProjectsListContent
        case .knowledge:
            iOSKnowledgeView()
                .navigationTitle("Knowledge")
        case .financial:
            iOSFinancialView()
                .navigationTitle("Financial")
        case .settings:
            iOSSettingsView()
                .navigationTitle("Settings")
        case .none:
            ContentUnavailableView(
                "Select a Section",
                systemImage: "sidebar.left",
                description: Text("Choose a section from the sidebar")
            )
        }
    }

    // MARK: - Chat List

    private var iPadChatListContent: some View {
        Group {
            if chatManager.conversations.isEmpty {
                ContentUnavailableView {
                    Label("No Conversations", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Start a new conversation with THEA")
                } actions: {
                    Button {
                        showingNewConversation = true
                    } label: {
                        Label("New Conversation", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List(chatManager.conversations, selection: $selectedConversation) { conversation in
                    NavigationLink(value: conversation) {
                        ConversationRow(conversation: conversation)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewConversation = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    // MARK: - Projects List

    private var iPadProjectsListContent: some View {
        Group {
            if projectManager.projects.isEmpty {
                ContentUnavailableView {
                    Label("No Projects", systemImage: "folder")
                } description: {
                    Text("Create a project to organize your conversations")
                } actions: {
                    Button {
                        showingNewProject = true
                    } label: {
                        Label("New Project", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List(projectManager.projects, selection: $selectedProject) { project in
                    NavigationLink(value: project) {
                        IPadProjectRow(project: project)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            projectManager.deleteProject(project)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewProject = true
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .chat:
            if let conversation = selectedConversation {
                IPadChatDetailView(conversation: conversation)
            } else {
                WelcomeView { prompt in
                    let conversation = chatManager.createConversation(title: "New Conversation")
                    selectedConversation = conversation
                    Task {
                        try? await chatManager.sendMessage(prompt, in: conversation)
                    }
                }
            }
        case .projects:
            if let project = selectedProject {
                IPadProjectDetailView(project: project)
            } else {
                ContentUnavailableView(
                    "Select a Project",
                    systemImage: "folder",
                    description: Text("Choose a project from the list")
                )
            }
        case .knowledge, .financial, .settings:
            EmptyView()
        case .none:
            WelcomeView { prompt in
                selectedSection = .chat
                let conversation = chatManager.createConversation(title: "New Conversation")
                selectedConversation = conversation
                Task {
                    try? await chatManager.sendMessage(prompt, in: conversation)
                }
            }
        }
    }

    // MARK: - Setup

    private func setupManagers() {
        chatManager.setModelContext(modelContext)
        projectManager.setModelContext(modelContext)
        knowledgeManager.setModelContext(modelContext)
        financialManager.setModelContext(modelContext)

        if voiceManager.isEnabled {
            Task {
                try? await voiceManager.requestPermissions()
                try? voiceManager.startWakeWordDetection()
            }
        }
    }
}

// MARK: - iPad Project Row

private struct IPadProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.xs) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)

                Text(project.title)
                    .font(.theaBody)
                    .lineLimit(1)
            }

            HStack(spacing: TheaSpacing.lg) {
                Label("\(project.conversations.count)", systemImage: "message")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)

                Label("\(project.files.count)", systemImage: "doc")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)

                Text(project.updatedAt, style: .relative)
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, TheaSpacing.xxs)
    }
}

// MARK: - iPad Chat Detail View

struct IPadChatDetailView: View {
    let conversation: Conversation

    @Environment(\.modelContext) private var modelContext
    @State private var chatManager = ChatManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    @Query private var allMessages: [Message]

    @StateObject private var settingsManager = SettingsManager.shared
    @State private var messageText = ""
    @State private var isListeningForVoice = false
    @FocusState private var isInputFocused: Bool

    private var messageSpacing: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.sm
        case "spacious": TheaSpacing.xxl
        default: TheaSpacing.lg
        }
    }

    private var messages: [Message] {
        allMessages
            .filter { $0.conversationID == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }

    init(conversation: Conversation) {
        self.conversation = conversation
        _allMessages = Query(sort: \Message.timestamp)
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            chatInput
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isListeningForVoice.toggle()
                    handleVoiceInput()
                } label: {
                    Image(systemName: isListeningForVoice ? "mic.fill" : "mic")
                        .foregroundStyle(isListeningForVoice ? .red : .theaPrimary)
                        .symbolEffect(.bounce, value: isListeningForVoice)
                }
                .help("Voice input")
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Menu {
                    Button {
                        chatManager.togglePin(conversation)
                    } label: {
                        Label(
                            conversation.isPinned ? "Unpin" : "Pin",
                            systemImage: conversation.isPinned ? "pin.slash" : "pin"
                        )
                    }

                    Button(role: .destructive) {
                        chatManager.deleteConversation(conversation)
                    } label: {
                        Label("Delete Conversation", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            chatManager.selectConversation(conversation)
            isInputFocused = true
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty && !chatManager.isStreaming {
                    WelcomeView { prompt in
                        messageText = prompt
                        sendMessage()
                    }
                } else {
                    LazyVStack(spacing: messageSpacing) {
                        // When streaming, hide the last assistant message to avoid duplicate display
                        // (it's shown live by StreamingMessageView instead)
                        let displayMessages = chatManager.isStreaming
                            ? messages.filter { msg in
                                if msg.messageRole == .assistant,
                                   msg.id == messages.last(where: { $0.messageRole == .assistant })?.id {
                                    return false
                                }
                                return true
                            }
                            : messages

                        ForEach(displayMessages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                ))
                        }

                        if chatManager.isStreaming {
                            StreamingMessageView(
                                streamingText: chatManager.streamingText,
                                status: chatManager.streamingText.isEmpty ? .thinking : .generating
                            )
                            .id("streaming")
                        }
                    }
                    .padding(.horizontal, TheaSpacing.xxl)
                    .padding(.vertical, TheaSpacing.lg)
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatManager.streamingText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // MARK: - Chat Input

    private var chatInput: some View {
        HStack(spacing: TheaSpacing.md) {
            TextField("Message Thea...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1 ... 6)
                .disabled(chatManager.isStreaming)
                .onSubmit {
                    if !messageText.isEmpty {
                        sendMessage()
                    }
                }
                .padding(.horizontal, TheaSpacing.lg)
                .padding(.vertical, TheaSpacing.md)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.xl))

            Button {
                if chatManager.isStreaming {
                    chatManager.cancelStreaming()
                } else {
                    sendMessage()
                }
            } label: {
                Image(systemName: chatManager.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isStreaming
                            ? Color.theaPrimaryDefault : .secondary
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatManager.isStreaming)
            .accessibilityLabel(chatManager.isStreaming ? "Stop generating" : "Send message")
        }
        .padding(.horizontal, TheaSpacing.lg)
        .padding(.vertical, TheaSpacing.md)
    }

    // MARK: - Actions

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(TheaAnimation.smooth) {
            if chatManager.isStreaming {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let lastMessage = messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""

        Task {
            do {
                try await chatManager.sendMessage(text, in: conversation)
            } catch {
                print("Failed to send message: \(error)")
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

// MARK: - iPad Project Detail View

struct IPadProjectDetailView: View {
    let project: Project

    @State private var projectManager = ProjectManager.shared
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
            Section("Project Info") {
                if isEditing {
                    TextField("Title", text: $editedTitle)
                } else {
                    LabeledContent("Title", value: project.title)
                }

                LabeledContent("Created", value: project.createdAt, format: .dateTime)
                LabeledContent("Updated", value: project.updatedAt, format: .dateTime)
            }

            Section("Statistics") {
                LabeledContent("Conversations", value: "\(project.conversations.count)")
                LabeledContent("Files", value: "\(project.files.count)")
            }

            Section("Custom Instructions") {
                if isEditing {
                    TextEditor(text: $editedInstructions)
                        .frame(minHeight: 150)
                } else if project.customInstructions.isEmpty {
                    Text("No custom instructions")
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                } else {
                    Text(project.customInstructions)
                        .font(.theaBody)
                }
            }

            if !project.conversations.isEmpty {
                Section("Conversations") {
                    ForEach(project.conversations) { conversation in
                        NavigationLink(destination: IPadChatDetailView(conversation: conversation)) {
                            ConversationRow(conversation: conversation)
                        }
                    }
                }
            }

            if !project.files.isEmpty {
                Section("Files") {
                    ForEach(project.files) { file in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: TheaSpacing.xxs) {
                                Text(file.name)
                                    .font(.theaBody)

                                Text("\(file.size) bytes")
                                    .font(.theaCaption2)
                                    .foregroundStyle(.secondary)
                            }
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

// MARK: - iPad New Project View

struct IPadNewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var projectManager = ProjectManager.shared

    @State private var title = ""
    @State private var customInstructions = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project name", text: $title)
                }

                Section("Custom Instructions (Optional)") {
                    TextEditor(text: $customInstructions)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func createProject() {
        let project = projectManager.createProject(title: title)
        if !customInstructions.isEmpty {
            project.customInstructions = customInstructions
        }
        dismiss()
    }
}
