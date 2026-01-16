import Testing
import Foundation
@testable import Thea

/// Tests for career development service
@Suite("Career Service Tests")
struct CareerServiceTests {

    // MARK: - Goal Tests

    @Test("Create goal successfully")
    func testCreateGoal() async throws {
        let service = CareerService()

        let goal = CareerGoal(
            title: "Learn Swift",
            description: "Master Swift programming language",
            category: .skillDevelopment,
            priority: .high
        )

        try await service.createGoal(goal)

        let goals = try await service.fetchGoals()
        #expect(goals.count == 1)
        #expect(goals[0].title == "Learn Swift")
    }

    @Test("Update goal successfully")
    func testUpdateGoal() async throws {
        let service = CareerService()

        var goal = CareerGoal(
            title: "Original Title",
            description: "Original description",
            category: .skillDevelopment
        )

        try await service.createGoal(goal)

        goal.title = "Updated Title"
        try await service.updateGoal(goal)

        let goals = try await service.fetchGoals()
        #expect(goals[0].title == "Updated Title")
    }

    @Test("Filter goals by status")
    func testFilterGoalsByStatus() async throws {
        let service = CareerService()

        let goal1 = CareerGoal(
            title: "Goal 1",
            description: "Test",
            category: .skillDevelopment,
            status: .inProgress
        )

        let goal2 = CareerGoal(
            title: "Goal 2",
            description: "Test",
            category: .careerAdvancement,
            status: .completed
        )

        try await service.createGoal(goal1)
        try await service.createGoal(goal2)

        let inProgressGoals = try await service.fetchGoals(status: .inProgress)
        #expect(inProgressGoals.count == 1)
        #expect(inProgressGoals[0].title == "Goal 1")
    }

    @Test("Add milestone to goal")
    func testAddMilestone() async throws {
        let service = CareerService()

        let goal = CareerGoal(
            title: "Test Goal",
            description: "Test",
            category: .skillDevelopment
        )

        try await service.createGoal(goal)

        let milestone = Milestone(
            title: "Complete Chapter 1",
            description: "Finish reading first chapter"
        )

        try await service.addMilestone(milestone, to: goal.id)

        let goals = try await service.fetchGoals()
        #expect(goals[0].milestones.count == 1)
    }

    @Test("Complete milestone updates progress")
    func testCompleteMilestone() async throws {
        let service = CareerService()

        var goal = CareerGoal(
            title: "Test Goal",
            description: "Test",
            category: .skillDevelopment
        )

        let milestone1 = Milestone(title: "Milestone 1")
        let milestone2 = Milestone(title: "Milestone 2")

        goal.milestones = [milestone1, milestone2]
        try await service.createGoal(goal)

        try await service.completeMilestone(milestoneID: milestone1.id, in: goal.id)

        let goals = try await service.fetchGoals()
        #expect(goals[0].progress == 0.5) // 1 of 2 completed
    }

    // MARK: - Skill Tests

    @Test("Add skill successfully")
    func testAddSkill() async throws {
        let service = CareerService()

        let skill = Skill(
            name: "SwiftUI",
            category: .technical,
            proficiency: .beginner,
            targetProficiency: .expert
        )

        try await service.addSkill(skill)

        let skills = try await service.fetchSkills()
        #expect(skills.count == 1)
        #expect(skills[0].name == "SwiftUI")
    }

    @Test("Update skill proficiency")
    func testUpdateProficiency() async throws {
        let service = CareerService()

        let skill = Skill(
            name: "SwiftUI",
            category: .technical,
            proficiency: .beginner
        )

        try await service.addSkill(skill)
        try await service.updateProficiency(skillID: skill.id, proficiency: .intermediate)

        let skills = try await service.fetchSkills()
        #expect(skills[0].proficiency == .intermediate)
    }

    @Test("Log practice hours")
    func testLogPracticeHours() async throws {
        let service = CareerService()

        let skill = Skill(
            name: "SwiftUI",
            category: .technical,
            hoursInvested: 10.0
        )

        try await service.addSkill(skill)
        try await service.logPracticeHours(skillID: skill.id, hours: 5.0)

        let skills = try await service.fetchSkills()
        #expect(skills[0].hoursInvested == 15.0)
    }

    @Test("Filter skills by category")
    func testFilterSkillsByCategory() async throws {
        let service = CareerService()

        let skill1 = Skill(name: "SwiftUI", category: .technical)
        let skill2 = Skill(name: "Communication", category: .soft)

        try await service.addSkill(skill1)
        try await service.addSkill(skill2)

        let technicalSkills = try await service.fetchSkills(category: .technical)
        #expect(technicalSkills.count == 1)
        #expect(technicalSkills[0].name == "SwiftUI")
    }

