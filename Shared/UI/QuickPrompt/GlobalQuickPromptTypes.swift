// GlobalQuickPromptTypes.swift
// Types, views, and helpers for GlobalQuickPromptManager

import Combine
import SwiftUI
#if os(macOS)
    import AppKit
    import Carbon.HIToolbox
#endif

// MARK: - Configuration

/// Cross-platform modifier flags for keyboard shortcuts
public struct QuickPromptModifierFlags: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let control = QuickPromptModifierFlags(rawValue: 1 << 0)
    public static let option = QuickPromptModifierFlags(rawValue: 1 << 1)
    public static let shift = QuickPromptModifierFlags(rawValue: 1 << 2)
    public static let command = QuickPromptModifierFlags(rawValue: 1 << 3)
}

public struct QuickPromptConfiguration: Codable, Equatable {
    public var hotkeyKeyCode: Int = 49 // Space
    public var hotkeyModifiers: QuickPromptModifierFlags = .option
    public var windowSize: CGSize = .init(width: 600, height: 120)
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
        case hotkeyKeyCode, hotkeyModifiers, windowSize, showRecentPrompts
        case autoHideAfterSubmit, defaultShowInlineResponse, theme
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkeyKeyCode = try container.decodeIfPresent(Int.self, forKey: .hotkeyKeyCode) ?? 49
        hotkeyModifiers = try container.decodeIfPresent(QuickPromptModifierFlags.self, forKey: .hotkeyModifiers) ?? .option
        windowSize = try container.decodeIfPresent(CGSize.self, forKey: .windowSize) ?? CGSize(width: 600, height: 120)
        showRecentPrompts = try container.decodeIfPresent(Bool.self, forKey: .showRecentPrompts) ?? true
        autoHideAfterSubmit = try container.decodeIfPresent(Bool.self, forKey: .autoHideAfterSubmit) ?? false
        defaultShowInlineResponse = try container.decodeIfPresent(Bool.self, forKey: .defaultShowInlineResponse) ?? true
        theme = try container.decodeIfPresent(QuickPromptTheme.self, forKey: .theme) ?? .system
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hotkeyKeyCode, forKey: .hotkeyKeyCode)
        try container.encode(hotkeyModifiers, forKey: .hotkeyModifiers)
        try container.encode(windowSize, forKey: .windowSize)
        try container.encode(showRecentPrompts, forKey: .showRecentPrompts)
        try container.encode(autoHideAfterSubmit, forKey: .autoHideAfterSubmit)
        try container.encode(defaultShowInlineResponse, forKey: .defaultShowInlineResponse)
        try container.encode(theme, forKey: .theme)
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
            if manager.response != nil, manager.showInlineResponse {
                Divider()
                responseArea
            }

            // Recent prompts (if configured)
            if manager.configuration.showRecentPrompts,
               manager.response == nil,
               !manager.recentPrompts.isEmpty,
               manager.promptText.isEmpty
            {
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
                .font(.theaTitle2)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)

            // Text input
            TextField("Ask Thea anything...", text: $manager.promptText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.theaBody)
                .lineLimit(1 ... 5)
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
                            .font(.theaTitle1)
                            .foregroundStyle(manager.promptText.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
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
                        .font(.theaTitle3)
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
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)

                Spacer()

                // Action buttons
                Button(action: { manager.copyResponse() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.theaCaption1)
                }
                .buttonStyle(.plain)
                .help("Copy response")

                Button(action: {
                    manager.openInMainApp(prompt: manager.promptText, response: manager.response?.text)
                }) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.theaCaption1)
                }
                .buttonStyle(.plain)
                .help("Continue in Thea")

                Button(action: {
                    manager.clearResponse()
                    manager.promptText = ""
                    #if os(macOS)
                        manager.collapseWindow()
                    #endif
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.theaCaption1)
                }
                .buttonStyle(.plain)
                .help("Dismiss response")
            }

            ScrollView {
                Text(manager.response?.text ?? "")
                    .font(.theaCallout)
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
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear") {
                    manager.clearRecentPrompts()
                }
                .font(.theaCaption1)
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
                                    .font(.theaCaption1)
                                    .foregroundStyle(.secondary)

                                Text(prompt.text)
                                    .font(.theaFootnote)
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

        func makeNSView(context _: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = material
            view.blendingMode = blendingMode
            view.state = .active
            return view
        }

        func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
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
        #if os(macOS)
        .sheet(isPresented: $isRecordingHotkey) {
            HotkeyRecorderView(isPresented: $isRecordingHotkey)
        }
        #endif
    }

    private var hotkeyDisplayString: String {
        var parts: [String] = []

        let modifiers = manager.configuration.hotkeyModifiers
        if modifiers.contains(.control) { parts.append("\u{2303}") }
        if modifiers.contains(.option) { parts.append("\u{2325}") }
        if modifiers.contains(.shift) { parts.append("\u{21E7}") }
        if modifiers.contains(.command) { parts.append("\u{2318}") }

        // Key name
        let keyCode = manager.configuration.hotkeyKeyCode
        let keyName = keyCodeToString(keyCode)
        parts.append(keyName)

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: Int) -> String {
        switch keyCode {
        case 49: "Space"
        case 36: "Return"
        case 48: "Tab"
        case 51: "Delete"
        case 53: "Escape"
        default: "Key \(keyCode)"
        }
    }
}

/// View for recording custom hotkey (macOS only)
#if os(macOS)
    struct HotkeyRecorderView: View {
        @Binding var isPresented: Bool
        @ObservedObject var manager = GlobalQuickPromptManager.shared
        @State private var recordedKeyCode: Int?
        @State private var recordedModifiers: QuickPromptModifierFlags = []

        var body: some View {
            VStack(spacing: 20) {
                Text("Press your desired key combination")
                    .font(.theaHeadline)

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
            .onKeyDown { event in
                recordedKeyCode = Int(event.keyCode)
                // Convert NSEvent.ModifierFlags to QuickPromptModifierFlags
                var flags: QuickPromptModifierFlags = []
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if modifiers.contains(.control) { flags.insert(.control) }
                if modifiers.contains(.option) { flags.insert(.option) }
                if modifiers.contains(.shift) { flags.insert(.shift) }
                if modifiers.contains(.command) { flags.insert(.command) }
                recordedModifiers = flags
            }
        }

        private var displayString: String {
            guard let keyCode = recordedKeyCode else {
                return "Waiting..."
            }

            var parts: [String] = []

            if recordedModifiers.contains(.control) { parts.append("\u{2303}") }
            if recordedModifiers.contains(.option) { parts.append("\u{2325}") }
            if recordedModifiers.contains(.shift) { parts.append("\u{21E7}") }
            if recordedModifiers.contains(.command) { parts.append("\u{2318}") }

            switch keyCode {
            case 49: parts.append("Space")
            case 36: parts.append("Return")
            default: parts.append("Key \(keyCode)")
            }

            return parts.joined()
        }
    }
#endif

// MARK: - Key Down Handler (macOS)

#if os(macOS)
    extension View {
        func onKeyDown(_ handler: @escaping (NSEvent) -> Void) -> some View {
            background(KeyDownHandler(handler: handler))
        }
    }

    struct KeyDownHandler: NSViewRepresentable {
        let handler: (NSEvent) -> Void

        func makeNSView(context _: Context) -> KeyDownView {
            let view = KeyDownView()
            view.handler = handler
            return view
        }

        func updateNSView(_ nsView: KeyDownView, context _: Context) {
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
