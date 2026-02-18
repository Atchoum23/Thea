// PersonalizedLearning.swift
// Thea V2
//
// Personalized learning and skill tracking system inspired by:
// - Outskill: Personalized learning paths, mentorship, skill tracking
// - 360Learning: AI-powered collaborative learning
// - Docebo: Adaptive content recommendations

import Foundation
import OSLog

// MARK: - User Skill Profile

/// User's skill profile for personalized AI assistance
public struct UserSkillProfile: Codable, Sendable {
    public var id: UUID
    public var skills: [LearningSkill]
    public var learningGoals: [LearningGoal]
    public var preferredLearningStyle: LearningStyle
    public var experienceLevel: ExperienceLevel
    public var interests: [String]
    public var completedModules: [UUID]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        skills: [LearningSkill] = [],
        learningGoals: [LearningGoal] = [],
        preferredLearningStyle: LearningStyle = .balanced,
        experienceLevel: ExperienceLevel = .intermediate,
        interests: [String] = [],
        completedModules: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.skills = skills
        self.learningGoals = learningGoals
        self.preferredLearningStyle = preferredLearningStyle
        self.experienceLevel = experienceLevel
        self.interests = interests
        self.completedModules = completedModules
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Learning Skill

/// A learning skill with proficiency tracking (prefixed to avoid conflict with CareerModels.Skill)
public struct LearningSkill: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var category: LearningSkillCategory
    public var proficiencyLevel: LearningProficiencyLevel
    public var lastPracticed: Date?
    public var practiceCount: Int
    public var assessmentScores: [LearningAssessmentScore]

    public init(
        id: UUID = UUID(),
        name: String,
        category: LearningSkillCategory,
        proficiencyLevel: LearningProficiencyLevel = .beginner,
        lastPracticed: Date? = nil,
        practiceCount: Int = 0,
        assessmentScores: [LearningAssessmentScore] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.proficiencyLevel = proficiencyLevel
        self.lastPracticed = lastPracticed
        self.practiceCount = practiceCount
        self.assessmentScores = assessmentScores
    }

    /// Calculate average score from assessments
    public var averageScore: Double? {
        guard !assessmentScores.isEmpty else { return nil }
        let total = assessmentScores.reduce(0.0) { $0 + $1.score }
        return total / Double(assessmentScores.count)
    }
}

/// Learning skill categories (prefixed to avoid conflict with CareerModels.SkillCategory)
public enum LearningSkillCategory: String, Codable, Sendable, CaseIterable {
    case programming
    case dataScience
    case aiMl
    case devOps
    case design
    case productManagement
    case communication
    case leadership
    case domainKnowledge
    case tools

    public var displayName: String {
        switch self {
        case .programming: return "Programming"
        case .dataScience: return "Data Science"
        case .aiMl: return "AI/ML"
        case .devOps: return "DevOps"
        case .design: return "Design"
        case .productManagement: return "Product Management"
        case .communication: return "Communication"
        case .leadership: return "Leadership"
        case .domainKnowledge: return "Domain Knowledge"
        case .tools: return "Tools"
        }
    }

    public var icon: String {
        switch self {
        case .programming: return "chevron.left.forwardslash.chevron.right"
        case .dataScience: return "chart.bar.xaxis"
        case .aiMl: return "brain"
        case .devOps: return "gear.badge.checkmark"
        case .design: return "paintpalette"
        case .productManagement: return "list.clipboard"
        case .communication: return "bubble.left.and.bubble.right"
        case .leadership: return "person.3"
        case .domainKnowledge: return "books.vertical"
        case .tools: return "wrench.and.screwdriver"
        }
    }
}

/// Learning proficiency levels (prefixed to avoid conflict with CareerModels.ProficiencyLevel)
public enum LearningProficiencyLevel: String, Codable, Sendable, CaseIterable {
    case beginner
    case elementary
    case intermediate
    case advanced
    case expert

    public var displayName: String {
        rawValue.capitalized
    }

    public var numericValue: Int {
        switch self {
        case .beginner: return 1
        case .elementary: return 2
        case .intermediate: return 3
        case .advanced: return 4
        case .expert: return 5
        }
    }
}

/// Assessment score for learning (prefixed to avoid conflict with AssessmentModels)
public struct LearningAssessmentScore: Codable, Sendable {
    public let date: Date
    public let score: Double  // 0.0 - 100.0
    public let assessmentType: String
}

// MARK: - Learning Goal

/// A learning goal with progress tracking
public struct LearningGoal: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String
    public var targetDate: Date?
    public var targetSkills: [String]
    public var milestones: [LearningMilestone]
    public var status: GoalStatus
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        targetDate: Date? = nil,
        targetSkills: [String] = [],
        milestones: [LearningMilestone] = [],
        status: GoalStatus = .notStarted,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.targetDate = targetDate
        self.targetSkills = targetSkills
        self.milestones = milestones
        self.status = status
        self.createdAt = createdAt
    }

    /// Calculate progress percentage
    public var progress: Double {
        guard !milestones.isEmpty else { return 0 }
        let completed = milestones.filter { $0.isCompleted }.count
        return Double(completed) / Double(milestones.count)
    }
}

