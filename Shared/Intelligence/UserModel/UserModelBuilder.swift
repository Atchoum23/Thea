//
//  UserModelBuilder.swift
//  Thea
//
//  Builds a comprehensive understanding of the user from behavioral patterns,
//  preferences, communication style, and interaction history.
//  Enables deep personalization of responses and suggestions.
//

import Foundation
import Observation
import os.log

private let userModelLogger = Logger(subsystem: "ai.thea.app", category: "UserModelBuilder")

// MARK: - User Profile

public struct UserProfile: Sendable {
    public let id: UUID
    public var communicationStyle: CommunicationStyle
    public var technicalProfile: TechnicalProfile
    public var workHabits: WorkHabits
    public var learningStyle: UserLearningStyle
    public var preferences: UserPreferences
    public var stressIndicators: StressIndicators
    public var createdAt: Date
    public var lastUpdated: Date

    public init(
        id: UUID = UUID(),
        communicationStyle: CommunicationStyle = CommunicationStyle(),
        technicalProfile: TechnicalProfile = TechnicalProfile(),
        workHabits: WorkHabits = WorkHabits(),
        learningStyle: UserLearningStyle = UserLearningStyle(),
        preferences: UserPreferences = UserPreferences(),
        stressIndicators: StressIndicators = StressIndicators(),
        createdAt: Date = Date(),
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.communicationStyle = communicationStyle
        self.technicalProfile = technicalProfile
        self.workHabits = workHabits
        self.learningStyle = learningStyle
        self.preferences = preferences
        self.stressIndicators = stressIndicators
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Communication Style

public struct CommunicationStyle: Sendable {
    public var verbosityPreference: Double       // 0 = concise, 1 = detailed
    public var formalityLevel: Double            // 0 = casual, 1 = formal
    public var technicalDepth: Double            // 0 = simplified, 1 = expert
    public var examplePreference: Double         // 0 = abstract, 1 = concrete examples
    public var questioningStyle: QuestioningStyle
    public var feedbackStyle: FeedbackStyle
    public var averageQueryLength: Double
    public var usesCodeBlocks: Bool
    public var prefersStructuredResponses: Bool

    public enum QuestioningStyle: String, Sendable {
        case direct      // "How do I X?"
        case contextual  // "I'm trying to do Y, and need X"
        case exploratory // "What are the options for X?"
        case debugging   // "X doesn't work, why?"
    }

    public enum FeedbackStyle: String, Sendable {
        case explicit    // Clear yes/no feedback
        case implicit    // Behavioral signals
        case detailed    // Explains what worked/didn't
        case minimal     // Little feedback given
    }

    public init(
        verbosityPreference: Double = 0.5,
        formalityLevel: Double = 0.5,
        technicalDepth: Double = 0.5,
        examplePreference: Double = 0.5,
        questioningStyle: QuestioningStyle = .direct,
        feedbackStyle: FeedbackStyle = .implicit,
        averageQueryLength: Double = 50,
        usesCodeBlocks: Bool = false,
        prefersStructuredResponses: Bool = true
    ) {
        self.verbosityPreference = verbosityPreference
        self.formalityLevel = formalityLevel
        self.technicalDepth = technicalDepth
        self.examplePreference = examplePreference
        self.questioningStyle = questioningStyle
        self.feedbackStyle = feedbackStyle
        self.averageQueryLength = averageQueryLength
        self.usesCodeBlocks = usesCodeBlocks
        self.prefersStructuredResponses = prefersStructuredResponses
    }
}

// MARK: - Technical Profile

public struct TechnicalProfile: Sendable {
    public var overallLevel: ExpertiseLevel
    public var domainExpertise: [String: ExpertiseLevel]
    public var preferredLanguages: [String]
    public var preferredFrameworks: [String]
    public var codeStyle: CodeStylePreferences
    public var errorHandlingApproach: ErrorHandlingApproach
    public var debuggingSkill: Double             // 0 = needs help, 1 = self-sufficient

    public enum ExpertiseLevel: String, Sendable {
        case beginner     // Needs explanations
        case intermediate // Understands concepts
        case advanced     // Can handle complexity
        case expert       // Deep knowledge
    }

    public enum ErrorHandlingApproach: String, Sendable {
        case cautious     // Lots of error checking
        case balanced     // Standard practices
        case optimistic   // Minimal checking
        case robust       // Comprehensive handling
    }

    public struct CodeStylePreferences: Sendable {
        public var prefersFunctional: Bool
        public var prefersOOP: Bool
        public var usesComments: Bool
        public var prefersVerboseNames: Bool
        public var indentationStyle: String

        public init(
            prefersFunctional: Bool = false,
            prefersOOP: Bool = true,
            usesComments: Bool = true,
            prefersVerboseNames: Bool = true,
            indentationStyle: String = "spaces"
        ) {
            self.prefersFunctional = prefersFunctional
            self.prefersOOP = prefersOOP
            self.usesComments = usesComments
            self.prefersVerboseNames = prefersVerboseNames
            self.indentationStyle = indentationStyle
        }
    }

    public init(
        overallLevel: ExpertiseLevel = .intermediate,
        domainExpertise: [String: ExpertiseLevel] = [:],
        preferredLanguages: [String] = [],
        preferredFrameworks: [String] = [],
        codeStyle: CodeStylePreferences = CodeStylePreferences(),
        errorHandlingApproach: ErrorHandlingApproach = .balanced,
        debuggingSkill: Double = 0.5
    ) {
        self.overallLevel = overallLevel
        self.domainExpertise = domainExpertise
        self.preferredLanguages = preferredLanguages
        self.preferredFrameworks = preferredFrameworks
        self.codeStyle = codeStyle
        self.errorHandlingApproach = errorHandlingApproach
        self.debuggingSkill = debuggingSkill
    }
}

// MARK: - Work Habits

public struct WorkHabits: Sendable {
    public var peakProductivityHours: [Int]      // 0-23
    public var averageSessionDuration: TimeInterval
    public var breakFrequency: Double             // breaks per hour
    public var multitaskingTendency: Double       // 0 = focused, 1 = multitasker
    public var planningStyle: PlanningStyle
    public var taskApproach: TaskApproach
    public var deadlineResponse: DeadlineResponse
    public var preferredWorkBlocks: TimeInterval  // preferred uninterrupted work time

    public enum PlanningStyle: String, Sendable {
        case detailed    // Plans everything
        case flexible    // General direction
        case reactive    // Responds to needs
        case structured  // Follows frameworks
    }

    public enum TaskApproach: String, Sendable {
        case sequential  // One at a time
        case parallel    // Multiple streams
        case iterative   // Build up gradually
        case focused     // Deep work on one thing
    }

    public enum DeadlineResponse: String, Sendable {
        case early       // Finishes ahead
        case steady      // Consistent pace
        case lastMinute  // Works under pressure
        case flexible    // Adapts as needed
    }

    public init(
        peakProductivityHours: [Int] = [9, 10, 11, 14, 15],
        averageSessionDuration: TimeInterval = 3600,
        breakFrequency: Double = 1.0,
        multitaskingTendency: Double = 0.3,
        planningStyle: PlanningStyle = .flexible,
        taskApproach: TaskApproach = .iterative,
        deadlineResponse: DeadlineResponse = .steady,
        preferredWorkBlocks: TimeInterval = 1800
    ) {
        self.peakProductivityHours = peakProductivityHours
        self.averageSessionDuration = averageSessionDuration
        self.breakFrequency = breakFrequency
        self.multitaskingTendency = multitaskingTendency
        self.planningStyle = planningStyle
        self.taskApproach = taskApproach
        self.deadlineResponse = deadlineResponse
        self.preferredWorkBlocks = preferredWorkBlocks
    }
}

// MARK: - Learning Style

public struct UserLearningStyle: Sendable {
    public var preferredMethod: LearningMethod
    public var pacingPreference: Double          // 0 = slow/thorough, 1 = fast/overview
    public var retentionStyle: RetentionStyle
    public var curiosityLevel: Double            // 0 = focused, 1 = exploratory
    public var prefersAnalogies: Bool
    public var learnsFromErrors: Bool
    public var seeksFeedback: Bool

    public enum LearningMethod: String, Sendable {
        case reading      // Documentation/articles
        case examples     // Code samples
        case interactive  // Try and learn
        case visual       // Diagrams/videos
        case discussion   // Q&A style
    }

    public enum RetentionStyle: String, Sendable {
        case notes        // Takes notes
        case practice     // Learns by doing
        case review       // Periodic review
        case application  // Uses immediately
    }

    public init(
        preferredMethod: LearningMethod = .examples,
        pacingPreference: Double = 0.5,
        retentionStyle: RetentionStyle = .practice,
        curiosityLevel: Double = 0.6,
        prefersAnalogies: Bool = true,
        learnsFromErrors: Bool = true,
        seeksFeedback: Bool = true
    ) {
        self.preferredMethod = preferredMethod
        self.pacingPreference = pacingPreference
        self.retentionStyle = retentionStyle
        self.curiosityLevel = curiosityLevel
        self.prefersAnalogies = prefersAnalogies
        self.learnsFromErrors = learnsFromErrors
        self.seeksFeedback = seeksFeedback
    }
}

// MARK: - User Preferences

public struct UserPreferences: Sendable {
    public var preferredAIModel: String?
    public var preferredResponseFormat: ResponseFormat
    public var codeLanguagePreferences: [String: Double]
    public var topicInterests: [String: Double]
    public var avoidTopics: [String]
    public var prefersDarkMode: Bool
    public var notificationPreference: NotificationPreference
    public var proactivityLevel: Double          // 0 = only when asked, 1 = highly proactive

    public enum ResponseFormat: String, Sendable {
        case conversational  // Natural language
        case structured      // Headers, lists
        case minimal         // Just the answer
        case detailed        // Full explanation
        case codeFirst       // Lead with code
    }

    public enum NotificationPreference: String, Sendable {
        case all             // Everything
        case important       // Key updates only
        case minimal         // Critical only
        case none            // Silent
    }

    public init(
        preferredAIModel: String? = nil,
        preferredResponseFormat: ResponseFormat = .structured,
        codeLanguagePreferences: [String: Double] = [:],
        topicInterests: [String: Double] = [:],
        avoidTopics: [String] = [],
        prefersDarkMode: Bool = true,
        notificationPreference: NotificationPreference = .important,
        proactivityLevel: Double = 0.6
    ) {
        self.preferredAIModel = preferredAIModel
        self.preferredResponseFormat = preferredResponseFormat
        self.codeLanguagePreferences = codeLanguagePreferences
        self.topicInterests = topicInterests
        self.avoidTopics = avoidTopics
        self.prefersDarkMode = prefersDarkMode
        self.notificationPreference = notificationPreference
        self.proactivityLevel = proactivityLevel
    }
}

// MARK: - Stress Indicators

public struct StressIndicators: Sendable {
    public var currentStressLevel: Double        // 0 = relaxed, 1 = stressed
    public var frustrationPatterns: [String]
    public var recoveryBehaviors: [String]
    public var stressTriggers: [String]
    public var calmingFactors: [String]
    public var lastStressEvent: Date?
    public var stressHistory: [(level: Double, timestamp: Date)]

    public init(
        currentStressLevel: Double = 0.2,
        frustrationPatterns: [String] = [],
        recoveryBehaviors: [String] = [],
        stressTriggers: [String] = [],
        calmingFactors: [String] = [],
        lastStressEvent: Date? = nil,
        stressHistory: [(level: Double, timestamp: Date)] = []
    ) {
        self.currentStressLevel = currentStressLevel
        self.frustrationPatterns = frustrationPatterns
        self.recoveryBehaviors = recoveryBehaviors
        self.stressTriggers = stressTriggers
        self.calmingFactors = calmingFactors
        self.lastStressEvent = lastStressEvent
        self.stressHistory = stressHistory
    }
}

// MARK: - Observation Record

public struct ObservationRecord: Identifiable, Sendable {
    public let id: UUID
    public let type: ObservationType
    public let value: String
    public let confidence: Double
    public let timestamp: Date
    public let context: [String: String]

    public enum ObservationType: String, Sendable {
        case queryPattern
        case responseReaction
        case codeStyle
        case errorResponse
        case topicInterest
        case workTiming
        case frustrationSignal
        case satisfactionSignal
        case learningBehavior
        case preferenceExpressed
    }

    public init(
        id: UUID = UUID(),
        type: ObservationType,
        value: String,
        confidence: Double,
        timestamp: Date = Date(),
        context: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.confidence = confidence
        self.timestamp = timestamp
        self.context = context
    }
}

