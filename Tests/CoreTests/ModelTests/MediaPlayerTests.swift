// MediaPlayerTests.swift
// Tests for MediaPlayer service types, formatting, and logic.

import Testing
import Foundation

// MARK: - Test Doubles

/// Mirror of MediaPlaybackType for SPM testing.
private enum TestMediaPlaybackType: String, Codable, CaseIterable {
    case video
    case audio
    case stream

    var icon: String {
        switch self {
        case .video: "film"
        case .audio: "music.note"
        case .stream: "antenna.radiowaves.left.and.right"
        }
    }

    var displayName: String {
        switch self {
        case .video: "Video"
        case .audio: "Audio"
        case .stream: "Stream"
        }
    }
}

/// Mirror of PlaybackStatus for SPM testing.
private enum TestPlaybackStatus: String, Codable {
    case idle
    case loading
    case playing
    case paused
    case stopped
    case failed

    var isActive: Bool {
        self == .playing || self == .paused
    }
}

/// Mirror of PlaybackSpeed for SPM testing.
private enum TestPlaybackSpeed: Double, CaseIterable {
    case quarterSpeed = 0.25
    case halfSpeed = 0.5
    case threeQuarterSpeed = 0.75
    case normal = 1.0
    case oneAndQuarter = 1.25
    case oneAndHalf = 1.5
    case double = 2.0
    case triple = 3.0

    var displayName: String {
        if self == .normal { return "1x" }
        let value = rawValue
        if value == value.rounded() {
            return "\(Int(value))x"
        }
        return "\(value)x"
    }
}

/// Mirror of MediaBookmark for SPM testing.
private struct TestMediaBookmark: Codable, Identifiable {
    let id: UUID
    let timestamp: TimeInterval
    let label: String
    let note: String?
    let createdAt: Date

    init(timestamp: TimeInterval, label: String, note: String? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.label = label
        self.note = note
        self.createdAt = Date()
    }

    var formattedTimestamp: String {
        formatDuration(timestamp)
    }
}

/// Mirror of MediaChapter for SPM testing.
private struct TestMediaChapter: Codable, Identifiable {
    let id: UUID
    let title: String
    let startTime: TimeInterval
    let endTime: TimeInterval?

    init(title: String, startTime: TimeInterval, endTime: TimeInterval? = nil) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
    }

    var formattedStart: String {
        formatDuration(startTime)
    }
}

/// Mirror of PlayedMediaItem for SPM testing.
private struct TestPlayedMediaItem: Codable, Identifiable {
    let id: UUID
    let title: String
    let url: String
    let mediaType: TestMediaPlaybackType
    let duration: TimeInterval
    var lastPosition: TimeInterval
    var lastPlayedAt: Date
    let addedAt: Date
    var playCount: Int
    var bookmarks: [TestMediaBookmark]
    var chapters: [TestMediaChapter]
    var isFavorite: Bool
    var thumbnailPath: String?
    var codec: String?
    var resolution: String?
    var fileSize: Int64?
    var aiSummary: String?

    init(title: String, url: String, mediaType: TestMediaPlaybackType, duration: TimeInterval = 0) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.mediaType = mediaType
        self.duration = duration
        self.lastPosition = 0
        self.lastPlayedAt = Date()
        self.addedAt = Date()
        self.playCount = 1
        self.bookmarks = []
        self.chapters = []
        self.isFavorite = false
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(lastPosition / duration, 1.0)
    }
}

/// Mirror of MediaPlaybackStats for SPM testing.
private struct TestMediaPlaybackStats: Codable {
    var totalItemsPlayed: Int
    var totalPlayTime: TimeInterval
    var videoCount: Int
    var audioCount: Int
    var streamCount: Int
    var favoriteCount: Int
    var bookmarkCount: Int

    static var empty: TestMediaPlaybackStats {
        TestMediaPlaybackStats(
            totalItemsPlayed: 0,
            totalPlayTime: 0,
            videoCount: 0,
            audioCount: 0,
            streamCount: 0,
            favoriteCount: 0,
            bookmarkCount: 0
        )
    }

