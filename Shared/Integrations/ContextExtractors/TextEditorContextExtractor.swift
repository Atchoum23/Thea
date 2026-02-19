import AppKit
import ApplicationServices
import Foundation
import os.log

private let textEditorLogger = Logger(subsystem: "ai.thea.app", category: "TextEditorContextExtractor")

// periphery:ignore - Reserved: textEditorLogger global var reserved for future feature activation

// periphery:ignore - Reserved: TextEditorContextExtractor type reserved for future feature activation
/// Extracts context from Notes/TextEdit using Accessibility API
enum TextEditorContextExtractor {
    /// Extract context from frontmost text editor (Notes or TextEdit)
    static func extract(
        includeSelectedText: Bool,
        includeWindowContent: Bool
    ) async -> AppContext? {
        // Try Notes first, then TextEdit
        let editorBundles = [
            "com.apple.Notes",
            "com.apple.TextEdit"
        ]

        for bundleID in editorBundles {
            if let editorApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == bundleID && $0.isActive
            }) {
                return await extractFromEditor(
                    app: editorApp,
                    bundleID: bundleID,
                    includeSelectedText: includeSelectedText,
                    includeWindowContent: includeWindowContent
                )
            }
        }

        textEditorLogger.debug("No text editor app is frontmost")
        return nil
    }

    // MARK: - Private Helpers

    private static func extractFromEditor(
        app: NSRunningApplication,
        bundleID: String,
        includeSelectedText: Bool,
        includeWindowContent: Bool
    ) async -> AppContext? {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Get window title (note name or document name)
        var windowTitle = app.localizedName ?? "Document"
        if let title = getWindowTitle(appElement) {
            windowTitle = title
        }

        // Get selected text
        var selectedText: String?
        if includeSelectedText {
            selectedText = getSelectedText(appElement)
        }

        // Get visible content (document text)
        var visibleContent: String?
        if includeWindowContent {
            visibleContent = getDocumentContent(appElement)
        }

        // Build metadata
        var metadata: [String: String] = [:]

        // Extract note/document name from window title
        // Notes format: "Note Title"
        // TextEdit format: "Document Name — Edited" or just "Document Name"
        let documentName = windowTitle
            .replacingOccurrences(of: " — Edited", with: "")
            .trimmingCharacters(in: .whitespaces)

        if !documentName.isEmpty && documentName != app.localizedName {
            metadata["Document"] = documentName
        }

        let appName = app.localizedName ?? bundleID

        return AppContext(
            bundleID: bundleID,
            appName: appName,
            windowTitle: windowTitle,
            selectedText: selectedText,
            visibleContent: visibleContent,
            cursorPosition: nil, // Can be enhanced later if needed
            additionalMetadata: metadata.isEmpty ? nil : metadata
        )
    }

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
            textEditorLogger.debug("Could not get focused UI element")
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
            textEditorLogger.debug("No selected text")
            return nil
        }

        textEditorLogger.debug("Extracted \(text.count) chars of selected text")
        return text
    }

    private static func getDocumentContent(_ appElement: AXUIElement) -> String? {
        // Find focused UI element (text area)
        var focusedElement: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else { return nil }

        // Get value (entire document content)
        var value: CFTypeRef?
        result = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXValueAttribute as CFString,
            &value
        )

        guard result == .success, let text = value as? String else {
            textEditorLogger.debug("Could not extract document content")
            return nil
        }

        // Limit to first 10,000 characters to avoid token bloat
        let truncated = String(text.prefix(10000))
        textEditorLogger.debug("Extracted \(truncated.count) chars of document content")

        return truncated
    }
}
