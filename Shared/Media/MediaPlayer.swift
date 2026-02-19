// MediaPlayer.swift
// Thea — Intelligent media player with AI-powered features
// Replaces: IINA (video player)
//
// AVKit-based player with playback history, subtitle generation,
// bookmarks, and AI summaries. Supports video, audio, and streaming.

import AVFoundation
import Foundation
import OSLog
import UniformTypeIdentifiers

// MARK: - Types

/// Supported media types for playback.
enum MediaPlaybackType: String, Codable, CaseIterable, Sendable {
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

/// Playback status.
enum PlaybackStatus: String, Codable, Sendable {
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

/// Speed presets for playback.
enum PlaybackSpeed: Double, CaseIterable, Sendable {
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

/// A bookmark/note within media.
struct MediaBookmark: Codable, Identifiable, Sendable {
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
        MediaPlayer.formatDuration(timestamp)
    }
}

/// A chapter marker within media.
struct MediaChapter: Codable, Identifiable, Sendable {
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
        MediaPlayer.formatDuration(startTime)
    }
}

/// A played media item with metadata and history.
struct PlayedMediaItem: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let url: String
    let mediaType: MediaPlaybackType
    let duration: TimeInterval
    var lastPosition: TimeInterval
    var lastPlayedAt: Date
    let addedAt: Date
    var playCount: Int
    var bookmarks: [MediaBookmark]
    var chapters: [MediaChapter]
    var isFavorite: Bool
    var thumbnailPath: String?
    var codec: String?
    var resolution: String?
    var fileSize: Int64?
    var aiSummary: String?

