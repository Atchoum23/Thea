import Foundation

// MARK: - Career Service Protocol

/// Protocol for career development services
public protocol CareerServiceProtocol: Actor {
    /// Create a new career goal
    func createGoal(_ goal: CareerGoal) async throws

    /// Update an existing goal
    func updateGoal(_ goal: CareerGoal) async throws

    /// Delete a goal
    func deleteGoal(id: UUID) async throws

    /// Fetch all goals
    func fetchGoals() async throws -> [CareerGoal]

    /// Fetch goals by status
    func fetchGoals(status: CareerGoalStatus) async throws -> [CareerGoal]

    /// Add a milestone to a goal
    func addMilestone(_ milestone: Milestone, to goalID: UUID) async throws

    /// Mark milestone as completed
    func completeMilestone(milestoneID: UUID, in goalID: UUID) async throws
}

// MARK: - Skill Tracking Protocol

/// Protocol for skill tracking services
public protocol SkillTrackingProtocol: Actor {
    /// Add a new skill
    func addSkill(_ skill: Skill) async throws

    /// Update skill proficiency
    func updateProficiency(skillID: UUID, proficiency: ProficiencyLevel) async throws

    /// Log practice hours
    func logPracticeHours(skillID: UUID, hours: Double) async throws

    /// Fetch all skills
    func fetchSkills() async throws -> [Skill]

    /// Fetch skills by category
    func fetchSkills(category: SkillCategory) async throws -> [Skill]

    /// Add learning resource to skill
    func addResource(_ resource: LearningResource, to skillID: UUID) async throws
}

// MARK: - CareerReflection Protocol

/// Protocol for daily reflection services
public protocol CareerCareerReflectionServiceProtocol: Actor {
    /// Create a new reflection
    func createCareerReflection(_ reflection: CareerReflection) async throws

    /// Update an existing reflection
    func updateCareerReflection(_ reflection: CareerReflection) async throws

    /// Fetch reflection for a specific date
    func fetchCareerReflection(for date: Date) async throws -> CareerReflection?

    /// Fetch reflections for a date range
    func fetchCareerReflections(from startDate: Date, to endDate: Date) async throws -> [CareerReflection]

    /// Analyze mood trends over time
    func analyzeMoodTrends(days: Int) async throws -> MoodTrend
}

// MARK: - Growth Recommendation Protocol

/// Protocol for AI-powered growth recommendations
public protocol GrowthRecommendationProtocol: Actor {
    /// Generate personalized growth recommendations
    func generateRecommendations(
        goals: [CareerGoal],
        skills: [Skill],
        reflections: [CareerReflection]
    ) async throws -> [GrowthRecommendation]

    /// Dismiss a recommendation
    func dismissRecommendation(id: UUID) async throws

    /// Fetch active recommendations
    func fetchActiveRecommendations() async throws -> [GrowthRecommendation]
}

// MARK: - Supporting Types

/// Mood trend analysis
public struct MoodTrend: Sendable, Codable {
    public var averageMood: Double // 1.0 (difficult) to 5.0 (great)
    public var trend: Trend
    public var moodCounts: [Mood: Int]
    public var periodDays: Int

    public init(
        averageMood: Double,
        trend: Trend,
        moodCounts: [Mood: Int],
        periodDays: Int
    ) {
        self.averageMood = averageMood
        self.trend = trend
        self.moodCounts = moodCounts
        self.periodDays = periodDays
    }
}
