//
//  ChatViewModel.swift
//  Thea
//
//  Created by Claude Code on 2026-02-01
//  ViewModel for chat interactions - manages streaming state and message flow
//

import Foundation
import SwiftUI

/// ViewModel for managing chat interactions
/// Separates business logic from ChatView for better testability
@MainActor
@Observable
final class ChatViewModel {
    // MARK: - State

    /// Current input text from the user
    var inputText: String = ""

    /// Whether a message is currently being streamed
    private(set) var isStreaming: Bool = false

    /// The text being streamed from the AI response
    private(set) var streamingText: String = ""

    /// Current error to display
    var showingError: Error?

    /// Whether to show the provider selector
    var showingProviderSelector: Bool = false

    // MARK: - Dependencies

    @ObservationIgnored private let chatManager: ChatManager
    @ObservationIgnored private let providerRegistry: ProviderRegistry

    // MARK: - Initialization

    init(
        chatManager: ChatManager = .shared,
        providerRegistry: ProviderRegistry = .shared
    ) {
        self.chatManager = chatManager
        self.providerRegistry = providerRegistry
    }

    // MARK: - Message Handling

    /// Send a message in the given conversation
    func sendMessage(in conversation: Conversation) async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let messageText = inputText
        inputText = ""
        isStreaming = true
        streamingText = ""

        do {
            try await chatManager.sendMessage(messageText, in: conversation)
        } catch {
            showingError = error
        }

        isStreaming = false
        streamingText = ""
    }

    /// Cancel the current streaming operation
    func cancelStreaming() {
        chatManager.cancelStreaming()
        isStreaming = false
        streamingText = ""
    }

    /// Regenerate the last assistant message
    func regenerateLastMessage(in conversation: Conversation) async {
        isStreaming = true

        do {
            try await chatManager.regenerateLastMessage(in: conversation)
        } catch {
            showingError = error
        }

        isStreaming = false
    }

    // MARK: - Provider Selection

    /// Get available providers
    var availableProviderInfo: [any AIProvider] {
        providerRegistry.availableProviders
    }

    /// Get configured providers
    var configuredProviders: [any AIProvider] {
        providerRegistry.configuredProviders
    }

    // MARK: - Conversation Management

    /// Create a new conversation
    func createNewConversation(title: String = "New Conversation") -> Conversation {
        chatManager.createConversation(title: title)
    }

    /// Delete a conversation
    func deleteConversation(_ conversation: Conversation) {
        chatManager.deleteConversation(conversation)
    }

    /// Update conversation title
    func updateTitle(_ conversation: Conversation, to title: String) {
        chatManager.updateConversationTitle(conversation, title: title)
    }

    /// Toggle pin status
    func togglePin(_ conversation: Conversation) {
        chatManager.togglePin(conversation)
    }

    // MARK: - Sync with ChatManager

    /// Sync streaming state with ChatManager
    func syncWithChatManager() {
        isStreaming = chatManager.isStreaming
        streamingText = chatManager.streamingText
    }
}

// MARK: - Chat Error

enum ChatViewModelError: LocalizedError {
    case noProviderSelected
    case noModelSelected
    case emptyMessage

    var errorDescription: String? {
        switch self {
        case .noProviderSelected:
            return "No AI provider selected"
        case .noModelSelected:
            return "No model selected"
        case .emptyMessage:
            return "Message cannot be empty"
        }
    }
}