    var formattedPlayTime: String {
        formatDuration(totalPlayTime)
    }
}

/// Mirror of MediaPlayerError for SPM testing.
private enum TestMediaPlayerError: Error, LocalizedError {
    case fileNotFound(String)
    case unsupportedFormat(String)
    case playbackFailed(String)
    case networkError(String)
    case noActiveItem

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): "File not found: \(path)"
        case .unsupportedFormat(let format): "Unsupported format: \(format)"
        case .playbackFailed(let reason): "Playback failed: \(reason)"
        case .networkError(let reason): "Network error: \(reason)"
        case .noActiveItem: "No media item is currently active"
        }
    }
}

/// Standalone format duration (mirrors nonisolated static method).
private func formatDuration(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite && seconds >= 0 else { return "0:00" }
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}

/// Media type inference (mirrors private method).
private func inferMediaType(from ext: String) -> TestMediaPlaybackType {
    let videoExtensions = Set(["mp4", "mov", "mkv", "avi", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "ts", "3gp"])
    let audioExtensions = Set(["mp3", "m4a", "aac", "wav", "flac", "ogg", "wma", "aiff", "alac", "opus"])

    if videoExtensions.contains(ext) { return .video }
    if audioExtensions.contains(ext) { return .audio }
    if ext == "m3u8" { return .stream }
    return .video
}

// MARK: - Tests

@Suite("MediaPlaybackType — Enum Properties")
struct MediaPlaybackTypeTests {
    @Test func allCasesExist() {
        #expect(TestMediaPlaybackType.allCases.count == 3)
    }

    @Test func uniqueRawValues() {
        let values = Set(TestMediaPlaybackType.allCases.map(\.rawValue))
        #expect(values.count == 3)
    }

    @Test func icons() {
        #expect(TestMediaPlaybackType.video.icon == "film")
        #expect(TestMediaPlaybackType.audio.icon == "music.note")
        #expect(TestMediaPlaybackType.stream.icon == "antenna.radiowaves.left.and.right")
    }

    @Test func displayNames() {
        #expect(TestMediaPlaybackType.video.displayName == "Video")
        #expect(TestMediaPlaybackType.audio.displayName == "Audio")
        #expect(TestMediaPlaybackType.stream.displayName == "Stream")
    }

    @Test func codableRoundtrip() throws {
        let original = TestMediaPlaybackType.audio
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestMediaPlaybackType.self, from: data)
        #expect(decoded == original)
    }
}

@Suite("PlaybackStatus — State Logic")
struct PlaybackStatusTests {
    @Test func isActivePlaying() {
        #expect(TestPlaybackStatus.playing.isActive)
    }

    @Test func isActivePaused() {
        #expect(TestPlaybackStatus.paused.isActive)
    }

    @Test func isNotActiveIdle() {
        #expect(!TestPlaybackStatus.idle.isActive)
    }

    @Test func isNotActiveStopped() {
        #expect(!TestPlaybackStatus.stopped.isActive)
    }

    @Test func isNotActiveFailed() {
        #expect(!TestPlaybackStatus.failed.isActive)
    }

    @Test func isNotActiveLoading() {
        #expect(!TestPlaybackStatus.loading.isActive)
    }
}

@Suite("PlaybackSpeed — Display Names")
struct PlaybackSpeedTests {
    @Test func normalIsOneX() {
        #expect(TestPlaybackSpeed.normal.displayName == "1x")
    }

    @Test func doubleIsTwoX() {
        #expect(TestPlaybackSpeed.double.displayName == "2x")
    }

    @Test func tripleIsThreeX() {
        #expect(TestPlaybackSpeed.triple.displayName == "3x")
    }

    @Test func halfSpeedDecimal() {
        #expect(TestPlaybackSpeed.halfSpeed.displayName == "0.5x")
    }

    @Test func oneAndHalfDecimal() {
        #expect(TestPlaybackSpeed.oneAndHalf.displayName == "1.5x")
    }

    @Test func quarterSpeedDecimal() {
        #expect(TestPlaybackSpeed.quarterSpeed.displayName == "0.25x")
    }

    @Test func allCasesCount() {
        #expect(TestPlaybackSpeed.allCases.count == 8)
    }

