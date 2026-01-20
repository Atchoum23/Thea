//
//  NotesIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
#endif

// MARK: - Notes Integration

/// Integration module for Notes app
public actor NotesIntegration: IntegrationModule {
    public static let shared = NotesIntegration()

    public let moduleId = "notes"
    public let displayName = "Notes"
    public let bundleIdentifier = "com.apple.Notes"
    public let icon = "note.text"

    private var isConnected = false

    private init() {}

    public func connect() async throws {
        #if os(macOS)
        isConnected = true
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    public func disconnect() async { isConnected = false }

    public func isAvailable() async -> Bool {
        #if os(macOS)
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
        #else
        return false
        #endif
    }

    /// Create a new note
    public func createNote(title: String, body: String, folder: String? = nil) async throws {
        #if os(macOS)
        let folderPart = folder.map { "in folder \"\($0)\"" } ?? ""
        let script = """
        tell application "Notes"
            make new note \(folderPart) with properties {name:"\(title)", body:"\(body)"}
            activate
        end tell
        """
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Get all notes
    public func getAllNotes() async throws -> [NoteInfo] {
        #if os(macOS)
        let script = """
        tell application "Notes"
            set noteList to {}
            repeat with n in notes
                set end of noteList to {id of n, name of n}
            end repeat
            return noteList
        end tell
        """
        let result = try await executeAppleScript(script)
        guard let resultString = result else { return [] }

        var notes: [NoteInfo] = []
        // Basic parsing
        let items = resultString.components(separatedBy: "}, {")
        for item in items {
            let cleaned = item.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
            let parts = cleaned.components(separatedBy: ", ")
            if parts.count >= 2 {
                notes.append(NoteInfo(id: parts[0], title: parts[1]))
            }
        }
        return notes
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Get note content
    public func getNoteContent(_ noteId: String) async throws -> String? {
        #if os(macOS)
        let script = """
        tell application "Notes"
            return plaintext of note id "\(noteId)"
        end tell
        """
        return try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Search notes
    public func searchNotes(_ query: String) async throws {
        #if os(macOS)
        let script = """
        tell application "Notes"
            activate
            tell application "System Events"
                keystroke "f" using command down
                delay 0.2
                keystroke "\(query)"
            end tell
        end tell
        """
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    #if os(macOS)
    private func executeAppleScript(_ source: String) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let script = NSAppleScript(source: source) {
                    let result = script.executeAndReturnError(&error)
                    if let error = error {
                        continuation.resume(throwing: IntegrationModuleError.scriptError(error.description))
                    } else {
                        continuation.resume(returning: result.stringValue)
                    }
                } else {
                    continuation.resume(throwing: IntegrationModuleError.scriptError("Failed to create script"))
                }
            }
        }
    }
    #endif
}

public struct NoteInfo: Sendable, Identifiable {
    public let id: String
    public let title: String
}
