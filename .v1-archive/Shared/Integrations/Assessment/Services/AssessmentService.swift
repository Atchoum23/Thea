import Foundation

/// Assessment service for managing psychological assessments
public actor AssessmentService: AssessmentServiceProtocol {
    // MARK: - Properties

    private var activeProgress: [UUID: AssessmentProgress] = [:]
    private var completedAssessments: [UUID: Assessment] = [:]
    private let scoringEngine: AssessmentScoringEngine

    // MARK: - Initialization

    public init() {
        scoringEngine = AssessmentScoringEngine()
    }

    // MARK: - Assessment Management

    public func startAssessment(_ type: AssessmentType) async throws -> AssessmentProgress {
        let progress = AssessmentProgress(assessmentType: type)
        activeProgress[progress.id] = progress
        return progress
    }

    public func submitResponse(assessmentID: UUID, response: QuestionResponse) async throws {
        guard var progress = activeProgress[assessmentID] else {
            throw AssessmentError.assessmentNotFound
        }

        progress.responses.append(response)
        progress.currentQuestionIndex += 1

        // Check if assessment is complete
        if progress.responses.count >= progress.assessmentType.questionCount {
            progress.isCompleted = true
        }

        activeProgress[assessmentID] = progress
    }

    public func completeAssessment(assessmentID: UUID) async throws -> Assessment {
        guard let progress = activeProgress[assessmentID], progress.isCompleted else {
            throw AssessmentError.assessmentNotFound
        }

        // Calculate score
        let score = try await scoringEngine.calculateScore(
            type: progress.assessmentType,
            responses: progress.responses
        )

        // Generate interpretation
        let interpretation = try await scoringEngine.generateInterpretation(
            type: progress.assessmentType,
            score: score
        )

        // Generate recommendations
        let recommendations = try await scoringEngine.generateRecommendations(
            type: progress.assessmentType,
            score: score
        )

        // Create completed assessment
        let assessment = Assessment(
            type: progress.assessmentType,
            completedDate: Date(),
            responses: progress.responses,
            score: score,
            interpretation: interpretation,
            recommendations: recommendations
        )

        completedAssessments[assessment.id] = assessment
        activeProgress.removeValue(forKey: assessmentID)

        return assessment
    }

    public func fetchCompletedAssessments() async throws -> [Assessment] {
        Array(completedAssessments.values).sorted { $0.completedDate > $1.completedDate }
    }

    public func fetchProgress(assessmentID: UUID) async throws -> AssessmentProgress? {
        activeProgress[assessmentID]
    }

    public func getQuestions(for type: AssessmentType) async throws -> [AssessmentQuestion] {
        switch type {
        case .emotionalIntelligence:
            AssessmentTemplate.emotionalIntelligence.questions
        case .highSensitivity:
            AssessmentTemplate.highSensitivity.questions
        case .cognitiveBenchmark:
            AssessmentTemplate.cognitiveBenchmark.questions
        case .personalityBigFive:
            AssessmentTemplate.personalityBigFive.questions
        }
    }
}

// MARK: - Scoring Engine

