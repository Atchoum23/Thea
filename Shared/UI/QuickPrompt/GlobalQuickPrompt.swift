// GlobalQuickPrompt.swift
// Global quick prompt overlay like Claude Desktop, ChatGPT, Perplexity
// Activated with Option+Space (configurable)

import SwiftUI
import Combine
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

    private var cancellables = Set<AnyCancellable>()
    private let maxRecentPrompts = 10

    // MARK: - Initialization

    private init() {
        loadConfiguration()
        loadRecentPrompts()
        setupHotkey()
    }

    deinit {
        #if os(macOS)
        unregisterHotkey()
        #endif
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "quickPrompt.configuration"),
           let config = try? JSONDecoder().decode(QuickPromptConfiguration.self, from: data) {
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
           let prompts = try? JSONDecoder().decode([RecentPrompt].self, from: data) {
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
            guard let self = self else { return }

            Task { @MainActor in
                if self.isHotkeyMatch(event) {
                    self.toggle()
                }
            }
        }

        // Also monitor local events when app is active
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

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

        return keyCode == configuredKeyCode &&
               modifiers.contains(configuredModifiers)
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
            guard let self = self,
                  let window = self.quickPromptWindow else { return }

            // Check if click is outside the window
            let clickLocation = event.locationInWindow
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
        // Use the AI service to process the prompt
        // This would integrate with your existing AI infrastructure

        // For now, simulate processing
        try await Task.sleep(nanoseconds: 500_000_000)

        // In real implementation:
        // return try await AIService.shared.quickPrompt(text)

        return "This is a simulated response. In production, this would connect to the AI backend."
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
}

// MARK: - Configuration

public struct QuickPromptConfiguration: Codable {
    public var hotkeyKeyCode: Int = 49 // Space
    public var hotkeyModifiers: NSEvent.ModifierFlags = .option
    public var windowSize: CGSize = CGSize(width: 600, height: 120)
    public var showRecentPrompts: Bool = true
    public var autoHideAfterSubmit: Bool = false
    public var defaultShowInlineResponse: Bool = true
    public var theme: QuickPromptTheme = .system

    public enum QuickPromptTheme: String, Codable, CaseIterable {
        case system
        case light
        case dark
        case translucent
    }

    enum CodingKeys: String, CodingKey {
        case hotkeyKeyCode, windowSize, showRecentPrompts
        case autoHideAfterSubmit, defaultShowInlineResponse, theme
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkeyKeyCode = try container.decodeIfPresent(Int.self, forKey: .hotkeyKeyCode) ?? 49
        windowSize = try container.decodeIfPresent(CGSize.self, forKey: .windowSize) ?? CGSize(width: 600, height: 120)
        showRecentPrompts = try container.decodeIfPresent(Bool.self, forKey: .showRecentPrompts) ?? true
        autoHideAfterSubmit = try container.decodeIfPresent(Bool.self, forKey: .autoHideAfterSubmit) ?? false
        defaultShowInlineResponse = try container.decodeIfPresent(Bool.self, forKey: .defaultShowInlineResponse) ?? true
        theme = try container.decodeIfPresent(QuickPromptTheme.self, forKey: .theme) ?? .system
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hotkeyKeyCode, forKey: .hotkeyKeyCode)
        try container.encode(windowSize, forKey: .windowSize)
        try container.encode(showRecentPrompts, forKey: .showRecentPrompts)
        try container.encode(autoHideAfterSubmit, forKey: .autoHideAfterSubmit)
        try container.encode(defaultShowInlineResponse, forKey: .defaultShowInlineResponse)
        try container.encode(theme, forKey: .theme)
    }
}

