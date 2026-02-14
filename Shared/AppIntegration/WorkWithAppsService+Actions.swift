//
//  WorkWithAppsService+Actions.swift
//  Thea
//
//  App-specific action implementations for WorkWithAppsService
//

import Foundation
#if os(macOS)
    import AppKit
    import ApplicationServices

    // MARK: - Finder Actions

    @MainActor
    extension WorkWithAppsService {
        func executeFinderAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
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
    }

    // MARK: - Safari Actions

    @MainActor
    extension WorkWithAppsService {
        func executeSafariAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
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
    }

    // MARK: - Mail Actions

    @MainActor
    extension WorkWithAppsService {
        func executeMailAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
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
    }

    // MARK: - Notes Actions

    @MainActor
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

    @MainActor
    extension WorkWithAppsService {
        func executeRemindersAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
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

    @MainActor
    extension WorkWithAppsService {
        func executeCalendarAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
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

    @MainActor
    extension WorkWithAppsService {
        func executeTerminalAction(_ action: String, parameters: [String: Any]) async throws -> AppActionResult {
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

    // MARK: - Generic & AppleScript Actions

    @MainActor
    extension WorkWithAppsService {
        func executeGenericAction(
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
    }
#endif
