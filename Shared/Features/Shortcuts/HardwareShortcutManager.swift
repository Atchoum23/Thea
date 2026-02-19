// HardwareShortcutManager.swift
// Manages hardware keyboard shortcuts for Thea activation
// macOS: Function keys (F5/Microphone), global hotkeys
// iOS: Action button integration via ActionButtonHandler

import Combine
import Foundation
import OSLog
#if os(macOS)
import AppKit
import Carbon.HIToolbox
#endif

// MARK: - Hardware Shortcut Types

/// Available hardware shortcut triggers
enum HardwareTrigger: String, Codable, Sendable, CaseIterable {
    case functionKey = "Function Key (F5)"
    case microphoneKey = "Microphone Key (🎤)"
    case customHotkey = "Custom Hotkey"
    case actionButton = "Action Button (iPhone)"
    case doubleTapCrown = "Double Tap Crown (Watch)"

    var platformAvailable: Bool {
        #if os(macOS)
        switch self {
        case .functionKey, .microphoneKey, .customHotkey: true
        case .actionButton, .doubleTapCrown: false
        }
        #elseif os(iOS)
        switch self {
        case .actionButton: true
        default: false
        }
        #elseif os(watchOS)
        switch self {
        case .doubleTapCrown: true
        default: false
        }
        #else
        return false
        #endif
    }
}

/// Action to perform when hardware shortcut is triggered
enum HardwareShortcutAction: String, Codable, Sendable, CaseIterable {
    case activateThea = "Activate Thea"
    case startVoiceInput = "Start Voice Input"
    case toggleListening = "Toggle Listening"
    case quickAsk = "Quick Ask"
    case newConversation = "New Conversation"
    case runLastWorkflow = "Run Last Workflow"
    case takeScreenshot = "Take Screenshot & Ask"
}

/// Shortcut configuration
struct ShortcutConfig: Identifiable, Codable, Sendable {
    let id: UUID
    var trigger: HardwareTrigger
    var action: HardwareShortcutAction
    var isEnabled: Bool
    var modifiers: KeyModifiers
    var keyCode: Int?  // For custom hotkeys

    struct KeyModifiers: Codable, Sendable {
        var command: Bool = false
        var option: Bool = false
        var control: Bool = false
        var shift: Bool = false

        var isEmpty: Bool {
            !command && !option && !control && !shift
        }

        #if os(macOS)
        var nsEventFlags: NSEvent.ModifierFlags {
            var flags: NSEvent.ModifierFlags = []
            if command { flags.insert(.command) }
            if option { flags.insert(.option) }
            if control { flags.insert(.control) }
            if shift { flags.insert(.shift) }
            return flags
        }
        #endif
    }

    init(
        id: UUID = UUID(),
        trigger: HardwareTrigger,
        action: HardwareShortcutAction,
        isEnabled: Bool = true,
        modifiers: KeyModifiers = KeyModifiers(),
        keyCode: Int? = nil
    ) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.isEnabled = isEnabled
        self.modifiers = modifiers
        self.keyCode = keyCode
    }
}

// MARK: - Hardware Shortcut Manager

/// Manages hardware shortcut registration and handling
@MainActor
@Observable
final class HardwareShortcutManager {
    // periphery:ignore - Reserved: shared static property — reserved for future feature activation
    static let shared = HardwareShortcutManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "HardwareShortcutManager")

    // State
    private(set) var isMonitoring = false
    private(set) var registeredShortcuts: [ShortcutConfig] = []
    private(set) var lastTriggeredShortcut: ShortcutConfig?

    // Callbacks
    var onShortcutTriggered: ((HardwareShortcutAction) -> Void)?

// periphery:ignore - Reserved: shared static property reserved for future feature activation

    // Internal
    #if os(macOS)
    private var globalMonitor: Any?
    private var localMonitor: Any?
    #endif

    private init() {
        loadShortcuts()
    }

    // MARK: - Public API

    // periphery:ignore - Reserved: startMonitoring() instance method — reserved for future feature activation
    /// Start monitoring for hardware shortcuts
    func startMonitoring() {
        guard !isMonitoring else { return }

        #if os(macOS)
        setupMacOSMonitors()
        #endif

        isMonitoring = true
    }

    // periphery:ignore - Reserved: startMonitoring() instance method reserved for future feature activation
    /// Stop monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }

        #if os(macOS)
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            // periphery:ignore - Reserved: stopMonitoring() instance method reserved for future feature activation
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        #endif

        isMonitoring = false
    }

    // periphery:ignore - Reserved: registerShortcut(_:) instance method — reserved for future feature activation
    /// Register a new shortcut
    func registerShortcut(_ config: ShortcutConfig) {
        // Remove existing if same trigger
        registeredShortcuts.removeAll { $0.trigger == config.trigger }
        registeredShortcuts.append(config)
        saveShortcuts()
    }

    // periphery:ignore - Reserved: registerShortcut(_:) instance method reserved for future feature activation
    /// Unregister a shortcut
    func unregisterShortcut(id: UUID) {
        registeredShortcuts.removeAll { $0.id == id }
        saveShortcuts()
    }

    // periphery:ignore - Reserved: setShortcutEnabled(_:enabled:) instance method — reserved for future feature activation
    /// Enable/disable a shortcut
    func setShortcutEnabled(_ id: UUID, enabled: Bool) {
        // periphery:ignore - Reserved: unregisterShortcut(id:) instance method reserved for future feature activation
        if let index = registeredShortcuts.firstIndex(where: { $0.id == id }) {
            registeredShortcuts[index].isEnabled = enabled
            saveShortcuts()
        }
    }

