#if os(macOS)
    import Foundation

    /// Manages file operations for Cowork sessions
    @MainActor
    final class FileOperationsManager {
        private let folderAccess = FolderAccessManager.shared
        private let fileManager = FileManager.default

        enum OperationError: LocalizedError {
            case accessDenied(String)
            case fileNotFound(URL)
            case fileExists(URL)
            case operationFailed(String)
            case invalidPath(String)

            var errorDescription: String? {
                switch self {
                case let .accessDenied(reason):
                    "Access denied: \(reason)"
                case let .fileNotFound(url):
                    "File not found: \(url.lastPathComponent)"
                case let .fileExists(url):
                    "File already exists: \(url.lastPathComponent)"
                case let .operationFailed(reason):
                    "Operation failed: \(reason)"
                case let .invalidPath(path):
                    "Invalid path: \(path)"
                }
            }
        }

        // MARK: - Read Operations

        func readFile(at url: URL) throws -> Data {
            let validation = folderAccess.validateOperation(.read, at: url)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            guard fileManager.fileExists(atPath: url.path) else {
                throw OperationError.fileNotFound(url)
            }

            return try folderAccess.withAccess(to: url) {
                try Data(contentsOf: url)
            }
        }

        func readTextFile(at url: URL, encoding: String.Encoding = .utf8) throws -> String {
            let data = try readFile(at: url)
            guard let text = String(data: data, encoding: encoding) else {
                throw OperationError.operationFailed("Could not decode file as text")
            }
            return text
        }

        func listDirectory(at url: URL, includeHidden: Bool = false) throws -> [URL] {
            let validation = folderAccess.validateOperation(.read, at: url)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else {
                throw OperationError.invalidPath("Not a directory: \(url.path)")
            }

            return try folderAccess.withAccess(to: url) {
                let contents = try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                    options: includeHidden ? [] : [.skipsHiddenFiles]
                )
                return contents
            }
        }

        func getFileAttributes(at url: URL) throws -> FileAttributes {
            let validation = folderAccess.validateOperation(.read, at: url)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            return try folderAccess.withAccess(to: url) {
                let attrs = try fileManager.attributesOfItem(atPath: url.path)
                return FileAttributes(
                    size: attrs[.size] as? Int64 ?? 0,
                    createdAt: attrs[.creationDate] as? Date,
                    modifiedAt: attrs[.modificationDate] as? Date,
                    isDirectory: (attrs[.type] as? FileAttributeType) == .typeDirectory,
                    isReadOnly: !fileManager.isWritableFile(atPath: url.path)
                )
            }
        }

        // MARK: - Write Operations

        func writeFile(data: Data, to url: URL, overwrite: Bool = false) throws {
            let validation = folderAccess.validateOperation(.write, at: url)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            if fileManager.fileExists(atPath: url.path), !overwrite {
                throw OperationError.fileExists(url)
            }

            try folderAccess.withAccess(to: url.deletingLastPathComponent()) {
                try data.write(to: url, options: .atomic)
            }
        }

        func writeTextFile(_ text: String, to url: URL, encoding: String.Encoding = .utf8, overwrite: Bool = false) throws {
            guard let data = text.data(using: encoding) else {
                throw OperationError.operationFailed("Could not encode text")
            }
            try writeFile(data: data, to: url, overwrite: overwrite)
        }

        func createDirectory(at url: URL, withIntermediates: Bool = true) throws {
            let validation = folderAccess.validateOperation(.createDirectory, at: url.deletingLastPathComponent())
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            try folderAccess.withAccess(to: url.deletingLastPathComponent()) {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: withIntermediates)
            }
        }

        // MARK: - Modify Operations

        func moveFile(from source: URL, to destination: URL, overwrite: Bool = false) throws {
            // Check source read access
            var validation = folderAccess.validateOperation(.read, at: source)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            // Check destination write access
            validation = folderAccess.validateOperation(.write, at: destination)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            // Check source delete access (moving requires deleting from source)
            validation = folderAccess.validateOperation(.delete, at: source)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            if fileManager.fileExists(atPath: destination.path) {
                if overwrite {
                    try deleteFile(at: destination)
                } else {
                    throw OperationError.fileExists(destination)
                }
            }

            let sourceAccess = folderAccess.startAccessing(source)
            let destAccess = folderAccess.startAccessing(destination.deletingLastPathComponent())
            defer {
                if sourceAccess { folderAccess.stopAccessing(source) }
                if destAccess { folderAccess.stopAccessing(destination.deletingLastPathComponent()) }
            }

            try fileManager.moveItem(at: source, to: destination)
        }

        func copyFile(from source: URL, to destination: URL, overwrite: Bool = false) throws {
            // Check source read access
            var validation = folderAccess.validateOperation(.read, at: source)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            // Check destination write access
            validation = folderAccess.validateOperation(.write, at: destination)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            if fileManager.fileExists(atPath: destination.path) {
                if overwrite {
                    try deleteFile(at: destination)
                } else {
                    throw OperationError.fileExists(destination)
                }
            }

            let sourceAccess = folderAccess.startAccessing(source)
            let destAccess = folderAccess.startAccessing(destination.deletingLastPathComponent())
            defer {
                if sourceAccess { folderAccess.stopAccessing(source) }
                if destAccess { folderAccess.stopAccessing(destination.deletingLastPathComponent()) }
            }

            try fileManager.copyItem(at: source, to: destination)
        }

        func renameFile(at url: URL, to newName: String) throws {
            let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            try moveFile(from: url, to: newURL)
        }

        // MARK: - Delete Operations

        func deleteFile(at url: URL, moveToTrash: Bool = true) throws {
            let validation = folderAccess.validateOperation(.delete, at: url)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            guard fileManager.fileExists(atPath: url.path) else {
                throw OperationError.fileNotFound(url)
            }

            try folderAccess.withAccess(to: url) {
                if moveToTrash {
                    try fileManager.trashItem(at: url, resultingItemURL: nil)
                } else {
                    try fileManager.removeItem(at: url)
                }
            }
        }

        // MARK: - Batch Operations

        func batchCopy(files: [URL], to directory: URL, overwrite: Bool = false) throws -> [URL] {
            var copiedFiles: [URL] = []

            for file in files {
                let destination = directory.appendingPathComponent(file.lastPathComponent)
                try copyFile(from: file, to: destination, overwrite: overwrite)
                copiedFiles.append(destination)
            }

            return copiedFiles
        }

        func batchMove(files: [URL], to directory: URL, overwrite: Bool = false) throws -> [URL] {
            var movedFiles: [URL] = []

            for file in files {
                let destination = directory.appendingPathComponent(file.lastPathComponent)
                try moveFile(from: file, to: destination, overwrite: overwrite)
                movedFiles.append(destination)
            }

            return movedFiles
        }

        func batchDelete(files: [URL], moveToTrash: Bool = true) throws {
            for file in files {
                try deleteFile(at: file, moveToTrash: moveToTrash)
            }
        }

        // MARK: - Search Operations

        func searchFiles(
            in directory: URL,
            matching pattern: String,
            recursive: Bool = true,
            caseSensitive: Bool = false
        ) throws -> [URL] {
            let validation = folderAccess.validateOperation(.read, at: directory)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            var results: [URL] = []

            return try folderAccess.withAccess(to: directory) {
                let enumerator = fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: recursive ? [.skipsHiddenFiles] : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                )

                while let url = enumerator?.nextObject() as? URL {
                    let name = url.lastPathComponent
                    let matches = caseSensitive
                        ? name.contains(pattern)
                        : name.localizedCaseInsensitiveContains(pattern)

                    if matches {
                        results.append(url)
                    }
                }

                return results
            }
        }

        func findFiles(
            in directory: URL,
            withExtensions extensions: [String],
            recursive: Bool = true
        ) throws -> [URL] {
            let validation = folderAccess.validateOperation(.read, at: directory)
            if case let .denied(reason) = validation {
                throw OperationError.accessDenied(reason)
            }

            let lowercasedExtensions = Set(extensions.map { $0.lowercased() })
            var results: [URL] = []

            return try folderAccess.withAccess(to: directory) {
                let enumerator = fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: recursive ? [.skipsHiddenFiles] : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                )

                while let url = enumerator?.nextObject() as? URL {
                    if lowercasedExtensions.contains(url.pathExtension.lowercased()) {
                        results.append(url)
                    }
                }

                return results
            }
        }
    }

    // MARK: - Supporting Types

    struct FileAttributes {
        let size: Int64
        let createdAt: Date?
        let modifiedAt: Date?
        let isDirectory: Bool
        let isReadOnly: Bool

        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
#endif