    @Test func rawValuesAscending() {
        let values = TestPlaybackSpeed.allCases.map(\.rawValue)
        #expect(values == values.sorted())
    }
}

@Suite("Duration Formatting")
struct DurationFormatTests {
    @Test func zeroSeconds() {
        #expect(formatDuration(0) == "0:00")
    }

    @Test func thirtySeconds() {
        #expect(formatDuration(30) == "0:30")
    }

    @Test func oneMinute() {
        #expect(formatDuration(60) == "1:00")
    }

    @Test func oneMinuteThirty() {
        #expect(formatDuration(90) == "1:30")
    }

    @Test func tenMinutes() {
        #expect(formatDuration(600) == "10:00")
    }

    @Test func oneHour() {
        #expect(formatDuration(3600) == "1:00:00")
    }

    @Test func oneHourThirtyMinutes() {
        #expect(formatDuration(5400) == "1:30:00")
    }

    @Test func twoHoursFifteenMinutesThirtySeconds() {
        #expect(formatDuration(8130) == "2:15:30")
    }

    @Test func negativeReturnsZero() {
        #expect(formatDuration(-5) == "0:00")
    }

    @Test func infiniteReturnsZero() {
        #expect(formatDuration(Double.infinity) == "0:00")
    }

    @Test func nanReturnsZero() {
        #expect(formatDuration(Double.nan) == "0:00")
    }

    @Test func veryLargeValue() {
        let result = formatDuration(86400) // 24 hours
        #expect(result == "24:00:00")
    }
}

@Suite("MediaBookmark")
struct MediaBookmarkTests {
    @Test func creation() {
        let bookmark = TestMediaBookmark(timestamp: 120, label: "Important part")
        #expect(bookmark.timestamp == 120)
        #expect(bookmark.label == "Important part")
        #expect(bookmark.note == nil)
    }

    @Test func creationWithNote() {
        let bookmark = TestMediaBookmark(timestamp: 300, label: "Key scene", note: "Character introduction")
        #expect(bookmark.note == "Character introduction")
    }

    @Test func uniqueIDs() {
        let a = TestMediaBookmark(timestamp: 0, label: "A")
        let b = TestMediaBookmark(timestamp: 0, label: "B")
        #expect(a.id != b.id)
    }

    @Test func formattedTimestamp() {
        let bookmark = TestMediaBookmark(timestamp: 3661, label: "Test")
        #expect(bookmark.formattedTimestamp == "1:01:01")
    }

    @Test func codableRoundtrip() throws {
        let bookmark = TestMediaBookmark(timestamp: 45.5, label: "Mark", note: "test note")
        let data = try JSONEncoder().encode(bookmark)
        let decoded = try JSONDecoder().decode(TestMediaBookmark.self, from: data)
        #expect(decoded.label == bookmark.label)
        #expect(decoded.timestamp == bookmark.timestamp)
        #expect(decoded.note == bookmark.note)
    }
}

@Suite("MediaChapter")
struct MediaChapterTests {
    @Test func creation() {
        let chapter = TestMediaChapter(title: "Introduction", startTime: 0, endTime: 120)
        #expect(chapter.title == "Introduction")
        #expect(chapter.startTime == 0)
        #expect(chapter.endTime == 120)
    }

    @Test func noEndTime() {
        let chapter = TestMediaChapter(title: "Last Chapter", startTime: 600)
        #expect(chapter.endTime == nil)
    }

    @Test func formattedStart() {
        let chapter = TestMediaChapter(title: "Act 2", startTime: 1800)
        #expect(chapter.formattedStart == "30:00")
    }

    @Test func uniqueIDs() {
        let a = TestMediaChapter(title: "A", startTime: 0)
        let b = TestMediaChapter(title: "B", startTime: 0)
        #expect(a.id != b.id)
    }

    @Test func codableRoundtrip() throws {
        let chapter = TestMediaChapter(title: "Scene 1", startTime: 30, endTime: 90)
        let data = try JSONEncoder().encode(chapter)
        let decoded = try JSONDecoder().decode(TestMediaChapter.self, from: data)
        #expect(decoded.title == chapter.title)
        #expect(decoded.startTime == chapter.startTime)
        #expect(decoded.endTime == chapter.endTime)
    }
}

