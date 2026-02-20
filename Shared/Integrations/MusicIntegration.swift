//
//  MusicIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
#endif

// MARK: - Music Integration

/// Integration module for Music app
public actor MusicIntegration: AppIntegrationModule {
    public static let shared = MusicIntegration()

    public let moduleId = "music"
    public let displayName = "Music"
    public let bundleIdentifier = "com.apple.Music"
    public let icon = "music.note"

    private var isConnected = false

    private init() {}

    public func connect() async throws {
        #if os(macOS)
            isConnected = true
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    public func disconnect() async { isConnected = false }

    public func isAvailable() async -> Bool {
        #if os(macOS)
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
        #else
            return false
        #endif
    }

    /// Play/pause
    public func playPause() async throws {
        #if os(macOS)
            let script = "tell application \"Music\" to playpause"
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Next track
    public func nextTrack() async throws {
        #if os(macOS)
            let script = "tell application \"Music\" to next track"
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Previous track
    public func previousTrack() async throws {
        #if os(macOS)
            let script = "tell application \"Music\" to previous track"
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Get current track info
    public func getCurrentTrack() async throws -> MusicKitTrackInfo? {
        #if os(macOS)
            let script = """
            tell application "Music"
                if player state is playing then
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set trackDuration to duration of current track
                    return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration
                end if
            end tell
            """
            guard let result = try await executeAppleScript(script) else { return nil }
            let parts = result.components(separatedBy: "|||")
            guard parts.count >= 4 else { return nil }

            let durationSecs = Int(Double(parts[3]) ?? 0)
            return MusicKitTrackInfo(
                id: "\(parts[0])-\(parts[1])",
                title: parts[0],
                artistName: parts[1],
                albumTitle: parts[2],
                genreNames: [],
                durationSeconds: durationSecs > 0 ? durationSecs : nil,
                releaseDate: nil,
                isExplicit: false
            )
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Set volume (0-100)
    public func setVolume(_ volume: Int) async throws {
        #if os(macOS)
            let clampedVolume = max(0, min(100, volume))
            let script = "tell application \"Music\" to set sound volume to \(clampedVolume)"
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Search and play
    public func searchAndPlay(_ query: String) async throws {
        #if os(macOS)
            let script = """
            tell application "Music"
                activate
                set results to search playlist "Library" for "\(query)"
                if (count of results) > 0 then
                    play item 1 of results
                end if
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    #if os(macOS)
        private func executeAppleScript(_ source: String) async throws -> String? {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    var error: NSDictionary?
                    if let script = NSAppleScript(source: source) {
                        let result = script.executeAndReturnError(&error)
                        if let error {
                            continuation.resume(throwing: AppIntegrationModuleError.scriptError(error.description))
                        } else {
                            continuation.resume(returning: result.stringValue)
                        }
                    } else {
                        continuation.resume(throwing: AppIntegrationModuleError.scriptError("Failed to create script"))
                    }
                }
            }
        }
    #endif
}

// MusicKitTrackInfo is defined in Shared/Intelligence/Music/MusicKitIntelligenceService.swift (canonical).
// Use MusicKitIntelligenceService.MusicKitTrackInfo from that file.
