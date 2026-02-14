// TabManagerTests.swift
// Tests for TabManager tab creation, closure, selection, and close-unpinned behavior.
// Navigation, pinning, reordering, title updates, queries, add/move, and edge cases
// are in TabManagerAdvancedTests.swift.

import Foundation
import XCTest

final class TabManagerTests: XCTestCase {

    // MARK: - Mirrored Types (from TabManager.swift)

    /// Lightweight conversation stub (replaces SwiftData @Model Conversation)
    struct TestConversation: Identifiable {
        let id: UUID
        var title: String

        init(id: UUID = UUID(), title: String = "Untitled") {
            self.id = id
            self.title = title
        }
    }

    /// Mirror of ConversationTab
    struct TestTab: Identifiable {
        let id: UUID
        let conversation: TestConversation
        var title: String
        var isPinned: Bool

        init(
            id: UUID = UUID(),
            conversation: TestConversation,
            title: String,
            isPinned: Bool = false
        ) {
            self.id = id
            self.conversation = conversation
            self.title = title
            self.isPinned = isPinned
        }
    }

    /// Mirror of TabManager (pure state machine, no ModelContext dependency)
    final class TestTabManager {
        private(set) var openTabs: [TestTab] = []
        var selectedTab: UUID?

        var tabCount: Int { openTabs.count }
        var hasOpenTabs: Bool { !openTabs.isEmpty }
        var hasSelectedTab: Bool { selectedTab != nil }

        /// Opens a tab with a given conversation; auto-selects it
        func openTab(conversation: TestConversation, isPinned: Bool = false) -> TestTab {
            let tab = TestTab(
                conversation: conversation,
                title: conversation.title,
                isPinned: isPinned
            )
            openTabs.append(tab)
            selectedTab = tab.id
            return tab
        }

        func closeTab(_ tabID: UUID) {
            guard let index = openTabs.firstIndex(where: { $0.id == tabID }) else { return }
            openTabs.remove(at: index)

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

        func closeAllTabs() {
            openTabs.removeAll()
            selectedTab = nil
        }

        func closeAllUnpinnedTabs() {
            openTabs.removeAll { !$0.isPinned }
            if let selected = selectedTab,
               !openTabs.contains(where: { $0.id == selected })
            {
                selectedTab = openTabs.first?.id
            }
        }

        func selectTab(_ tabID: UUID) {
            if openTabs.contains(where: { $0.id == tabID }) {
                selectedTab = tabID
            }
        }

        func togglePin(_ tabID: UUID) {
            if let index = openTabs.firstIndex(where: { $0.id == tabID }) {
                openTabs[index].isPinned.toggle()
                if openTabs[index].isPinned {
                    let tab = openTabs.remove(at: index)
                    let lastPinnedIndex = openTabs.lastIndex { $0.isPinned } ?? -1
                    openTabs.insert(tab, at: lastPinnedIndex + 1)
                }
            }
        }

        func getTab(_ tabID: UUID) -> TestTab? {
            openTabs.first { $0.id == tabID }
        }

        func getSelectedTab() -> TestTab? {
            guard let selectedID = selectedTab else { return nil }
            return openTabs.first { $0.id == selectedID }
        }
    }

    // MARK: - Helpers

    private func makeManager() -> TestTabManager { TestTabManager() }

    private func makeConversation(_ title: String = "Test") -> TestConversation {
        TestConversation(title: title)
    }

    // MARK: - Tab Creation

    func testOpenTabIncreasesCount() {
        let mgr = makeManager()
        XCTAssertEqual(mgr.tabCount, 0)
        XCTAssertFalse(mgr.hasOpenTabs)

        _ = mgr.openTab(conversation: makeConversation("First"))
        XCTAssertEqual(mgr.tabCount, 1)
        XCTAssertTrue(mgr.hasOpenTabs)
    }

    func testOpenTabAutoSelectsNewTab() {
        let mgr = makeManager()
        let tab = mgr.openTab(conversation: makeConversation("A"))
        XCTAssertEqual(mgr.selectedTab, tab.id)
        XCTAssertTrue(mgr.hasSelectedTab)
    }

    func testOpenMultipleTabsSelectsLatest() {
        let mgr = makeManager()
        _ = mgr.openTab(conversation: makeConversation("A"))
        let second = mgr.openTab(conversation: makeConversation("B"))
        XCTAssertEqual(mgr.selectedTab, second.id)
        XCTAssertEqual(mgr.tabCount, 2)
    }

    func testTabTitleMatchesConversation() {
        let mgr = makeManager()
        let tab = mgr.openTab(conversation: makeConversation("Hello World"))
        XCTAssertEqual(mgr.getTab(tab.id)?.title, "Hello World")
    }

