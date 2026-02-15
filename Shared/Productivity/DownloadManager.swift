// DownloadManager.swift
// Thea — Unified download management
// Replaces: qBittorrent (for HTTP downloads)
//
// URLSession-based downloads with queue management, speed controls,
// auto-categorization, progress tracking, and history.

import Foundation
import OSLog

private let dlLogger = Logger(subsystem: "ai.thea.app", category: "DownloadManager")

// MARK: - Data Types

enum DownloadStatus: String, Codable, Sendable {
    case queued = "Queued"
    case downloading = "Downloading"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"

    var icon: String {
        switch self {
        case .queued: "clock"
        case .downloading: "arrow.down.circle"
        case .paused: "pause.circle"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "minus.circle"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: true
        default: false
        }
    }
}

enum DownloadCategory: String, Codable, Sendable, CaseIterable {
    case document = "Documents"
    case image = "Images"
    case video = "Video"
    case audio = "Audio"
    case archive = "Archives"
    case application = "Applications"
    case code = "Code"
    case other = "Other"

    var icon: String {
        switch self {
        case .document: "doc.fill"
        case .image: "photo.fill"
        case .video: "film.fill"
        case .audio: "music.note"
        case .archive: "archivebox.fill"
        case .application: "app.fill"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .other: "questionmark.folder.fill"
        }
    }

    static func categorize(filename: String) -> DownloadCategory {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv", "pages", "numbers", "key":
            return .document
        case "jpg", "jpeg", "png", "gif", "webp", "svg", "heic", "tiff", "bmp", "ico":
            return .image
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v":
            return .video
        case "mp3", "wav", "flac", "aac", "m4a", "ogg", "wma", "aiff":
            return .audio
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso":
            return .archive
        case "app", "exe", "msi", "pkg", "deb", "rpm", "apk", "ipa":
            return .application
        case "swift", "py", "js", "ts", "java", "cpp", "c", "h", "rb", "go", "rs", "json", "xml", "html", "css":
            return .code
        default:
            return .other
        }
    }
}

enum DownloadPriority: Int, Codable, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2

    static func < (lhs: DownloadPriority, rhs: DownloadPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct DownloadItem: Codable, Sendable, Identifiable {
    let id: UUID
    let url: String
    let fileName: String
    var category: DownloadCategory
    var status: DownloadStatus
    var priority: DownloadPriority
    var bytesDownloaded: Int64
    var totalBytes: Int64
    var speedBytesPerSecond: Double
    let createdAt: Date
    var completedAt: Date?
    var localPath: String?
    var errorMessage: String?

    init(
        url: String,
        fileName: String? = nil,
        priority: DownloadPriority = .normal
    ) {
        self.id = UUID()
        self.url = url
        let name = fileName ?? (URL(string: url)?.lastPathComponent ?? "download")
        self.fileName = name
        self.category = DownloadCategory.categorize(filename: name)
        self.status = .queued
        self.priority = priority
        self.bytesDownloaded = 0
        self.totalBytes = -1
        self.speedBytesPerSecond = 0
        self.createdAt = Date()
    }

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(totalBytes)
    }

    var formattedSize: String {
        Self.formatBytes(totalBytes > 0 ? totalBytes : bytesDownloaded)
    }

    var formattedSpeed: String {
        guard speedBytesPerSecond > 0 else { return "" }
        return "\(Self.formatBytes(Int64(speedBytesPerSecond)))/s"
    }

    var estimatedTimeRemaining: TimeInterval? {
        guard speedBytesPerSecond > 0, totalBytes > 0 else { return nil }
        let remaining = Double(totalBytes - bytesDownloaded)
        return remaining / speedBytesPerSecond
    }

    var formattedETA: String {
        guard let eta = estimatedTimeRemaining else { return "" }
        if eta < 60 { return "\(Int(eta))s" }
        if eta < 3600 { return "\(Int(eta / 60))m \(Int(eta.truncatingRemainder(dividingBy: 60)))s" }
        return "\(Int(eta / 3600))h \(Int((eta.truncatingRemainder(dividingBy: 3600)) / 60))m"
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return unitIndex == 0 ? "\(bytes) B" : String(format: "%.1f %@", value, units[unitIndex])
    }
}

