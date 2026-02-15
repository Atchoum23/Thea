@preconcurrency import SwiftData
import SwiftUI

// MARK: - Unified Chat View

/// Cross-platform chat view using shared components.
/// Adapts horizontal padding via environment size class.
/// Uses shared MessageBubble, ChatInputView, StreamingMessageView, and WelcomeView.
struct ChatView: View {
    let conversation: Conversation

    @State var chatManager = ChatManager.shared
    @State private var planManager = PlanManager.shared
    @State var orchestrator = TheaAgentOrchestrator.shared
    @State var inputText = ""
    @State var selectedProvider: AIProvider?
    @State var showingError: Error?
    @State private var showingRenameDialog = false
    @State private var showingExportDialog = false
    @State var showingAPIKeySetup = false
    @State private var newTitle = ""
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var syncConflictManager = SyncConflictManager.shared

    /// Message being edited (triggers edit sheet)
    @State var editingMessage: Message?

    /// Selected agent session (for inspector panel)
    @State var selectedAgentSession: TheaAgentSession?

    /// Model comparison mode
    @State var isComparisonMode = false
    @State var comparisonResults: (Message, Message)?

    /// Tracks which branch index is selected for each parent message ID
    @State var selectedBranches: [UUID: Int] = [:]

    /// Search state
    @State var isSearching = false
    @State var searchText = ""
    @State var searchMatchIndex = 0

    @Query private var allMessages: [Message]

