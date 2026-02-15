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

        case let .retryWithModel(modelId):
            Task {
                do {
                    // Find the user message that preceded this assistant response
                    let sorted = conversation.messages.sorted { $0.orderIndex < $1.orderIndex }
                    if let idx = sorted.firstIndex(where: { $0.id == message.id }),
                       idx > 0,
                       sorted[idx - 1].messageRole == .user
                    {
                        let userText = sorted[idx - 1].content.textValue
                        // Get provider for the specified model
                        if let provider = ProviderRegistry.shared.getProvider(for: modelId) {
                            _ = try await chatManager.compareModels(
                                userText,
                                model1: message.model ?? modelId, provider1: provider,
                                model2: modelId, provider2: provider,
                                in: conversation
                            )
                        }
                    }
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

        // Comparison mode: send to two providers simultaneously
        if isComparisonMode {
            Task {
                do {
                    let (provider1, model1, _) = try await chatManager.selectProviderAndModel(for: text)
                    // Pick a second, different provider
                    let configured = ProviderRegistry.shared.configuredProviders
                    let provider2: any AIProvider
                    let model2: String
                    if let alt = configured.first(where: { $0.metadata.name != provider1.metadata.name }) {
                        provider2 = alt
                        let altModels = try await alt.listModels()
                        model2 = altModels.first?.id ?? model1
                    } else {
                        // Same provider, different model
                        provider2 = provider1
                        let models = try await provider1.listModels()
                        model2 = models.first(where: { $0.id != model1 })?.id ?? model1
                    }
                    let results = try await chatManager.compareModels(
                        text,
                        model1: model1, provider1: provider1,
                        model2: model2, provider2: provider2,
                        in: conversation
                    )
                    comparisonResults = results
                } catch {
                    showingError = error
                    inputText = text
                }
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
