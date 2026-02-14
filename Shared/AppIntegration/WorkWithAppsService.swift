//
//  WorkWithAppsService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
    import ApplicationServices

    // MARK: - Work With Apps Service

    /// Enhanced app automation service similar to ChatGPT's "Work with Apps"
    /// Provides deep integration with macOS applications for AI-assisted workflows
    @MainActor
    public class WorkWithAppsService: ObservableObject {
        public static let shared = WorkWithAppsService()

        // MARK: - Published State

        @Published public private(set) var connectedApps: [ConnectedApp] = []
        @Published public private(set) var activeApp: ConnectedApp?
        @Published public private(set) var recentActions: [AppAction] = []
        @Published public private(set) var isAccessibilityEnabled = false

        // MARK: - Observer Storage (Memory Leak Prevention)

        /// Stores notification observers for proper cleanup
        /// Using nonisolated(unsafe) to allow access in deinit
        nonisolated(unsafe) private var notificationObservers: [any NSObjectProtocol] = []

        // MARK: - Supported Apps

        private let supportedApps: [AppDefinition] = [
            AppDefinition(
                bundleId: "com.apple.finder",
                name: "Finder",
                icon: "folder",
                capabilities: [.fileOperations, .navigation, .selection],
                actions: ["open", "reveal", "copy", "move", "delete", "createFolder", "getSelection"]
            ),
            AppDefinition(
                bundleId: "com.apple.Safari",
                name: "Safari",
                icon: "safari",
                capabilities: [.webBrowsing, .readContent, .navigation],
                actions: ["openURL", "getCurrentURL", "getPageContent", "search", "goBack", "goForward"]
            ),
            AppDefinition(
                bundleId: "com.apple.mail",
                name: "Mail",
                icon: "envelope",
                capabilities: [.readContent, .compose, .search],
                actions: ["compose", "getSelected", "search", "getMailboxes", "moveToFolder"]
            ),
            AppDefinition(
                bundleId: "com.apple.Notes",
                name: "Notes",
                icon: "note.text",
                capabilities: [.readContent, .writeContent, .search],
                actions: ["createNote", "getNote", "updateNote", "searchNotes", "getFolders"]
            ),
            AppDefinition(
                bundleId: "com.apple.reminders",
                name: "Reminders",
                icon: "checklist",
                capabilities: [.readContent, .writeContent, .search],
                actions: ["createReminder", "completeReminder", "getLists", "getReminders"]
            ),
            AppDefinition(
                bundleId: "com.apple.iCal",
                name: "Calendar",
                icon: "calendar",
                capabilities: [.readContent, .writeContent, .search],
                actions: ["createEvent", "getEvents", "updateEvent", "deleteEvent", "getCalendars"]
            ),
            AppDefinition(
                bundleId: "com.apple.TextEdit",
                name: "TextEdit",
                icon: "doc.text",
                capabilities: [.readContent, .writeContent, .fileOperations],
                actions: ["newDocument", "getContent", "setContent", "save", "saveAs"]
            ),
            AppDefinition(
                bundleId: "com.microsoft.VSCode",
                name: "VS Code",
                icon: "chevron.left.forwardslash.chevron.right",
                capabilities: [.readContent, .writeContent, .navigation, .terminal],
                actions: ["openFile", "openFolder", "getContent", "runCommand", "openTerminal"]
            ),
            AppDefinition(
                bundleId: "com.apple.Terminal",
                name: "Terminal",
                icon: "terminal",
                capabilities: [.terminal, .readContent],
                actions: ["runCommand", "getOutput", "newTab", "newWindow"]
            ),
            AppDefinition(
                bundleId: "com.slack.Slack",
                name: "Slack",
                icon: "bubble.left.and.bubble.right",
                capabilities: [.readContent, .compose, .search],
                actions: ["sendMessage", "getChannels", "searchMessages", "setStatus"]
            ),
            AppDefinition(
                bundleId: "com.figma.Desktop",
                name: "Figma",
                icon: "paintbrush",
                capabilities: [.readContent, .navigation],
                actions: ["openFile", "exportSelection", "getSelection"]
            ),
            AppDefinition(
                bundleId: "com.anthropic.claudefordesktop",
                name: "Claude",
                icon: "brain",
                capabilities: [.readContent, .compose],
                actions: ["newChat", "sendMessage", "getResponse", "copyLastResponse"]
            )
        ]

        // MARK: - Initialization

        private init() {
            checkAccessibilityPermissions()
            discoverConnectedApps()

            // Monitor for app changes
            setupAppMonitoring()
        }

        // MARK: - Accessibility

        private func checkAccessibilityPermissions() {
            isAccessibilityEnabled = AXIsProcessTrusted()
        }

        /// Request accessibility permissions
        public func requestAccessibilityPermissions() {
            // Use nonisolated(unsafe) to access the constant safely
            let promptKey = "AXTrustedCheckOptionPrompt"
            let options: NSDictionary = [promptKey: true]
            _ = AXIsProcessTrustedWithOptions(options)

            // Check again after a delay
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                checkAccessibilityPermissions()
            }
        }

        // MARK: - App Discovery

        private func discoverConnectedApps() {
            let workspace = NSWorkspace.shared
            let runningApps = workspace.runningApplications

            connectedApps = supportedApps.compactMap { definition in
                guard let runningApp = runningApps.first(where: { $0.bundleIdentifier == definition.bundleId }) else {
                    // Check if installed but not running
                    if workspace.urlForApplication(withBundleIdentifier: definition.bundleId) != nil {
                        return ConnectedApp(
                            definition: definition,
                            status: .installed,
                            processId: nil
                        )
                    }
                    return nil
                }

                return ConnectedApp(
                    definition: definition,
                    status: .running,
                    processId: runningApp.processIdentifier
                )
            }
        }

        private func setupAppMonitoring() {
            let workspace = NSWorkspace.shared

            // MEMORY SAFETY: Store observer references for proper cleanup
            let launchObserver = workspace.notificationCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.discoverConnectedApps()
                }
            }
            notificationObservers.append(launchObserver)

            let terminateObserver = workspace.notificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.discoverConnectedApps()
                }
            }
            notificationObservers.append(terminateObserver)

            let activateObserver = workspace.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      let bundleId = app.bundleIdentifier else { return }
                Task { @MainActor in
                    self.activeApp = self.connectedApps.first { $0.definition.bundleId == bundleId }
                }
            }
            notificationObservers.append(activateObserver)
        }

        /// Cleanup method to remove all notification observers
        /// Called when the service is being deallocated
        public func cleanup() {
            let workspace = NSWorkspace.shared
            for observer in notificationObservers {
                workspace.notificationCenter.removeObserver(observer)
            }
            notificationObservers.removeAll()
        }

        deinit {
            // Note: Since this is a singleton and @MainActor, deinit is rarely called
            // but we include it for completeness. Use cleanup() for explicit teardown.
            let observers = notificationObservers
            let workspace = NSWorkspace.shared
            for observer in observers {
                workspace.notificationCenter.removeObserver(observer)
            }
        }

        // MARK: - Execute Action

        /// Execute an action on a connected app
        public func execute(
            action: String,
            on app: ConnectedApp,
            parameters: [String: Any] = [:]
        ) async throws -> AppActionResult {
            guard isAccessibilityEnabled else {
                throw WorkWithAppsError.accessibilityNotEnabled
            }

            if app.status != .running {
                // Try to launch the app
                try await launch(app)
            }

            let result: AppActionResult = switch app.definition.bundleId {
            case "com.apple.finder":
                try await executeFinderAction(action, parameters: parameters)
            case "com.apple.Safari":
                try await executeSafariAction(action, parameters: parameters)
            case "com.apple.mail":
                try await executeMailAction(action, parameters: parameters)
            case "com.apple.Notes":
                try await executeNotesAction(action, parameters: parameters)
            case "com.apple.reminders":
                try await executeRemindersAction(action, parameters: parameters)
            case "com.apple.iCal":
                try await executeCalendarAction(action, parameters: parameters)
            case "com.apple.Terminal":
                try await executeTerminalAction(action, parameters: parameters)
            default:
                try await executeGenericAction(action, on: app, parameters: parameters)
            }

            // Record action
            let actionRecord = AppAction(
                id: UUID(),
                appBundleId: app.definition.bundleId,
                actionName: action,
                parameters: parameters.mapValues { "\($0)" },
                result: result,
                timestamp: Date()
            )
            recentActions.insert(actionRecord, at: 0)
            if recentActions.count > 100 {
                recentActions.removeLast()
            }

            return result
        }

        // MARK: - Launch App

        /// Launch an app
        public func launch(_ app: ConnectedApp) async throws {
            let workspace = NSWorkspace.shared

            guard let url = workspace.urlForApplication(withBundleIdentifier: app.definition.bundleId) else {
                throw WorkWithAppsError.appNotFound
            }

            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false

            try await workspace.openApplication(at: url, configuration: configuration)

            // Wait for app to start
            try await Task.sleep(nanoseconds: 1_000_000_000)
            discoverConnectedApps()
        }

        /// Activate (bring to front) an app
        public func activate(_ app: ConnectedApp) throws {
            guard let runningApp = NSRunningApplication.runningApplications(
                withBundleIdentifier: app.definition.bundleId
            ).first else {
                throw WorkWithAppsError.appNotRunning
            }

            runningApp.activate()
        }

        // MARK: - Finder Actions

        private func executeFinderAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
            switch action {
            case "open":
                guard let path = parameters["path"] as? String else {
                    throw WorkWithAppsError.missingParameter("path")
                }
                return try await openInFinder(path: path)

            case "reveal":
                guard let path = parameters["path"] as? String else {
                    throw WorkWithAppsError.missingParameter("path")
                }
                return try await revealInFinder(path: path)

            case "getSelection":
                return try await getFinderSelection()

            case "createFolder":
                guard let path = parameters["path"] as? String,
                      let name = parameters["name"] as? String
                else {
                    throw WorkWithAppsError.missingParameter("path or name")
                }
                return try await createFolder(at: path, name: name)

            default:
                throw WorkWithAppsError.unsupportedAction(action)
            }
        }

        private func openInFinder(path: String) async throws -> AppActionResult {
            let script = """
            tell application "Finder"
                open POSIX file "\(path)"
                activate
            end tell
            """
            return try await runAppleScript(script)
        }

        private func revealInFinder(path: String) async throws -> AppActionResult {
            let script = """
            tell application "Finder"
                reveal POSIX file "\(path)"
                activate
            end tell
            """
            return try await runAppleScript(script)
        }

        private func getFinderSelection() async throws -> AppActionResult {
            let script = """
            tell application "Finder"
                set selectedItems to selection
                set itemPaths to {}
                repeat with anItem in selectedItems
                    set end of itemPaths to POSIX path of (anItem as alias)
                end repeat
                return itemPaths
            end tell
            """
            return try await runAppleScript(script)
        }

        private func createFolder(at path: String, name: String) async throws -> AppActionResult {
            let script = """
            tell application "Finder"
                make new folder at POSIX file "\(path)" with properties {name:"\(name)"}
            end tell
            """
            return try await runAppleScript(script)
        }

        // MARK: - Safari Actions

        private func executeSafariAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
            switch action {
            case "openURL":
                guard let url = parameters["url"] as? String else {
                    throw WorkWithAppsError.missingParameter("url")
                }
                return try await openSafariURL(url)

            case "getCurrentURL":
                return try await getSafariCurrentURL()

            case "getPageContent":
                return try await getSafariPageContent()

            case "search":
                guard let query = parameters["query"] as? String else {
                    throw WorkWithAppsError.missingParameter("query")
                }
                return try await searchInSafari(query)

            default:
                throw WorkWithAppsError.unsupportedAction(action)
            }
        }

        private func openSafariURL(_ url: String) async throws -> AppActionResult {
            let script = """
            tell application "Safari"
                open location "\(url)"
                activate
            end tell
            """
            return try await runAppleScript(script)
        }

        private func getSafariCurrentURL() async throws -> AppActionResult {
            let script = """
            tell application "Safari"
                return URL of current tab of front window
            end tell
            """
            return try await runAppleScript(script)
        }

        private func getSafariPageContent() async throws -> AppActionResult {
            let script = """
            tell application "Safari"
                return text of current tab of front window
            end tell
            """
            return try await runAppleScript(script)
        }

        private func searchInSafari(_ query: String) async throws -> AppActionResult {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let script = """
            tell application "Safari"
                open location "https://www.google.com/search?q=\(encoded)"
                activate
            end tell
            """
            return try await runAppleScript(script)
        }

        // MARK: - Mail Actions

        private func executeMailAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
            switch action {
            case "compose":
                let to = parameters["to"] as? String ?? ""
                let subject = parameters["subject"] as? String ?? ""
                let body = parameters["body"] as? String ?? ""
                return try await composeMail(to: to, subject: subject, body: body)

            case "getSelected":
                return try await getSelectedMail()

            default:
                throw WorkWithAppsError.unsupportedAction(action)
            }
        }

        private func composeMail(to: String, subject: String, body: String) async throws -> AppActionResult {
            let script = """
            tell application "Mail"
                set newMessage to make new outgoing message with properties {subject:"\(subject)", content:"\(body)"}
                tell newMessage
                    make new to recipient with properties {address:"\(to)"}
                end tell
                activate
            end tell
            """
            return try await runAppleScript(script)
        }

        private func getSelectedMail() async throws -> AppActionResult {
            let script = """
            tell application "Mail"
                set selectedMessages to selection
                set messageInfo to {}
                repeat with msg in selectedMessages
                    set end of messageInfo to {subject of msg, sender of msg, date received of msg}
                end repeat
                return messageInfo
            end tell
            """
            return try await runAppleScript(script)
        }

        // MARK: - Notes Actions

        private func executeNotesAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
            switch action {
            case "createNote":
                let title = parameters["title"] as? String ?? "New Note"
                let body = parameters["body"] as? String ?? ""
                return try await createNote(title: title, body: body)

            case "searchNotes":
                guard let query = parameters["query"] as? String else {
                    throw WorkWithAppsError.missingParameter("query")
                }
                return try await searchNotes(query)

            default:
                throw WorkWithAppsError.unsupportedAction(action)
            }
        }

        private func createNote(title: String, body: String) async throws -> AppActionResult {
            let script = """
            tell application "Notes"
                make new note at folder "Notes" with properties {name:"\(title)", body:"\(body)"}
                activate
            end tell
            """
            return try await runAppleScript(script)
        }

        private func searchNotes(_ query: String) async throws -> AppActionResult {
            let script = """
            tell application "Notes"
                set matchingNotes to notes whose name contains "\(query)" or body contains "\(query)"
                set noteInfo to {}
                repeat with n in matchingNotes
                    set end of noteInfo to name of n
                end repeat
                return noteInfo
            end tell
            """
            return try await runAppleScript(script)
        }

        // MARK: - Reminders Actions

        private func executeRemindersAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
            switch action {
            case "createReminder":
                guard let title = parameters["title"] as? String else {
                    throw WorkWithAppsError.missingParameter("title")
                }
                let list = parameters["list"] as? String
                return try await createReminder(title: title, list: list)

            case "getLists":
                return try await getReminderLists()

            default:
                throw WorkWithAppsError.unsupportedAction(action)
            }
        }

        private func createReminder(title: String, list: String?) async throws -> AppActionResult {
            let listClause = list != nil ? "in list \"\(list!)\"" : ""
            let script = """
            tell application "Reminders"
                make new reminder \(listClause) with properties {name:"\(title)"}
                activate
            end tell
            """
            return try await runAppleScript(script)
        }

        private func getReminderLists() async throws -> AppActionResult {
            let script = """
            tell application "Reminders"
                return name of every list
            end tell
            """
            return try await runAppleScript(script)
        }

        // MARK: - Calendar Actions

        private func executeCalendarAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
            switch action {
            case "createEvent":
                guard let title = parameters["title"] as? String,
                      let startDate = parameters["startDate"] as? Date
                else {
                    throw WorkWithAppsError.missingParameter("title or startDate")
                }
                let endDate = parameters["endDate"] as? Date ?? startDate.addingTimeInterval(3600)
                return try await createCalendarEvent(title: title, start: startDate, end: endDate)

            case "getCalendars":
                return try await getCalendars()

            default:
                throw WorkWithAppsError.unsupportedAction(action)
            }
        }

        private func createCalendarEvent(title: String, start: Date, end: Date) async throws -> AppActionResult {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"

            let script = """
            tell application "Calendar"
                tell calendar "Calendar"
                    make new event with properties {summary:"\(title)", start date:date "\(formatter.string(from: start))", end date:date "\(formatter.string(from: end))"}
                end tell
                activate
            end tell
            """
            return try await runAppleScript(script)
        }

        private func getCalendars() async throws -> AppActionResult {
            let script = """
            tell application "Calendar"
                return name of every calendar
            end tell
            """
            return try await runAppleScript(script)
        }

        // MARK: - Terminal Actions

        private func executeTerminalAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
            switch action {
            case "runCommand":
                guard let command = parameters["command"] as? String else {
                    throw WorkWithAppsError.missingParameter("command")
                }
                return try await runTerminalCommand(command)

            case "newTab":
                return try await newTerminalTab()

            default:
                throw WorkWithAppsError.unsupportedAction(action)
            }
        }

        private func runTerminalCommand(_ command: String) async throws -> AppActionResult {
            let script = """
            tell application "Terminal"
                do script "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
                activate
            end tell
            """
            return try await runAppleScript(script)
        }

        private func newTerminalTab() async throws -> AppActionResult {
            let script = """
            tell application "Terminal"
                tell application "System Events" to keystroke "t" using command down
                activate
            end tell
            """
            return try await runAppleScript(script)
        }

        // MARK: - Generic Actions

        private func executeGenericAction(
            _ action: String,
            on app: ConnectedApp,
            parameters _: [String: Any]
        ) async throws -> AppActionResult {
            // Generic action execution using accessibility API
            guard let pid = app.processId else {
                throw WorkWithAppsError.appNotRunning
            }

            let appElement = AXUIElementCreateApplication(pid)

            switch action {
            case "activate":
                let script = """
                tell application "\(app.definition.name)"
                    activate
                end tell
                """
                return try await runAppleScript(script)

            case "getWindowTitle":
                var windowRef: CFTypeRef?
                AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &windowRef)

                if let window = windowRef {
                    var titleRef: CFTypeRef?
                    // swiftlint:disable:next force_cast
                    AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef)

                    if let title = titleRef as? String {
                        return AppActionResult(success: true, output: title)
                    }
                }
                return AppActionResult(success: false, error: "Could not get window title")

            default:
                throw WorkWithAppsError.unsupportedAction(action)
            }
        }

        // MARK: - AppleScript Helper

        private func runAppleScript(_ source: String) async throws -> AppActionResult {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                throw WorkWithAppsError.scriptError("Failed to create AppleScript")
            }

            let result = script.executeAndReturnError(&error)

            if let error {
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                return AppActionResult(success: false, error: errorMessage)
            }

            return AppActionResult(success: true, output: result.stringValue ?? "Success")
        }

        // MARK: - Convenience Methods

        /// Get content from the currently active app
        public func getActiveAppContent() async throws -> String {
            guard let app = activeApp else {
                throw WorkWithAppsError.noActiveApp
            }

            let result = try await execute(action: "getContent", on: app)
            return result.output ?? ""
        }

        /// Send text to the currently active app
        public func sendToActiveApp(_ text: String) async throws {
            guard let app = activeApp else {
                throw WorkWithAppsError.noActiveApp
            }

            _ = try await execute(action: "setContent", on: app, parameters: ["content": text])
        }
    }

// Supporting types are in WorkWithAppsServiceTypes.swift

#else
    // iOS stub
    @MainActor
    public class WorkWithAppsService: ObservableObject {
        public static let shared = WorkWithAppsService()

        @Published public private(set) var connectedApps: [String] = []

        private init() {}
    }

// WorkWithAppsError is in WorkWithAppsServiceTypes.swift

#endif
