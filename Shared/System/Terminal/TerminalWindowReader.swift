#if os(macOS)
    import AppKit
    import Foundation

    /// Reads content from Terminal.app windows using AppleScript
    /// This is the core component for "Work with Apps" style Terminal reading
    // @unchecked Sendable: stateless — uses AppleScript for each read call, no mutable state
    final class TerminalWindowReader: @unchecked Sendable {
        enum ReaderError: LocalizedError {
            case terminalNotRunning
            case noWindowsOpen
            case appleScriptError(String)
            case accessibilityDenied

            var errorDescription: String? {
                switch self {
                case .terminalNotRunning:
                    "Terminal.app is not running"
                case .noWindowsOpen:
                    "No Terminal windows are open"
                case let .appleScriptError(message):
                    "AppleScript error: \(message)"
                case .accessibilityDenied:
                    "Accessibility access is required to read Terminal content"
                }
            }
        }

        // MARK: - Window Information

        /// Get list of all Terminal windows and their tabs
        func getWindowList() async throws -> [WindowInfo] {
            let script = """
            tell application "Terminal"
                set windowList to {}
                set windowIndex to 1
                repeat with w in windows
                    set tabList to {}
                    set tabIndex to 1
                    repeat with t in tabs of w
                        set tabInfo to {tabIndex:tabIndex, busy:busy of t, processes:(processes of t), ttyName:(tty of t)}
                        set end of tabList to tabInfo
                        set tabIndex to tabIndex + 1
                    end repeat
                    set windowInfo to {windowIndex:windowIndex, tabCount:(count tabs of w), selectedTab:(index of selected tab of w), tabs:tabList, windowName:(name of w)}
                    set end of windowList to windowInfo
                    set windowIndex to windowIndex + 1
                end repeat
                return windowList
            end tell
            """

            let result = try await runAppleScript(script)
            return parseWindowList(result)
        }

        // MARK: - Content Reading

        /// Read the content of the front Terminal window's selected tab
        func readFrontWindowContent() async throws -> String {
            let script = """
            tell application "Terminal"
                if (count windows) > 0 then
                    return contents of selected tab of front window
                else
                    error "No Terminal windows open"
                end if
            end tell
            """

            guard let result = try await runAppleScript(script) as? String else {
                throw ReaderError.noWindowsOpen
            }
            return result
        }

        /// Read content from a specific window and tab
        func readContent(windowIndex: Int, tabIndex: Int) async throws -> String {
            let script = """
            tell application "Terminal"
                if (count windows) >= \(windowIndex) then
                    set targetWindow to window \(windowIndex)
                    if (count tabs of targetWindow) >= \(tabIndex) then
                        return contents of tab \(tabIndex) of targetWindow
                    else
                        error "Tab index out of range"
                    end if
                else
                    error "Window index out of range"
                end if
            end tell
            """

            guard let result = try await runAppleScript(script) as? String else {
                throw ReaderError.appleScriptError("Failed to read content")
            }
            return result
        }

        /// Read the full scrollback history (history buffer) from front window
        func readHistory() async throws -> String {
            let script = """
            tell application "Terminal"
                if (count windows) > 0 then
                    return history of selected tab of front window
                else
                    error "No Terminal windows open"
                end if
            end tell
            """

            guard let result = try await runAppleScript(script) as? String else {
                throw ReaderError.noWindowsOpen
            }
            return result
        }

        /// Read history from a specific window/tab
        func readHistory(windowIndex: Int, tabIndex: Int) async throws -> String {
            let script = """
            tell application "Terminal"
                if (count windows) >= \(windowIndex) then
                    set targetWindow to window \(windowIndex)
                    if (count tabs of targetWindow) >= \(tabIndex) then
                        return history of tab \(tabIndex) of targetWindow
                    else
                        error "Tab index out of range"
                    end if
                else
                    error "Window index out of range"
                end if
            end tell
            """

            guard let result = try await runAppleScript(script) as? String else {
                throw ReaderError.appleScriptError("Failed to read history")
            }
            return result
        }

        // MARK: - State Queries

        /// Check if Terminal.app is running
        func isTerminalRunning() -> Bool {
            NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Terminal" }
        }

        /// Check if the front Terminal window's current tab is busy (command running)
        func isBusy() async throws -> Bool {
            let script = """
            tell application "Terminal"
                if (count windows) > 0 then
                    return busy of selected tab of front window
                else
                    return false
                end if
            end tell
            """

            return try await runAppleScript(script) as? Bool ?? false
        }

        /// Check if a specific tab is busy
        func isBusy(windowIndex: Int, tabIndex: Int) async throws -> Bool {
            let script = """
            tell application "Terminal"
                if (count windows) >= \(windowIndex) then
                    set targetWindow to window \(windowIndex)
                    if (count tabs of targetWindow) >= \(tabIndex) then
                        return busy of tab \(tabIndex) of targetWindow
                    end if
                end if
                return false
            end tell
            """

            return try await runAppleScript(script) as? Bool ?? false
        }

        /// Get the current processes running in the front window's tab
        func getCurrentProcesses() async throws -> [String] {
            let script = """
            tell application "Terminal"
                if (count windows) > 0 then
                    return processes of selected tab of front window
                else
                    return {}
                end if
            end tell
            """

            let result = try await runAppleScript(script)
            if let processes = result as? [String] {
                return processes
            }
            return []
        }

        /// Get the TTY device name for the current tab
        func getTTY() async throws -> String {
            let script = """
            tell application "Terminal"
                if (count windows) > 0 then
                    return tty of selected tab of front window
                else
                    return ""
                end if
            end tell
            """

            return try await runAppleScript(script) as? String ?? ""
        }

        /// Get the current working directory (by reading PWD or using lsof)
        func getCurrentDirectory() async throws -> URL? {
            // Try to get PWD from the last prompt or use lsof
            let tty = try await getTTY()
            guard !tty.isEmpty else { return nil }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            process.arguments = ["-a", "-p", "$(pgrep -t \(tty))", "-d", "cwd", "-F", "n"]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines where line.hasPrefix("n") {
                        let path = String(line.dropFirst())
                        return URL(fileURLWithPath: path)
                    }
                }
            } catch {
                // Fallback - couldn't determine directory
            }

            return nil
        }

        // MARK: - Private Helpers

        private func runAppleScript(_ source: String) async throws -> Any? {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    var error: NSDictionary?
                    let script = NSAppleScript(source: source)
                    let result = script?.executeAndReturnError(&error)

                    if let error {
                        let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                        continuation.resume(throwing: ReaderError.appleScriptError(message))
                        return
                    }

                    if let result {
                        continuation.resume(returning: self.convertAppleScriptResult(result))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }

        private func convertAppleScriptResult(_ descriptor: NSAppleEventDescriptor) -> Any? {
            switch descriptor.descriptorType {
            case typeTrue:
                return true
            case typeFalse:
                return false
            case typeSInt32, typeSInt16:
                return descriptor.int32Value
            case typeIEEE64BitFloatingPoint, typeIEEE32BitFloatingPoint:
                return descriptor.doubleValue
            case typeUnicodeText, typeUTF8Text, typeChar:
                return descriptor.stringValue
            case typeAEList:
                var array: [Any] = []
                for i in 1 ... descriptor.numberOfItems {
                    if let item = descriptor.atIndex(i) {
                        if let value = convertAppleScriptResult(item) {
                            array.append(value)
                        }
                    }
                }
                return array
            case typeAERecord:
                var dict: [String: Any] = [:]
                for i in 1 ... descriptor.numberOfItems {
                    if let item = descriptor.atIndex(i) {
                        let key = descriptor.keywordForDescriptor(at: i)
                        let keyString = String(format: "%c%c%c%c",
                                               (key >> 24) & 0xFF,
                                               (key >> 16) & 0xFF,
                                               (key >> 8) & 0xFF,
                                               key & 0xFF)
                        if let value = convertAppleScriptResult(item) {
                            dict[keyString] = value
                        }
                    }
                }
                return dict
            default:
                return descriptor.stringValue
            }
        }

        private func parseWindowList(_ result: Any?) -> [WindowInfo] {
            guard let list = result as? [[String: Any]] else { return [] }

            return list.compactMap { dict -> WindowInfo? in
                guard let index = dict["windowIndex"] as? Int,
                      let tabCount = dict["tabCount"] as? Int,
                      let selectedTab = dict["selectedTab"] as? Int,
                      let name = dict["windowName"] as? String
                else {
                    return nil
                }

                var tabs: [TabInfo] = []
                if let tabList = dict["tabs"] as? [[String: Any]] {
                    for tabDict in tabList {
                        if let tabIndex = tabDict["tabIndex"] as? Int,
                           let busy = tabDict["busy"] as? Bool,
                           let processes = tabDict["processes"] as? [String],
                           let tty = tabDict["ttyName"] as? String
                        {
                            tabs.append(TabInfo(index: tabIndex, isBusy: busy, processes: processes, tty: tty))
                        }
                    }
                }

                return WindowInfo(index: index, name: name, tabCount: tabCount, selectedTab: selectedTab, tabs: tabs)
            }
        }
    }

    // MARK: - Supporting Types

    struct WindowInfo: Identifiable {
        var id: Int { index }
        let index: Int
        let name: String
        let tabCount: Int
        let selectedTab: Int
        let tabs: [TabInfo]
    }

    struct TabInfo: Identifiable {
        var id: Int { index }
        let index: Int
        let isBusy: Bool
        let processes: [String]
        let tty: String
    }
#endif
