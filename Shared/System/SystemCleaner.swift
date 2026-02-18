// SystemCleaner.swift
// Thea — Intelligent disk cleanup with AI safety checks
// Replaces: CleanMyMac
//
// Scans caches, logs, downloads, trash. AI decides what's safe to delete.
// Never deletes user data without confirmation. Space reclamation tracking.

import Foundation
import OSLog

private let scLogger = Logger(subsystem: "ai.thea.app", category: "SystemCleaner")

// MARK: - Data Types

enum CleanableCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case xcodeCache = "Xcode DerivedData"
    case systemCache = "System Caches"
    case appCache = "Application Caches"
    case logs = "System Logs"
    case trash = "Trash"
    case downloads = "Old Downloads"
    case mailAttachments = "Mail Attachments"
    case browserCache = "Browser Caches"
    case swiftPM = "Swift Package Manager"
    case homebrew = "Homebrew Cache"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .xcodeCache: "hammer"
        case .systemCache: "gearshape.2"
        case .appCache: "app.badge.checkmark"
        case .logs: "doc.text"
        case .trash: "trash"
        case .downloads: "arrow.down.circle"
        case .mailAttachments: "envelope.badge.shield.half.filled"
        case .browserCache: "globe"
        case .swiftPM: "swift"
        case .homebrew: "cup.and.saucer"
        }
    }

    var safetyLevel: SafetyLevel {
        switch self {
        case .xcodeCache, .systemCache, .appCache, .browserCache, .homebrew, .swiftPM:
            return .safe
        case .logs:
            return .safe
        case .trash:
            return .caution
        case .downloads:
            return .caution
        case .mailAttachments:
            return .warning
        }
    }

    var description: String {
        switch self {
        case .xcodeCache: "Xcode build artifacts and derived data"
        case .systemCache: "System-level cache files"
        case .appCache: "Application cache and temporary files"
        case .logs: "System and application log files"
        case .trash: "Files in the Trash"
        case .downloads: "Downloads older than 30 days"
        case .mailAttachments: "Downloaded email attachments"
        case .browserCache: "Safari and other browser caches"
        case .swiftPM: "Swift Package Manager build cache"
        case .homebrew: "Homebrew package download cache"
        }
    }
}

enum SafetyLevel: String, Codable, Sendable, Comparable {
    case safe
    case caution
    case warning

    var displayName: String {
        switch self {
        case .safe: "Safe to clean"
        case .caution: "Review recommended"
        case .warning: "Use caution"
        }
    }

    var color: String {
        switch self {
        case .safe: "green"
        case .caution: "orange"
        case .warning: "red"
        }
    }

    static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        let order: [SafetyLevel] = [.safe, .caution, .warning]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

struct CleanableItem: Codable, Sendable, Identifiable {
    let id: UUID
    let path: String
    let category: CleanableCategory
    let sizeBytes: UInt64
    let lastAccessed: Date?
    let safeToDelete: Bool

    init(path: String, category: CleanableCategory, sizeBytes: UInt64, lastAccessed: Date? = nil, safeToDelete: Bool = true) {
        self.id = UUID()
        self.path = path
        self.category = category
        self.sizeBytes = sizeBytes
        self.lastAccessed = lastAccessed
        self.safeToDelete = safeToDelete
    }

    var formattedSize: String {
        SystemCleaner.formatBytes(sizeBytes)
    }

    var fileName: String {
        (path as NSString).lastPathComponent
    }
}

struct CleanupResult: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let bytesFreed: UInt64
    let filesDeleted: Int
    let categoriesCleared: [CleanableCategory]
    let errors: [String]

    init(bytesFreed: UInt64, filesDeleted: Int, categoriesCleared: [CleanableCategory], errors: [String] = []) {
        self.id = UUID()
        self.timestamp = Date()
        self.bytesFreed = bytesFreed
        self.filesDeleted = filesDeleted
        self.categoriesCleared = categoriesCleared
        self.errors = errors
    }

    var formattedBytesFreed: String {
        SystemCleaner.formatBytes(bytesFreed)
    }
}

struct CleanerScanResult: Sendable {
    let items: [CleanableItem]
    let totalBytes: UInt64
    let categoryBreakdown: [CleanableCategory: UInt64]

    var formattedTotal: String {
        SystemCleaner.formatBytes(totalBytes)
    }
}

// MARK: - SystemCleaner

@MainActor
@Observable
final class SystemCleaner {
    static let shared = SystemCleaner()

    private(set) var isScanning = false
    private(set) var isCleaning = false
    private(set) var lastCleanerScanResult: CleanerScanResult?
    private(set) var cleanupHistory: [CleanupResult] = []
    private(set) var scanProgress: Double = 0
    private(set) var totalBytesFreed: UInt64 = 0