@Suite("PlayedMediaItem")
struct PlayedMediaItemTests {
    @Test func creation() {
        let item = TestPlayedMediaItem(title: "movie.mp4", url: "file:///movie.mp4", mediaType: .video, duration: 7200)
        #expect(item.title == "movie.mp4")
        #expect(item.mediaType == .video)
        #expect(item.duration == 7200)
        #expect(item.playCount == 1)
        #expect(item.bookmarks.isEmpty)
        #expect(item.chapters.isEmpty)
        #expect(!item.isFavorite)
    }

    @Test func progressZero() {
        let item = TestPlayedMediaItem(title: "test", url: "file:///test", mediaType: .audio)
        #expect(item.progress == 0)
    }

    @Test func progressZeroDuration() {
        var item = TestPlayedMediaItem(title: "test", url: "file:///test", mediaType: .audio)
        item.lastPosition = 50
        #expect(item.progress == 0) // duration is 0
    }

    @Test func progressHalfway() {
        var item = TestPlayedMediaItem(title: "test", url: "file:///test", mediaType: .audio, duration: 100)
        item.lastPosition = 50
        #expect(item.progress == 0.5)
    }

    @Test func progressCappedAtOne() {
        var item = TestPlayedMediaItem(title: "test", url: "file:///test", mediaType: .audio, duration: 100)
        item.lastPosition = 200
        #expect(item.progress == 1.0)
    }

    @Test func uniqueIDs() {
        let a = TestPlayedMediaItem(title: "a", url: "file:///a", mediaType: .video)
        let b = TestPlayedMediaItem(title: "b", url: "file:///b", mediaType: .video)
        #expect(a.id != b.id)
    }

    @Test func codableRoundtrip() throws {
        var item = TestPlayedMediaItem(title: "test.mp4", url: "file:///test.mp4", mediaType: .video, duration: 3600)
        item.isFavorite = true
        item.resolution = "1920x1080"
        item.fileSize = 1_073_741_824
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(TestPlayedMediaItem.self, from: data)
        #expect(decoded.title == item.title)
        #expect(decoded.mediaType == .video)
        #expect(decoded.isFavorite)
        #expect(decoded.resolution == "1920x1080")
        #expect(decoded.fileSize == 1_073_741_824)
    }

    @Test func favoriteToggle() {
        var item = TestPlayedMediaItem(title: "test", url: "file:///test", mediaType: .audio)
        #expect(!item.isFavorite)
        item.isFavorite = true
        #expect(item.isFavorite)
        item.isFavorite = false
        #expect(!item.isFavorite)
    }
}

@Suite("MediaPlaybackStats")
struct MediaPlaybackStatsTests {
    @Test func empty() {
        let stats = TestMediaPlaybackStats.empty
        #expect(stats.totalItemsPlayed == 0)
        #expect(stats.totalPlayTime == 0)
        #expect(stats.videoCount == 0)
        #expect(stats.audioCount == 0)
        #expect(stats.streamCount == 0)
        #expect(stats.favoriteCount == 0)
        #expect(stats.bookmarkCount == 0)
    }

    @Test func formattedPlayTimeZero() {
        let stats = TestMediaPlaybackStats.empty
        #expect(stats.formattedPlayTime == "0:00")
    }

    @Test func formattedPlayTimeHours() {
        var stats = TestMediaPlaybackStats.empty
        stats.totalPlayTime = 7200
        #expect(stats.formattedPlayTime == "2:00:00")
    }

    @Test func codableRoundtrip() throws {
        let stats = TestMediaPlaybackStats(
            totalItemsPlayed: 42,
            totalPlayTime: 86400,
            videoCount: 20,
            audioCount: 15,
            streamCount: 7,
            favoriteCount: 5,
            bookmarkCount: 12
        )
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(TestMediaPlaybackStats.self, from: data)
        #expect(decoded.totalItemsPlayed == 42)
        #expect(decoded.videoCount == 20)
        #expect(decoded.bookmarkCount == 12)
    }
}

