@preconcurrency import SwiftData
import SwiftUI

/// iPad-optimized home view using three-column NavigationSplitView
/// Provides a native iPad experience with sidebar navigation, list content, and detail view
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
    @State private var showingVoiceSettings = false

    enum SidebarSection: String, CaseIterable, Identifiable {
        case chat = "Chat"
        case projects = "Projects"
        case knowledge = "Knowledge"
        case financial = "Financial"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .chat: "message.fill"
            case .projects: "folder.fill"
            case .knowledge: "brain.head.profile"
            case .financial: "dollarsign.circle.fill"
            case .settings: "gear"
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
        .adaptiveToolbar()
        .sheet(isPresented: $showingNewConversation) {
            iOSNewConversationView()
        }
        .sheet(isPresented: $showingNewProject) {
            IPadNewProjectView()
        }
        .sheet(isPresented: $showingVoiceSettings) {
            iOSVoiceSettingsView()
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
                } icon: {
                    Image(systemName: section.icon)
                        .foregroundStyle(section.accentColor)
                }
            }
        }
        .navigationTitle("THEA")
        .listStyle(.sidebar)
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        switch selectedSection {
        case .chat:
            chatListContent
        case .projects:
            projectsListContent
        case .knowledge:
            knowledgeListContent
        case .financial:
            financialListContent
        case .settings:
            settingsListContent
        case .none:
            ContentUnavailableView(
                "Select a Section",
                systemImage: "sidebar.left",
                description: Text("Choose a section from the sidebar")
            )
        }
    }

    private var chatListContent: some View {
        Group {
            if chatManager.conversations.isEmpty {
                ContentUnavailableView {
                    Label("No Conversations", systemImage: "message")
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
                        IPadConversationRow(conversation: conversation)
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
                            chatManager.togglePin(conversation)
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
        }
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewConversation = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }

    private var projectsListContent: some View {
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
            }
        }
    }

    private var knowledgeListContent: some View {
        iOSKnowledgeView()
            .navigationTitle("Knowledge")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingVoiceSettings = true
                    } label: {
                        Image(systemName: voiceManager.isEnabled ? "mic.fill" : "mic.slash.fill")
                            .foregroundStyle(voiceManager.isEnabled ? .theaPrimary : .secondary)
                    }
                }
            }
    }

    private var financialListContent: some View {
        iOSFinancialView()
            .navigationTitle("Financial")
    }

    private var settingsListContent: some View {
        iOSSettingsView()
            .navigationTitle("Settings")
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .chat:
            if let conversation = selectedConversation {
                IPadChatDetailView(conversation: conversation)
            } else {
                chatPlaceholderView
            }
        case .projects:
            if let project = selectedProject {
                IPadProjectDetailView(project: project)
            } else {
                projectPlaceholderView
            }
        case .knowledge, .financial, .settings:
            // These sections don't have a detail view - content is in the list column
            EmptyView()
        case .none:
            welcomePlaceholderView
        }
    }

    private var chatPlaceholderView: some View {
        VStack(spacing: 32) {
            Image(systemName: "message.fill")
                .font(.system(size: 80))
                .foregroundStyle(.theaPrimary)

            VStack(spacing: 12) {
                Text("Select a Conversation")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Or start a new one")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Button {
                showingNewConversation = true
            } label: {
                Label("New Conversation", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.theaPrimary)
                    .liquidGlass()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var projectPlaceholderView: some View {
        VStack(spacing: 32) {
            Image(systemName: "folder.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("Select a Project")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Or create a new one")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Button {
                showingNewProject = true
            } label: {
                Label("New Project", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .liquidGlass()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcomePlaceholderView: some View {
        VStack(spacing: 32) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 100))
                .foregroundStyle(.theaPrimary)

            VStack(spacing: 12) {
                Text("Welcome to THEA")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your AI Life Companion")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Text("Select a section from the sidebar to get started")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - iPad Conversation Row

private struct IPadConversationRow: View {
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
                Text(lastMessage.content.textValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text(conversation.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if !conversation.messages.isEmpty {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("\(conversation.messages.count) messages")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - iPad Project Row

private struct IPadProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)

                Text(project.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack(spacing: 16) {
                Label("\(project.conversations.count)", systemImage: "message")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(project.files.count)", systemImage: "doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(project.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - iPad Chat Detail View

struct IPadChatDetailView: View {
    let conversation: Conversation

    @Environment(\.modelContext) private var modelContext
    @State private var chatManager = ChatManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    @Query private var allMessages: [Message]

    @State private var messageText = ""
    @State private var isListeningForVoice = false
    @State private var showingAttachmentOptions = false
    @FocusState private var isInputFocused: Bool

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
            Divider()
            inputArea
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button {
                        isListeningForVoice.toggle()
                        handleVoiceInput()
                    } label: {
                        Image(systemName: isListeningForVoice ? "mic.fill" : "mic")
                            .foregroundStyle(isListeningForVoice ? .red : .theaPrimary)
                    }

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
        }
        .onAppear {
            chatManager.selectConversation(conversation)
            isInputFocused = true
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if chatManager.isStreaming, !chatManager.streamingText.isEmpty {
                        HStack {
                            Text(chatManager.streamingText)
                                .padding(16)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .id("streaming")
                    }
                }
                .padding(.vertical, 20)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatManager.streamingText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
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
        HStack(alignment: .bottom, spacing: 16) {
            // Attachment menu
            Menu {
                Button {
                    // Photo library - placeholder for future implementation
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }

                Button {
                    // Camera - placeholder for future implementation
                } label: {
                    Label("Camera", systemImage: "camera")
                }

                Button {
                    // Files - placeholder for future implementation
                } label: {
                    Label("Files", systemImage: "folder")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }

            TextField("Message THEA...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .lineLimit(1 ... 8)
                .focused($isInputFocused)
                .disabled(chatManager.isStreaming)
                .submitLabel(.send)
                .onSubmit {
                    if !messageText.isEmpty, !chatManager.isStreaming {
                        sendMessage()
                    }
                }

            Button {
                if chatManager.isStreaming {
                    chatManager.cancelStreaming()
                } else {
                    sendMessage()
                }
            } label: {
                Image(systemName: chatManager.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        messageText.isEmpty && !chatManager.isStreaming
                            ? Color.secondary
                            : Color.theaPrimary
                    )
            }
            .disabled(messageText.isEmpty && !chatManager.isStreaming)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .liquidGlassRounded(cornerRadius: 0)
        .background(Color(uiColor: .systemBackground).opacity(0.8))
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
            voiceManager.onTranscriptionComplete = { transcription in
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
                        .foregroundStyle(.secondary)
                } else {
                    Text(project.customInstructions)
                }
            }

            if !project.conversations.isEmpty {
                Section("Conversations") {
                    ForEach(project.conversations) { conversation in
                        NavigationLink(destination: IPadChatDetailView(conversation: conversation)) {
                            IPadConversationRow(conversation: conversation)
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
