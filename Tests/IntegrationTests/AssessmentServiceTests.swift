import Foundation
import Testing
#if SWIFT_PACKAGE
@testable import TheaCore
#else
@testable import Thea
#endif

/// Tests for assessment service
@Suite("Assessment Service Tests")
struct AssessmentServiceTests {
    // MARK: - Assessment Management Tests

    @Test("Start assessment successfully")
    func testStartAssessment() async throws {
        let service = AssessmentService()

        let progress = try await service.startAssessment(.emotionalIntelligence)

        #expect(progress.assessmentType == .emotionalIntelligence)
        #expect(progress.currentQuestionIndex == 0)
        #expect(progress.responses.isEmpty)
        #expect(!progress.isCompleted)
    }

    @Test("Submit response updates progress")
    func testSubmitResponse() async throws {
        let service = AssessmentService()
        let progress = try await service.startAssessment(.highSensitivity)
        let assessmentID = progress.id  // Use the ID from the started assessment

        let response = QuestionResponse(questionID: UUID(), value: 4)
        try await service.submitResponse(assessmentID: assessmentID, response: response)

        if let updated = try await service.fetchProgress(assessmentID: assessmentID) {
            #expect(updated.responses.count == 1)
            #expect(updated.currentQuestionIndex == 1)
        }
    }

    @Test("Get questions for assessment type")
    func testGetQuestions() async throws {
        let service = AssessmentService()

        let questions = try await service.getQuestions(for: .emotionalIntelligence)

        #expect(!questions.isEmpty)
        #expect(questions.count >= 5) // At least some questions
    }

    // MARK: - Scoring Tests

    @Test("Calculate EQ score")
    func testCalculateEQScore() async throws {
        let engine = AssessmentScoringEngine()

        let responses = (0..<30).map { _ in
            QuestionResponse(questionID: UUID(), value: Int.random(in: 1...5))
        }

        let score = try await engine.calculateScore(
            type: .emotionalIntelligence,
            responses: responses
        )

        #expect(score.overall >= 0 && score.overall <= 100)
        #expect(!score.subscores.isEmpty)
    }

    @Test("Calculate HSP score")
    func testCalculateHSPScore() async throws {
        let engine = AssessmentScoringEngine()

        let responses = (0..<27).map { _ in
            QuestionResponse(questionID: UUID(), value: Int.random(in: 1...5))
        }

        let score = try await engine.calculateScore(
            type: .highSensitivity,
            responses: responses
        )

        #expect(score.overall >= 0 && score.overall <= 100)
        #expect(score.subscores.keys.contains("Sensory Sensitivity"))
    }

    @Test("Generate interpretation for score")
    func testGenerateInterpretation() async throws {
        let engine = AssessmentScoringEngine()

        let score = AssessmentScore(overall: 75.0)
        let interpretation = try await engine.generateInterpretation(
            type: .emotionalIntelligence,
            score: score
        )

        #expect(!interpretation.isEmpty)
        #expect(interpretation.contains("emotional intelligence"))
    }

    @Test("Generate recommendations")
    func testGenerateRecommendations() async throws {
        let engine = AssessmentScoringEngine()

        let score = AssessmentScore(overall: 60.0)
        let recommendations = try await engine.generateRecommendations(
            type: .highSensitivity,
            score: score
        )

        #expect(!recommendations.isEmpty)
    }

    // MARK: - Score Classification Tests

    @Test("Score classification ranges")
    func testScoreClassification() {
        let veryLowScore = AssessmentScore(overall: 15.0)
        #expect(veryLowScore.classification == .veryLow)

        let lowScore = AssessmentScore(overall: 35.0)
        #expect(lowScore.classification == .low)

        let averageScore = AssessmentScore(overall: 55.0)
        #expect(averageScore.classification == .average)

        let highScore = AssessmentScore(overall: 75.0)
        #expect(highScore.classification == .high)

        let veryHighScore = AssessmentScore(overall: 95.0)
        #expect(veryHighScore.classification == .veryHigh)
    }

    // MARK: - Progress Tracking Tests

    @Test("Progress percentage calculation")
    func testProgressPercentage() {
        var progress = AssessmentProgress(assessmentType: .emotionalIntelligence)

        #expect(progress.progressPercentage == 0.0)

        progress.responses.append(QuestionResponse(questionID: UUID(), value: 3))
        progress.responses.append(QuestionResponse(questionID: UUID(), value: 4))

        // 2 out of 30 questions = 6.67%
        let expected = (2.0 / 30.0) * 100.0
        #expect(abs(progress.progressPercentage - expected) < 0.1)
    }
}