@Suite("MediaPlayerError — Descriptions")
struct MediaPlayerErrorTests {
    @Test func fileNotFound() {
        let error = TestMediaPlayerError.fileNotFound("/path/to/file.mp4")
        #expect(error.errorDescription?.contains("File not found") == true)
        #expect(error.errorDescription?.contains("/path/to/file.mp4") == true)
    }

    @Test func unsupportedFormat() {
        let error = TestMediaPlayerError.unsupportedFormat("rm")
        #expect(error.errorDescription?.contains("Unsupported format") == true)
        #expect(error.errorDescription?.contains("rm") == true)
    }

    @Test func playbackFailed() {
        let error = TestMediaPlayerError.playbackFailed("codec not found")
        #expect(error.errorDescription?.contains("Playback failed") == true)
    }

    @Test func networkError() {
        let error = TestMediaPlayerError.networkError("timeout")
        #expect(error.errorDescription?.contains("Network error") == true)
    }

    @Test func noActiveItem() {
        let error = TestMediaPlayerError.noActiveItem
        #expect(error.errorDescription?.contains("No media item") == true)
    }
}

@Suite("Media Type Inference")
struct MediaTypeInferenceTests {
    @Test func mp4IsVideo() {
        #expect(inferMediaType(from: "mp4") == .video)
    }

    @Test func movIsVideo() {
        #expect(inferMediaType(from: "mov") == .video)
    }

    @Test func mkvIsVideo() {
        #expect(inferMediaType(from: "mkv") == .video)
    }

    @Test func aviIsVideo() {
        #expect(inferMediaType(from: "avi") == .video)
    }

    @Test func webmIsVideo() {
        #expect(inferMediaType(from: "webm") == .video)
    }

    @Test func mp3IsAudio() {
        #expect(inferMediaType(from: "mp3") == .audio)
    }

    @Test func m4aIsAudio() {
        #expect(inferMediaType(from: "m4a") == .audio)
    }

    @Test func flacIsAudio() {
        #expect(inferMediaType(from: "flac") == .audio)
    }

    @Test func wavIsAudio() {
        #expect(inferMediaType(from: "wav") == .audio)
    }

    @Test func opusIsAudio() {
        #expect(inferMediaType(from: "opus") == .audio)
    }

    @Test func m3u8IsStream() {
        #expect(inferMediaType(from: "m3u8") == .stream)
    }

    @Test func unknownDefaultsToVideo() {
        #expect(inferMediaType(from: "xyz") == .video)
    }

    @Test func emptyDefaultsToVideo() {
        #expect(inferMediaType(from: "") == .video)
    }
}

@Suite("Bookmark Sorting")
struct BookmarkSortingTests {
    @Test func sortByTimestamp() {
        var bookmarks = [
            TestMediaBookmark(timestamp: 300, label: "Third"),
            TestMediaBookmark(timestamp: 100, label: "First"),
            TestMediaBookmark(timestamp: 200, label: "Second")
        ]
        bookmarks.sort { $0.timestamp < $1.timestamp }
        #expect(bookmarks[0].label == "First")
        #expect(bookmarks[1].label == "Second")
        #expect(bookmarks[2].label == "Third")
    }
}

@Suite("MediaPlayer History Management")
struct MediaPlayerHistoryTests {
    @Test func findOrCreateNew() {
        let items: [TestPlayedMediaItem] = []
        let result = items.first { $0.url == "file:///new.mp4" }
        #expect(result == nil)
    }

    @Test func findOrCreateExisting() {
        let existing = TestPlayedMediaItem(title: "test", url: "file:///test.mp4", mediaType: .video, duration: 100)
        let items = [existing]
        let result = items.first { $0.url == "file:///test.mp4" }
        #expect(result != nil)
        #expect(result?.title == "test")
    }

    @Test func historyCapAt500() {
        var items: [TestPlayedMediaItem] = (0..<510).map { i in
            TestPlayedMediaItem(title: "item\(i)", url: "file:///item\(i).mp4", mediaType: .video)
        }
        if items.count > 500 {
            items = Array(items.prefix(500))
        }
        #expect(items.count == 500)
    }

