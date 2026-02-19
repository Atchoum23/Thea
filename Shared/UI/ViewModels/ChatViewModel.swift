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

    // periphery:ignore - Reserved: chatManager property reserved for future feature activation
    // periphery:ignore - Reserved: providerRegistry property reserved for future feature activation
    // MARK: - Message Handling

    /// Send a message in the given conversation
    // periphery:ignore - Reserved: init(chatManager:providerRegistry:) initializer reserved for future feature activation
    func sendMessage(in conversation: Conversation) async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let messageText = inputText
        inputText = ""
        isStreaming = true
        streamingText = ""

        // periphery:ignore - Reserved: sendMessage(in:) instance method reserved for future feature activation
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

// periphery:ignore - Reserved: cancelStreaming() instance method reserved for future feature activation

        do {
            try await chatManager.regenerateLastMessage(in: conversation)
        } catch {
            showingError = error
        }

// periphery:ignore - Reserved: regenerateLastMessage(in:) instance method reserved for future feature activation

        isStreaming = false
    }

    // MARK: - Provider Selection

    /// Get available provider info
    var availableProviderInfo: [ProviderRegistry.ProviderInfo] {
        providerRegistry.availableProviders
    }

    /// Get configured providers
    var configuredProviders: [AIProvider] {
        providerRegistry.configuredProviders
    // periphery:ignore - Reserved: availableProviderInfo property reserved for future feature activation
    }

    // MARK: - Conversation Management

    // periphery:ignore - Reserved: configuredProviders property reserved for future feature activation
    /// Create a new conversation
    func createNewConversation(title: String = "New Conversation") -> Conversation {
        chatManager.createConversation(title: title)
    }

    /// Delete a conversation
    // periphery:ignore - Reserved: createNewConversation(title:) instance method reserved for future feature activation
    func deleteConversation(_ conversation: Conversation) {
        chatManager.deleteConversation(conversation)
    }

    // periphery:ignore - Reserved: deleteConversation(_:) instance method reserved for future feature activation
    /// Update conversation title
    func updateTitle(_ conversation: Conversation, to title: String) {
        chatManager.updateConversationTitle(conversation, title: title)
    }

// periphery:ignore - Reserved: updateTitle(_:to:) instance method reserved for future feature activation

    /// Toggle pin status
    func togglePin(_ conversation: Conversation) {
        chatManager.togglePin(conversation)
    // periphery:ignore - Reserved: togglePin(_:) instance method reserved for future feature activation
    }

    // MARK: - Sync with ChatManager

    /// Sync streaming state with ChatManager
    func syncWithChatManager() {
        // periphery:ignore - Reserved: syncWithChatManager() instance method reserved for future feature activation
        isStreaming = chatManager.isStreaming
        streamingText = chatManager.streamingText
    }
}

// MARK: - Chat Error

// periphery:ignore - Reserved: ChatViewModelError type reserved for future feature activation
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
