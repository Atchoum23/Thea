import AVFoundation
import Foundation

/// Service for managing focus modes and sessions
public actor FocusModeService: FocusModeServiceProtocol {
    private var activeSession: FocusSession?
    private var sessionHistory: [FocusSession] = []
    private var observers: [WeakObserver] = []
    private var audioPlayer: AVAudioPlayer?
    private var currentAudio: AmbientAudio?

    public init() {}

    // MARK: - Session Management

    /// Starts a new focus session with the given mode and duration in minutes.
    public func startSession(mode: WellnessFocusMode, duration: Int) async throws -> FocusSession {
        guard activeSession == nil else {
            throw WellnessError.sessionAlreadyActive
        }

        guard duration > 0 else {
            throw WellnessError.invalidDuration
        }

        let session = FocusSession(
            mode: mode,
            startDate: Date(),
            targetDuration: duration
        )

        activeSession = session
        await notifySessionStart(session)

        return session
    }

    /// Ends the active focus session, recording whether it was completed or interrupted.
    public func endSession(completed: Bool) async throws -> FocusSession {
        guard var session = activeSession else {
            throw WellnessError.sessionNotFound
        }

        let endDate = Date()
        session = FocusSession(
            id: session.id,
            mode: session.mode,
            startDate: session.startDate,
            endDate: endDate,
            targetDuration: session.targetDuration,
            completed: completed,
            interrupted: !completed,
            notes: session.notes
        )

        sessionHistory.insert(session, at: 0)
        activeSession = nil

        await notifySessionEnd(session)

        return session
    }

    /// Returns the currently active focus session, if any.
    public func getActiveSession() async -> FocusSession? {
        activeSession
    }

    /// Returns the most recent focus sessions up to the given limit.
    public func getSessionHistory(limit: Int = 20) async -> [FocusSession] {
        Array(sessionHistory.prefix(limit))
    }

    // MARK: - Ambient Audio

    /// Starts looping playback of the specified ambient audio at the given volume (0.0-1.0).
    public func playAmbientAudio(_ audio: AmbientAudio, volume: Double) async throws {
        await stopAmbientAudio()

        currentAudio = audio
        await notifyAudioChange(isPlaying: true, audio: audio)

        guard let url = Bundle.main.url(forResource: audio.rawValue, withExtension: "mp3")
                ?? Bundle.main.url(forResource: audio.rawValue, withExtension: "m4a")
                ?? Bundle.main.url(forResource: audio.rawValue, withExtension: "wav") else {
            // Audio file not bundled — track the state but skip playback
            return
        }

        let player = try AVAudioPlayer(contentsOf: url)
        player.volume = Float(volume)
        player.numberOfLoops = -1
        player.play()
        audioPlayer = player
    }

    /// Stops any currently playing ambient audio.
    public func stopAmbientAudio() async {
        audioPlayer?.stop()
        audioPlayer = nil
        let previousAudio = currentAudio
        currentAudio = nil

        if previousAudio != nil {
            await notifyAudioChange(isPlaying: false, audio: nil)
        }
    }

    // MARK: - Statistics

    /// Computes session statistics (count, completion rate, total minutes) for the given date range.
    public func getSessionStats(for period: DateInterval) async -> SessionStats {
        let sessionsInPeriod = sessionHistory.filter { session in
            session.startDate >= period.start && session.startDate <= period.end
        }

        let totalSessions = sessionsInPeriod.count
        let completedSessions = sessionsInPeriod.filter(\.completed).count
        let totalMinutes = sessionsInPeriod.compactMap(\.actualDuration).reduce(0, +)

        let modeBreakdown = Dictionary(grouping: sessionsInPeriod, by: \.mode).mapValues { $0.count }

        return SessionStats(
            totalSessions: totalSessions,
            completedSessions: completedSessions,
            totalMinutes: totalMinutes,
            completionRate: totalSessions > 0 ? Double(completedSessions) / Double(totalSessions) * 100 : 0,
            modeBreakdown: modeBreakdown
        )
    }

    // MARK: - Observer Management

    /// Registers an observer for focus session and ambient audio change notifications.
    public func addObserver(_ observer: WellnessObserver) {
        observers.append(WeakObserver(observer))
        cleanupObservers()
    }

    /// Removes a previously registered observer.
    public func removeObserver(_ observer: WellnessObserver) {
        observers.removeAll { $0.value === observer }
    }

    private func cleanupObservers() {
        observers.removeAll { $0.value == nil }
    }

    private func notifySessionStart(_ session: FocusSession) async {
        cleanupObservers()
        for weakObserver in observers {
            weakObserver.value?.focusSessionDidStart(session)
        }
    }

    private func notifySessionEnd(_ session: FocusSession) async {
        cleanupObservers()
        for weakObserver in observers {
            weakObserver.value?.focusSessionDidEnd(session)
        }
    }

    private func notifyAudioChange(isPlaying: Bool, audio: AmbientAudio?) async {
        cleanupObservers()
        for weakObserver in observers {
            weakObserver.value?.ambientAudioDidChange(isPlaying: isPlaying, audio: audio)
        }
    }

    // MARK: - Helper Types

    private struct WeakObserver {
        weak var value: WellnessObserver?

        init(_ value: WellnessObserver) {
            self.value = value
        }
    }
}

// MARK: - Session Statistics

/// Statistics for focus sessions
public struct SessionStats: Sendable, Codable {
    public let totalSessions: Int
    public let completedSessions: Int
    public let totalMinutes: Int
    public let completionRate: Double
    public let modeBreakdown: [WellnessFocusMode: Int]

    public init(
        totalSessions: Int,
        completedSessions: Int,
        totalMinutes: Int,
        completionRate: Double,
        modeBreakdown: [WellnessFocusMode: Int]
    ) {
        self.totalSessions = totalSessions
        self.completedSessions = completedSessions
        self.totalMinutes = totalMinutes
        self.completionRate = completionRate
        self.modeBreakdown = modeBreakdown
    }
}
