// QuickLauncher.swift
// Raycast-style quick launcher with command palette and AI integration

import Combine
import Foundation
import OSLog
#if canImport(AppKit)
    import AppKit
#endif
#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Quick Launcher

/// Raycast-style command palette with AI integration
@MainActor
public final class QuickLauncher: ObservableObject {
    public static let shared = QuickLauncher()

    private let logger = Logger(subsystem: "com.thea.app", category: "QuickLauncher")
    // periphery:ignore - Reserved: cancellables property reserved for future feature activation
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State

    @Published public private(set) var isVisible = false
    @Published public private(set) var searchQuery = ""
    @Published public private(set) var results: [LauncherResult] = []
    @Published public private(set) var selectedIndex = 0
    @Published public private(set) var isLoading = false
    @Published public private(set) var recentCommands: [LauncherCommand] = []
    @Published public private(set) var pinnedCommands: [LauncherCommand] = []

    // MARK: - Commands Registry

    private var registeredCommands: [LauncherCommand] = []
    private var extensions: [LauncherExtension] = []

    // MARK: - Initialization

    private init() {
        registerBuiltInCommands()
        loadRecentCommands()
        loadPinnedCommands()
    }

    // MARK: - Show/Hide

    /// Show the launcher
    public func show() {
        isVisible = true
        searchQuery = ""
        selectedIndex = 0
        results = getInitialResults()
        logger.info("Launcher shown")
    }

    /// Hide the launcher
    public func hide() {
        isVisible = false
        searchQuery = ""
        results = []
        logger.info("Launcher hidden")
    }

    /// Toggle visibility
    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Search

    /// Update search query and results
    public func search(_ query: String) async {
        searchQuery = query
        selectedIndex = 0

        if query.isEmpty {
            results = getInitialResults()
            return
        }

        isLoading = true

        // Search registered commands
        var matchingResults: [LauncherResult] = []

        // 1. Exact command matches
        let commandMatches = registeredCommands.filter { command in
            command.title.localizedCaseInsensitiveContains(query) ||
                command.keywords.contains { $0.localizedCaseInsensitiveContains(query) }
        }.map { LauncherResult.command($0) }
        matchingResults.append(contentsOf: commandMatches)

        // 2. Extension results
        for ext in extensions {
            if let extResults = await ext.search(query: query) {
                matchingResults.append(contentsOf: extResults)
            }
        }

        // 3. AI fallback - suggest asking AI
        if matchingResults.isEmpty || query.count > 10 {
            matchingResults.append(.aiSuggestion(query))
        }

        // 4. Quick calculations
        if let calcResult = evaluateExpression(query) {
            matchingResults.insert(.calculation(query, calcResult), at: 0)
        }

        results = matchingResults
        isLoading = false
    }

    // MARK: - Selection

    /// Move selection up
    public func selectPrevious() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    /// Move selection down
    public func selectNext() {
        if selectedIndex < results.count - 1 {
            selectedIndex += 1
        }
    }

    /// Execute selected result
    public func executeSelected() async {
        guard selectedIndex < results.count else { return }
        await execute(results[selectedIndex])
    }

    /// Execute a specific result
    public func execute(_ result: LauncherResult) async {
        hide()

        switch result {
        case let .command(command):
            await executeCommand(command)
            addToRecent(command)

        case let .file(url):
            openFile(url)

        case let .url(url):
            openURL(url)

        case let .aiSuggestion(query):
            await askAI(query)

        case let .calculation(_, value):
            copyToClipboard(value)

        case let .extension(extResult):
            await extResult.execute()
        }
    }

    // MARK: - Command Execution

    private func executeCommand(_ command: LauncherCommand) async {
        logger.info("Executing command: \(command.id)")

        switch command.action {
        case let .navigate(destination):
            // Navigate to destination in app
            NotificationCenter.default.post(
                name: .launcherNavigate,
                object: nil,
                userInfo: ["destination": destination]
            )

        case let .run(handler):
            await handler()

        case let .openURL(url):
            openURL(url)

        case let .shortcut(name):
            await runShortcut(name)

        case let .script(script):
            await runScript(script)

        case let .aiPrompt(prompt):
            await askAI(prompt)
        }
    }

