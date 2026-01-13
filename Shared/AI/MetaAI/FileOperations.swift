import Foundation

// MARK: - Advanced File Operations
// Comprehensive file system management

@MainActor
@Observable
final class FileOperations {
    static let shared = FileOperations()

    private(set) var operationHistory: [FileOperation] = []

    private init() {}

    // MARK: - File Reading

    nonisolated func readFile(at path: String) async throws -> String {
        let url = URL(fileURLWithPath: path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    nonisolated func readBinaryFile(at path: String) async throws -> Data {
        let url = URL(fileURLWithPath: path)
        return try Data(contentsOf: url)
    }

    nonisolated func readLines(at path: String) async throws -> [String] {
        let content = try await readFile(at: path)
        return content.components(separatedBy: .newlines)
    }

    // MARK: - File Writing

    nonisolated func writeFile(content: String, to path: String) async throws {
        let url = URL(fileURLWithPath: path)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    nonisolated func writeBinaryFile(data: Data, to path: String) async throws {
        let url = URL(fileURLWithPath: path)
        try data.write(to: url, options: .atomic)
    }

    nonisolated func appendToFile(content: String, at path: String) async throws {
        let url = URL(fileURLWithPath: path)

        if FileManager.default.fileExists(atPath: path) {
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { try? fileHandle.close() }

            fileHandle.seekToEndOfFile()
            if let data = content.data(using: .utf8) {
                fileHandle.write(data)
            }
        } else {
            try await writeFile(content: content, to: path)
        }
    }

    // MARK: - Directory Operations

    nonisolated func listDirectory(at path: String, recursive: Bool = false) async throws -> [String] {
        let url = URL(fileURLWithPath: path)

        if recursive {
            let enumerator = FileManager.default.enumerator(atPath: path)
            return enumerator?.allObjects.compactMap { $0 as? String } ?? []
        } else {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return contents.map { $0.lastPathComponent }
        }
    }

    nonisolated func createDirectory(at path: String) async throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    nonisolated func deleteDirectory(at path: String) async throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - File Search

    nonisolated func findFiles(
        in directory: String,
        matching pattern: String,
        recursive: Bool = true
    ) async throws -> [String] {
        let files = try await listDirectory(at: directory, recursive: recursive)

        return files.filter { filename in
            filename.range(of: pattern, options: .regularExpression) != nil
        }
    }

    nonisolated func searchFileContent(
        in directory: String,
        for searchTerm: String,
        fileTypes: [String] = []
    ) async throws -> [FileSearchResult] {
        var results: [FileSearchResult] = []
        let files = try await listDirectory(at: directory, recursive: true)

        for file in files {
            // Filter by file type if specified
            if !fileTypes.isEmpty {
                let fileExtension = (file as NSString).pathExtension
                guard fileTypes.contains(fileExtension) else { continue }
            }

            let fullPath = (directory as NSString).appendingPathComponent(file)

            do {
                let content = try await readFile(at: fullPath)
                let lines = content.components(separatedBy: .newlines)

                for (index, line) in lines.enumerated() {
                    if line.contains(searchTerm) {
                        results.append(FileSearchResult(
                            file: file,
                            line: index + 1,
                            content: line
                        ))
                    }
                }
            } catch {
                // Skip files that can't be read
                continue
            }
        }

        return results
    }

    // MARK: - File Manipulation

    nonisolated func copyFile(from source: String, to destination: String) async throws {
        let sourceURL = URL(fileURLWithPath: source)
        let destURL = URL(fileURLWithPath: destination)
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
    }

    nonisolated func moveFile(from source: String, to destination: String) async throws {
        let sourceURL = URL(fileURLWithPath: source)
        let destURL = URL(fileURLWithPath: destination)
        try FileManager.default.moveItem(at: sourceURL, to: destURL)
    }

    nonisolated func deleteFile(at path: String) async throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.removeItem(at: url)
    }

    nonisolated func renameFile(at path: String, to newName: String) async throws {
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent()
        let newURL = directory.appendingPathComponent(newName)
        try FileManager.default.moveItem(at: url, to: newURL)
    }

    // MARK: - File Information

    nonisolated func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    nonisolated func fileSize(at path: String) async throws -> Int64 {
        let url = URL(fileURLWithPath: path)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }

    nonisolated func fileModificationDate(at path: String) async throws -> Date {
        let url = URL(fileURLWithPath: path)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.modificationDate] as? Date ?? Date()
    }

    // MARK: - Batch Operations

    nonisolated func batchRename(
        in directory: String,
        pattern: String,
        replacement: String
    ) async throws -> Int {
        let files = try await findFiles(in: directory, matching: pattern, recursive: false)
        var count = 0

        for file in files {
            let fullPath = (directory as NSString).appendingPathComponent(file)
            let newName = file.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)

            if newName != file {
                try await renameFile(at: fullPath, to: newName)
                count += 1
            }
        }

        return count
    }

    nonisolated func batchDelete(
        in directory: String,
        matching pattern: String
    ) async throws -> Int {
        let files = try await findFiles(in: directory, matching: pattern, recursive: false)

        for file in files {
            let fullPath = (directory as NSString).appendingPathComponent(file)
            try await deleteFile(at: fullPath)
        }

        return files.count
    }

    // MARK: - File Organization

    nonisolated func organizeByExtension(in directory: String) async throws {
        let files = try await listDirectory(at: directory, recursive: false)

        for file in files {
            let fullPath = (directory as NSString).appendingPathComponent(file)
            let fileExtension = (file as NSString).pathExtension

            guard !fileExtension.isEmpty else { continue }

            let extensionDir = (directory as NSString).appendingPathComponent(fileExtension)
            try await createDirectory(at: extensionDir)

            let destination = (extensionDir as NSString).appendingPathComponent(file)
            try await moveFile(from: fullPath, to: destination)
        }
    }

    nonisolated func organizeByDate(in directory: String) async throws {
        let files = try await listDirectory(at: directory, recursive: false)

        for file in files {
            let fullPath = (directory as NSString).appendingPathComponent(file)
            let modDate = try await fileModificationDate(at: fullPath)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let monthFolder = formatter.string(from: modDate)

            let monthDir = (directory as NSString).appendingPathComponent(monthFolder)
            try await createDirectory(at: monthDir)

            let destination = (monthDir as NSString).appendingPathComponent(file)
            try await moveFile(from: fullPath, to: destination)
        }
    }
}

// MARK: - Models

struct FileOperation: Identifiable {
    let id: UUID
    let type: OperationType
    let path: String
    let timestamp: Date
    var success: Bool

    enum OperationType {
        case read, write, delete, move, copy
    }
}

struct FileSearchResult: Identifiable {
    let id = UUID()
    let file: String
    let line: Int
    let content: String
}

enum FileError: LocalizedError {
    case fileNotFound
    case permissionDenied
    case invalidPath

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .permissionDenied:
            return "Permission denied"
        case .invalidPath:
            return "Invalid file path"
        }
    }
}
