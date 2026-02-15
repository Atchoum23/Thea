// MediaServerTests.swift
// Tests for MediaServer types and logic
// SPM-compatible — uses standalone test doubles mirroring production types

import Testing
import Foundation

// MARK: - Test Doubles

private enum TestMediaFileType: String, Codable, CaseIterable {
    case video
    case audio
    case image

    var displayName: String {
        switch self {
        case .video: "Video"
        case .audio: "Audio"
        case .image: "Image"
        }
    }

    var icon: String {
        switch self {
        case .video: "film"
        case .audio: "music.note"
        case .image: "photo"
        }
    }

    var supportedExtensions: Set<String> {
        switch self {
        case .video: ["mp4", "m4v", "mov", "avi", "mkv", "wmv", "webm", "flv", "ts", "mpg", "mpeg"]
        case .audio: ["mp3", "m4a", "aac", "flac", "wav", "aiff", "ogg", "wma", "opus"]
        case .image: ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "bmp", "svg"]
        }
    }

    static func detect(from ext: String) -> TestMediaFileType? {
        let lowered = ext.lowercased()
        for type in allCases {
            if type.supportedExtensions.contains(lowered) {
                return type
            }
        }
        return nil
    }
}

private struct TestMediaLibraryItem: Codable, Identifiable {
    let id: UUID
    let name: String
    let path: String
    let type: TestMediaFileType
    let sizeBytes: Int64
    let duration: TimeInterval?
    var addedAt: Date
    var lastPlayedAt: Date?
    var playCount: Int
    var isFavorite: Bool
    var tags: [String]

    init(name: String, path: String, type: TestMediaFileType, sizeBytes: Int64, duration: TimeInterval? = nil) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.type = type
        self.sizeBytes = sizeBytes
        self.duration = duration
        self.addedAt = Date()
        self.playCount = 0
        self.isFavorite = false
        self.tags = []
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct TestMediaLibraryFolder: Codable, Identifiable {
    let id: UUID
    let path: String
    let name: String
    var lastScannedAt: Date?
    var itemCount: Int

    init(path: String) {
        self.id = UUID()
        self.path = path
        self.name = URL(fileURLWithPath: path).lastPathComponent
        self.itemCount = 0
    }
}

private enum TestMediaServerStatus: String {
    case stopped, starting, running, error

    var displayName: String {
        switch self {
        case .stopped: "Stopped"
        case .starting: "Starting..."
        case .running: "Running"
        case .error: "Error"
        }
    }

    var icon: String {
        switch self {
        case .stopped: "stop.circle"
        case .starting: "arrow.clockwise.circle"
        case .running: "play.circle.fill"
        case .error: "exclamationmark.triangle"
        }
    }
}

private enum TestMediaServerError: Error, LocalizedError {
    case alreadyRunning
    case failedToStart(String)
    case folderNotFound(String)
    case scanFailed(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning: "Server is already running"
        case .failedToStart(let reason): "Failed to start server: \(reason)"
        case .folderNotFound(let path): "Folder not found: \(path)"
        case .scanFailed(let reason): "Library scan failed: \(reason)"
        case .fileNotFound(let path): "Media file not found: \(path)"
        }
    }
}

// MARK: - Mime Type Helper

private func mimeType(for ext: String) -> String {
    switch ext.lowercased() {
    case "mp4", "m4v": "video/mp4"
    case "mov": "video/quicktime"
    case "avi": "video/x-msvideo"
    case "mkv": "video/x-matroska"
    case "webm": "video/webm"
    case "mp3": "audio/mpeg"
    case "m4a", "aac": "audio/mp4"
    case "flac": "audio/flac"
    case "wav": "audio/wav"
    case "ogg", "opus": "audio/ogg"
    case "jpg", "jpeg": "image/jpeg"
    case "png": "image/png"
    case "gif": "image/gif"
    case "webp": "image/webp"
    case "svg": "image/svg+xml"
    case "heic", "heif": "image/heic"
    default: "application/octet-stream"
    }
}

// MARK: - HTML Escape Helper

