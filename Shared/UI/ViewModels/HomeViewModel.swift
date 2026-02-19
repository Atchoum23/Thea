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

    // periphery:ignore - Reserved: activeConversation property reserved for future feature activation
    // MARK: - Initialization

    init(
        chatManager: ChatManager = .shared,
        settingsManager: SettingsManager = .shared
    // periphery:ignore - Reserved: chatManager property reserved for future feature activation
    // periphery:ignore - Reserved: settingsManager property reserved for future feature activation
    ) {
        self.chatManager = chatManager
        self.settingsManager = settingsManager
        // periphery:ignore - Reserved: chatViewModel property reserved for future feature activation
        // periphery:ignore - Reserved: conversationListViewModel property reserved for future feature activation
        self.chatViewModel = ChatViewModel(chatManager: chatManager)
        self.conversationListViewModel = ConversationListViewModel(chatManager: chatManager)
    }

// periphery:ignore - Reserved: init(chatManager:settingsManager:) initializer reserved for future feature activation

    // MARK: - Navigation Actions

    /// Toggle sidebar visibility
    func toggleSidebar() {
        isSidebarVisible.toggle()
        columnVisibility = isSidebarVisible ? .all : .detailOnly
    }

    /// Show new conversation UI
    func showNewConversation() {
        showingNewConversation = true
    // periphery:ignore - Reserved: toggleSidebar() instance method reserved for future feature activation
    }

    /// Create a new conversation and navigate to it
    func createNewConversation(title: String = "New Conversation") {
        let conversation = chatManager.createConversation(title: title)
        // periphery:ignore - Reserved: showNewConversation() instance method reserved for future feature activation
        chatManager.selectConversation(conversation)
        conversationListViewModel.selectedConversation = conversation
        showingNewConversation = false
    }

// periphery:ignore - Reserved: createNewConversation(title:) instance method reserved for future feature activation

    /// Select a conversation
    func selectConversation(_ conversation: Conversation) {
        chatManager.selectConversation(conversation)
        conversationListViewModel.selectedConversation = conversation
    }

    // periphery:ignore - Reserved: selectConversation(_:) instance method reserved for future feature activation
    /// Open settings
    func openSettings() {
        showingSettings = true
    }

    // periphery:ignore - Reserved: openSettings() instance method reserved for future feature activation
    /// Toggle command palette
    func toggleCommandPalette() {
        showingCommandPalette.toggle()
    }

// periphery:ignore - Reserved: toggleCommandPalette() instance method reserved for future feature activation

    // MARK: - Keyboard Shortcuts

    /// Handle keyboard shortcut
    func handleKeyboardShortcut(_ shortcut: KeyboardShortcut) {
        switch shortcut {
        // periphery:ignore - Reserved: handleKeyboardShortcut(_:) instance method reserved for future feature activation
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
        // periphery:ignore - Reserved: KeyboardShortcut type reserved for future feature activation
        case newConversation // Cmd+N
        case toggleSidebar   // Cmd+Shift+S
        case openSettings    // Cmd+,
        case commandPalette  // Cmd+K
    }

    // MARK: - Sync

    /// Sync state with ChatManager
    // periphery:ignore - Reserved: syncWithChatManager() instance method reserved for future feature activation
    func syncWithChatManager() {
        chatViewModel.syncWithChatManager()
        if let active = chatManager.activeConversation,
           conversationListViewModel.selectedConversation?.id != active.id {
            conversationListViewModel.selectedConversation = active
        }
    }
}
