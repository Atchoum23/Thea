//
//  MediaMonitor.swift
//  Thea
//
//  Media playback monitoring for life tracking
//  Tracks music and video streaming across platforms:
//  - Apple Music, YouTube Music, Spotify
//  - YouTube, Rumble, Netflix, and other streaming services
//

import Combine
import Foundation
import os.log
#if os(macOS)
    import AppKit
#endif
#if canImport(MediaPlayer)
    import MediaPlayer
#endif

// MARK: - Media Monitor

/// Monitors media playback across music and video streaming services
/// Emits LifeEvents for playback start, pause, track changes
@MainActor
public class MediaMonitor: ObservableObject {
    public static let shared = MediaMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "MediaMonitor")

    @Published public private(set) var isRunning = false
    @Published public private(set) var currentlyPlaying: MediaItem?
    @Published public private(set) var playbackState: MediaPlaybackState = .stopped
    @Published public private(set) var activeService: MediaService?

    private var cancellables = Set<AnyCancellable>()
    private var pollingTask: Task<Void, Never>?
    private var sessionHistory: [MediaSession] = []
    private var currentSession: MediaSession?

    // Track last known state to detect changes
    private var lastKnownTrack: String?
    private var lastKnownService: MediaService?
    private init() {}

    // MARK: - Lifecycle

    /// Start monitoring media playback
    public func start() async {
        guard !isRunning else { return }

        isRunning = true
        logger.info("Media monitor started")

        // Setup platform-specific monitoring
        #if os(iOS)
            setupMPNowPlayingInfoCenter()
        #endif

        // Start polling for playback state changes
        startPolling()
    }

    /// Stop monitoring
    public func stop() async {
        guard isRunning else { return }

        isRunning = false
        pollingTask?.cancel()
        pollingTask = nil

        // End current session if active
        if let session = currentSession {
            await endSession(session)
        }

        logger.info("Media monitor stopped")
    }

    // MARK: - iOS Now Playing Center

    #if os(iOS)
        private func setupMPNowPlayingInfoCenter() {
            // Subscribe to now playing info changes using raw notification names
            // to ensure compatibility across iOS versions
            NotificationCenter.default.publisher(for: Notification.Name.MPMusicPlayerControllerNowPlayingItemDidChange)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        await self?.checkNowPlayingInfo()
                    }
                }
                .store(in: &cancellables)

            NotificationCenter.default.publisher(for: Notification.Name.MPMusicPlayerControllerPlaybackStateDidChange)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        await self?.checkNowPlayingInfo()
                    }
                }
                .store(in: &cancellables)
        }

        private func checkNowPlayingInfo() async {
            let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo

            guard let info = nowPlayingInfo else {
                if playbackState != .stopped {
                    await handlePlaybackStopped()
                }
                return
            }

            let title = info[MPMediaItemPropertyTitle] as? String ?? "Unknown"
            let artist = info[MPMediaItemPropertyArtist] as? String
            let album = info[MPMediaItemPropertyAlbumTitle] as? String
            let duration = info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval ?? 0

            let item = MediaItem(
                id: "\(title)-\(artist ?? "")",
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                service: .appleMusic,
                mediaType: .music,
                url: nil
            )

            await handleMediaChange(item)
        }
    #endif

    // MARK: - Polling (macOS / Cross-platform)

    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                await pollMediaPlaybackState()
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds
            }
        }
    }

    private func pollMediaPlaybackState() async {
        #if os(macOS)
            // Check running media apps and their playback state
            await checkMacOSMediaApps()
        #endif
    }

    #if os(macOS)
        private func checkMacOSMediaApps() async {
            let runningApps = NSWorkspace.shared.runningApplications

            // Check for media apps in priority order
            let mediaApps: [(bundle: String, service: MediaService)] = [
                ("com.apple.Music", .appleMusic),
                ("com.spotify.client", .spotify),
                ("com.apple.TV", .appleTV),
                ("com.google.Chrome", .browser), // For YouTube, Rumble, Netflix
                ("org.mozilla.firefox", .browser),
                ("com.apple.Safari", .browser),
                ("com.microsoft.edgemac", .browser)
            ]

            for (bundleId, service) in mediaApps {
                if let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }) {
                    // For browsers, we rely on the browser extension to report playback
                    // For native apps, we check if they're playing via AppleScript
                    if service != .browser {
                        await checkNativeAppPlayback(app: app, service: service)
                    }
                }
            }
        }

        private func checkNativeAppPlayback(app _app: NSRunningApplication, service: MediaService) async {
            // Use AppleScript to check playback state
            let appName: String
            switch service {
            case .appleMusic:
                appName = "Music"
            case .spotify:
                appName = "Spotify"
            case .appleTV:
                appName = "TV"
            default:
                return
            }

            // Get player state via AppleScript
            let script = """
            tell application "\(appName)"
                try
                    if player state is playing then
                        set trackName to name of current track
                        set trackArtist to artist of current track
                        set trackAlbum to album of current track
                        set trackDuration to duration of current track
                        return "playing|" & trackName & "|" & trackArtist & "|" & trackAlbum & "|" & trackDuration
                    else if player state is paused then
                        return "paused"
                    else
                        return "stopped"
                    end if
                on error
                    return "error"
                end try
            end tell
            """

            guard let appleScript = NSAppleScript(source: script) else { return }

            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)

            if let errorDict = error {
                logger.debug("AppleScript error for \(appName): \(errorDict)")
                return
            }

            guard let output = result.stringValue else { return }

            if output.hasPrefix("playing|") {
                let parts = output.components(separatedBy: "|")
                if parts.count >= 5 {
                    let item = MediaItem(
                        id: "\(parts[1])-\(parts[2])",
                        title: parts[1],
                        artist: parts[2],
                        album: parts[3],
                        duration: TimeInterval(parts[4]) ?? 0,
                        service: service,
                        mediaType: .music,
                        url: nil
                    )

                    await handleMediaChange(item)
                    playbackState = .playing
                    activeService = service
                }
            } else if output == "paused" {
                if activeService == service && playbackState == .playing {
                    await handlePlaybackPaused()
                }
            } else if output == "stopped" {
                if activeService == service && playbackState != .stopped {
                    await handlePlaybackStopped()
                }
            }
        }
    #endif

    // MARK: - Browser Extension Integration

    /// Called from browser extension when video/music playback is detected
    public func reportBrowserPlayback(_ playback: BrowserMediaPlayback) {
        let service = detectService(from: playback.url)
        let mediaType = detectMediaType(from: playback)

        let item = MediaItem(
            id: playback.url,
            title: playback.title,
            artist: playback.channelName,
            album: nil,
            duration: playback.duration,
            service: service,
            mediaType: mediaType,
            url: playback.url
        )

        Task { @MainActor in
            switch playback.state {
            case .playing:
                await handleMediaChange(item)
            case .paused:
                await handlePlaybackPaused()
            case .ended:
                await handlePlaybackStopped()
            }
        }
    }

    private func detectService(from url: String) -> MediaService {
        let lowercased = url.lowercased()

        if lowercased.contains("youtube.com") || lowercased.contains("youtu.be") {
            if lowercased.contains("music.youtube") {
                return .youtubeMusic
            }
            return .youtube
        } else if lowercased.contains("rumble.com") {
            return .rumble
        } else if lowercased.contains("netflix.com") {
            return .netflix
        } else if lowercased.contains("spotify.com") {
            return .spotifyWeb
        } else if lowercased.contains("apple.com/music") || lowercased.contains("music.apple.com") {
            return .appleMusicWeb
        } else if lowercased.contains("soundcloud.com") {
            return .soundcloud
        } else if lowercased.contains("twitch.tv") {
            return .twitch
        } else if lowercased.contains("vimeo.com") {
            return .vimeo
        } else if lowercased.contains("dailymotion.com") {
            return .dailymotion
        } else if lowercased.contains("primevideo") || lowercased.contains("amazon.com/video") {
            return .primeVideo
        } else if lowercased.contains("disneyplus.com") {
            return .disneyPlus
        } else if lowercased.contains("hulu.com") {
            return .hulu
        } else if lowercased.contains("hbomax.com") || lowercased.contains("max.com") {
            return .hboMax
        } else if lowercased.contains("peacock") {
            return .peacock
        } else if lowercased.contains("paramountplus") {
            return .paramountPlus
        }

        return .unknown
    }

    private func detectMediaType(from playback: BrowserMediaPlayback) -> MediaType {
        // Check if it's explicitly audio
        if playback.isAudioOnly {
            return .music
        }

        // Check service
        let service = detectService(from: playback.url)
        switch service {
        case .youtubeMusic, .spotify, .spotifyWeb, .appleMusic, .appleMusicWeb, .soundcloud:
            return .music
        case .youtube, .rumble, .netflix, .primeVideo, .disneyPlus, .hulu, .hboMax, .peacock, .paramountPlus, .twitch, .vimeo, .dailymotion, .appleTV:
            return .video
        default:
            // Heuristic: if duration > 10 minutes, likely video
            return playback.duration > 600 ? .video : .music
        }
    }

    // MARK: - State Change Handling

    private func handleMediaChange(_ item: MediaItem) async {
        let trackId = "\(item.title)-\(item.artist ?? "")"

        // Check if this is a new track
        if trackId != lastKnownTrack || item.service != lastKnownService {
            // End previous session
            if let session = currentSession {
                await endSession(session)
            }

            // Start new session
            currentSession = MediaSession(item: item, startTime: Date())

            // Emit track change event
            await emitMediaEvent(item, action: .started)

            lastKnownTrack = trackId
            lastKnownService = item.service
        }

        currentlyPlaying = item
        playbackState = .playing
        activeService = item.service
    }

    private func handlePlaybackPaused() async {
        guard playbackState == .playing else { return }

        playbackState = .paused

        if let item = currentlyPlaying {
            await emitMediaEvent(item, action: .paused)
        }

        // Update session
        currentSession?.addPause()
    }

    private func handlePlaybackStopped() async {
        guard playbackState != .stopped else { return }

        let previousItem = currentlyPlaying

        playbackState = .stopped
        currentlyPlaying = nil
        activeService = nil
        lastKnownTrack = nil

        if let item = previousItem {
            await emitMediaEvent(item, action: .stopped)
        }

        // End session
        if let session = currentSession {
            await endSession(session)
            currentSession = nil
        }
    }

    private func endSession(_ session: MediaSession) async {
        var completedSession = session
        completedSession.endTime = Date()

        // Add to history
        sessionHistory.append(completedSession)
        if sessionHistory.count > 100 {
            sessionHistory.removeFirst()
        }

        // Emit session summary if significant
        let duration = completedSession.duration
        if duration > 30 { // More than 30 seconds
            await emitSessionSummary(completedSession)
        }
    }

    // MARK: - Event Emission

    private func emitMediaEvent(_ item: MediaItem, action: MediaAction) async {
        let eventType: LifeEventType
        let significance: EventSignificance

        switch action {
        case .started:
            eventType = item.mediaType == .music ? .musicPlaying : .videoPlaying
            significance = .minor
        case .paused:
            eventType = item.mediaType == .music ? .musicPaused : .videoPaused
            significance = .trivial
        case .stopped:
            eventType = item.mediaType == .music ? .musicStopped : .videoStopped
            significance = .trivial
        }

        let summary: String
        switch action {
        case .started:
            if let artist = item.artist {
                summary = "Playing: \(item.title) by \(artist)"
            } else {
                summary = "Playing: \(item.title)"
            }
        case .paused:
            summary = "Paused: \(item.title)"
        case .stopped:
            summary = "Stopped: \(item.title)"
        }

        var eventData: [String: String] = [
            "title": item.title,
            "service": item.service.rawValue,
            "mediaType": item.mediaType.rawValue,
            "action": action.rawValue
        ]

        if let artist = item.artist {
            eventData["artist"] = artist
        }

        if let album = item.album {
            eventData["album"] = album
        }

        if item.duration > 0 {
            eventData["duration"] = String(format: "%.0f", item.duration)
        }

        if let url = item.url {
            eventData["url"] = url
        }

        let lifeEvent = LifeEvent(
            type: eventType,
            source: .media,
            summary: summary,
            data: eventData,
            significance: significance
        )

        LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
        logger.info("Media \(action.rawValue): \(item.title) on \(item.service.rawValue)")
    }

    private func emitSessionSummary(_ session: MediaSession) async {
        let eventType: LifeEventType = session.item.mediaType == .music ? .musicSessionEnded : .videoSessionEnded

        let durationMinutes = Int(session.duration / 60)
        let summary = "Watched/listened to \(session.item.title) for \(durationMinutes) minutes"

        var eventData: [String: String] = [
            "title": session.item.title,
            "service": session.item.service.rawValue,
            "mediaType": session.item.mediaType.rawValue,
            "durationSeconds": String(format: "%.0f", session.duration),
            "pauseCount": String(session.pauseCount)
        ]

        if let artist = session.item.artist {
            eventData["artist"] = artist
        }

        let lifeEvent = LifeEvent(
            type: eventType,
            source: .media,
            summary: summary,
            data: eventData,
            significance: session.duration > 300 ? .moderate : .minor // > 5 min is more significant
        )

        await MainActor.run {
            LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
        }
    }

    // MARK: - Query Methods

    /// Get recent media sessions
    public func getRecentSessions(limit: Int = 10) -> [MediaSession] {
        Array(sessionHistory.suffix(limit))
    }

    /// Get listening/watching statistics
    public func getStatistics(for period: StatisticsPeriod = .today) -> MediaStatistics {
        let now = Date()
        let startDate: Date

        switch period {
        case .today:
            startDate = Calendar.current.startOfDay(for: now)
        case .thisWeek:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        case .thisMonth:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        }

        let relevantSessions = sessionHistory.filter { $0.startTime >= startDate }

        let totalMusicTime = relevantSessions
            .filter { $0.item.mediaType == .music }
            .map(\.duration)
            .reduce(0, +)

        let totalVideoTime = relevantSessions
            .filter { $0.item.mediaType == .video }
            .map(\.duration)
            .reduce(0, +)

        // Count by service
        var timeByService: [MediaService: TimeInterval] = [:]
        for session in relevantSessions {
            timeByService[session.item.service, default: 0] += session.duration
        }

        // Most played
        var countByTitle: [String: Int] = [:]
        for session in relevantSessions {
            countByTitle[session.item.title, default: 0] += 1
        }
        let mostPlayed = countByTitle.max { $0.value < $1.value }?.key

        return MediaStatistics(
            totalMusicTime: totalMusicTime,
            totalVideoTime: totalVideoTime,
            sessionCount: relevantSessions.count,
            timeByService: timeByService,
            mostPlayedItem: mostPlayed
        )
    }

    public enum StatisticsPeriod {
        case today
        case thisWeek
        case thisMonth
    }
}

