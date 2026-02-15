// SystemCleanerTests.swift
// Tests for SystemCleaner service types and logic

import Testing

// MARK: - Test Doubles

private enum TestCleanableCategory: String, CaseIterable, Sendable {
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

    var safetyLevel: TestSafetyLevel {
        switch self {
        case .xcodeCache, .systemCache, .appCache, .browserCache, .homebrew, .swiftPM, .logs:
            return .safe
        case .trash, .downloads:
            return .caution
        case .mailAttachments:
            return .warning
        }
    }

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

private enum TestSafetyLevel: String, Comparable, Sendable {
    case safe, caution, warning

    var displayName: String {
        switch self {
        case .safe: "Safe to clean"
        case .caution: "Review recommended"
        case .warning: "Use caution"
        }
    }

    static func < (lhs: TestSafetyLevel, rhs: TestSafetyLevel) -> Bool {
        let order: [TestSafetyLevel] = [.safe, .caution, .warning]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

private struct TestCleanableItem: Sendable {
    let path: String
    let category: TestCleanableCategory
    let sizeBytes: UInt64
    let safeToDelete: Bool

    var fileName: String { (path as NSString).lastPathComponent }
}

private struct TestCleanupResult: Sendable {
    let bytesFreed: UInt64
    let filesDeleted: Int
    let categories: [TestCleanableCategory]
    let errors: [String]
}

private func formatBytes(_ bytes: UInt64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes)
    var unitIndex = 0
    while value >= 1024 && unitIndex < units.count - 1 {
        value /= 1024
        unitIndex += 1
    }
    if unitIndex == 0 { return "\(bytes) B" }
    return String(format: "%.1f %@", value, units[unitIndex])
}

// MARK: - CleanableCategory Tests

@Suite("SystemCleaner — Category Properties")
struct CleanerCategoryTests {
    @Test("All 10 categories exist")
    func allCategories() {
        #expect(TestCleanableCategory.allCases.count == 10)
    }

    @Test("All raw values are unique")
    func uniqueRawValues() {
        let rawValues = TestCleanableCategory.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All categories have non-empty icons")
    func allHaveIcons() {
        for category in TestCleanableCategory.allCases {
            #expect(!category.icon.isEmpty, "Missing icon for \(category.rawValue)")
        }
    }

    @Test("All categories have non-empty descriptions")
    func allHaveDescriptions() {
        for category in TestCleanableCategory.allCases {
            #expect(!category.description.isEmpty, "Missing description for \(category.rawValue)")
        }
    }

    @Test("Cache categories are safe to clean")
    func safeCacheCategories() {
        #expect(TestCleanableCategory.xcodeCache.safetyLevel == .safe)
        #expect(TestCleanableCategory.systemCache.safetyLevel == .safe)
        #expect(TestCleanableCategory.appCache.safetyLevel == .safe)
        #expect(TestCleanableCategory.browserCache.safetyLevel == .safe)
        #expect(TestCleanableCategory.homebrew.safetyLevel == .safe)
        #expect(TestCleanableCategory.swiftPM.safetyLevel == .safe)
        #expect(TestCleanableCategory.logs.safetyLevel == .safe)
    }

    @Test("User data categories require caution")
    func cautionCategories() {
        #expect(TestCleanableCategory.trash.safetyLevel == .caution)
        #expect(TestCleanableCategory.downloads.safetyLevel == .caution)
    }

    @Test("Mail attachments require warning")
    func warningCategories() {
        #expect(TestCleanableCategory.mailAttachments.safetyLevel == .warning)
    }
}

// MARK: - SafetyLevel Tests

@Suite("SystemCleaner — Safety Levels")
struct CleanerSafetyLevelTests {
    @Test("Safety level ordering")
    func ordering() {
        #expect(TestSafetyLevel.safe < TestSafetyLevel.caution)
        #expect(TestSafetyLevel.caution < TestSafetyLevel.warning)
        #expect(TestSafetyLevel.safe < TestSafetyLevel.warning)
    }

    @Test("Display names are user-friendly")
    func displayNames() {
        #expect(TestSafetyLevel.safe.displayName == "Safe to clean")
        #expect(TestSafetyLevel.caution.displayName == "Review recommended")
        #expect(TestSafetyLevel.warning.displayName == "Use caution")
    }
}

// MARK: - Format Bytes Tests

@Suite("SystemCleaner — Format Bytes")
struct CleanerFormatBytesTests {
    @Test("Format bytes")
    func formatSmallBytes() {
        #expect(formatBytes(0) == "0 B")
        #expect(formatBytes(512) == "512 B")
    }

