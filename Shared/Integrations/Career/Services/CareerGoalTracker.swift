import Foundation

import Combine

/// Service for tracking career goals and professional development
public actor CareerGoalTracker {
    public static let shared = CareerGoalTracker()

    private var goals: [CareerGoal] = []
    private var milestones: [UUID: [Milestone]] = [:]
    private var reflections: [UUID: [DailyReflection]] = [:]

    public enum TrackerError: Error, Sendable, LocalizedError {
        case goalNotFound
        case invalidData
        case milestoneNotFound

        public var errorDescription: String? {
            switch self {
            case .goalNotFound:
                return "Career goal not found"
            case .invalidData:
                return "Invalid goal data provided"
            case .milestoneNotFound:
                return "Milestone not found"
            }
        }
    }

    private init() {}

    // MARK: - Goal Management

    public func createGoal(_ goal: CareerGoal) async throws {
        goals.append(goal)
    }

    public func updateGoal(_ updatedGoal: CareerGoal) async throws {
        guard let index = goals.firstIndex(where: { $0.id == updatedGoal.id }) else {
            throw TrackerError.goalNotFound
        }
        goals[index] = updatedGoal
    }

    public func deleteGoal(id: UUID) async throws {
        guard goals.contains(where: { $0.id == id }) else {
            throw TrackerError.goalNotFound
        }

        goals.removeAll { $0.id == id }
        milestones.removeValue(forKey: id)
        reflections.removeValue(forKey: id)
    }

    public func getGoal(id: UUID) async throws -> CareerGoal {
        guard let goal = goals.first(where: { $0.id == id }) else {
            throw TrackerError.goalNotFound
        }
        return goal
    }

    public func getAllGoals() async -> [CareerGoal] {
        goals
    }

    public func getActiveGoals() async -> [CareerGoal] {
        goals.filter { $0.status == .inProgress }
    }

    // MARK: - Milestone Management

    public func addMilestone(_ milestone: Milestone, to goalID: UUID) async throws {
        guard goals.contains(where: { $0.id == goalID }) else {
            throw TrackerError.goalNotFound
        }

        if milestones[goalID] == nil {
            milestones[goalID] = []
        }
        milestones[goalID]?.append(milestone)
    }

    public func completeMilestone(id: UUID, for goalID: UUID) async throws {
        guard var goalMilestones = milestones[goalID] else {
            throw TrackerError.goalNotFound
        }

        guard let index = goalMilestones.firstIndex(where: { $0.id == id }) else {
            throw TrackerError.milestoneNotFound
        }

        goalMilestones[index].isCompleted = true
        goalMilestones[index].completionDate = Date()
        milestones[goalID] = goalMilestones

        // Update goal progress
        try await updateGoalProgress(goalID)
    }

    public func getMilestones(for goalID: UUID) async -> [Milestone] {
        milestones[goalID] ?? []
    }

    // MARK: - Reflection Management

    public func addReflection(_ reflection: DailyReflection, for goalID: UUID) async throws {
        guard goals.contains(where: { $0.id == goalID }) else {
            throw TrackerError.goalNotFound
        }

        if reflections[goalID] == nil {
            reflections[goalID] = []
        }
        reflections[goalID]?.append(reflection)
    }

    public func getReflections(for goalID: UUID, limit: Int? = nil) async -> [DailyReflection] {
        let goalReflections = reflections[goalID] ?? []
        let sorted = goalReflections.sorted { $0.date > $1.date }

        if let limit = limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }

    // MARK: - Progress Tracking

    private func updateGoalProgress(_ goalID: UUID) async throws {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else {
            throw TrackerError.goalNotFound
        }

        let goalMilestones = milestones[goalID] ?? []
        guard !goalMilestones.isEmpty else { return }

        let completedCount = goalMilestones.filter { $0.isCompleted }.count
        let progress = Double(completedCount) / Double(goalMilestones.count)

        goals[index].progress = progress

        // Auto-complete goal if all milestones are done
        if progress >= 1.0 {
            goals[index].status = .completed
            goals[index].completionDate = Date()
        }
    }

    public func getProgressReport(for goalID: UUID) async throws -> ProgressReport {
        let goal = try await getGoal(id: goalID)
        let goalMilestones = await getMilestones(for: goalID)
        let goalReflections = await getReflections(for: goalID)

        let completedMilestones = goalMilestones.filter { $0.isCompleted }.count
        let totalMilestones = goalMilestones.count

        let daysSinceStart = Calendar.current.dateComponents([.day], from: goal.startDate, to: Date()).day ?? 0
        let daysToDeadline = goal.deadline.map {
            Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 0
        }

        return ProgressReport(
            goal: goal,
            completedMilestones: completedMilestones,
            totalMilestones: totalMilestones,
            currentProgress: goal.progress,
            daysSinceStart: daysSinceStart,
            daysToDeadline: daysToDeadline,
            recentReflections: goalReflections.prefix(5).map { $0 },
            momentum: calculateMomentum(goalReflections)
        )
    }

    // MARK: - Analytics

    private func calculateMomentum(_ reflections: [DailyReflection]) -> String {
        guard reflections.count >= 3 else { return "Insufficient data" }

        let recentReflections = reflections.prefix(7)
        let positiveCount = recentReflections.filter {
            $0.mood == .motivated || $0.mood == .accomplished
        }.count

        let percentage = Double(positiveCount) / Double(recentReflections.count)

        if percentage >= 0.7 { return "Strong momentum" }
        if percentage >= 0.4 { return "Moderate momentum" }
        return "Low momentum"
    }

    public func getOverallStatistics() async -> CareerStatistics {
        let totalGoals = goals.count
        let activeGoals = goals.filter { $0.status == .inProgress }.count
        let completedGoals = goals.filter { $0.status == .completed }.count

        let allMilestones = milestones.values.flatMap { $0 }
        let completedMilestones = allMilestones.filter { $0.isCompleted }.count

        let allReflections = reflections.values.flatMap { $0 }
        let reflectionStreak = calculateReflectionStreak(allReflections)

        let goalsByCategory = Dictionary(grouping: goals) { $0.category }

        return CareerStatistics(
            totalGoals: totalGoals,
            activeGoals: activeGoals,
            completedGoals: completedGoals,
            completionRate: totalGoals > 0 ? Double(completedGoals) / Double(totalGoals) : 0,
            totalMilestones: allMilestones.count,
            completedMilestones: completedMilestones,
            reflectionCount: allReflections.count,
            reflectionStreak: reflectionStreak,
            goalsByCategory: goalsByCategory.mapValues { $0.count }
        )
    }

    private func calculateReflectionStreak(_ reflections: [DailyReflection]) -> Int {
        guard !reflections.isEmpty else { return 0 }

        let sorted = reflections.sorted { $0.date > $1.date }
        var streak = 0
        var currentDate = Date().startOfDay

        for reflection in sorted {
            if Calendar.current.isDate(reflection.date, inSameDayAs: currentDate) {
                streak += 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }

        return streak
    }
}

// MARK: - Data Models

public struct CareerGoal: Identifiable, Sendable, Codable {
    public let id: UUID
    public var title: String
    public var description: String
    public var category: CareerGoalCategory
    public var priority: CareerPriority
    public var status: CareerGoalStatus
    public var progress: Double
    public var startDate: Date
    public var deadline: Date?
    public var completionDate: Date?
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: CareerGoalCategory,
        priority: CareerPriority = .medium,
        status: CareerGoalStatus = .notStarted,
        progress: Double = 0.0,
        startDate: Date = Date(),
        deadline: Date? = nil,
        completionDate: Date? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.status = status
        self.progress = progress
        self.startDate = startDate
        self.deadline = deadline
        self.completionDate = completionDate
        self.tags = tags
    }
}

