import AppKit
import ApplicationServices
import Foundation
import os.log

private let xcodeLogger = Logger(subsystem: "ai.thea.app", category: "XcodeContextExtractor")

// periphery:ignore - Reserved: xcodeLogger global var reserved for future feature activation

// periphery:ignore - Reserved: XcodeContextExtractor type reserved for future feature activation
/// Extracts context from Xcode using Accessibility API
enum XcodeContextExtractor {
    /// Extract context from frontmost Xcode window
    static func extract(
        includeSelectedText: Bool,
        includeWindowContent: Bool
    ) async -> AppContext? {
        guard let xcodeApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.dt.Xcode" && $0.isActive
        }) else {
            xcodeLogger.debug("Xcode not frontmost")
            return nil
        }

        let pid = xcodeApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Get window title
        var windowTitle = "Xcode"
        if let title = getWindowTitle(appElement) {
            windowTitle = title
        }

        // Try to extract file path from window title (e.g., "ChatManager.swift — Thea")
        var filePath: String?
        if let firstPart = windowTitle.components(separatedBy: " — ").first {
            filePath = firstPart
        }

        // Get selected text using Accessibility API
        var selectedText: String?
        if includeSelectedText {
            selectedText = getSelectedText(appElement)
        }

        // Get cursor position
        var cursorPosition: AppContext.CursorPosition?
        if let position = getCursorPosition(appElement) {
            cursorPosition = position
        }

        // Get visible content (source editor text)
        var visibleContent: String?
        if includeWindowContent {
            visibleContent = getVisibleSourceCode(appElement)
        }

        // Try to extract build errors from Issue Navigator
        var metadata: [String: String] = [:]
        if let errors = getBuildErrors(appElement) {
            metadata["Build Errors"] = errors
        }

        if let filePath = filePath {
            metadata["File"] = filePath
        }

        return AppContext(
            bundleID: "com.apple.dt.Xcode",
            appName: "Xcode",
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
        // Find the focused UI element (text editor)
        var focusedElement: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else {
            xcodeLogger.debug("Could not get focused UI element")
            return nil
        }

        // Get selected text range
        var selectedTextValue: CFTypeRef?
        result = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )

        guard result == .success, let text = selectedTextValue as? String, !text.isEmpty else {
            xcodeLogger.debug("No selected text")
            return nil
        }

        xcodeLogger.debug("Extracted \(text.count) chars of selected text")
        return text
    }

    private static func getCursorPosition(_ appElement: AXUIElement) -> AppContext.CursorPosition? {
        // Find focused UI element
        var focusedElement: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else { return nil }

        // Get insertion point (cursor position as character index)
        var insertionPoint: CFTypeRef?
        result = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXInsertionPointLineNumberAttribute as CFString,
            &insertionPoint
        )

        if result == .success, let lineNumber = insertionPoint as? Int {
            // Try to get column as well
            var selectedRange: CFTypeRef?
            let rangeResult = AXUIElementCopyAttributeValue(
                element as! AXUIElement,
                kAXSelectedTextRangeAttribute as CFString,
                &selectedRange
            )

            var column = 0
            if rangeResult == .success, let range = selectedRange {
                // Extract column from range
                var rangeValue = CFRange(location: 0, length: 0)
                if AXValueGetValue(range as! AXValue, .cfRange, &rangeValue) {
                    // Get line start to calculate column
                    var lineText: CFTypeRef?
                    var lineRange = CFRange(location: 0, length: rangeValue.location)
                    let lineRangeValue = AXValueCreate(.cfRange, &lineRange)

                    let lineResult = AXUIElementCopyParameterizedAttributeValue(
                        element as! AXUIElement,
                        kAXStringForRangeParameterizedAttribute as CFString,
                        lineRangeValue!,
                        &lineText
                    )

                    if lineResult == .success, let textBeforeCursor = lineText as? String {
                        // Count chars from last newline
                        if let lastNewline = textBeforeCursor.lastIndex(of: "\n") {
                            column = textBeforeCursor.distance(from: lastNewline, to: textBeforeCursor.endIndex) - 1
                        } else {
                            column = textBeforeCursor.count
                        }
                    }
                }
            }

            return AppContext.CursorPosition(line: lineNumber, column: column)
        }

        return nil
    }

    private static func getVisibleSourceCode(_ appElement: AXUIElement) -> String? {
        // Find focused UI element (source editor)
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
            xcodeLogger.debug("Could not extract source code text")
            return nil
        }

        // Limit to first 10,000 characters to avoid token bloat
        let truncated = String(text.prefix(10000))
        xcodeLogger.debug("Extracted \(truncated.count) chars of source code")

        return truncated
    }

    private static func getBuildErrors(_ appElement: AXUIElement) -> String? {
        // Try to find Issue Navigator errors
        // This is complex because the UI structure varies
        // For now, return nil - can enhance later with more robust navigation

        // TODO: Navigate AX hierarchy to find Issue Navigator
        // and extract error messages if present

        return nil
    }
}