// MARK: - Supporting Types

public struct MediaItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let artist: String?
    public let album: String?
    public let duration: TimeInterval
    public let service: MediaService
    public let mediaType: MediaType
    public let url: String?
}

public enum MediaService: String, Sendable, CaseIterable {
    case appleMusic = "apple_music"
    case appleMusicWeb = "apple_music_web"
    case appleTV = "apple_tv"
    case spotify = "spotify"
    case spotifyWeb = "spotify_web"
    case youtube = "youtube"
    case youtubeMusic = "youtube_music"
    case rumble = "rumble"
    case netflix = "netflix"
    case primeVideo = "prime_video"
    case disneyPlus = "disney_plus"
    case hulu = "hulu"
    case hboMax = "hbo_max"
    case peacock = "peacock"
    case paramountPlus = "paramount_plus"
    case twitch = "twitch"
    case vimeo = "vimeo"
    case dailymotion = "dailymotion"
    case soundcloud = "soundcloud"
    case browser = "browser"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .appleMusic, .appleMusicWeb: return "Apple Music"
        case .appleTV: return "Apple TV"
        case .spotify, .spotifyWeb: return "Spotify"
        case .youtube: return "YouTube"
        case .youtubeMusic: return "YouTube Music"
        case .rumble: return "Rumble"
        case .netflix: return "Netflix"
        case .primeVideo: return "Prime Video"
        case .disneyPlus: return "Disney+"
        case .hulu: return "Hulu"
        case .hboMax: return "Max"
        case .peacock: return "Peacock"
        case .paramountPlus: return "Paramount+"
        case .twitch: return "Twitch"
        case .vimeo: return "Vimeo"
        case .dailymotion: return "Dailymotion"
        case .soundcloud: return "SoundCloud"
        case .browser: return "Browser"
        case .unknown: return "Unknown"
        }
    }

    public var isMusic: Bool {
        switch self {
        case .appleMusic, .appleMusicWeb, .spotify, .spotifyWeb, .youtubeMusic, .soundcloud:
            return true
        default:
            return false
        }
    }

    public var isVideo: Bool {
        switch self {
        case .youtube, .rumble, .netflix, .primeVideo, .disneyPlus, .hulu, .hboMax, .peacock, .paramountPlus, .twitch, .vimeo, .dailymotion, .appleTV:
            return true
        default:
            return false
        }
    }
}

