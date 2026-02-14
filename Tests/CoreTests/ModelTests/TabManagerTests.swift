import Foundation
import XCTest

/// Standalone tests for TabManager state machine logic.
/// Mirrors ConversationTab and TabManager locally to avoid SwiftData/Observation imports.
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

        func selectNextTab() {
            guard let currentID = selectedTab,
                  let currentIndex = openTabs.firstIndex(where: { $0.id == currentID })
            else { return }
            let nextIndex = (currentIndex + 1) % openTabs.count
            selectedTab = openTabs[nextIndex].id
        }

        func selectPreviousTab() {
            guard let currentID = selectedTab,
                  let currentIndex = openTabs.firstIndex(where: { $0.id == currentID })
            else { return }
            let previousIndex = (currentIndex - 1 + openTabs.count) % openTabs.count
            selectedTab = openTabs[previousIndex].id
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

        func reorderTabs(from source: IndexSet, to destination: Int) {
            // Manual implementation of move(fromOffsets:toOffset:) to avoid SwiftUI dependency
            let items = source.map { openTabs[$0] }
            // Remove from high to low to preserve indices
            for index in source.sorted().reversed() {
                openTabs.remove(at: index)
            }
            // Adjust destination for removed items before it
            let adjustedDest = destination - source.filter { $0 < destination }.count
            let clampedDest = min(adjustedDest, openTabs.count)
            openTabs.insert(contentsOf: items, at: clampedDest)
        }

        func updateTabTitle(_ tabID: UUID, title: String) {
            if let index = openTabs.firstIndex(where: { $0.id == tabID }) {
                openTabs[index].title = title
            }
        }

        func getSelectedTab() -> TestTab? {
            guard let selectedID = selectedTab else { return nil }
            return openTabs.first { $0.id == selectedID }
        }

        func getTab(_ tabID: UUID) -> TestTab? {
            openTabs.first { $0.id == tabID }
        }

        func getTab(forConversation conversationID: UUID) -> TestTab? {
            openTabs.first { $0.conversation.id == conversationID }
        }

        func getPinnedTabs() -> [TestTab] {
            openTabs.filter(\.isPinned)
        }

        func getUnpinnedTabs() -> [TestTab] {
            openTabs.filter { !$0.isPinned }
        }

        func addTab(_ tab: TestTab) {
            openTabs.append(tab)
            selectedTab = tab.id
        }

        func moveTabToNewWindow(_ tabID: UUID) -> TestTab? {
            guard let index = openTabs.firstIndex(where: { $0.id == tabID }) else { return nil }
            let tab = openTabs.remove(at: index)
            if selectedTab == tabID {
                selectedTab = openTabs.isEmpty ? nil : openTabs.first?.id
            }
            return tab
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

    // MARK: - Navigation (Next / Previous)

    func testSelectNextTabWrapsAround() {
        let mgr = makeManager()
        let tabA = mgr.openTab(conversation: makeConversation("A"))
        let tabB = mgr.openTab(conversation: makeConversation("B"))
        let tabC = mgr.openTab(conversation: makeConversation("C"))

        mgr.selectTab(tabA.id)
        mgr.selectNextTab()
        XCTAssertEqual(mgr.selectedTab, tabB.id)

        mgr.selectNextTab()
        XCTAssertEqual(mgr.selectedTab, tabC.id)

        // Wrap around to first
        mgr.selectNextTab()
        XCTAssertEqual(mgr.selectedTab, tabA.id)
    }

    func testSelectPreviousTabWrapsAround() {
        let mgr = makeManager()
        let tabA = mgr.openTab(conversation: makeConversation("A"))
        _ = mgr.openTab(conversation: makeConversation("B"))
        let tabC = mgr.openTab(conversation: makeConversation("C"))

        mgr.selectTab(tabA.id)
        // Wrap backward from first to last
        mgr.selectPreviousTab()
        XCTAssertEqual(mgr.selectedTab, tabC.id)
    }

    func testNextAndPreviousNoOpWithNoSelection() {
        let mgr = makeManager()
        mgr.selectNextTab()
        mgr.selectPreviousTab()
        XCTAssertNil(mgr.selectedTab, "Navigation on empty manager should be no-op")
    }

    func testNextTabWithSingleTab() {
        let mgr = makeManager()
        let tab = mgr.openTab(conversation: makeConversation())
        mgr.selectNextTab()
        XCTAssertEqual(mgr.selectedTab, tab.id, "Next on single tab should stay on same tab")
    }

    // MARK: - Pinning

    func testTogglePinMovesTabToFront() {
        let mgr = makeManager()
        _ = mgr.openTab(conversation: makeConversation("A"))
        let tabB = mgr.openTab(conversation: makeConversation("B"))
        _ = mgr.openTab(conversation: makeConversation("C"))

        mgr.togglePin(tabB.id)
        XCTAssertTrue(mgr.getTab(tabB.id)?.isPinned ?? false)
        // Pinned tab should be at front (index 0)
        XCTAssertEqual(mgr.openTabs.first?.id, tabB.id)
    }

    func testUnpinDoesNotMove() {
        let mgr = makeManager()
        _ = mgr.openTab(conversation: makeConversation("A"))
        let tabB = mgr.openTab(conversation: makeConversation("B"))

        mgr.togglePin(tabB.id)  // pin
        mgr.togglePin(tabB.id)  // unpin
        XCTAssertFalse(mgr.getTab(tabB.id)?.isPinned ?? true)
    }

    func testMultiplePinnedTabsStayGrouped() {
        let mgr = makeManager()
        let tabA = mgr.openTab(conversation: makeConversation("A"))
        _ = mgr.openTab(conversation: makeConversation("B"))
        let tabC = mgr.openTab(conversation: makeConversation("C"))

        mgr.togglePin(tabA.id)
        mgr.togglePin(tabC.id)

        let pinnedTabs = mgr.getPinnedTabs()
        XCTAssertEqual(pinnedTabs.count, 2)
        // Both should be at the front of the array
        XCTAssertTrue(mgr.openTabs[0].isPinned)
        XCTAssertTrue(mgr.openTabs[1].isPinned)
        XCTAssertFalse(mgr.openTabs[2].isPinned)
    }

    func testGetPinnedAndUnpinned() {
        let mgr = makeManager()
        let tabA = mgr.openTab(conversation: makeConversation("A"))
        _ = mgr.openTab(conversation: makeConversation("B"))
        mgr.togglePin(tabA.id)

        XCTAssertEqual(mgr.getPinnedTabs().count, 1)
        XCTAssertEqual(mgr.getUnpinnedTabs().count, 1)
    }

    // MARK: - Reordering

    func testReorderTabs() {
        let mgr = makeManager()
        let tabA = mgr.openTab(conversation: makeConversation("A"))
        _ = mgr.openTab(conversation: makeConversation("B"))
        _ = mgr.openTab(conversation: makeConversation("C"))

        // Move first tab to the end
        mgr.reorderTabs(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(mgr.openTabs.last?.id, tabA.id)
    }

    // MARK: - Tab Title Update

    func testUpdateTabTitle() {
        let mgr = makeManager()
        let tab = mgr.openTab(conversation: makeConversation("Old Title"))
        mgr.updateTabTitle(tab.id, title: "New Title")
        XCTAssertEqual(mgr.getTab(tab.id)?.title, "New Title")
    }

    func testUpdateNonExistentTabTitleIsNoOp() {
        let mgr = makeManager()
        mgr.updateTabTitle(UUID(), title: "Ghost")
        XCTAssertEqual(mgr.tabCount, 0)
    }

    // MARK: - Tab Queries

    func testGetTabByConversationID() {
        let mgr = makeManager()
        let conv = makeConversation("Lookup")
        let tab = mgr.openTab(conversation: conv)
        let found = mgr.getTab(forConversation: conv.id)
        XCTAssertEqual(found?.id, tab.id)
    }

    func testGetTabByConversationIDReturnsNil() {
        let mgr = makeManager()
        _ = mgr.openTab(conversation: makeConversation())
        XCTAssertNil(mgr.getTab(forConversation: UUID()))
    }

    func testGetSelectedTabReturnsCorrectTab() {
        let mgr = makeManager()
        let tab = mgr.openTab(conversation: makeConversation("Selected"))
        XCTAssertEqual(mgr.getSelectedTab()?.id, tab.id)
    }

    func testGetSelectedTabReturnsNilWhenEmpty() {
        let mgr = makeManager()
        XCTAssertNil(mgr.getSelectedTab())
    }

    // MARK: - Add Tab / Move to Window

    func testAddExternalTab() {
        let mgr = makeManager()
        let externalTab = TestTab(conversation: makeConversation("External"), title: "External")
        mgr.addTab(externalTab)
        XCTAssertEqual(mgr.tabCount, 1)
        XCTAssertEqual(mgr.selectedTab, externalTab.id)
    }

    func testMoveTabToNewWindowRemovesTab() {
        let mgr = makeManager()
        let tabA = mgr.openTab(conversation: makeConversation("A"))
        _ = mgr.openTab(conversation: makeConversation("B"))

        mgr.selectTab(tabA.id)
        let moved = mgr.moveTabToNewWindow(tabA.id)
        XCTAssertNotNil(moved)
        XCTAssertEqual(moved?.id, tabA.id)
        XCTAssertEqual(mgr.tabCount, 1)
        // Selection should move to remaining tab
        XCTAssertNotNil(mgr.selectedTab)
    }

    func testMoveNonExistentTabReturnsNil() {
        let mgr = makeManager()
        XCTAssertNil(mgr.moveTabToNewWindow(UUID()))
    }

    func testMoveLastTabClearsSelection() {
        let mgr = makeManager()
        let tab = mgr.openTab(conversation: makeConversation())
        _ = mgr.moveTabToNewWindow(tab.id)
        XCTAssertNil(mgr.selectedTab)
        XCTAssertEqual(mgr.tabCount, 0)
    }

    // MARK: - Edge Cases

    func testEmptyManagerState() {
        let mgr = makeManager()
        XCTAssertEqual(mgr.tabCount, 0)
        XCTAssertFalse(mgr.hasOpenTabs)
        XCTAssertFalse(mgr.hasSelectedTab)
        XCTAssertNil(mgr.getSelectedTab())
    }

    func testTogglePinOnNonExistentTabIsNoOp() {
        let mgr = makeManager()
        mgr.togglePin(UUID())
        XCTAssertEqual(mgr.tabCount, 0)
    }

    func testRapidOpenCloseSequence() {
        let mgr = makeManager()
        var tabs: [TestTab] = []
        for i in 0..<10 {
            tabs.append(mgr.openTab(conversation: makeConversation("Tab \(i)")))
        }
        XCTAssertEqual(mgr.tabCount, 10)

        // Close odd-indexed tabs
        for i in stride(from: 1, to: 10, by: 2) {
            mgr.closeTab(tabs[i].id)
        }
        XCTAssertEqual(mgr.tabCount, 5)
        // All remaining tabs should be even-indexed originals
        for i in stride(from: 0, to: 10, by: 2) {
            XCTAssertNotNil(mgr.getTab(tabs[i].id))
        }
    }

    func testCloseAllUnpinnedOnFullyPinnedSet() {
        let mgr = makeManager()
        let tabA = mgr.openTab(conversation: makeConversation("A"))
        let tabB = mgr.openTab(conversation: makeConversation("B"))
        mgr.togglePin(tabA.id)
        mgr.togglePin(tabB.id)

        mgr.closeAllUnpinnedTabs()
        XCTAssertEqual(mgr.tabCount, 2, "All tabs are pinned; none should be removed")
    }

    func testCloseAllUnpinnedOnFullyUnpinnedSet() {
        let mgr = makeManager()
        _ = mgr.openTab(conversation: makeConversation("A"))
        _ = mgr.openTab(conversation: makeConversation("B"))

        mgr.closeAllUnpinnedTabs()
        XCTAssertEqual(mgr.tabCount, 0)
        XCTAssertNil(mgr.selectedTab)
    }
}