    @Test func searchByTitle() {
        let items = [
            TestPlayedMediaItem(title: "My Awesome Movie", url: "file:///a", mediaType: .video),
            TestPlayedMediaItem(title: "Song Track 1", url: "file:///b", mediaType: .audio),
            TestPlayedMediaItem(title: "Another Movie", url: "file:///c", mediaType: .video)
        ]
        let query = "movie"
        let results = items.filter { $0.title.lowercased().contains(query.lowercased()) }
        #expect(results.count == 2)
    }

    @Test func searchEmptyQuery() {
        let items = [
            TestPlayedMediaItem(title: "test", url: "file:///a", mediaType: .video)
        ]
        let query = ""
        let results = query.isEmpty ? items : items.filter { $0.title.lowercased().contains(query.lowercased()) }
        #expect(results.count == 1)
    }

    @Test func favoritesFilter() {
        var item1 = TestPlayedMediaItem(title: "a", url: "file:///a", mediaType: .video)
        item1.isFavorite = true
        let item2 = TestPlayedMediaItem(title: "b", url: "file:///b", mediaType: .audio)
        var item3 = TestPlayedMediaItem(title: "c", url: "file:///c", mediaType: .video)
        item3.isFavorite = true

        let items = [item1, item2, item3]
        let favorites = items.filter(\.isFavorite)
        #expect(favorites.count == 2)
    }

    @Test func statsComputation() {
        var video1 = TestPlayedMediaItem(title: "v1", url: "file:///v1", mediaType: .video, duration: 3600)
        video1.lastPosition = 1800
        video1.isFavorite = true
        video1.bookmarks = [TestMediaBookmark(timestamp: 100, label: "BM")]

        var audio1 = TestPlayedMediaItem(title: "a1", url: "file:///a1", mediaType: .audio, duration: 300)
        audio1.lastPosition = 300

        let stream1 = TestPlayedMediaItem(title: "s1", url: "rtsp://stream", mediaType: .stream)

        let items = [video1, audio1, stream1]
        let stats = TestMediaPlaybackStats(
            totalItemsPlayed: items.count,
            totalPlayTime: items.reduce(0) { $0 + $1.lastPosition },
            videoCount: items.filter { $0.mediaType == .video }.count,
            audioCount: items.filter { $0.mediaType == .audio }.count,
            streamCount: items.filter { $0.mediaType == .stream }.count,
            favoriteCount: items.filter(\.isFavorite).count,
            bookmarkCount: items.reduce(0) { $0 + $1.bookmarks.count }
        )

        #expect(stats.totalItemsPlayed == 3)
        #expect(stats.totalPlayTime == 2100)
        #expect(stats.videoCount == 1)
        #expect(stats.audioCount == 1)
        #expect(stats.streamCount == 1)
        #expect(stats.favoriteCount == 1)
        #expect(stats.bookmarkCount == 1)
    }
}

@Suite("Supported Extensions")
struct SupportedExtensionsTests {
    @Test func videoExtensionsIncluded() {
        let exts = ["mp4", "mov", "mkv", "avi", "wmv", "flv", "webm", "m4v", "mpg", "mpeg"]
        for ext in exts {
            #expect(inferMediaType(from: ext) == .video, "Expected \(ext) to be video")
        }
    }

    @Test func audioExtensionsIncluded() {
        let exts = ["mp3", "m4a", "aac", "wav", "flac", "ogg", "wma", "aiff", "opus"]
        for ext in exts {
            #expect(inferMediaType(from: ext) == .audio, "Expected \(ext) to be audio")
        }
    }
}

@Suite("File Size Formatting")
struct FileSizeFormattingTests {
    @Test func noFileSize() {
        let item = TestPlayedMediaItem(title: "t", url: "f", mediaType: .video)
        #expect(item.fileSize == nil)
    }

    @Test func hasFileSize() {
        var item = TestPlayedMediaItem(title: "t", url: "f", mediaType: .video)
        item.fileSize = 1_073_741_824
        #expect(item.fileSize == 1_073_741_824)
    }
}
