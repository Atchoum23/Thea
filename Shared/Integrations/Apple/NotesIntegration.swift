// NotesIntegration.swift
// Thea V2
//
// Integration with Apple Notes using AppleScript
// Notes.app doesn't have a native framework, so we use scripting

import Foundation
import OSLog

#if os(macOS)

// MARK: - Notes Models

/// Represents a note in the system
public struct TheaNote: Identifiable, Sendable, Codable {
    public let id: String
    public var title: String
    public var body: String
    public var plainText: String
    public var folderId: String?
    public var folderName: String?
    public var creationDate: Date?
    public var modificationDate: Date?
    public var isPasswordProtected: Bool
    public var attachmentCount: Int

    public var snippet: String {
        let maxLength = 200
        let text = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }

    public init(
        id: String = UUID().uuidString,
        title: String = "",
        body: String = "",
        plainText: String = "",
        folderId: String? = nil,
        folderName: String? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        isPasswordProtected: Bool = false,
        attachmentCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.plainText = plainText
        self.folderId = folderId
        self.folderName = folderName
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.isPasswordProtected = isPasswordProtected
        self.attachmentCount = attachmentCount
    }
}

/// Represents a folder in Notes
public struct TheaNoteFolder: Identifiable, Sendable, Codable {
    public let id: String
    public var name: String
    public var noteCount: Int
    public var isDefault: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        noteCount: Int = 0,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.noteCount = noteCount
        self.isDefault = isDefault
    }
}

// MARK: - Search Criteria

/// Search criteria for notes
public struct NoteSearchCriteria: Sendable {
    public var searchText: String?
    public var folderId: String?
    public var folderName: String?
    public var modifiedAfter: Date?
    public var modifiedBefore: Date?
    public var limit: Int?

    public init(
        searchText: String? = nil,
        folderId: String? = nil,
        folderName: String? = nil,
        modifiedAfter: Date? = nil,
        modifiedBefore: Date? = nil,
        limit: Int? = nil
    ) {
        self.searchText = searchText
        self.folderId = folderId
        self.folderName = folderName
        self.modifiedAfter = modifiedAfter
        self.modifiedBefore = modifiedBefore
        self.limit = limit
    }

    public static func search(_ text: String) -> NoteSearchCriteria {
        NoteSearchCriteria(searchText: text)
    }

    public static func inFolder(_ name: String) -> NoteSearchCriteria {
        NoteSearchCriteria(folderName: name)
    }
}

// MARK: - Notes Integration Actor