public enum MediaType: String, Sendable {
    case music
    case video
    case podcast
    case audiobook
    case livestream
}

public enum MediaPlaybackState: String, Sendable {
    case playing
    case paused
    case stopped
    case buffering
}

private enum MediaAction: String {
    case started
    case paused
    case stopped
}

public struct MediaSession: Identifiable, Sendable {
    public let id = UUID()
    public let item: MediaItem
    public let startTime: Date
    public var endTime: Date?
    public private(set) var pauseCount: Int = 0

    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    mutating func addPause() {
        pauseCount += 1
    }
}

public struct MediaStatistics: Sendable {
    public let totalMusicTime: TimeInterval
    public let totalVideoTime: TimeInterval
    public let sessionCount: Int
    public let timeByService: [MediaService: TimeInterval]
    public let mostPlayedItem: String?

    public var totalTime: TimeInterval {
        totalMusicTime + totalVideoTime
    }
}

/// Playback info from browser extension
public struct BrowserMediaPlayback: Sendable {
    public let url: String
    public let title: String
    public let channelName: String?
    public let duration: TimeInterval
    public let currentTime: TimeInterval
    public let state: BrowserMediaPlaybackState
    public let isAudioOnly: Bool

    public enum BrowserMediaPlaybackState: String, Sendable {
        case playing
        case paused
        case ended
    }

    public init(
        url: String,
        title: String,
        channelName: String? = nil,
        duration: TimeInterval,
        currentTime: TimeInterval,
        state: BrowserMediaPlaybackState,
        isAudioOnly: Bool = false
    ) {
        self.url = url
        self.title = title
        self.channelName = channelName
        self.duration = duration
        self.currentTime = currentTime
        self.state = state
        self.isAudioOnly = isAudioOnly
    }
}

// MARK: - LifeEventType & DataSourceType
// Note: LifeEventType cases (music*, video*) and DataSourceType.media
// are defined in LifeMonitoringCoordinator.swift
