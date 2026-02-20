// ShazamKitService.swift
// Thea — AAD3-1: Ambient Audio Intelligence
//
// SHManagedSession-based song recognition via ShazamKit.
// Wire in: AmbientIntelligenceEngine.startAudioAnalysis() → ShazamKitService.shared.startListening()
// Platform: iOS 15+ / macOS 12+ (#if canImport(ShazamKit) guard)

import Foundation
import os.log

private let logger = Logger(subsystem: "app.thea", category: "ShazamKitService")

// MARK: - ShazamKit Match Result

// periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
struct ShazamMatch: Sendable {
    let title: String
    let artist: String
    let album: String?
    let appleMusicURL: URL?
    let artworkURL: URL?
    let isrc: String?
    let recognizedAt: Date
}

// MARK: - ShazamKitService

#if canImport(ShazamKit)
import ShazamKit

// periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
/// Singleton service for real-time song recognition using SHManagedSession.
/// Uses SHManagedSession (iOS 16+/macOS 13+) which handles audio capture internally.
/// Falls back to nil on older OS versions.
@MainActor
final class ShazamKitService: NSObject, ObservableObject {

    static let shared = ShazamKitService()

    // MARK: - Published State

    @Published var isListening: Bool = false
    @Published var lastMatch: ShazamMatch?
    @Published var errorMessage: String?

    // MARK: - Private

    private var session: SHManagedSession?
    private var recognitionTask: Task<Void, Never>?

    override private init() {
        super.init()
        if #available(iOS 16.0, macOS 13.0, *) {
            session = SHManagedSession()
        }
        logger.info("ShazamKitService initialized")
    }

    // MARK: - Recognition

    /// Start listening for a song. Captures audio internally via SHManagedSession.
    func startListening() {
        guard !isListening else { return }

        if #available(iOS 16.0, macOS 13.0, *) {
            guard let session else {
                logger.warning("ShazamKitService: SHManagedSession unavailable")
                return
            }
            isListening = true
            errorMessage = nil

            recognitionTask?.cancel()
            recognitionTask = Task { [weak self, weak session] in
                guard let self, let session else { return }
                // SHManagedSession.result() returns async (non-throwing) in ShazamKit 26+
                // Error cases are surfaced as SHSession.Result.error(error, signature)
                let result = await session.result()
                self.handleResult(result)
            }
        } else {
            logger.warning("ShazamKitService: SHManagedSession requires iOS 16+ or macOS 13+")
        }
    }

    /// Stop any in-progress recognition session.
    func stopListening() {
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        logger.info("ShazamKitService: stopped listening")
    }

    // MARK: - Result Handling

    @available(iOS 16.0, macOS 13.0, *)
    private func handleResult(_ result: SHSession.Result) {
        isListening = false
        switch result {
        case .match(let match):
            guard let mediaItem = match.mediaItems.first else {
                logger.info("ShazamKitService: match with no media items")
                return
            }
            let shazamMatch = ShazamMatch(
                title: mediaItem.title ?? "Unknown",
                artist: mediaItem.artist ?? "Unknown",
                album: mediaItem.subtitle,  // SHMatchedMediaItem.subtitle is album title
                appleMusicURL: mediaItem.appleMusicURL,
                artworkURL: mediaItem.artworkURL,
                isrc: mediaItem.isrc,
                recognizedAt: Date()
            )
            lastMatch = shazamMatch
            logger.info("ShazamKitService: matched '\(shazamMatch.title)' by \(shazamMatch.artist)")

        case .noMatch:
            logger.info("ShazamKitService: no match found")
            errorMessage = "No match found for the current audio."

        case .error(let error, _):
            errorMessage = error.localizedDescription
            logger.error("ShazamKitService: session error: \(error.localizedDescription)")
        @unknown default:
            logger.warning("ShazamKitService: unknown result type")
        }
    }

    // MARK: - Context Summary

    /// Returns a summary of the last recognized song for AI context injection.
    func contextSummary() -> String? {
        guard let match = lastMatch else { return nil }
        return "Now playing: '\(match.title)' by \(match.artist)\(match.album.map { " from \($0)" } ?? "")."
    }
}

#else

// MARK: - Fallback Stub (ShazamKit not available)

@MainActor
final class ShazamKitService: ObservableObject {
    static let shared = ShazamKitService()

    @Published var isListening: Bool = false
    @Published var lastMatch: ShazamMatch?
    @Published var errorMessage: String?

    private init() {
        logger.info("ShazamKitService stub: ShazamKit not available on this platform")
    }

    func startListening() {
        logger.info("ShazamKitService stub: startListening() — ShazamKit unavailable")
    }

    func stopListening() {}

    func contextSummary() -> String? { nil }
}

#endif
