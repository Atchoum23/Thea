import Charts
import SwiftUI

/// Health goal setting and tracking view
@MainActor
public struct HealthGoalsView: View {
    @State private var viewModel = HealthGoalsViewModel()
    @State private var showingAddGoal = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overview Card
                overviewCard

                // Active Goals
                activeGoalsSection

                // Completed Goals
                if !viewModel.completedGoals.isEmpty {
                    completedGoalsSection
                }

                // Goal Suggestions
                suggestionsSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Health Goals")
        .toolbar {
            Button {
                showingAddGoal = true
            } label: {
                Label("Add Goal", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadGoals()
        }
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                // Total goals
                VStack(spacing: 4) {
                    Text("\(viewModel.totalGoals)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.blue)

                    Text("Total Goals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Active goals
                VStack(spacing: 4) {
                    Text("\(viewModel.activeGoals.count)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.green)

                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Completion rate
                VStack(spacing: 4) {
                    Text("\(Int(viewModel.completionRate))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.orange)

                    Text("Completion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Overall progress bar
            VStack(spacing: 8) {
                HStack {
                    Text("Overall Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(viewModel.completedGoals.count) / \(viewModel.totalGoals) completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * (viewModel.completionRate / 100), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Active Goals Section

    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Goals")
                .font(.headline)
                .padding(.horizontal)

            if viewModel.activeGoals.isEmpty {
                EmptyGoalsView(message: "No active goals. Tap + to create one!")
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.activeGoals) { goal in
                        GoalCard(goal: goal, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Completed Goals Section

    private var completedGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed Goals")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(viewModel.completedGoals.prefix(5)) { goal in
                    CompletedGoalCard(goal: goal)
                }
            }
            .padding(.horizontal)

            if viewModel.completedGoals.count > 5 {
                Button("View All Completed Goals (\(viewModel.completedGoals.count))") {
                    // Would navigate to full list
                }
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Suggestions Section

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Goals")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(viewModel.suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion, viewModel: viewModel)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Empty Goals View

private struct EmptyGoalsView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Goal Card

private struct GoalCard: View {
    let goal: HealthGoal
    @Bindable var viewModel: HealthGoalsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.category.icon)
                    .font(.title2)
                    .foregroundStyle(goal.category.color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.headline)

                    Text(goal.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button("Edit") {
                        // Edit goal
                    }
                    Button("Mark Complete", systemImage: "checkmark.circle") {
                        Task {
                            await viewModel.completeGoal(goal)
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        Task {
                            await viewModel.deleteGoal(goal)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }

            Text(goal.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Progress
            VStack(spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(goal.progress * 100))%")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(goal.progressColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(goal.progressColor)
                            .frame(width: geometry.size.width * goal.progress, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(goal.currentValue) / \(goal.targetValue) \(goal.unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let deadline = goal.deadline {
                        Label(
                            deadline.timeIntervalSinceNow > 0 ?
                            "\(daysUntil(deadline)) days left" :
                            "Overdue",
                            systemImage: deadline.timeIntervalSinceNow > 0 ? "calendar" : "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(deadline.timeIntervalSinceNow > 0 ? Color.secondary : Color.red)
                    }
                }
            }

            // Milestones
            if !goal.milestones.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Milestones")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.secondary)

                    ForEach(goal.milestones) { milestone in
                        MilestoneRow(milestone: milestone)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(goal.category.color.opacity(0.3), lineWidth: 1)
        )
    }

    private func daysUntil(_ date: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return max(0, days)
    }
}

// MARK: - Milestone Row

private struct MilestoneRow: View {
    let milestone: GoalMilestone

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(milestone.isCompleted ? .green : .secondary)

            Text(milestone.title)
                .font(.caption)
                .foregroundStyle(milestone.isCompleted ? .secondary : .primary)
                .strikethrough(milestone.isCompleted)

            Spacer()

            if milestone.isCompleted, let date = milestone.completedDate {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Completed Goal Card

private struct CompletedGoalCard: View {
    let goal: HealthGoal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.subheadline)
                    .bold()

                if let completed = goal.completedDate {
                    Text("Completed \(completed, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(goal.category.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(goal.category.color.opacity(0.2))
                .foregroundStyle(goal.category.color)
                .clipShape(Capsule())
        }
        .padding()
        .background(Color.gray.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Suggestion Card

private struct SuggestionCard: View {
    let suggestion: GoalSuggestion
    @Bindable var viewModel: HealthGoalsViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.icon)
                .font(.title3)
                .foregroundStyle(suggestion.category.color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .bold()

                Text(suggestion.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await viewModel.createGoalFromSuggestion(suggestion)
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Add Goal View

private struct AddGoalView: View {
    @Bindable var viewModel: HealthGoalsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var category: GoalCategory = .sleep
    @State private var targetValue = ""
    @State private var unit = ""
    @State private var hasDeadline = false
    @State private var deadline = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Title", text: $title)

                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)

                    Picker("Category", selection: $category) {
                        ForEach(GoalCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                }

                Section("Target") {
                    TextField("Target Value", text: $targetValue)

                    TextField("Unit (e.g., steps, minutes, kg)", text: $unit)
                }

                Section("Deadline") {
                    Toggle("Set Deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createGoal()
                        }
                    }
                    .disabled(title.isEmpty || targetValue.isEmpty)
                }
            }
        }
    }

    private func createGoal() async {
        guard let target = Int(targetValue) else { return }

        let goal = HealthGoal(
            title: title,
            description: description,
            category: category,
            targetValue: target,
            currentValue: 0,
            unit: unit,
            deadline: hasDeadline ? deadline : nil,
            milestones: []
        )

        await viewModel.addGoal(goal)
        dismiss()
    }
}

// MARK: - Models

public struct HealthGoal: Identifiable, Sendable {
    public let id = UUID()
    public var title: String
    public var description: String
    public var category: GoalCategory
    public var targetValue: Int
    public var currentValue: Int
    public var unit: String
    public var deadline: Date?
    public var milestones: [GoalMilestone]
    public var createdDate = Date()
    public var completedDate: Date?
    public var isActive: Bool = true

    public var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1.0)
    }

    public var progressColor: Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.75 { return .blue }
        if progress >= 0.5 { return .yellow }
        return .orange
    }

    public init(
        title: String,
        description: String,
        category: GoalCategory,
        targetValue: Int,
        currentValue: Int,
        unit: String,
        deadline: Date?,
        milestones: [GoalMilestone]
    ) {
        self.title = title
        self.description = description
        self.category = category
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.deadline = deadline
        self.milestones = milestones
    }
}

public enum GoalCategory: String, CaseIterable, Sendable {
    case sleep
    case activity
    case nutrition
    case weight
    case heart
    case mindfulness
    case general

    public var displayName: String {
        switch self {
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        case .nutrition: return "Nutrition"
        case .weight: return "Weight"
        case .heart: return "Heart Health"
        case .mindfulness: return "Mindfulness"
        case .general: return "General Health"
        }
    }

    public var icon: String {
        switch self {
        case .sleep: return "bed.double.fill"
        case .activity: return "figure.run"
        case .nutrition: return "fork.knife"
        case .weight: return "scalemass.fill"
        case .heart: return "heart.fill"
        case .mindfulness: return "brain.head.profile"
        case .general: return "heart.text.square.fill"
        }
    }

    public var color: Color {
        switch self {
        case .sleep: return .blue
        case .activity: return .green
        case .nutrition: return .orange
        case .weight: return .purple
        case .heart: return .red
        case .mindfulness: return .indigo
        case .general: return .pink
        }
    }
}

public struct GoalMilestone: Identifiable, Sendable {
    public let id = UUID()
    public var title: String
    public var targetValue: Int
    public var isCompleted: Bool
    public var completedDate: Date?

    public init(title: String, targetValue: Int, isCompleted: Bool = false, completedDate: Date? = nil) {
        self.title = title
        self.targetValue = targetValue
        self.isCompleted = isCompleted
        self.completedDate = completedDate
    }
}

public struct GoalSuggestion: Identifiable, Sendable {
    public let id = UUID()
    public var title: String
    public var description: String
    public var category: GoalCategory
    public var icon: String
    public var targetValue: Int
    public var unit: String

    public init(
        title: String,
        description: String,
        category: GoalCategory,
        icon: String,
        targetValue: Int,
        unit: String
    ) {
        self.title = title
        self.description = description
        self.category = category
        self.icon = icon
        self.targetValue = targetValue
        self.unit = unit
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class HealthGoalsViewModel {
    var activeGoals: [HealthGoal] = []
    var completedGoals: [HealthGoal] = []
    var suggestions: [GoalSuggestion] = []

    var totalGoals: Int {
        activeGoals.count + completedGoals.count
    }

    var completionRate: Double {
        guard totalGoals > 0 else { return 0 }
        return Double(completedGoals.count) / Double(totalGoals) * 100
    }

    func loadGoals() async {
        // Would load from persistent storage
        // Mock data for demonstration
        await generateMockData()
    }

    func addGoal(_ goal: HealthGoal) async {
        activeGoals.append(goal)
    }

    func completeGoal(_ goal: HealthGoal) async {
        guard let index = activeGoals.firstIndex(where: { $0.id == goal.id }) else { return }

        var completedGoal = activeGoals.remove(at: index)
        completedGoal.completedDate = Date()
        completedGoal.isActive = false
        completedGoals.insert(completedGoal, at: 0)
    }

    func deleteGoal(_ goal: HealthGoal) async {
        activeGoals.removeAll { $0.id == goal.id }
    }

    func createGoalFromSuggestion(_ suggestion: GoalSuggestion) async {
        let goal = HealthGoal(
            title: suggestion.title,
            description: suggestion.description,
            category: suggestion.category,
            targetValue: suggestion.targetValue,
            currentValue: 0,
            unit: suggestion.unit,
            deadline: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            milestones: []
        )
        await addGoal(goal)
        suggestions.removeAll { $0.id == suggestion.id }
    }

    private func generateMockData() async {
        // Mock active goals
        activeGoals = [
            HealthGoal(
                title: "10,000 Daily Steps",
                description: "Walk 10,000 steps every day for better cardiovascular health",
                category: .activity,
                targetValue: 10_000,
                currentValue: 7_500,
                unit: "steps",
                deadline: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
                milestones: [
                    GoalMilestone(title: "First 5,000 steps", targetValue: 5_000, isCompleted: true, completedDate: Date().addingTimeInterval(-86_400 * 3)),
                    GoalMilestone(title: "Reach 7,500 steps", targetValue: 7_500, isCompleted: true, completedDate: Date()),
                    GoalMilestone(title: "Hit 10,000 steps", targetValue: 10_000)
                ]
            ),
            HealthGoal(
                title: "8 Hours of Sleep",
                description: "Get consistent 8 hours of quality sleep every night",
                category: .sleep,
                targetValue: 8,
                currentValue: 7,
                unit: "hours",
                deadline: nil,
                milestones: []
            ),
            HealthGoal(
                title: "Lose 5 kg",
                description: "Gradually lose 5 kg through healthy diet and exercise",
                category: .weight,
                targetValue: 5,
                currentValue: 2,
                unit: "kg",
                deadline: Calendar.current.date(byAdding: .month, value: 3, to: Date()),
                milestones: [
                    GoalMilestone(title: "Lose 2 kg", targetValue: 2, isCompleted: true, completedDate: Date().addingTimeInterval(-86_400 * 15)),
                    GoalMilestone(title: "Lose 3.5 kg", targetValue: 3, isCompleted: false),
                    GoalMilestone(title: "Reach target", targetValue: 5, isCompleted: false)
                ]
            )
        ]

        // Mock completed goals
        completedGoals = [
            HealthGoal(
                title: "30 Days of Meditation",
                description: "Meditate for 10 minutes daily for 30 consecutive days",
                category: .mindfulness,
                targetValue: 30,
                currentValue: 30,
                unit: "days",
                deadline: nil,
                milestones: []
            )
        ]
        completedGoals[0].completedDate = Date().addingTimeInterval(-86_400 * 5)
        completedGoals[0].isActive = false

        // Mock suggestions
        suggestions = [
            GoalSuggestion(
                title: "Lower Resting Heart Rate",
                description: "Improve cardiovascular fitness by lowering resting HR",
                category: .heart,
                icon: "heart.fill",
                targetValue: 60,
                unit: "BPM"
            ),
            GoalSuggestion(
                title: "Increase Protein Intake",
                description: "Consume 100g of protein daily for muscle health",
                category: .nutrition,
                icon: "leaf.fill",
                targetValue: 100,
                unit: "g"
            ),
            GoalSuggestion(
                title: "Weekly Active Minutes",
                description: "Achieve 150 minutes of moderate activity per week",
                category: .activity,
                icon: "timer",
                targetValue: 150,
                unit: "minutes"
            )
        ]
    }
}

#Preview {
    NavigationStack {
        HealthGoalsView()
    }
}
