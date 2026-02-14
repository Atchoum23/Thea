//
//  HomeViewModel.swift
//  Thea
//
//  Created by Claude Code on 2026-02-01
//  ViewModel for the main Home view
//

import Foundation
import SwiftUI

/// ViewModel for the main Home view
/// Coordinates between sidebar selection and chat content
@MainActor
@Observable
final class HomeViewModel {
    // MARK: - State

    /// Whether the sidebar is visible (macOS)
    var isSidebarVisible: Bool = true

    /// Current navigation column visibility
    var columnVisibility: NavigationSplitViewVisibility = .all

    /// Whether to show the new conversation sheet
    var showingNewConversation: Bool = false

    /// Whether to show settings
    var showingSettings: Bool = false

    /// Whether to show the command palette
    var showingCommandPalette: Bool = false

    /// Active conversation (synced with ChatManager)
    var activeConversation: Conversation? {
        chatManager.activeConversation
    }

    // MARK: - Dependencies

    @ObservationIgnored private let chatManager: ChatManager
    @ObservationIgnored private let settingsManager: SettingsManager

    // MARK: - Child ViewModels

    let chatViewModel: ChatViewModel
    let conversationListViewModel: ConversationListViewModel

    // MARK: - Initialization

    init(
        chatManager: ChatManager = .shared,
        settingsManager: SettingsManager = .shared
    ) {
        self.chatManager = chatManager
        self.settingsManager = settingsManager
        self.chatViewModel = ChatViewModel(chatManager: chatManager)
        self.conversationListViewModel = ConversationListViewModel(chatManager: chatManager)
    }

    // MARK: - Navigation Actions

    /// Toggle sidebar visibility
    func toggleSidebar() {
        isSidebarVisible.toggle()
        columnVisibility = isSidebarVisible ? .all : .detailOnly
    }

    /// Show new conversation UI
    func showNewConversation() {
        showingNewConversation = true
    }

    /// Create a new conversation and navigate to it
    func createNewConversation(title: String = "New Conversation") {
        let conversation = chatManager.createConversation(title: title)
        chatManager.selectConversation(conversation)
        conversationListViewModel.selectedConversation = conversation
        showingNewConversation = false
    }

    /// Select a conversation
    func selectConversation(_ conversation: Conversation) {
        chatManager.selectConversation(conversation)
        conversationListViewModel.selectedConversation = conversation
    }

    /// Open settings
    func openSettings() {
        showingSettings = true
    }

    /// Toggle command palette
    func toggleCommandPalette() {
        showingCommandPalette.toggle()
    }

    // MARK: - Keyboard Shortcuts

    /// Handle keyboard shortcut
    func handleKeyboardShortcut(_ shortcut: KeyboardShortcut) {
        switch shortcut {
        case .newConversation:
            createNewConversation()
        case .toggleSidebar:
            toggleSidebar()
        case .openSettings:
            openSettings()
        case .commandPalette:
            toggleCommandPalette()
        }
    }

    /// Available keyboard shortcuts
    enum KeyboardShortcut {
        case newConversation // Cmd+N
        case toggleSidebar   // Cmd+Shift+S
        case openSettings    // Cmd+,
        case commandPalette  // Cmd+K
    }

    // MARK: - Sync

    /// Sync state with ChatManager
    func syncWithChatManager() {
        chatViewModel.syncWithChatManager()
        if let active = chatManager.activeConversation,
           conversationListViewModel.selectedConversation?.id != active.id {
            conversationListViewModel.selectedConversation = active
        }
    }
}
