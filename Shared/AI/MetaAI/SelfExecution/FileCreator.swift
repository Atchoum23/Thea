// FileCreator.swift
import Foundation
import OSLog

public actor FileCreator {
    public static let shared = FileCreator()

    private let logger = Logger(subsystem: "com.thea.app", category: "FileCreator")
    private let basePath = "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"

    public struct CreationResult: Sendable {
        public let success: Bool
        public let path: String
        public let linesWritten: Int
        public let error: String?
    }

    public enum CreationError: Error, LocalizedError, Sendable {
        case fileAlreadyExists(path: String)
        case directoryCreationFailed(path: String)
        case writeFailure(path: String, reason: String)
        case invalidPath(path: String)

        public var errorDescription: String? {
            switch self {
            case .fileAlreadyExists(let path):
                return "File already exists: \(path)"
            case .directoryCreationFailed(let path):
                return "Failed to create directory: \(path)"
            case .writeFailure(let path, let reason):
                return "Failed to write \(path): \(reason)"
            case .invalidPath(let path):
                return "Invalid path: \(path)"
            }
        }
    }

    // MARK: - Public API

    public func createFile(at relativePath: String, content: String, overwrite: Bool = false) async throws -> CreationResult {
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)

        logger.info("Creating file: \(fullPath)")

        // Check if file exists
        if FileManager.default.fileExists(atPath: fullPath) && !overwrite {
            throw CreationError.fileAlreadyExists(path: fullPath)
        }

        // Create directory if needed
        let directory = (fullPath as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: directory) {
            do {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                logger.info("Created directory: \(directory)")
            } catch {
                throw CreationError.directoryCreationFailed(path: directory)
            }
        }

        // Write file
        do {
            try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
            let lines = content.components(separatedBy: "\n").count
            logger.info("Wrote \(lines) lines to \(fullPath)")

            return CreationResult(
                success: true,
                path: fullPath,
                linesWritten: lines,
                error: nil
            )
        } catch {
            throw CreationError.writeFailure(path: fullPath, reason: error.localizedDescription)
        }
    }

    public func editFile(at relativePath: String, newContent: String) async throws -> CreationResult {
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)

        logger.info("Editing file: \(fullPath)")

        // Verify file exists
        guard FileManager.default.fileExists(atPath: fullPath) else {
            throw CreationError.invalidPath(path: fullPath)
        }

        // Create backup
        let backupPath = fullPath + ".backup"
        try? FileManager.default.copyItem(atPath: fullPath, toPath: backupPath)

        // Write new content
        do {
            try newContent.write(toFile: fullPath, atomically: true, encoding: .utf8)
            let lines = newContent.components(separatedBy: "\n").count

            // Remove backup on success
            try? FileManager.default.removeItem(atPath: backupPath)

            return CreationResult(
                success: true,
                path: fullPath,
                linesWritten: lines,
                error: nil
            )
        } catch {
            // Restore backup on failure
            try? FileManager.default.removeItem(atPath: fullPath)
            try? FileManager.default.moveItem(atPath: backupPath, toPath: fullPath)

            throw CreationError.writeFailure(path: fullPath, reason: error.localizedDescription)
        }
    }

    public func readFile(at relativePath: String) async throws -> String {
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
        return try String(contentsOfFile: fullPath, encoding: .utf8)
    }

    public func fileExists(at relativePath: String) async -> Bool {
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: fullPath)
    }

    public func getRelatedFiles(for path: String) async -> [String: String] {
        var related: [String: String] = [:]

        // Get files in same directory
        let directory = (path as NSString).deletingLastPathComponent
        let fullDir = (basePath as NSString).appendingPathComponent(directory)

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: fullDir) else {
            return related
        }

        for file in contents where file.hasSuffix(".swift") {
            let relativePath = (directory as NSString).appendingPathComponent(file)
            let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
            if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                related[relativePath] = content
            }
        }

        return related
    }
}
