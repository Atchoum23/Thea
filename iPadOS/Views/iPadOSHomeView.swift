import SwiftData
import SwiftUI

@MainActor
struct iPadOSHomeView: View {
  @Environment(\.modelContext) private var modelContext
  @StateObject private var chatManager = ChatManager.shared
  @StateObject private var projectManager = ProjectManager.shared
  @StateObject private var voiceManager = VoiceActivationManager.shared

  @State private var selectedTab: NavigationItem? = .chat
  @State private var selectedConversation: Conversation?
  @State private var selectedProject: Project?
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  enum NavigationItem: String, CaseIterable, Identifiable {
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
  }

  private var sidebarContent: some View {
    List(NavigationItem.allCases, selection: $selectedTab) { item in
      NavigationLink(value: item) {
        Label(item.rawValue, systemImage: item.icon)
      }
    }
    .navigationTitle("THEA")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          columnVisibility = .all
        } label: {
          Image(systemName: "sidebar.left")
        }
      }
    }
  }

  @ViewBuilder
  private var listContent: some View {
    switch selectedTab {
    case .chat:
      chatListView
    case .projects:
      projectsListView
    case .knowledge:
      iOSKnowledgeView()
    case .financial:
      iOSFinancialView()
    case .settings:
      iOSSettingsView()
    case .none:
      Text("Select a section")
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var detailContent: some View {
    if let conversation = selectedConversation {
      iPadOSChatDetailView(conversation: conversation)
    } else if let project = selectedProject {
      iPadOSProjectDetailView(project: project)
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
  }

  private var projectsListView: some View {
    List(projectManager.projects, selection: $selectedProject) { project in
      NavigationLink(value: project) {
        ProjectRow(project: project)
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
  }

  private var placeholderView: some View {
    VStack(spacing: 24) {
      Image(systemName: selectedTab?.icon ?? "brain.head.profile")
        .font(.system(size: 64))
        .foregroundStyle(.theaPrimary)

      Text("Welcome to THEA")
        .font(.title)
        .fontWeight(.semibold)

      Text("Your AI Life Companion")
        .font(.title3)
        .foregroundStyle(.secondary)

      if selectedTab == .chat {
        Button {
          createNewConversation()
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

struct iPadOSChatDetailView: View {
  let conversation: Conversation

  @StateObject private var chatManager = ChatManager.shared
  @StateObject private var voiceManager = VoiceActivationManager.shared

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
    .navigationBarTitleDisplayMode(.inline)
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
    HStack(alignment: .bottom, spacing: 16) {
      TextField("Message THEA...", text: $messageText, axis: .vertical)
        .textFieldStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .lineLimit(1...8)
        .focused($isInputFocused)
        .disabled(chatManager.isStreaming)

      Button {
        sendMessage()
      } label: {
        Image(systemName: chatManager.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
          .font(.system(size: 40))
          .foregroundStyle(
            messageText.isEmpty && !chatManager.isStreaming ? .secondary : .theaPrimary)
      }
      .disabled(messageText.isEmpty && !chatManager.isStreaming)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .background(Color(uiColor: .systemBackground))
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

// MARK: - Project Detail View

struct iPadOSProjectDetailView: View {
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
              .frame(minHeight: 150)
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
          NavigationLink(destination: iPadOSChatDetailView(conversation: conversation)) {
            ConversationRow(conversation: conversation)
          }
        }
      }

      Section("Files") {
        ForEach(project.files) { file in
          HStack {
            Image(systemName: "doc.fill")
              .foregroundStyle(.theaPrimary)

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
