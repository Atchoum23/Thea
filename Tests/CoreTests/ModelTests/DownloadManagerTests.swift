// DownloadManagerTests.swift
// Tests for DownloadManager types and logic
// SPM-compatible — uses standalone test doubles mirroring production types

import Testing
import Foundation

// MARK: - Test Doubles

private enum TestDLStatus: String, Codable {
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

private enum TestDownloadCategory: String, Codable, CaseIterable {
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

    static func categorize(filename: String) -> TestDownloadCategory {
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

private enum TestDownloadPriority: Int, Codable, Comparable {
    case low = 0
    case normal = 1
    case high = 2

    static func < (lhs: TestDownloadPriority, rhs: TestDownloadPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private struct TestDownloadItem: Codable, Identifiable {
    let id: UUID
    let url: String
    let fileName: String
    var category: TestDownloadCategory
    var status: TestDLStatus
    var priority: TestDownloadPriority
    var bytesDownloaded: Int64
    var totalBytes: Int64
    var speedBytesPerSecond: Double
    let createdAt: Date
    var completedAt: Date?
    var localPath: String?
    var errorMessage: String?

    init(url: String, fileName: String? = nil, priority: TestDownloadPriority = .normal) {
        self.id = UUID()
        self.url = url
        let name = fileName ?? (URL(string: url)?.lastPathComponent ?? "download")
        self.fileName = name
        self.category = TestDownloadCategory.categorize(filename: name)
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

private struct TestDownloadStats: Codable {
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
        TestDownloadItem.formatBytes(totalBytesDownloaded)
    }
}

private enum TestDownloadManagerError: Error, LocalizedError {
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

// MARK: - Tests

@Suite("DLStatus")
struct DLStatusTests {
    @Test func terminalStates() {
        #expect(TestDLStatus.completed.isTerminal)
        #expect(TestDLStatus.failed.isTerminal)
        #expect(TestDLStatus.cancelled.isTerminal)
    }

    @Test func nonTerminalStates() {
        #expect(!TestDLStatus.queued.isTerminal)
        #expect(!TestDLStatus.downloading.isTerminal)
        #expect(!TestDLStatus.paused.isTerminal)
    }

    @Test func uniqueIcons() {
        let statuses: [TestDLStatus] = [.queued, .downloading, .paused, .completed, .failed, .cancelled]
        let icons = statuses.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }

    @Test func codableRoundtrip() throws {
        let status = TestDLStatus.downloading
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(TestDLStatus.self, from: data)
        #expect(decoded == status)
    }
}

@Suite("DownloadCategory")
struct DownloadCategoryTests {
    @Test func allCases() {
        #expect(TestDownloadCategory.allCases.count == 8)
    }

    @Test func categorizeDocument() {
        #expect(TestDownloadCategory.categorize(filename: "report.pdf") == .document)
        #expect(TestDownloadCategory.categorize(filename: "data.xlsx") == .document)
        #expect(TestDownloadCategory.categorize(filename: "doc.txt") == .document)
        #expect(TestDownloadCategory.categorize(filename: "slides.pptx") == .document)
    }

    @Test func categorizeImage() {
        #expect(TestDownloadCategory.categorize(filename: "photo.jpg") == .image)
        #expect(TestDownloadCategory.categorize(filename: "logo.png") == .image)
        #expect(TestDownloadCategory.categorize(filename: "avatar.webp") == .image)
        #expect(TestDownloadCategory.categorize(filename: "scan.heic") == .image)
    }

    @Test func categorizeVideo() {
        #expect(TestDownloadCategory.categorize(filename: "movie.mp4") == .video)
        #expect(TestDownloadCategory.categorize(filename: "clip.mov") == .video)
        #expect(TestDownloadCategory.categorize(filename: "film.mkv") == .video)
    }

    @Test func categorizeAudio() {
        #expect(TestDownloadCategory.categorize(filename: "song.mp3") == .audio)
        #expect(TestDownloadCategory.categorize(filename: "podcast.m4a") == .audio)
        #expect(TestDownloadCategory.categorize(filename: "music.flac") == .audio)
    }

    @Test func categorizeArchive() {
        #expect(TestDownloadCategory.categorize(filename: "package.zip") == .archive)
        #expect(TestDownloadCategory.categorize(filename: "backup.tar") == .archive)
        #expect(TestDownloadCategory.categorize(filename: "installer.dmg") == .archive)
    }

    @Test func categorizeApplication() {
        #expect(TestDownloadCategory.categorize(filename: "app.pkg") == .application)
        #expect(TestDownloadCategory.categorize(filename: "setup.exe") == .application)
    }

    @Test func categorizeCode() {
        #expect(TestDownloadCategory.categorize(filename: "main.swift") == .code)
        #expect(TestDownloadCategory.categorize(filename: "app.py") == .code)
        #expect(TestDownloadCategory.categorize(filename: "index.html") == .code)
        #expect(TestDownloadCategory.categorize(filename: "config.json") == .code)
    }

    @Test func categorizeOther() {
        #expect(TestDownloadCategory.categorize(filename: "file.xyz") == .other)
        #expect(TestDownloadCategory.categorize(filename: "download") == .other)
    }

    @Test func uniqueIcons() {
        let icons = TestDownloadCategory.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }
}

@Suite("DownloadPriority")
struct DownloadPriorityTests {
    @Test func ordering() {
        #expect(TestDownloadPriority.low < TestDownloadPriority.normal)
        #expect(TestDownloadPriority.normal < TestDownloadPriority.high)
    }

    @Test func sorting() {
        let priorities: [TestDownloadPriority] = [.high, .low, .normal, .low, .high]
        let sorted = priorities.sorted()
        #expect(sorted == [.low, .low, .normal, .high, .high])
    }
}

@Suite("DownloadItem")
struct DownloadItemTests {
    @Test func creation() {
        let item = TestDownloadItem(url: "https://example.com/file.zip")
        #expect(item.url == "https://example.com/file.zip")
        #expect(item.fileName == "file.zip")
        #expect(item.category == .archive)
        #expect(item.status == .queued)
        #expect(item.priority == .normal)
        #expect(item.bytesDownloaded == 0)
        #expect(item.totalBytes == -1)
    }

    @Test func customFileName() {
        let item = TestDownloadItem(url: "https://example.com/dl?id=123", fileName: "report.pdf")
        #expect(item.fileName == "report.pdf")
        #expect(item.category == .document)
    }

    @Test func progressZero() {
        let item = TestDownloadItem(url: "https://example.com/file.mp4")
        #expect(item.progress == 0)
    }

    @Test func progressHalf() {
        var item = TestDownloadItem(url: "https://example.com/file.mp4")
        item.bytesDownloaded = 500
        item.totalBytes = 1000
        #expect(item.progress == 0.5)
    }

    @Test func progressUnknownTotal() {
        var item = TestDownloadItem(url: "https://example.com/file.mp4")
        item.bytesDownloaded = 500
        item.totalBytes = -1
        #expect(item.progress == 0) // Unknown total = 0%
    }

    @Test func formattedSpeedEmpty() {
        let item = TestDownloadItem(url: "https://example.com/file.zip")
        #expect(item.formattedSpeed == "")
    }

    @Test func formattedSpeedMB() {
        var item = TestDownloadItem(url: "https://example.com/file.zip")
        item.speedBytesPerSecond = 1024 * 1024 // 1 MB/s
        #expect(item.formattedSpeed == "1.0 MB/s")
    }

    @Test func etaNil() {
        let item = TestDownloadItem(url: "https://example.com/file.zip")
        #expect(item.estimatedTimeRemaining == nil)
    }

    @Test func etaSeconds() {
        var item = TestDownloadItem(url: "https://example.com/file.zip")
        item.bytesDownloaded = 500
        item.totalBytes = 1000
        item.speedBytesPerSecond = 100
        #expect(item.formattedETA == "5s")
    }

    @Test func etaMinutes() {
        var item = TestDownloadItem(url: "https://example.com/file.zip")
        item.bytesDownloaded = 0
        item.totalBytes = 120_000
        item.speedBytesPerSecond = 1000
        #expect(item.formattedETA == "2m 0s")
    }

    @Test func etaHours() {
        var item = TestDownloadItem(url: "https://example.com/file.zip")
        item.bytesDownloaded = 0
        item.totalBytes = 7_200_000
        item.speedBytesPerSecond = 1000
        #expect(item.formattedETA == "2h 0m")
    }

    @Test func formatBytesSmall() {
        #expect(TestDownloadItem.formatBytes(512) == "512 B")
    }

    @Test func formatBytesKB() {
        #expect(TestDownloadItem.formatBytes(2048) == "2.0 KB")
    }

    @Test func formatBytesMB() {
        #expect(TestDownloadItem.formatBytes(5 * 1024 * 1024) == "5.0 MB")
    }

    @Test func formatBytesGB() {
        #expect(TestDownloadItem.formatBytes(3 * 1024 * 1024 * 1024) == "3.0 GB")
    }

    @Test func formatBytesTB() {
        #expect(TestDownloadItem.formatBytes(2 * 1024 * 1024 * 1024 * 1024) == "2.0 TB")
    }

    @Test func uniqueIDs() {
        let a = TestDownloadItem(url: "https://example.com/file.zip")
        let b = TestDownloadItem(url: "https://example.com/file.zip")
        #expect(a.id != b.id)
    }

    @Test func codableRoundtrip() throws {
        var item = TestDownloadItem(url: "https://example.com/big.mp4", priority: .high)
        item.bytesDownloaded = 50000
        item.totalBytes = 100000
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(TestDownloadItem.self, from: data)
        #expect(decoded.url == "https://example.com/big.mp4")
        #expect(decoded.priority == .high)
        #expect(decoded.bytesDownloaded == 50000)
        #expect(decoded.totalBytes == 100000)
    }
}

@Suite("DownloadStats")
struct DownloadStatsTests {
    @Test func completionRate() {
        let stats = TestDownloadStats(totalDownloads: 10, completedDownloads: 7, failedDownloads: 2, totalBytesDownloaded: 1000, activeDownloads: 1)
        #expect(stats.completionRate == 0.7)
    }

    @Test func completionRateZero() {
        let stats = TestDownloadStats(totalDownloads: 0, completedDownloads: 0, failedDownloads: 0, totalBytesDownloaded: 0, activeDownloads: 0)
        #expect(stats.completionRate == 0)
    }

    @Test func completionRatePerfect() {
        let stats = TestDownloadStats(totalDownloads: 5, completedDownloads: 5, failedDownloads: 0, totalBytesDownloaded: 5000, activeDownloads: 0)
        #expect(stats.completionRate == 1.0)
    }

    @Test func formattedTotalSize() {
        let stats = TestDownloadStats(totalDownloads: 3, completedDownloads: 3, failedDownloads: 0, totalBytesDownloaded: 10 * 1024 * 1024, activeDownloads: 0)
        #expect(stats.formattedTotalSize == "10.0 MB")
    }
}

@Suite("DownloadManagerError")
struct DownloadManagerErrorTests {
    @Test func invalidURL() {
        let err = TestDownloadManagerError.invalidURL
        #expect(err.errorDescription?.contains("Invalid") == true)
    }

    @Test func downloadFailed() {
        let err = TestDownloadManagerError.downloadFailed("network timeout")
        #expect(err.errorDescription?.contains("network timeout") == true)
    }

    @Test func maxConcurrent() {
        let err = TestDownloadManagerError.maxConcurrentReached
        #expect(err.errorDescription?.contains("concurrent") == true)
    }

    @Test func alreadyExists() {
        let err = TestDownloadManagerError.alreadyExists
        #expect(err.errorDescription?.contains("already") == true)
    }

    @Test func notFound() {
        let err = TestDownloadManagerError.notFound
        #expect(err.errorDescription?.contains("not found") == true)
    }
}

@Suite("Queue Logic")
struct QueueLogicTests {
    @Test func duplicateDetection() {
        let items = [
            TestDownloadItem(url: "https://example.com/a.zip"),
            TestDownloadItem(url: "https://example.com/b.zip")
        ]
        let newURL = "https://example.com/a.zip"
        let isDuplicate = items.contains(where: { $0.url == newURL && !$0.status.isTerminal })
        #expect(isDuplicate)
    }

    @Test func duplicateAllowedAfterTerminal() {
        var item = TestDownloadItem(url: "https://example.com/a.zip")
        item.status = .completed
        let items = [item]
        let isDuplicate = items.contains(where: { $0.url == "https://example.com/a.zip" && !$0.status.isTerminal })
        #expect(!isDuplicate) // Completed = terminal, so not a duplicate
    }

    @Test func prioritySorting() {
        let items = [
            TestDownloadItem(url: "https://a.com/1.zip", priority: .low),
            TestDownloadItem(url: "https://a.com/2.zip", priority: .high),
            TestDownloadItem(url: "https://a.com/3.zip", priority: .normal)
        ]
        let sorted = items.sorted { $0.priority > $1.priority }
        #expect(sorted[0].priority == .high)
        #expect(sorted[1].priority == .normal)
        #expect(sorted[2].priority == .low)
    }

    @Test func clearHistoryKeepCompleted() {
        var items = [
            TestDownloadItem(url: "https://a.com/1.zip"),
            TestDownloadItem(url: "https://a.com/2.zip"),
            TestDownloadItem(url: "https://a.com/3.zip")
        ]
        items[0].status = .completed
        items[1].status = .failed
        items[2].status = .downloading

        items.removeAll { $0.status.isTerminal && $0.status != .completed }
        #expect(items.count == 2) // completed + downloading kept
    }

    @Test func clearHistoryAll() {
        var items = [
            TestDownloadItem(url: "https://a.com/1.zip"),
            TestDownloadItem(url: "https://a.com/2.zip"),
            TestDownloadItem(url: "https://a.com/3.zip")
        ]
        items[0].status = .completed
        items[1].status = .failed
        items[2].status = .downloading

        items.removeAll { $0.status.isTerminal }
        #expect(items.count == 1) // Only downloading kept
    }

    @Test func statsComputation() {
        var items = [
            TestDownloadItem(url: "https://a.com/1.zip"),
            TestDownloadItem(url: "https://a.com/2.zip"),
            TestDownloadItem(url: "https://a.com/3.zip")
        ]
        items[0].status = .completed
        items[0].bytesDownloaded = 1000
        items[1].status = .failed
        items[1].bytesDownloaded = 500
        items[2].status = .downloading
        items[2].bytesDownloaded = 200

        let total = items.reduce(Int64(0)) { $0 + $1.bytesDownloaded }
        let completed = items.filter { $0.status == .completed }.count
        let failed = items.filter { $0.status == .failed }.count
        #expect(total == 1700)
        #expect(completed == 1)
        #expect(failed == 1)
    }
}
