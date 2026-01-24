import Foundation

// MARK: - Task Breakdown

/// AI-generated task breakdown
public struct TaskBreakdown: Sendable, Codable, Identifiable {
    public let id: UUID
    public let originalTask: String
    public let subtasks: [CognitiveSubtask]
    public let estimatedTotalMinutes: Int
    public let difficulty: Difficulty
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        originalTask: String,
        subtasks: [CognitiveSubtask],
        estimatedTotalMinutes: Int,
        difficulty: Difficulty,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.originalTask = originalTask
        self.subtasks = subtasks
        self.estimatedTotalMinutes = estimatedTotalMinutes
        self.difficulty = difficulty
        self.createdAt = createdAt
    }

    public enum Difficulty: String, Sendable, Codable {
        case easy
        case moderate
        case challenging
        case expert

        public var displayName: String {
            switch self {
            case .easy: return "Easy"
            case .moderate: return "Moderate"
            case .challenging: return "Challenging"
            case .expert: return "Expert"
            }
        }

        public var color: String {
            switch self {
            case .easy: return "#10B981"      // Green
            case .moderate: return "#F59E0B"  // Amber
            case .challenging: return "#F97316" // Orange
            case .expert: return "#EF4444"    // Red
            }
        }
    }
}

/// Individual subtask within a breakdown
public struct CognitiveSubtask: Sendable, Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let estimatedMinutes: Int
    public let order: Int
    public var completed: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        estimatedMinutes: Int,
        order: Int,
        completed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.estimatedMinutes = estimatedMinutes
        self.order = order
        self.completed = completed
    }
}

// MARK: - Visual Timeline

/// Timeline event for visual scheduling
public struct TimelineEvent: Sendable, Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let startTime: Date
    public let endTime: Date
    public let category: EventCategory
    public let color: String
    public let isCompleted: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        startTime: Date,
        endTime: Date,
        category: EventCategory,
        color: String? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.category = category
        self.color = color ?? category.defaultColor
        self.isCompleted = isCompleted
    }

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public var durationMinutes: Int {
        Int(duration / 60)
    }

    public enum EventCategory: String, Sendable, Codable {
        case work
        case personal
        case breakTime
        case meeting
        case focus
        case exercise

        public var displayName: String {
            switch self {
            case .work: return "Work"
            case .personal: return "Personal"
            case .breakTime: return "Break"
            case .meeting: return "Meeting"
            case .focus: return "Focus"
            case .exercise: return "Exercise"
            }
        }

        public var defaultColor: String {
            switch self {
            case .work: return "#3B82F6"      // Blue
            case .personal: return "#8B5CF6"  // Purple
            case .breakTime: return "#10B981"     // Green
            case .meeting: return "#F59E0B"   // Amber
            case .focus: return "#EF4444"     // Red
            case .exercise: return "#EC4899"  // Pink
            }
        }
    }
}

// MARK: - Pomodoro Timer

/// Pomodoro timer session
public struct PomodoroSession: Sendable, Codable, Identifiable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date?
    public let targetMinutes: Int
    public let type: SessionType
    public let completed: Bool
    public let taskName: String?

    public init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        targetMinutes: Int,
        type: SessionType,
        completed: Bool = false,
        taskName: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.targetMinutes = targetMinutes
        self.type = type
        self.completed = completed
        self.taskName = taskName
    }

    public var isActive: Bool {
        endTime == nil
    }

    public var actualMinutes: Int? {
        guard let endTime = endTime else { return nil }
        return Int(endTime.timeIntervalSince(startTime) / 60)
    }

    public enum SessionType: String, Sendable, Codable {
        case work
        case shortBreak
        case longBreak

        public var displayName: String {
            switch self {
            case .work: return "Work"
            case .shortBreak: return "Short Break"
            case .longBreak: return "Long Break"
            }
        }

        public var defaultDuration: Int {
            switch self {
            case .work: return 25
            case .shortBreak: return 5
            case .longBreak: return 15
            }
        }

        public var color: String {
            switch self {
            case .work: return "#EF4444"      // Red
            case .shortBreak: return "#10B981" // Green
            case .longBreak: return "#3B82F6"  // Blue
            }
        }
    }
}

// MARK: - Focus Forest

/// Focus forest tree growth gamification
public struct FocusTree: Sendable, Codable, Identifiable {
    public let id: UUID
    public let plantedAt: Date
    public let grownAt: Date?
    public let minutesGrown: Int
    public let treeType: TreeType
    public let isDead: Bool