// Custom Codable for NSEvent.ModifierFlags
extension NSEvent.ModifierFlags: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(UInt.self)
        self.init(rawValue: rawValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Types

public struct QuickPromptResponse {
    public let text: String
    public let timestamp: Date
    public let success: Bool
}

public struct RecentPrompt: Identifiable, Codable {
    public let id: UUID
    public let text: String
    public let timestamp: Date

    public init(id: UUID = UUID(), text: String, timestamp: Date) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let quickPromptCopied = Notification.Name("thea.quickPrompt.copied")
    static let quickPromptSubmitted = Notification.Name("thea.quickPrompt.submitted")
}

// MARK: - SwiftUI Views

/// Main quick prompt overlay view
public struct QuickPromptOverlayView: View {
    @ObservedObject var manager = GlobalQuickPromptManager.shared
    @FocusState private var isTextFieldFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Input area
            inputArea

            // Response area (if showing inline)
            if manager.response != nil && manager.showInlineResponse {
                Divider()
                responseArea
            }

            // Recent prompts (if configured)
            if manager.configuration.showRecentPrompts &&
               manager.response == nil &&
               !manager.recentPrompts.isEmpty &&
               manager.promptText.isEmpty {
                Divider()
                recentPromptsArea
            }
        }
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch manager.configuration.theme {
        case .system:
            #if os(macOS)
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            #else
            Color(.systemBackground).opacity(0.95)
            #endif
        case .light:
            Color.white.opacity(0.95)
        case .dark:
            Color.black.opacity(0.85)
        case .translucent:
            #if os(macOS)
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
            #else
            Color(.systemBackground).opacity(0.8)
            #endif
        }
    }

    private var inputArea: some View {
        HStack(spacing: 12) {
            // App icon
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)

            // Text input
            TextField("Ask Thea anything...", text: $manager.promptText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .lineLimit(1...5)
                .focused($isTextFieldFocused)
                .onSubmit {
                    Task {
                        await manager.submitPrompt()
                    }
                }
                .onKeyPress(.escape) {
                    manager.hide()
                    return .handled
                }

            // Action buttons
            HStack(spacing: 8) {
                if manager.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    // Submit button
                    Button(action: {
                        Task {
                            await manager.submitPrompt()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(manager.promptText.isEmpty ? .secondary : .tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(manager.promptText.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                }

                // Open in app button
                Button(action: {
                    manager.openInMainApp()
                }) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open in Thea")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var responseArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Response")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Action buttons
                Button(action: { manager.copyResponse() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy response")

                Button(action: {
                    manager.openInMainApp(prompt: manager.promptText, response: manager.response?.text)
                }) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Continue in Thea")

                Button(action: {
                    manager.response = nil
                    manager.promptText = ""
                    #if os(macOS)
                    manager.collapseWindow()
                    #endif
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Dismiss response")
            }

            ScrollView {
                Text(manager.response?.text ?? "")
                    .font(.system(size: 14))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 250)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var recentPromptsArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Recent")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear") {
                    manager.clearRecentPrompts()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(manager.recentPrompts.prefix(5)) { prompt in
                        Button(action: { manager.useRecentPrompt(prompt) }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(prompt.text)
                                    .font(.system(size: 13))
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Visual Effect View (macOS)

#if os(macOS)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
#endif

// MARK: - Settings View for Quick Prompt

public struct QuickPromptSettingsView: View {
    @ObservedObject var manager = GlobalQuickPromptManager.shared
    @State private var isRecordingHotkey = false

    public init() {}

    public var body: some View {
        Form {
            Section {
                // Hotkey configuration
                HStack {
                    Text("Keyboard Shortcut")

                    Spacer()

                    Button(action: { isRecordingHotkey = true }) {
                        Text(hotkeyDisplayString)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                Toggle("Show Recent Prompts", isOn: $manager.configuration.showRecentPrompts)

                Toggle("Show Inline Response", isOn: $manager.showInlineResponse)

                Toggle("Auto-hide After Submit", isOn: $manager.configuration.autoHideAfterSubmit)
            } header: {
                Text("Quick Prompt")
            }

            Section {
                Picker("Theme", selection: $manager.configuration.theme) {
                    ForEach(QuickPromptConfiguration.QuickPromptTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
            } header: {
                Text("Appearance")
            }
        }
        .onChange(of: manager.configuration) { _, _ in
            manager.saveConfiguration()
        }
        .sheet(isPresented: $isRecordingHotkey) {
            HotkeyRecorderView(isPresented: $isRecordingHotkey)
        }
    }

    private var hotkeyDisplayString: String {
        var parts: [String] = []

        let modifiers = manager.configuration.hotkeyModifiers
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        // Key name
        let keyCode = manager.configuration.hotkeyKeyCode
        let keyName = keyCodeToString(keyCode)
        parts.append(keyName)

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: Int) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Escape"
        default: return "Key \(keyCode)"
        }
    }
}

/// View for recording custom hotkey
struct HotkeyRecorderView: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager = GlobalQuickPromptManager.shared
    @State private var recordedKeyCode: Int?
    @State private var recordedModifiers: NSEvent.ModifierFlags = []

    var body: some View {
        VStack(spacing: 20) {
            Text("Press your desired key combination")
                .font(.headline)

            Text("Current: \(displayString)")
                .font(.title2)
                .padding()
                .frame(minWidth: 200)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    if let keyCode = recordedKeyCode {
                        manager.configuration.hotkeyKeyCode = keyCode
                        manager.configuration.hotkeyModifiers = recordedModifiers
                        manager.saveConfiguration()
                    }
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(recordedKeyCode == nil)
            }
        }
        .padding(30)
        .frame(minWidth: 300)
        #if os(macOS)
        .onKeyDown { event in
            recordedKeyCode = Int(event.keyCode)
            recordedModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        }
        #endif
    }

    private var displayString: String {
        guard let keyCode = recordedKeyCode else {
            return "Waiting..."
        }

        var parts: [String] = []

        if recordedModifiers.contains(.control) { parts.append("⌃") }
        if recordedModifiers.contains(.option) { parts.append("⌥") }
        if recordedModifiers.contains(.shift) { parts.append("⇧") }
        if recordedModifiers.contains(.command) { parts.append("⌘") }

        switch keyCode {
        case 49: parts.append("Space")
        case 36: parts.append("Return")
        default: parts.append("Key \(keyCode)")
        }

        return parts.joined()
    }
}

// MARK: - Key Down Handler (macOS)

#if os(macOS)
extension View {
    func onKeyDown(_ handler: @escaping (NSEvent) -> Void) -> some View {
        self.background(KeyDownHandler(handler: handler))
    }
}

struct KeyDownHandler: NSViewRepresentable {
    let handler: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyDownView {
        let view = KeyDownView()
        view.handler = handler
        return view
    }

    func updateNSView(_ nsView: KeyDownView, context: Context) {
        nsView.handler = handler
    }
}

class KeyDownView: NSView {
    var handler: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        handler?(event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}
#endif

// MARK: - Menu Bar Integration

#if os(macOS)
public struct QuickPromptMenuBarItem: View {
    @ObservedObject var manager = GlobalQuickPromptManager.shared

    public init() {}

    public var body: some View {
        Button(action: { manager.show() }) {
            Label("Quick Prompt", systemImage: "sparkles")
        }
        .keyboardShortcut(" ", modifiers: .option)
    }
}
#endif
