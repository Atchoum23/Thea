import AppKit
import ApplicationServices
import Foundation
import os.log

private let genericLogger = Logger(subsystem: "ai.thea.app", category: "GenericContextExtractor")

// periphery:ignore - Reserved: genericLogger global var reserved for future feature activation

/// Generic fallback context extractor for apps without specific handlers
// periphery:ignore - Reserved: GenericContextExtractor type reserved for future feature activation
enum GenericContextExtractor {
    /// Extract basic context from any app using Accessibility API
    static func extract(
        app: NSRunningApplication,
        includeSelectedText: Bool,
        includeWindowContent: Bool
    ) async -> AppContext? {
        guard let bundleID = app.bundleIdentifier else { return nil }

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Get window title
        var windowTitle = app.localizedName ?? "Unknown"
        if let title = getWindowTitle(appElement) {
            windowTitle = title
        }

        // Get selected text
        var selectedText: String?
        if includeSelectedText {
            selectedText = getSelectedText(appElement)
        }

        // Get visible content (generic text extraction)
        var visibleContent: String?
        if includeWindowContent {
            visibleContent = getVisibleText(appElement)
        }

        let appName = app.localizedName ?? bundleID

        return AppContext(
            bundleID: bundleID,
            appName: appName,
            windowTitle: windowTitle,
            selectedText: selectedText,
            visibleContent: visibleContent,
            cursorPosition: nil,
            additionalMetadata: nil
        )
    }

    // MARK: - Private Helpers

    private static func getWindowTitle(_ appElement: AXUIElement) -> String? {
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard result == .success, let window = focusedWindow else { return nil }

        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &title
        )

        guard titleResult == .success, let titleString = title as? String else { return nil }

        return titleString
    }

    private static func getSelectedText(_ appElement: AXUIElement) -> String? {
        // Find focused UI element
        var focusedElement: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else {
            genericLogger.debug("Could not get focused UI element")
            return nil
        }

        // Get selected text
        var selectedTextValue: CFTypeRef?
        result = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )

        guard result == .success, let text = selectedTextValue as? String, !text.isEmpty else {
            genericLogger.debug("No selected text")
            return nil
        }

        genericLogger.debug("Extracted \(text.count) chars of selected text")
        return text
    }

    private static func getVisibleText(_ appElement: AXUIElement) -> String? {
        // Find focused UI element
        var focusedElement: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else { return nil }

        // Try to get value (text content)
        var value: CFTypeRef?
        result = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXValueAttribute as CFString,
            &value
        )

        if result == .success, let text = value as? String, !text.isEmpty {
            // Limit to first 5,000 characters
            let truncated = String(text.prefix(5000))
            genericLogger.debug("Extracted \(truncated.count) chars of visible text")
            return truncated
        }

        // Fallback: Try to get description
        var description: CFTypeRef?
        result = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXDescriptionAttribute as CFString,
            &description
        )

        if result == .success, let desc = description as? String, !desc.isEmpty {
            genericLogger.debug("Extracted description: \(desc)")
            return desc
        }

        genericLogger.debug("Could not extract visible text")
        return nil
    }
}
