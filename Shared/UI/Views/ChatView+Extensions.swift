import SwiftUI

// MARK: - ChatView + Search

extension ChatView {
    #if os(macOS)
    var chatSearchBar: some View {
        HStack(spacing: TheaSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search messages…", text: $searchText)
                .textFieldStyle(.plain)
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
                .accessibilityLabel("Previous match")

                Button { navigateSearch(forward: true) } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(searchMatches.isEmpty)
                .accessibilityLabel("Next match")
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
            .accessibilityLabel("Close search")
        }
        .padding(.horizontal, TheaSpacing.lg)
        .padding(.vertical, TheaSpacing.sm)
        .background(.bar)
    }

    func navigateSearch(forward: Bool) {
        guard !searchMatches.isEmpty else { return }
        if forward {
            searchMatchIndex = (searchMatchIndex + 1) % searchMatches.count
        } else {
            searchMatchIndex = (searchMatchIndex - 1 + searchMatches.count) % searchMatches.count
        }
    }

    func isCurrentSearchMatch(_ message: Message) -> Bool {
        !searchMatches.isEmpty
            && searchMatchIndex < searchMatches.count
            && searchMatches[searchMatchIndex].id == message.id
    }

    func searchDimOpacity(for message: Message) -> Double {
        guard isSearching, !searchText.isEmpty else { return 1.0 }
        let isMatch = message.content.textValue.localizedCaseInsensitiveContains(searchText)
        return isMatch ? 1.0 : 0.4
    }
    #endif
}

// MARK: - ChatView + Actions

extension ChatView {
    func branchInfo(for message: Message) -> MessageBubble.BranchInfo? {
        let branches = chatManager.getBranches(for: message, in: conversation)
        guard branches.count > 1 else { return nil }

        let currentIdx = selectedBranches[message.parentMessageId ?? message.id] ?? 0
        let parentId = message.parentMessageId ?? message.id

        return MessageBubble.BranchInfo(
            currentIndex: currentIdx,
            totalCount: branches.count
        ) { newIndex in
            selectedBranches[parentId] = newIndex
        }
    }

    func handleMessageAction(_ action: MessageAction, message: Message) {
        switch action {
        case .copy:
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.content.textValue, forType: .string)
            #else
            UIPasteboard.general.string = message.content.textValue
            #endif

        case .edit:
            editingMessage = message

        case .regenerate:
            Task {
                do {
                    try await chatManager.editMessageAndBranch(
                        message, newContent: message.content.textValue, in: conversation
                    )
                } catch {
                    showingError = error
                }
            }

        case .deleteMessage:
            chatManager.deleteMessage(message, from: conversation)

        case .continueFromHere:
            Task {
                do {
                    try await chatManager.sendMessage("Continue", in: conversation)
                } catch {
                    showingError = error
                }
            }

        default:
            break
        }
    }

    func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(TheaAnimation.smooth) {
            if chatManager.isStreaming {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let lastMessage = messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    func setupProvider() async {
        let hasLocalModels = !ProviderRegistry.shared.getAvailableLocalModels().isEmpty

        if let apiKey = try? SecureStorage.shared.loadAPIKey(for: "openai") {
            selectedProvider = OpenAIProvider(apiKey: apiKey)
        } else if hasLocalModels {
            selectedProvider = ProviderRegistry.shared.getLocalProvider()
        } else {
            showingAPIKeySetup = true
        }
    }

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        // Parse @agent prefix — delegate to orchestrator instead of direct chat
        if text.hasPrefix("@agent "), SettingsManager.shared.agentDelegationEnabled {
            let taskDescription = String(text.dropFirst(7))
            Task {
                let session = await orchestrator.delegateTask(
                    description: taskDescription,
                    from: conversation.id
                )
                selectedAgentSession = session
            }
            return
        }

        Task {
            do {
                try await chatManager.sendMessage(text, in: conversation)
            } catch {
                showingError = error
                inputText = text
            }
        }
    }
}
