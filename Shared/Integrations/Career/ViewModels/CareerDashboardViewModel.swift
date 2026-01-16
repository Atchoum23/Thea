import Foundation
import SwiftUI

/// View model for career dashboard
@MainActor
@Observable
public final class CareerDashboardViewModel {
    // MARK: - Published State

    public var goals: [CareerGoal] = []
    public var skills: [Skill] = []
    public var todayCareerReflection: CareerReflection?
    public var recommendations: [GrowthRecommendation] = []
    public var moodTrend: MoodTrend?
    public var isLoading = false
    public var errorMessage: String?

    // MARK: - Filtering

    public var selectedGoalStatus: CareerGoalStatus?
    public var selectedSkillCategory: SkillCategory?

    // MARK: - Dependencies

    private let careerService: CareerService

    // MARK: - Initialization

    public init(careerService: CareerService = CareerService()) {
        self.careerService = careerService
    }

    // MARK: - Data Loading

    public func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let goalsTask = careerService.fetchGoals()
            async let skillsTask = careerService.fetchSkills()
            async let reflectionTask = careerService.fetchCareerReflection(for: Date())
            async let recommendationsTask = careerService.fetchActiveRecommendations()
            async let moodTrendTask = careerService.analyzeMoodTrends(days: 30)

            goals = try await goalsTask
            skills = try await skillsTask
            todayCareerReflection = try await reflectionTask
            recommendations = try await recommendationsTask
            moodTrend = try await moodTrendTask
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func refreshData() async {
        await loadData()
    }

    // MARK: - Goal Management

    public func createGoal(
        title: String,
        description: String,
        category: CareerGoalCategory,
        priority: CareerPriority,
        targetDate: Date?
    ) async {
        let goal = CareerGoal(
            title: title,
            description: description,
            category: category,
            priority: priority,
            startDate: targetDate ?? Date()
        )

        do {
            try await careerService.createGoal(goal)
            goals = try await careerService.fetchGoals()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateGoal(_ goal: CareerGoal) async {
        do {
            try await careerService.updateGoal(goal)
            goals = try await careerService.fetchGoals()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteGoal(_ goal: CareerGoal) async {
        do {
            try await careerService.deleteGoal(id: goal.id)
            goals = try await careerService.fetchGoals()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addMilestone(_ milestone: Milestone, to goal: CareerGoal) async {
        do {
            try await careerService.addMilestone(milestone, to: goal.id)
            goals = try await careerService.fetchGoals()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func completeMilestone(_ milestoneID: UUID, in goal: CareerGoal) async {
        do {
            try await careerService.completeMilestone(milestoneID: milestoneID, in: goal.id)
            goals = try await careerService.fetchGoals()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Skill Management

    public func addSkill(
        name: String,
        category: SkillCategory,
        proficiency: ProficiencyLevel,
        targetProficiency: ProficiencyLevel,
        targetHours: Double?
    ) async {
        let skill = Skill(
            name: name,
            category: category,
            proficiency: proficiency,
            targetHours: targetHours,
            targetProficiency: targetProficiency
        )

        do {
            try await careerService.addSkill(skill)
            skills = try await careerService.fetchSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateProficiency(skillID: UUID, proficiency: ProficiencyLevel) async {
        do {
            try await careerService.updateProficiency(skillID: skillID, proficiency: proficiency)
            skills = try await careerService.fetchSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func logPracticeHours(skillID: UUID, hours: Double) async {
        do {
            try await careerService.logPracticeHours(skillID: skillID, hours: hours)
            skills = try await careerService.fetchSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - CareerReflection Management

    public func createOrUpdateCareerReflection(
        wins: String,
        challenges: String,
        learnings: String,
        gratitude: String,
        tomorrowGoals: String,
        mood: Mood
    ) async {
        if let existing = todayCareerReflection {
            var updated = existing
            updated.wins = wins
            updated.challenges = challenges
            updated.learnings = learnings
            updated.gratitude = gratitude
            updated.tomorrowGoals = tomorrowGoals
            updated.mood = mood

            do {
                try await careerService.updateCareerReflection(updated)
                todayCareerReflection = updated
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            let reflection = CareerReflection(
                mood: mood,
                accomplishments: wins,
                challenges: challenges,
                learnings: learnings,
                gratitude: gratitude,
                tomorrowGoals: tomorrowGoals,
                wins: wins
            )

            do {
                try await careerService.createCareerReflection(reflection)
                todayCareerReflection = reflection
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Recommendations

    public func generateRecommendations() async {
        do {
            recommendations = try await careerService.generateRecommendations(
                goals: goals,
                skills: skills,
                reflections: [] // Pass recent reflections if available
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func dismissRecommendation(_ recommendation: GrowthRecommendation) async {
        do {
            try await careerService.dismissRecommendation(id: recommendation.id)
            recommendations = try await careerService.fetchActiveRecommendations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed Properties

    public var filteredGoals: [CareerGoal] {
        if let status = selectedGoalStatus {
            return goals.filter { $0.status == status }
        }
        return goals
    }

    public var filteredSkills: [Skill] {
        if let category = selectedSkillCategory {
            return skills.filter { $0.category == category }
        }
        return skills
    }

    public var activeGoalsCount: Int {
        goals.filter { $0.status == .inProgress }.count
    }

    public var completedGoalsCount: Int {
        goals.filter { $0.status == .completed }.count
    }

    public var averageGoalProgress: Double {
        guard !goals.isEmpty else { return 0.0 }
        let total = goals.reduce(0.0) { $0 + $1.progress }
        return total / Double(goals.count)
    }

    public var skillsInProgress: Int {
        skills.filter { skill in
            guard let target = skill.targetProficiency else { return false }
            return skill.proficiency < target
        }.count
    }

    public var totalPracticeHours: Double {
        skills.reduce(0.0) { $0 + $1.hoursInvested }
    }
}
