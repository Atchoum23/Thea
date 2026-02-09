@preconcurrency import SwiftData
import SwiftUI

// MARK: - macOS Chat Detail View

/// Full chat conversation view for macOS with message list, streaming support,
/// and glass-styled input area. Uses shared components from Sprint 2.
struct MacChatDetailView: View {
    let conversation: Conversation

    @Environment(\.modelContext) private var modelContext
    @StateObject private var chatManager = ChatManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    // Use @Query to properly observe message changes
    @Query private var allMessages: [Message]

    @StateObject private var settingsManager = SettingsManager.shared
    @State private var messageText = ""
    @State private var isListeningForVoice = false
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var searchMatchIndex = 0
    @State private var showingSystemPrompt = false
    @State private var systemPromptText = ""
    @FocusState private var isInputFocused: Bool
    @FocusState private var isSearchFocused: Bool

    /// Message spacing derived from the density setting
    private var messageSpacing: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.sm
        case "spacious": TheaSpacing.xxl
        default: TheaSpacing.lg  // "comfortable"
        }
    }

    /// Vertical padding derived from the density setting
    private var messagePadding: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.sm
        case "spacious": TheaSpacing.xl
        default: TheaSpacing.lg  // "comfortable"
        }
    }

    // Filter messages for this conversation
    private var messages: [Message] {
        allMessages
            .filter { $0.conversationID == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Messages matching the current search query
    private var searchMatches: [Message] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return messages.filter { $0.content.textValue.lowercased().contains(query) }
    }

    init(conversation: Conversation) {
        self.conversation = conversation
        _allMessages = Query(sort: \Message.timestamp)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSearching {
                searchBar
            }
            messageList
            chatInput
        }
        .navigationTitle(conversation.title)
        .onAppear {
            chatManager.selectConversation(conversation)
            isInputFocused = true
        }
        .keyboardShortcut("f", modifiers: .command)  // Note: handled via toolbar below
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    systemPromptText = conversation.metadata.systemPrompt ?? ""
                    showingSystemPrompt.toggle()
                } label: {
                    Image(systemName: "text.bubble")
                }
                .help("Edit system prompt")
                .popover(isPresented: $showingSystemPrompt, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: TheaSpacing.sm) {
                        Text("System Prompt")
                            .font(.theaSubhead)
                            .fontWeight(.semibold)

                        Text("Custom instructions for the AI in this conversation.")
                            .font(.theaCaption1)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $systemPromptText)
                            .font(.theaBody)
                            .frame(minHeight: 100, maxHeight: 200)
                            .scrollContentBackground(.hidden)
                            .padding(TheaSpacing.xs)
                            .background(Color.theaSurface)
                            .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.sm))

                        HStack {
                            Button("Clear") {
                                systemPromptText = ""
                                var metadata = conversation.metadata
                                metadata.systemPrompt = nil
                                conversation.metadata = metadata
                                try? modelContext.save()
                            }
                            .foregroundStyle(.secondary)

                            Spacer()

                            Button("Save") {
                                var metadata = conversation.metadata
                                metadata.systemPrompt = systemPromptText.isEmpty ? nil : systemPromptText
                                conversation.metadata = metadata
                                try? modelContext.save()
                                showingSystemPrompt = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(TheaSpacing.md)
                    .frame(width: 350)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    isSearching.toggle()
                    if isSearching {
                        isSearchFocused = true
                    } else {
                        searchText = ""
                        searchMatchIndex = 0
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: .command)
                .help("Search in conversation (⌘F)")
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: TheaSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search messages…", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    navigateSearch(forward: true)
                }

            if !searchText.isEmpty {
                Text("\(searchMatches.isEmpty ? 0 : searchMatchIndex + 1)/\(searchMatches.count)")
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Button { navigateSearch(forward: false) } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .disabled(searchMatches.isEmpty)

                Button { navigateSearch(forward: true) } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(searchMatches.isEmpty)
            }

            Button {
                isSearching = false
                searchText = ""
                searchMatchIndex = 0
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, TheaSpacing.lg)
        .padding(.vertical, TheaSpacing.sm)
        .background(.bar)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .containerRelativeFrame(.vertical) { length, _ in length }
                } else {
                    LazyVStack(spacing: messageSpacing) {
                        // When streaming, hide the last assistant message to avoid duplicate display
                        let displayMessages = chatManager.isStreaming
                            ? messages.filter { msg in
                                // Skip the last assistant message (it's shown by StreamingMessageView)
                                if msg.messageRole == .assistant, msg.id == messages.last(where: { $0.messageRole == .assistant })?.id {
                                    return false
                                }
                                return true
                            }
                            : messages

                        ForEach(displayMessages) { message in
                            let isCurrentMatch = !searchMatches.isEmpty
                                && searchMatchIndex < searchMatches.count
                                && searchMatches[searchMatchIndex].id == message.id
                            let isAnyMatch = isSearching && !searchText.isEmpty
                                && message.content.textValue.localizedCaseInsensitiveContains(searchText)

                            MessageBubble(message: message)
                                .id(message.id)
                                .overlay(
                                    RoundedRectangle(cornerRadius: TheaRadius.md)
                                        .stroke(isCurrentMatch ? Color.accentColor : .clear, lineWidth: 2)
                                )
                                .opacity(isSearching && !searchText.isEmpty && !isAnyMatch ? 0.4 : 1.0)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                ))
                        }

                        // Show streaming response with indicator
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
            .onChange(of: searchMatchIndex) { _, newIndex in
                if !searchMatches.isEmpty, newIndex < searchMatches.count {
                    withAnimation(TheaAnimation.smooth) {
                        proxy.scrollTo(searchMatches[newIndex].id, anchor: .center)
                    }
                }
            }
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
        ChatInputView(
            text: $messageText,
            isStreaming: chatManager.isStreaming,
            onSend: {
                if chatManager.isStreaming {
                    chatManager.cancelStreaming()
                } else {
                    sendMessage()
                }
            },
            onVoiceToggle: {
                isListeningForVoice.toggle()
                handleVoiceInput()
            },
            isListening: isListeningForVoice
        )
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

    private func navigateSearch(forward: Bool) {
        guard !searchMatches.isEmpty else { return }
        if forward {
            searchMatchIndex = (searchMatchIndex + 1) % searchMatches.count
        } else {
            searchMatchIndex = (searchMatchIndex - 1 + searchMatches.count) % searchMatches.count
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