    /// All messages for this conversation, sorted by time
    var allConversationMessages: [Message] {
        allMessages
            .filter { $0.conversationID == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Messages filtered to show only the currently-selected branch for each message position
    var messages: [Message] {
        var result: [Message] = []
        var seenParents = Set<UUID>()

        for msg in allConversationMessages {
            let parentId = msg.parentMessageId ?? msg.id

            // Skip if we already picked a branch for this parent
            guard !seenParents.contains(parentId) else { continue }

            // Find all siblings (branches) for this parent
            let siblings = allConversationMessages.filter {
                $0.id == parentId || $0.parentMessageId == parentId
            }

            if siblings.count <= 1 {
                // No branching — just show the message
                result.append(msg)
            } else {
                // Pick the branch the user selected (default 0 = original)
                let selectedIdx = selectedBranches[parentId] ?? 0
                let sorted = siblings.sorted { $0.branchIndex < $1.branchIndex }
                if selectedIdx < sorted.count {
                    result.append(sorted[selectedIdx])
                } else {
                    result.append(sorted[0])
                }
            }

            seenParents.insert(parentId)
        }

        return result
    }

    init(conversation: Conversation) {
        self.conversation = conversation
        _allMessages = Query(sort: \Message.timestamp)
    }

    /// Messages matching the current search query
    var searchMatches: [Message] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return messages.filter { $0.content.textValue.lowercased().contains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            if isSearching {
                chatSearchBar
            }
            #endif
            messageList
            if !orchestrator.activeSessions.isEmpty {
                TheaAgentStatusBar(
                    sessions: orchestrator.sessions
                ) { session in
                    selectedAgentSession = session
                }
            }
            chatInput
        }
        .overlay(alignment: .bottomTrailing) {
            if planManager.isPanelCollapsed && planManager.activePlan?.isActive == true {
                CompactPlanBar()
                    .padding(TheaSpacing.lg)
            }
        }
        #if os(macOS) || os(iOS)
        .inspector(isPresented: Binding(
            get: { planManager.isPanelVisible || selectedAgentSession != nil },
            set: { if !$0 { planManager.isPanelVisible = false; selectedAgentSession = nil } }
        )) {
            if let session = selectedAgentSession {
                #if os(macOS)
                TheaAgentDetailView(session: session)
                    .inspectorColumnWidth(min: 300, ideal: 400, max: 500)
                #endif
            } else {
                PlanPanel()
                    .inspectorColumnWidth(min: 300, ideal: 400, max: 500)
            }
        }
        #endif
        .navigationTitle(conversation.title)
        #if os(macOS)
            .navigationSubtitle("\(messages.count) messages")
        #endif
            .toolbar {
                ToolbarItem {
                    // Plan toggle — only visible when a plan exists
                    if planManager.activePlan != nil {
                        Button {
                            planManager.togglePanel()
                        } label: {
                            Label("Plan", systemImage: "list.bullet.clipboard")
                        }
                        .help("Toggle plan panel")
                    }
                }

                ToolbarItem {
                    if !orchestrator.sessions.isEmpty {
                        Button {
                            if let first = orchestrator.activeSessions.first {
                                selectedAgentSession = first
                            } else if let first = orchestrator.sessions.first {
                                selectedAgentSession = first
                            }
                        } label: {
                            Label("Agents", systemImage: "person.3.fill")
                        }
                        .help("Show agent details")
                    }
                }

                #if os(macOS)
                ToolbarItem {
                    Button {
                        isSearching.toggle()
                        if !isSearching {
                            searchText = ""
                            searchMatchIndex = 0
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .keyboardShortcut("f", modifiers: .command)
                    .help("Search in conversation (⌘F)")
                    .accessibilityLabel("Search messages")
                }
                #endif

                #if os(macOS)
                ToolbarItem {
                    Toggle(isOn: $isComparisonMode) {
                        Label("Compare", systemImage: "square.split.2x1")
                    }
                    .help("Compare models: send next message to two providers side-by-side")
                    .accessibilityLabel("Toggle model comparison mode")
                }
                #endif

                ToolbarItem {
                    SyncStatusIndicator()
                        .help("Sync status and transport info")
                }

                ToolbarItem {
                    ConversationLanguagePickerView(conversation: conversation)
                        .help("Set conversation language")
                }

                ToolbarItem {
                    Menu {
                        Button("Rename") {
                            newTitle = conversation.title
                            showingRenameDialog = true
                        }

                        Button("Export") {
                            showingExportDialog = true
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            ChatManager.shared.deleteConversation(conversation)
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .alert("Rename Conversation", isPresented: $showingRenameDialog) {
                TextField("Title", text: $newTitle)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    conversation.title = newTitle
                }
            } message: {
                Text("Enter a new name for this conversation")
            }
            .fileExporter(
                isPresented: $showingExportDialog,
                document: ConversationDocument(conversation: conversation),
                contentType: .json,
                defaultFilename: "\(conversation.title).json"
            ) { result in
                if case let .failure(error) = result {
                    showingError = error
                }
            }
            .sheet(isPresented: $showingAPIKeySetup) {
                APIKeySetupView()
            }
            .alert(error: $showingError)
            .sheet(item: $syncConflictManager.activeConflict) { conflict in
                SyncConflictResolutionView(conflict: conflict) { resolution in
                    syncConflictManager.resolveActiveConflict(with: resolution)
                }
            }
            .task {
                await setupProvider()
            }
            .sheet(item: $editingMessage) { message in
                MessageEditSheet(
                    originalMessage: message,
                    onSave: { newText in
                        editingMessage = nil
                        Task {
                            do {
                                try await chatManager.editMessageAndBranch(
                                    message, newContent: newText, in: conversation
                                )
                            } catch {
                                showingError = error
                            }
                        }
                    },
                    onCancel: {
                        editingMessage = nil
                    }
                )
            }
    }

    // MARK: - Density-Aware Spacing

    private var messageSpacing: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.sm
        case "spacious": TheaSpacing.xxl
        default: TheaSpacing.lg
        }
    }

    private var messagePadding: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.sm
        case "spacious": TheaSpacing.xxl
        default: TheaSpacing.lg
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty && !chatManager.isStreaming {
                    WelcomeView { prompt in
                        inputText = prompt
                        sendMessage()
                    }
                } else {
                    LazyVStack(spacing: messageSpacing) {
                        // When streaming, hide the last assistant message to avoid duplicate display
                        let displayMessages = chatManager.isStreaming
                            ? messages.filter { msg in
                                if msg.messageRole == .assistant, msg.id == messages.last(where: { $0.messageRole == .assistant })?.id {
                                    return false
                                }
                                return true
                            }
                            : messages

                        ForEach(displayMessages) { message in
                            MessageBubble(
                                message: message,
                                onEdit: { msg in
                                    editingMessage = msg
                                },
                                onRegenerate: { msg in
                                    Task {
                                        do {
                                            try await chatManager.editMessageAndBranch(
                                                msg, newContent: msg.content.textValue,
                                                in: conversation
                                            )
                                        } catch {
                                            showingError = error
                                        }
                                    }
                                },
                                onAction: { action, msg in
                                    handleMessageAction(action, message: msg)
                                },
                                branchInfo: branchInfo(for: message)
                            )
                            .id(message.id)
                            #if os(macOS)
                            .overlay(
                                RoundedRectangle(cornerRadius: TheaCornerRadius.lg)
                                    .stroke(
                                        isCurrentSearchMatch(message) ? Color.accentColor : .clear,
                                        lineWidth: 2
                                    )
                            )
                            .opacity(searchDimOpacity(for: message))
                            #endif
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
                    .padding(.vertical, messagePadding)
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatManager.streamingText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: searchMatchIndex) { _, newIndex in
                if newIndex < searchMatches.count {
                    withAnimation(TheaAnimation.smooth) {
                        proxy.scrollTo(searchMatches[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Chat Input

    private var chatInput: some View {
        #if os(macOS)
            ChatInputView(
                text: $inputText,
                isStreaming: chatManager.isStreaming
            ) {
                if chatManager.isStreaming {
                    chatManager.cancelStreaming()
                } else {
                    sendMessage()
                }
            }
        #else
            HStack(spacing: TheaSpacing.md) {
                TextField("Message Thea...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1 ... 6)
                    .disabled(chatManager.isStreaming)
                    .onSubmit {
                        if !inputText.isEmpty {
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
                            !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isStreaming
                                ? Color.theaPrimaryDefault : .secondary
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatManager.isStreaming)
                .accessibilityLabel(chatManager.isStreaming ? "Stop generating" : "Send message")
                .accessibilityHint(chatManager.isStreaming ? "Stops the current response" : "Sends your message to Thea")
            }
            .padding(.horizontal, TheaSpacing.lg)
            .padding(.vertical, TheaSpacing.md)
        #endif
    }

}