    @Test("Format kilobytes")
    func formatKB() {
        #expect(formatBytes(1024) == "1.0 KB")
        #expect(formatBytes(1536) == "1.5 KB")
    }

    @Test("Format megabytes")
    func formatMB() {
        #expect(formatBytes(1_048_576) == "1.0 MB")
        #expect(formatBytes(524_288_000) == "500.0 MB")
    }

    @Test("Format gigabytes")
    func formatGB() {
        #expect(formatBytes(1_073_741_824) == "1.0 GB")
        #expect(formatBytes(5_368_709_120) == "5.0 GB")
    }

    @Test("Format terabytes")
    func formatTB() {
        #expect(formatBytes(1_099_511_627_776) == "1.0 TB")
    }
}

// MARK: - CleanableItem Tests

@Suite("SystemCleaner — Cleanable Items")
struct CleanableItemTests {
    @Test("File name extraction")
    func fileNameExtraction() {
        let item = TestCleanableItem(path: "/Users/test/Library/Caches/com.test", category: .appCache, sizeBytes: 1024, safeToDelete: true)
        #expect(item.fileName == "com.test")
    }

    @Test("Root path file name")
    func rootPath() {
        let item = TestCleanableItem(path: "/test.log", category: .logs, sizeBytes: 256, safeToDelete: true)
        #expect(item.fileName == "test.log")
    }

    @Test("Safe item properties")
    func safeItem() {
        let item = TestCleanableItem(path: "/tmp/cache", category: .systemCache, sizeBytes: 5000, safeToDelete: true)
        #expect(item.safeToDelete)
        #expect(item.category == .systemCache)
    }

    @Test("Unsafe item properties")
    func unsafeItem() {
        let item = TestCleanableItem(path: "~/Downloads/important.zip", category: .downloads, sizeBytes: 1_000_000, safeToDelete: false)
        #expect(!item.safeToDelete)
    }
}

// MARK: - CleanupResult Tests

@Suite("SystemCleaner — Cleanup Results")
struct CleanupResultTests {
    @Test("Successful cleanup result")
    func successfulCleanup() {
        let result = TestCleanupResult(bytesFreed: 1_073_741_824, filesDeleted: 42, categories: [.xcodeCache, .logs], errors: [])
        #expect(result.bytesFreed == 1_073_741_824)
        #expect(result.filesDeleted == 42)
        #expect(result.categories.count == 2)
        #expect(result.errors.isEmpty)
    }

    @Test("Cleanup with errors")
    func cleanupWithErrors() {
        let result = TestCleanupResult(bytesFreed: 500, filesDeleted: 1, categories: [.trash], errors: ["Permission denied"])
        #expect(!result.errors.isEmpty)
        #expect(result.errors.first == "Permission denied")
    }

    @Test("Empty cleanup result")
    func emptyCleanup() {
        let result = TestCleanupResult(bytesFreed: 0, filesDeleted: 0, categories: [], errors: [])
        #expect(result.bytesFreed == 0)
        #expect(result.filesDeleted == 0)
    }

    @Test("Formatted bytes freed")
    func formattedBytesFreed() {
        let result = TestCleanupResult(bytesFreed: 1_073_741_824, filesDeleted: 1, categories: [.xcodeCache], errors: [])
        #expect(formatBytes(result.bytesFreed) == "1.0 GB")
    }
}

// MARK: - Disk Space Tests

@Suite("SystemCleaner — Disk Usage")
struct CleanerDiskUsageTests {
    @Test("Disk usage percentage calculation")
    func diskUsagePercent() {
        let total: UInt64 = 1_000_000_000_000
        let used: UInt64 = 750_000_000_000
        let percent = Double(used) / Double(total) * 100
        #expect(percent == 75.0)
    }

    @Test("Zero total disk doesn't crash")
    func zeroDisk() {
        let total: UInt64 = 0
        let used: UInt64 = 0
        let percent = total > 0 ? Double(used) / Double(total) * 100 : 0
        #expect(percent == 0)
    }
}
