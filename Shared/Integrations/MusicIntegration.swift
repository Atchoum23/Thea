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
public actor MusicIntegration: IntegrationModule {
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
        throw IntegrationModuleError.notSupported
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
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Next track
    public func nextTrack() async throws {
        #if os(macOS)
        let script = "tell application \"Music\" to next track"
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Previous track
    public func previousTrack() async throws {
        #if os(macOS)
        let script = "tell application \"Music\" to previous track"
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Get current track info
    public func getCurrentTrack() async throws -> MusicTrackInfo? {
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

        return MusicTrackInfo(
            name: parts[0],
            artist: parts[1],
            album: parts[2],
            duration: Double(parts[3]) ?? 0
        )
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Set volume (0-100)
    public func setVolume(_ volume: Int) async throws {
        #if os(macOS)
        let clampedVolume = max(0, min(100, volume))
        let script = "tell application \"Music\" to set sound volume to \(clampedVolume)"
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
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
        throw IntegrationModuleError.notSupported
        #endif
    }

    #if os(macOS)
    private func executeAppleScript(_ source: String) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let script = NSAppleScript(source: source) {
                    let result = script.executeAndReturnError(&error)
                    if let error = error {
                        continuation.resume(throwing: IntegrationModuleError.scriptError(error.description))
                    } else {
                        continuation.resume(returning: result.stringValue)
                    }
                } else {
                    continuation.resume(throwing: IntegrationModuleError.scriptError("Failed to create script"))
                }
            }
        }
    }
    #endif
}

public struct MusicTrackInfo: Sendable {
    public let name: String
    public let artist: String
    public let album: String
    public let duration: Double

    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
