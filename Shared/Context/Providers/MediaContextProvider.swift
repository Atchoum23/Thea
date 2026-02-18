import Foundation
import MediaPlayer
import os.log

#if os(macOS)
    import AppKit
#endif

// MARK: - Media Context Provider

/// Provides context about currently playing media
public actor MediaContextProvider: ContextProvider {
    public let providerId = "media"
    public let displayName = "Now Playing"

    private let logger = Logger(subsystem: "app.thea", category: "MediaProvider")

    private var state: ContextProviderState = .idle
    private var continuation: AsyncStream<ContextUpdate>.Continuation?
    private var _updates: AsyncStream<ContextUpdate>?
    private var updateTask: Task<Void, Never>?

    #if os(macOS)
        private var observerHelper: MediaObserverHelper?
    #elseif os(iOS)
        private var observerHelper: IOSMediaObserverHelper?
    #endif

    public var isActive: Bool { state == .running }

    public var updates: AsyncStream<ContextUpdate> {
        if let existing = _updates {
            return existing
        }
        let (stream, cont) = AsyncStream<ContextUpdate>.makeStream()
        _updates = stream
        continuation = cont
        return stream
    }

    public init() {}

    public func start() async throws {
        guard state != .running else {
            throw ContextProviderError.alreadyRunning
        }

        state = .starting

        #if os(iOS)
            await setupIOSObservers()
        #elseif os(macOS)
            await setupMacOSObservers()
        #endif

        // Start periodic updates
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchMediaInfo()
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    break // Task cancelled — stop periodic updates
                }
            }
        }

        state = .running
        logger.info("Media provider started")
    }

    public func stop() async {
        guard state == .running else { return }

        state = .stopping
        updateTask?.cancel()
        updateTask = nil

        #if os(macOS)
            if let helper = observerHelper {
                await helper.teardown()
            }
            observerHelper = nil
        #elseif os(iOS)
            if let helper = observerHelper {
                await helper.teardown()
            }
            observerHelper = nil
        #endif

        continuation?.finish()
        continuation = nil
        _updates = nil

        state = .stopped
        logger.info("Media provider stopped")
    }

    public func getCurrentContext() async -> ContextUpdate? {
        let context = await buildMediaContext()
        return ContextUpdate(
            providerId: providerId,
            updateType: .media(context),
            priority: .low
        )
    }

    // MARK: - Private Methods

    #if os(iOS)
        private func setupIOSObservers() async {
            let helper = await MainActor.run {
                IOSMediaObserverHelper()
            }
            observerHelper = helper

            await helper.setup { [weak self] in
                Task {
                    await self?.fetchMediaInfo()
                }
            }
        }
    #endif

    #if os(macOS)
        private func setupMacOSObservers() async {
            let helper = await MainActor.run {
                MediaObserverHelper()
            }
            observerHelper = helper

            await helper.setup { [weak self] in
                Task {
                    await self?.fetchMediaInfo()
                }
            }
        }
    #endif

    private func fetchMediaInfo() async {
        let context = await buildMediaContext()

        let update = ContextUpdate(
            providerId: providerId,
            updateType: .media(context),
            priority: context.isPlaying ? .normal : .low
        )
        continuation?.yield(update)
    }

    private func buildMediaContext() async -> MediaContext {
        #if os(iOS)
            return await buildIOSMediaContext()
        #elseif os(macOS)
            return await buildMacOSMediaContext()
        #else
            return MediaContext()
        #endif
    }

    #if os(iOS)
        private func buildIOSMediaContext() async -> MediaContext {
            await MainActor.run {
                let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo

                guard let info = nowPlayingInfo else {
                    return MediaContext(isPlaying: false)
                }

                let isPlaying = MPNowPlayingInfoCenter.default().playbackState == .playing

                return MediaContext(
                    isPlaying: isPlaying,
                    nowPlayingTitle: info[MPMediaItemPropertyTitle] as? String,
                    nowPlayingArtist: info[MPMediaItemPropertyArtist] as? String,
                    nowPlayingAlbum: info[MPMediaItemPropertyAlbumTitle] as? String,
                    nowPlayingApp: nil, // Would need private API
                    playbackPosition: info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval,
                    duration: info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval
                )
            }
        }
    #endif

    #if os(macOS)
        private func buildMacOSMediaContext() async -> MediaContext {
            await MainActor.run {
                // Check if Music app is playing via AppleScript
                if let info = getMusicAppInfo() {
                    return MediaContext(
                        isPlaying: info.isPlaying,
                        nowPlayingTitle: info.title,
                        nowPlayingArtist: info.artist,
                        nowPlayingAlbum: info.album,
                        nowPlayingApp: "Music",
                        playbackPosition: info.position,
                        duration: info.duration
                    )
                }

                // Check for Spotify
                if let info = getSpotifyInfo() {
                    return MediaContext(
                        isPlaying: info.isPlaying,
                        nowPlayingTitle: info.title,
                        nowPlayingArtist: info.artist,
                        nowPlayingAlbum: info.album,
                        nowPlayingApp: "Spotify",
                        playbackPosition: info.position,
                        duration: info.duration
                    )
                }

                return MediaContext(isPlaying: false)
            }
        }
    #endif
}

