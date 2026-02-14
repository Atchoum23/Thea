// GlobalQuickPrompt.swift
// Global quick prompt overlay like Claude Desktop, ChatGPT, Perplexity
// Activated with Option+Space (configurable)

import Combine
import SwiftUI
#if os(macOS)
    import AppKit
    import Carbon.HIToolbox
#endif

// MARK: - Global Quick Prompt Manager

/// Manages the global quick prompt overlay
@MainActor
public final class GlobalQuickPromptManager: ObservableObject {
    public static let shared = GlobalQuickPromptManager()

    // MARK: - Published State

    @Published public private(set) var isVisible = false
    @Published public private(set) var isProcessing = false
    @Published public var promptText = ""
    @Published public private(set) var response: QuickPromptResponse?
    @Published public private(set) var recentPrompts: [RecentPrompt] = []
    @Published public var showInlineResponse = true

    // MARK: - Configuration

    @Published public var configuration = QuickPromptConfiguration()

    // MARK: - Private Properties

    #if os(macOS)
        private var quickPromptWindow: NSWindow?
        private var eventMonitor: Any?
        private var globalHotkeyMonitor: Any?
    #endif

    private let maxRecentPrompts = 10

    // MARK: - Initialization

    private init() {
        loadConfiguration()
        loadRecentPrompts()
        setupHotkey()
    }

    // Note: deinit removed because @MainActor isolated methods cannot be called from deinit
    // Hotkey cleanup should be handled explicitly before deallocation

