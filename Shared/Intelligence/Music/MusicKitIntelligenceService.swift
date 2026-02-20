// MusicKitIntelligenceService.swift
// Thea — AAH3: MusicKit Intelligence Service
//
// Fetches recently played tracks and listening patterns via MusicKit.
// Provides music context for PersonalParameters.snapshot() so Claude
// knows what Thea is listening to, enabling mood-aware responses.
//
// Wiring: After each successful fetch, sets
//   PersonalParameters.shared.musicContextSummary
// so snapshot() includes the music section automatically.
//
// Authorization: MusicAuthorization.request() — user must grant access.
// Platform: macOS 12+ / iOS 15+ (not tvOS). watchOS has limited MusicKit.

import Foundation
import OSLog

#if !os(tvOS)
    import MusicKit
#endif

// MARK: - MusicKitIntelligenceService

/// Fetches listening history via MusicKit to provide music context for intelligence.
/// Wired into PersonalParameters.snapshot() via musicContextSummary property.
@MainActor
public final class MusicKitIntelligenceService: ObservableObject {
    public static let shared = MusicKitIntelligenceService()

    private let logger = Logger(subsystem: "ai.thea.app", category: "MusicKitIntelligence")

    // MARK: - Published State

    @Published public private(set) var authorizationStatus: MusicAuthStatus = .notDetermined
    @Published public private(set) var recentTracks: [MusicKitTrackInfo] = []
    @Published public private(set) var topGenres: [String] = []
    @Published public private(set) var currentMood: MusicMood = .unknown
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastFetchDate: Date?

    // MARK: - Configuration

    /// Maximum recently played tracks to fetch.
    public var trackLimit: Int = 25

    /// Minimum genre occurrence count to appear in topGenres.
    public var genreMinOccurrences: Int = 2

    // MARK: - Init

    private init() {
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Authorization

    /// Refreshes the stored authorization status without prompting.
    public func refreshAuthorizationStatus() async {
        #if !os(tvOS)
            authorizationStatus = MusicAuthStatus(from: MusicAuthorization.currentStatus)
        #else
            authorizationStatus = .denied
        #endif
    }

    /// Requests MusicKit authorization from the user.
    /// - Returns: The resulting authorization status.
    @discardableResult
    public func requestAuthorization() async -> MusicAuthStatus {
        #if !os(tvOS)
            let status = await MusicAuthorization.request()
            authorizationStatus = MusicAuthStatus(from: status)
            return authorizationStatus
        #else
            authorizationStatus = .denied
            return .denied
        #endif
    }

    // MARK: - Data Fetching

    /// Fetches recent tracks, derives genres and mood, then updates PersonalParameters.
    public func fetchRecentTracks() async {
        guard authorizationStatus == .authorized else {
            logger.info("MusicKit not authorized — skipping fetch (status: \(self.authorizationStatus.rawValue))")
            return
        }
        guard !isLoading else { return }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            #if !os(tvOS)
                let tracks = try await loadRecentlyPlayed()
                recentTracks = tracks
                topGenres = deriveTopGenres(from: tracks)
                currentMood = inferMood(from: tracks)
                lastFetchDate = .now

                // Music context available via MusicKitIntelligenceService.shared.buildContextSummary()
                // (PersonalParameters.snapshot() reads it from MusicKitIntelligenceService directly)
                logger.info("MusicKit fetch complete — \(tracks.count) tracks, mood=\(self.currentMood.rawValue)")
            #endif
        } catch {
            lastError = error.localizedDescription
            logger.error("MusicKit fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private: MusicKit Queries

    #if !os(tvOS)
        private func loadRecentlyPlayed() async throws -> [MusicKitTrackInfo] {
            var request = MusicRecentlyPlayedRequest<Song>()
            request.limit = trackLimit
            let response = try await request.response()
            return response.items.map { song in
                MusicKitTrackInfo(
                    id: song.id.rawValue,
                    title: song.title,
                    artistName: song.artistName,
                    albumTitle: song.albumTitle ?? "",
                    genreNames: song.genreNames,
                    durationSeconds: song.duration.map { Int($0) },
                    releaseDate: song.releaseDate,
                    isExplicit: song.contentRating == .explicit
                )
            }
        }
    #endif

    // MARK: - Private: Analysis

    private func deriveTopGenres(from tracks: [MusicKitTrackInfo]) -> [String] {
        var counts: [String: Int] = [:]
        for track in tracks {
            for genre in track.genreNames {
                counts[genre, default: 0] += 1
            }
        }
        return counts
            .filter { $0.value >= genreMinOccurrences }
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }

    private func inferMood(from tracks: [MusicKitTrackInfo]) -> MusicMood {
        guard !tracks.isEmpty else { return .unknown }

        // Heuristic: infer mood from genre mix
        let genres = Set(tracks.flatMap { $0.genreNames }.map { $0.lowercased() })

        let energeticKeywords = ["electronic", "rock", "hip-hop", "dance", "pop", "edm", "metal"]
        let calmKeywords = ["classical", "ambient", "jazz", "acoustic", "folk", "meditation"]
        let focusKeywords = ["instrumental", "soundtrack", "lo-fi", "study", "concentration"]

        let energeticScore = genres.filter { g in energeticKeywords.contains(where: { g.contains($0) }) }.count
        let calmScore = genres.filter { g in calmKeywords.contains(where: { g.contains($0) }) }.count
        let focusScore = genres.filter { g in focusKeywords.contains(where: { g.contains($0) }) }.count

        let maxScore = max(energeticScore, calmScore, focusScore)
        guard maxScore > 0 else { return .mixed }

        if focusScore == maxScore { return .focused }
        if calmScore == maxScore { return .relaxed }
        if energeticScore == maxScore { return .energized }
        return .mixed
    }

    /// Returns a compact music context string suitable for injection into PersonalParameters.snapshot().
    public func buildContextSummary() -> String {
        guard !recentTracks.isEmpty else { return "" }
        let topArtists = Array(
            Set(recentTracks.prefix(10).map { $0.artistName })
        ).prefix(3).joined(separator: ", ")
        let genreList = topGenres.prefix(3).joined(separator: ", ")
        return "mood=\(currentMood.rawValue) artists=[\(topArtists)] genres=[\(genreList)] tracks=\(recentTracks.count)"
    }
}

// MARK: - Model Types

/// Lightweight track descriptor (MusicKit Song without full framework dependency).
public struct MusicKitTrackInfo: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let artistName: String
    public let albumTitle: String
    public let genreNames: [String]
    public let durationSeconds: Int?
    public let releaseDate: Date?
    public let isExplicit: Bool
}

public enum MusicMood: String, Sendable {
    case energized
    case relaxed
    case focused
    case mixed
    case unknown
}

public enum MusicAuthStatus: String, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined

    #if !os(tvOS)
        init(from status: MusicAuthorization.Status) {
            switch status {
            case .authorized: self = .authorized
            case .denied: self = .denied
            case .restricted: self = .restricted
            case .notDetermined: self = .notDetermined
            @unknown default: self = .notDetermined
            }
        }
    #endif
}
