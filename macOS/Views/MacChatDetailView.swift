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

    @State private var messageText = ""
    @State private var isListeningForVoice = false
    @FocusState private var isInputFocused: Bool

    // Filter messages for this conversation
    private var messages: [Message] {
        allMessages
            .filter { $0.conversationID == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }

    init(conversation: Conversation) {
        self.conversation = conversation
        _allMessages = Query(sort: \Message.timestamp)
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            chatInput
        }
        .navigationTitle(conversation.title)
        .onAppear {
            chatManager.selectConversation(conversation)
            isInputFocused = true
        }
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
                } else {
                    LazyVStack(spacing: TheaSpacing.lg) {
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
                            MessageBubble(message: message)
                                .id(message.id)
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
                    .padding(.vertical, TheaSpacing.lg)
                }
            }
            .scrollContentBackground(.hidden)
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