private func escapeHTML(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

// MARK: - MediaFileType Tests

@Suite("MediaFileType")
struct MediaFileTypeTests {
    @Test("All 3 cases exist")
    func allCases() {
        #expect(TestMediaFileType.allCases.count == 3)
    }

    @Test("Display names")
    func displayNames() {
        #expect(TestMediaFileType.video.displayName == "Video")
        #expect(TestMediaFileType.audio.displayName == "Audio")
        #expect(TestMediaFileType.image.displayName == "Image")
    }

    @Test("Icons")
    func icons() {
        #expect(TestMediaFileType.video.icon == "film")
        #expect(TestMediaFileType.audio.icon == "music.note")
        #expect(TestMediaFileType.image.icon == "photo")
    }

    @Test("Video detection from common extensions")
    func detectVideo() {
        for ext in ["mp4", "m4v", "mov", "avi", "mkv", "wmv", "webm"] {
            #expect(TestMediaFileType.detect(from: ext) == .video, "Expected video for .\(ext)")
        }
    }

    @Test("Audio detection from common extensions")
    func detectAudio() {
        for ext in ["mp3", "m4a", "aac", "flac", "wav", "aiff", "ogg"] {
            #expect(TestMediaFileType.detect(from: ext) == .audio, "Expected audio for .\(ext)")
        }
    }

    @Test("Image detection from common extensions")
    func detectImage() {
        for ext in ["jpg", "jpeg", "png", "gif", "heic", "webp", "svg", "tiff", "bmp"] {
            #expect(TestMediaFileType.detect(from: ext) == .image, "Expected image for .\(ext)")
        }
    }

    @Test("Nil for unknown extensions")
    func detectUnknown() {
        #expect(TestMediaFileType.detect(from: "txt") == nil)
        #expect(TestMediaFileType.detect(from: "pdf") == nil)
        #expect(TestMediaFileType.detect(from: "swift") == nil)
        #expect(TestMediaFileType.detect(from: "") == nil)
    }

    @Test("Case-insensitive detection")
    func caseInsensitive() {
        #expect(TestMediaFileType.detect(from: "MP4") == .video)
        #expect(TestMediaFileType.detect(from: "Flac") == .audio)
        #expect(TestMediaFileType.detect(from: "PNG") == .image)
    }

    @Test("Video supported extensions count")
    func videoExtensionCount() {
        #expect(TestMediaFileType.video.supportedExtensions.count == 11)
    }

    @Test("Audio supported extensions count")
    func audioExtensionCount() {
        #expect(TestMediaFileType.audio.supportedExtensions.count == 9)
    }

    @Test("Image supported extensions count")
    func imageExtensionCount() {
        #expect(TestMediaFileType.image.supportedExtensions.count == 10)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for type in TestMediaFileType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(TestMediaFileType.self, from: data)
            #expect(decoded == type)
        }
    }
}

// MARK: - MediaLibraryItem Tests

@Suite("MediaLibraryItem")
struct MediaLibraryItemTests {
    @Test("Init defaults")
    func initDefaults() {
        let item = TestMediaLibraryItem(name: "Movie", path: "/videos/movie.mp4", type: .video, sizeBytes: 1_500_000_000)
        #expect(item.name == "Movie")
        #expect(item.path == "/videos/movie.mp4")
        #expect(item.type == .video)
        #expect(item.sizeBytes == 1_500_000_000)
        #expect(item.duration == nil)
        #expect(item.playCount == 0)
        #expect(item.isFavorite == false)
        #expect(item.tags.isEmpty)
        #expect(item.lastPlayedAt == nil)
    }

    @Test("Init with duration")
    func initWithDuration() {
        let item = TestMediaLibraryItem(name: "Song", path: "/music/song.mp3", type: .audio, sizeBytes: 5_000_000, duration: 213.5)
        #expect(item.duration == 213.5)
    }

    @Test("Formatted size for GB file")
    func formattedSizeGB() {
        let item = TestMediaLibraryItem(name: "Big", path: "/big.mkv", type: .video, sizeBytes: 4_500_000_000)
        #expect(item.formattedSize.contains("GB"))
    }

    @Test("Formatted size for MB file")
    func formattedSizeMB() {
        let item = TestMediaLibraryItem(name: "Small", path: "/small.mp3", type: .audio, sizeBytes: 3_500_000)
        #expect(item.formattedSize.contains("MB"))
    }

    @Test("Formatted duration for minutes only")
    func durationMinutes() {
        let item = TestMediaLibraryItem(name: "Track", path: "/t.mp3", type: .audio, sizeBytes: 1000, duration: 185)
        #expect(item.formattedDuration == "3:05")
    }

    @Test("Formatted duration for hours")
    func durationHours() {
        let item = TestMediaLibraryItem(name: "Movie", path: "/m.mp4", type: .video, sizeBytes: 1000, duration: 7384)
        #expect(item.formattedDuration == "2:03:04")
    }