    // MARK: - Configuration

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "quickPrompt.configuration"),
           let config = try? JSONDecoder().decode(QuickPromptConfiguration.self, from: data)
        {
            configuration = config
        }
    }

    public func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "quickPrompt.configuration")
        }

        // Re-register hotkey with new configuration
        #if os(macOS)
            unregisterHotkey()
            setupHotkey()
        #endif
    }

    private func loadRecentPrompts() {
        if let data = UserDefaults.standard.data(forKey: "quickPrompt.recentPrompts"),
           let prompts = try? JSONDecoder().decode([RecentPrompt].self, from: data)
        {
            recentPrompts = prompts
        }
    }

    private func saveRecentPrompts() {
        if let data = try? JSONEncoder().encode(recentPrompts) {
            UserDefaults.standard.set(data, forKey: "quickPrompt.recentPrompts")
        }
    }

    // MARK: - Hotkey Setup

    private func setupHotkey() {
        #if os(macOS)
            registerGlobalHotkey()
        #endif
    }

    #if os(macOS)
        private func registerGlobalHotkey() {
            // Use NSEvent global monitor for Option+Space
            globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return }

                Task { @MainActor in
                    if self.isHotkeyMatch(event) {
                        self.toggle()
                    }
                }
            }

            // Also monitor local events when app is active
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                Task { @MainActor in
                    if self.isHotkeyMatch(event) {
                        self.toggle()
                    }
                }

                return event
            }
        }

        private func isHotkeyMatch(_ event: NSEvent) -> Bool {
            let keyCode = Int(event.keyCode)
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Default: Option + Space (keyCode 49 is space)
            let configuredKeyCode = configuration.hotkeyKeyCode
            let configuredModifiers = configuration.hotkeyModifiers

            // Convert configured modifiers to NSEvent.ModifierFlags for comparison
            var expectedModifiers: NSEvent.ModifierFlags = []
            if configuredModifiers.contains(.control) { expectedModifiers.insert(.control) }
            if configuredModifiers.contains(.option) { expectedModifiers.insert(.option) }
            if configuredModifiers.contains(.shift) { expectedModifiers.insert(.shift) }
            if configuredModifiers.contains(.command) { expectedModifiers.insert(.command) }

            return keyCode == configuredKeyCode &&
                modifiers.contains(expectedModifiers)
        }

        private func unregisterHotkey() {
            if let monitor = globalHotkeyMonitor {
                NSEvent.removeMonitor(monitor)
                globalHotkeyMonitor = nil
            }
        }
    #endif

    // MARK: - Visibility Control

    /// Toggle the quick prompt overlay
    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Show the quick prompt overlay
    public func show() {
        guard !isVisible else { return }

        isVisible = true
        promptText = ""
        response = nil

        #if os(macOS)
            showQuickPromptWindow()
        #endif

        // Analytics
        AnalyticsManager.shared.track("quick_prompt_opened")
    }

    /// Hide the quick prompt overlay
    public func hide() {
        guard isVisible else { return }

        isVisible = false

        #if os(macOS)
            hideQuickPromptWindow()
        #endif
    }

    // MARK: - macOS Window Management

    #if os(macOS)
        private func showQuickPromptWindow() {
            if quickPromptWindow == nil {
                createQuickPromptWindow()
            }

            guard let window = quickPromptWindow else { return }

            // Position window in center of screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowSize = configuration.windowSize

                let x = screenFrame.midX - windowSize.width / 2
                let y = screenFrame.midY + screenFrame.height * 0.15 // Slightly above center

                window.setFrame(NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height), display: true)
            }

            // Show window
            window.makeKeyAndOrderFront(nil)
            window.level = .floating
            NSApp.activate(ignoringOtherApps: true)

            // Setup click-outside-to-dismiss
            setupEventMonitor()
        }

        private func createQuickPromptWindow() {
            let contentView = QuickPromptOverlayView()

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 120),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            window.contentView = NSHostingView(rootView: contentView)
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isMovableByWindowBackground = true

            // Make window rounded
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.cornerRadius = 16
            window.contentView?.layer?.masksToBounds = true

            quickPromptWindow = window
        }

        private func hideQuickPromptWindow() {
            quickPromptWindow?.orderOut(nil)
            removeEventMonitor()
        }

        private func setupEventMonitor() {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self,
                      let window = self.quickPromptWindow else { return }

                // Check if click is outside the window
                _ = event.locationInWindow
                let windowFrame = window.frame

                if !windowFrame.contains(NSEvent.mouseLocation) {
                    Task { @MainActor in
                        self.hide()
                    }
                }
            }
        }

        private func removeEventMonitor() {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }

        /// Update window size for inline response
        public func expandForResponse() {
            guard let window = quickPromptWindow else { return }

            var frame = window.frame
            let newHeight: CGFloat = 400
            frame.origin.y -= (newHeight - frame.height)
            frame.size.height = newHeight

            window.setFrame(frame, display: true, animate: true)
        }

        /// Collapse window back to input only
        public func collapseWindow() {
            guard let window = quickPromptWindow else { return }

            var frame = window.frame
            let newHeight = configuration.windowSize.height
            frame.origin.y += (frame.height - newHeight)
            frame.size.height = newHeight

            window.setFrame(frame, display: true, animate: true)
        }
    #endif

    // MARK: - Prompt Submission

    /// Submit the current prompt
    public func submitPrompt() async {
        let text = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isProcessing = true

        // Add to recent prompts
        let recentPrompt = RecentPrompt(text: text, timestamp: Date())
        recentPrompts.insert(recentPrompt, at: 0)
        if recentPrompts.count > maxRecentPrompts {
            recentPrompts = Array(recentPrompts.prefix(maxRecentPrompts))
        }
        saveRecentPrompts()

        // Track usage
        AnalyticsManager.shared.track("quick_prompt_submitted", properties: [
            "prompt_length": text.count
        ])

        do {
            // Process with AI
            let result = try await processPrompt(text)

            response = QuickPromptResponse(
                text: result,
                timestamp: Date(),
                success: true
            )

            if showInlineResponse {
                #if os(macOS)
                    expandForResponse()
                #endif
            } else {
                // Open in main app
                openInMainApp(prompt: text, response: result)
                hide()
            }
        } catch {
            response = QuickPromptResponse(
                text: "Error: \(error.localizedDescription)",
                timestamp: Date(),
                success: false
            )
        }

        isProcessing = false
    }

    private func processPrompt(_ text: String) async throws -> String {
        // Use the default provider from ProviderRegistry
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            throw QuickPromptError.noProvider
        }
        let model = AppConfiguration.shared.providerConfig.defaultModel

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(text),
            timestamp: Date(),
            model: model
        )

        let stream = try await provider.chat(
            messages: [message],
            model: model,
            stream: false
        )

        var result = ""
        for try await chunk in stream {
            switch chunk.type {
            case let .delta(delta):
                result += delta
            case let .complete(finalMessage):
                result = finalMessage.content.textValue
            case let .error(error):
                throw error
            }
        }

        return result.isEmpty ? "No response received." : result
    }

    private enum QuickPromptError: LocalizedError {
        case noProvider

        var errorDescription: String? {
            switch self {
            case .noProvider:
                "No AI provider configured. Please set up a provider in Settings."
            }
        }
    }

    /// Open prompt in main Thea app
    public func openInMainApp(prompt: String? = nil, response: String? = nil) {
        let finalPrompt = prompt ?? promptText

        // Create deep link to open conversation
        var components = URLComponents()
        components.scheme = "thea"
        components.host = "conversation"
        components.path = "/new"
        components.queryItems = [
            URLQueryItem(name: "prompt", value: finalPrompt)
        ]

        if let responseText = response {
            components.queryItems?.append(URLQueryItem(name: "response", value: responseText))
        }

        if let url = components.url {
            #if os(macOS)
                NSWorkspace.shared.open(url)
            #elseif os(iOS)
                UIApplication.shared.open(url)
            #endif
        }

        hide()
    }

    /// Copy response to clipboard
    public func copyResponse() {
        guard let responseText = response?.text else { return }

        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(responseText, forType: .string)
        #elseif os(iOS)
            UIPasteboard.general.string = responseText
        #endif

        // Show feedback
        NotificationCenter.default.post(name: .quickPromptCopied, object: nil)
    }

    /// Use a recent prompt
    public func useRecentPrompt(_ prompt: RecentPrompt) {
        promptText = prompt.text
    }

    /// Clear recent prompts
    public func clearRecentPrompts() {
        recentPrompts.removeAll()
        saveRecentPrompts()
    }

    /// Clear the current response
    public func clearResponse() {
        response = nil
    }
}
