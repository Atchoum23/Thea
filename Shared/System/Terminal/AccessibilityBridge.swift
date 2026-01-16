#if os(macOS)
import AppKit
import ApplicationServices
import Foundation

/// Bridge for reading Terminal content via macOS Accessibility API
/// Provides an alternative to AppleScript for deeper Terminal access
struct AccessibilityBridge {
    enum AccessibilityError: LocalizedError {
        case accessDenied
        case terminalNotFound
        case noFocusedWindow
        case elementNotFound
        case attributeReadFailed

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Accessibility access is denied. Please grant access in System Preferences > Security & Privacy > Privacy > Accessibility"
            case .terminalNotFound:
                return "Terminal.app is not running"
            case .noFocusedWindow:
                return "No Terminal window is focused"
            case .elementNotFound:
                return "Could not find Terminal text element"
            case .attributeReadFailed:
                return "Failed to read text attribute from Terminal"
            }
        }
    }

    // MARK: - Permission Check

    /// Check if accessibility access is granted
    nonisolated static func isAccessibilityEnabled() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request accessibility access (shows system prompt)
    nonisolated static func requestAccessibilityAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Terminal Reading

    /// Read text content from Terminal.app using Accessibility API
    static func readTerminalText() throws -> String {
        guard isAccessibilityEnabled() else {
            throw AccessibilityError.accessDenied
        }

        guard let terminalApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.Terminal"
        }) else {
            throw AccessibilityError.terminalNotFound
        }

        let appElement = AXUIElementCreateApplication(terminalApp.processIdentifier)

        // Get focused window
        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard windowResult == .success, let window = focusedWindow else {
            throw AccessibilityError.noFocusedWindow
        }

        // Find the text area (scroll area > text area)
        // swiftlint:disable:next force_cast
        let windowElement = window as! AXUIElement
        if let textContent = try? findTextContent(in: windowElement) {
            return textContent
        }

        throw AccessibilityError.elementNotFound
    }

    /// Read selected text from Terminal
    static func readSelectedText() throws -> String? {
        guard isAccessibilityEnabled() else {
            throw AccessibilityError.accessDenied
        }

        guard let terminalApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.Terminal"
        }) else {
            throw AccessibilityError.terminalNotFound
        }

        let appElement = AXUIElementCreateApplication(terminalApp.processIdentifier)

        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard result == .success, let element = focusedElement else {
            return nil
        }

        var selectedText: CFTypeRef?
        // swiftlint:disable:next force_cast
        let axElement = element as! AXUIElement
        let textResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedText)

        if textResult == .success, let text = selectedText as? String {
            return text
        }

        return nil
    }

    /// Get Terminal window bounds
    static func getTerminalWindowBounds() throws -> CGRect? {
        guard isAccessibilityEnabled() else {
            throw AccessibilityError.accessDenied
        }

        guard let terminalApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.Terminal"
        }) else {
            throw AccessibilityError.terminalNotFound
        }

        let appElement = AXUIElementCreateApplication(terminalApp.processIdentifier)

        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard windowResult == .success, let windowRef = focusedWindow else {
            throw AccessibilityError.noFocusedWindow
        }

        // swiftlint:disable:next force_cast
        let window = windowRef as! AXUIElement

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)

        var position = CGPoint.zero
        var size = CGSize.zero

        if let posRef = positionValue {
            // swiftlint:disable:next force_cast
            let posValue = posRef as! AXValue
            AXValueGetValue(posValue, .cgPoint, &position)
        }

        if let szRef = sizeValue {
            // swiftlint:disable:next force_cast
            let szValue = szRef as! AXValue
            AXValueGetValue(szValue, .cgSize, &size)
        }

        return CGRect(origin: position, size: size)
    }

    // MARK: - Private Helpers

    private static func findTextContent(in element: AXUIElement) throws -> String? {
        // Try to get value directly
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
           let text = value as? String {
            return text
        }

        // Get role
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        // If this is a text area, try to get its content
        if let roleString = role as? String,
           roleString == kAXTextAreaRole as String || roleString == kAXScrollAreaRole as String {
            // Try getting the string value
            var stringValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &stringValue) == .success,
               let text = stringValue as? String {
                return text
            }
        }

        // Recursively search children
        var children: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
           let childrenArray = children as? [AXUIElement] {
            for child in childrenArray {
                if let text = try? findTextContent(in: child) {
                    return text
                }
            }
        }

        return nil
    }

    /// Get all children elements of a given element
    static func getChildren(of element: AXUIElement) -> [AXUIElement] {
        var children: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success {
            return children as? [AXUIElement] ?? []
        }
        return []
    }

    /// Get the role of an element
    static func getRole(of element: AXUIElement) -> String? {
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success {
            return role as? String
        }
        return nil
    }

    /// Get the title of an element
    static func getTitle(of element: AXUIElement) -> String? {
        var title: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title) == .success {
            return title as? String
        }
        return nil
    }
}

// MARK: - Accessibility Monitoring

/// Monitor for Terminal content changes using Accessibility observers
final class TerminalAccessibilityMonitor {
    private var observer: AXObserver?
    private var terminalPID: pid_t?
    fileprivate var onChange: ((String) -> Void)?

    func startMonitoring(onChange: @escaping (String) -> Void) throws {
        guard AccessibilityBridge.isAccessibilityEnabled() else {
            throw AccessibilityBridge.AccessibilityError.accessDenied
        }

        guard let terminalApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.Terminal"
        }) else {
            throw AccessibilityBridge.AccessibilityError.terminalNotFound
        }

        self.onChange = onChange
        self.terminalPID = terminalApp.processIdentifier

        var observer: AXObserver?
        let result = AXObserverCreate(terminalApp.processIdentifier, observerCallback, &observer)

        guard result == .success, let obs = observer else {
            throw AccessibilityBridge.AccessibilityError.accessDenied
        }

        self.observer = obs

        let appElement = AXUIElementCreateApplication(terminalApp.processIdentifier)

        // Observe value changes
        AXObserverAddNotification(obs, appElement, kAXValueChangedNotification as CFString, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)
    }

    func stopMonitoring() {
        if let observer = observer {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        onChange = nil
    }

    deinit {
        stopMonitoring()
    }
}

private func observerCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let monitor = Unmanaged<TerminalAccessibilityMonitor>.fromOpaque(refcon).takeUnretainedValue()

    // Read the new content
    if let content = try? AccessibilityBridge.readTerminalText() {
        DispatchQueue.main.async {
            monitor.onChange?(content)
        }
    }
}
#endif
