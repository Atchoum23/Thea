//
//  IncrementalIndexer.swift
//  Thea
//
//  Incremental file watching and indexing for the semantic codebase system
//  Watches for file changes and updates the index in real-time
//

import Foundation
import os.log

// MARK: - File Change Event

/// Represents a change to a file in the codebase
public struct FileChangeEvent: Sendable {
    public enum ChangeType: String, Sendable {
        case created
        case modified
        case deleted
        case renamed
    }

    public let path: String
    public let changeType: ChangeType
    public let timestamp: Date
    public let oldPath: String?  // For renames

    public init(path: String, changeType: ChangeType, timestamp: Date = Date(), oldPath: String? = nil) {
        self.path = path
        self.changeType = changeType
        self.timestamp = timestamp
        self.oldPath = oldPath
    }
}

// MARK: - File Watcher Delegate

/// Protocol for receiving file change notifications
public protocol FileWatcherDelegate: AnyObject, Sendable {
    func fileWatcher(_ watcher: IncrementalIndexer, didDetectChanges changes: [FileChangeEvent]) async
}

// MARK: - Incremental Indexer

/// Watches for file system changes and triggers incremental index updates
/// Optimized for large codebases with debouncing and batching
public actor IncrementalIndexer {
    public static let shared = IncrementalIndexer()

    private let logger = Logger(subsystem: "ai.thea.app", category: "IncrementalIndexer")

    // MARK: - State

    private var isWatching = false
    private var watchedPaths: Set<String> = []
    private var fileSystemSources: [String: DispatchSourceFileSystemObject] = [:]
    private var directoryMonitors: [String: DirectoryMonitor] = [:]

    // Debouncing
    private var pendingChanges: [String: FileChangeEvent] = [:]
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.5  // 500ms debounce

    // File state tracking for change detection
    private var fileModificationDates: [String: Date] = [:]
    private var fileHashes: [String: String] = [:]

    // Configuration
    private var ignoredPatterns: [String] = [
        ".git", ".svn", ".hg",
        "node_modules", ".build", "DerivedData",
        ".DS_Store", "*.swp", "*.tmp",
        "Pods", "Carthage", ".cache"
    ]

    // Delegate for notifications
    private weak var delegate: (any FileWatcherDelegate)?

    // Callback for changes
    private var onChangesDetected: (([FileChangeEvent]) async -> Void)?

    private init() {}

    // MARK: - Configuration

    /// Set the delegate for file change notifications
    public func setDelegate(_ delegate: any FileWatcherDelegate) {
        self.delegate = delegate
    }

    /// Set a callback for when changes are detected
    public func setOnChangesDetected(_ callback: @escaping ([FileChangeEvent]) async -> Void) {
        self.onChangesDetected = callback
    }

    /// Add patterns to ignore during watching
    public func addIgnoredPatterns(_ patterns: [String]) {
        ignoredPatterns.append(contentsOf: patterns)
    }

    /// Remove patterns from the ignore list
    public func removeIgnoredPatterns(_ patterns: [String]) {
        ignoredPatterns.removeAll { patterns.contains($0) }
    }

    // MARK: - Watching

    /// Start watching a directory for changes
    public func startWatching(directory: String) async throws {
        guard !watchedPaths.contains(directory) else {
            logger.info("Already watching: \(directory)")
            return
        }

        let expandedPath = (directory as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw IncrementalIndexerError.directoryNotFound(directory)
        }

        logger.info("Starting to watch: \(directory)")

        // Initial scan to build file state
        await scanDirectory(expandedPath)

        // Set up directory monitor
        let pathToWatch = expandedPath
        let monitor = DirectoryMonitor(path: expandedPath) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleDirectoryChange(pathToWatch)
            }
        }

        try monitor.start()
        directoryMonitors[expandedPath] = monitor
        watchedPaths.insert(expandedPath)
        isWatching = true

        logger.info("Now watching \(self.watchedPaths.count) directories")
    }

    /// Stop watching a specific directory
    public func stopWatching(directory: String) async {
        let expandedPath = (directory as NSString).expandingTildeInPath

        if let monitor = directoryMonitors[expandedPath] {
            monitor.stop()
            directoryMonitors.removeValue(forKey: expandedPath)
        }

        watchedPaths.remove(expandedPath)

        // Clean up file state for this directory
        fileModificationDates = fileModificationDates.filter { !$0.key.hasPrefix(expandedPath) }
        fileHashes = fileHashes.filter { !$0.key.hasPrefix(expandedPath) }

        logger.info("Stopped watching: \(directory)")

        if watchedPaths.isEmpty {
            isWatching = false
        }
    }

    /// Stop all watching
    public func stopAll() async {
        for (path, monitor) in directoryMonitors {
            monitor.stop()
            logger.debug("Stopped monitor for: \(path)")
        }

        directoryMonitors.removeAll()
        watchedPaths.removeAll()
        fileModificationDates.removeAll()
        fileHashes.removeAll()
        pendingChanges.removeAll()
        debounceTask?.cancel()
        debounceTask = nil
        isWatching = false

        logger.info("Stopped all file watching")
    }

    // MARK: - Directory Scanning

    /// Scan a directory and record file states
    private func scanDirectory(_ path: String) async {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            logger.error("Failed to create enumerator for: \(path)")
            return
        }

        var scannedCount = 0

        while let url = enumerator.nextObject() as? URL {
            // Check if should skip
            if shouldIgnore(url.path) {
                enumerator.skipDescendants()
                continue
            }

            // Only track regular files
            guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }

            let filePath = url.path
            if let modDate = resourceValues.contentModificationDate {
                fileModificationDates[filePath] = modDate
            }

            scannedCount += 1

            // Yield periodically for large directories
            if scannedCount % 1000 == 0 {
                await Task.yield()
            }
        }

        logger.info("Scanned \(scannedCount) files in \(path)")
    }

    /// Check if a path should be ignored
    private func shouldIgnore(_ path: String) -> Bool {
        let fileName = (path as NSString).lastPathComponent

        for pattern in ignoredPatterns {
            if pattern.contains("*") {
                // Simple glob matching
                let regex = pattern
                    .replacingOccurrences(of: ".", with: "\\.")
                    .replacingOccurrences(of: "*", with: ".*")
                if let range = fileName.range(of: regex, options: .regularExpression),
                   range.lowerBound == fileName.startIndex {
                    return true
                }
            } else {
                // Exact match
                if fileName == pattern || path.contains("/\(pattern)/") {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Change Detection

    /// Handle a directory change notification
    private func handleDirectoryChange(_ directory: String) async {
        // Re-scan the directory to detect what changed
        let changes = await detectChanges(in: directory)

        guard !changes.isEmpty else { return }

        // Add to pending changes with debouncing
        for change in changes {
            pendingChanges[change.path] = change
        }

        // Cancel existing debounce task
        debounceTask?.cancel()

        // Schedule new debounce task
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await self.flushPendingChanges()
        }
    }

    /// Detect what changed in a directory
    private func detectChanges(in directory: String) async -> [FileChangeEvent] {
        var changes: [FileChangeEvent] = []

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return changes
        }

        var currentFiles: Set<String> = []

        while let url = enumerator.nextObject() as? URL {
            if shouldIgnore(url.path) {
                enumerator.skipDescendants()
                continue
            }

            guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }

            let filePath = url.path
            currentFiles.insert(filePath)

            let currentModDate = resourceValues.contentModificationDate

            if let previousModDate = fileModificationDates[filePath] {
                // File existed before - check if modified
                if let currentModDate = currentModDate, currentModDate > previousModDate {
                    changes.append(FileChangeEvent(path: filePath, changeType: .modified))
                    fileModificationDates[filePath] = currentModDate
                }
            } else {
                // New file
                changes.append(FileChangeEvent(path: filePath, changeType: .created))
                if let currentModDate = currentModDate {
                    fileModificationDates[filePath] = currentModDate
                }
            }
        }

        // Find deleted files
        let previousFiles = Set(fileModificationDates.keys.filter { $0.hasPrefix(directory) })
        let deletedFiles = previousFiles.subtracting(currentFiles)

        for deletedPath in deletedFiles {
            changes.append(FileChangeEvent(path: deletedPath, changeType: .deleted))
            fileModificationDates.removeValue(forKey: deletedPath)
            fileHashes.removeValue(forKey: deletedPath)
        }

        return changes
    }

    /// Flush pending changes to delegates/callbacks
    private func flushPendingChanges() async {
        guard !pendingChanges.isEmpty else { return }

        let changes = Array(pendingChanges.values)
        pendingChanges.removeAll()

        logger.info("Flushing \(changes.count) file changes")

        // Notify delegate
        if let delegate = delegate {
            await delegate.fileWatcher(self, didDetectChanges: changes)
        }

        // Call callback
        if let callback = onChangesDetected {
            await callback(changes)
        }
    }

    // MARK: - Manual Refresh

    /// Force a refresh of all watched directories
    public func refreshAll() async -> [FileChangeEvent] {
        var allChanges: [FileChangeEvent] = []

        for directory in watchedPaths {
            let changes = await detectChanges(in: directory)
            allChanges.append(contentsOf: changes)
        }

        if !allChanges.isEmpty {
            await delegate?.fileWatcher(self, didDetectChanges: allChanges)
            await onChangesDetected?(allChanges)
        }

        return allChanges
    }

    // MARK: - Query Methods

    /// Get the list of watched directories
    public func getWatchedDirectories() -> [String] {
        Array(watchedPaths)
    }

    /// Check if a path is being watched
    public func isWatching(path: String) -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        return watchedPaths.contains { expandedPath.hasPrefix($0) }
    }

    /// Get the count of tracked files
    public func getTrackedFileCount() -> Int {
        fileModificationDates.count
    }

    /// Check if watching is active
    public func isActive() -> Bool {
        isWatching
    }
}