struct DownloadStats: Codable, Sendable {
    var totalDownloads: Int
    var completedDownloads: Int
    var failedDownloads: Int
    var totalBytesDownloaded: Int64
    var activeDownloads: Int

    var completionRate: Double {
        guard totalDownloads > 0 else { return 0 }
        return Double(completedDownloads) / Double(totalDownloads)
    }

    var formattedTotalSize: String {
        DownloadItem.formatBytes(totalBytesDownloaded)
    }
}

enum DownloadManagerError: Error, LocalizedError {
    case invalidURL
    case downloadFailed(String)
    case maxConcurrentReached
    case alreadyExists
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid download URL"
        case .downloadFailed(let msg): "Download failed: \(msg)"
        case .maxConcurrentReached: "Maximum concurrent downloads reached"
        case .alreadyExists: "This URL is already in the download queue"
        case .notFound: "Download item not found"
        }
    }
}

// MARK: - Download Manager

actor TheaDownloadManager {
    static let shared = TheaDownloadManager()

    private var downloads: [DownloadItem] = []
    private var activeTasks: [UUID: URLSessionDownloadTask] = [:]
    private let maxConcurrent: Int = 5
    private let historyFile: URL
    private let downloadDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let theaDir = appSupport.appendingPathComponent("Thea/Downloads")
        try? FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        let file = theaDir.appendingPathComponent("download_history.json")
        self.historyFile = file
        self.downloadDirectory = theaDir

        // Inline loadHistory to avoid calling actor-isolated method from init
        if let data = try? Data(contentsOf: file) {
            self.downloads = (try? JSONDecoder().decode([DownloadItem].self, from: data)) ?? []
        }
    }

    // MARK: - Queue Management

    func addDownload(url: String, fileName: String? = nil, priority: DownloadPriority = .normal) throws -> DownloadItem {
        guard URL(string: url) != nil else { throw DownloadManagerError.invalidURL }

        if downloads.contains(where: { $0.url == url && !$0.status.isTerminal }) {
            throw DownloadManagerError.alreadyExists
        }

        let item = DownloadItem(url: url, fileName: fileName, priority: priority)
        downloads.append(item)
        saveHistory()

        dlLogger.info("Queued download: \(item.fileName)")
        return item
    }

    func startDownload(_ id: UUID) async throws {
        guard var item = downloads.first(where: { $0.id == id }) else {
            throw DownloadManagerError.notFound
        }

        let activeCount = activeTasks.count
        guard activeCount < maxConcurrent else {
            throw DownloadManagerError.maxConcurrentReached
        }

        guard let url = URL(string: item.url) else {
            throw DownloadManagerError.invalidURL
        }

        item.status = .downloading
        updateItem(item)

        let session = URLSession(configuration: .default)
        let task = session.downloadTask(with: url)
        activeTasks[id] = task
        task.resume()

        dlLogger.info("Started download: \(item.fileName)")

        // Monitor progress in background
        Task.detached { [weak self] in
            await self?.monitorDownload(id: id, task: task, session: session)
        }
    }

    func pauseDownload(_ id: UUID) {
        guard var item = downloads.first(where: { $0.id == id }) else { return }
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)
        item.status = .paused
        item.speedBytesPerSecond = 0
        updateItem(item)
    }

    func cancelDownload(_ id: UUID) {
        guard var item = downloads.first(where: { $0.id == id }) else { return }
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)
        item.status = .cancelled
        item.speedBytesPerSecond = 0
        updateItem(item)
    }

    func removeDownload(_ id: UUID) {
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)

        if let item = downloads.first(where: { $0.id == id }),
           let path = item.localPath {
            try? FileManager.default.removeItem(atPath: path)
        }

        downloads.removeAll { $0.id == id }
        saveHistory()
    }

    func retryDownload(_ id: UUID) async throws {
        guard var item = downloads.first(where: { $0.id == id }) else {
            throw DownloadManagerError.notFound
        }
        item.status = .queued
        item.bytesDownloaded = 0
        item.errorMessage = nil
        item.completedAt = nil
        updateItem(item)

        try await startDownload(id)
    }

    // MARK: - Progress Monitoring

    private func monitorDownload(id: UUID, task: URLSessionDownloadTask, session: URLSession) async {
        var lastCheck = Date()
        var lastBytes: Int64 = 0

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            guard var item = downloads.first(where: { $0.id == id }) else { break }
            guard item.status == .downloading else { break }

            let received = task.countOfBytesReceived
            let expected = task.countOfBytesExpectedToReceive

            let now = Date()
            let elapsed = now.timeIntervalSince(lastCheck)
            if elapsed > 0 {
                item.speedBytesPerSecond = Double(received - lastBytes) / elapsed
            }

            item.bytesDownloaded = received
            if expected > 0 { item.totalBytes = expected }

            lastCheck = now
            lastBytes = received

            updateItem(item)

            // Check if completed or failed
            switch task.state {
            case .completed:
                item.status = .completed
                item.completedAt = Date()
                item.speedBytesPerSecond = 0

                // Move file to downloads directory
                if let location = task.response?.url {
                    let destPath = downloadDirectory.appendingPathComponent(item.fileName)
                    try? FileManager.default.moveItem(at: location, to: destPath)
                    item.localPath = destPath.path
                }

                updateItem(item)
                activeTasks.removeValue(forKey: id)
                dlLogger.info("Download completed: \(item.fileName)")

                // Start next queued download
                await startNextQueued()
                return

            case .canceling:
                activeTasks.removeValue(forKey: id)
                return

            default:
                break
            }

            if let error = task.error {
                item.status = .failed
                item.errorMessage = error.localizedDescription
                item.speedBytesPerSecond = 0
                updateItem(item)
                activeTasks.removeValue(forKey: id)
                dlLogger.error("Download failed: \(item.fileName) — \(error.localizedDescription)")
                return
            }
        }
    }

    private func startNextQueued() async {
        let queued = downloads
            .filter { $0.status == .queued }
            .sorted { $0.priority > $1.priority }

        if let next = queued.first {
            try? await startDownload(next.id)
        }
    }

    // MARK: - Queries

    func getDownloads() -> [DownloadItem] { downloads }

    func getActiveDownloads() -> [DownloadItem] {
        downloads.filter { $0.status == .downloading }
    }

    func getDownloadsByCategory(_ category: DownloadCategory) -> [DownloadItem] {
        downloads.filter { $0.category == category }
    }

    func getDownloadsByStatus(_ status: DownloadStatus) -> [DownloadItem] {
        downloads.filter { $0.status == status }
    }

    func getStats() -> DownloadStats {
        DownloadStats(
            totalDownloads: downloads.count,
            completedDownloads: downloads.filter { $0.status == .completed }.count,
            failedDownloads: downloads.filter { $0.status == .failed }.count,
            totalBytesDownloaded: downloads.reduce(0) { $0 + $1.bytesDownloaded },
            activeDownloads: activeTasks.count
        )
    }

    func search(_ query: String) -> [DownloadItem] {
        let lowered = query.lowercased()
        return downloads.filter {
            $0.fileName.lowercased().contains(lowered) ||
            $0.url.lowercased().contains(lowered)
        }
    }

    func clearHistory(keepCompleted: Bool = false) {
        if keepCompleted {
            downloads.removeAll { $0.status.isTerminal && $0.status != .completed }
        } else {
            // Keep only active downloads
            downloads.removeAll { $0.status.isTerminal }
        }
        saveHistory()
    }

    // MARK: - Persistence

    private func updateItem(_ item: DownloadItem) {
        if let index = downloads.firstIndex(where: { $0.id == item.id }) {
            downloads[index] = item
        }
        saveHistory()
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(downloads) else { return }
        try? data.write(to: historyFile, options: .atomic)
    }
}
