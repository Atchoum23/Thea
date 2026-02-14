//
//  WorkWithAppsService+FinderSafari.swift
//  Thea
//
//  Finder, Safari, and Mail action methods for WorkWithAppsService
//

import Foundation
#if os(macOS)
    import AppKit

    // MARK: - Finder Actions

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

#endif
