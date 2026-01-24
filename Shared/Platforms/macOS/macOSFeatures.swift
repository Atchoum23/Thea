// macOSFeatures.swift
// macOS-specific features: Menu Bar, Global Shortcuts, Touch Bar, AppleScript, Finder integration

#if os(macOS)
import Foundation
import AppKit
import OSLog
import Carbon.HIToolbox

// MARK: - Menu Bar Manager

/// Manages the Thea menu bar extra (status bar item)
@MainActor
public final class MenuBarManager: NSObject, ObservableObject {
    public static let shared = MenuBarManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "MenuBar")
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    // MARK: - Published State

    @Published public var isVisible = true
    @Published public var showQuickActions = true
    @Published public var currentStatus: MenuBarStatus = .idle

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Setup

    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Thea")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        setupPopover()
        logger.info("Menu bar setup complete")
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.animates = true
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Status Updates

    public func updateStatus(_ status: MenuBarStatus) {
        currentStatus = status

        guard let button = statusItem?.button else { return }

        switch status {
        case .idle:
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Thea")
        case .thinking:
            button.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "Thinking")
        case .processing:
            button.image = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: "Processing")
        case .notification:
            button.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "Notification")
        case .error:
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error")
        }
    }

    public func hide() {
        statusItem = nil
        isVisible = false
    }

    public func show() {
        setup()
        isVisible = true
    }
}

public enum MenuBarStatus {
    case idle
    case thinking
    case processing
    case notification
    case error
}

// MARK: - Global Hotkey Manager

/// Manages global keyboard shortcuts
@MainActor
public final class GlobalHotkeyManager: ObservableObject {
    public static let shared = GlobalHotkeyManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "GlobalHotkeys")
    private var eventHandlers: [String: Any] = [:]

    // MARK: - Published State

    @Published public var registeredHotkeys: [GlobalHotkey] = []
    @Published public var isEnabled = true

    // MARK: - Default Hotkeys

    public static let defaultHotkeys: [GlobalHotkey] = [
        GlobalHotkey(id: "activate", keyCode: UInt16(kVK_Space), modifiers: [.command, .shift], action: .activateThea, description: "Activate Thea"),
        GlobalHotkey(id: "quickAsk", keyCode: UInt16(kVK_ANSI_T), modifiers: [.command, .shift], action: .quickAsk, description: "Quick Ask"),
        GlobalHotkey(id: "screenshot", keyCode: UInt16(kVK_ANSI_S), modifiers: [.command, .shift, .option], action: .screenshotAndAsk, description: "Screenshot and Ask"),
        GlobalHotkey(id: "clipboard", keyCode: UInt16(kVK_ANSI_V), modifiers: [.command, .shift, .option], action: .processClipboard, description: "Process Clipboard"),
        GlobalHotkey(id: "voice", keyCode: UInt16(kVK_ANSI_V), modifiers: [.command, .control], action: .voiceInput, description: "Voice Input")
    ]

    // MARK: - Initialization

    private init() {
        registeredHotkeys = Self.defaultHotkeys
    }

    // MARK: - Registration

    public func registerAllHotkeys() {
        guard isEnabled else { return }

        for hotkey in registeredHotkeys where hotkey.isEnabled {
            registerHotkey(hotkey)
        }

        logger.info("Registered \(registeredHotkeys.filter { $0.isEnabled }.count) global hotkeys")
    }

    public func registerHotkey(_ hotkey: GlobalHotkey) {
        // Use CGEvent or NSEvent.addGlobalMonitorForEvents
        let mask: NSEvent.EventTypeMask = .keyDown

        let handler = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self = self, self.isEnabled else { return }

            let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let requiredModifiers = self.modifiersToFlags(hotkey.modifiers)

            if event.keyCode == hotkey.keyCode && modifierFlags == requiredModifiers {
                Task { @MainActor in
                    self.executeHotkeyAction(hotkey.action)
                }
            }
        }

        if let handler = handler {
            eventHandlers[hotkey.id] = handler
        }
    }

    public func unregisterHotkey(_ id: String) {
        if let handler = eventHandlers[id] {
            NSEvent.removeMonitor(handler)
            eventHandlers.removeValue(forKey: id)
        }
    }

    public func unregisterAllHotkeys() {
        for handler in eventHandlers.values {
            NSEvent.removeMonitor(handler)
        }
        eventHandlers.removeAll()
    }

    // MARK: - Actions

    private func executeHotkeyAction(_ action: HotkeyAction) {
        logger.info("Executing hotkey action: \(action.rawValue)")

        switch action {
        case .activateThea:
            NSApp.activate(ignoringOtherApps: true)

        case .quickAsk:
            NotificationCenter.default.post(name: .theaQuickAsk, object: nil)

        case .screenshotAndAsk:
            NotificationCenter.default.post(name: .theaScreenshotAsk, object: nil)

        case .processClipboard:
            NotificationCenter.default.post(name: .theaProcessClipboard, object: nil)

        case .voiceInput:
            NotificationCenter.default.post(name: .theaVoiceInput, object: nil)

        case .newConversation:
            NotificationCenter.default.post(name: .theaNewConversation, object: nil)

        case .toggleWindow:
            if let window = NSApp.mainWindow {
                if window.isVisible {
                    window.orderOut(nil)
                } else {
                    window.makeKeyAndOrderFront(nil)
                }
            }

        case .custom(let identifier):
            NotificationCenter.default.post(name: .theaCustomHotkey, object: identifier)
        }
    }

    private func modifiersToFlags(_ modifiers: Set<HotkeyModifier>) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        return flags
    }
}

// MARK: - Global Hotkey Model

