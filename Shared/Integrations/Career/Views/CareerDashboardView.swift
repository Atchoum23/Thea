import SwiftUI

/// Career development dashboard view
public struct CareerDashboardView: View {
    @State private var viewModel = CareerDashboardViewModel()
    @State private var selectedTab: CareerTab = .goals

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Section", selection: $selectedTab) {
                    ForEach(CareerTab.allCases, id: \.self) { tab in
                        Label(tab.title, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                if viewModel.isLoading {
                    ProgressView("Loading career data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadData() }
                    }
                } else {
                    TabView(selection: $selectedTab) {
                        GoalsTabView(viewModel: viewModel)
                            .tag(CareerTab.goals)

                        SkillsTabView(viewModel: viewModel)
                            .tag(CareerTab.skills)

                        CareerReflectionTabView(viewModel: viewModel)
                            .tag(CareerTab.reflection)

                        RecommendationsTabView(viewModel: viewModel)
                            .tag(CareerTab.recommendations)
                    }
                    .tabViewStyle(.automatic)
                }
            }
            .navigationTitle("Career Development")
            .task {
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.refreshData()
            }
        }
    }
}

// MARK: - Career Tabs

private enum CareerTab: String, CaseIterable {
    case goals
    case skills
    case reflection
    case recommendations

    var title: String {
        switch self {
        case .goals: "Goals"
        case .skills: "Skills"
        case .reflection: "CareerReflection"
        case .recommendations: "Growth"
        }
    }

    var icon: String {
        switch self {
        case .goals: "target"
        case .skills: "brain.head.profile"
        case .reflection: "book.fill"
        case .recommendations: "lightbulb.fill"
        }
    }
}

// MARK: - Goals Tab

