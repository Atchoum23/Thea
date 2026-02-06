import Foundation
import SwiftUI

/// ViewModel for the Cognitive/ADHD Dashboard
@MainActor
@Observable
public final class CognitiveDashboardViewModel {
    // MARK: - Published Properties

    // Task Breakdown
    public var currentBreakdown: TaskBreakdown?
    public var breakdownHistory: [TaskBreakdown] = []
    public var taskInput = ""

    // Pomodoro Timer
    public var activePomodoro: PomodoroSession?
    public var pomodoroHistory: [PomodoroSession] = []
    public var pomodoroStats: PomodoroStats?

    // Focus Forest
    public var forest: FocusForest?
    public var currentTree: FocusTree?
    public var forestStats: ForestStats?
    public var selectedTreeType: FocusTree.TreeType = .oak

    // Timeline
    public var timelineEvents: [TimelineEvent] = []

    // State
    public var isLoading = false
    public var errorMessage: String?
    public var selectedTab = 0

    // MARK: - Private Properties

    private let taskBreakdownService: TaskBreakdownService
    private let timerService: VisualTimerService
    private let forestService: FocusForestService

    // MARK: - Initialization

    public init(
        taskBreakdownService: TaskBreakdownService = TaskBreakdownService(),
        timerService: VisualTimerService = VisualTimerService(),
        forestService: FocusForestService = FocusForestService()
    ) {
        self.taskBreakdownService = taskBreakdownService
        self.timerService = timerService
        self.forestService = forestService
    }

    // MARK: - Task Breakdown Methods

    public func breakdownTask() async {
        guard !taskInput.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            currentBreakdown = try await taskBreakdownService.breakdownTask(taskInput)
            await loadBreakdownHistory()
            taskInput = ""
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func loadBreakdownHistory() async {
        breakdownHistory = await taskBreakdownService.getBreakdownHistory(limit: 10)
    }

    public func completeSubtask(breakdownId: UUID, subtaskId: UUID) async {
        do {
            try await taskBreakdownService.completeSubtask(breakdownId: breakdownId, subtaskId: subtaskId)
            await loadBreakdownHistory()

            // Update current breakdown if it matches
            if currentBreakdown?.id == breakdownId {
                currentBreakdown = breakdownHistory.first { $0.id == breakdownId }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Pomodoro Methods

    public func startPomodoro(type: PomodoroSession.SessionType, taskName: String? = nil) async {
        errorMessage = nil

        do {
            activePomodoro = try await timerService.startPomodoro(type: type, duration: nil, taskName: taskName)

            // If starting work session with a tree type selected, plant tree
            if type == .work {
                do {
                    _ = try await forestService.plantTree(type: selectedTreeType)
                } catch {
                    // Tree planting failed, but we can continue with the session
                    print("Failed to plant tree: \(error)")
                }
                currentTree = await forestService.getCurrentTree()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func endPomodoro(completed: Bool) async {
        errorMessage = nil

        do {
            let session = try await timerService.endPomodoro(completed: completed)
            activePomodoro = nil

            // Update forest if work session
            if session.type == .work, let minutes = session.actualMinutes {
                if completed {
                    try? await forestService.updateTreeGrowth(minutes: minutes)
                } else {
                    try? await forestService.killCurrentTree()
                }
            }

            await loadPomodoroData()
            await loadForestData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadPomodoroData() async {
        activePomodoro = await timerService.getActiveSession()
        pomodoroHistory = await timerService.getSessionHistory(limit: 10)
        pomodoroStats = await timerService.getTodayStats()
    }

    // MARK: - Focus Forest Methods

    public func loadForestData() async {
        forest = await forestService.getForest()
        currentTree = await forestService.getCurrentTree()
        forestStats = await forestService.getForestStats()
    }

    public func plantTree(type: FocusTree.TreeType) async {
        errorMessage = nil

        do {
            currentTree = try await forestService.plantTree(type: type)
            selectedTreeType = type
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Timeline Methods

    public func loadTimelineEvents() async {
        // Generate timeline events for today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Create sample events (in production, these would come from calendar integration)
        timelineEvents = [
            TimelineEvent(
                title: "Morning Focus",
                startTime: calendar.date(byAdding: .hour, value: 9, to: today) ?? today.addingTimeInterval(9 * 3600),
                endTime: calendar.date(byAdding: .hour, value: 11, to: today) ?? today.addingTimeInterval(11 * 3600),
                category: .focus
            ),
            TimelineEvent(
                title: "Team Meeting",
                startTime: calendar.date(byAdding: .hour, value: 11, to: today) ?? today.addingTimeInterval(11 * 3600),
                endTime: calendar.date(byAdding: .hour, value: 12, to: today) ?? today.addingTimeInterval(12 * 3600),
                category: .meeting
            ),
            TimelineEvent(
                title: "Lunch Break",
                startTime: calendar.date(byAdding: .hour, value: 12, to: today) ?? today.addingTimeInterval(12 * 3600),
                endTime: calendar.date(byAdding: .hour, value: 13, to: today) ?? today.addingTimeInterval(13 * 3600),
                category: .breakTime
            ),
            TimelineEvent(
                title: "Deep Work",
                startTime: calendar.date(byAdding: .hour, value: 14, to: today) ?? today.addingTimeInterval(14 * 3600),
                endTime: calendar.date(byAdding: .hour, value: 17, to: today) ?? today.addingTimeInterval(17 * 3600),
                category: .work
            )
        ]
    }

    // MARK: - Refresh All Data

    public func refreshData() async {
        isLoading = true

        await loadBreakdownHistory()
        await loadPomodoroData()
        await loadForestData()
        await loadTimelineEvents()

        isLoading = false
    }

    // MARK: - Computed Properties

    public var pomodoroElapsedTime: String {
        guard let session = activePomodoro else { return "00:00" }
        let elapsed = Int(Date().timeIntervalSince(session.startTime) / 60)
        let minutes = elapsed % 60
        let seconds = Int(Date().timeIntervalSince(session.startTime)) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var pomodoroProgress: Double {
        guard let session = activePomodoro else { return 0 }
        let elapsed = Date().timeIntervalSince(session.startTime) / 60
        return min(100, (elapsed / Double(session.targetMinutes)) * 100)
    }

    public var pomodoroTimeRemaining: String {
        guard let session = activePomodoro else { return "" }
        let elapsed = Int(Date().timeIntervalSince(session.startTime) / 60)
        let remaining = max(0, session.targetMinutes - elapsed)
        return "\(remaining)m"
    }

    public var treeGrowthProgress: Double {
        currentTree?.growthProgress ?? 0
    }

    public var completedSubtasksCount: Int {
        currentBreakdown?.subtasks.filter(\.completed).count ?? 0
    }

    public var totalSubtasksCount: Int {
        currentBreakdown?.subtasks.count ?? 0
    }

    public var breakdownProgress: Double {
        guard let breakdown = currentBreakdown, !breakdown.subtasks.isEmpty else { return 0 }
        return (Double(completedSubtasksCount) / Double(totalSubtasksCount)) * 100
    }
}
