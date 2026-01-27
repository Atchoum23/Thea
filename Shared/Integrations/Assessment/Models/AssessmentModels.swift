import Foundation

// MARK: - Assessment

/// Represents a completed assessment
public struct Assessment: Sendable, Codable, Identifiable {
    public let id: UUID
    public var type: AssessmentType
    public var completedDate: Date
    public var responses: [QuestionResponse]
    public var score: AssessmentScore
    public var interpretation: String
    public var recommendations: [String]

    public init(
        id: UUID = UUID(),
        type: AssessmentType,
        completedDate: Date = Date(),
        responses: [QuestionResponse],
        score: AssessmentScore,
        interpretation: String,
        recommendations: [String] = []
    ) {
        self.id = id
        self.type = type
        self.completedDate = completedDate
        self.responses = responses
        self.score = score
        self.interpretation = interpretation
        self.recommendations = recommendations
    }
}

// MARK: - Assessment Types

/// Types of assessments available
public enum AssessmentType: String, Sendable, Codable, CaseIterable {
    case emotionalIntelligence = "Emotional Intelligence (TEIQue-SF)"
    case highSensitivity = "Highly Sensitive Person (HSP)"
    case cognitiveBenchmark = "Cognitive Benchmark"
    case personalityBigFive = "Big Five Personality"

    public var displayName: String { rawValue }

    public var questionCount: Int {
        switch self {
        case .emotionalIntelligence: 30 // TEIQue Short Form
        case .highSensitivity: 27 // Aron HSP Scale
        case .cognitiveBenchmark: 20
        case .personalityBigFive: 50 // BFI-2
        }
    }

    public var icon: String {
        switch self {
        case .emotionalIntelligence: "brain.head.profile"
        case .highSensitivity: "heart.text.square.fill"
        case .cognitiveBenchmark: "chart.line.uptrend.xyaxis"
        case .personalityBigFive: "person.crop.circle.fill"
        }
    }

    public var description: String {
        switch self {
        case .emotionalIntelligence:
            "Measures ability to perceive, use, understand, and manage emotions"
        case .highSensitivity:
            "Evaluates sensory processing sensitivity and environmental awareness"
        case .cognitiveBenchmark:
            "Assesses reasoning, problem-solving, and processing speed"
        case .personalityBigFive:
            "Measures openness, conscientiousness, extraversion, agreeableness, neuroticism"
        }
    }
}

// MARK: - Question & Response

/// Assessment question
public struct AssessmentQuestion: Sendable, Codable, Identifiable {
    public let id: UUID
    public let text: String
    public let category: String?
    public let scaleType: ScaleType

    public init(
        id: UUID = UUID(),
        text: String,
        category: String? = nil,
        scaleType: ScaleType = .likert5
    ) {
        self.id = id
        self.text = text
        self.category = category
        self.scaleType = scaleType
    }
}

/// Scale type for questions
public enum ScaleType: String, Sendable, Codable {
    case likert5 = "1-5 (Strongly Disagree to Strongly Agree)"
    case likert7 = "1-7 (Strongly Disagree to Strongly Agree)"
    case yesNo = "Yes/No"
    case frequency = "Never to Always"

    public var options: [String] {
        switch self {
        case .likert5:
            ["Strongly Disagree", "Disagree", "Neutral", "Agree", "Strongly Agree"]
        case .likert7:
            ["Strongly Disagree", "Disagree", "Slightly Disagree", "Neutral", "Slightly Agree", "Agree", "Strongly Agree"]
        case .yesNo:
            ["No", "Yes"]
        case .frequency:
            ["Never", "Rarely", "Sometimes", "Often", "Always"]
        }
    }
}

/// User's response to a question
public struct QuestionResponse: Sendable, Codable, Identifiable {
    public let id: UUID
    public let questionID: UUID
    public var value: Int // Numeric value for scoring
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        questionID: UUID,
        value: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.questionID = questionID
        self.value = value
        self.timestamp = timestamp
    }
}

// MARK: - Assessment Score

/// Score for a completed assessment
public struct AssessmentScore: Sendable, Codable {
    public var overall: Double // 0.0 to 100.0
    public var subscores: [String: Double] // Category scores
    public var percentile: Double? // Compared to general population

    public init(
        overall: Double,
        subscores: [String: Double] = [:],
        percentile: Double? = nil
    ) {
        self.overall = overall
        self.subscores = subscores
        self.percentile = percentile
    }

    /// Classification based on score
    public var classification: ScoreClassification {
        switch overall {
        case 0 ..< 20: .veryLow
        case 20 ..< 40: .low
        case 40 ..< 60: .average
        case 60 ..< 80: .high
        case 80 ... 100: .veryHigh
        default: .average
        }
    }
}