// periphery:ignore - Reserved: setShortcutEnabled(_:enabled:) instance method reserved for future feature activation

    /// Get default shortcuts for platform
    func getDefaultShortcuts() -> [ShortcutConfig] {
        #if os(macOS)
        return [
            ShortcutConfig(
                trigger: .functionKey,
                action: .activateThea,
                modifiers: ShortcutConfig.KeyModifiers()
            ),
            ShortcutConfig(
                trigger: .customHotkey,
                action: .startVoiceInput,
                modifiers: ShortcutConfig.KeyModifiers(command: true, shift: true),
                keyCode: 49  // Space key
            )
        ]
        #elseif os(iOS)
        return [
            ShortcutConfig(
                trigger: .actionButton,
                action: .activateThea
            )
        ]
        #else
        return []
        #endif
    }

    // MARK: - macOS Implementation

    #if os(macOS)
    // periphery:ignore - Reserved: setupMacOSMonitors() instance method — reserved for future feature activation
    private func setupMacOSMonitors() {
        // Global monitor for when app is not focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            // periphery:ignore - Reserved: setupMacOSMonitors() instance method reserved for future feature activation
            }
        }

        // Local monitor for when app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
            return event
        }
    }

    // periphery:ignore - Reserved: handleKeyEvent(_:) instance method — reserved for future feature activation
    private func handleKeyEvent(_ event: NSEvent) {
        // Check F5 key (keyCode 96) for function key trigger
        if event.keyCode == 96 {
            if let shortcut = registeredShortcuts.first(where: {
                // periphery:ignore - Reserved: handleKeyEvent(_:) instance method reserved for future feature activation
                $0.trigger == .functionKey && $0.isEnabled
            }) {
                triggerShortcut(shortcut)
                return
            }
        }

        // Check for custom hotkeys
        for shortcut in registeredShortcuts where shortcut.trigger == .customHotkey && shortcut.isEnabled {
            if let keyCode = shortcut.keyCode,
               event.keyCode == keyCode,
               event.modifierFlags.intersection(.deviceIndependentFlagsMask) == shortcut.modifiers.nsEventFlags {
                triggerShortcut(shortcut)
                return
            }
        }

        // Check for microphone key (F5 or special media key)
        // Some keyboards have a dedicated microphone key
        if event.keyCode == 0x40 {  // Microphone key on some keyboards
            if let shortcut = registeredShortcuts.first(where: {
                $0.trigger == .microphoneKey && $0.isEnabled
            }) {
                triggerShortcut(shortcut)
            }
        }
    }
    #endif

    // MARK: - Trigger Handling

    // periphery:ignore - Reserved: triggerShortcut(_:) instance method — reserved for future feature activation
    private func triggerShortcut(_ config: ShortcutConfig) {
        lastTriggeredShortcut = config
        onShortcutTriggered?(config.action)
    // periphery:ignore - Reserved: triggerShortcut(_:) instance method reserved for future feature activation
    }

    // periphery:ignore - Reserved: triggerAction(_:) instance method — reserved for future feature activation
    /// Manually trigger an action (for external callers like ActionButton)
    func triggerAction(_ action: HardwareShortcutAction) {
        onShortcutTriggered?(action)
    // periphery:ignore - Reserved: triggerAction(_:) instance method reserved for future feature activation
    }

    // MARK: - Persistence

    private func loadShortcuts() {
        guard let data = UserDefaults.standard.data(forKey: "hardwareShortcuts") else {
            registeredShortcuts = getDefaultShortcuts()
            return
        }
        do {
            registeredShortcuts = try JSONDecoder().decode([ShortcutConfig].self, from: data)
        } catch {
            logger.error("Failed to decode hardware shortcuts: \(error.localizedDescription)")
            registeredShortcuts = getDefaultShortcuts()
        }
    }

    private func saveShortcuts() {
        // periphery:ignore - Reserved: saveShortcuts() instance method reserved for future feature activation
        do {
            let data = try JSONEncoder().encode(registeredShortcuts)
            UserDefaults.standard.set(data, forKey: "hardwareShortcuts")
        } catch {
            logger.error("Failed to encode hardware shortcuts: \(error.localizedDescription)")
        }
    }
}

// MARK: - Key Code Reference

#if os(macOS)
// periphery:ignore - Reserved: MacKeyCode type reserved for future feature activation
/// Common key codes for macOS
enum MacKeyCode: Int {
    case space = 49
    case returnKey = 36
    case tab = 48
    case escape = 53
    case delete = 51
    case f1 = 122
    case f2 = 120
    case f3 = 99
    case f4 = 118
    case f5 = 96
    case f6 = 97
    case f7 = 98
    case f8 = 100
    case f9 = 101
    case f10 = 109
    case f11 = 103
    case f12 = 111
    case a = 0
    case s = 1
    case d = 2
    case t = 17

    var displayName: String {
        switch self {
        case .space: "Space"
        case .returnKey: "Return"
        case .tab: "Tab"
        case .escape: "Escape"
        case .delete: "Delete"
        case .f1: "F1"
        case .f2: "F2"
        case .f3: "F3"
        case .f4: "F4"
        case .f5: "F5"
        case .f6: "F6"
        case .f7: "F7"
        case .f8: "F8"
        case .f9: "F9"
        case .f10: "F10"
        case .f11: "F11"
        case .f12: "F12"
        case .a: "A"
        case .s: "S"
        case .d: "D"
        case .t: "T"
        }
    }
}
#endif
