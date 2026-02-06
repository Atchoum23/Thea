import Foundation

// MARK: - Task Breakdown Service Protocol

/// Protocol for AI-powered task breakdown
public protocol TaskBreakdownServiceProtocol: Actor {
    /// Break down a complex task into subtasks
    func breakdownTask(_ task: String) async throws -> TaskBreakdown

    /// Get breakdown history
    func getBreakdownHistory(limit: Int) async -> [TaskBreakdown]

    /// Mark subtask as completed
    func completeSubtask(breakdownId: UUID, subtaskId: UUID) async throws
}

// MARK: - Visual Timer Service Protocol

/// Protocol for visual timer management
public protocol VisualTimerServiceProtocol: Actor {
    /// Start a Pomodoro session
    func startPomodoro(type: PomodoroSession.SessionType, duration: Int?, taskName: String?) async throws -> PomodoroSession

    /// End active Pomodoro session
    func endPomodoro(completed: Bool) async throws -> PomodoroSession

    /// Get active session
    func getActiveSession() async -> PomodoroSession?

    /// Get session history
    func getSessionHistory(limit: Int) async -> [PomodoroSession]

    /// Get statistics for period
    func getStatistics(for period: DateInterval) async -> PomodoroStats
}

/// Pomodoro statistics
public struct PomodoroStats: Sendable, Codable {
    public let totalSessions: Int
    public let completedSessions: Int
    public let totalMinutes: Int
    public let completionRate: Double
    public let averageSessionLength: Int

    public init(
        totalSessions: Int,
        completedSessions: Int,
        totalMinutes: Int,
        completionRate: Double,
        averageSessionLength: Int
    ) {
        self.totalSessions = totalSessions
        self.completedSessions = completedSessions
        self.totalMinutes = totalMinutes
        self.completionRate = completionRate
        self.averageSessionLength = averageSessionLength
    }
}

// MARK: - Focus Forest Service Protocol

/// Protocol for focus forest gamification
public protocol FocusForestServiceProtocol: Actor {
    /// Plant a new tree
    func plantTree(type: FocusTree.TreeType) async throws -> FocusTree

    /// Update tree growth based on focus time
    func updateTreeGrowth(minutes: Int) async throws

    /// Kill current tree (interrupted focus)
    func killCurrentTree() async throws

    /// Get current forest
    func getForest() async -> FocusForest

    /// Get forest statistics
    func getForestStats() async -> ForestStats
}

/// Forest statistics
public struct ForestStats: Sendable, Codable {
    public let totalTrees: Int
    public let totalMinutesFocused: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let favoriteTreeType: FocusTree.TreeType?

    public init(
        totalTrees: Int,
        totalMinutesFocused: Int,
        currentStreak: Int,
        longestStreak: Int,
        favoriteTreeType: FocusTree.TreeType?
    ) {
        self.totalTrees = totalTrees
        self.totalMinutesFocused = totalMinutesFocused
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.favoriteTreeType = favoriteTreeType
    }
}

// MARK: - CBT Lessons Service Protocol

/// Protocol for CBT micro-lessons
public protocol CBTLessonsServiceProtocol: Actor {
    /// Get all available lessons
    func getAllLessons() async -> [CBTLesson]

    /// Get lessons by category
    func getLessons(category: CBTLesson.Category) async -> [CBTLesson]

    /// Get recommended lesson based on user patterns
    func getRecommendedLesson() async -> CBTLesson?

    /// Mark lesson as completed
    func completeLesson(_ lessonId: UUID) async

    /// Get completion history
    func getCompletionHistory() async -> [UUID]
}
