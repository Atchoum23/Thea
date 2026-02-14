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
