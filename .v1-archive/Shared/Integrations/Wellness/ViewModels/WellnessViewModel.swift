import Foundation
import SwiftUI

/// ViewModel for the Wellness Dashboard
@MainActor
@Observable
public final class WellnessViewModel {
    // MARK: - Published Properties

    public var currentPhase: CircadianPhase = .morning
    public var uiRecommendations: UIRecommendations?
    public var activeSession: FocusSession?
    public var sessionHistory: [FocusSession] = []
    public var sessionStats: SessionStats?
    public var isPlayingAudio = false
    public var currentAudio: AmbientAudio?
    public var audioVolume: Double = 0.5

    public var isLoading = false
    public var errorMessage: String?

    // MARK: - Private Properties

    private let circadianService: CircadianService
    private let focusService: FocusModeService

    // MARK: - Initialization

    public init(
        circadianService: CircadianService = CircadianService(),
        focusService: FocusModeService = FocusModeService()
    ) {
        self.circadianService = circadianService
        self.focusService = focusService
    }

    // MARK: - Circadian Methods

    /// Load current circadian phase and recommendations
    public func loadCircadianData() async {
        isLoading = true
        errorMessage = nil

        currentPhase = await circadianService.getCurrentPhase()
        uiRecommendations = await circadianService.getUIRecommendations()

        isLoading = false
    }

    /// Update circadian phase settings
    public func updatePhaseSettings() async {
        await circadianService.updatePhaseSettings()
        await loadCircadianData()
    }

    // MARK: - Focus Session Methods

    /// Start a focus session
    public func startFocusSession(mode: WellnessFocusMode, duration: Int? = nil) async {
        errorMessage = nil

        do {
            let sessionDuration = duration ?? mode.recommendedDuration
            activeSession = try await focusService.startSession(mode: mode, duration: sessionDuration)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// End the active focus session
    public func endFocusSession(completed: Bool) async {
        errorMessage = nil

        do {
            _ = try await focusService.endSession(completed: completed)
            activeSession = nil
            await loadSessionHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Load session history
    public func loadSessionHistory(limit: Int = 20) async {
        sessionHistory = await focusService.getSessionHistory(limit: limit)
    }

    /// Load session statistics
    public func loadSessionStats(for period: DateInterval = .lastDays(7)) async {
        sessionStats = await focusService.getSessionStats(for: period)
    }

    /// Refresh all data
    public func refreshData() async {
        await loadCircadianData()
        activeSession = await focusService.getActiveSession()
        await loadSessionHistory()
        await loadSessionStats()
    }

    // MARK: - Ambient Audio Methods

    /// Start playing ambient audio
    public func playAmbientAudio(_ audio: AmbientAudio) async {
        errorMessage = nil

        do {
            try await focusService.playAmbientAudio(audio, volume: audioVolume)
            isPlayingAudio = true
            currentAudio = audio
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stop ambient audio
    public func stopAmbientAudio() async {
        await focusService.stopAmbientAudio()
        isPlayingAudio = false
        currentAudio = nil
    }

    /// Update audio volume
    public func updateAudioVolume(_ volume: Double) async {
        audioVolume = volume
        if let audio = currentAudio {
            try? await focusService.playAmbientAudio(audio, volume: volume)
        }
    }

    // MARK: - Computed Properties

    /// Formatted elapsed time for active session
    public var sessionElapsedTime: String {
        guard let session = activeSession else { return "00:00" }
        let elapsed = Int(Date().timeIntervalSince(session.startDate) / 60)
        let hours = elapsed / 60
        let minutes = elapsed % 60
        if hours > 0 {
            return String(format: "%02d:%02d", hours, minutes)
        } else {
            return String(format: "%02d", minutes)
        }
    }

    /// Progress percentage for active session
    public var sessionProgress: Double {
        guard let session = activeSession else { return 0 }
        let elapsed = Date().timeIntervalSince(session.startDate) / 60
        return min(100, (elapsed / Double(session.targetDuration)) * 100)
    }

    /// Time remaining in active session
    public var sessionTimeRemaining: String {
        guard let session = activeSession else { return "" }
        let elapsed = Int(Date().timeIntervalSince(session.startDate) / 60)
        let remaining = max(0, session.targetDuration - elapsed)
        let hours = remaining / 60
        let minutes = remaining % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