    init(title: String, url: String, mediaType: MediaPlaybackType, duration: TimeInterval = 0) {
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

    var formattedDuration: String {
        MediaPlayer.formatDuration(duration)
    }

    var formattedLastPosition: String {
        MediaPlayer.formatDuration(lastPosition)
    }

    var formattedFileSize: String? {
        guard let fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

/// Playback statistics.
struct MediaPlaybackStats: Codable, Sendable {
    var totalItemsPlayed: Int
    var totalPlayTime: TimeInterval
    var videoCount: Int
    var audioCount: Int
    var streamCount: Int
    var favoriteCount: Int
    var bookmarkCount: Int

    static var empty: MediaPlaybackStats {
        MediaPlaybackStats(
            totalItemsPlayed: 0,
            totalPlayTime: 0,
            videoCount: 0,
            // periphery:ignore - Reserved: empty static property reserved for future feature activation
            audioCount: 0,
            streamCount: 0,
            favoriteCount: 0,
            bookmarkCount: 0
        )
    }

    var formattedPlayTime: String {
        MediaPlayer.formatDuration(totalPlayTime)
    }
}

/// Media player errors.
enum MediaPlayerError: Error, LocalizedError, Sendable {
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

// MARK: - Media Player Service

/// Singleton media player with playback history, bookmarks, and AI features.
@MainActor
final class MediaPlayer: ObservableObject {
    static let shared = MediaPlayer()

    private let logger = Logger(subsystem: "ai.thea.app", category: "MediaPlayer")

    // MARK: - Published State

    @Published private(set) var status: PlaybackStatus = .idle
    @Published private(set) var currentItem: PlayedMediaItem?
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var volume: Float = 1.0
    @Published var speed: PlaybackSpeed = .normal
    @Published private(set) var history: [PlayedMediaItem] = []
    @Published private(set) var isSubtitlesEnabled = false

    // MARK: - AVPlayer

    // periphery:ignore - Reserved: isSubtitlesEnabled property reserved for future feature activation
    private(set) var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var itemObserver: NSKeyValueObservation?

    // MARK: - Persistence

    private let storageURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea")
            .appendingPathComponent("MediaPlayer")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Logger(subsystem: "ai.thea.app", category: "MediaPlayer").debug("Could not create media player storage: \(error.localizedDescription)")
        }
        return dir
    }()

    private var historyFileURL: URL {
        storageURL.appendingPathComponent("history.json")
    }

    // MARK: - Init

    private init() {
        loadHistory()
    }

    // MARK: - Playback Control

    /// Open and play a media file or URL.
    func open(url: URL) async throws {
        // Determine media type
        let mediaType = inferMediaType(from: url)
        let title = url.lastPathComponent

        // Validate local files
        if url.isFileURL && !FileManager.default.fileExists(atPath: url.path) {
            throw MediaPlayerError.fileNotFound(url.path)
        }

        status = .loading

        // Create AVPlayer
        let asset = AVURLAsset(url: url)

        // Load asset properties
        let loadedDuration: CMTime
        do {
            loadedDuration = try await asset.load(.duration)
        } catch {
            status = .failed
            throw MediaPlayerError.playbackFailed(error.localizedDescription)
        }

        let durationSeconds = CMTimeGetSeconds(loadedDuration)
        let playerItem = AVPlayerItem(asset: asset)

        // Extract metadata
        var item = findOrCreateHistoryItem(title: title, url: url.absoluteString, mediaType: mediaType, duration: durationSeconds)
        item.playCount += 1
        item.lastPlayedAt = Date()

        // Extract video metadata
        do {
            if let videoTrack = try await asset.loadTracks(withMediaType: .video).first {
                do {
                    let size = try await videoTrack.load(.naturalSize)
                    item.resolution = "\(Int(size.width))x\(Int(size.height))"
                } catch {
                    logger.debug("Could not load video track size: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.debug("Could not load video tracks: \(error.localizedDescription)")
        }

        // File size for local files
        if url.isFileURL {
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                item.fileSize = attrs[.size] as? Int64
            } catch {
                logger.debug("Could not get file size for \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Extract chapters from asset
        let chapters = await extractChapters(from: asset)
        if !chapters.isEmpty && item.chapters.isEmpty {
            item.chapters = chapters
        }

        // Setup player
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.rate = Float(speed.rawValue)
        avPlayer.volume = volume

        // Clean up old observer
        if let oldObserver = timeObserver, let oldPlayer = player {
            oldPlayer.removeTimeObserver(oldObserver)
        }
        statusObserver?.invalidate()
        itemObserver?.invalidate()

        player = avPlayer
        currentItem = item
        duration = durationSeconds

        // Resume from last position if applicable
        if item.lastPosition > 5 && item.lastPosition < durationSeconds - 5 {
            await avPlayer.seek(to: CMTime(seconds: item.lastPosition, preferredTimescale: 600))
        }

        // Add periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = CMTimeGetSeconds(time)
                // Auto-save position every 10 seconds
                if Int(self.currentTime) % 10 == 0 {
                    self.savePosition()
                }
            }
        }

        // Observe playback end
        itemObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if item.status == .failed {
                    self.status = .failed
                }
            }
        }

        // Start playback
        avPlayer.play()
        status = .playing

        // Update history
        updateHistory(item)
    }

    /// Play the current item.
    func play() {
        guard let player else { return }
        player.play()
        player.rate = Float(speed.rawValue)
        status = .playing
    }

    /// Pause playback.
    func pause() {
        player?.pause()
        status = .paused
        savePosition()
    }

    /// Toggle play/pause.
    func togglePlayPause() {
        if status == .playing {
            pause()
        } else {
            play()
        }
    }

    /// Stop playback and save position.
    func stop() {
        savePosition()
        player?.pause()
        // periphery:ignore - Reserved: stop() instance method reserved for future feature activation
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        statusObserver?.invalidate()
        itemObserver?.invalidate()
        player = nil
        status = .stopped
    }

    /// Seek to a specific time.
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    /// Skip forward by seconds.
    func skipForward(_ seconds: TimeInterval = 10) {
        seek(to: min(currentTime + seconds, duration))
    }

    /// Skip backward by seconds.
    func skipBackward(_ seconds: TimeInterval = 10) {
        seek(to: max(currentTime - seconds, 0))
    }

    /// Set playback speed.
    func setSpeed(_ speed: PlaybackSpeed) {
        self.speed = speed
        if status == .playing {
            player?.rate = Float(speed.rawValue)
        }
    }

    /// Set volume (0.0 - 1.0).
    func setVolume(_ volume: Float) {
        self.volume = max(0, min(1, volume))
        player?.volume = self.volume
    }

    /// Toggle mute.
    func toggleMute() {
        if volume > 0 {
            player?.volume = 0
        } else {
            player?.volume = volume
        }
    }

    // MARK: - Bookmarks

    /// Add a bookmark at the current time.
    func addBookmark(label: String, note: String? = nil) {
        guard var item = currentItem else { return }
        let bookmark = MediaBookmark(timestamp: currentTime, label: label, note: note)
        item.bookmarks.append(bookmark)
        item.bookmarks.sort { $0.timestamp < $1.timestamp }
        currentItem = item
        updateHistory(item)
    }

    /// Remove a bookmark.
    func removeBookmark(id: UUID) {
        guard var item = currentItem else { return }
        item.bookmarks.removeAll { $0.id == id }
        currentItem = item
        updateHistory(item)
    }

    /// Jump to a bookmark.
    func jumpToBookmark(_ bookmark: MediaBookmark) {
        seek(to: bookmark.timestamp)
    }

    /// Jump to a chapter.
    func jumpToChapter(_ chapter: MediaChapter) {
        seek(to: chapter.startTime)
    }

    // MARK: - Favorites

    /// Toggle favorite on current item.
    func toggleFavorite() {
        guard var item = currentItem else { return }
        item.isFavorite.toggle()
        currentItem = item
        updateHistory(item)
    }

    /// Toggle favorite on a history item.
    func toggleFavorite(id: UUID) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        history[index].isFavorite.toggle()
        if currentItem?.id == id {
            currentItem?.isFavorite = history[index].isFavorite
        }
        saveHistory()
    }

    // MARK: - History

    /// Remove a history item.
    func removeFromHistory(id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }

    /// Clear all history.
    func clearHistory() {
        history.removeAll()
        // periphery:ignore - Reserved: clearHistory() instance method reserved for future feature activation
        saveHistory()
    }

    /// Get playback statistics.
    func getStats() -> MediaPlaybackStats {
        MediaPlaybackStats(
            totalItemsPlayed: history.count,
            totalPlayTime: history.reduce(0) { $0 + $1.lastPosition },
            videoCount: history.filter { $0.mediaType == .video }.count,
            audioCount: history.filter { $0.mediaType == .audio }.count,
            streamCount: history.filter { $0.mediaType == .stream }.count,
            favoriteCount: history.filter(\.isFavorite).count,
            bookmarkCount: history.reduce(0) { $0 + $1.bookmarks.count }
        )
    }

    /// Get recently played items.
    func recentlyPlayed(limit: Int = 10) -> [PlayedMediaItem] {
        // periphery:ignore - Reserved: recentlyPlayed(limit:) instance method reserved for future feature activation
        Array(history.sorted { $0.lastPlayedAt > $1.lastPlayedAt }.prefix(limit))
    }

    /// Get favorites.
    func favorites() -> [PlayedMediaItem] {
        history.filter(\.isFavorite).sorted { $0.lastPlayedAt > $1.lastPlayedAt }
    }

    /// Search history by title.
    func search(query: String) -> [PlayedMediaItem] {
        guard !query.isEmpty else { return history }
        let lowered = query.lowercased()
        return history.filter { $0.title.lowercased().contains(lowered) }
    }

    // MARK: - Chapter Extraction

    /// Extract chapters from AVAsset metadata.
    private func extractChapters(from asset: AVURLAsset) async -> [MediaChapter] {
        do {
            let languages = try await asset.load(.availableChapterLocales)
            guard let locale = languages.first else { return [] }
            let groups = try await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: [locale.identifier])
            var chapters: [MediaChapter] = []
            for group in groups {
                // Load title string using async API (stringValue deprecated in macOS 13+)
                let titleItems = group.items.filter { $0.commonKey == .commonKeyTitle }
                var title = "Chapter"
                for item in titleItems {
                    if let s = try? await item.load(.stringValue) {
                        title = s
                        break
                    }
                }
                let start = CMTimeGetSeconds(group.timeRange.start)
                let end = start + CMTimeGetSeconds(group.timeRange.duration)
                chapters.append(MediaChapter(title: title, startTime: start, endTime: end))
            }
            return chapters
        } catch {
            return []
        }
    }

    // MARK: - Helpers

    /// Infer media type from URL.
    private func inferMediaType(from url: URL) -> MediaPlaybackType {
        let ext = url.pathExtension.lowercased()
        let videoExtensions = Set(["mp4", "mov", "mkv", "avi", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "ts", "3gp"])
        let audioExtensions = Set(["mp3", "m4a", "aac", "wav", "flac", "ogg", "wma", "aiff", "alac", "opus"])

        if videoExtensions.contains(ext) { return .video }
        if audioExtensions.contains(ext) { return .audio }

        // Check URL scheme for streams
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "rtsp" || scheme == "rtmp" || scheme == "hls" { return .stream }
        if url.pathExtension == "m3u8" { return .stream }

        // Default to video for unknown
        return .video
    }

    /// Find existing history item or create new.
    private func findOrCreateHistoryItem(title: String, url: String, mediaType: MediaPlaybackType, duration: TimeInterval) -> PlayedMediaItem {
        if let existing = history.first(where: { $0.url == url }) {
            return existing
        }
        return PlayedMediaItem(title: title, url: url, mediaType: mediaType, duration: duration)
    }

    /// Update item in history.
    private func updateHistory(_ item: PlayedMediaItem) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            history[index] = item
        } else {
            history.insert(item, at: 0)
        }
        // Keep last 500 items
        if history.count > 500 {
            history = Array(history.prefix(500))
        }
        saveHistory()
    }

    /// Save current playback position.
    private func savePosition() {
        guard var item = currentItem else { return }
        item.lastPosition = currentTime
        currentItem = item
        updateHistory(item)
    }

    // MARK: - Persistence

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyFileURL)
            history = try JSONDecoder().decode([PlayedMediaItem].self, from: data)
        } catch {
            ErrorLogger.log(error, context: "MediaPlayer.loadHistory")
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            ErrorLogger.log(error, context: "MediaPlayer.saveHistory")
        }
    }

    // MARK: - Format Duration

    /// Format seconds into HH:MM:SS or MM:SS string.
    nonisolated static func formatDuration(_ seconds: TimeInterval) -> String {
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

    /// Get supported file extensions.
    // periphery:ignore - Reserved: supportedExtensions static property reserved for future feature activation
    nonisolated static var supportedExtensions: [String] {
        ["mp4", "mov", "mkv", "avi", "wmv", "flv", "webm", "m4v", "mpg", "mpeg",
         "mp3", "m4a", "aac", "wav", "flac", "ogg", "wma", "aiff", "opus",
         "m3u8", "ts"]
    }

    /// Get UTTypes for file picker.
    nonisolated static var supportedUTTypes: [UTType] {
        [.movie, .audio, .mpeg4Movie, .quickTimeMovie, .avi, .mpeg, .mp3, .wav, .aiff]
    }
}
