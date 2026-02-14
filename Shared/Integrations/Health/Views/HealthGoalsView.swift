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
                        .lineLimit(3 ... 6)

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

public struct HealthGoal: Identifiable, Sendable, Codable {
    public var id = UUID()
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

public enum GoalCategory: String, CaseIterable, Sendable, Codable {
    case sleep
    case activity
    case nutrition
    case weight
    case heart
    case mindfulness
    case general

    public var displayName: String {
        switch self {
        case .sleep: "Sleep"
        case .activity: "Activity"
        case .nutrition: "Nutrition"
        case .weight: "Weight"
        case .heart: "Heart Health"
        case .mindfulness: "Mindfulness"
        case .general: "General Health"
        }
    }

    public var icon: String {
        switch self {
        case .sleep: "bed.double.fill"
        case .activity: "figure.run"
        case .nutrition: "fork.knife"
        case .weight: "scalemass.fill"
        case .heart: "heart.fill"
        case .mindfulness: "brain.head.profile"
        case .general: "heart.text.square.fill"
        }
    }

    public var color: Color {
        switch self {
        case .sleep: .blue
        case .activity: .green
        case .nutrition: .orange
        case .weight: .purple
        case .heart: .red
        case .mindfulness: .indigo
        case .general: .pink
        }
    }
}

public struct GoalMilestone: Identifiable, Sendable, Codable {
    public var id = UUID()
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
        await loadPersistedGoalsAndRefresh()
    }

    func addGoal(_ goal: HealthGoal) async {
        activeGoals.append(goal)
        persistGoals()
    }

    func completeGoal(_ goal: HealthGoal) async {
        guard let index = activeGoals.firstIndex(where: { $0.id == goal.id }) else { return }

        var completedGoal = activeGoals.remove(at: index)
        completedGoal.completedDate = Date()
        completedGoal.isActive = false
        completedGoals.insert(completedGoal, at: 0)
        persistGoals()
    }

    func deleteGoal(_ goal: HealthGoal) async {
        activeGoals.removeAll { $0.id == goal.id }
        persistGoals()
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

    private static let goalsKey = "thea.health.goals.active"
    private static let completedGoalsKey = "thea.health.goals.completed"
    private let healthKitService = HealthKitService()

    private func loadPersistedGoalsAndRefresh() async {
        // Load persisted goals from UserDefaults
        if let data = UserDefaults.standard.data(forKey: Self.goalsKey),
           let saved = try? JSONDecoder().decode([HealthGoal].self, from: data)
        {
            activeGoals = saved
        }
        if let data = UserDefaults.standard.data(forKey: Self.completedGoalsKey),
           let saved = try? JSONDecoder().decode([HealthGoal].self, from: data)
        {
            completedGoals = saved
        }

        // Update current values from HealthKit if available
        do {
            _ = try await healthKitService.requestAuthorization()
            let today = Date()
            let summary = try await healthKitService.fetchActivityData(for: today)

            for index in activeGoals.indices {
                switch activeGoals[index].category {
                case .activity:
                    if activeGoals[index].unit == "steps" {
                        activeGoals[index].currentValue = summary.steps
                    } else if activeGoals[index].unit == "minutes" {
                        activeGoals[index].currentValue = summary.activeMinutes
                    }
                case .sleep:
                    let sleepStart = Calendar.current.date(byAdding: .hour, value: -30, to: Calendar.current.startOfDay(for: today)) ?? today
                    let sleepEnd = Calendar.current.date(byAdding: .hour, value: 12, to: Calendar.current.startOfDay(for: today)) ?? today
                    let sleepRange = DateInterval(start: sleepStart, end: sleepEnd)
                    if let records = try? await healthKitService.fetchSleepData(for: sleepRange),
                       let lastRecord = records.last
                    {
                        let hours = Int(lastRecord.endDate.timeIntervalSince(lastRecord.startDate) / 3600)
                        activeGoals[index].currentValue = hours
                    }
                default:
                    break
                }
                // Update milestone completion
                for mIndex in activeGoals[index].milestones.indices {
                    if !activeGoals[index].milestones[mIndex].isCompleted &&
                        activeGoals[index].currentValue >= activeGoals[index].milestones[mIndex].targetValue
                    {
                        activeGoals[index].milestones[mIndex].isCompleted = true
                        activeGoals[index].milestones[mIndex].completedDate = Date()
                    }
                }
            }
        } catch {
            // HealthKit unavailable — goals remain with last saved values
        }

        // Seed initial goals if none exist
        if activeGoals.isEmpty && completedGoals.isEmpty {
            activeGoals = [
                HealthGoal(
                    title: "10,000 Daily Steps",
                    description: "Walk 10,000 steps every day for better cardiovascular health",
                    category: .activity, targetValue: 10000, currentValue: 0, unit: "steps",
                    deadline: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                    milestones: [
                        GoalMilestone(title: "5,000 steps", targetValue: 5000),
                        GoalMilestone(title: "10,000 steps", targetValue: 10000)
                    ]
                ),
                HealthGoal(
                    title: "7+ Hours Sleep",
                    description: "Get at least 7 hours of quality sleep nightly",
                    category: .sleep, targetValue: 7, currentValue: 0, unit: "hours",
                    deadline: nil, milestones: []
                )
            ]
        }

        // Generate suggestions based on what goals don't exist yet
        let existingCategories = Set((activeGoals + completedGoals).map(\.category))
        suggestions = []
        if !existingCategories.contains(.heart) {
            suggestions.append(GoalSuggestion(
                title: "Lower Resting Heart Rate", description: "Improve cardiovascular fitness",
                category: .heart, icon: "heart.fill", targetValue: 60, unit: "BPM"
            ))
        }
        if !existingCategories.contains(.nutrition) {
            suggestions.append(GoalSuggestion(
                title: "Daily Protein Intake", description: "Consume 100g of protein daily",
                category: .nutrition, icon: "leaf.fill", targetValue: 100, unit: "g"
            ))
        }
        if !existingCategories.contains(.mindfulness) {
            suggestions.append(GoalSuggestion(
                title: "Daily Meditation", description: "Meditate for 10 minutes daily",
                category: .mindfulness, icon: "brain.head.profile.fill", targetValue: 30, unit: "days"
            ))
        }

        persistGoals()
    }

    private func persistGoals() {
        if let data = try? JSONEncoder().encode(activeGoals) {
            UserDefaults.standard.set(data, forKey: Self.goalsKey)
        }
        if let data = try? JSONEncoder().encode(completedGoals) {
            UserDefaults.standard.set(data, forKey: Self.completedGoalsKey)
        }
    }
}

#Preview {
    NavigationStack {
        HealthGoalsView()
    }
}