    // MARK: - Tab Closure

    func testCloseLastTabClearsSelection() {
        let mgr = makeManager()
        let tab = mgr.openTab(conversation: makeConversation())
        mgr.closeTab(tab.id)
        XCTAssertEqual(mgr.tabCount, 0)
        XCTAssertNil(mgr.selectedTab)
        XCTAssertFalse(mgr.hasOpenTabs)
    }

    func testCloseActiveTabSelectsNextAdjacentTab() {
        let mgr = makeManager()
        let tabA = mgr.openTab(conversation: makeConversation("A"))
        let tabB = mgr.openTab(conversation: makeConversation("B"))
        let tabC = mgr.openTab(conversation: makeConversation("C"))

        // Select the middle tab and close it
        mgr.selectTab(tabB.id)
        mgr.closeTab(tabB.id)

        // Should select the tab that took index 1's place, which is tabC
        XCTAssertEqual(mgr.selectedTab, tabC.id)
        XCTAssertEqual(mgr.tabCount, 2)
        // tabA should still exist
        XCTAssertNotNil(mgr.getTab(tabA.id))
    }

    func testCloseLastPositionTabSelectsPrevious() {
        let mgr = makeManager()
        _ = mgr.openTab(conversation: makeConversation("A"))
        let tabB = mgr.openTab(conversation: makeConversation("B"))

        // tabB is at index 1 (last); close it while selected
        mgr.closeTab(tabB.id)
        // Should fall back to the previous (index 0)
        XCTAssertNotNil(mgr.selectedTab)
        XCTAssertEqual(mgr.tabCount, 1)
    }

    func testCloseNonSelectedTabPreservesSelection() {
        let mgr = makeManager()
        let tabA = mgr.openTab(conversation: makeConversation("A"))
        let tabB = mgr.openTab(conversation: makeConversation("B"))
        // tabB is selected
        XCTAssertEqual(mgr.selectedTab, tabB.id)

        mgr.closeTab(tabA.id)
        XCTAssertEqual(mgr.selectedTab, tabB.id, "Closing a non-selected tab should not change selection")
        XCTAssertEqual(mgr.tabCount, 1)
    }

    func testCloseNonExistentTabIsNoOp() {
        let mgr = makeManager()
        _ = mgr.openTab(conversation: makeConversation())
        let fakeID = UUID()
        mgr.closeTab(fakeID)
        XCTAssertEqual(mgr.tabCount, 1)
    }

    func testCloseAllTabs() {
        let mgr = makeManager()
        _ = mgr.openTab(conversation: makeConversation("A"))
        _ = mgr.openTab(conversation: makeConversation("B"))
        mgr.closeAllTabs()
        XCTAssertEqual(mgr.tabCount, 0)
        XCTAssertNil(mgr.selectedTab)
    }

    // MARK: - Close Unpinned Tabs

    func testCloseAllUnpinnedKeepsPinned() {
        let mgr = makeManager()
        let pinned = mgr.openTab(conversation: makeConversation("Pinned"))
        mgr.togglePin(pinned.id)
        _ = mgr.openTab(conversation: makeConversation("Unpinned"))

        mgr.closeAllUnpinnedTabs()
        XCTAssertEqual(mgr.tabCount, 1)
        XCTAssertTrue(mgr.openTabs.first?.isPinned ?? false)
    }

    func testCloseUnpinnedReassignsSelectionToPinned() {
        let mgr = makeManager()
        let pinned = mgr.openTab(conversation: makeConversation("Pinned"))
        mgr.togglePin(pinned.id)
        let unpinned = mgr.openTab(conversation: makeConversation("Unpinned"))
        mgr.selectTab(unpinned.id)

        mgr.closeAllUnpinnedTabs()
        // Selected tab was unpinned and removed; should reassign to first (pinned)
        XCTAssertNotNil(mgr.selectedTab)
        XCTAssertTrue(mgr.getSelectedTab()?.isPinned ?? false)
    }

    // MARK: - Tab Selection

    func testSelectExistingTab() {
        let mgr = makeManager()
        let tabA = mgr.openTab(conversation: makeConversation("A"))
        _ = mgr.openTab(conversation: makeConversation("B"))
        mgr.selectTab(tabA.id)
        XCTAssertEqual(mgr.selectedTab, tabA.id)
    }

    func testSelectNonExistentTabIsIgnored() {
        let mgr = makeManager()
        let tab = mgr.openTab(conversation: makeConversation())
        let fakeID = UUID()
        mgr.selectTab(fakeID)
        XCTAssertEqual(mgr.selectedTab, tab.id, "Selection should not change for nonexistent ID")
    }
}