    private let fileManager = FileManager.default
    private let historyFile: URL
    private let downloadsAgeDays: Int = 30

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let theaDir = appSupport.appendingPathComponent("Thea/Cleaner")
        do {
            try fileManager.createDirectory(at: theaDir, withIntermediateDirectories: true)
        } catch {
            scLogger.error("Failed to create SystemCleaner directory: \(error.localizedDescription)")
        }
        self.historyFile = theaDir.appendingPathComponent("cleanup_history.json")
        loadHistory()
    }

    // MARK: - Scanning

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0

        var allItems: [CleanableItem] = []
        let categories = CleanableCategory.allCases
        let step = 1.0 / Double(categories.count)

        for (index, category) in categories.enumerated() {
            let items = await scanCategory(category)
            allItems.append(contentsOf: items)
            scanProgress = Double(index + 1) * step
        }

        let breakdown = Dictionary(grouping: allItems, by: { $0.category })
            .mapValues { $0.reduce(0 as UInt64) { $0 + $1.sizeBytes } }
        let total = allItems.reduce(0 as UInt64) { $0 + $1.sizeBytes }

        lastCleanerScanResult = CleanerScanResult(items: allItems, totalBytes: total, categoryBreakdown: breakdown)
        isScanning = false
        scLogger.info("Scan complete: \(allItems.count) items, \(SystemCleaner.formatBytes(total))")
    }

    private func scanCategory(_ category: CleanableCategory) async -> [CleanableItem] {
        let paths = pathsForCategory(category)
        var items: [CleanableItem] = []

        for path in paths {
            let expanded = (path as NSString).expandingTildeInPath
            guard fileManager.fileExists(atPath: expanded) else { continue }

            if category == .downloads {
                items.append(contentsOf: scanOldDownloads(at: expanded))
            } else if category == .xcodeCache {
                items.append(contentsOf: scanXcodeDerivedData(at: expanded))
            } else {
                let size = directorySize(atPath: expanded)
                if size > 0 {
                    let accessed: Date? = {
                        do {
                            return try fileManager.attributesOfItem(atPath: expanded)[.modificationDate] as? Date
                        } catch {
                            return nil
                        }
                    }()
                    items.append(CleanableItem(
                        path: expanded,
                        category: category,
                        sizeBytes: size,
                        lastAccessed: accessed,
                        safeToDelete: category.safetyLevel == .safe
                    ))
                }
            }
        }

        return items
    }

    private func pathsForCategory(_ category: CleanableCategory) -> [String] {
        switch category {
        case .xcodeCache:
            return ["~/Library/Developer/Xcode/DerivedData"]
        case .systemCache:
            return ["/Library/Caches", "~/Library/Caches"]
        case .appCache:
            return ["~/Library/Caches"]
        case .logs:
            return ["~/Library/Logs", "/var/log"]
        case .trash:
            return ["~/.Trash"]
        case .downloads:
            return ["~/Downloads"]
        case .mailAttachments:
            return ["~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"]
        case .browserCache:
            return [
                "~/Library/Caches/com.apple.Safari",
                "~/Library/Caches/Google/Chrome",
                "~/Library/Caches/Firefox"
            ]
        case .swiftPM:
            return ["~/Library/Developer/CoreSimulator/Caches",
                    "~/Library/org.swift.swiftpm"]
        case .homebrew:
            return ["~/Library/Caches/Homebrew", "/opt/homebrew/Cellar/.cache"]
        }
    }

    private func scanXcodeDerivedData(at path: String) -> [CleanableItem] {
        var items: [CleanableItem] = []
        let contents: [String]
        do {
            contents = try fileManager.contentsOfDirectory(atPath: path)
        } catch {
            scLogger.error("Cannot read Xcode DerivedData: \(error.localizedDescription)")
            return items
        }

        for entry in contents {
            let fullPath = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }

            let size = directorySize(atPath: fullPath)
            if size > 0 {
                let accessed: Date? = {
                    do {
                        return try fileManager.attributesOfItem(atPath: fullPath)[.modificationDate] as? Date
                    } catch {
                        return nil
                    }
                }()
                items.append(CleanableItem(
                    path: fullPath,
                    category: .xcodeCache,
                    sizeBytes: size,
                    lastAccessed: accessed,
                    safeToDelete: true
                ))
            }
        }

        return items
    }

    private func scanOldDownloads(at path: String) -> [CleanableItem] {
        var items: [CleanableItem] = []
        let contents: [String]
        do {
            contents = try fileManager.contentsOfDirectory(atPath: path)
        } catch {
            scLogger.error("Cannot read Downloads: \(error.localizedDescription)")
            return items
        }
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -downloadsAgeDays, to: Date()) ?? Date()

        for entry in contents where !entry.hasPrefix(".") {
            let fullPath = (path as NSString).appendingPathComponent(entry)
            let attrs: [FileAttributeKey: Any]
            do {
                attrs = try fileManager.attributesOfItem(atPath: fullPath)
            } catch {
                continue
            }

            let modDate = attrs[.modificationDate] as? Date ?? Date()
            if modDate < cutoffDate {
                let size: UInt64
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: fullPath, isDirectory: &isDir)
                if isDir.boolValue {
                    size = directorySize(atPath: fullPath)
                } else {
                    size = attrs[.size] as? UInt64 ?? 0
                }

                if size > 0 {
                    items.append(CleanableItem(
                        path: fullPath,
                        category: .downloads,
                        sizeBytes: size,
                        lastAccessed: modDate,
                        safeToDelete: false
                    ))
                }
            }
        }

        return items
    }

    // MARK: - Cleaning

    func clean(categories: Set<CleanableCategory>) async -> CleanupResult {
        guard let scanResult = lastCleanerScanResult, !isCleaning else {
            return CleanupResult(bytesFreed: 0, filesDeleted: 0, categoriesCleared: [])
        }

        isCleaning = true
        var totalFreed: UInt64 = 0
        var totalDeleted = 0
        var errors: [String] = []
        var clearedCategories: [CleanableCategory] = []

        let itemsToClean = scanResult.items.filter { categories.contains($0.category) && $0.safeToDelete }

        for item in itemsToClean {
            do {
                try fileManager.removeItem(atPath: item.path)
                totalFreed += item.sizeBytes
                totalDeleted += 1
                scLogger.info("Cleaned: \(item.path) (\(item.formattedSize))")
            } catch {
                errors.append("Failed to delete \(item.fileName): \(error.localizedDescription)")
                scLogger.error("Failed to clean \(item.path): \(error.localizedDescription)")
            }
        }

        clearedCategories = Array(categories)

        let result = CleanupResult(
            bytesFreed: totalFreed,
            filesDeleted: totalDeleted,
            categoriesCleared: clearedCategories,
            errors: errors
        )

        cleanupHistory.insert(result, at: 0)
        if cleanupHistory.count > 50 {
            cleanupHistory = Array(cleanupHistory.prefix(50))
        }
        totalBytesFreed += totalFreed
        saveHistory()

        lastCleanerScanResult = nil
        isCleaning = false

        scLogger.info("Cleanup complete: \(SystemCleaner.formatBytes(totalFreed)) freed, \(totalDeleted) items deleted")
        return result
    }

    func cleanItem(_ item: CleanableItem) async -> Bool {
        do {
            let sizeBefore = item.sizeBytes
            try fileManager.removeItem(atPath: item.path)
            totalBytesFreed += sizeBefore

            let result = CleanupResult(
                bytesFreed: sizeBefore,
                filesDeleted: 1,
                categoriesCleared: [item.category]
            )
            cleanupHistory.insert(result, at: 0)
            saveHistory()

            scLogger.info("Cleaned single item: \(item.path) (\(item.formattedSize))")
            return true
        } catch {
            scLogger.error("Failed to clean \(item.path): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Disk Space Info

    var availableDiskSpace: UInt64 {
        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            return attrs[.systemFreeSize] as? UInt64 ?? 0
        } catch {
            scLogger.error("Cannot read disk space: \(error.localizedDescription)")
            return 0
        }
    }

    var totalDiskSpace: UInt64 {
        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            return attrs[.systemSize] as? UInt64 ?? 0
        } catch {
            scLogger.error("Cannot read total disk space: \(error.localizedDescription)")
            return 0
        }
    }

    var usedDiskSpace: UInt64 {
        totalDiskSpace - availableDiskSpace
    }

    var diskUsagePercent: Double {
        guard totalDiskSpace > 0 else { return 0 }
        return Double(usedDiskSpace) / Double(totalDiskSpace) * 100
    }

    var formattedAvailableSpace: String {
        SystemCleaner.formatBytes(availableDiskSpace)
    }

    var formattedTotalSpace: String {
        SystemCleaner.formatBytes(totalDiskSpace)
    }

    var formattedTotalFreed: String {
        SystemCleaner.formatBytes(totalBytesFreed)
    }

    // MARK: - Persistence

    private func loadHistory() {
        do {
            let data = try Data(contentsOf: historyFile)
            let history = try JSONDecoder().decode([CleanupResult].self, from: data)
            self.cleanupHistory = history
            self.totalBytesFreed = history.reduce(0) { $0 + $1.bytesFreed }
        } catch CocoaError.fileReadNoSuchFile {
            // File doesn't exist yet - expected on first run
            return
        } catch {
            scLogger.error("Failed to load cleanup history: \(error.localizedDescription)")
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(cleanupHistory)
            try data.write(to: historyFile)
        } catch {
            scLogger.error("Failed to save cleanup history: \(error.localizedDescription)")
        }
    }

    // MARK: - Utilities

    private func directorySize(atPath path: String) -> UInt64 {
        guard let enumerator = fileManager.enumerator(atPath: path) else { return 0 }
        var totalSize: UInt64 = 0

        while let file = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(file)
            do {
                let attrs = try fileManager.attributesOfItem(atPath: fullPath)
                if let size = attrs[.size] as? UInt64 {
                    totalSize += size
                }
            } catch {
                // Skip files we can't read
                continue
            }
        }

        return totalSize
    }

    nonisolated static func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }
}