public struct GlobalHotkey: Identifiable, Codable {
    public let id: String
    public var keyCode: UInt16
    public var modifiers: Set<HotkeyModifier>
    public var action: HotkeyAction
    public var description: String
    public var isEnabled: Bool

    public init(id: String, keyCode: UInt16, modifiers: Set<HotkeyModifier>, action: HotkeyAction, description: String, isEnabled: Bool = true) {
        self.id = id
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
        self.description = description
        self.isEnabled = isEnabled
    }

    public var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Escape: return "⎋"
        default:
            if let char = keyCodeToCharacter(keyCode) {
                return char.uppercased()
            }
            return "?"
        }
    }

    private func keyCodeToCharacter(_ keyCode: UInt16) -> String? {
        let inputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else { return nil }

        let layout = unsafeBitCast(layoutData, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layout), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var actualStringLength = 0
        var unicodeString = [UniChar](repeating: 0, count: 4)

        let status = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &actualStringLength,
            &unicodeString
        )

        guard status == noErr else { return nil }
        return String(utf16CodeUnits: unicodeString, count: actualStringLength)
    }
}

public enum HotkeyModifier: String, Codable, CaseIterable {
    case command
    case option
    case control
    case shift
}

public enum HotkeyAction: Codable, Equatable {
    case activateThea
    case quickAsk
    case screenshotAndAsk
    case processClipboard
    case voiceInput
    case newConversation
    case toggleWindow
    case custom(String)

    public var rawValue: String {
        switch self {
        case .activateThea: return "activate"
        case .quickAsk: return "quickAsk"
        case .screenshotAndAsk: return "screenshotAsk"
        case .processClipboard: return "clipboard"
        case .voiceInput: return "voice"
        case .newConversation: return "newConversation"
        case .toggleWindow: return "toggleWindow"
        case .custom(let id): return "custom:\(id)"
        }
    }
}

// MARK: - Finder Integration

/// Integration with Finder for file operations
@MainActor
public final class FinderIntegration: ObservableObject {
    public static let shared = FinderIntegration()

    private let logger = Logger(subsystem: "com.thea.app", category: "Finder")

    // MARK: - Get Selection

    /// Get currently selected files in Finder
    public func getSelectedFiles() async throws -> [URL] {
        let script = """
        tell application "Finder"
            set selectedItems to selection as alias list
            set filePaths to {}
            repeat with anItem in selectedItems
                set end of filePaths to POSIX path of anItem
            end repeat
            return filePaths
        end tell
        """

        let paths = try await executeAppleScript(script)
        return paths.compactMap { URL(fileURLWithPath: $0) }
    }

    /// Get current Finder window path
    public func getCurrentFolder() async throws -> URL? {
        let script = """
        tell application "Finder"
            if (count of Finder windows) > 0 then
                return POSIX path of (target of front Finder window as alias)
            end if
        end tell
        return ""
        """

        let result = try await executeAppleScriptSingle(script)
        guard !result.isEmpty else { return nil }
        return URL(fileURLWithPath: result)
    }

    // MARK: - File Operations

    /// Reveal file in Finder
    public func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Open file with default application
    public func openFile(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Open file with specific application
    public func openFile(_ url: URL, withApplication appURL: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        try await NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
    }

    /// Quick Look preview
    public func previewFile(_ url: URL) {
        // Would use QLPreviewPanel
        revealInFinder(url)
    }

    // MARK: - Folder Actions

    /// Create folder in Finder
    public func createFolder(named name: String, at location: URL) throws -> URL {
        let newFolderURL = location.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: true)
        return newFolderURL
    }

    // MARK: - AppleScript Execution

    private func executeAppleScript(_ script: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                let output = scriptObject.executeAndReturnError(&error)

                if let error = error {
                    continuation.resume(throwing: AppleScriptError.executionFailed(error.description))
                    return
                }

                var results: [String] = []
                if output.numberOfItems > 0 {
                    for i in 1...output.numberOfItems {
                        if let item = output.atIndex(i)?.stringValue {
                            results.append(item)
                        }
                    }
                } else if let stringValue = output.stringValue {
                    results.append(stringValue)
                }

                continuation.resume(returning: results)
            } else {
                continuation.resume(throwing: AppleScriptError.scriptCreationFailed)
            }
        }
    }

    private func executeAppleScriptSingle(_ script: String) async throws -> String {
        let results = try await executeAppleScript(script)
        return results.first ?? ""
    }
}

public enum AppleScriptError: Error, LocalizedError {
    case scriptCreationFailed
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .scriptCreationFailed:
            return "Failed to create AppleScript"
        case .executionFailed(let details):
            return "AppleScript execution failed: \(details)"
        }
    }
}

// MARK: - Service Provider

/// Provides Services menu integration
public final class TheaServiceProvider: NSObject {
    @objc public func processText(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string) else { return }

        // Send text to Thea for processing
        NotificationCenter.default.post(
            name: .theaServiceProcessText,
            object: nil,
            userInfo: ["text": text, "action": userData]
        )
    }

    @objc public func askThea(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string) else { return }

        NotificationCenter.default.post(
            name: .theaServiceAsk,
            object: nil,
            userInfo: ["text": text]
        )
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let theaQuickAsk = Notification.Name("theaQuickAsk")
    static let theaScreenshotAsk = Notification.Name("theaScreenshotAsk")
    static let theaProcessClipboard = Notification.Name("theaProcessClipboard")
    static let theaVoiceInput = Notification.Name("theaVoiceInput")
    static let theaNewConversation = Notification.Name("theaNewConversation")
    static let theaCustomHotkey = Notification.Name("theaCustomHotkey")
    static let theaServiceProcessText = Notification.Name("theaServiceProcessText")
    static let theaServiceAsk = Notification.Name("theaServiceAsk")
}

#endif