    @Test("Formatted duration nil when no duration")
    func durationNil() {
        let item = TestMediaLibraryItem(name: "Photo", path: "/p.jpg", type: .image, sizeBytes: 1000)
        #expect(item.formattedDuration == nil)
    }

    @Test("Formatted duration for exactly 0 seconds")
    func durationZero() {
        let item = TestMediaLibraryItem(name: "Test", path: "/t.mp3", type: .audio, sizeBytes: 100, duration: 0)
        #expect(item.formattedDuration == "0:00")
    }

    @Test("Formatted duration for exactly 60 seconds")
    func durationOneMinute() {
        let item = TestMediaLibraryItem(name: "Test", path: "/t.mp3", type: .audio, sizeBytes: 100, duration: 60)
        #expect(item.formattedDuration == "1:00")
    }

    @Test("Formatted duration for exactly 3600 seconds")
    func durationOneHour() {
        let item = TestMediaLibraryItem(name: "Test", path: "/t.mp4", type: .video, sizeBytes: 100, duration: 3600)
        #expect(item.formattedDuration == "1:00:00")
    }

    @Test("Unique IDs")
    func uniqueIDs() {
        let a = TestMediaLibraryItem(name: "A", path: "/a.mp4", type: .video, sizeBytes: 100)
        let b = TestMediaLibraryItem(name: "B", path: "/b.mp4", type: .video, sizeBytes: 200)
        #expect(a.id != b.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        var item = TestMediaLibraryItem(name: "Song", path: "/s.mp3", type: .audio, sizeBytes: 5_000_000, duration: 180)
        item.isFavorite = true
        item.playCount = 5
        item.tags = ["rock", "favorites"]
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(TestMediaLibraryItem.self, from: data)
        #expect(decoded.name == "Song")
        #expect(decoded.type == .audio)
        #expect(decoded.isFavorite == true)
        #expect(decoded.playCount == 5)
        #expect(decoded.tags == ["rock", "favorites"])
        #expect(decoded.duration == 180)
    }

    @Test("Favorite toggle")
    func favoriteToggle() {
        var item = TestMediaLibraryItem(name: "Test", path: "/t.mp3", type: .audio, sizeBytes: 100)
        #expect(item.isFavorite == false)
        item.isFavorite.toggle()
        #expect(item.isFavorite == true)
        item.isFavorite.toggle()
        #expect(item.isFavorite == false)
    }

    @Test("Play count increment")
    func playCountIncrement() {
        var item = TestMediaLibraryItem(name: "Test", path: "/t.mp4", type: .video, sizeBytes: 100)
        #expect(item.playCount == 0)
        item.playCount += 1
        #expect(item.playCount == 1)
        item.playCount += 1
        #expect(item.playCount == 2)
    }
}

// MARK: - MediaLibraryFolder Tests

@Suite("MediaLibraryFolder")
struct MediaLibraryFolderTests {
    @Test("Init from path")
    func initFromPath() {
        let folder = TestMediaLibraryFolder(path: "/Users/alexis/Movies")
        #expect(folder.path == "/Users/alexis/Movies")
        #expect(folder.name == "Movies")
        #expect(folder.itemCount == 0)
        #expect(folder.lastScannedAt == nil)
    }

    @Test("Name extracted from path")
    func nameExtraction() {
        let folder = TestMediaLibraryFolder(path: "/media/Music Library")
        #expect(folder.name == "Music Library")
    }

    @Test("Unique IDs")
    func uniqueIDs() {
        let a = TestMediaLibraryFolder(path: "/a")
        let b = TestMediaLibraryFolder(path: "/b")
        #expect(a.id != b.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        var folder = TestMediaLibraryFolder(path: "/Users/alexis/Music")
        folder.lastScannedAt = Date()
        folder.itemCount = 42
        let data = try JSONEncoder().encode(folder)
        let decoded = try JSONDecoder().decode(TestMediaLibraryFolder.self, from: data)
        #expect(decoded.path == "/Users/alexis/Music")
        #expect(decoded.name == "Music")
        #expect(decoded.itemCount == 42)
        #expect(decoded.lastScannedAt != nil)
    }
}

// MARK: - MediaServerStatus Tests

@Suite("MediaServerStatus")
struct MediaServerStatusTests {
    @Test("Display names")
    func displayNames() {
        #expect(TestMediaServerStatus.stopped.displayName == "Stopped")
        #expect(TestMediaServerStatus.starting.displayName == "Starting...")
        #expect(TestMediaServerStatus.running.displayName == "Running")
        #expect(TestMediaServerStatus.error.displayName == "Error")
    }

