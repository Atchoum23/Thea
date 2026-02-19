//
//  ConversationListViewModel.swift
//  Thea
//
//  Created by Claude Code on 2026-02-01
//  ViewModel for managing conversation list (sidebar)
//

import Foundation
import SwiftUI

/// ViewModel for managing the conversation list in the sidebar
@MainActor
@Observable
final class ConversationListViewModel {
    // MARK: - State

    /// Current search text for filtering conversations
    var searchText: String = ""

    /// Whether to show pinned conversations separately
    var showPinnedSection: Bool = true

    /// Currently selected conversation
    var selectedConversation: Conversation?

    /// Whether deletion confirmation is showing
    var showingDeleteConfirmation: Bool = false

    /// Conversation pending deletion
    var conversationToDelete: Conversation?

    // MARK: - Dependencies

    @ObservationIgnored private let chatManager: ChatManager

    // MARK: - Initialization

    init(chatManager: ChatManager = .shared) {
        self.chatManager = chatManager
    }

    // MARK: - Computed Properties

    /// All conversations from the chat manager
    var allConversations: [Conversation] {
        chatManager.conversations
    }

    /// Filtered conversations based on search text
    var filteredConversations: [Conversation] {
        guard !searchText.isEmpty else {
            return allConversations
        }
        let searchLower = searchText.lowercased()
        return allConversations.filter { conversation in
            conversation.title.lowercased().contains(searchLower) ||
            conversation.messages.contains { message in
                message.content.textValue.lowercased().contains(searchLower)
            }
        }
    }

    /// Pinned conversations (filtered)
    var pinnedConversations: [Conversation] {
        filteredConversations.filter(\.isPinned)
    }

    /// Unpinned/recent conversations (filtered)
    var recentConversations: [Conversation] {
        filteredConversations.filter { !$0.isPinned }
    }

    /// Conversations grouped by date
    var conversationsByDate: [(title: String, conversations: [Conversation])] {
        let unpinned = recentConversations
        let calendar = Calendar.current
        let now = Date()

        var today: [Conversation] = []
        var yesterday: [Conversation] = []
        var thisWeek: [Conversation] = []
        var thisMonth: [Conversation] = []
        var older: [Conversation] = []

        for conversation in unpinned {
            if calendar.isDateInToday(conversation.updatedAt) {
                today.append(conversation)
            } else if calendar.isDateInYesterday(conversation.updatedAt) {
                yesterday.append(conversation)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      conversation.updatedAt >= weekAgo {
                thisWeek.append(conversation)
            } else if let monthAgo = calendar.date(byAdding: .month, value: -1, to: now),
                      conversation.updatedAt >= monthAgo {
                thisMonth.append(conversation)
            } else {
                older.append(conversation)
            }
        }

        var groups: [(title: String, conversations: [Conversation])] = []
        if !today.isEmpty { groups.append(("Today", today)) }
        if !yesterday.isEmpty { groups.append(("Yesterday", yesterday)) }
        if !thisWeek.isEmpty { groups.append(("This Week", thisWeek)) }
        if !thisMonth.isEmpty { groups.append(("This Month", thisMonth)) }
        if !older.isEmpty { groups.append(("Older", older)) }

        return groups
    }

    // MARK: - Actions

    /// Create a new conversation and select it
    func createNewConversation() {
        let conversation = chatManager.createConversation()
        selectedConversation = conversation
        chatManager.selectConversation(conversation)
    }

    /// Select a conversation
    func selectConversation(_ conversation: Conversation) {
        selectedConversation = conversation
        chatManager.selectConversation(conversation)
    }

    /// Request deletion of a conversation (shows confirmation)
    func requestDelete(_ conversation: Conversation) {
        conversationToDelete = conversation
        showingDeleteConfirmation = true
    }

    /// Confirm deletion of pending conversation
    func confirmDelete() {
        guard let conversation = conversationToDelete else { return }
        chatManager.deleteConversation(conversation)

        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }

        conversationToDelete = nil
        showingDeleteConfirmation = false
    }

    /// Cancel deletion
    func cancelDelete() {
        conversationToDelete = nil
        showingDeleteConfirmation = false
    }

    /// Toggle pin status of a conversation
    func togglePin(_ conversation: Conversation) {
        chatManager.togglePin(conversation)
    }

    /// Update conversation title
    func updateTitle(_ conversation: Conversation, to title: String) {
        chatManager.updateConversationTitle(conversation, title: title)
    }

    /// Clear search text
    func clearSearch() {
        searchText = ""
    }
}
