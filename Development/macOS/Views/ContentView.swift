import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var chatManager = ChatManager.shared
    @StateObject private var projectManager = ProjectManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    @State private var selectedItem: NavigationItem? = .chat
    @State private var selectedConversation: Conversation?
    @State private var selectedProject: Project?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
            case .chat: return "message.fill"
            case .projects: return "folder.fill"
            case .knowledge: return "brain.head.profile"
            case .financial: return "dollarsign.circle.fill"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .migration: return "arrow.down.doc.fill"
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
        .onAppear {
            setupManagers()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.left")
                }
            }
        }
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

    private func toggleSidebar() {
        NSApp.keyWindow?.contentViewController?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
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

// MARK: - Chat Detail View

struct macOSChatDetailView: View {
    let conversation: Conversation

    @StateObject private var chatManager = ChatManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    @State private var messageText = ""
    @State private var isListeningForVoice = false
    @FocusState private var isInputFocused: Bool

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
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(conversation.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(24)
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
        HStack(alignment: .bottom, spacing: 16) {
            TextField("Message THEA...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .lineLimit(1...8)
                .focused($isInputFocused)
                .disabled(chatManager.isStreaming)
                .onSubmit {
                    if !messageText.isEmpty {
                        sendMessage()
                    }
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: chatManager.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(messageText.isEmpty && !chatManager.isStreaming ? Color.secondary : Color.theaPrimary)
            }
            .buttonStyle(.plain)
            .disabled(messageText.isEmpty && !chatManager.isStreaming)
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sendMessage() {
        guard !messageText.isEmpty || chatManager.isStreaming else { return }

        if chatManager.isStreaming {
            chatManager.cancelStreaming()
        } else {
            let text = messageText
            messageText = ""

            Task {
                try? await chatManager.sendMessage(text, in: conversation)
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
