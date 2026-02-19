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

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - Tab Operations

    /// Opens a new tab with optional conversation
    func openNewTab(conversation: Conversation? = nil) {
        let tab: ConversationTab

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
            do { try context.save() } catch { tabLogger.error("Failed to save new conversation for tab: \(error.localizedDescription)") }

            tab = ConversationTab(
                conversation: newConversation,
                title: newConversation.title,
                isPinned: false
            )
        }

        openTabs.append(tab)
        selectedTab = tab.id
    }

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

    /// Closes all tabs
    func closeAllTabs() {
        openTabs.removeAll()
        selectedTab = nil
    }

    /// Closes all tabs except pinned ones
    func closeAllUnpinnedTabs() {
        openTabs.removeAll { !$0.isPinned }

        if let selected = selectedTab,
           !openTabs.contains(where: { $0.id == selected })
        {
            selectedTab = openTabs.first?.id
        }
    }

    /// Selects a tab
    func selectTab(_ tabID: UUID) {
        if openTabs.contains(where: { $0.id == tabID }) {
            selectedTab = tabID
        }
    }

    /// Selects the next tab
    func selectNextTab() {
        guard let currentID = selectedTab,
              let currentIndex = openTabs.firstIndex(where: { $0.id == currentID })
        else {
            return
        }

        let nextIndex = (currentIndex + 1) % openTabs.count
        selectedTab = openTabs[nextIndex].id
    }

    /// Selects the previous tab
    func selectPreviousTab() {
        guard let currentID = selectedTab,
              let currentIndex = openTabs.firstIndex(where: { $0.id == currentID })
        else {
            return
        }

        let previousIndex = (currentIndex - 1 + openTabs.count) % openTabs.count
        selectedTab = openTabs[previousIndex].id
    }

    // MARK: - Tab Modifications

    /// Pins or unpins a tab
    func togglePin(_ tabID: UUID) {
        if let index = openTabs.firstIndex(where: { $0.id == tabID }) {
            openTabs[index].isPinned.toggle()

            // Move pinned tabs to the front
            if openTabs[index].isPinned {
                let tab = openTabs.remove(at: index)
                let lastPinnedIndex = openTabs.lastIndex { $0.isPinned } ?? -1
                openTabs.insert(tab, at: lastPinnedIndex + 1)
            }
        }
    }

    /// Reorders tabs
    func reorderTabs(from source: IndexSet, to destination: Int) {
        openTabs.move(fromOffsets: source, toOffset: destination)
    }

    /// Updates tab title
    func updateTabTitle(_ tabID: UUID, title: String) {
        if let index = openTabs.firstIndex(where: { $0.id == tabID }) {
            openTabs[index].title = title
        }
    }

    // MARK: - Tab Queries

    /// Gets currently selected tab
    func getSelectedTab() -> ConversationTab? {
        guard let selectedID = selectedTab else { return nil }
        return openTabs.first { $0.id == selectedID }
    }

    /// Gets tab by ID
    func getTab(_ tabID: UUID) -> ConversationTab? {
        openTabs.first { $0.id == tabID }
    }

    /// Gets tab for conversation
    func getTab(forConversation conversationID: UUID) -> ConversationTab? {
        openTabs.first { $0.conversation.id == conversationID }
    }

    /// Gets all pinned tabs
    func getPinnedTabs() -> [ConversationTab] {
        openTabs.filter(\.isPinned)
    }

    /// Gets all unpinned tabs
    func getUnpinnedTabs() -> [ConversationTab] {
        openTabs.filter { !$0.isPinned }
    }

    // MARK: - Bulk Operations

    /// Duplicates a tab
    func duplicateTab(_ tabID: UUID) {
        guard let tab = openTabs.first(where: { $0.id == tabID }) else {
            return
        }

        // Create new conversation with same title
        guard let context = modelContext else { return }

        let newConversation = Conversation(
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

    /// Moves tab to a new window
    func moveTabToNewWindow(_ tabID: UUID) -> ConversationTab? {
        guard let index = openTabs.firstIndex(where: { $0.id == tabID }) else {
            return nil
        }

        let tab = openTabs.remove(at: index)

        // Select adjacent tab
        if selectedTab == tabID {
            if !openTabs.isEmpty {
                selectedTab = openTabs.first?.id
            } else {
                selectedTab = nil
            }
        }

        return tab
    }

    /// Adds an existing tab (from another window)
    func addTab(_ tab: ConversationTab) {
        openTabs.append(tab)
        selectedTab = tab.id
    }

    // MARK: - Tab State

    /// Gets tab count
    var tabCount: Int {
        openTabs.count
    }

    /// Checks if there are any tabs
    var hasOpenTabs: Bool {
        !openTabs.isEmpty
    }

    /// Checks if a tab is selected
    var hasSelectedTab: Bool {
        selectedTab != nil
    }
}

// MARK: - Conversation Tab

struct ConversationTab: Identifiable {
    let id: UUID
    let conversation: Conversation
    var title: String
    var isPinned: Bool

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
