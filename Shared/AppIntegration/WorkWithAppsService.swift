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
                try? await Task.sleep(for: .seconds(2))
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
            try await Task.sleep(for: .seconds(1))
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

        // MARK: - AppleScript Helper

        /// Runs an AppleScript and returns the result
        /// Internal access to allow extension files to use this helper
        func runAppleScript(_ source: String) async throws -> AppActionResult {
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
// App-specific actions are in WorkWithAppsService+FinderSafari.swift
//   and WorkWithAppsService+AppActions.swift

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
