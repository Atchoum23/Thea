import SwiftUI

/// Assessment dashboard view
public struct AssessmentDashboardView: View {
    @State private var viewModel = AssessmentViewModel()
    @State private var showingAssessmentPicker = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasActiveAssessment {
                    AssessmentTakingView(viewModel: viewModel)
                } else {
                    assessmentListView
                }
            }
            .navigationTitle("Assessments")
            .toolbar {
                if !viewModel.hasActiveAssessment {
                    Button {
                        showingAssessmentPicker = true
                    } label: {
                        Label("New Assessment", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAssessmentPicker) {
                AssessmentPickerView { type in
                    Task {
                        await viewModel.startAssessment(type)
                        showingAssessmentPicker = false
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    private var assessmentListView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Available Assessments
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Assessments")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(AssessmentType.allCases, id: \.self) { type in
                        Button {
                            Task {
                                await viewModel.startAssessment(type)
                            }
                        } label: {
                            AssessmentTypeCard(type: type)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Completed Assessments
                if !viewModel.completedAssessments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Completed Assessments")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.completedAssessments) { assessment in
                            CompletedAssessmentCard(assessment: assessment)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Assessment Type Card

private struct AssessmentTypeCard: View {
    let type: AssessmentType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text(type.displayName)
                        .font(.headline)

                    Text("\(type.questionCount) questions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }

            Text(type.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Completed Assessment Card

private struct CompletedAssessmentCard: View {
    let assessment: Assessment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: assessment.type.icon)
                    .foregroundStyle(Color(assessment.score.classification.color))

                Text(assessment.type.displayName)
                    .font(.headline)

                Spacer()

                Text(assessment.completedDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Score: \(Int(assessment.score.overall))/100")
                    .font(.subheadline)

                Spacer()

                Text(assessment.score.classification.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(assessment.score.classification.color).opacity(0.2))
                    .clipShape(Capsule())
            }

            Text(assessment.interpretation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Assessment Taking View

private struct AssessmentTakingView: View {
    @Bindable var viewModel: AssessmentViewModel
    @State private var selectedValue: Int?

    var body: some View {
        VStack(spacing: 20) {
            // Progress bar
            ProgressView(value: viewModel.progressPercentage / 100.0)
                .padding()

            Text("Question \(viewModel.currentProgress?.currentQuestionIndex ?? 0 + 1) of \(viewModel.currentProgress?.assessmentType.questionCount ?? 0)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let question = viewModel.currentQuestion {
                VStack(spacing: 20) {
                    Text(question.text)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()

                    VStack(spacing: 12) {
                        ForEach(0..<question.scaleType.options.count, id: \.self) { index in
                            Button {
                                selectedValue = index + 1
                            } label: {
                                HStack {
                                    Text(question.scaleType.options[index])
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if selectedValue == index + 1 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding()
                                .background(selectedValue == index + 1 ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    Button {
                        if let value = selectedValue,
                           let progress = viewModel.currentProgress {
                            Task {
                                await viewModel.submitResponse(
                                    assessmentID: progress.id,
                                    questionID: question.id,
                                    value: value
                                )
                                selectedValue = nil

                                // Check if completed
                                if progress.isCompleted {
                                    await viewModel.completeAssessment(assessmentID: progress.id)
                                }
                            }
                        }
                    } label: {
                        Text("Next")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedValue != nil ? Color.blue : Color.gray)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(selectedValue == nil)
                    .padding(.horizontal)
                }
            }

            Spacer()

            Button("Cancel Assessment") {
                viewModel.cancelAssessment()
            }
            .foregroundStyle(.red)
        }
    }
}

// MARK: - Assessment Picker

private struct AssessmentPickerView: View {
    let onSelect: (AssessmentType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(AssessmentType.allCases, id: \.self) { type in
                Button {
                    onSelect(type)
                } label: {
                    VStack(alignment: .leading) {
                        Text(type.displayName)
                            .font(.headline)

                        Text(type.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Choose Assessment")
            .toolbar {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AssessmentDashboardView()
}
