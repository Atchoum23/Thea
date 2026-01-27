//
//  MediaObserver.swift
//  Thea
//
//  Created by Thea
//

#if os(macOS)
    import Foundation
    import MediaPlayer
    import os.log

    /// Observes media playback state on macOS
    /// Uses MediaRemote private framework for Now Playing information
    @MainActor
    public final class MediaObserver {
        public static let shared = MediaObserver()

        private let logger = Logger(subsystem: "app.thea.media", category: "MediaObserver")

        // Callbacks
        public var onNowPlayingChanged: ((NowPlayingInfo?) -> Void)?
        public var onPlaybackStateChanged: ((PlaybackState) -> Void)?

        // Current state
        public private(set) var currentNowPlaying: NowPlayingInfo?
        public private(set) var currentPlaybackState: PlaybackState = .unknown

        // Distributed notification observers
        private var nowPlayingObserver: NSObjectProtocol?
        private var playbackStateObserver: NSObjectProtocol?

        private init() {}

        // MARK: - Lifecycle

        public func start() {
            // Listen for now playing changes via distributed notifications
            let center = DistributedNotificationCenter.default()

            nowPlayingObserver = center.addObserver(
                forName: NSNotification.Name("com.apple.Music.playerInfo"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                // Extract values into Sendable types before capturing
                let userInfo = notification.userInfo
                let title = userInfo?["Name"] as? String
                let artist = userInfo?["Artist"] as? String
                let album = userInfo?["Album"] as? String
                let duration = userInfo?["Total Time"] as? TimeInterval
                let elapsedTime = userInfo?["Player Position"] as? TimeInterval
                let playerState = userInfo?["Player State"] as? String

                Task { @MainActor in
                    self?.handleMusicNotificationValues(
                        title: title,
                        artist: artist,
                        album: album,
                        duration: duration,
                        elapsedTime: elapsedTime,
                        playerState: playerState
                    )
                }
            }

            // Also try to get current state
            fetchCurrentNowPlaying()

            logger.info("Media observer started")
        }

        public func stop() {
            if let observer = nowPlayingObserver {
                DistributedNotificationCenter.default().removeObserver(observer)
            }
            if let observer = playbackStateObserver {
                DistributedNotificationCenter.default().removeObserver(observer)
            }

            logger.info("Media observer stopped")
        }

        // MARK: - Notification Handling

        private func handleMusicNotificationValues(
            title: String?,
            artist: String?,
            album: String?,
            duration: TimeInterval?,
            elapsedTime: TimeInterval?,
            playerState: String?
        ) {
            let info = NowPlayingInfo(
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                elapsedTime: elapsedTime,
                artworkData: nil,
                appBundleIdentifier: "com.apple.Music",
                appName: "Music"
            )

            let state: PlaybackState = if let playState = playerState {
                switch playState.lowercased() {
                case "playing":
                    .playing
                case "paused":
                    .paused
                case "stopped":
                    .stopped
                default:
                    .unknown
                }
            } else {
                .unknown
            }

            updateState(nowPlaying: info, playbackState: state)
        }

        private func updateState(nowPlaying: NowPlayingInfo?, playbackState: PlaybackState) {
            let nowPlayingChanged = currentNowPlaying != nowPlaying
            let stateChanged = currentPlaybackState != playbackState

            currentNowPlaying = nowPlaying
            currentPlaybackState = playbackState

            if nowPlayingChanged {
                logger.info("Now playing: \(nowPlaying?.title ?? "Nothing")")
                onNowPlayingChanged?(nowPlaying)
            }

            if stateChanged {
                logger.info("Playback state: \(playbackState.rawValue)")
                onPlaybackStateChanged?(playbackState)
            }
        }

        // MARK: - Manual Fetch

        /// Attempt to fetch current now playing info
        /// This uses AppleScript as a fallback since MediaRemote is private
        public func fetchCurrentNowPlaying() {
            Task {
                // Try to get info from Music app
                let script = """
                tell application "System Events"
                    if exists process "Music" then
                        tell application "Music"
                            if player state is playing then
                                set trackName to name of current track
                                set artistName to artist of current track
                                set albumName to album of current track
                                return trackName & "|" & artistName & "|" & albumName
                            end if
                        end tell
                    end if
                end tell
                return ""
                """

                if let result = await runAppleScript(script), !result.isEmpty {
                    let parts = result.components(separatedBy: "|")
                    if parts.count >= 3 {
                        let info = NowPlayingInfo(
                            title: parts[0],
                            artist: parts[1],
                            album: parts[2],
                            duration: nil,
                            elapsedTime: nil,
                            artworkData: nil,
                            appBundleIdentifier: "com.apple.Music",
                            appName: "Music"
                        )
                        updateState(nowPlaying: info, playbackState: .playing)
                    }
                }
            }
        }

        private func runAppleScript(_ source: String) async -> String? {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    var error: NSDictionary?
                    let script = NSAppleScript(source: source)
                    let result = script?.executeAndReturnError(&error)

                    if let error {
                        self.logger.error("AppleScript error: \(error)")
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: result?.stringValue)
                    }
                }
            }
        }
    }

    // MARK: - Models

    public struct NowPlayingInfo: Equatable, Sendable {
        public let title: String?
        public let artist: String?
        public let album: String?
        public let duration: TimeInterval?
        public let elapsedTime: TimeInterval?
        public let artworkData: Data?
        public let appBundleIdentifier: String?
        public let appName: String?

        public var displayTitle: String {
            if let title, let artist {
                "\(title) – \(artist)"
            } else if let title {
                title
            } else {
                "Unknown"
            }
        }
    }

    public enum PlaybackState: String, Sendable {
        case unknown = "Unknown"
        case playing = "Playing"
        case paused = "Paused"
        case stopped = "Stopped"
    }
#endif