// MARK: - Media Info Structure

#if os(macOS)
    private struct MediaInfo {
        let isPlaying: Bool
        let title: String?
        let artist: String?
        let album: String?
        let position: TimeInterval?
        let duration: TimeInterval?
    }

    @MainActor
    private func getMusicAppInfo() -> MediaInfo? {
        // Check if Music is running
        let musicApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == "com.apple.Music"
        }
        guard !musicApps.isEmpty else { return nil }

        // Use AppleScript to get info
        let script = """
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackPosition to player position
                set trackDuration to duration of current track
                return {true, trackName, trackArtist, trackAlbum, trackPosition, trackDuration}
            else
                return {false, "", "", "", 0, 0}
            end if
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if error == nil, result.numberOfItems >= 6 {
                let isPlaying = result.atIndex(1)?.booleanValue ?? false
                let title = result.atIndex(2)?.stringValue
                let artist = result.atIndex(3)?.stringValue
                let album = result.atIndex(4)?.stringValue
                let position = result.atIndex(5)?.doubleValue
                let duration = result.atIndex(6)?.doubleValue

                return MediaInfo(
                    isPlaying: isPlaying,
                    title: title,
                    artist: artist,
                    album: album,
                    position: position,
                    duration: duration
                )
            }
        }

        return nil
    }

    @MainActor
    private func getSpotifyInfo() -> MediaInfo? {
        // Check if Spotify is running
        let spotifyApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == "com.spotify.client"
        }
        guard !spotifyApps.isEmpty else { return nil }

        let script = """
        tell application "Spotify"
            if player state is playing then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackPosition to player position
                set trackDuration to duration of current track
                return {true, trackName, trackArtist, trackAlbum, trackPosition, trackDuration / 1000}
            else
                return {false, "", "", "", 0, 0}
            end if
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if error == nil, result.numberOfItems >= 6 {
                let isPlaying = result.atIndex(1)?.booleanValue ?? false
                let title = result.atIndex(2)?.stringValue
                let artist = result.atIndex(3)?.stringValue
                let album = result.atIndex(4)?.stringValue
                let position = result.atIndex(5)?.doubleValue
                let duration = result.atIndex(6)?.doubleValue

                return MediaInfo(
                    isPlaying: isPlaying,
                    title: title,
                    artist: artist,
                    album: album,
                    position: position,
                    duration: duration
                )
            }
        }

        return nil
    }

    // MARK: - macOS Media Observer Helper

    @MainActor
    private final class MediaObserverHelper {
        private var observer: NSObjectProtocol?

        nonisolated init() {}

        func setup(onChange: @escaping @Sendable () -> Void) {
            let center = DistributedNotificationCenter.default()
            observer = center.addObserver(
                forName: NSNotification.Name("com.apple.Music.playerInfo"),
                object: nil,
                queue: .main
            ) { _ in
                onChange()
            }
        }

        func teardown() {
            if let obs = observer {
                DistributedNotificationCenter.default().removeObserver(obs)
                observer = nil
            }
        }
    }
#endif

#if os(iOS)
    import UIKit

    // MARK: - iOS Media Observer Helper

    @MainActor
    private final class IOSMediaObserverHelper {
        private var observer: NSObjectProtocol?

        nonisolated init() {}

        func setup(onChange: @escaping @Sendable () -> Void) {
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                onChange()
            }
        }

        func teardown() {
            if let obs = observer {
                NotificationCenter.default.removeObserver(obs)
                observer = nil
            }
        }
    }
#endif
