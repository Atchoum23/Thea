// WindowManager.swift
// Multi-window and tab management like Safari

import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

// MARK: - Window Manager

/// Manages multiple windows and tabs like Safari
@MainActor
public final class WindowManager: ObservableObject {
    public static let shared = WindowManager()

    private let logger = OSLog(subsystem: "com.thea.app", category: "WindowManager")

    // MARK: - Published State

    @Published public private(set) var windows: [TheaWindow] = []
    @Published public private(set) var activeWindowId: UUID?
    @Published public private(set) var recentlyClosedTabs: [TabInfo] = []

    // MARK: - Configuration

    private let maxRecentlyClosedTabs = 20

    // MARK: - Initialization

    private init() {
        // Create initial window
        createWindow()
    }

    // MARK: - Window Management

    /// Create a new window
    @discardableResult
    public func createWindow(with conversation: String? = nil) -> TheaWindow {
        let window = TheaWindow()

        if let conversationId = conversation {
            window.addTab(TheaTab(conversationId: conversationId))
        } else {
            window.addTab(TheaTab()) // Empty new tab
        }

        windows.append(window)
        activeWindowId = window.id

        #if os(macOS)
        openNSWindow(for: window)
        #endif

        return window
    }

    /// Close a window
    public func closeWindow(_ windowId: UUID) {
        guard let index = windows.firstIndex(where: { $0.id == windowId }) else { return }

        let window = windows[index]

        // Save tabs to recently closed
        for tab in window.tabs {
            recentlyClosedTabs.insert(TabInfo(from: tab), at: 0)
        }

        // Trim recently closed
        if recentlyClosedTabs.count > maxRecentlyClosedTabs {
            recentlyClosedTabs = Array(recentlyClosedTabs.prefix(maxRecentlyClosedTabs))
        }

        windows.remove(at: index)

        // Update active window
        if activeWindowId == windowId {
            activeWindowId = windows.last?.id
        }

        // Create new window if all closed
        if windows.isEmpty {
            createWindow()
        }
    }

    /// Get active window
    public var activeWindow: TheaWindow? {
        windows.first { $0.id == activeWindowId }
    }

    /// Set active window
    public func setActiveWindow(_ windowId: UUID) {
        guard windows.contains(where: { $0.id == windowId }) else { return }
        activeWindowId = windowId

        #if os(macOS)
        bringWindowToFront(windowId)
        #endif
    }

    // MARK: - Tab Management

    /// Create a new tab in the active window
    public func newTab(in windowId: UUID? = nil, conversation: String? = nil) {
        let targetWindowId = windowId ?? activeWindowId

        guard let window = windows.first(where: { $0.id == targetWindowId }) else {
            // Create new window if none exists
            createWindow(with: conversation)
            return
        }

        let tab = TheaTab(conversationId: conversation)
        window.addTab(tab)
    }

    /// Close a tab
    public func closeTab(_ tabId: UUID, in windowId: UUID) {
        guard let window = windows.first(where: { $0.id == windowId }) else { return }

        if let tab = window.tabs.first(where: { $0.id == tabId }) {
            recentlyClosedTabs.insert(TabInfo(from: tab), at: 0)

            // Trim
            if recentlyClosedTabs.count > maxRecentlyClosedTabs {
                recentlyClosedTabs = Array(recentlyClosedTabs.prefix(maxRecentlyClosedTabs))
            }
        }

        window.closeTab(tabId)

        // Close window if no tabs
        if window.tabs.isEmpty {
            closeWindow(windowId)
        }
    }

    /// Reopen last closed tab
    public func reopenLastClosedTab() {
        guard let tabInfo = recentlyClosedTabs.first else { return }
        recentlyClosedTabs.removeFirst()

        newTab(conversation: tabInfo.conversationId)
    }

    /// Move tab to new window
    public func moveTabToNewWindow(_ tabId: UUID, from windowId: UUID) {
        guard let window = windows.first(where: { $0.id == windowId }),
              let tab = window.tabs.first(where: { $0.id == tabId }) else { return }

        window.closeTab(tabId)

        let newWindow = createWindow()
        newWindow.tabs.removeAll() // Remove default tab
        newWindow.addTab(tab)
    }

