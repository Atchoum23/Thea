// FileSystemMonitor.swift
// Thea V2 - File System Monitoring Service
//
// Monitors file system changes using FSEvents API
// to track document activity for THEA's life monitoring.

#if os(macOS)

import CoreServices
import Foundation
import os.log

// MARK: - File System Monitor Protocol

/// Delegate that receives notifications when file system changes are detected via FSEvents.
public protocol FileSystemMonitorDelegate: AnyObject, Sendable {
    nonisolated func fileSystemMonitor(_ _monitor: FileSystemMonitor, didDetect change: FileSystemChange)
}

// MARK: - File System Monitor

/// Monitors file system changes on macOS
// @unchecked Sendable: mutable state serialized on dedicated `eventQueue` DispatchQueue + FSEvents callback
public final class FileSystemMonitor: @unchecked Sendable {
    private let logger = Logger(subsystem: "ai.thea.app", category: "FileSystemMonitor")

    public weak var delegate: FileSystemMonitorDelegate?

    private var eventStream: FSEventStreamRef?
    private let watchPaths: [String]
    private var isRunning = false

    // Queue for event processing
    private let eventQueue = DispatchQueue(label: "ai.thea.fileSystemMonitor")

    // Recent events deduplication
    private var recentEvents: [String: Date] = [:]
    private let deduplicationWindowSeconds: TimeInterval = 2.0

    // Excluded patterns
    private let excludedPatterns: [String] = [
        ".DS_Store",
        ".localized",
        ".Trash",
        ".git",
        ".svn",
        "node_modules",
        "DerivedData",
        ".build",
        "__pycache__",
        ".cache",
        "*.swp",
        "*.tmp",
        "*~"
    ]

    public init(watchPaths: [String] = []) {
        // Expand paths
        self.watchPaths = watchPaths.map { path in
            if path.hasPrefix("~") {
                return FileManager.default.homeDirectoryForCurrentUser.path +
                    path.dropFirst()
            }
            return path
        }
    }

    deinit {
        if isRunning {
            stopSync()
        }
    }

    // MARK: - Lifecycle

    public func start() async {
        guard !isRunning else {
            logger.warning("File system monitor already running")
            return
        }

        // Verify paths exist
        let validPaths = watchPaths.filter { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }

        guard !validPaths.isEmpty else {
            logger.warning("No valid directories to watch")
            return
        }

        createEventStream(for: validPaths)
        isRunning = true

        logger.info("File system monitor started for \(validPaths.count) directories")
    }

    public func stop() async {
        stopSync()
    }

    private func stopSync() {
        guard isRunning else { return }

        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }

        isRunning = false
        logger.info("File system monitor stopped")
    }

    // MARK: - FSEvents Setup

    private func createEventStream(for paths: [String]) {
        let cfPaths = paths as CFArray

        // Callback context
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        // Create event stream
        eventStream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // Latency in seconds
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagUseCFTypes |
                    kFSEventStreamCreateFlagFileEvents |
                    kFSEventStreamCreateFlagNoDefer
            )
        )

        guard let stream = eventStream else {
            logger.error("Failed to create FSEvent stream")
            return
        }

        FSEventStreamSetDispatchQueue(stream, eventQueue)
        FSEventStreamStart(stream)
    }

    // MARK: - Event Handling

    fileprivate func handleEvents(paths: [String], flags: [UInt32]) {
        for (index, path) in paths.enumerated() {
            let eventFlags = flags[index]

            // Skip excluded patterns
            if shouldExclude(path: path) {
                continue
            }

            // Deduplicate rapid events
            if !shouldProcess(path: path) {
                continue
            }

            // Determine change type
            let changeType = determineChangeType(flags: eventFlags)

            // Get file info
            let (fileName, fileType) = getFileInfo(path: path)

            let change = FileSystemChange(
                path: path,
                fileName: fileName,
                fileType: fileType,
                type: changeType,
                timestamp: Date()
            )

            delegate?.fileSystemMonitor(self, didDetect: change)
        }
    }

    private func shouldExclude(path: String) -> Bool {
        let components = path.components(separatedBy: "/")
        let fileName = components.last ?? ""

        for pattern in excludedPatterns {
            if pattern.hasPrefix("*") {
                // Wildcard suffix match
                let suffix = String(pattern.dropFirst())
                if fileName.hasSuffix(suffix) {
                    return true
                }
            } else if components.contains(pattern) {
                // Directory match
                return true
            } else if fileName == pattern {
                // Exact match
                return true
            }
        }

        return false
    }

    private func shouldProcess(path: String) -> Bool {
        let now = Date()

        // Clean old entries
        recentEvents = recentEvents.filter { _, date in
            now.timeIntervalSince(date) < deduplicationWindowSeconds * 2
        }

        // Check if recently seen
        if let lastSeen = recentEvents[path],
           now.timeIntervalSince(lastSeen) < deduplicationWindowSeconds {
            return false
        }

        recentEvents[path] = now
        return true
    }

    private func determineChangeType(flags: UInt32) -> FileSystemChangeType {
        if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
            return .created
        }
        if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
            return .deleted
        }
        if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
            return .renamed
        }
        if flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 {
            return .modified
        }
        return .modified // Default
    }

    private func getFileInfo(path: String) -> (fileName: String, fileType: String?) {
        let url = URL(fileURLWithPath: path)
        let fileName = url.lastPathComponent

        // Get file type from extension
        let fileExtension = url.pathExtension.lowercased()
        let fileType: String? = fileExtension.isEmpty ? nil : fileExtension

        return (fileName, fileType)
    }
}

// MARK: - FSEvents Callback

private func fsEventCallback(
    streamRef _: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }

    let monitor = Unmanaged<FileSystemMonitor>.fromOpaque(info).takeUnretainedValue()

    // Extract paths
    let cfPaths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
    var paths: [String] = []
    for i in 0..<numEvents {
        if let cfPath = CFArrayGetValueAtIndex(cfPaths, i) {
            let path = Unmanaged<CFString>.fromOpaque(cfPath).takeUnretainedValue() as String
            paths.append(path)
        }
    }

    // Extract flags
    let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))

    // Process events
    monitor.handleEvents(paths: paths, flags: flags)
}

// MARK: - File System Change

public struct FileSystemChange: Sendable {
    public let path: String
    public let fileName: String
    public let fileType: String?
    public let type: FileSystemChangeType
    public let timestamp: Date

    public var directory: String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    public var isDocument: Bool {
        let documentTypes = ["doc", "docx", "pdf", "txt", "rtf", "pages", "md", "markdown"]
        return fileType.map { documentTypes.contains($0) } ?? false
    }

    public var isImage: Bool {
        let imageTypes = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "svg", "raw"]
        return fileType.map { imageTypes.contains($0) } ?? false
    }

    public var isCode: Bool {
        let codeTypes = ["swift", "py", "js", "ts", "go", "rs", "c", "cpp", "h", "java", "kt", "rb"]
        return fileType.map { codeTypes.contains($0) } ?? false
    }
}

public enum FileSystemChangeType: String, Codable, Sendable {
    case created
    case modified
    case deleted
    case renamed
}

#endif