/// Learning milestone (prefixed to avoid conflict with CareerModels.Milestone)
public struct LearningMilestone: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

public enum GoalStatus: String, Codable, Sendable {
    case notStarted
    case inProgress
    case completed
    case paused
    case abandoned
}

// MARK: - Learning Style

public enum LearningStyle: String, Codable, Sendable, CaseIterable {
    case visual        // Prefers diagrams, charts, videos
    case reading       // Prefers text-based learning
    case handson       // Prefers coding exercises
    case interactive   // Prefers Q&A, discussion
    case balanced      // Mix of all styles

    public var displayName: String {
        switch self {
        case .visual: return "Visual"
        case .reading: return "Reading/Writing"
        case .handson: return "Hands-On"
        case .interactive: return "Interactive"
        case .balanced: return "Balanced"
        }
    }
}

// MARK: - Experience Level

public enum ExperienceLevel: String, Codable, Sendable, CaseIterable {
    case novice
    case beginner
    case intermediate
    case advanced
    case expert

    public var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Learning Manager

/// Manages personalized learning and skill development
@MainActor
public final class LearningManager: ObservableObject {
    public static let shared = LearningManager()

    private let logger = Logger(subsystem: "com.thea.v2", category: "LearningManager")

    @Published public var userProfile: UserSkillProfile
    @Published public private(set) var recommendedContent: [LearningContent] = []
    @Published public private(set) var dailyProgress: DailyProgress?
    @Published public private(set) var streak: Int = 0

    private var storagePath: URL {
        #if os(macOS)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".thea/learning_profile.json")
        #else
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea/learning_profile.json")
        #endif
    }

    private init() {
        userProfile = UserSkillProfile()
        Task {
            await loadProfile()
            await generateRecommendations()
        }
    }

    // MARK: - Profile Management

    /// Load user profile from storage
    public func loadProfile() async {
        guard FileManager.default.fileExists(atPath: storagePath.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: storagePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            userProfile = try decoder.decode(UserSkillProfile.self, from: data)
            logger.info("Loaded learning profile")
        } catch {
            logger.error("Failed to load learning profile: \(error.localizedDescription)")
        }
    }

    /// Save user profile to storage
    public func saveProfile() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(userProfile)

        let directory = storagePath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        try data.write(to: storagePath)
        logger.info("Saved learning profile")
    }

    // MARK: - Skill Tracking

    /// Add or update a skill
    public func updateSkill(_ skill: LearningSkill) {
        if let index = userProfile.skills.firstIndex(where: { $0.id == skill.id }) {
            userProfile.skills[index] = skill
        } else {
            userProfile.skills.append(skill)
        }
        userProfile.updatedAt = Date()

        Task {
            do { try await saveProfile() } catch { logger.error("Failed to save learning profile: \(error.localizedDescription)") }
            await generateRecommendations()
        }
    }

    /// Record skill practice
    public func recordPractice(skillId: UUID) {
        guard let index = userProfile.skills.firstIndex(where: { $0.id == skillId }) else { return }

        userProfile.skills[index].lastPracticed = Date()
        userProfile.skills[index].practiceCount += 1
        userProfile.updatedAt = Date()

        Task {
            do { try await saveProfile() } catch { logger.error("Failed to save learning profile: \(error.localizedDescription)") }
        }
    }

    /// Add assessment score to skill
    public func addAssessmentScore(skillId: UUID, score: Double, type: String) {
        guard let index = userProfile.skills.firstIndex(where: { $0.id == skillId }) else { return }

        let assessment = LearningAssessmentScore(date: Date(), score: score, assessmentType: type)
        userProfile.skills[index].assessmentScores.append(assessment)

        // Update proficiency level based on scores
        updateProficiencyLevel(skillIndex: index)
        userProfile.updatedAt = Date()

        Task {
            do { try await saveProfile() } catch { logger.error("Failed to save learning profile: \(error.localizedDescription)") }
        }
    }

    private func updateProficiencyLevel(skillIndex: Int) {
        guard let avgScore = userProfile.skills[skillIndex].averageScore else { return }

        let newLevel: LearningProficiencyLevel
        switch avgScore {
        case 0..<20: newLevel = .beginner
        case 20..<40: newLevel = .elementary
        case 40..<60: newLevel = .intermediate
        case 60..<80: newLevel = .advanced
        default: newLevel = .expert
        }

        userProfile.skills[skillIndex].proficiencyLevel = newLevel
    }

    // MARK: - Goals

