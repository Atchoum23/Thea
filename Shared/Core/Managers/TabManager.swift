import Foundation
import Observation
import os.log
@preconcurrency import SwiftData

private let tabLogger = Logger(subsystem: "ai.thea.app", category: "TabManager")

// MARK: - Tab Manager

// Manages tabs within windows for multi-tab conversation support

@MainActor
@Observable
final class TabManager {
    private(set) var openTabs: [ConversationTab] = []
    var selectedTab: UUID?

    private var modelContext: ModelContext?

    init() {}

    // periphery:ignore - Reserved: setModelContext(_:) instance method — reserved for future feature activation
    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - Tab Operations

    // periphery:ignore - Reserved: openNewTab(conversation:) instance method — reserved for future feature activation
    /// Opens a new tab with optional conversation
    func openNewTab(conversation: Conversation? = nil) {
        let tab: ConversationTab

        // periphery:ignore - Reserved: tabLogger global var reserved for future feature activation
        if let conversation {
            tab = ConversationTab(
                conversation: conversation,
                title: conversation.title,
                isPinned: false
            )
        } else {
            // Create new conversation
            guard let context = modelContext else { return }

            let newConversation = Conversation(
                title: "New Conversation",
                createdAt: Date()
            )
            context.insert(newConversation)
            // periphery:ignore - Reserved: setModelContext(_:) instance method reserved for future feature activation
            do { try context.save() } catch { tabLogger.error("Failed to save new conversation for tab: \(error.localizedDescription)") }

            tab = ConversationTab(
                conversation: newConversation,
                title: newConversation.title,
                isPinned: false
            // periphery:ignore - Reserved: openNewTab(conversation:) instance method reserved for future feature activation
            )
        }

        openTabs.append(tab)
        selectedTab = tab.id
    }

    // periphery:ignore - Reserved: closeTab(_:) instance method — reserved for future feature activation
    /// Closes a tab
    func closeTab(_ tabID: UUID) {
        guard let index = openTabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }

        openTabs.remove(at: index)

        // Select adjacent tab if closing selected tab
        if selectedTab == tabID {
            if !openTabs.isEmpty {
                if index < openTabs.count {
                    selectedTab = openTabs[index].id
                } else if index > 0 {
                    selectedTab = openTabs[index - 1].id
                } else {
                    selectedTab = openTabs.first?.id
                }
            } else {
                selectedTab = nil
            }
        }
    }

    // periphery:ignore - Reserved: closeTab(_:) instance method reserved for future feature activation
    /// Closes all tabs
    func closeAllTabs() {
        openTabs.removeAll()
        selectedTab = nil
    }

    // periphery:ignore - Reserved: closeAllUnpinnedTabs() instance method — reserved for future feature activation
    /// Closes all tabs except pinned ones
    func closeAllUnpinnedTabs() {
        openTabs.removeAll { !$0.isPinned }

        if let selected = selectedTab,
           !openTabs.contains(where: { $0.id == selected })
        {
            selectedTab = openTabs.first?.id
        }
    }

    // periphery:ignore - Reserved: selectTab(_:) instance method — reserved for future feature activation
    /// Selects a tab
    func selectTab(_ tabID: UUID) {
        if openTabs.contains(where: { $0.id == tabID }) {
            selectedTab = tabID
        }
    }

// periphery:ignore - Reserved: closeAllTabs() instance method reserved for future feature activation

    /// Selects the next tab
    func selectNextTab() {
        guard let currentID = selectedTab,
              let currentIndex = openTabs.firstIndex(where: { $0.id == currentID })
        // periphery:ignore - Reserved: closeAllUnpinnedTabs() instance method reserved for future feature activation
        else {
            return
        }

        let nextIndex = (currentIndex + 1) % openTabs.count
        selectedTab = openTabs[nextIndex].id
    }

    // periphery:ignore - Reserved: selectPreviousTab() instance method — reserved for future feature activation
    /// Selects the previous tab
    func selectPreviousTab() {
        // periphery:ignore - Reserved: selectTab(_:) instance method reserved for future feature activation
        guard let currentID = selectedTab,
              let currentIndex = openTabs.firstIndex(where: { $0.id == currentID })
        else {
            return
        }

        // periphery:ignore - Reserved: selectNextTab() instance method reserved for future feature activation
        let previousIndex = (currentIndex - 1 + openTabs.count) % openTabs.count
        selectedTab = openTabs[previousIndex].id
    }

    // MARK: - Tab Modifications

    // periphery:ignore - Reserved: togglePin(_:) instance method — reserved for future feature activation
    /// Pins or unpins a tab
    func togglePin(_ tabID: UUID) {
        if let index = openTabs.firstIndex(where: { $0.id == tabID }) {
            openTabs[index].isPinned.toggle()

            // periphery:ignore - Reserved: selectPreviousTab() instance method reserved for future feature activation
            // Move pinned tabs to the front
            if openTabs[index].isPinned {
                let tab = openTabs.remove(at: index)
                let lastPinnedIndex = openTabs.lastIndex { $0.isPinned } ?? -1
                openTabs.insert(tab, at: lastPinnedIndex + 1)
            }
        }
    }

    // periphery:ignore - Reserved: reorderTabs(from:to:) instance method — reserved for future feature activation
    /// Reorders tabs
    func reorderTabs(from source: IndexSet, to destination: Int) {
        openTabs.move(fromOffsets: source, toOffset: destination)
    }

