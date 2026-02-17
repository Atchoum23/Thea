import Foundation
@preconcurrency import SwiftData

/// Career development service
public actor CareerService: CareerServiceProtocol, SkillTrackingProtocol, CareerCareerReflectionServiceProtocol, GrowthRecommendationProtocol {
    // MARK: - Properties

    private var goals: [UUID: CareerGoal] = [:]
    private var skills: [UUID: Skill] = [:]
    private var reflections: [UUID: CareerReflection] = [:]
    private var recommendations: [UUID: GrowthRecommendation] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - Goal Management

    /// Creates a new career goal, validating that its title is non-empty.
    public func createGoal(_ goal: CareerGoal) async throws {
        guard !goal.title.isEmpty else {
            throw CareerError.invalidGoal("Title cannot be empty")
        }
        goals[goal.id] = goal
    }

    /// Updates an existing career goal, throwing if the goal is not found.
    public func updateGoal(_ goal: CareerGoal) async throws {
        guard goals[goal.id] != nil else {
            throw CareerError.invalidGoal("Goal not found")
        }
        goals[goal.id] = goal
    }

    /// Deletes a career goal by its identifier.
    public func deleteGoal(id: UUID) async throws {
        goals.removeValue(forKey: id)
    }

    /// Returns all career goals sorted by start date, most recent first.
    public func fetchGoals() async throws -> [CareerGoal] {
        Array(goals.values).sorted { $0.startDate > $1.startDate }
    }

    /// Returns career goals filtered by the given status, sorted by start date descending.
    public func fetchGoals(status: CareerGoalStatus) async throws -> [CareerGoal] {
        goals.values.filter { $0.status == status }
            .sorted { $0.startDate > $1.startDate }
    }

    /// Adds a milestone to the specified career goal (milestone management delegated to CareerGoalTracker).
    public func addMilestone(_: Milestone, to goalID: UUID) async throws {
        guard let goal = goals[goalID] else {
            throw CareerError.invalidGoal("Goal not found")
        }
        // Milestone management moved to CareerGoalTracker
        // goal.milestones.append(milestone)
        // goal.updateProgress()
        goals[goalID] = goal
    }

    /// Marks a milestone as completed within the specified goal (milestone management delegated to CareerGoalTracker).
    public func completeMilestone(milestoneID _: UUID, in goalID: UUID) async throws {
        guard let goal = goals[goalID] else {
            throw CareerError.invalidGoal("Goal not found")
        }

        // Milestone management moved to CareerGoalTracker
        /* guard let index = goal.milestones.firstIndex(where: { $0.id == milestoneID }) else {
             throw CareerError.invalidGoal("Milestone not found")
         }

         goal.milestones[index].completed = true
         goal.milestones[index].completedDate = Date()
         goal.updateProgress() */
        goals[goalID] = goal
    }

    // MARK: - Skill Tracking

    /// Adds a new skill to tracking, validating that its name is non-empty.
    public func addSkill(_ skill: Skill) async throws {
        guard !skill.name.isEmpty else {
            throw CareerError.invalidSkill("Skill name cannot be empty")
        }
        skills[skill.id] = skill
    }

    /// Updates the proficiency level of a skill and records the current date as last practiced.
    public func updateProficiency(skillID: UUID, proficiency: ProficiencyLevel) async throws {
        guard var skill = skills[skillID] else {
            throw CareerError.invalidSkill("Skill not found")
        }
        skill.proficiency = proficiency
        skill.lastPracticed = Date()
        skills[skillID] = skill
    }

    /// Logs practice hours for a skill and auto-upgrades proficiency when the investment threshold is reached.
    public func logPracticeHours(skillID: UUID, hours: Double) async throws {
        guard var skill = skills[skillID] else {
            throw CareerError.invalidSkill("Skill not found")
        }
        skill.hoursInvested += hours
        skill.lastPracticed = Date()

        // Auto-upgrade proficiency based on hours invested
        if let targetHours = skill.targetHours, let targetProf = skill.targetProficiency {
            let progressRatio = skill.hoursInvested / targetHours
            if progressRatio >= 0.8, skill.proficiency < targetProf {
                skill.proficiency = min(ProficiencyLevel(rawValue: skill.proficiency.rawValue + 1) ?? skill.proficiency,
                                        targetProf)
            }
        }

        skills[skillID] = skill
    }

    /// Returns all tracked skills sorted alphabetically by name.
    public func fetchSkills() async throws -> [Skill] {
        Array(skills.values).sorted { $0.name < $1.name }
    }

    /// Returns skills filtered by category, sorted alphabetically by name.
    public func fetchSkills(category: SkillCategory) async throws -> [Skill] {
        skills.values.filter { $0.category == category }
            .sorted { $0.name < $1.name }
    }

    /// Associates a learning resource with the specified skill (resource management handled separately).
    public func addResource(_: LearningResource, to skillID: UUID) async throws {
        guard skills[skillID] != nil else {
            throw CareerError.invalidSkill("Skill not found")
        }
        // Note: Skill model doesn't have resources property
        // Resource management should be handled separately
        // skills[skillID] = skill
    }

    // MARK: - CareerReflection

    /// Stores a new career reflection entry.
    public func createCareerReflection(_ reflection: CareerReflection) async throws {
        reflections[reflection.id] = reflection
    }

    /// Updates an existing career reflection, throwing if not found.
    public func updateCareerReflection(_ reflection: CareerReflection) async throws {
        guard reflections[reflection.id] != nil else {
            throw CareerError.invalidCareerReflection("CareerReflection not found")
        }
        reflections[reflection.id] = reflection
    }

    /// Returns the career reflection recorded on the given date, if any.
    public func fetchCareerReflection(for date: Date) async throws -> CareerReflection? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)

        return reflections.values.first { reflection in
            reflection.date >= startOfDay && reflection.date < endOfDay
        }
    }

    /// Returns career reflections within the given date range, sorted most recent first.
    public func fetchCareerReflections(from startDate: Date, to endDate: Date) async throws -> [CareerReflection] {
        reflections.values.filter { reflection in
            reflection.date >= startDate && reflection.date <= endDate
        }.sorted { $0.date > $1.date }
    }

    /// Analyzes career mood trends over the specified number of days, comparing first-half vs second-half averages.
    public func analyzeMoodTrends(days: Int) async throws -> MoodTrend {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate.addingTimeInterval(Double(-days) * 86400)

        let periodCareerReflections = try await fetchCareerReflections(from: startDate, to: endDate)

        guard !periodCareerReflections.isEmpty else {
            return MoodTrend(
                averageMood: 3.0,
                trend: .unknown,
                moodCounts: [:],
                periodDays: days
            )
        }

        // Calculate mood counts
        var moodCounts: [Mood: Int] = [:]
        for reflection in periodCareerReflections {
            moodCounts[reflection.mood, default: 0] += 1
        }

        // Calculate average mood (1.0 = frustrated, 7.0 = excited)
        let moodValues: [Mood: Double] = [
            .frustrated: 1.0,
            .stressed: 2.0,
            .neutral: 3.0,
            .satisfied: 4.0,
            .motivated: 5.0,
            .accomplished: 6.0,
            .excited: 7.0
        ]

        let totalMoodValue = periodCareerReflections.reduce(0.0) { sum, reflection in
            sum + (moodValues[reflection.mood] ?? 3.0)
        }
        let averageMood = totalMoodValue / Double(periodCareerReflections.count)

        // Determine trend (compare first half vs second half)
        let midpoint = periodCareerReflections.count / 2
        let firstHalf = periodCareerReflections.suffix(from: midpoint)
        let secondHalf = periodCareerReflections.prefix(midpoint)

        let firstHalfAvg = firstHalf.reduce(0.0) { sum, reflection in
            sum + (moodValues[reflection.mood] ?? 3.0)
        } / Double(max(firstHalf.count, 1))

        let secondHalfAvg = secondHalf.reduce(0.0) { sum, reflection in
            sum + (moodValues[reflection.mood] ?? 3.0)
        } / Double(max(secondHalf.count, 1))

        let trend: Trend = if secondHalfAvg > firstHalfAvg + 0.5 {
            .improving
        } else if secondHalfAvg < firstHalfAvg - 0.5 {
            .declining
        } else {
            .stable
        }

        return MoodTrend(
            averageMood: averageMood,
            trend: trend,
            moodCounts: moodCounts,
            periodDays: days
        )
    }

    // MARK: - Growth Recommendations

    /// Generates growth recommendations based on skill gaps, goal alignment, and wellbeing signals.
    public func generateRecommendations(
        goals: [CareerGoal],
        skills: [Skill],
        reflections: [CareerReflection]
    ) async throws -> [GrowthRecommendation] {
        var newRecommendations: [GrowthRecommendation] = []

        // Skill gap recommendations
        let skillGaps = identifySkillGaps(goals: goals, skills: skills)
        newRecommendations.append(contentsOf: skillGaps)

        // Goal alignment recommendations
        let goalAlignments = analyzeGoalAlignment(goals: goals)
        newRecommendations.append(contentsOf: goalAlignments)

        // Wellbeing recommendations based on mood trends
        if let wellbeingRecs = try? await generateWellbeingRecommendations(reflections: reflections) {
            newRecommendations.append(contentsOf: wellbeingRecs)
        }

        // Store recommendations
        for recommendation in newRecommendations {
            recommendations[recommendation.id] = recommendation
        }

        return newRecommendations
    }

    /// Dismisses a growth recommendation so it no longer appears in active results.
    public func dismissRecommendation(id: UUID) async throws {
        guard var recommendation = recommendations[id] else {
            return
        }
        recommendation.dismissed = true
        recommendations[id] = recommendation
    }

    /// Returns all non-dismissed recommendations sorted by priority descending.
    public func fetchActiveRecommendations() async throws -> [GrowthRecommendation] {
        recommendations.values.filter { !$0.dismissed }
            .sorted { $0.priority > $1.priority }
    }

    // MARK: - Private Helpers

    private func identifySkillGaps(goals _: [CareerGoal], skills: [Skill]) -> [GrowthRecommendation] {
        var recommendations: [GrowthRecommendation] = []

        // Identify skills that haven't been practiced recently
        let staleSkills = skills.filter { skill in
            let daysSince = Calendar.current.dateComponents([.day], from: skill.lastPracticed, to: Date()).day ?? 0
            return daysSince > 14 // Not practiced in 2 weeks
        }

        for skill in staleSkills.prefix(3) {
            recommendations.append(GrowthRecommendation(
                type: .skillDevelopment,
                title: "Practice \(skill.name)",
                description: "You haven't practiced \(skill.name) recently. Consider dedicating some time to maintain this skill.",
                priority: .medium,
                actionItems: [
                    "Review fundamentals",
                    "Complete a small project",
                    "Engage with learning resources"
                ],
                estimatedTimeMinutes: 60
            ))
        }

        return recommendations
    }

    private func analyzeGoalAlignment(goals: [CareerGoal]) -> [GrowthRecommendation] {
        var recommendations: [GrowthRecommendation] = []

        // Find goals with no recent progress
        let stagnantGoals = goals.filter { goal in
            goal.status == .inProgress && goal.progress < 0.2
        }

        for goal in stagnantGoals.prefix(2) {
            recommendations.append(GrowthRecommendation(
                type: .projectWork,
                title: "Make progress on '\(goal.title)'",
                description: "This goal has been in progress but shows minimal advancement. Consider breaking it down further.",
                priority: .high,
                actionItems: [
                    "Review goal milestones",
                    "Identify blockers",
                    "Schedule dedicated time"
                ],
                estimatedTimeMinutes: 30
            ))
        }

        return recommendations
    }

    private func generateWellbeingRecommendations(reflections _: [CareerReflection]) async throws -> [GrowthRecommendation] {
        var recommendations: [GrowthRecommendation] = []

        let moodTrend = try await analyzeMoodTrends(days: 7)

        if moodTrend.averageMood < 2.5 {
            recommendations.append(GrowthRecommendation(
                type: .mentorship,
                title: "Focus on wellbeing",
                description: "Your mood has been lower than usual recently. Consider taking steps to improve your wellbeing.",
                priority: .urgent,
                actionItems: [
                    "Schedule self-care activities",
                    "Connect with support network",
                    "Review work-life balance",
                    "Consider professional support if needed"
                ],
                estimatedTimeMinutes: 0
            ))
        }

        return recommendations
    }
}
