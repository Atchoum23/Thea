import Foundation

// MARK: - Circadian Service Protocol

/// Protocol for circadian rhythm management
public protocol CircadianServiceProtocol: Actor {
    /// Get current circadian phase
    func getCurrentPhase() async -> CircadianPhase

    /// Get recommended UI adjustments for current phase
    func getUIRecommendations() async -> UIRecommendations

    /// Update phase-based settings
    func updatePhaseSettings() async
}

/// UI recommendations based on circadian phase
public struct UIRecommendations: Sendable, Codable {
    public let brightness: Double
    public let blueFilterIntensity: Double
    public let suggestedTheme: Theme
    public let phase: CircadianPhase

    public init(
        brightness: Double,
        blueFilterIntensity: Double,
        suggestedTheme: Theme,
        phase: CircadianPhase
    ) {
        self.brightness = brightness
        self.blueFilterIntensity = blueFilterIntensity
        self.suggestedTheme = suggestedTheme
        self.phase = phase
    }

    public enum Theme: String, Sendable, Codable {
        case light
        case dark
        case auto

        public var displayName: String {
            switch self {
            case .light: "Light"
            case .dark: "Dark"
            case .auto: "Auto"
            }
        }
    }
}

// MARK: - Focus Mode Service Protocol

/// Protocol for focus mode management
public protocol FocusModeServiceProtocol: Actor {
    /// Start a focus session
    func startSession(mode: FocusMode, duration: Int) async throws -> FocusSession

    /// End the active session
    func endSession(completed: Bool) async throws -> FocusSession

    /// Get active session
    func getActiveSession() async -> FocusSession?

    /// Get session history
    func getSessionHistory(limit: Int) async -> [FocusSession]

    /// Play ambient audio
    func playAmbientAudio(_ audio: AmbientAudio, volume: Double) async throws

    /// Stop ambient audio
    func stopAmbientAudio() async
}

// MARK: - Wellness Observer Protocol

/// Protocol for observing wellness data changes
public protocol WellnessObserver: AnyObject {
    /// Called when circadian phase changes
    func circadianPhaseDidChange(to phase: CircadianPhase)

    /// Called when focus session starts
    func focusSessionDidStart(_ session: FocusSession)

    /// Called when focus session ends
    func focusSessionDidEnd(_ session: FocusSession)

    /// Called when ambient audio state changes
    func ambientAudioDidChange(isPlaying: Bool, audio: AmbientAudio?)
}