    // MARK: - Built-in Commands

    private func registerBuiltInCommands() {
        registeredCommands = [
            // Conversations
            LauncherCommand(
                id: "new-conversation",
                title: "New Conversation",
                subtitle: "Start a new chat with Thea",
                icon: "plus.message",
                keywords: ["chat", "new", "create"],
                action: .navigate("conversation/new")
            ),
            LauncherCommand(
                id: "search-conversations",
                title: "Search Conversations",
                subtitle: "Find past conversations",
                icon: "magnifyingglass",
                keywords: ["find", "search", "history"],
                action: .navigate("search")
            ),

            // AI Actions
            LauncherCommand(
                id: "ask-ai",
                title: "Ask AI",
                subtitle: "Quick question to Thea",
                icon: "sparkles",
                keywords: ["ask", "question", "help"],
                action: .run {
                    // Show AI input
                    NotificationCenter.default.post(name: .launcherQuickAsk, object: nil)
                }
            ),
            LauncherCommand(
                id: "explain-clipboard",
                title: "Explain Clipboard",
                subtitle: "Have AI explain clipboard contents",
                icon: "doc.on.clipboard",
                keywords: ["explain", "clipboard", "paste"],
                action: .aiPrompt("Explain this: [CLIPBOARD]")
            ),
            LauncherCommand(
                id: "summarize-clipboard",
                title: "Summarize Clipboard",
                subtitle: "Summarize clipboard contents",
                icon: "text.justify.left",
                keywords: ["summarize", "summary", "tldr"],
                action: .aiPrompt("Summarize this concisely: [CLIPBOARD]")
            ),
            LauncherCommand(
                id: "translate-clipboard",
                title: "Translate Clipboard",
                subtitle: "Translate clipboard contents",
                icon: "globe",
                keywords: ["translate", "language"],
                action: .aiPrompt("Translate this to English: [CLIPBOARD]")
            ),

            // Artifacts
            LauncherCommand(
                id: "new-artifact",
                title: "New Code Artifact",
                subtitle: "Create a new code artifact",
                icon: "doc.text",
                keywords: ["code", "artifact", "create"],
                action: .navigate("artifact/new")
            ),
            LauncherCommand(
                id: "browse-artifacts",
                title: "Browse Artifacts",
                subtitle: "View all saved artifacts",
                icon: "folder",
                keywords: ["artifacts", "browse", "view"],
                action: .navigate("artifacts")
            ),

            // Agents
            LauncherCommand(
                id: "switch-agent",
                title: "Switch Agent",
                subtitle: "Change to a different AI agent",
                icon: "person.2",
                keywords: ["agent", "switch", "change"],
                action: .navigate("agents")
            ),
            LauncherCommand(
                id: "create-agent",
                title: "Create Agent",
                subtitle: "Build a new custom agent",
                icon: "person.badge.plus",
                keywords: ["agent", "create", "new", "build"],
                action: .navigate("agent/new")
            ),

            // Tools
            LauncherCommand(
                id: "available-tools",
                title: "Available Tools",
                subtitle: "View connected MCP tools",
                icon: "wrench.and.screwdriver",
                keywords: ["tools", "mcp", "integrations"],
                action: .navigate("tools")
            ),

            // Memory
            LauncherCommand(
                id: "view-memories",
                title: "View Memories",
                subtitle: "See what Thea remembers",
                icon: "brain",
                keywords: ["memory", "memories", "remember"],
                action: .navigate("memories")
            ),
            LauncherCommand(
                id: "add-memory",
                title: "Add Memory",
                subtitle: "Teach Thea something new",
                icon: "brain.head.profile",
                keywords: ["memory", "add", "remember", "teach"],
                action: .navigate("memory/new")
            ),

            // Settings
            LauncherCommand(
                id: "settings",
                title: "Settings",
                subtitle: "Configure Thea",
                icon: "gear",
                keywords: ["settings", "preferences", "config"],
                action: .navigate("settings")
            ),
            LauncherCommand(
                id: "keyboard-shortcuts",
                title: "Keyboard Shortcuts",
                subtitle: "View all keyboard shortcuts",
                icon: "keyboard",
                keywords: ["keyboard", "shortcuts", "hotkeys"],
                action: .navigate("settings/shortcuts")
            ),

            // Sync
            LauncherCommand(
                id: "sync-now",
                title: "Sync Now",
                subtitle: "Sync across all devices",
                icon: "arrow.triangle.2.circlepath",
                keywords: ["sync", "icloud", "refresh"],
                action: .run {
                    do {
                        try await CloudKitService.shared.syncAll()
                    } catch {
                        Logger(subsystem: "com.thea.app", category: "QuickLauncher").error("Sync failed: \(error.localizedDescription)")
                    }
                }
            ),

            // System
            LauncherCommand(
                id: "clear-cache",
                title: "Clear Cache",
                subtitle: "Free up storage space",
                icon: "trash",
                keywords: ["clear", "cache", "storage"],
                action: .run {
                    // Clear cache implementation
                }
            ),
            LauncherCommand(
                id: "check-updates",
                title: "Check for Updates",
                subtitle: "See if updates are available",
                icon: "arrow.down.circle",
                keywords: ["update", "version"],
                action: .navigate("settings/updates")
            )
        ]

        logger.info("Registered \(self.registeredCommands.count) built-in commands")
    }

