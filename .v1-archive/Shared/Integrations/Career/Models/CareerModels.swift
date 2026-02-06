import Foundation

// MARK: - Skills

public struct Skill: Identifiable, Sendable, Codable {
    public let id: UUID
    public var name: String
    public var category: SkillCategory
    public var proficiency: ProficiencyLevel
    public var yearsOfExperience: Double
    public var lastPracticed: Date
    public var notes: String
    public var hoursInvested: Double
    public var targetHours: Double?
    public var targetProficiency: ProficiencyLevel?
    public var progress: Double

    public init(
        id: UUID = UUID(),
        name: String,
        category: SkillCategory,
        proficiency: ProficiencyLevel = .beginner,
        yearsOfExperience: Double = 0,
        lastPracticed: Date = Date(),
        notes: String = "",
        hoursInvested: Double = 0,
        targetHours: Double? = nil,
        targetProficiency: ProficiencyLevel? = nil,
        progress: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.proficiency = proficiency
        self.yearsOfExperience = yearsOfExperience
        self.lastPracticed = lastPracticed
        self.notes = notes
        self.hoursInvested = hoursInvested
        self.targetHours = targetHours
        self.targetProficiency = targetProficiency
        self.progress = progress
    }
}

public enum SkillCategory: String, Sendable, Codable, CaseIterable {
    case technical = "Technical"
    case soft = "Soft Skills"
    case leadership = "Leadership"
    case communication = "Communication"
    case creative = "Creative"
    case analytical = "Analytical"
    case other = "Other"

    public var icon: String {
        switch self {
        case .technical: "cpu"
        case .soft: "person.2"
        case .leadership: "crown"
        case .communication: "bubble.left.and.bubble.right"
        case .creative: "paintbrush"
        case .analytical: "chart.bar"
        case .other: "star"
        }
    }
}

public enum ProficiencyLevel: Int, Sendable, Codable, CaseIterable, Comparable {
    case beginner = 1
    case intermediate = 2
    case advanced = 3
    case expert = 4

    public static func < (lhs: ProficiencyLevel, rhs: ProficiencyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        case .expert: "Expert"
        }
    }
}

// MARK: - Learning Resources

public struct LearningResource: Identifiable, Sendable, Codable {
    public let id: UUID
    public var title: String
    public var type: ResourceType
    public var url: String?
    public var notes: String
    public var completed: Bool
    public var relatedSkills: [UUID]

    public init(
        id: UUID = UUID(),
        title: String,
        type: ResourceType,
        url: String? = nil,
        notes: String = "",
        completed: Bool = false,
        relatedSkills: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.url = url
        self.notes = notes
        self.completed = completed
        self.relatedSkills = relatedSkills
    }
}

public enum ResourceType: String, Sendable, Codable {
    case course = "Course"
    case book = "Book"
    case article = "Article"
    case video = "Video"
    case workshop = "Workshop"
    case certification = "Certification"
    case other = "Other"
}

// MARK: - Career Reflections

public struct CareerReflection: Identifiable, Sendable, Codable {
    public let id: UUID
    public var date: Date
    public var mood: Mood
    public var accomplishments: String
    public var challenges: String
    public var learnings: String
    public var gratitude: String
    public var tomorrowFocus: String
    public var tomorrowGoals: String
    public var wins: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        mood: Mood,
        accomplishments: String,
        challenges: String,
        learnings: String,
        gratitude: String = "",
        tomorrowFocus: String = "",
        tomorrowGoals: String = "",
        wins: String = ""
    ) {
        self.id = id
        self.date = date
        self.mood = mood
        self.accomplishments = accomplishments
        self.challenges = challenges
        self.learnings = learnings
        self.gratitude = gratitude
        self.tomorrowFocus = tomorrowFocus
        self.tomorrowGoals = tomorrowGoals
        self.wins = wins
    }
}

public enum Mood: String, Sendable, Codable, CaseIterable {
    case frustrated = "Frustrated"
    case stressed = "Stressed"
    case neutral = "Neutral"
    case satisfied = "Satisfied"
    case motivated = "Motivated"
    case accomplished = "Accomplished"
    case excited = "Excited"

    public var icon: String {
        switch self {
        case .frustrated: "face.frowning"
        case .stressed: "exclamationmark.triangle.fill"
        case .neutral: "face.neutral"
        case .satisfied: "face.smiling"
        case .motivated: "bolt.fill"
        case .accomplished: "star.fill"
        case .excited: "sparkles"
        }
    }

    public var color: String {
        switch self {
        case .frustrated: "#EF4444"
        case .stressed: "#F59E0B"
        case .neutral: "#6B7280"
        case .satisfied: "#10B981"
        case .motivated: "#3B82F6"
        case .accomplished: "#8B5CF6"
        case .excited: "#EC4899"
        }
    }
}

// MARK: - Growth Recommendations

public struct GrowthRecommendation: Identifiable, Sendable, Codable {
    public let id: UUID
    public var type: RecommendationType
    public var category: RecommendationType
    public var title: String
    public var description: String
    public var priority: CareerPriority
    public var actionItems: [String]
    public var dismissed: Bool
    public var estimatedTimeMinutes: Int

    public init(
        id: UUID = UUID(),
        type: RecommendationType,
        title: String,
        description: String,
        priority: CareerPriority = .medium,
        actionItems: [String] = [],
        dismissed: Bool = false,
        estimatedTimeMinutes: Int = 30
    ) {
        self.id = id
        self.type = type
        category = type
        self.title = title
        self.description = description
        self.priority = priority
        self.actionItems = actionItems
        self.dismissed = dismissed
        self.estimatedTimeMinutes = estimatedTimeMinutes
    }
}

public enum RecommendationType: String, Sendable, Codable {
    case skillDevelopment = "Skill Development"
    case networking = "Networking"
    case certification = "Certification"
    case mentorship = "Mentorship"
    case projectWork = "Project Work"
    case leadership = "Leadership Opportunity"

    public var icon: String {
        switch self {
        case .skillDevelopment: "brain.head.profile"
        case .networking: "person.2"
        case .certification: "rosette"
        case .mentorship: "person.badge.plus"
        case .projectWork: "folder.badge.gearshape"
        case .leadership: "crown"
        }
    }
}

// MARK: - Career Error

public enum CareerError: Error, Sendable, LocalizedError {
    case goalNotFound
    case skillNotFound
    case reflectionNotFound
    case invalidData
    case invalidGoal(String)
    case invalidSkill(String)
    case invalidCareerReflection(String)
    case saveFailed

    public var errorDescription: String? {
        switch self {
        case .goalNotFound:
            "Career goal not found"
        case .skillNotFound:
            "Skill not found"
        case .reflectionNotFound:
            "Reflection not found"
        case .invalidData:
            "Invalid data provided"
        case let .invalidGoal(message):
            "Invalid goal: \(message)"
        case let .invalidSkill(message):
            "Invalid skill: \(message)"
        case let .invalidCareerReflection(message):
            "Invalid career reflection: \(message)"
        case .saveFailed:
            "Failed to save career data"
        }
    }
}