// periphery:ignore - Reserved: togglePin(_:) instance method reserved for future feature activation

    /// Updates tab title
    func updateTabTitle(_ tabID: UUID, title: String) {
        if let index = openTabs.firstIndex(where: { $0.id == tabID }) {
            openTabs[index].title = title
        }
    }

    // MARK: - Tab Queries

    // periphery:ignore - Reserved: getSelectedTab() instance method — reserved for future feature activation
    /// Gets currently selected tab
    func getSelectedTab() -> ConversationTab? {
        guard let selectedID = selectedTab else { return nil }
        // periphery:ignore - Reserved: reorderTabs(from:to:) instance method reserved for future feature activation
        return openTabs.first { $0.id == selectedID }
    }

    // periphery:ignore - Reserved: updateTabTitle(_:title:) instance method reserved for future feature activation
    /// Gets tab by ID
    func getTab(_ tabID: UUID) -> ConversationTab? {
        openTabs.first { $0.id == tabID }
    }

    // periphery:ignore - Reserved: getTab(forConversation:) instance method — reserved for future feature activation
    /// Gets tab for conversation
    func getTab(forConversation conversationID: UUID) -> ConversationTab? {
        openTabs.first { $0.conversation.id == conversationID }
    }

// periphery:ignore - Reserved: getSelectedTab() instance method reserved for future feature activation

    /// Gets all pinned tabs
    func getPinnedTabs() -> [ConversationTab] {
        openTabs.filter(\.isPinned)
    }

// periphery:ignore - Reserved: getTab(_:) instance method reserved for future feature activation

    /// Gets all unpinned tabs
    func getUnpinnedTabs() -> [ConversationTab] {
        openTabs.filter { !$0.isPinned }
    // periphery:ignore - Reserved: getTab(forConversation:) instance method reserved for future feature activation
    }

    // MARK: - Bulk Operations

    // periphery:ignore - Reserved: getPinnedTabs() instance method reserved for future feature activation
    /// Duplicates a tab
    func duplicateTab(_ tabID: UUID) {
        guard let tab = openTabs.first(where: { $0.id == tabID }) else {
            return
        // periphery:ignore - Reserved: getUnpinnedTabs() instance method reserved for future feature activation
        }

        // Create new conversation with same title
        guard let context = modelContext else { return }

        let newConversation = Conversation(
            // periphery:ignore - Reserved: duplicateTab(_:) instance method reserved for future feature activation
            title: "\(tab.conversation.title) (Copy)",
            createdAt: Date()
        )
        context.insert(newConversation)
        do { try context.save() } catch { tabLogger.error("Failed to save duplicated tab conversation: \(error.localizedDescription)") }

        let newTab = ConversationTab(
            conversation: newConversation,
            title: newConversation.title,
            isPinned: false
        )

        // Insert after current tab
        if let index = openTabs.firstIndex(where: { $0.id == tabID }) {
            openTabs.insert(newTab, at: index + 1)
        } else {
            openTabs.append(newTab)
        }

        selectedTab = newTab.id
    }

    // periphery:ignore - Reserved: moveTabToNewWindow(_:) instance method — reserved for future feature activation
    /// Moves tab to a new window
    func moveTabToNewWindow(_ tabID: UUID) -> ConversationTab? {
        guard let index = openTabs.firstIndex(where: { $0.id == tabID }) else {
            return nil
        }

        let tab = openTabs.remove(at: index)

        // Select adjacent tab
        // periphery:ignore - Reserved: moveTabToNewWindow(_:) instance method reserved for future feature activation
        if selectedTab == tabID {
            if !openTabs.isEmpty {
                selectedTab = openTabs.first?.id
            } else {
                selectedTab = nil
            }
        }

        return tab
    }

    // periphery:ignore - Reserved: addTab(_:) instance method — reserved for future feature activation
    /// Adds an existing tab (from another window)
    func addTab(_ tab: ConversationTab) {
        openTabs.append(tab)
        selectedTab = tab.id
    }

    // MARK: - Tab State

    // periphery:ignore - Reserved: addTab(_:) instance method reserved for future feature activation
    /// Gets tab count
    var tabCount: Int {
        openTabs.count
    }

    // periphery:ignore - Reserved: hasOpenTabs property — reserved for future feature activation
    /// Checks if there are any tabs
    var hasOpenTabs: Bool {
        // periphery:ignore - Reserved: tabCount property reserved for future feature activation
        !openTabs.isEmpty
    }

    // periphery:ignore - Reserved: hasOpenTabs property reserved for future feature activation
    /// Checks if a tab is selected
    var hasSelectedTab: Bool {
        selectedTab != nil
    }
}

// periphery:ignore - Reserved: hasSelectedTab property reserved for future feature activation

// MARK: - Conversation Tab

struct ConversationTab: Identifiable {
    let id: UUID
    let conversation: Conversation
    var title: String
    var isPinned: Bool

// periphery:ignore - Reserved: conversation property reserved for future feature activation

// periphery:ignore - Reserved: title property reserved for future feature activation

// periphery:ignore - Reserved: isPinned property reserved for future feature activation

    // periphery:ignore - Reserved: init(id:conversation:title:isPinned:) initializer reserved for future feature activation
    init(
        id: UUID = UUID(),
        conversation: Conversation,
        title: String,
        isPinned: Bool = false
    ) {
        self.id = id
        self.conversation = conversation
        self.title = title
        self.isPinned = isPinned
    }
}
