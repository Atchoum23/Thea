import SwiftUI

// MARK: - Chat View

struct iOSChatView: View {
    let conversation: Conversation

    @State private var chatManager = ChatManager.shared
    @State private var voiceManager = VoiceActivationManager.shared

    @StateObject private var settingsManager = SettingsManager.shared
    @State private var messageText = ""
    @State private var isListeningForVoice = false
    @FocusState private var isInputFocused: Bool

    private var messageSpacing: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.xs
        case "spacious": TheaSpacing.xl
        default: TheaSpacing.md
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            iOSChatInput
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.title)
                        .font(.theaBody)
                        .fontWeight(.semibold)

                    if chatManager.isStreaming {
                        Text("Thinking...")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isListeningForVoice.toggle()
                    handleVoiceInput()
                } label: {
                    Image(systemName: isListeningForVoice ? "mic.fill" : "mic")
                        .foregroundStyle(isListeningForVoice ? .red : .theaPrimary)
                        .symbolEffect(.bounce, value: isListeningForVoice)
                }
                .accessibilityLabel(isListeningForVoice ? "Stop voice input" : "Start voice input")
            }
        }
        .onAppear {
            chatManager.selectConversation(conversation)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if conversation.messages.isEmpty && !chatManager.isStreaming {
                    WelcomeView { prompt in
                        messageText = prompt
                        sendMessage()
                    }
                } else {
                    LazyVStack(spacing: messageSpacing) {
                        let allMessages = conversation.messages.sorted { $0.timestamp < $1.timestamp }
                        let displayMessages = chatManager.isStreaming
                            ? allMessages.filter { msg in
                                if msg.messageRole == .assistant,
                                   msg.id == allMessages.last(where: { $0.messageRole == .assistant })?.id {
                                    return false
                                }
                                return true
                            }
                            : allMessages

                        ForEach(displayMessages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if chatManager.isStreaming {
                            StreamingMessageView(
                                streamingText: chatManager.streamingText,
                                status: chatManager.streamingText.isEmpty ? .thinking : .generating
                            )
                            .id("streaming")
                        }
                    }
                    .padding(.horizontal, TheaSpacing.lg)
                    .padding(.vertical, TheaSpacing.md)
                }
            }
            .onChange(of: conversation.messages.count) { _, _ in
                if let lastMessage = conversation.messages.last {
                    withAnimation(TheaAnimation.smooth) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatManager.streamingText) { _, _ in
                withAnimation(TheaAnimation.smooth) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - iOS Chat Input

    private var iOSChatInput: some View {
        HStack(spacing: TheaSpacing.md) {
            TextField("Message Thea...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1 ... 6)
                .focused($isInputFocused)
                .disabled(chatManager.isStreaming)
                .accessibilityIdentifier("chatMessageInput")
                .accessibilityLabel("Message input")
                .onSubmit {
                    if !messageText.isEmpty {
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
                        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isStreaming
                            ? Color.theaPrimaryDefault : .secondary
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatManager.isStreaming)
            .accessibilityLabel(chatManager.isStreaming ? "Stop generating" : "Send message")
        }
        .padding(.horizontal, TheaSpacing.lg)
        .padding(.vertical, TheaSpacing.md)
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isInputFocused = false

        Task {
            try? await chatManager.sendMessage(text, in: conversation)
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

// MARK: - New Conversation View

struct iOSNewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var chatManager = ChatManager.shared
    @State private var projectManager = ProjectManager.shared

    @State private var title = ""
    @State private var selectedProject: Project?
    @State private var showingProjectPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: TheaSpacing.xxl) {
                SuggestionChipGrid { item in
                    let conversation = chatManager.createConversation(title: item.text)
                    chatManager.selectConversation(conversation)
                    NotificationCenter.default.post(
                        name: Notification.Name.newConversation,
                        object: item.prompt
                    )
                    dismiss()
                }
                .padding(.horizontal, TheaSpacing.lg)

                Divider()

                Form {
                    Section("Or start with a title") {
                        TextField("Conversation title...", text: $title)
                    }

                    Section("Project (Optional)") {
                        Button {
                            showingProjectPicker = true
                        } label: {
                            HStack {
                                Text(selectedProject?.title ?? "None")
                                    .foregroundStyle(selectedProject == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createConversation() }
                        .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingProjectPicker) {
                ProjectPickerView(selectedProject: $selectedProject)
            }
        }
    }

    private func createConversation() {
        let conversation = chatManager.createConversation(
            title: title.isEmpty ? "New Conversation" : title
        )
        chatManager.selectConversation(conversation)
        dismiss()
    }
}

// MARK: - Project Picker

struct ProjectPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedProject: Project?
    @State private var projectManager = ProjectManager.shared

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedProject = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("None")
                        Spacer()
                        if selectedProject == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.theaPrimary)
                        }
                    }
                }

                ForEach(projectManager.projects) { project in
                    Button {
                        selectedProject = project
                        dismiss()
                    } label: {
                        HStack {
                            Text(project.title)
                            Spacer()
                            if selectedProject?.id == project.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.theaPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
