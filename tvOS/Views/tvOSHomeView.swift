import SwiftUI
import SwiftData

struct tvOSHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var chatManager = ChatManager.shared
    @StateObject private var projectManager = ProjectManager.shared

    @State private var selectedTab: Tab = .chat
    @State private var selectedConversation: Conversation?

    enum Tab: String, CaseIterable {
        case chat = "Chat"
        case projects = "Projects"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .chat: return "message.fill"
            case .projects: return "folder.fill"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                NavigationStack {
                    viewForTab(tab)
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .onAppear {
            chatManager.setModelContext(modelContext)
            projectManager.setModelContext(modelContext)
        }
    }

    @ViewBuilder
    private func viewForTab(_ tab: Tab) -> some View {
        switch tab {
        case .chat:
            tvOSChatView()
        case .projects:
            tvOSProjectsView()
        case .settings:
            tvOSSettingsView()
        }
    }
}

// MARK: - Chat View

struct tvOSChatView: View {
    @StateObject private var chatManager = ChatManager.shared
    @State private var selectedConversation: Conversation?
    @State private var showingNewChat = false

    var body: some View {
        HStack(spacing: 0) {
            conversationList
                .frame(width: 400)

            Divider()

            if let conversation = selectedConversation {
                chatDetail(conversation: conversation)
            } else {
                placeholderView
            }
        }
        .sheet(isPresented: $showingNewChat) {
            tvOSNewChatView()
        }
    }

    private var conversationList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conversations")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    showingNewChat = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if chatManager.conversations.isEmpty {
                VStack(spacing: 24) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("No Conversations")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Button("New Chat") {
                        showingNewChat = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(chatManager.conversations, selection: $selectedConversation) { conversation in
                    Button {
                        selectedConversation = conversation
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(conversation.title)
                                .font(.headline)
                                .lineLimit(1)

                            if let lastMessage = conversation.messages.last {
                                Text(lastMessage.content)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func chatDetail(conversation: Conversation) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(conversation.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if chatManager.isStreaming {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(conversation.messages) { message in
                        tvOSMessageBubble(message: message)
                    }
                }
                .padding()
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 32) {
            Image(systemName: "message.fill")
                .font(.system(size: 100))
                .foregroundStyle(.theaPrimary)

            Text("Welcome to THEA")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your AI Life Companion on Apple TV")
                .font(.title2)
                .foregroundStyle(.secondary)

            Button {
                showingNewChat = true
            } label: {
                Label("New Conversation", systemImage: "plus")
                    .font(.title3)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct tvOSMessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if message.messageRole == .user {
                Spacer(minLength: 100)
            }

            VStack(alignment: message.messageRole == .user ? .trailing : .leading, spacing: 12) {
                HStack {
                    if message.messageRole == .assistant {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.theaPrimary)
                    }

                    Text(message.messageRole == .user ? "You" : "THEA")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    if message.messageRole == .user {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.theaPrimary)
                    }
                }

                Text(message.content)
                    .font(.title3)
                    .padding(20)
                    .background(backgroundColor)
                    .foregroundStyle(message.messageRole == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .frame(maxWidth: 800, alignment: message.messageRole == .user ? .trailing : .leading)

            if message.messageRole == .assistant {
                Spacer(minLength: 100)
            }
        }
    }

    private var backgroundColor: Color {
        switch message.messageRole {
        case .user:
            return .theaPrimary
        case .assistant:
            return Color(.systemGray5)
        case .system:
            return Color(.systemGray4)
        }
    }
}

// MARK: - Projects View

struct tvOSProjectsView: View {
    @StateObject private var projectManager = ProjectManager.shared
    @State private var selectedProject: Project?

    var body: some View {
        HStack(spacing: 0) {
            projectList
                .frame(width: 400)

            Divider()

            if let project = selectedProject {
                projectDetail(project: project)
            } else {
                placeholderView
            }
        }
    }

    private var projectList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    createNewProject()
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if projectManager.projects.isEmpty {
                emptyProjectsView
            } else {
                List(projectManager.projects, selection: $selectedProject) { project in
                    Button {
                        selectedProject = project
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(project.title)
                                .font(.headline)
                                .lineLimit(1)

                            HStack(spacing: 20) {
                                Label("\(project.conversations.count)", systemImage: "message.fill")
                                Label("\(project.files.count)", systemImage: "doc.fill")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyProjectsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Projects")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("New Project") {
                createNewProject()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectDetail(project: Project) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(project.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(label: "Conversations", value: "\(project.conversations.count)")
                            DetailRow(label: "Files", value: "\(project.files.count)")
                            DetailRow(label: "Created", value: project.createdAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }

                    if !project.customInstructions.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Custom Instructions")
                                .font(.headline)

                            Text(project.customInstructions)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 32) {
            Image(systemName: "folder.fill")
                .font(.system(size: 100))
                .foregroundStyle(.theaPrimary)

            Text("Organize Your Work")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Create projects to group related conversations")
                .font(.title2)
                .foregroundStyle(.secondary)

            Button {
                createNewProject()
            } label: {
                Label("New Project", systemImage: "plus")
                    .font(.title3)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createNewProject() {
        let project = projectManager.createProject(title: "New Project")
        selectedProject = project
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Settings View

struct tvOSSettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared

    var body: some View {
        Form {
            Section("AI Provider") {
                Picker("Default Provider", selection: $settingsManager.defaultProvider) {
                    ForEach(settingsManager.availableProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }

                Toggle("Stream Responses", isOn: $settingsManager.streamResponses)
            }

            Section("Appearance") {
                Picker("Theme", selection: $settingsManager.theme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }

                Picker("Font Size", selection: $settingsManager.fontSize) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }
            }

            Section("Privacy") {
                Toggle("iCloud Sync", isOn: $settingsManager.iCloudSyncEnabled)
                Toggle("Analytics", isOn: $settingsManager.analyticsEnabled)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Platform")
                    Spacer()
                    Text("tvOS")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - New Chat View

struct tvOSNewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatManager = ChatManager.shared

    @State private var title = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("New Conversation")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                TextField("Conversation title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.title2)
                    .frame(width: 600)
                    .focused($isFocused)

                HStack(spacing: 24) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Create") {
                        createChat()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.isEmpty)
                }
            }
            .padding(60)
            .onAppear {
                isFocused = true
            }
        }
    }

    private func createChat() {
        chatManager.createConversation(title: title.isEmpty ? "New Conversation" : title)
        dismiss()
    }
}
