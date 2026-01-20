//
//  FinderIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
#endif

// MARK: - Finder Integration

/// Integration module for Finder file management
public actor FinderIntegration: AppIntegrationModule {
    public static let shared = FinderIntegration()

    // MARK: - Module Info

    public let moduleId = "finder"
    public let displayName = "Finder"
    public let bundleIdentifier = "com.apple.finder"
    public let icon = "folder"

    // MARK: - State

    private var isConnected = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Connection

    public func connect() async throws {
        #if os(macOS)
        isConnected = true
        #else
        throw AppIntegrationModuleError.notSupported
        #endif
    }

    public func disconnect() async {
        isConnected = false
    }

    public func isAvailable() async -> Bool {
        #if os(macOS)
        return true // Finder is always available on macOS
        #else
        return false
        #endif
    }

    // MARK: - File Operations

    /// Get selected files in Finder
    public func getSelectedFiles() async throws -> [URL] {
        #if os(macOS)
        let script = """
        tell application "Finder"
            set selectedItems to selection
            set filePaths to {}
            repeat with item in selectedItems
                set end of filePaths to POSIX path of (item as alias)
            end repeat
            return filePaths
        end tell
        """
        let result = try await executeAppleScript(script)
        guard let paths = result else { return [] }

        return paths.components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { URL(fileURLWithPath: $0) }
        #else
        throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Get current Finder location
    public func getCurrentLocation() async throws -> URL? {
        #if os(macOS)
        let script = """
        tell application "Finder"
            if (count of Finder windows) > 0 then
                return POSIX path of (target of front Finder window as alias)
            end if
        end tell
        """
        let result = try await executeAppleScript(script)
        return result.map { URL(fileURLWithPath: $0) }
        #else
        throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Open a folder in Finder
    public func openFolder(_ url: URL) async throws {
        #if os(macOS)
        await MainActor.run {
            _ = NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        }
        #else
        throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Reveal a file in Finder
    public func revealFile(_ url: URL) async throws {
        #if os(macOS)
        await MainActor.run {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        #else
        throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Create a new folder
    public func createFolder(at url: URL, named name: String) async throws -> URL {
        let folderURL = url.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL
    }

    /// Move file to trash
    public func moveToTrash(_ url: URL) async throws {
        #if os(macOS)
        var resultURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
        #else
        throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Duplicate a file
    public func duplicateFile(_ url: URL) async throws -> URL {
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let parent = url.deletingLastPathComponent()

        var counter = 1
        var newURL = parent.appendingPathComponent("\(baseName) copy.\(ext)")
        while FileManager.default.fileExists(atPath: newURL.path) {
            counter += 1
            newURL = parent.appendingPathComponent("\(baseName) copy \(counter).\(ext)")
        }

        try FileManager.default.copyItem(at: url, to: newURL)
        return newURL
    }

    /// Get file info
    public func getFileInfo(_ url: URL) async throws -> FileInfo {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

        return FileInfo(
            url: url,
            name: url.lastPathComponent,
            size: attributes[.size] as? Int64 ?? 0,
            creationDate: attributes[.creationDate] as? Date,
            modificationDate: attributes[.modificationDate] as? Date,
            isDirectory: (attributes[.type] as? FileAttributeType) == .typeDirectory
        )
    }

    /// Quick Look preview
    public func quickLook(_ urls: [URL]) async throws {
        #if os(macOS)
        let script = """
        tell application "Finder"
            activate
            select (POSIX file "\(urls.first?.path ?? "")")
            tell application "System Events"
                keystroke " "
            end tell
        end tell
        """
        _ = try await executeAppleScript(script)
        #else
        throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Get folder contents
    public func getFolderContents(_ url: URL) async throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles]
        )
        return contents.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Tags

    /// Get file tags
    public func getTags(_ url: URL) async throws -> [String] {
        #if os(macOS)
        let resourceValues = try url.resourceValues(forKeys: [.tagNamesKey])
        return resourceValues.tagNames ?? []
        #else
        throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Set file tags
    public func setTags(_ tags: [String], for url: URL) async throws {
        #if os(macOS)
        // Use NSURL extended attributes for tag setting
        try (url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
        #else
        throw AppIntegrationModuleError.notSupported
        #endif
    }

    // MARK: - Helper Methods

    #if os(macOS)
    private func executeAppleScript(_ source: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let script = NSAppleScript(source: source) {
                    let result = script.executeAndReturnError(&error)
                    if let error = error {
                        continuation.resume(throwing: AppIntegrationModuleError.scriptError(error.description))
                    } else {
                        continuation.resume(returning: result.stringValue)
                    }
                } else {
                    continuation.resume(throwing: AppIntegrationModuleError.scriptError("Failed to create script"))
                }
            }
        }
    }
    #endif
}

// MARK: - File Info

public struct FileInfo: Sendable {
    public let url: URL
    public let name: String
    public let size: Int64
    public let creationDate: Date?
    public let modificationDate: Date?
    public let isDirectory: Bool

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
