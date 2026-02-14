//
//  FileSystemObserver.swift
//  Thea
//
//  Created by Thea
//  Deep System Awareness - File System Monitoring
//

#if os(macOS)
    import Foundation
    import os.log

    // MARK: - File System Observer

    /// Monitors file system events for project activity detection and document tracking
    public actor FileSystemObserver {
        public static let shared = FileSystemObserver()

        private let logger = Logger(subsystem: "app.thea", category: "FileSystemObserver")

        // FSEvents stream
        private var eventStream: FSEventStreamRef?
        private var isRunning = false

        // Watched paths
        private var watchedPaths: Set<String> = []

        // Recent events buffer
        private var recentEvents: [FileSystemEvent] = []
        private let maxRecentEvents = 1000

        // Callbacks
        private var eventHandlers: [(FileSystemEvent) -> Void] = []

        private init() {}

        // MARK: - Public API

        /// Add a path to watch
        public func watch(path: String) {
            watchedPaths.insert(path)

            if isRunning {
                // Restart stream with new path
                stopStream()
                startStream()
            }
        }

        /// Remove a path from watching
        public func unwatch(path: String) {
            watchedPaths.remove(path)

            if isRunning, !watchedPaths.isEmpty {
                stopStream()
                startStream()
            } else if watchedPaths.isEmpty {
                stopStream()
            }
        }

        /// Start monitoring file system events
        public func start() {
            guard !isRunning else { return }
            guard !watchedPaths.isEmpty else {
                logger.warning("No paths to watch")
                return
            }

            startStream()
            isRunning = true
            logger.info("File system observer started")
        }

        /// Stop monitoring file system events
        public func stop() {
            guard isRunning else { return }

            stopStream()
            isRunning = false
            logger.info("File system observer stopped")
        }

        /// Register an event handler
        public func onEvent(_ handler: @escaping (FileSystemEvent) -> Void) {
            eventHandlers.append(handler)
        }

        /// Get recent events
        public func getRecentEvents(limit: Int = 100) -> [FileSystemEvent] {
            Array(recentEvents.suffix(limit))
        }

        /// Get events for a specific path
        public func getEvents(for path: String, limit: Int = 50) -> [FileSystemEvent] {
            recentEvents
                .filter { $0.path.hasPrefix(path) }
                .suffix(limit)
                .map(\.self)
        }

        // MARK: - Private Methods

        private func startStream() {
            let pathsToWatch = Array(watchedPaths) as CFArray

            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: nil
            )

            let callback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
                let observer = Unmanaged<FileSystemObserver>.fromOpaque(clientCallBackInfo!).takeUnretainedValue()

                let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]

                for i in 0 ..< numEvents {
                    let path = paths[i]
                    let flags = eventFlags[i]
                    let eventId = eventIds[i]

                    let event = FileSystemEvent(
                        path: path,
                        flags: FileSystemEventFlags(rawValue: flags),
                        eventId: eventId
                    )

                    Task {
                        await observer.handleEvent(event)
                    }
                }
            }

            eventStream = FSEventStreamCreate(
                kCFAllocatorDefault,
                callback,
                &context,
                pathsToWatch,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.5, // Latency in seconds
                FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
            )

            if let stream = eventStream {
                FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
                FSEventStreamStart(stream)
            }
        }

        private func stopStream() {
            if let stream = eventStream {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                eventStream = nil
            }
        }

        private func handleEvent(_ event: FileSystemEvent) {
            // Add to recent events buffer
            recentEvents.append(event)
            if recentEvents.count > maxRecentEvents {
                recentEvents.removeFirst(recentEvents.count - maxRecentEvents)
            }

            // Notify handlers
            for handler in eventHandlers {
                handler(event)
            }

            // Log significant events
            if event.flags.contains(.itemCreated) || event.flags.contains(.itemRemoved) {
                logger.debug("File event: \(event.flags.description) at \(event.path)")
            }
        }

        // MARK: - Project Detection

        /// Detect if a path is a project root
        nonisolated public func isProjectRoot(_ path: String) -> Bool {
            let projectIndicators = [
                "package.json",
                "Package.swift",
                "Cargo.toml",
                "go.mod",
                "pyproject.toml",
                "requirements.txt",
                "Makefile",
                "CMakeLists.txt",
                ".git",
                ".xcodeproj",
                ".xcworkspace",
                "build.gradle",
                "pom.xml"
            ]

            let fileManager = FileManager.default

            for indicator in projectIndicators {
                let indicatorPath = (path as NSString).appendingPathComponent(indicator)
                if fileManager.fileExists(atPath: indicatorPath) {
                    return true
                }
            }

            return false
        }

        /// Get project type for a path
        nonisolated public func detectProjectType(_ path: String) -> ProjectType? {
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: (path as NSString).appendingPathComponent("Package.swift")) ||
                fileManager.fileExists(atPath: (path as NSString).appendingPathComponent(".xcodeproj")) ||
                fileManager.fileExists(atPath: (path as NSString).appendingPathComponent(".xcworkspace"))
            {
                return .swift
            }

            if fileManager.fileExists(atPath: (path as NSString).appendingPathComponent("package.json")) {
                return .javascript
            }

            if fileManager.fileExists(atPath: (path as NSString).appendingPathComponent("Cargo.toml")) {
                return .rust
            }

            if fileManager.fileExists(atPath: (path as NSString).appendingPathComponent("go.mod")) {
                return .go
            }

            if fileManager.fileExists(atPath: (path as NSString).appendingPathComponent("pyproject.toml")) ||
                fileManager.fileExists(atPath: (path as NSString).appendingPathComponent("requirements.txt"))
            {
                return .python
            }

            return nil
        }

        /// Find recently modified files in a path
        nonisolated public func findRecentlyModifiedFiles(in path: String, within seconds: TimeInterval = 3600) -> [String] {
            let fileManager = FileManager.default
            let cutoffDate = Date().addingTimeInterval(-seconds)

            var recentFiles: [String] = []

            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return []
            }

            while let fileURL = enumerator.nextObject() as? URL {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                    if let modDate = resourceValues.contentModificationDate, modDate > cutoffDate {
                        recentFiles.append(fileURL.path)
                    }
                } catch {
                    continue
                }
            }

            return recentFiles
        }
    }

    // MARK: - Data Types

    public struct FileSystemEvent: Sendable {
        public let path: String
        public let flags: FileSystemEventFlags
        public let eventId: UInt64
        public let timestamp = Date()
    }

    public struct FileSystemEventFlags: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let itemCreated = FileSystemEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemCreated))
        public static let itemRemoved = FileSystemEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemRemoved))
        public static let itemRenamed = FileSystemEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemRenamed))
        public static let itemModified = FileSystemEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemModified))
        public static let itemInodeMetaMod = FileSystemEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemInodeMetaMod))
        public static let itemFinderInfoMod = FileSystemEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemFinderInfoMod))
        public static let itemChangeOwner = FileSystemEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemChangeOwner))
        public static let itemXattrMod = FileSystemEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemXattrMod))
        public static let itemIsFile = FileSystemEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemIsFile))
        public static let itemIsDir = FileSystemEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemIsDir))
        public static let itemIsSymlink = FileSystemEventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemIsSymlink))

        public var description: String {
            var parts: [String] = []
            if contains(.itemCreated) { parts.append("created") }
            if contains(.itemRemoved) { parts.append("removed") }
            if contains(.itemRenamed) { parts.append("renamed") }
            if contains(.itemModified) { parts.append("modified") }
            if contains(.itemIsFile) { parts.append("file") }
            if contains(.itemIsDir) { parts.append("dir") }
            return parts.joined(separator: ", ")
        }
    }

    public enum ProjectType: String, Sendable {
        case swift = "Swift"
        case javascript = "JavaScript/TypeScript"
        case rust = "Rust"
        case go = "Go"
        case python = "Python"
        case ruby = "Ruby"
        case java = "Java"
        case csharp = "C#"
        case cpp = "C/C++"
        case other = "Other"
    }
#endif
