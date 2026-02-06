import Foundation

// MARK: - Assessment Service Protocol

/// Protocol for assessment services
public protocol AssessmentServiceProtocol: Actor {
    /// Start a new assessment
    func startAssessment(_ type: AssessmentType) async throws -> AssessmentProgress

    /// Submit a response to the current question
    func submitResponse(assessmentID: UUID, response: QuestionResponse) async throws

    /// Complete the assessment and calculate score
    func completeAssessment(assessmentID: UUID) async throws -> Assessment

    /// Fetch all completed assessments
    func fetchCompletedAssessments() async throws -> [Assessment]

    /// Fetch assessment progress
    func fetchProgress(assessmentID: UUID) async throws -> AssessmentProgress?

    /// Get questions for an assessment type
    func getQuestions(for type: AssessmentType) async throws -> [AssessmentQuestion]
}

// MARK: - Scoring Protocol

/// Protocol for assessment scoring engines
public protocol AssessmentScoringProtocol: Actor {
    /// Calculate score for an assessment
    func calculateScore(
        type: AssessmentType,
        responses: [QuestionResponse]
    ) async throws -> AssessmentScore

    /// Generate interpretation text
    func generateInterpretation(
        type: AssessmentType,
        score: AssessmentScore
    ) async throws -> String

    /// Generate personalized recommendations
    func generateRecommendations(
        type: AssessmentType,
        score: AssessmentScore
    ) async throws -> [String]
}