public enum CareerGoalCategory: String, Sendable, Codable, CaseIterable {
    case skillDevelopment = "Skill Development"
    case certification = "Certification"
    case promotion = "Promotion"
    case networking = "Networking"
    case projectCompletion = "Project Completion"
    case careerChange = "Career Change"
    case leadership = "Leadership"
    case other = "Other"

    public var icon: String {
        switch self {
        case .skillDevelopment: return "brain.head.profile"
        case .certification: return "rosette"
        case .promotion: return "arrow.up.right.circle"
        case .networking: return "person.3"
        case .projectCompletion: return "checkmark.circle"
        case .careerChange: return "arrow.triangle.2.circlepath"
        case .leadership: return "crown"
        case .other: return "star"
        }
    }
}

public enum CareerPriority: Int, Sendable, Codable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    public static func < (lhs: CareerPriority, rhs: CareerPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum CareerGoalStatus: String, Sendable, Codable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case paused = "Paused"
    case completed = "Completed"
    case abandoned = "Abandoned"
}

public struct Milestone: Identifiable, Sendable, Codable {
    public let id: UUID
    public var title: String
    public var description: String
    public var targetDate: Date?
    public var isCompleted: Bool
    public var completionDate: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        targetDate: Date? = nil,
        isCompleted: Bool = false,
        completionDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.targetDate = targetDate
        self.isCompleted = isCompleted
        self.completionDate = completionDate
    }
}

