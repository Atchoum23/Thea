import Foundation

/// Service for visual timer (Pomodoro) management
public actor VisualTimerService: VisualTimerServiceProtocol {
    private var activeSession: PomodoroSession?
    private var sessionHistory: [PomodoroSession] = []

    public init() {}

    // MARK: - Session Management

    /// Starts a new Pomodoro session with the given type and optional custom duration.
    public func startPomodoro(
        type: PomodoroSession.SessionType,
        duration: Int? = nil,
        taskName: String? = nil
    ) async throws -> PomodoroSession {
        guard activeSession == nil else {
            throw CognitiveError.pomodoroSessionActive
        }

        let sessionDuration = duration ?? type.defaultDuration
        guard sessionDuration > 0 else {
            throw CognitiveError.invalidDuration
        }

        let session = PomodoroSession(
            startTime: Date(),
            targetMinutes: sessionDuration,
            type: type,
            taskName: taskName
        )

        activeSession = session
        return session
    }

    /// Ends the active Pomodoro session, recording whether it was completed.
    public func endPomodoro(completed: Bool) async throws -> PomodoroSession {
        guard var session = activeSession else {
            throw CognitiveError.taskBreakdownFailed("No active Pomodoro session")
        }

        let endTime = Date()
        session = PomodoroSession(
            id: session.id,
            startTime: session.startTime,
            endTime: endTime,
            targetMinutes: session.targetMinutes,
            type: session.type,
            completed: completed,
            taskName: session.taskName
        )

        sessionHistory.insert(session, at: 0)
        activeSession = nil

        return session
    }

    /// Returns the currently active Pomodoro session, if any.
    public func getActiveSession() async -> PomodoroSession? {
        activeSession
    }

    /// Returns the most recent Pomodoro sessions up to the given limit.
    public func getSessionHistory(limit: Int = 20) async -> [PomodoroSession] {
        Array(sessionHistory.prefix(limit))
    }

    // MARK: - Statistics

    /// Computes Pomodoro statistics (session count, completion rate, average length) for the given date range.
    public func getStatistics(for period: DateInterval) async -> PomodoroStats {
        let sessionsInPeriod = sessionHistory.filter { session in
            session.startTime >= period.start && session.startTime <= period.end
        }

        let totalSessions = sessionsInPeriod.count
        let completedSessions = sessionsInPeriod.filter(\.completed).count
        let totalMinutes = sessionsInPeriod.compactMap(\.actualMinutes).reduce(0, +)
        let averageLength = totalSessions > 0 ? totalMinutes / totalSessions : 0

        return PomodoroStats(
            totalSessions: totalSessions,
            completedSessions: completedSessions,
            totalMinutes: totalMinutes,
            completionRate: totalSessions > 0 ? Double(completedSessions) / Double(totalSessions) * 100 : 0,
            averageSessionLength: averageLength
        )
    }

    // MARK: - Helper Methods

    /// Returns Pomodoro statistics for today.
    public func getTodayStats() async -> PomodoroStats {
        await getStatistics(for: .today)
    }

    /// Returns Pomodoro statistics for the current week.
    public func getWeekStats() async -> PomodoroStats {
        await getStatistics(for: .thisWeek)
    }
}