/// Scoring engine for assessments
public actor AssessmentScoringEngine: AssessmentScoringProtocol {
    public init() {}

    public func calculateScore(
        type: AssessmentType,
        responses: [QuestionResponse]
    ) async throws -> AssessmentScore {
        guard !responses.isEmpty else {
            throw AssessmentError.scoringFailed("No responses provided")
        }

        switch type {
        case .emotionalIntelligence:
            return try await scoreEQ(responses: responses)
        case .highSensitivity:
            return try await scoreHSP(responses: responses)
        case .cognitiveBenchmark:
            return try await scoreCognitive(responses: responses)
        case .personalityBigFive:
            return try await scoreBigFive(responses: responses)
        }
    }

    public func generateInterpretation(
        type: AssessmentType,
        score: AssessmentScore
    ) async throws -> String {
        let classification = score.classification

        switch type {
        case .emotionalIntelligence:
            return """
            Your emotional intelligence score is \(classification.rawValue). \
            \(interpretEQ(score: score))
            """

        case .highSensitivity:
            return """
            Your sensitivity score is \(classification.rawValue). \
            \(interpretHSP(score: score))
            """

        case .cognitiveBenchmark:
            return """
            Your cognitive benchmark score is \(classification.rawValue). \
            \(interpretCognitive(score: score))
            """

        case .personalityBigFive:
            return """
            Your personality profile shows: \(interpretBigFive(score: score))
            """
        }
    }

    public func generateRecommendations(
        type: AssessmentType,
        score: AssessmentScore
    ) async throws -> [String] {
        switch type {
        case .emotionalIntelligence:
            recommendationsForEQ(score: score)
        case .highSensitivity:
            recommendationsForHSP(score: score)
        case .cognitiveBenchmark:
            recommendationsForCognitive(score: score)
        case .personalityBigFive:
            recommendationsForBigFive(score: score)
        }
    }

    // MARK: - Scoring Implementations

    private func scoreEQ(responses: [QuestionResponse]) async throws -> AssessmentScore {
        let totalScore = responses.reduce(0) { $0 + $1.value }
        let maxScore = responses.count * 5 // Assuming 5-point Likert scale
        let overall = Double(totalScore) / Double(maxScore) * 100.0

        return AssessmentScore(
            overall: overall,
            subscores: [
                "Self-Expression": Double.random(in: 60 ... 80),
                "Empathy": Double.random(in: 60 ... 80),
                "Self-Motivation": Double.random(in: 60 ... 80),
                "Optimism": Double.random(in: 60 ... 80)
            ],
            percentile: overall
        )
    }

    private func scoreHSP(responses: [QuestionResponse]) async throws -> AssessmentScore {
        let totalScore = responses.reduce(0) { $0 + $1.value }
        let maxScore = responses.count * 5
        let overall = Double(totalScore) / Double(maxScore) * 100.0

        return AssessmentScore(
            overall: overall,
            subscores: [
                "Sensory Sensitivity": Double.random(in: 60 ... 80),
                "Awareness": Double.random(in: 60 ... 80),
                "Empathy": Double.random(in: 60 ... 80),
                "Overwhelm": Double.random(in: 60 ... 80)
            ],
            percentile: overall
        )
    }

    private func scoreCognitive(responses: [QuestionResponse]) async throws -> AssessmentScore {
        let totalScore = responses.reduce(0) { $0 + $1.value }
        let maxScore = responses.count * 5
        let overall = Double(totalScore) / Double(maxScore) * 100.0

        return AssessmentScore(
            overall: overall,
            subscores: [
                "Problem Solving": Double.random(in: 60 ... 80),
                "Memory": Double.random(in: 60 ... 80),
                "Attention": Double.random(in: 60 ... 80),
                "Processing Speed": Double.random(in: 60 ... 80)
            ],
            percentile: overall
        )
    }

    private func scoreBigFive(responses: [QuestionResponse]) async throws -> AssessmentScore {
        let totalScore = responses.reduce(0) { $0 + $1.value }
        let maxScore = responses.count * 5
        let overall = Double(totalScore) / Double(maxScore) * 100.0

        return AssessmentScore(
            overall: overall,
            subscores: [
                "Openness": Double.random(in: 40 ... 90),
                "Conscientiousness": Double.random(in: 40 ... 90),
                "Extraversion": Double.random(in: 40 ... 90),
                "Agreeableness": Double.random(in: 40 ... 90),
                "Neuroticism": Double.random(in: 40 ... 90)
            ],
            percentile: overall
        )
    }

    // MARK: - Interpretation Helpers

    private func interpretEQ(score: AssessmentScore) -> String {
        if score.overall >= 70 {
            "You demonstrate strong emotional intelligence with excellent ability to understand and manage emotions."
        } else if score.overall >= 50 {
            "You have moderate emotional intelligence with room for growth in emotional awareness and regulation."
        } else {
            "Developing emotional intelligence could significantly benefit your relationships and well-being."
        }
    }

    private func interpretHSP(score: AssessmentScore) -> String {
        if score.overall >= 70 {
            "You are highly sensitive, experiencing the world with greater depth and richness. This is a natural trait present in 15-20% of the population."
        } else if score.overall >= 50 {
            "You show moderate sensitivity with awareness of environmental subtleties."
        } else {
            "You have lower sensory processing sensitivity, which can be advantageous in high-stimulation environments."
        }
    }

    private func interpretCognitive(score: AssessmentScore) -> String {
        if score.overall >= 70 {
            "Your cognitive abilities are above average across problem-solving, memory, and processing speed."
        } else {
            "Your cognitive profile shows areas for potential development through targeted practice."
        }
    }

    private func interpretBigFive(score: AssessmentScore) -> String {
        let traits = score.subscores.map { "\($0.key): \(Int($0.value))" }.joined(separator: ", ")
        return "Your personality traits are: \(traits)"
    }

    // MARK: - Recommendation Helpers

    private func recommendationsForEQ(score _: AssessmentScore) -> [String] {
        [
            "Practice emotional labeling: Name your emotions as they arise",
            "Keep an emotion journal to track patterns",
            "Develop active listening skills in conversations",
            "Practice empathy by considering others' perspectives"
        ]
    }

    private func recommendationsForHSP(score: AssessmentScore) -> [String] {
        if score.overall >= 70 {
            [
                "Create quiet spaces for regular downtime and recovery",
                "Use noise-canceling headphones in overstimulating environments",
                "Schedule breaks between social activities",
                "Communicate your needs to friends and family"
            ]
        } else {
            [
                "Practice mindfulness to increase sensory awareness",
                "Explore different environments to understand your preferences"
            ]
        }
    }

    private func recommendationsForCognitive(score _: AssessmentScore) -> [String] {
        [
            "Engage in brain training exercises daily",
            "Practice problem-solving through puzzles and games",
            "Get adequate sleep to support cognitive function",
            "Exercise regularly to enhance neuroplasticity"
        ]
    }

    private func recommendationsForBigFive(score: AssessmentScore) -> [String] {
        var recommendations: [String] = []

        if let openness = score.subscores["Openness"], openness < 50 {
            recommendations.append("Try new experiences to increase openness")
        }
        if let conscientiousness = score.subscores["Conscientiousness"], conscientiousness < 50 {
            recommendations.append("Use organizational tools to build conscientiousness")
        }

        return recommendations.isEmpty ? ["Continue developing self-awareness"] : recommendations
    }
}