    // MARK: - Extensions

    /// Register a launcher extension
    public func registerExtension(_ extension: LauncherExtension) {
        extensions.append(`extension`)
        logger.info("Registered extension: \(`extension`.name)")
    }

    // MARK: - Helpers

    private func getInitialResults() -> [LauncherResult] {
        // Show pinned commands first, then recent
        var results: [LauncherResult] = []

        results.append(contentsOf: pinnedCommands.map { .command($0) })
        results.append(contentsOf: recentCommands.prefix(5).map { .command($0) })

        // Deduplicate
        var seenIds = Set<String>()
        results = results.filter { result in
            if case let .command(cmd) = result {
                if seenIds.contains(cmd.id) { return false }
                seenIds.insert(cmd.id)
            }
            return true
        }

        return results
    }

    private func evaluateExpression(_ expression: String) -> String? {
        // Simple math evaluation
        let mathExpression = NSExpression(format: expression)
        if let result = mathExpression.expressionValue(with: nil, context: nil) {
            return "\(result)"
        }
        return nil
    }

    private func addToRecent(_ command: LauncherCommand) {
        recentCommands.removeAll { $0.id == command.id }
        recentCommands.insert(command, at: 0)
        if recentCommands.count > 20 {
            recentCommands.removeLast()
        }
        saveRecentCommands()
    }