    public init(
        id: UUID = UUID(),
        plantedAt: Date,
        grownAt: Date? = nil,
        minutesGrown: Int,
        treeType: TreeType,
        isDead: Bool = false
    ) {
        self.id = id
        self.plantedAt = plantedAt
        self.grownAt = grownAt
        self.minutesGrown = minutesGrown
        self.treeType = treeType
        self.isDead = isDead
    }

    public var isFullyGrown: Bool {
        grownAt != nil && !isDead
    }

    public var growthProgress: Double {
        guard !isFullyGrown else { return 100 }
        let target = treeType.minutesToGrow
        return min(100, (Double(minutesGrown) / Double(target)) * 100)
    }

    public enum TreeType: String, Sendable, Codable, CaseIterable {
        case oak
        case pine
        case cherry
        case maple

        public var displayName: String {
            switch self {
            case .oak: return "Oak"
            case .pine: return "Pine"
            case .cherry: return "Cherry Blossom"
            case .maple: return "Maple"
            }
        }

        public var minutesToGrow: Int {
            switch self {
            case .oak: return 30
            case .pine: return 25
            case .cherry: return 20
            case .maple: return 35
            }
        }

        public var icon: String {
            "tree"
        }
    }
}

/// Focus forest (collection of trees)
public struct FocusForest: Sendable, Codable {
    public var trees: [FocusTree]
    public let createdAt: Date

    public init(trees: [FocusTree] = [], createdAt: Date = Date()) {
        self.trees = trees
        self.createdAt = createdAt
    }

    public var totalTreesGrown: Int {
        trees.filter(\.isFullyGrown).count
    }

    public var totalMinutesFocused: Int {
        trees.filter(\.isFullyGrown).reduce(0) { $0 + $1.minutesGrown }
    }

    public var currentStreak: Int {
        // Calculate consecutive days with grown trees
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        while true {
            let hasTreeToday = trees.contains { tree in
                guard let grownAt = tree.grownAt else { return false }
                return calendar.isDate(grownAt, inSameDayAs: currentDate)
            }

            if hasTreeToday {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate.addingTimeInterval(-86400)
            } else {
                break
            }
        }

        return streak
    }
}

// MARK: - CBT Micro-Lessons

/// Cognitive Behavioral Therapy micro-lesson
public struct CBTLesson: Sendable, Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let content: String
    public let category: Category
    public let estimatedMinutes: Int
    public let difficulty: Difficulty

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        content: String,
        category: Category,
        estimatedMinutes: Int,
        difficulty: Difficulty
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.content = content
        self.category = category
        self.estimatedMinutes = estimatedMinutes
        self.difficulty = difficulty
    }

    public enum Category: String, Sendable, Codable {
        case timeManagement
        case emotionalRegulation
        case prioritization
        case distraction
        case motivation

        public var displayName: String {
            switch self {
            case .timeManagement: return "Time Management"
            case .emotionalRegulation: return "Emotional Regulation"
            case .prioritization: return "Prioritization"
            case .distraction: return "Managing Distractions"
            case .motivation: return "Motivation"
            }
        }

        public var icon: String {
            switch self {
            case .timeManagement: return "clock.fill"
            case .emotionalRegulation: return "heart.fill"
            case .prioritization: return "list.number"
            case .distraction: return "eye.slash.fill"
            case .motivation: return "bolt.fill"
            }
        }
    }

    public enum Difficulty: String, Sendable, Codable {
        case beginner
        case intermediate
        case advanced

        public var displayName: String {
            switch self {
            case .beginner: return "Beginner"
            case .intermediate: return "Intermediate"
            case .advanced: return "Advanced"
            }
        }
    }
}

// MARK: - Cognitive Error

/// Cognitive module errors
public enum CognitiveError: Error, Sendable, LocalizedError {
    case taskBreakdownFailed(String)
    case pomodoroSessionActive
    case invalidDuration
    case treeAlreadyPlanted

    public var errorDescription: String? {
        switch self {
        case .taskBreakdownFailed(let reason):
            return "Failed to break down task: \(reason)"
        case .pomodoroSessionActive:
            return "A Pomodoro session is already active. Complete or cancel it first."
        case .invalidDuration:
            return "The duration must be greater than 0 minutes."
        case .treeAlreadyPlanted:
            return "A tree is already growing. Complete the current session first."
        }
    }
}
