import AppKit
import ApplicationServices
import Foundation
import os.log

private let safariLogger = Logger(subsystem: "ai.thea.app", category: "SafariContextExtractor")

// periphery:ignore - Reserved: safariLogger global var reserved for future feature activation

// periphery:ignore - Reserved: SafariContextExtractor type reserved for future feature activation
/// Extracts context from Safari using AppleScript and Accessibility API
enum SafariContextExtractor {
    /// Extract context from frontmost Safari window
    static func extract(
        includeSelectedText: Bool,
        includeWindowContent: Bool
    ) async -> AppContext? {
        guard let safariApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.Safari" && $0.isActive
        }) else {
            safariLogger.debug("Safari not frontmost")
            return nil
        }

        let pid = safariApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Get window title (page title)
        var windowTitle = "Safari"
        if let title = getWindowTitle(appElement) {
            windowTitle = title
        }

        // Get URL and selected text via AppleScript (more reliable than Accessibility API for Safari)
        var url: String?
        var selectedText: String?

        if let scriptResult = await executeAppleScript() {
            url = scriptResult.url
            if includeSelectedText {
                selectedText = scriptResult.selectedText
            }
        }

        // Fallback: try Accessibility API for selected text if AppleScript failed
        if includeSelectedText && selectedText == nil {
            selectedText = getSelectedTextViaAccessibility(appElement)
        }

        // Build metadata
        var metadata: [String: String] = [:]
        if let url = url, !url.isEmpty {
            metadata["URL"] = url
        }

        // Visible content: For Safari, we don't extract full page content
        // (would require complex DOM traversal or web scraping)
        // Instead, rely on URL and selected text

        return AppContext(
            bundleID: "com.apple.Safari",
            appName: "Safari",
            windowTitle: windowTitle,
            selectedText: selectedText,
            visibleContent: nil, // Not extracting full page content
            cursorPosition: nil,
            additionalMetadata: metadata.isEmpty ? nil : metadata
        )
    }

    // MARK: - AppleScript Execution

    private struct SafariScriptResult {
        let url: String?
        let selectedText: String?
    }

    private static func executeAppleScript() async -> SafariScriptResult? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let script = """
                tell application "Safari"
                    if (count of windows) > 0 then
                        set currentTab to current tab of front window
                        set theURL to URL of currentTab

                        try
                            set selectedText to (do JavaScript "window.getSelection().toString()" in currentTab)
                        on error
                            set selectedText to ""
                        end try

                        return {theURL, selectedText}
                    else
                        return {"", ""}
                    end if
                end tell
                """

                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let output = scriptObject.executeAndReturnError(&error)

                    if let error = error {
                        safariLogger.error("AppleScript error: \(String(describing: error))")
                        continuation.resume(returning: nil)
                        return
                    }

                    // Parse output: {URL, selectedText}
                    if output.numberOfItems >= 2 {
                        let url = output.atIndex(1)?.stringValue
                        let selectedText = output.atIndex(2)?.stringValue

                        let result = SafariScriptResult(
                            url: url,
                            selectedText: selectedText?.isEmpty == true ? nil : selectedText
                        )

                        continuation.resume(returning: result)
                        return
                    }
                }

                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Accessibility API Fallback

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

    private static func getSelectedTextViaAccessibility(_ appElement: AXUIElement) -> String? {
        // Find focused UI element
        var focusedElement: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else {
            safariLogger.debug("Could not get focused UI element")
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
            safariLogger.debug("No selected text via Accessibility API")
            return nil
        }

        safariLogger.debug("Extracted \(text.count) chars of selected text via Accessibility API")
        return text
    }
}