    private func loadRecentCommands() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "launcher.recent") {
            do {
                let ids = try JSONDecoder().decode([String].self, from: data)
                recentCommands = ids.compactMap { id in
                    registeredCommands.first { $0.id == id }
                }
            } catch {
                logger.debug("Could not decode recent commands: \(error.localizedDescription)")
            }
        }
    }

    private func saveRecentCommands() {
        let ids = recentCommands.map(\.id)
        do {
            let data = try JSONEncoder().encode(ids)
            UserDefaults.standard.set(data, forKey: "launcher.recent")
        } catch {
            logger.error("Failed to save recent commands: \(error.localizedDescription)")
        }
    }

    private func loadPinnedCommands() {
        if let data = UserDefaults.standard.data(forKey: "launcher.pinned") {
            do {
                let ids = try JSONDecoder().decode([String].self, from: data)
                pinnedCommands = ids.compactMap { id in
                    registeredCommands.first { $0.id == id }
                }
            } catch {
                logger.debug("Could not decode pinned commands: \(error.localizedDescription)")
            }
        }
    }

    /// Pin a command
    public func pin(_ command: LauncherCommand) {
        guard !pinnedCommands.contains(where: { $0.id == command.id }) else { return }
        pinnedCommands.append(command)
        let ids = pinnedCommands.map(\.id)
        do {
            let data = try JSONEncoder().encode(ids)
            UserDefaults.standard.set(data, forKey: "launcher.pinned")
        } catch {
            logger.error("Failed to save pinned commands: \(error.localizedDescription)")
        }
    }

    /// Unpin a command
    public func unpin(_ command: LauncherCommand) {
        pinnedCommands.removeAll { $0.id == command.id }
        let ids = pinnedCommands.map(\.id)
        do {
            let data = try JSONEncoder().encode(ids)
            UserDefaults.standard.set(data, forKey: "launcher.pinned")
        } catch {
            logger.error("Failed to save pinned commands after unpin: \(error.localizedDescription)")
        }
    }

    // MARK: - Actions

    private func openFile(_ url: URL) {
        #if os(macOS)
            NSWorkspace.shared.open(url)
        #elseif os(iOS)
            // Handle file opening on iOS
        #endif
    }

    private func openURL(_ url: URL) {
        #if os(macOS)
            NSWorkspace.shared.open(url)
        #elseif os(iOS)
            Task { @MainActor in
                await UIApplication.shared.open(url)
            }
        #endif
    }

    private func askAI(_ query: String) async {
        var finalQuery = query

        // Replace [CLIPBOARD] placeholder
        if query.contains("[CLIPBOARD]") {
            #if os(macOS)
                if let clipboard = UniversalClipboardManager.shared.getText() {
                    finalQuery = query.replacingOccurrences(of: "[CLIPBOARD]", with: clipboard)
                }
            #elseif os(iOS)
                if let clipboard = UIPasteboard.general.string {
                    finalQuery = query.replacingOccurrences(of: "[CLIPBOARD]", with: clipboard)
                }
            #endif
        }

        NotificationCenter.default.post(
            name: .launcherAskAI,
            object: nil,
            userInfo: ["query": finalQuery]
        )
    }

    private func runShortcut(_: String) async {
        #if os(iOS)
        // Run Siri Shortcut
        #elseif os(macOS)
            // Run Shortcuts app shortcut via AppleScript
        #endif
    }

    private func runScript(_ script: String) async {
        #if os(macOS)
            // Run AppleScript
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            do {
                try process.run()
            } catch {
                logger.error("Failed to run script: \(error.localizedDescription)")
            }
        #endif
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
            UniversalClipboardManager.shared.copyText(text, source: "QuickLauncher")
        #elseif os(iOS)
            UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - Launcher Types

public struct LauncherCommand: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let icon: String
    public let keywords: [String]
    public let action: LauncherAction

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String,
        keywords: [String] = [],
        action: LauncherAction
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.keywords = keywords
        self.action = action
    }

    public static func == (lhs: LauncherCommand, rhs: LauncherCommand) -> Bool {
        lhs.id == rhs.id
    }
}

public enum LauncherAction: Sendable {
    case navigate(String)
    case run(@Sendable () async -> Void)
    case openURL(URL)
    case shortcut(String)
    case script(String)
    case aiPrompt(String)
}

public enum LauncherResult: Identifiable, Sendable {
    case command(LauncherCommand)
    case file(URL)
    case url(URL)
    case aiSuggestion(String)
    case calculation(String, String)
    case `extension`(ExtensionResult)

    public var id: String {
        switch self {
        case let .command(cmd): "cmd-\(cmd.id)"
        case let .file(url): "file-\(url.path)"
        case let .url(url): "url-\(url.absoluteString)"
        case let .aiSuggestion(query): "ai-\(query)"
        case let .calculation(expr, _): "calc-\(expr)"
        case let .extension(result): "ext-\(result.id)"
        }
    }
}

public protocol LauncherExtension: Sendable {
    var name: String { get }
    func search(query: String) async -> [LauncherResult]?
}

public struct ExtensionResult: Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let icon: String
    public let execute: @Sendable () async -> Void

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String,
        execute: @escaping @Sendable () async -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.execute = execute
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let launcherNavigate = Notification.Name("thea.launcher.navigate")
    static let launcherQuickAsk = Notification.Name("thea.launcher.quickAsk")
    static let launcherAskAI = Notification.Name("thea.launcher.askAI")
}
