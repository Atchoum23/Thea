import OSLog
@preconcurrency import SwiftData
import SwiftUI

// MARK: - iOS Home View

@MainActor
struct iOSHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var chatManager = ChatManager.shared
    @State private var projectManager = ProjectManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    @State private var selectedTab: AppTab = .chat
    @State private var showingNewConversation = false
    @State private var showingVoiceSettings = false

    // Renamed from Tab to AppTab to avoid conflict with SwiftUI's iOS 18+ Tab type.
    enum AppTab: String, CaseIterable, Identifiable {
        case chat = "Chat"
        case projects = "Projects"
        case health = "Health"
        case knowledge = "Knowledge"
        case translation = "Translate"
        case financial = "Financial"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .chat: "bubble.left.and.bubble.right.fill"
            case .projects: "folder.fill"
            case .health: "heart.fill"
            case .knowledge: "books.vertical.fill"
            case .translation: "character.bubble.fill"
            case .financial: "chart.pie.fill"
            case .settings: "gearshape"
            }
        }
    }

    var body: some View {
        // iOS 18+ Tab API: correctly exposes tab labels in the iOS 26 liquid glass
        // tab bar accessibility tree (old .tabItem{} API hides text on iOS 26).
        TabView(selection: $selectedTab) {
            Tab("Chat", systemImage: AppTab.chat.icon, value: AppTab.chat) {
                NavigationStack {
                    viewForTab(.chat)
                        .navigationTitle("Chat")
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { toolbarButtonForTab(.chat) } }
                }
            }
            .accessibilityIdentifier("tab-chat")
            Tab("Projects", systemImage: AppTab.projects.icon, value: AppTab.projects) {
                NavigationStack {
                    viewForTab(.projects)
                        .navigationTitle("Projects")
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { toolbarButtonForTab(.projects) } }
                }
            }
            .accessibilityIdentifier("tab-projects")
            Tab("Health", systemImage: AppTab.health.icon, value: AppTab.health) {
                NavigationStack {
                    viewForTab(.health)
                        .navigationTitle("Health")
                }
            }
            .accessibilityIdentifier("tab-health")
            Tab("Knowledge", systemImage: AppTab.knowledge.icon, value: AppTab.knowledge) {
                NavigationStack {
                    viewForTab(.knowledge)
                        .navigationTitle("Knowledge")
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { toolbarButtonForTab(.knowledge) } }
                }
            }
            .accessibilityIdentifier("tab-knowledge")
            Tab("Translate", systemImage: AppTab.translation.icon, value: AppTab.translation) {
                NavigationStack {
                    viewForTab(.translation)
                        .navigationTitle("Translate")
                }
            }
            .accessibilityIdentifier("tab-translate")
            Tab("Financial", systemImage: AppTab.financial.icon, value: AppTab.financial) {
                NavigationStack {
                    viewForTab(.financial)
                        .navigationTitle("Financial")
                }
            }
            .accessibilityIdentifier("tab-financial")
            Tab("Settings", systemImage: AppTab.settings.icon, value: AppTab.settings) {
                NavigationStack {
                    viewForTab(.settings)
                        .navigationTitle("Settings")
                }
            }
            .accessibilityIdentifier("tab-settings")
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
    private func viewForTab(_ tab: AppTab) -> some View {
        switch tab {
        case .chat:
            iOSChatListView(showingNewConversation: $showingNewConversation)
        case .projects:
            iOSProjectsView()
        case .health:
            HealthDashboardView()
        case .knowledge:
            iOSKnowledgeView()
        case .translation:
            TranslationView()
        case .financial:
            iOSFinancialView()
        case .settings:
            iOSSettingsView()
        }
    }

    @ViewBuilder
    private func toolbarButtonForTab(_ tab: AppTab) -> some View {
        switch tab {
        case .chat:
            Button {
                showingNewConversation = true
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel("New conversation")
        case .projects:
            Button {
                _ = projectManager.createProject(title: "New Project")
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("New project")
        case .knowledge:
            Button {
                showingVoiceSettings = true
            } label: {
                Image(systemName: voiceManager.isEnabled ? "mic.fill" : "mic.slash.fill")
                    .foregroundStyle(voiceManager.isEnabled ? .theaPrimary : .secondary)
            }
            .accessibilityLabel(voiceManager.isEnabled ? "Voice enabled, tap to configure" : "Voice disabled, tap to configure")
        case .health, .translation, .financial, .settings:
            EmptyView()
        }
    }

    private func setupManagers() {
        chatManager.setModelContext(modelContext)
        projectManager.setModelContext(modelContext)

        if voiceManager.isEnabled {
            Task {
                do {
                    try await voiceManager.requestPermissions()
                    try voiceManager.startWakeWordDetection()
                } catch {
                    Logger(subsystem: "app.thea", category: "iOSHome")
                        .error("Voice setup failed: \(error.localizedDescription)")
                }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(iosConversationAccessibilityLabel)
    }

    private var iosConversationAccessibilityLabel: String {
        var label = conversation.title
        if conversation.isPinned { label += ", pinned" }
        let time = conversation.updatedAt.formatted(.relative(presentation: .named))
        label += ", \(time)"
        if let lastMessage = conversation.messages.last {
            let preview = lastMessage.content.textValue
            label += ". \(preview.count > 80 ? String(preview.prefix(80)) + "..." : preview)"
        }
        return label
    }
}