    /// Add a learning goal
    public func addGoal(_ goal: LearningGoal) {
        userProfile.learningGoals.append(goal)
        userProfile.updatedAt = Date()

        Task {
            do { try await saveProfile() } catch { logger.error("Failed to save learning profile: \(error.localizedDescription)") }
        }
    }

    /// Update goal progress
    public func updateGoal(_ goal: LearningGoal) {
        if let index = userProfile.learningGoals.firstIndex(where: { $0.id == goal.id }) {
            userProfile.learningGoals[index] = goal
            userProfile.updatedAt = Date()

            Task {
                do { try await saveProfile() } catch { logger.error("Failed to save learning profile: \(error.localizedDescription)") }
            }
        }
    }

    /// Complete a milestone
    public func completeMilestone(goalId: UUID, milestoneId: UUID) {
        guard let goalIndex = userProfile.learningGoals.firstIndex(where: { $0.id == goalId }),
              let milestoneIndex = userProfile.learningGoals[goalIndex].milestones.firstIndex(where: { $0.id == milestoneId }) else {
            return
        }

        userProfile.learningGoals[goalIndex].milestones[milestoneIndex].isCompleted = true
        userProfile.learningGoals[goalIndex].milestones[milestoneIndex].completedAt = Date()

        // Check if goal is complete
        let goal = userProfile.learningGoals[goalIndex]
        if goal.progress >= 1.0 {
            userProfile.learningGoals[goalIndex].status = .completed
        } else if goal.status == .notStarted {
            userProfile.learningGoals[goalIndex].status = .inProgress
        }

        userProfile.updatedAt = Date()

        Task {
            do { try await saveProfile() } catch { logger.error("Failed to save learning profile: \(error.localizedDescription)") }
        }
    }

    // MARK: - Recommendations

    /// Generate personalized content recommendations
    public func generateRecommendations() async {
        var recommendations: [LearningContent] = []

        // Recommend based on learning goals
        for goal in userProfile.learningGoals where goal.status == .inProgress {
            for skillName in goal.targetSkills {
                let content = LearningContent(
                    id: UUID(),
                    title: "Master \(skillName)",
                    description: "Content to help achieve your goal: \(goal.title)",
                    type: .tutorial,
                    skillCategory: .programming,
                    difficulty: userProfile.experienceLevel,
                    estimatedMinutes: 30,
                    relevanceScore: 0.9
                )
                recommendations.append(content)
            }
        }

        // Recommend based on skills that need practice
        let staleSkills = userProfile.skills.filter { skill in
            guard let lastPracticed = skill.lastPracticed else { return true }
            let daysSincePractice = Calendar.current.dateComponents([.day], from: lastPracticed, to: Date()).day ?? 0
            return daysSincePractice > 7
        }

        for skill in staleSkills.prefix(3) {
            let content = LearningContent(
                id: UUID(),
                title: "Practice: \(skill.name)",
                description: "Keep your \(skill.name) skills sharp",
                type: .exercise,
                skillCategory: skill.category,
                difficulty: userProfile.experienceLevel,
                estimatedMinutes: 15,
                relevanceScore: 0.7
            )
            recommendations.append(content)
        }

        // Sort by relevance
        recommendations.sort { $0.relevanceScore > $1.relevanceScore }

        recommendedContent = Array(recommendations.prefix(10))
        logger.info("Generated \(self.recommendedContent.count) recommendations")
    }

    // MARK: - Adaptive Response

    /// Get response style based on user profile
    public func getResponseStyle() -> ResponseStyle {
        ResponseStyle(
            verbosity: userProfile.experienceLevel == .novice ? .detailed : .concise,
            codeExamples: userProfile.preferredLearningStyle == .handson,
            visualAids: userProfile.preferredLearningStyle == .visual,
            interactiveElements: userProfile.preferredLearningStyle == .interactive,
            technicalDepth: userProfile.experienceLevel.rawValue
        )
    }
}

// MARK: - Learning Content

/// Recommended learning content
public struct LearningContent: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let type: ContentType
    public let skillCategory: LearningSkillCategory
    public let difficulty: ExperienceLevel
    public let estimatedMinutes: Int
    public let relevanceScore: Double  // 0.0 - 1.0
}

public enum ContentType: String, Sendable {
    case tutorial
    case exercise
    case quiz
    case project
    case article
    case video
}

// MARK: - Daily Progress

public struct DailyProgress: Sendable {
    public let date: Date
    public var minutesLearned: Int
    public var tasksCompleted: Int
    public var skillsPracticed: [UUID]
}

// MARK: - Response Style

/// Style configuration for AI responses based on user profile
public struct ResponseStyle: Sendable {
    public let verbosity: Verbosity
    public let codeExamples: Bool
    public let visualAids: Bool
    public let interactiveElements: Bool
    public let technicalDepth: String

    public enum Verbosity: String, Sendable {
        case concise
        case moderate
        case detailed
    }
}