    @Test("Icons")
    func icons() {
        #expect(TestMediaServerStatus.stopped.icon == "stop.circle")
        #expect(TestMediaServerStatus.starting.icon == "arrow.clockwise.circle")
        #expect(TestMediaServerStatus.running.icon == "play.circle.fill")
        #expect(TestMediaServerStatus.error.icon == "exclamationmark.triangle")
    }
}

// MARK: - MediaServerError Tests

@Suite("MediaServerError")
struct MediaServerErrorTests {
    @Test("Already running")
    func alreadyRunning() {
        let error = TestMediaServerError.alreadyRunning
        #expect(error.errorDescription == "Server is already running")
    }

    @Test("Failed to start with reason")
    func failedToStart() {
        let error = TestMediaServerError.failedToStart("port in use")
        #expect(error.errorDescription?.contains("port in use") == true)
    }

    @Test("Folder not found")
    func folderNotFound() {
        let error = TestMediaServerError.folderNotFound("/missing/folder")
        #expect(error.errorDescription?.contains("/missing/folder") == true)
    }

    @Test("Scan failed")
    func scanFailed() {
        let error = TestMediaServerError.scanFailed("permission denied")
        #expect(error.errorDescription?.contains("permission denied") == true)
    }

    @Test("File not found")
    func fileNotFound() {
        let error = TestMediaServerError.fileNotFound("/missing/file.mp4")
        #expect(error.errorDescription?.contains("/missing/file.mp4") == true)
    }
}

// MARK: - MIME Type Tests

@Suite("MimeType")
struct MimeTypeTests {
    @Test("Video MIME types")
    func videoMime() {
        #expect(mimeType(for: "mp4") == "video/mp4")
        #expect(mimeType(for: "m4v") == "video/mp4")
        #expect(mimeType(for: "mov") == "video/quicktime")
        #expect(mimeType(for: "avi") == "video/x-msvideo")
        #expect(mimeType(for: "mkv") == "video/x-matroska")
        #expect(mimeType(for: "webm") == "video/webm")
    }

    @Test("Audio MIME types")
    func audioMime() {
        #expect(mimeType(for: "mp3") == "audio/mpeg")
        #expect(mimeType(for: "m4a") == "audio/mp4")
        #expect(mimeType(for: "aac") == "audio/mp4")
        #expect(mimeType(for: "flac") == "audio/flac")
        #expect(mimeType(for: "wav") == "audio/wav")
        #expect(mimeType(for: "ogg") == "audio/ogg")
        #expect(mimeType(for: "opus") == "audio/ogg")
    }

    @Test("Image MIME types")
    func imageMime() {
        #expect(mimeType(for: "jpg") == "image/jpeg")
        #expect(mimeType(for: "jpeg") == "image/jpeg")
        #expect(mimeType(for: "png") == "image/png")
        #expect(mimeType(for: "gif") == "image/gif")
        #expect(mimeType(for: "webp") == "image/webp")
        #expect(mimeType(for: "svg") == "image/svg+xml")
        #expect(mimeType(for: "heic") == "image/heic")
    }

    @Test("Unknown extension falls back to octet-stream")
    func unknownMime() {
        #expect(mimeType(for: "xyz") == "application/octet-stream")
        #expect(mimeType(for: "doc") == "application/octet-stream")
    }

    @Test("Case-insensitive MIME detection")
    func caseInsensitive() {
        #expect(mimeType(for: "MP4") == "video/mp4")
        #expect(mimeType(for: "PNG") == "image/png")
        #expect(mimeType(for: "Flac") == "audio/flac")
    }
}

// MARK: - HTML Escaping Tests

@Suite("HTMLEscaping")
struct HTMLEscapingTests {
    @Test("Escapes ampersand")
    func ampersand() {
        #expect(escapeHTML("A & B") == "A &amp; B")
    }

    @Test("Escapes angle brackets")
    func angleBrackets() {
        #expect(escapeHTML("<script>alert(1)</script>") == "&lt;script&gt;alert(1)&lt;/script&gt;")
    }

    @Test("No change for safe string")
    func noChange() {
        #expect(escapeHTML("Hello World") == "Hello World")
    }

    @Test("Multiple escapes")
    func multiple() {
        #expect(escapeHTML("a < b & c > d") == "a &lt; b &amp; c &gt; d")
    }
}

// MARK: - Library Filtering Logic Tests

