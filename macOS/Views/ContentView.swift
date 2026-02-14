@preconcurrency import SwiftData
import SwiftUI

// MARK: - Content View (macOS)

/// Main macOS window shell with three-column NavigationSplitView.
/// Column 1: Section sidebar (Chat, Projects, Knowledge, etc.)
/// Column 2: List view (conversations, projects, etc.)
/// Column 3: Detail view (chat, project details, etc.)
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
    @State private var welcomeInputText = ""
    @State private var isListeningForVoice = false
    @State private var showingNewProjectDialog = false
    @State private var showingRenameProjectDialog = false
    @State private var renamingProject: Project?
    @State private var showingKeyboardShortcuts = false
    @State private var showingCommandPalette = false
    @State private var newProjectTitle = ""

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } content: {
            listContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.prominentDetail)
        .toolbar(removing: .sidebarToggle)
        .toolbarTitleDisplayMode(.inline)
        .textSelection(.enabled)
        .preferredColorScheme(colorSchemeForTheme)
        .id("\(settingsManager.fontSize)_\(settingsManager.theme)")
        .onAppear {
            setupManagers()
        }
        .onChange(of: settingsManager.windowFloatOnTop) { _, floatOnTop in
            NSApp.keyWindow?.level = floatOnTop ? .floating : .normal
        }
        .sheet(isPresented: $showingKeyboardShortcuts) {
            KeyboardShortcutsHelpView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .overlay {
            if showingCommandPalette {
                CommandPaletteView(
                    isPresented: $showingCommandPalette,
                    commands: CommandPaletteManager.shared.commands
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
            showingCommandPalette = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { _ in
            showingKeyboardShortcuts = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectNewConversation)) { notification in
            if let conversation = notification.object as? Conversation {
                selectedItem = .chat
                selectedConversation = conversation
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSection)) { notification in
            if let section = notification.object as? String {
                switch section {
                case "chat": selectedItem = .chat
                case "projects": selectedItem = .projects
                case "knowledge": selectedItem = .knowledge
                default: break
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleDarkMode)) { _ in
            settingsManager.theme = settingsManager.theme == "dark" ? "light" : "dark"
        }
        .onReceive(NotificationCenter.default.publisher(for: .newConversation)) { _ in
            let conversation = chatManager.createConversation(title: "New Conversation")
            selectedItem = .chat
            selectedConversation = conversation
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickEntrySubmit)) { notification in
            guard let text = notification.object as? String, !text.isEmpty else { return }
            let conversation = selectedConversation ?? chatManager.createConversation(title: "New Conversation")
            selectedItem = .chat
            selectedConversation = conversation
            chatManager.queueOrSendMessage(text, in: conversation)
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportConversation)) { _ in
            guard let conversation = selectedConversation else { return }
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "\(conversation.title).md"
            panel.allowedContentTypes = [.plainText]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            let messages = conversation.messages.sorted { $0.timestamp < $1.timestamp }
            var lines = ["# \(conversation.title)", "", "*Exported \(Date().formatted(.dateTime))*", ""]
            for msg in messages {
                let role = msg.messageRole == .user ? "**You**" : "**Thea**"
                let time = msg.timestamp.formatted(.dateTime.hour().minute())
                lines.append("### \(role) — \(time)")
                lines.append("")
                lines.append(msg.content.textValue)
                lines.append("")
                lines.append("---")
                lines.append("")
            }
            try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(NavigationItem.allCases, selection: $selectedItem) { item in
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.icon)
                    .font(.theaBody)
            }
        }
        .navigationTitle("THEA")
        .frame(minWidth: 160, idealWidth: 180)
        .listStyle(.sidebar)
    }

    // MARK: - List Column

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
            ContentUnavailableView(
                "Select a Section",
                systemImage: "sidebar.left",
                description: Text("Choose a section from the sidebar.")
            )
        }
    }

    // MARK: - Detail Column

    @ViewBuilder
    private var detailContent: some View {
        if let conversation = selectedConversation {
            MacChatDetailView(conversation: conversation)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        sidebarToggleButton
                    }
                }
        } else if let project = selectedProject {
            MacProjectDetailView(project: project)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        sidebarToggleButton
                    }
                }
        } else {
            // Welcome view with input bar always visible at bottom
            VStack(spacing: 0) {
                WelcomeView { prompt in
                    welcomeInputText = ""
                    let conversation = chatManager.createConversation(title: "New Conversation")
                    selectedConversation = conversation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        Task {
                            try? await chatManager.sendMessage(prompt, in: conversation)
                        }
                    }
                }

                // Input bar always visible even on welcome screen
                ChatInputView(
                    text: $welcomeInputText,
                    isStreaming: false,
                    onSend: {
                        guard !welcomeInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        else { return }
                        let prompt = welcomeInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        welcomeInputText = ""
                        let conversation = chatManager.createConversation(title: "New Conversation")
                        selectedConversation = conversation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            Task {
                                try? await chatManager.sendMessage(prompt, in: conversation)
                            }
                        }
                    },
                    onVoiceToggle: {
                        isListeningForVoice.toggle()
                        handleVoiceInput()
                    },
                    isListening: isListeningForVoice
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    sidebarToggleButton
                }
            }
        }
    }

    /// Sidebar toggle button — shown in detail column toolbar so it's always accessible.
    /// Cycles: .all → .doubleColumn (hide nav sidebar) → .detailOnly (hide conversations too) → .all
    private var sidebarToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                switch columnVisibility {
                case .all:
                    columnVisibility = .doubleColumn
                case .doubleColumn:
                    columnVisibility = .detailOnly
                default:
                    columnVisibility = .all
                }
            }
        } label: {
            Image(systemName: columnVisibility == .all ? "sidebar.left" : "sidebar.right")
        }
        .help(columnVisibility == .detailOnly ? "Show All Panels" : (columnVisibility == .doubleColumn ? "Hide Conversations" : "Hide Sidebar"))
        .accessibilityLabel(columnVisibility == .detailOnly ? "Show all panels" : (columnVisibility == .doubleColumn ? "Hide conversations" : "Hide sidebar"))
    }

    // MARK: - Chat List

    private var chatListView: some View {
        SidebarView(selection: $selectedConversation)
            .frame(minWidth: 250)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let conversation = chatManager.createConversation(title: "New Conversation")
                        selectedConversation = conversation
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("New Conversation (⇧⌘N)")
                    .accessibilityLabel("New conversation")
                }
            }
    }

    // MARK: - Projects List

    private var projectsListView: some View {
        List(projectManager.projects, selection: $selectedProject) { project in
            NavigationLink(value: project) {
                ContentProjectRow(project: project)
            }
            .contextMenu {
                Button("Rename") {
                    newProjectTitle = project.title
                    renamingProject = project
                    showingRenameProjectDialog = true
                }
                Divider()
                Button("Delete", role: .destructive) {
                    projectManager.deleteProject(project)
                    if selectedProject?.id == project.id {
                        selectedProject = nil
                    }
                }
            }
        }
        .overlay {
            if projectManager.projects.isEmpty {
                ContentUnavailableView {
                    Label("No Projects", systemImage: "folder")
                } description: {
                    Text("Create a project to organize related conversations.")
                } actions: {
                    Button("Create Project") {
                        newProjectTitle = ""
                        showingNewProjectDialog = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newProjectTitle = ""
                    showingNewProjectDialog = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Project (⇧⌘P)")
                .accessibilityLabel("New project")
            }
        }
        .frame(minWidth: 250)
        .alert("New Project", isPresented: $showingNewProjectDialog) {
            TextField("Project Name", text: $newProjectTitle)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                createNewProject()
            }
            .disabled(newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a name for your new project workspace.")
        }
        .alert("Rename Project", isPresented: $showingRenameProjectDialog) {
            TextField("Project Name", text: $newProjectTitle)
            Button("Cancel", role: .cancel) {
                renamingProject = nil
            }
            Button("Rename") {
                renameProject()
            }
            .disabled(newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a new name for this project.")
        }
    }

    // MARK: - Actions

    private func createNewProject() {
        let title = newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = projectManager.createProject(title: title.isEmpty ? "New Project" : title)
        selectedProject = project
    }

    private func renameProject() {
        guard let project = renamingProject else { return }
        let title = newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        project.title = title
        project.updatedAt = Date()
        renamingProject = nil
    }

    private func handleVoiceInput() {
        if isListeningForVoice {
            try? voiceManager.startVoiceCommand()
            voiceManager.onTranscriptionComplete = { (transcription: String) in
                welcomeInputText = transcription
                isListeningForVoice = false
            }
        } else {
            voiceManager.stopVoiceCommand()
        }
    }

    // MARK: - Theme & Settings

    private var colorSchemeForTheme: ColorScheme? {
        switch settingsManager.theme {
        case "light": .light
        case "dark": .dark
        default: nil
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

// MARK: - Navigation Items

extension ContentView {
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
}

// MARK: - Placeholder Views (to be implemented)

struct macOSKnowledgeView: View {
    var body: some View {
        ContentUnavailableView(
            "Knowledge Base",
            systemImage: "brain.head.profile",
            description: Text("Coming soon in a future update.")
        )
    }
}

struct macOSFinancialView: View {
    var body: some View {
        ContentUnavailableView(
            "Financial Tracking",
            systemImage: "dollarsign.circle.fill",
            description: Text("Coming soon in a future update.")
        )
    }
}

struct macOSCodeView: View {
    var body: some View {
        ContentUnavailableView(
            "Code Intelligence",
            systemImage: "chevron.left.forwardslash.chevron.right",
            description: Text("Coming soon in a future update.")
        )
    }
}

struct macOSMigrationView: View {
    var body: some View {
        ContentUnavailableView(
            "Migration",
            systemImage: "arrow.down.doc.fill",
            description: Text("Coming soon in a future update.")
        )
    }
}

// MARK: - Project Row

struct ContentProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.xxs) {
            HStack(spacing: TheaSpacing.sm) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.theaPrimaryDefault)

                Text(project.title)
                    .font(.theaBody)
                    .lineLimit(1)
            }

            HStack(spacing: TheaSpacing.xs) {
                Text("\(project.conversations.count) conversations")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)

                Text("·")
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)

                Text("\(project.files.count) files")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, TheaSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.title), \(project.conversations.count) conversations, \(project.files.count) files")
    }
}