    // MARK: - CareerReflection Tests

    @Test("Create reflection successfully")
    func testCreateCareerReflection() async throws {
        let service = CareerService()

        let reflection = CareerReflection(
            wins: "Completed feature",
            challenges: "Bug fixing",
            learnings: "Learned async/await",
            mood: .good
        )

        try await service.createCareerReflection(reflection)

        let fetched = try await service.fetchCareerReflection(for: Date())
        #expect(fetched != nil)
        #expect(fetched?.wins == "Completed feature")
    }

    @Test("Update reflection successfully")
    func testUpdateCareerReflection() async throws {
        let service = CareerService()

        var reflection = CareerReflection(
            wins: "Original wins",
            mood: .neutral
        )

        try await service.createCareerReflection(reflection)

        reflection.wins = "Updated wins"
        try await service.updateCareerReflection(reflection)

        let fetched = try await service.fetchCareerReflection(for: Date())
        #expect(fetched?.wins == "Updated wins")
    }

    @Test("Analyze mood trends")
    func testAnalyzeMoodTrends() async throws {
        let service = CareerService()

        // Create reflections with different moods
        for i in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let mood: Mood = i < 3 ? .great : .good

            let reflection = CareerReflection(
                date: date,
                mood: mood
            )

            try await service.createCareerReflection(reflection)
        }

        let trend = try await service.analyzeMoodTrends(days: 7)
        #expect(trend.periodDays == 7)
        #expect(trend.averageMood > 3.0) // Should be good to great
    }

    // MARK: - Recommendation Tests

    @Test("Generate skill gap recommendations")
    func testGenerateSkillGapRecommendations() async throws {
        let service = CareerService()

        // Create a stale skill (not practiced in 2+ weeks)
        let pastDate = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        let skill = Skill(
            name: "Rust",
            category: .technical,
            lastPracticed: pastDate
        )

        try await service.addSkill(skill)

        let recommendations = try await service.generateRecommendations(
            goals: [],
            skills: [skill],
            reflections: []
        )

        #expect(!recommendations.isEmpty)
        #expect(recommendations.contains { $0.category == .skillGap })
    }

    @Test("Generate goal alignment recommendations")
    func testGenerateGoalAlignmentRecommendations() async throws {
        let service = CareerService()

        // Create a stagnant goal (in progress but low progress)
        let goal = CareerGoal(
            title: "Stagnant Goal",
            description: "Test",
            category: .skillDevelopment,
            status: .inProgress,
            progress: 0.1 // Very low progress
        )

        try await service.createGoal(goal)

        let recommendations = try await service.generateRecommendations(
            goals: [goal],
            skills: [],
            reflections: []
        )

        #expect(!recommendations.isEmpty)
        #expect(recommendations.contains { $0.category == .goalAlignment })
    }

    @Test("Dismiss recommendation")
    func testDismissRecommendation() async throws {
        let service = CareerService()

        let skill = Skill(
            name: "Test",
            category: .technical,
            lastPracticed: Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        )

        try await service.addSkill(skill)

        let recommendations = try await service.generateRecommendations(
            goals: [],
            skills: [skill],
            reflections: []
        )

        #expect(!recommendations.isEmpty)

        try await service.dismissRecommendation(id: recommendations[0].id)

        let activeRecommendations = try await service.fetchActiveRecommendations()
        #expect(activeRecommendations.count == recommendations.count - 1)
    }

    // MARK: - SMART Validation Tests

    @Test("SMART criteria validation")
    func testSMARTValidation() {
        let goal = CareerGoal(
            title: "Learn SwiftUI",
            description: "Build 5 apps using SwiftUI",
            category: .skillDevelopment,
            targetDate: Date().addingTimeInterval(60 * 60 * 24 * 30), // 30 days
            milestones: [
                Milestone(title: "App 1"),
                Milestone(title: "App 2")
            ]
        )

        let validation = goal.isSMART

        #expect(validation.specific == true) // Has title and description
        #expect(validation.measurable == true) // Has milestones
        #expect(validation.achievable == true) // Always true
        #expect(validation.relevant == true) // Category is not .other
        #expect(validation.timeBound == true) // Has target date
        #expect(validation.allCriteriaMet == true)
        #expect(validation.score == 1.0)
    }
}
