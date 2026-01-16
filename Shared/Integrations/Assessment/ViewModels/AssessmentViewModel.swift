import Foundation
import SwiftUI

/// View model for assessment dashboard
@MainActor
@Observable
public final class AssessmentViewModel {
    // MARK: - Published State

    public var completedAssessments: [Assessment] = []
    public var currentProgress: AssessmentProgress?
    public var currentQuestions: [AssessmentQuestion] = []
    public var isLoading = false
    public var errorMessage: String?

    // MARK: - Dependencies

    private let assessmentService: AssessmentService

    // MARK: - Initialization

    public init(assessmentService: AssessmentService = AssessmentService()) {
        self.assessmentService = assessmentService
    }

    // MARK: - Data Loading

    public func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            completedAssessments = try await assessmentService.fetchCompletedAssessments()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Assessment Management

    public func startAssessment(_ type: AssessmentType) async {
        do {
            currentProgress = try await assessmentService.startAssessment(type)
            currentQuestions = try await assessmentService.getQuestions(for: type)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func submitResponse(assessmentID: UUID, questionID: UUID, value: Int) async {
        let response = QuestionResponse(questionID: questionID, value: value)

        do {
            try await assessmentService.submitResponse(assessmentID: assessmentID, response: response)

            // Update progress
            if let updated = try await assessmentService.fetchProgress(assessmentID: assessmentID) {
                currentProgress = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func completeAssessment(assessmentID: UUID) async {
        do {
            let completed = try await assessmentService.completeAssessment(assessmentID: assessmentID)
            completedAssessments.insert(completed, at: 0)
            currentProgress = nil
            currentQuestions = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func cancelAssessment() {
        currentProgress = nil
        currentQuestions = []
    }

    // MARK: - Computed Properties

    public var hasActiveAssessment: Bool {
        currentProgress != nil
    }

    public var currentQuestion: AssessmentQuestion? {
        guard let progress = currentProgress,
              progress.currentQuestionIndex < currentQuestions.count else {
            return nil
        }
        return currentQuestions[progress.currentQuestionIndex]
    }

    public var progressPercentage: Double {
        currentProgress?.progressPercentage ?? 0.0
    }
}
