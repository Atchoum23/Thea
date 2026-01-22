//
//  RemoteFileService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation

// MARK: - Remote File Service

/// Secure file access service for remote operations
@MainActor
public class RemoteFileService: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isEnabled = true
    @Published public private(set) var transfersInProgress: [String: TransferProgress] = [:]
    @Published public private(set) var totalBytesTransferred: Int64 = 0

    // MARK: - Configuration

    public var allowedPaths: [String] = []
    public var blockedPaths: [String] = ["/etc", "/var", "/private", "/System", "/Library"]
    public var maxFileSize: Int64 = 1_073_741_824 // 1GB
    public var chunkSize: Int = 1_048_576 // 1MB

    // MARK: - Security

    private let securityManager = FileSecurityManager()

    // MARK: - Initialization

    public init() {}

    // MARK: - Request Handling

    public func handleRequest(_ request: FileRequest) async throws -> FileResponse {
        switch request {
        case .list(let path, let recursive, let showHidden):
            return try await listDirectory(path: path, recursive: recursive, showHidden: showHidden)

        case .info(let path):
            return try await getFileInfo(path: path)

        case .read(let path, let offset, let length):
            return try await readFile(path: path, offset: offset, length: length)

        case .write(let path, let data, let offset, let append):
            return try await writeFile(path: path, data: data, offset: offset, append: append)

        case .delete(let path, let recursive):
            return try await deleteFile(path: path, recursive: recursive)

        case .move(let from, let to):
            return try await moveFile(from: from, to: to)

        case .copy(let from, let to):
            return try await copyFile(from: from, to: to)

        case .createDirectory(let path, let intermediate):
            return try await createDirectory(path: path, intermediate: intermediate)

        case .download(let path):
            return try await downloadFile(path: path)

        case .upload(let path, let data, let overwrite):
            return try await uploadFile(path: path, data: data, overwrite: overwrite)
        }
    }

    // MARK: - List Directory

    private func listDirectory(path: String, recursive: Bool, showHidden: Bool) async throws -> FileResponse {
        let resolvedPath = try securityManager.validateAndResolvePath(path, allowedPaths: allowedPaths, blockedPaths: blockedPaths)

        let fileManager = FileManager.default
        var items: [FileItem] = []

        if recursive {
            if let enumerator = fileManager.enumerator(atPath: resolvedPath) {
                while let relativePath = enumerator.nextObject() as? String {
                    let fullPath = (resolvedPath as NSString).appendingPathComponent(relativePath)
                    let name = (relativePath as NSString).lastPathComponent

                    if !showHidden && name.hasPrefix(".") {
                        continue
                    }

                    if let item = try? createFileItem(at: fullPath, relativePath: relativePath) {
                        items.append(item)
                    }
                }
            }
        } else {
            let contents = try fileManager.contentsOfDirectory(atPath: resolvedPath)
            for name in contents {
                if !showHidden && name.hasPrefix(".") {
                    continue
                }

                let fullPath = (resolvedPath as NSString).appendingPathComponent(name)
                if let item = try? createFileItem(at: fullPath, relativePath: name) {
                    items.append(item)
                }
            }
        }

        return .listing(items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
    }

    // MARK: - File Info

    private func getFileInfo(path: String) async throws -> FileResponse {
        let resolvedPath = try securityManager.validateAndResolvePath(path, allowedPaths: allowedPaths, blockedPaths: blockedPaths)

        let item = try createFileItem(at: resolvedPath, relativePath: (path as NSString).lastPathComponent)
        return .info(item)
    }

    // MARK: - Read File

    private func readFile(path: String, offset: Int64, length: Int64) async throws -> FileResponse {
        let resolvedPath = try securityManager.validateAndResolvePath(path, allowedPaths: allowedPaths, blockedPaths: blockedPaths)

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: resolvedPath) else {
            return .error("File not found: \(path)")
        }

        guard let fileHandle = FileHandle(forReadingAtPath: resolvedPath) else {
            return .error("Cannot open file for reading")
        }

        defer { try? fileHandle.close() }

        // Seek to offset
        try fileHandle.seek(toOffset: UInt64(offset))

        // Read requested length
        let data = try fileHandle.read(upToCount: Int(length)) ?? Data()

        totalBytesTransferred += Int64(data.count)

        // Check if we've read all
        let fileSize = try fileHandle.seekToEnd()
        let isComplete = offset + Int64(data.count) >= fileSize

        return .data(data, isComplete: isComplete)
    }

    // MARK: - Write File

    private func writeFile(path: String, data: Data, offset: Int64, append: Bool) async throws -> FileResponse {
        let resolvedPath = try securityManager.validateAndResolvePath(path, allowedPaths: allowedPaths, blockedPaths: blockedPaths)

        let fileManager = FileManager.default

        // Create file if doesn't exist
        if !fileManager.fileExists(atPath: resolvedPath) {
            fileManager.createFile(atPath: resolvedPath, contents: nil)
        }

        guard let fileHandle = FileHandle(forWritingAtPath: resolvedPath) else {
            return .error("Cannot open file for writing")
        }

        defer { try? fileHandle.close() }

        if append {
            try fileHandle.seekToEnd()
        } else {
            try fileHandle.seek(toOffset: UInt64(offset))
        }

        try fileHandle.write(contentsOf: data)
        totalBytesTransferred += Int64(data.count)

        return .success("Written \(data.count) bytes")
    }

    // MARK: - Delete File

    private func deleteFile(path: String, recursive: Bool) async throws -> FileResponse {
        let resolvedPath = try securityManager.validateAndResolvePath(path, allowedPaths: allowedPaths, blockedPaths: blockedPaths)

        let fileManager = FileManager.default

        // Extra safety check for critical paths
        let criticalPaths = ["/", "/Users", "/System", "/Library", "/Applications", "/bin", "/sbin", "/usr"]
        for critical in criticalPaths {
            if resolvedPath == critical || resolvedPath.hasPrefix(critical + "/") && resolvedPath.components(separatedBy: "/").count <= 3 {
                return .error("Cannot delete critical system path")
            }
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDirectory) else {
            return .error("Path not found: \(path)")
        }

        if isDirectory.boolValue && !recursive {
            // Check if directory is empty
            let contents = try? fileManager.contentsOfDirectory(atPath: resolvedPath)
            if let contents = contents, !contents.isEmpty {
                return .error("Directory is not empty. Use recursive delete.")
            }
        }

        try fileManager.removeItem(atPath: resolvedPath)

        return .success("Deleted: \(path)")
    }

    // MARK: - Move File

    private func moveFile(from: String, to: String) async throws -> FileResponse {
        let fromPath = try securityManager.validateAndResolvePath(from, allowedPaths: allowedPaths, blockedPaths: blockedPaths)
        let toPath = try securityManager.validateAndResolvePath(to, allowedPaths: allowedPaths, blockedPaths: blockedPaths)

        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: fromPath) else {
            return .error("Source not found: \(from)")
        }

        // Create parent directory if needed
        let parentDir = (toPath as NSString).deletingLastPathComponent
        try fileManager.createDirectory(atPath: parentDir, withIntermediateDirectories: true)

        try fileManager.moveItem(atPath: fromPath, toPath: toPath)

        return .success("Moved from \(from) to \(to)")
    }

    // MARK: - Copy File

    private func copyFile(from: String, to: String) async throws -> FileResponse {
        let fromPath = try securityManager.validateAndResolvePath(from, allowedPaths: allowedPaths, blockedPaths: blockedPaths)
        let toPath = try securityManager.validateAndResolvePath(to, allowedPaths: allowedPaths, blockedPaths: blockedPaths)

        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: fromPath) else {
            return .error("Source not found: \(from)")
        }

        // Create parent directory if needed
        let parentDir = (toPath as NSString).deletingLastPathComponent
        try fileManager.createDirectory(atPath: parentDir, withIntermediateDirectories: true)

        try fileManager.copyItem(atPath: fromPath, toPath: toPath)

        return .success("Copied from \(from) to \(to)")
    }

    // MARK: - Create Directory

    private func createDirectory(path: String, intermediate: Bool) async throws -> FileResponse {
        let resolvedPath = try securityManager.validateAndResolvePath(path, allowedPaths: allowedPaths, blockedPaths: blockedPaths)

        let fileManager = FileManager.default

        try fileManager.createDirectory(atPath: resolvedPath, withIntermediateDirectories: intermediate)

        return .success("Created directory: \(path)")
    }

    // MARK: - Download File

    private func downloadFile(path: String) async throws -> FileResponse {
        let resolvedPath = try securityManager.validateAndResolvePath(path, allowedPaths: allowedPaths, blockedPaths: blockedPaths)

        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: resolvedPath) else {
            return .error("File not found: \(path)")
        }

        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            return .error("Cannot download directory. Use archive first.")
        }

        // Check file size
        let attributes = try fileManager.attributesOfItem(atPath: resolvedPath)
        let fileSize = attributes[.size] as? Int64 ?? 0

        if fileSize > maxFileSize {
            return .error("File too large (\(fileSize) bytes). Max: \(maxFileSize) bytes")
        }

        // Read entire file
        let data = try Data(contentsOf: URL(fileURLWithPath: resolvedPath))
        totalBytesTransferred += Int64(data.count)

        return .data(data, isComplete: true)
    }

    // MARK: - Upload File

    private func uploadFile(path: String, data: Data, overwrite: Bool) async throws -> FileResponse {
        let resolvedPath = try securityManager.validateAndResolvePath(path, allowedPaths: allowedPaths, blockedPaths: blockedPaths)

        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: resolvedPath) && !overwrite {
            return .error("File already exists and overwrite is disabled")
        }

        if Int64(data.count) > maxFileSize {
            return .error("File too large (\(data.count) bytes). Max: \(maxFileSize) bytes")
        }

        // Create parent directory if needed
        let parentDir = (resolvedPath as NSString).deletingLastPathComponent
        try fileManager.createDirectory(atPath: parentDir, withIntermediateDirectories: true)

        try data.write(to: URL(fileURLWithPath: resolvedPath))
        totalBytesTransferred += Int64(data.count)

        return .success("Uploaded \(data.count) bytes to \(path)")
    }

    // MARK: - Helpers

    private func createFileItem(at path: String, relativePath: String) throws -> FileItem {
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: path)

        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)

        let isSymlink = attributes[.type] as? FileAttributeType == .typeSymbolicLink
        var symlinkTarget: String?
        if isSymlink {
            symlinkTarget = try? fileManager.destinationOfSymbolicLink(atPath: path)
        }

        let name = (path as NSString).lastPathComponent

        return FileItem(
            name: name,
            path: path,
            isDirectory: isDirectory.boolValue,
            size: attributes[.size] as? Int64 ?? 0,
            createdAt: attributes[.creationDate] as? Date,
            modifiedAt: attributes[.modificationDate] as? Date,
            permissions: permissionsString(from: attributes[.posixPermissions] as? Int ?? 0),
            isHidden: name.hasPrefix("."),
            isSymlink: isSymlink,
            symlinkTarget: symlinkTarget
        )
    }

    private func permissionsString(from posix: Int) -> String {
        let owner = permissionTriple((posix >> 6) & 0x7)
        let group = permissionTriple((posix >> 3) & 0x7)
        let other = permissionTriple(posix & 0x7)
        return owner + group + other
    }

    private func permissionTriple(_ value: Int) -> String {
        var result = ""
        result += (value & 0x4) != 0 ? "r" : "-"
        result += (value & 0x2) != 0 ? "w" : "-"
        result += (value & 0x1) != 0 ? "x" : "-"
        return result
    }
}