public enum ScoreClassification: String, Sendable, Codable {
    case veryLow = "Very Low"
    case low = "Low"
    case average = "Average"
    case high = "High"
    case veryHigh = "Very High"

    public var color: String {
        switch self {
        case .veryLow: "red"
        case .low: "orange"
        case .average: "blue"
        case .high: "green"
        case .veryHigh: "purple"
        }
    }
}

// MARK: - Assessment Templates

/// Predefined assessment templates
public struct AssessmentTemplate: Sendable {
    public let type: AssessmentType
    public let questions: [AssessmentQuestion]

    public init(type: AssessmentType, questions: [AssessmentQuestion]) {
        self.type = type
        self.questions = questions
    }

    /// TEIQue Short Form (30 items)
    public static let emotionalIntelligence = AssessmentTemplate(
        type: .emotionalIntelligence,
        questions: [
            AssessmentQuestion(text: "I'm usually able to express my emotions when I want to", category: "Self-Expression"),
            AssessmentQuestion(text: "I often find it difficult to see things from another person's viewpoint", category: "Empathy"),
            AssessmentQuestion(text: "On the whole, I'm a highly motivated person", category: "Self-Motivation"),
            AssessmentQuestion(text: "I would normally find it difficult to keep myself motivated", category: "Self-Motivation"),
            AssessmentQuestion(text: "I generally believe that things will work out fine in my life", category: "Optimism")
            // ... Additional 25 questions would be added here
        ]
    )

    /// HSP Scale (27 items)
    public static let highSensitivity = AssessmentTemplate(
        type: .highSensitivity,
        questions: [
            AssessmentQuestion(text: "Are you easily overwhelmed by strong sensory input?", category: "Sensory Sensitivity"),
            AssessmentQuestion(text: "Do you seem to be aware of subtleties in your environment?", category: "Awareness"),
            AssessmentQuestion(text: "Do other people's moods affect you?", category: "Empathy"),
            AssessmentQuestion(text: "Do you tend to be more sensitive to pain?", category: "Physical Sensitivity"),
            AssessmentQuestion(text: "Do you find yourself needing to withdraw during busy days?", category: "Overwhelm")
            // ... Additional 22 questions would be added here
        ]
    )

    /// Cognitive Benchmark (20 items)
    public static let cognitiveBenchmark = AssessmentTemplate(
        type: .cognitiveBenchmark,
        questions: [
            AssessmentQuestion(text: "I can quickly solve complex problems", category: "Problem Solving"),
            AssessmentQuestion(text: "I easily remember names and faces", category: "Memory"),
            AssessmentQuestion(text: "I can focus on tasks without getting distracted", category: "Attention"),
            AssessmentQuestion(text: "I process information quickly", category: "Processing Speed"),
            AssessmentQuestion(text: "I can see patterns others miss", category: "Pattern Recognition")
            // ... Additional 15 questions would be added here
        ]
    )

    /// Big Five Personality (50 items)
    public static let personalityBigFive = AssessmentTemplate(
        type: .personalityBigFive,
        questions: [
            AssessmentQuestion(text: "I am someone who is talkative", category: "Extraversion"),
            AssessmentQuestion(text: "I am someone who tends to find fault with others", category: "Agreeableness"),
            AssessmentQuestion(text: "I am someone who does a thorough job", category: "Conscientiousness"),
            AssessmentQuestion(text: "I am someone who is depressed, blue", category: "Neuroticism"),
            AssessmentQuestion(text: "I am someone who is original, comes up with new ideas", category: "Openness")
            // ... Additional 45 questions would be added here
        ]
    )
}

// MARK: - Assessment Progress

/// Tracks progress through an assessment
public struct AssessmentProgress: Sendable, Codable, Identifiable {
    public let id: UUID
    public var assessmentType: AssessmentType
    public var currentQuestionIndex: Int
    public var responses: [QuestionResponse]
    public var startedDate: Date
    public var isCompleted: Bool

    public init(
        id: UUID = UUID(),
        assessmentType: AssessmentType,
        currentQuestionIndex: Int = 0,
        responses: [QuestionResponse] = [],
        startedDate: Date = Date(),
        isCompleted: Bool = false
    ) {
        self.id = id
        self.assessmentType = assessmentType
        self.currentQuestionIndex = currentQuestionIndex
        self.responses = responses
        self.startedDate = startedDate
        self.isCompleted = isCompleted
    }

    public var progressPercentage: Double {
        let totalQuestions = assessmentType.questionCount
        return Double(responses.count) / Double(totalQuestions) * 100.0
    }
}

// MARK: - Errors

public enum AssessmentError: Error, LocalizedError, Sendable {
    case invalidResponse
    case assessmentNotFound
    case scoringFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid assessment response"
        case .assessmentNotFound:
            "Assessment not found"
        case let .scoringFailed(reason):
            "Failed to score assessment: \(reason)"
        }
    }
}
