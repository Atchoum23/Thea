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

    public func startSession(mode: FocusMode, duration: Int) async throws -> FocusSession {
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

    public func getActiveSession() async -> FocusSession? {
        activeSession
    }

    public func getSessionHistory(limit: Int = 20) async -> [FocusSession] {
        Array(sessionHistory.prefix(limit))
    }

    // MARK: - Ambient Audio

    public func playAmbientAudio(_ audio: AmbientAudio, volume _: Double) async throws {
        await stopAmbientAudio()

        // Note: In a real implementation, we would load audio files from bundle
        // For now, this is a placeholder that demonstrates the structure
        currentAudio = audio
        await notifyAudioChange(isPlaying: true, audio: audio)

        // Placeholder for actual audio playback
        // In production, load and play audio file:
        // guard let url = Bundle.main.url(forResource: audio.rawValue, withExtension: "mp3") else {
        //     throw WellnessError.audioPlaybackFailed("Audio file not found")
        // }
        // audioPlayer = try AVAudioPlayer(contentsOf: url)
        // audioPlayer?.volume = Float(volume)
        // audioPlayer?.numberOfLoops = -1
        // audioPlayer?.play()
    }

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

    public func addObserver(_ observer: WellnessObserver) {
        observers.append(WeakObserver(observer))
        cleanupObservers()
    }

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
    public let modeBreakdown: [FocusMode: Int]

    public init(
        totalSessions: Int,
        completedSessions: Int,
        totalMinutes: Int,
        completionRate: Double,
        modeBreakdown: [FocusMode: Int]
    ) {
        self.totalSessions = totalSessions
        self.completedSessions = completedSessions
        self.totalMinutes = totalMinutes
        self.completionRate = completionRate
        self.modeBreakdown = modeBreakdown
    }
}