/// Actor for managing Notes operations via AppleScript
/// Thread-safe access to Notes.app
public actor NotesIntegration {
    public static let shared = NotesIntegration()

    private let logger = Logger(subsystem: "com.thea.integrations", category: "Notes")

    private init() {}

    // MARK: - Folder Operations

    /// Fetch all folders
    public func fetchFolders() async throws -> [TheaNoteFolder] {
        let script = """
        tell application "Notes"
            set folderList to {}
            repeat with f in folders
                set folderInfo to {id of f, name of f, count of notes in f}
                set end of folderList to folderInfo
            end repeat
            return folderList
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseFolders(result)
    }

    /// Create a new folder
    public func createFolder(name: String) async throws -> TheaNoteFolder {
        let escapedName = escapeForAppleScript(name)
        let script = """
        tell application "Notes"
            set newFolder to make new folder with properties {name:"\(escapedName)"}
            return {id of newFolder, name of newFolder, 0}
        end tell
        """

        let result = try await executeAppleScript(script)
        let folders = parseFolders(result)

        guard let folder = folders.first else {
            throw NotesError.createFailed("Failed to parse created folder")
        }

        logger.info("Created folder: \(name)")
        return folder
    }

    /// Delete a folder
    public func deleteFolder(name: String) async throws {
        let escapedName = escapeForAppleScript(name)
        let script = """
        tell application "Notes"
            delete folder "\(escapedName)"
        end tell
        """

        try await executeAppleScript(script)
        logger.info("Deleted folder: \(name)")
    }

    // MARK: - Note Fetch Operations

    /// Fetch all notes
    public func fetchAllNotes(limit: Int? = nil) async throws -> [TheaNote] {
        let limitClause = limit.map { "set noteList to items 1 thru (min of {\($0), count of noteList}) of noteList" } ?? ""

        let script = """
        tell application "Notes"
            set noteList to every note
            \(limitClause)
            set noteInfoList to {}
            repeat with n in noteList
                try
                    set noteInfo to {id of n, name of n, plaintext of n, name of container of n, creation date of n as string, modification date of n as string, password protected of n, count of attachments in n}
                    set end of noteInfoList to noteInfo
                end try
            end repeat
            return noteInfoList
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseNotes(result)
    }

    /// Fetch notes in a specific folder
    public func fetchNotes(inFolder folderName: String) async throws -> [TheaNote] {
        let escapedName = escapeForAppleScript(folderName)
        let script = """
        tell application "Notes"
            set noteList to notes of folder "\(escapedName)"
            set noteInfoList to {}
            repeat with n in noteList
                try
                    set noteInfo to {id of n, name of n, plaintext of n, "\(escapedName)", creation date of n as string, modification date of n as string, password protected of n, count of attachments in n}
                    set end of noteInfoList to noteInfo
                end try
            end repeat
            return noteInfoList
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseNotes(result)
    }

    /// Search notes by text
    public func searchNotes(text: String) async throws -> [TheaNote] {
        let escapedText = escapeForAppleScript(text)
        let script = """
        tell application "Notes"
            set matchingNotes to notes whose plaintext contains "\(escapedText)" or name contains "\(escapedText)"
            set noteInfoList to {}
            repeat with n in matchingNotes
                try
                    set noteInfo to {id of n, name of n, plaintext of n, name of container of n, creation date of n as string, modification date of n as string, password protected of n, count of attachments in n}
                    set end of noteInfoList to noteInfo
                end try
            end repeat
            return noteInfoList
        end tell
        """

        let result = try await executeAppleScript(script)
        return parseNotes(result)
    }

    /// Fetch notes by criteria
    public func fetchNotes(criteria: NoteSearchCriteria) async throws -> [TheaNote] {
        if let searchText = criteria.searchText, !searchText.isEmpty {
            var notes = try await searchNotes(text: searchText)

            // Apply folder filter if specified
            if let folderName = criteria.folderName {
                notes = notes.filter { $0.folderName == folderName }
            }

            // Apply date filters
            if let modifiedAfter = criteria.modifiedAfter {
                notes = notes.filter { note in
                    guard let modDate = note.modificationDate else { return false }
                    return modDate > modifiedAfter
                }
            }

            if let modifiedBefore = criteria.modifiedBefore {
                notes = notes.filter { note in
                    guard let modDate = note.modificationDate else { return false }
                    return modDate < modifiedBefore
                }
            }

            // Apply limit
            if let limit = criteria.limit, notes.count > limit {
                notes = Array(notes.prefix(limit))
            }

            return notes
        } else if let folderName = criteria.folderName {
            var notes = try await fetchNotes(inFolder: folderName)

            // Apply limit
            if let limit = criteria.limit, notes.count > limit {
                notes = Array(notes.prefix(limit))
            }

            return notes
        } else {
            return try await fetchAllNotes(limit: criteria.limit)
        }
    }

    /// Fetch a single note by title
    public func fetchNote(title: String, inFolder folderName: String? = nil) async throws -> TheaNote? {
        let escapedTitle = escapeForAppleScript(title)
        let folderClause: String
        if let folder = folderName {
            folderClause = " of folder \"\(escapeForAppleScript(folder))\""
        } else {
            folderClause = ""
        }

        let script = """
        tell application "Notes"
            try
                set n to note "\(escapedTitle)"\(folderClause)
                return {id of n, name of n, plaintext of n, name of container of n, creation date of n as string, modification date of n as string, password protected of n, count of attachments in n}
            on error
                return {}
            end try
        end tell
        """

        let result = try await executeAppleScript(script)
        let notes = parseNotes(result)
        return notes.first
    }

    // MARK: - Note CRUD Operations

    /// Create a new note
    public func createNote(title: String, body: String, folderName: String? = nil) async throws -> TheaNote {
        let escapedTitle = escapeForAppleScript(title)
        let escapedBody = escapeForAppleScript(body)

        let folderClause: String
        if let folder = folderName {
            folderClause = " in folder \"\(escapeForAppleScript(folder))\""
        } else {
            folderClause = ""
        }

        // Notes uses HTML for body content
        let htmlBody = "<h1>\(escapedTitle)</h1><p>\(escapedBody.replacingOccurrences(of: "\n", with: "<br>"))</p>"
        let escapedHtmlBody = escapeForAppleScript(htmlBody)

        let script = """
        tell application "Notes"
            set newNote to make new note\(folderClause) with properties {name:"\(escapedTitle)", body:"\(escapedHtmlBody)"}
            return {id of newNote, name of newNote, plaintext of newNote, name of container of newNote, creation date of newNote as string, modification date of newNote as string, password protected of newNote, 0}
        end tell
        """

        let result = try await executeAppleScript(script)
        let notes = parseNotes(result)

        guard let note = notes.first else {
            throw NotesError.createFailed("Failed to parse created note")
        }

        logger.info("Created note: \(title)")
        return note
    }

    /// Update a note's content
    public func updateNote(title: String, newBody: String, inFolder folderName: String? = nil) async throws {
        let escapedTitle = escapeForAppleScript(title)
        let escapedBody = escapeForAppleScript(newBody)

        let folderClause: String
        if let folder = folderName {
            folderClause = " of folder \"\(escapeForAppleScript(folder))\""
        } else {
            folderClause = ""
        }

        let htmlBody = "<h1>\(escapedTitle)</h1><p>\(escapedBody.replacingOccurrences(of: "\n", with: "<br>"))</p>"
        let escapedHtmlBody = escapeForAppleScript(htmlBody)

        let script = """
        tell application "Notes"
            set n to note "\(escapedTitle)"\(folderClause)
            set body of n to "\(escapedHtmlBody)"
        end tell
        """

        try await executeAppleScript(script)
        logger.info("Updated note: \(title)")
    }

    /// Append text to a note
    public func appendToNote(title: String, text: String, inFolder folderName: String? = nil) async throws {
        let escapedTitle = escapeForAppleScript(title)
        let escapedText = escapeForAppleScript(text)

        let folderClause: String
        if let folder = folderName {
            folderClause = " of folder \"\(escapeForAppleScript(folder))\""
        } else {
            folderClause = ""
        }

        let htmlText = "<p>\(escapedText.replacingOccurrences(of: "\n", with: "<br>"))</p>"
        let escapedHtmlText = escapeForAppleScript(htmlText)

        let script = """
        tell application "Notes"
            set n to note "\(escapedTitle)"\(folderClause)
            set body of n to (body of n) & "\(escapedHtmlText)"
        end tell
        """

        try await executeAppleScript(script)
        logger.info("Appended to note: \(title)")
    }

    /// Rename a note
    public func renameNote(oldTitle: String, newTitle: String, inFolder folderName: String? = nil) async throws {
        let escapedOldTitle = escapeForAppleScript(oldTitle)
        let escapedNewTitle = escapeForAppleScript(newTitle)

        let folderClause: String
        if let folder = folderName {
            folderClause = " of folder \"\(escapeForAppleScript(folder))\""
        } else {
            folderClause = ""
        }

        let script = """
        tell application "Notes"
            set n to note "\(escapedOldTitle)"\(folderClause)
            set name of n to "\(escapedNewTitle)"
        end tell
        """

        try await executeAppleScript(script)
        logger.info("Renamed note from '\(oldTitle)' to '\(newTitle)'")
    }

    /// Move a note to a different folder
    public func moveNote(title: String, fromFolder: String?, toFolder: String) async throws {
        let escapedTitle = escapeForAppleScript(title)
        let escapedToFolder = escapeForAppleScript(toFolder)

        let fromClause: String
        if let from = fromFolder {
            fromClause = " of folder \"\(escapeForAppleScript(from))\""
        } else {
            fromClause = ""
        }

        let script = """
        tell application "Notes"
            set n to note "\(escapedTitle)"\(fromClause)
            move n to folder "\(escapedToFolder)"
        end tell
        """

        try await executeAppleScript(script)
        logger.info("Moved note '\(title)' to folder '\(toFolder)'")
    }

    /// Delete a note
    public func deleteNote(title: String, inFolder folderName: String? = nil) async throws {
        let escapedTitle = escapeForAppleScript(title)

        let folderClause: String
        if let folder = folderName {
            folderClause = " of folder \"\(escapeForAppleScript(folder))\""
        } else {
            folderClause = ""
        }

        let script = """
        tell application "Notes"
            delete note "\(escapedTitle)"\(folderClause)
        end tell
        """

        try await executeAppleScript(script)
        logger.info("Deleted note: \(title)")
    }

    // MARK: - Utility Operations

    /// Get note count
    public func getNoteCount() async throws -> Int {
        let script = """
        tell application "Notes"
            return count of notes
        end tell
        """

        let result = try await executeAppleScript(script)
        return Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    /// Show a note in Notes.app
    public func showNote(title: String, inFolder folderName: String? = nil) async throws {
        let escapedTitle = escapeForAppleScript(title)

        let folderClause: String
        if let folder = folderName {
            folderClause = " of folder \"\(escapeForAppleScript(folder))\""
        } else {
            folderClause = ""
        }

        let script = """
        tell application "Notes"
            activate
            show note "\(escapedTitle)"\(folderClause)
        end tell
        """

        try await executeAppleScript(script)
    }

    // MARK: - Helper Methods

    @discardableResult
    private func executeAppleScript(_ script: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let result = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                    self.logger.error("AppleScript error: \(message)")
                    continuation.resume(throwing: NotesError.scriptError(message))
                } else if let result = result {
                    continuation.resume(returning: result.stringValue ?? "")
                } else {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    private func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func parseFolders(_ result: String) -> [TheaNoteFolder] {
        // Parse AppleScript list format
        // Format: {{id1, name1, count1}, {id2, name2, count2}, ...}
        var folders: [TheaNoteFolder] = []

        let cleaned = result.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
        let entries = cleaned.components(separatedBy: "}, {")

        for entry in entries where !entry.isEmpty {
            let components = entry.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
                .components(separatedBy: ", ")

            if components.count >= 2 {
                let id = components[0].trimmingCharacters(in: .whitespaces)
                let name = components[1].trimmingCharacters(in: .whitespaces)
                let count = components.count > 2 ? Int(components[2].trimmingCharacters(in: .whitespaces)) ?? 0 : 0

                folders.append(TheaNoteFolder(
                    id: id,
                    name: name,
                    noteCount: count
                ))
            }
        }

        return folders
    }

    private func parseNotes(_ result: String) -> [TheaNote] {
        // Parse AppleScript list format for notes
        var notes: [TheaNote] = []

        let cleaned = result.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
        let entries = cleaned.components(separatedBy: "}, {")

        for entry in entries where !entry.isEmpty {
            let components = entry.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
                .components(separatedBy: ", ")

            if components.count >= 4 {
                let id = components[0].trimmingCharacters(in: .whitespaces)
                let title = components[1].trimmingCharacters(in: .whitespaces)
                let plainText = components[2].trimmingCharacters(in: .whitespaces)
                let folderName = components[3].trimmingCharacters(in: .whitespaces)

                var creationDate: Date?
                var modificationDate: Date?

                if components.count > 4 {
                    creationDate = parseAppleScriptDate(components[4])
                }
                if components.count > 5 {
                    modificationDate = parseAppleScriptDate(components[5])
                }

                let isPasswordProtected = components.count > 6 && components[6].lowercased().contains("true")
                let attachmentCount = components.count > 7 ? Int(components[7].trimmingCharacters(in: .whitespaces)) ?? 0 : 0

                notes.append(TheaNote(
                    id: id,
                    title: title,
                    body: "",  // Would need separate fetch for full HTML body
                    plainText: plainText,
                    folderId: nil,
                    folderName: folderName,
                    creationDate: creationDate,
                    modificationDate: modificationDate,
                    isPasswordProtected: isPasswordProtected,
                    attachmentCount: attachmentCount
                ))
            }
        }

        return notes
    }

    private func parseAppleScriptDate(_ dateString: String) -> Date? {
        // AppleScript dates come in various formats
        let trimmed = dateString.trimmingCharacters(in: .whitespaces)

        let formatters = [
            "EEEE, MMMM d, yyyy 'at' h:mm:ss a",
            "yyyy-MM-dd HH:mm:ss Z",
            "MMM d, yyyy, h:mm:ss a"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US")
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }
}

// MARK: - Errors

/// Errors for Notes operations
public enum NotesError: LocalizedError {
    case notAuthorized
    case unavailable
    case noteNotFound
    case folderNotFound
    case createFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case scriptError(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Notes access not authorized"
        case .unavailable:
            "Notes integration not available on this platform"
        case .noteNotFound:
            "Note not found"
        case .folderNotFound:
            "Notes folder not found"
        case .createFailed(let reason):
            "Failed to create note: \(reason)"
        case .updateFailed(let reason):
            "Failed to update note: \(reason)"
        case .deleteFailed(let reason):
            "Failed to delete note: \(reason)"
        case .scriptError(let message):
            "AppleScript error: \(message)"
        }
    }
}

#endif  // os(macOS)