    /// Move tab to another window
    public func moveTab(_ tabId: UUID, from sourceWindowId: UUID, to targetWindowId: UUID) {
        guard let sourceWindow = windows.first(where: { $0.id == sourceWindowId }),
              let targetWindow = windows.first(where: { $0.id == targetWindowId }),
              let tab = sourceWindow.tabs.first(where: { $0.id == tabId }) else { return }

        sourceWindow.closeTab(tabId)
        targetWindow.addTab(tab)
    }

    /// Merge all windows into one
    public func mergeAllWindows() {
        guard windows.count > 1 else { return }

        let targetWindow = windows[0]

        for window in windows.dropFirst() {
            for tab in window.tabs {
                targetWindow.addTab(tab)
            }
        }

        // Close other windows
        let windowsToClose = windows.dropFirst().map { $0.id }
        for windowId in windowsToClose {
            if let index = windows.firstIndex(where: { $0.id == windowId }) {
                windows.remove(at: index)
            }
        }

        activeWindowId = targetWindow.id
    }

    // MARK: - macOS Window Integration

    #if os(macOS)
    private var nsWindows: [UUID: NSWindow] = [:]

    private func openNSWindow(for window: TheaWindow) {
        let contentView = WindowContentView(window: window)

        let nsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        nsWindow.contentView = NSHostingView(rootView: contentView)
        nsWindow.title = "Thea"
        nsWindow.titlebarAppearsTransparent = true
        nsWindow.toolbarStyle = .unified
        nsWindow.center()

        // Setup toolbar with tabs
        let toolbar = NSToolbar(identifier: "TheaToolbar-\(window.id)")
        toolbar.delegate = ToolbarDelegate.shared
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = true
        nsWindow.toolbar = toolbar

        // Window delegate
        let delegate = WindowDelegate(windowId: window.id)
        nsWindow.delegate = delegate

        nsWindow.makeKeyAndOrderFront(nil)
        nsWindows[window.id] = nsWindow
    }

    private func bringWindowToFront(_ windowId: UUID) {
        nsWindows[windowId]?.makeKeyAndOrderFront(nil)
    }

    // Toolbar Delegate
    class ToolbarDelegate: NSObject, NSToolbarDelegate {
        static let shared = ToolbarDelegate()

        func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
            switch itemIdentifier.rawValue {
            case "tabs":
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                // Tab bar would go here
                return item
            default:
                return nil
            }
        }

        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            return [.flexibleSpace, NSToolbarItem.Identifier("tabs"), .flexibleSpace]
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            return [.flexibleSpace, NSToolbarItem.Identifier("tabs")]
        }
    }

    // Window Delegate
    class WindowDelegate: NSObject, NSWindowDelegate {
        let windowId: UUID

        init(windowId: UUID) {
            self.windowId = windowId
        }

        func windowWillClose(_ notification: Notification) {
            Task { @MainActor in
                WindowManager.shared.closeWindow(windowId)
            }
        }

        func windowDidBecomeKey(_ notification: Notification) {
            Task { @MainActor in
                WindowManager.shared.activeWindowId = windowId
            }
        }
    }
    #endif
}

// MARK: - Window Model

/// Represents a Thea window
public class TheaWindow: ObservableObject, Identifiable {
    public let id = UUID()

    @Published public private(set) var tabs: [TheaTab] = []
    @Published public var activeTabId: UUID?

    public var activeTab: TheaTab? {
        tabs.first { $0.id == activeTabId }
    }

    public func addTab(_ tab: TheaTab) {
        tabs.append(tab)
        activeTabId = tab.id
    }

    public func closeTab(_ tabId: UUID) {
        tabs.removeAll { $0.id == tabId }
        if activeTabId == tabId {
            activeTabId = tabs.last?.id
        }
    }

    public func setActiveTab(_ tabId: UUID) {
        guard tabs.contains(where: { $0.id == tabId }) else { return }
        activeTabId = tabId
    }

    public func moveTab(from: Int, to: Int) {
        guard from < tabs.count, to < tabs.count else { return }
        let tab = tabs.remove(at: from)
        tabs.insert(tab, at: to)
    }
}

// MARK: - Tab Model

/// Represents a tab within a window
public class TheaTab: ObservableObject, Identifiable {
    public let id = UUID()

    @Published public var conversationId: String?
    @Published public var title: String = "New Tab"
    @Published public var isLoading: Bool = false
    @Published public var isPinned: Bool = false

    public let createdAt = Date()

    public init(conversationId: String? = nil) {
        self.conversationId = conversationId

        if conversationId != nil {
            self.title = "Conversation" // Would load actual title
        }
    }
}

// MARK: - Tab Info (for restoration)

