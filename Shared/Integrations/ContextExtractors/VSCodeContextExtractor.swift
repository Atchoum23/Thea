import AppKit
import ApplicationServices
import Foundation
import os.log

private let vscodeLogger = Logger(subsystem: "ai.thea.app", category: "VSCodeContextExtractor")

// periphery:ignore - Reserved: vscodeLogger global var reserved for future feature activation

// periphery:ignore - Reserved: VSCodeContextExtractor type reserved for future feature activation
/// Extracts context from VS Code using Accessibility API
enum VSCodeContextExtractor {
    /// Extract context from frontmost VS Code window
    static func extract(
        includeSelectedText: Bool,
        includeWindowContent: Bool
    ) async -> AppContext? {
        guard let vscodeApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.microsoft.VSCode" && $0.isActive
        }) else {
            vscodeLogger.debug("VS Code not frontmost")
            return nil
        }

        let pid = vscodeApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Get window title
        var windowTitle = "Visual Studio Code"
        if let title = getWindowTitle(appElement) {
            windowTitle = title
        }

        // Extract file path from window title (e.g., "● ChatManager.swift - Thea - Visual Studio Code")
        var filePath: String?
        var isUnsaved = false

        if windowTitle.hasPrefix("●") {
            isUnsaved = true
        }

        // Parse title: "● ChatManager.swift - Thea - Visual Studio Code"
        let components = windowTitle.replacingOccurrences(of: "●", with: "").trimmingCharacters(in: .whitespaces).components(separatedBy: " - ")
        if let firstPart = components.first?.trimmingCharacters(in: .whitespaces) {
            filePath = firstPart
        }

        // Get selected text
        var selectedText: String?
        if includeSelectedText {
            selectedText = getSelectedText(appElement)
        }

        // Get cursor position
        var cursorPosition: AppContext.CursorPosition?
        if let position = getCursorPosition(appElement) {
            cursorPosition = position
        }

        // Get visible content (editor text)
        var visibleContent: String?
        if includeWindowContent {
            visibleContent = getVisibleCode(appElement)
        }

        // Build metadata
        var metadata: [String: String] = [:]
        if let filePath = filePath {
            metadata["File"] = filePath
        }
        if isUnsaved {
            metadata["Unsaved Changes"] = "Yes"
        }

        return AppContext(
            bundleID: "com.microsoft.VSCode",
            appName: "Visual Studio Code",
            windowTitle: windowTitle,
            selectedText: selectedText,
            visibleContent: visibleContent,
            cursorPosition: cursorPosition,
            additionalMetadata: metadata.isEmpty ? nil : metadata
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
        // Find focused UI element (text editor)
        var focusedElement: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else {
            vscodeLogger.debug("Could not get focused UI element")
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
            vscodeLogger.debug("No selected text")
            return nil
        }

        vscodeLogger.debug("Extracted \(text.count) chars of selected text")
        return text
    }

    private static func getCursorPosition(_ appElement: AXUIElement) -> AppContext.CursorPosition? {
        // VS Code's Accessibility API support varies
        // Try to get line number if available

        var focusedElement: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else { return nil }

        // Try to get insertion point line number
        var insertionPoint: CFTypeRef?
        result = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXInsertionPointLineNumberAttribute as CFString,
            &insertionPoint
        )

        if result == .success, let lineNumber = insertionPoint as? Int {
            // Try to get selected text range for column calculation
            var selectedRange: CFTypeRef?
            let rangeResult = AXUIElementCopyAttributeValue(
                element as! AXUIElement,
                kAXSelectedTextRangeAttribute as CFString,
                &selectedRange
            )

            var column = 0
            if rangeResult == .success, let range = selectedRange {
                var rangeValue = CFRange(location: 0, length: 0)
                if AXValueGetValue(range as! AXValue, .cfRange, &rangeValue) {
                    // Simple approximation: use range location as column
                    // (This isn't perfect but better than nothing)
                    column = rangeValue.location
                }
            }

            return AppContext.CursorPosition(line: lineNumber, column: column)
        }

        return nil
    }

    private static func getVisibleCode(_ appElement: AXUIElement) -> String? {
        // Find focused UI element (editor)
        var focusedElement: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else { return nil }

        // Get value (entire text content)
        var value: CFTypeRef?
        result = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXValueAttribute as CFString,
            &value
        )

        guard result == .success, let text = value as? String else {
            vscodeLogger.debug("Could not extract editor text")
            return nil
        }

        // Limit to first 10,000 characters to avoid token bloat
        let truncated = String(text.prefix(10000))
        vscodeLogger.debug("Extracted \(truncated.count) chars of code")

        return truncated
    }
}
