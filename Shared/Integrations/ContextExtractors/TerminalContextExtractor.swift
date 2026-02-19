import AppKit
import ApplicationServices
import Foundation
import os.log

private let terminalLogger = Logger(subsystem: "ai.thea.app", category: "TerminalContextExtractor")

// periphery:ignore - Reserved: terminalLogger global var reserved for future feature activation

// periphery:ignore - Reserved: TerminalContextExtractor type reserved for future feature activation
/// Extracts context from Terminal/iTerm/Warp using Accessibility API
enum TerminalContextExtractor {
    /// Extract context from frontmost terminal window
    static func extract(
        includeSelectedText: Bool,
        includeWindowContent: Bool
    ) async -> AppContext? {
        // Try each terminal app
        let terminalBundles = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "dev.warp.Warp-Stable"
        ]

        for bundleID in terminalBundles {
            if let terminalApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == bundleID && $0.isActive
            }) {
                return await extractFromTerminal(
                    app: terminalApp,
                    bundleID: bundleID,
                    includeSelectedText: includeSelectedText,
                    includeWindowContent: includeWindowContent
                )
            }
        }

        terminalLogger.debug("No terminal app is frontmost")
        return nil
    }

    // MARK: - Private Helpers

    private static func extractFromTerminal(
        app: NSRunningApplication,
        bundleID: String,
        includeSelectedText: Bool,
        includeWindowContent: Bool
    ) async -> AppContext? {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Get window title
        var windowTitle = app.localizedName ?? "Terminal"
        if let title = getWindowTitle(appElement) {
            windowTitle = title
        }

        // Extract current directory from window title if present
        // Terminal.app format: "user@host: ~/path/to/dir"
        // iTerm format: similar or just shows path
        var currentDirectory: String?
        if windowTitle.contains(":") {
            let parts = windowTitle.components(separatedBy: ":")
            if parts.count >= 2 {
                let pathPart = parts[1].trimmingCharacters(in: .whitespaces)
                if !pathPart.isEmpty {
                    currentDirectory = pathPart
                }
            }
        }

        // Get selected text
        var selectedText: String?
        if includeSelectedText {
            selectedText = getSelectedText(appElement)
        }

        // Get visible terminal output
        var visibleContent: String?
        if includeWindowContent {
            visibleContent = getVisibleOutput(appElement)
        }

        // Build metadata
        var metadata: [String: String] = [:]
        if let currentDirectory = currentDirectory {
            metadata["Current Directory"] = currentDirectory
        }

        // Try to extract last command from visible output
        if let content = visibleContent, !content.isEmpty {
            if let lastCommand = extractLastCommand(from: content) {
                metadata["Last Command"] = lastCommand
            }
        }

        let appName = app.localizedName ?? bundleID

        return AppContext(
            bundleID: bundleID,
            appName: appName,
            windowTitle: windowTitle,
            selectedText: selectedText,
            visibleContent: visibleContent,
            cursorPosition: nil, // Terminals don't have line/column cursor position in same way
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
            terminalLogger.debug("Could not get focused UI element")
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
            terminalLogger.debug("No selected text")
            return nil
        }

        terminalLogger.debug("Extracted \(text.count) chars of selected text")
        return text
    }

    private static func getVisibleOutput(_ appElement: AXUIElement) -> String? {
        // Find focused UI element (terminal view)
        var focusedElement: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else { return nil }

        // Get value (visible terminal content)
        var value: CFTypeRef?
        result = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXValueAttribute as CFString,
            &value
        )

        guard result == .success, let text = value as? String else {
            terminalLogger.debug("Could not extract terminal output")
            return nil
        }

        // Get last 50 lines (or ~5000 chars max)
        let lines = text.components(separatedBy: .newlines)
        let recentLines = Array(lines.suffix(50))
        let recentOutput = recentLines.joined(separator: "\n")

        let truncated = String(recentOutput.prefix(5000))
        terminalLogger.debug("Extracted \(truncated.count) chars of terminal output")

        return truncated
    }

    private static func extractLastCommand(from output: String) -> String? {
        // Try to find the last prompt line (e.g., "$ command" or "user@host:~$ command")
        let lines = output.components(separatedBy: .newlines).reversed()

        for line in lines {
            // Look for common shell prompt patterns
            if line.contains("$") || line.contains("%") || line.contains("#") {
                // Extract command after prompt
                if let dollarIndex = line.lastIndex(of: "$") {
                    let commandStart = line.index(after: dollarIndex)
                    let command = String(line[commandStart...]).trimmingCharacters(in: .whitespaces)
                    if !command.isEmpty {
                        return command
                    }
                } else if let percentIndex = line.lastIndex(of: "%") {
                    let commandStart = line.index(after: percentIndex)
                    let command = String(line[commandStart...]).trimmingCharacters(in: .whitespaces)
                    if !command.isEmpty {
                        return command
                    }
                }
            }
        }

        return nil
    }
}