public struct TabInfo: Codable {
    public let conversationId: String?
    public let title: String
    public let closedAt: Date

    init(from tab: TheaTab) {
        self.conversationId = tab.conversationId
        self.title = tab.title
        self.closedAt = Date()
    }
}

// MARK: - SwiftUI Views

/// Tab bar view
public struct TabBarView: View {
    @ObservedObject var window: TheaWindow
    @ObservedObject var windowManager = WindowManager.shared

    public init(window: TheaWindow) {
        self.window = window
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(window.tabs) { tab in
                    TabItemView(
                        tab: tab,
                        isActive: tab.id == window.activeTabId,
                        onSelect: { window.setActiveTab(tab.id) },
                        onClose: { windowManager.closeTab(tab.id, in: window.id) }
                    )
                }

                // New tab button
                Button(action: { windowManager.newTab(in: window.id) }) {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
        }
        .frame(height: 36)
        .background(.bar)
    }
}

/// Individual tab item
struct TabItemView: View {
    @ObservedObject var tab: TheaTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            if tab.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            } else if tab.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
            }

            Text(tab.title)
                .lineLimit(1)
                .frame(maxWidth: 150)

            if isHovering && !tab.isPinned {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Pin Tab") {
                tab.isPinned.toggle()
            }

            Button("Duplicate Tab") {
                WindowManager.shared.newTab(conversation: tab.conversationId)
            }

            Divider()

            Button("Move to New Window") {
                WindowManager.shared.moveTabToNewWindow(tab.id, from: WindowManager.shared.activeWindowId!)
            }

            Divider()

            Button("Close Tab", role: .destructive, action: onClose)

            Button("Close Other Tabs") {
                // Close all tabs except this one
            }
        }
    }
}

/// Window content view
struct WindowContentView: View {
    @ObservedObject var window: TheaWindow
    @ObservedObject var windowManager = WindowManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBarView(window: window)

            Divider()

            // Content
            if let activeTab = window.activeTab {
                TabContentView(tab: activeTab)
            } else {
                EmptyTabView()
            }
        }
    }
}

/// Content for a tab
struct TabContentView: View {
    @ObservedObject var tab: TheaTab

    var body: some View {
        if let conversationId = tab.conversationId {
            // Show conversation
            Text("Conversation: \(conversationId)")
        } else {
            // New tab page
            NewTabPageView()
        }
    }
}

/// New tab page
struct NewTabPageView: View {
    @ObservedObject var windowManager = WindowManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("New Conversation")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Recent conversations would go here

            // Recently closed tabs
            if !windowManager.recentlyClosedTabs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recently Closed")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ForEach(windowManager.recentlyClosedTabs.prefix(5), id: \.closedAt) { tabInfo in
                        Button(action: {
                            windowManager.newTab(conversation: tabInfo.conversationId)
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text(tabInfo.title)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}

/// Empty tab placeholder
struct EmptyTabView: View {
    var body: some View {
        ContentUnavailableView(
            "No Tab Selected",
            systemImage: "square.dashed",
            description: Text("Create a new tab to get started")
        )
    }
}

// MARK: - Commands (macOS)

#if os(macOS)
public struct TheaCommands: Commands {
    @ObservedObject var windowManager = WindowManager.shared

    public init() {}

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                windowManager.createWindow()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("New Tab") {
                windowManager.newTab()
            }
            .keyboardShortcut("t", modifiers: .command)

            Divider()

            Button("Reopen Closed Tab") {
                windowManager.reopenLastClosedTab()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(windowManager.recentlyClosedTabs.isEmpty)
        }

        CommandGroup(after: .newItem) {
            Divider()

            Button("Close Tab") {
                if let windowId = windowManager.activeWindowId,
                   let tabId = windowManager.activeWindow?.activeTabId {
                    windowManager.closeTab(tabId, in: windowId)
                }
            }
            .keyboardShortcut("w", modifiers: .command)

            Button("Close Window") {
                if let windowId = windowManager.activeWindowId {
                    windowManager.closeWindow(windowId)
                }
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])
        }

        CommandMenu("Window") {
            Button("Merge All Windows") {
                windowManager.mergeAllWindows()
            }
            .disabled(windowManager.windows.count < 2)

            Divider()

            ForEach(windowManager.windows) { window in
                Button(window.activeTab?.title ?? "Window") {
                    windowManager.setActiveWindow(window.id)
                }
            }
        }
    }
}
#endif