// MARK: - Transfer Progress

public struct TransferProgress: Sendable {
    public let id: String
    public let fileName: String
    public let totalBytes: Int64
    public var transferredBytes: Int64
    public var startTime: Date
    public var isUpload: Bool

    public var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(transferredBytes) / Double(totalBytes)
    }

    public var bytesPerSecond: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed > 0 else { return 0 }
        return Double(transferredBytes) / elapsed
    }
}

// MARK: - File Security Manager

private class FileSecurityManager {

    func validateAndResolvePath(_ path: String, allowedPaths: [String], blockedPaths: [String]) throws -> String {
        // Expand tilde
        let expandedPath = (path as NSString).expandingTildeInPath

        // Resolve to absolute path
        let resolvedPath = (expandedPath as NSString).standardizingPath

        // Check for path traversal attacks
        if path.contains("..") {
            throw FileSecurityError.pathTraversalAttempt
        }

        // Check for null bytes
        if path.contains("\0") {
            throw FileSecurityError.invalidPath("Path contains null bytes")
        }

        // Check against blocked paths
        for blocked in blockedPaths {
            let expandedBlocked = (blocked as NSString).expandingTildeInPath
            if resolvedPath == expandedBlocked || resolvedPath.hasPrefix(expandedBlocked + "/") {
                throw FileSecurityError.accessDenied("Path is blocked: \(blocked)")
            }
        }

        // If allowed paths specified, check against them
        if !allowedPaths.isEmpty {
            var allowed = false
            for allowedPath in allowedPaths {
                let expandedAllowed = (allowedPath as NSString).expandingTildeInPath
                if resolvedPath == expandedAllowed || resolvedPath.hasPrefix(expandedAllowed + "/") {
                    allowed = true
                    break
                }
            }
            if !allowed {
                throw FileSecurityError.accessDenied("Path not in allowed list")
            }
        }

        return resolvedPath
    }
}

// MARK: - File Security Error

public enum FileSecurityError: Error, LocalizedError, Sendable {
    case pathTraversalAttempt
    case invalidPath(String)
    case accessDenied(String)

    public var errorDescription: String? {
        switch self {
        case .pathTraversalAttempt: return "Path traversal attack detected"
        case .invalidPath(let reason): return "Invalid path: \(reason)"
        case .accessDenied(let reason): return "Access denied: \(reason)"
        }
    }
}