public struct DailyReflection: Identifiable, Sendable, Codable {
    public let id: UUID
    public var date: Date
    public var accomplishments: String
    public var challenges: String
    public var learnings: String
    public var mood: ReflectionMood
    public var energyLevel: Int // 1-5

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        accomplishments: String,
        challenges: String,
        learnings: String,
        mood: ReflectionMood,
        energyLevel: Int
    ) {
        self.id = id
        self.date = date
        self.accomplishments = accomplishments
        self.challenges = challenges
        self.learnings = learnings
        self.mood = mood
        self.energyLevel = energyLevel
    }
}

public enum ReflectionMood: String, Sendable, Codable {
    case frustrated = "Frustrated"
    case neutral = "Neutral"
    case motivated = "Motivated"
    case accomplished = "Accomplished"
}

public struct ProgressReport: Sendable {
    public let goal: CareerGoal
    public let completedMilestones: Int
    public let totalMilestones: Int
    public let currentProgress: Double
    public let daysSinceStart: Int
    public let daysToDeadline: Int?
    public let recentReflections: [DailyReflection]
    public let momentum: String
}

public struct CareerStatistics: Sendable {
    public let totalGoals: Int
    public let activeGoals: Int
    public let completedGoals: Int
    public let completionRate: Double
    public let totalMilestones: Int
    public let completedMilestones: Int
    public let reflectionCount: Int
    public let reflectionStreak: Int
    public let goalsByCategory: [CareerGoalCategory: Int]
}

// MARK: - Coordinator

@MainActor
public final class CareerGoalCoordinator: ObservableObject {
    @Published public var goals: [CareerGoal] = []
    @Published public var statistics: CareerStatistics?
    @Published public var isLoading = false

    private let tracker = CareerGoalTracker.shared

    public init() {}

    public func loadGoals() async {
        isLoading = true
        goals = await tracker.getAllGoals()
        statistics = await tracker.getOverallStatistics()
        isLoading = false
    }

    public func createGoal(_ goal: CareerGoal) async {
        try? await tracker.createGoal(goal)
        await loadGoals()
    }

    public func updateGoal(_ goal: CareerGoal) async {
        try? await tracker.updateGoal(goal)
        await loadGoals()
    }

    public func deleteGoal(_ goal: CareerGoal) async {
        try? await tracker.deleteGoal(id: goal.id)
        await loadGoals()
    }
}