@Suite("LibraryFiltering")
struct LibraryFilteringTests {
    private static func makeSampleItems() -> [TestMediaLibraryItem] {
        [
            TestMediaLibraryItem(name: "Movie Night", path: "/m.mp4", type: .video, sizeBytes: 1_000_000),
            TestMediaLibraryItem(name: "Concert Live", path: "/c.mp4", type: .video, sizeBytes: 2_000_000),
            TestMediaLibraryItem(name: "Jazz Album", path: "/j.mp3", type: .audio, sizeBytes: 500_000),
            TestMediaLibraryItem(name: "Rock Song", path: "/r.flac", type: .audio, sizeBytes: 800_000),
            TestMediaLibraryItem(name: "Vacation Photo", path: "/v.jpg", type: .image, sizeBytes: 3_000_000),
        ]
    }

    private static func filter(items: [TestMediaLibraryItem], type: TestMediaFileType? = nil, search: String = "") -> [TestMediaLibraryItem] {
        var result = items
        if let type {
            result = result.filter { $0.type == type }
        }
        if !search.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(search) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(search) }
            }
        }
        return result
    }

    @Test("No filter returns all")
    func noFilter() {
        let items = Self.makeSampleItems()
        let filtered = Self.filter(items: items)
        #expect(filtered.count == 5)
    }

    @Test("Filter by video")
    func filterVideo() {
        let items = Self.makeSampleItems()
        let filtered = Self.filter(items: items, type: .video)
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.type == .video })
    }

    @Test("Filter by audio")
    func filterAudio() {
        let items = Self.makeSampleItems()
        let filtered = Self.filter(items: items, type: .audio)
        #expect(filtered.count == 2)
    }

    @Test("Filter by image")
    func filterImage() {
        let items = Self.makeSampleItems()
        let filtered = Self.filter(items: items, type: .image)
        #expect(filtered.count == 1)
    }

    @Test("Search by name")
    func searchByName() {
        let items = Self.makeSampleItems()
        let filtered = Self.filter(items: items, search: "Jazz")
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Jazz Album")
    }

    @Test("Search case-insensitive")
    func searchCaseInsensitive() {
        let items = Self.makeSampleItems()
        let filtered = Self.filter(items: items, search: "movie")
        #expect(filtered.count == 1)
    }

    @Test("Filter by type and search")
    func typeAndSearch() {
        let items = Self.makeSampleItems()
        let filtered = Self.filter(items: items, type: .video, search: "Concert")
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Concert Live")
    }

    @Test("Search with no matches")
    func searchNoMatch() {
        let items = Self.makeSampleItems()
        let filtered = Self.filter(items: items, search: "ZZZZZ")
        #expect(filtered.isEmpty)
    }

    @Test("Search by tag")
    func searchByTag() {
        var items = Self.makeSampleItems()
        items[0].tags = ["action", "thriller"]
        let filtered = Self.filter(items: items, search: "thriller")
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Movie Night")
    }
}

// MARK: - Library Stats Logic Tests

@Suite("LibraryStats")
struct LibraryStatsTests {
    @Test("Computed stats from items")
    func computeStats() {
        let items = [
            TestMediaLibraryItem(name: "V1", path: "/v1.mp4", type: .video, sizeBytes: 1_000_000_000),
            TestMediaLibraryItem(name: "V2", path: "/v2.mp4", type: .video, sizeBytes: 2_000_000_000),
            TestMediaLibraryItem(name: "A1", path: "/a1.mp3", type: .audio, sizeBytes: 5_000_000),
            TestMediaLibraryItem(name: "I1", path: "/i1.jpg", type: .image, sizeBytes: 3_000_000),
            TestMediaLibraryItem(name: "I2", path: "/i2.png", type: .image, sizeBytes: 2_000_000),
        ]
        let videos = items.filter { $0.type == .video }.count
        let audio = items.filter { $0.type == .audio }.count
        let images = items.filter { $0.type == .image }.count
        let totalSize = items.reduce(Int64(0)) { $0 + $1.sizeBytes }

        #expect(items.count == 5)
        #expect(videos == 2)
        #expect(audio == 1)
        #expect(images == 2)
        #expect(totalSize == 3_010_000_000)
    }

    @Test("Empty library stats")
    func emptyStats() {
        let items: [TestMediaLibraryItem] = []
        let videos = items.filter { $0.type == .video }.count
        let totalSize = items.reduce(Int64(0)) { $0 + $1.sizeBytes }
        #expect(items.isEmpty)
        #expect(videos == 0)
        #expect(totalSize == 0)
    }
}