// MARK: - Directory Monitor

/// Low-level directory monitor using GCD
private final class DirectoryMonitor: @unchecked Sendable {
    private let path: String
    private let callback: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "ai.thea.directoryMonitor", qos: .utility)

    init(path: String, callback: @escaping () -> Void) {
        self.path = path
        self.callback = callback
    }

    func start() throws {
        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            throw IncrementalIndexerError.cannotOpenDirectory(path)
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.callback()
        }

        source?.setCancelHandler {
            close(fileDescriptor)
        }

        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}

// MARK: - Errors

/// Errors that can occur during incremental indexing
public enum IncrementalIndexerError: Error, LocalizedError {
    case directoryNotFound(String)
    case cannotOpenDirectory(String)
    case watchingNotSupported
    case alreadyWatching(String)

    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .cannotOpenDirectory(let path):
            return "Cannot open directory for watching: \(path)"
        case .watchingNotSupported:
            return "File system watching is not supported"
        case .alreadyWatching(let path):
            return "Already watching: \(path)"
        }
    }
}

// MARK: - Integration with SemanticCodeIndexer

extension IncrementalIndexer {
    /// Connect this indexer to a SemanticCodeIndexer for automatic updates
    public func connectToSemanticIndexer(_ indexer: SemanticCodeIndexer) {
        setOnChangesDetected { changes in
            for change in changes {
                switch change.changeType {
                case .created, .modified:
                    await indexer.indexFile(at: change.path, rootPath: nil)
                case .deleted:
                    await indexer.removeFile(at: change.path)
                case .renamed:
                    if let oldPath = change.oldPath {
                        await indexer.handleFileRename(from: oldPath, to: change.path)
                    } else {
                        await indexer.indexFile(at: change.path, rootPath: nil)
                    }
                }
            }
        }
    }
}

// MARK: - Batch Change Summary

/// Summary of batch file changes for reporting
public struct FileChangeSummary: Sendable {
    public let created: Int
    public let modified: Int
    public let deleted: Int
    public let renamed: Int
    public let totalFiles: Int
    public let timestamp: Date

    public init(from changes: [FileChangeEvent]) {
        var created = 0
        var modified = 0
        var deleted = 0
        var renamed = 0

        for change in changes {
            switch change.changeType {
            case .created: created += 1
            case .modified: modified += 1
            case .deleted: deleted += 1
            case .renamed: renamed += 1
            }
        }

        self.created = created
        self.modified = modified
        self.deleted = deleted
        self.renamed = renamed
        self.totalFiles = changes.count
        self.timestamp = Date()
    }

    public var description: String {
        var parts: [String] = []
        if created > 0 { parts.append("\(created) created") }
        if modified > 0 { parts.append("\(modified) modified") }
        if deleted > 0 { parts.append("\(deleted) deleted") }
        if renamed > 0 { parts.append("\(renamed) renamed") }
        return parts.isEmpty ? "No changes" : parts.joined(separator: ", ")
    }
}
