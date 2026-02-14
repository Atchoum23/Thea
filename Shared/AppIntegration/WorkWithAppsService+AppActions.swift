//
//  WorkWithAppsService+AppActions.swift
//  Thea
//
//  Notes, Reminders, Calendar, Terminal, and Generic action methods for WorkWithAppsService
//

import Foundation
#if os(macOS)
    import AppKit
    import ApplicationServices

    // MARK: - Notes Actions

    extension WorkWithAppsService {
        func executeNotesAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
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
    }

    // MARK: - Reminders Actions

    extension WorkWithAppsService {
        func executeRemindersAction(
            _ action: String,
            parameters: [String: Any]
        ) async throws -> AppActionResult {
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
    }

    // MARK: - Calendar Actions

    extension WorkWithAppsService {
        func executeCalendarAction(
            _ action: String,
            parameters: [String: Any]
        ) async throws -> AppActionResult {
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
    }

    // MARK: - Terminal Actions

    extension WorkWithAppsService {
        func executeTerminalAction(
            _ action: String,
            parameters: [String: Any]
        ) async throws -> AppActionResult {
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
    }

    // MARK: - Generic Actions

    extension WorkWithAppsService {
        func executeGenericAction(
            _ action: String,
            on app: ConnectedApp,
            parameters _: [String: Any]
        ) async throws -> AppActionResult {
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
                    AXUIElementCopyAttributeValue(
                        window as! AXUIElement,
                        kAXTitleAttribute as CFString,
                        &titleRef
                    )

                    if let title = titleRef as? String {
                        return AppActionResult(success: true, output: title)
                    }
                }
                return AppActionResult(success: false, error: "Could not get window title")

            default:
                throw WorkWithAppsError.unsupportedAction(action)
            }
        }
    }

#endif