private struct GoalsTabView: View {
    @Bindable var viewModel: CareerDashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats
                HStack(spacing: 16) {
                    CareerStatCard(
                        title: "Active",
                        value: "\(viewModel.activeGoalsCount)",
                        icon: "arrow.forward.circle.fill",
                        color: .blue
                    )

                    CareerStatCard(
                        title: "Completed",
                        value: "\(viewModel.completedGoalsCount)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )

                    CareerStatCard(
                        title: "Progress",
                        value: "\(Int(viewModel.averageGoalProgress * 100))%",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .purple
                    )
                }
                .padding(.horizontal)

                // Goals list
                VStack(spacing: 12) {
                    ForEach(viewModel.filteredGoals) { goal in
                        GoalCard(goal: goal, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Skills Tab

private struct SkillsTabView: View {
    @Bindable var viewModel: CareerDashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats
                HStack(spacing: 16) {
                    CareerStatCard(
                        title: "In Progress",
                        value: "\(viewModel.skillsInProgress)",
                        icon: "arrow.up.right.circle.fill",
                        color: .blue
                    )

                    CareerStatCard(
                        title: "Total Hours",
                        value: "\(Int(viewModel.totalPracticeHours))",
                        icon: "clock.fill",
                        color: .orange
                    )
                }
                .padding(.horizontal)

                // Skills list
                VStack(spacing: 12) {
                    ForEach(viewModel.filteredSkills) { skill in
                        SkillCard(skill: skill, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - CareerReflection Tab

private struct CareerReflectionTabView: View {
    @Bindable var viewModel: CareerDashboardViewModel
    @State private var wins = ""
    @State private var challenges = ""
    @State private var learnings = ""
    @State private var gratitude = ""
    @State private var tomorrowGoals = ""
    @State private var selectedMood: Mood = .neutral

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Daily CareerReflection")
                    .font(.title2)
                    .bold()
                    .padding(.horizontal)

                // Mood selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("How was your day?")
                        .font(.headline)
                        .padding(.horizontal)

                    Picker("Mood", selection: $selectedMood) {
                        ForEach(Mood.allCases, id: \.self) { mood in
                            Label(mood.rawValue, systemImage: mood.icon)
                                .tag(mood)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                // CareerReflection fields
                VStack(spacing: 16) {
                    CareerReflectionField(title: "Wins", text: $wins, prompt: "What went well today?")
                    CareerReflectionField(title: "Challenges", text: $challenges, prompt: "What was difficult?")
                    CareerReflectionField(title: "Learnings", text: $learnings, prompt: "What did you learn?")
                    CareerReflectionField(title: "Gratitude", text: $gratitude, prompt: "What are you grateful for?")
                    CareerReflectionField(title: "Tomorrow's Goals", text: $tomorrowGoals, prompt: "What will you focus on tomorrow?")
                }
                .padding(.horizontal)

                Button("Save CareerReflection") {
                    Task {
                        await viewModel.createOrUpdateCareerReflection(
                            wins: wins,
                            challenges: challenges,
                            learnings: learnings,
                            gratitude: gratitude,
                            tomorrowGoals: tomorrowGoals,
                            mood: selectedMood
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear {
            if let reflection = viewModel.todayCareerReflection {
                wins = reflection.wins
                challenges = reflection.challenges
                learnings = reflection.learnings
                gratitude = reflection.gratitude
                tomorrowGoals = reflection.tomorrowGoals
                selectedMood = reflection.mood
            }
        }
    }
}

// MARK: - Recommendations Tab

private struct RecommendationsTabView: View {
    @Bindable var viewModel: CareerDashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.recommendations.isEmpty {
                    ContentUnavailableView(
                        "No Recommendations",
                        systemImage: "lightbulb",
                        description: Text("Check back later for personalized growth recommendations")
                    )
                } else {
                    ForEach(viewModel.recommendations) { recommendation in
                        CareerRecommendationCard(recommendation: recommendation, viewModel: viewModel)
                    }
                }
            }
            .padding()
        }
        .toolbar {
            Button {
                Task {
                    await viewModel.generateRecommendations()
                }
            } label: {
                Label("Generate", systemImage: "sparkles")
            }
        }
    }
}

// MARK: - Supporting Views

private struct CareerStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .bold()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct GoalCard: View {
    let goal: CareerGoal
    // periphery:ignore - Reserved: viewModel property — reserved for future feature activation
    let viewModel: CareerDashboardViewModel

// periphery:ignore - Reserved: viewModel property reserved for future feature activation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: goal.category.icon)
                    .foregroundStyle(.blue)

                Text(goal.title)
                    .font(.headline)

                Spacer()

                Text(goal.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }

            Text(goal.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: goal.progress)
                .tint(.blue)

            Text("\(Int(goal.progress * 100))% complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SkillCard: View {
    let skill: Skill
    // periphery:ignore - Reserved: viewModel property reserved for future feature activation
    let viewModel: CareerDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: skill.category.icon)
                    .foregroundStyle(.purple)

                Text(skill.name)
                    .font(.headline)

                Spacer()

                Text(skill.proficiency.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }

            HStack {
                Text("\(Int(skill.hoursInvested)) hours practiced")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Last: \(skill.lastPracticed, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: skill.progress)
                .tint(.purple)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct CareerReflectionField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .bold()

            TextEditor(text: $text)
                .frame(height: 80)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(prompt)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 16)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
}

private struct CareerRecommendationCard: View {
    let recommendation: GrowthRecommendation
    let viewModel: CareerDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: recommendation.category.icon)
                    .foregroundStyle(.orange)

                Text(recommendation.title)
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        await viewModel.dismissRecommendation(recommendation)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Text(recommendation.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !recommendation.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Actions:")
                        .font(.caption)
                        .bold()

                    ForEach(recommendation.actionItems, id: \.self) { item in
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                            Text(item)
                                .font(.caption)
                        }
                    }
                }
            }

            if recommendation.estimatedTimeMinutes > 0 {
                Text("Estimated time: \(recommendation.estimatedTimeMinutes) minutes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text(message)
                .multilineTextAlignment(.center)

            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    CareerDashboardView()
}
