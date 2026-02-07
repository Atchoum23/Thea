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

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } content: {
            listContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .textSelection(.enabled)
        .preferredColorScheme(colorSchemeForTheme)
        .dynamicTypeSize(dynamicTypeSizeForFontSize)
        .onAppear {
            setupManagers()
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
                        conversationsPanelToggle
                    }
                }
        } else if let project = selectedProject {
            MacProjectDetailView(project: project)
        } else {
            // Welcome view with input bar always visible at bottom
            VStack(spacing: 0) {
                WelcomeView()

                // Input bar always visible even on welcome screen
                ChatInputView(
                    text: $welcomeInputText,
                    isStreaming: false
                ) {
                    guard !welcomeInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    let prompt = welcomeInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    welcomeInputText = ""
                    let conversation = chatManager.createConversation(title: "New Conversation")
                    selectedConversation = conversation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        Task {
                            try? await chatManager.sendMessage(prompt, in: conversation)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    conversationsPanelToggle
                }
            }
        }
    }

    /// Toggle the conversations list (content column) visibility using NavigationSplitView's columnVisibility
    private var conversationsPanelToggle: some View {
        Button {
            withAnimation {
                if columnVisibility == .all {
                    columnVisibility = .detailOnly
                } else {
                    columnVisibility = .all
                }
            }
        } label: {
            Image(systemName: columnVisibility == .all ? "sidebar.right" : "sidebar.left")
        }
        .help(columnVisibility == .all ? "Hide Conversations" : "Show Conversations")
    }

    // MARK: - Chat List

    private var chatListView: some View {
        SidebarView(selection: $selectedConversation)
            .frame(minWidth: 250)
    }

    // MARK: - Projects List

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
                .help("New Project")
            }
        }
        .frame(minWidth: 250)
    }

    // MARK: - Actions

    private func createNewProject() {
        let project = projectManager.createProject(title: "New Project")
        selectedProject = project
    }

    // MARK: - Theme & Settings

    private var colorSchemeForTheme: ColorScheme? {
        switch settingsManager.theme {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    private var dynamicTypeSizeForFontSize: DynamicTypeSize {
        switch settingsManager.fontSize {
        case "small": .small
        case "large": .xxxLarge
        default: .medium
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
    }
}
