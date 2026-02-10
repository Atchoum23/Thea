import SwiftUI

/// Nutrition dashboard view
public struct NutritionDashboardView: View {
    @State private var viewModel = NutritionViewModel()
    @State private var showingMealLogger = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Calorie Progress
                    calorieProgressSection

                    // Macro Progress
                    macroProgressSection

                    // Today's Meals
                    mealsSection

                    // Insights
                    if !viewModel.insights.isEmpty {
                        insightsSection
                    }

                    // Deficiencies
                    if viewModel.hasDeficiencies {
                        deficienciesSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Nutrition")
            .toolbar {
                Button {
                    showingMealLogger = true
                } label: {
                    Label("Log Meal", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingMealLogger) {
                MealLoggerView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadTodayData()
            }
            .refreshable {
                await viewModel.refreshData()
            }
        }
    }

    // MARK: - Calorie Progress Section

    private var calorieProgressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Calories")
                    .font(.headline)
                Spacer()
                Text("\(Int(viewModel.caloriesConsumed)) / \(Int(viewModel.nutritionGoals.dailyCalories))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.calorieProgress)
                .tint(viewModel.calorieProgress > 1.0 ? .red : .blue)

            Text("\(Int(viewModel.caloriesRemaining)) cal remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Macro Progress Section

    private var macroProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macronutrients")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 16) {
                MacroProgressCard(
                    name: "Protein",
                    current: Int(viewModel.todaySummary?.totalNutrients.protein ?? 0),
                    goal: Int(viewModel.nutritionGoals.proteinGrams),
                    unit: "g",
                    color: .blue,
                    progress: viewModel.proteinProgress
                )

                MacroProgressCard(
                    name: "Carbs",
                    current: Int(viewModel.todaySummary?.totalNutrients.carbohydrates ?? 0),
                    goal: Int(viewModel.nutritionGoals.carbsGrams),
                    unit: "g",
                    color: .green,
                    progress: viewModel.carbsProgress
                )

                MacroProgressCard(
                    name: "Fat",
                    current: Int(viewModel.todaySummary?.totalNutrients.totalFat ?? 0),
                    goal: Int(viewModel.nutritionGoals.fatGrams),
                    unit: "g",
                    color: .orange,
                    progress: viewModel.fatProgress
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Meals Section

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Meals")
                .font(.headline)
                .padding(.horizontal)

            if viewModel.todayMeals.isEmpty {
                Text("No meals logged yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.todayMeals) { meal in
                    MealCard(meal: meal)
                }
            }
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.insights) { insight in
                NutritionInsightCard(insight: insight)
            }
        }
    }

    // MARK: - Deficiencies Section

    private var deficienciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrient Deficiencies")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.deficiencies) { deficiency in
                DeficiencyCard(deficiency: deficiency)
            }
        }
    }
}

// MARK: - Macro Progress Card

private struct MacroProgressCard: View {
    let name: String
    let current: Int
    let goal: Int
    let unit: String
    let color: Color
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)

            CircularProgressView(progress: progress, color: color)
                .frame(width: 60, height: 60)

            Text("\(current) / \(goal) \(unit)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Circular Progress View

private struct CircularProgressView: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 6)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .bold()
        }
    }
}

// MARK: - Meal Card

private struct MealCard: View {
    let meal: MealEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: meal.mealType.icon)
                    .foregroundStyle(.blue)

                Text(meal.mealType.rawValue)
                    .font(.headline)

                Spacer()

                Text(meal.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(Int(meal.totalCalories)) calories")
                .font(.subheadline)

            if !meal.foodItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(meal.foodItems) { item in
                        Text("• \(item.foodItem.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let notes = meal.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Nutrition Insight Card

private struct NutritionInsightCard: View {
    let insight: NutritionInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForSeverity(insight.severity))
                .foregroundStyle(Color(insight.severity.color))
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)

                Text(insight.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(insight.severity.color).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func iconForSeverity(_ severity: NutritionInsightSeverity) -> String {
        switch severity {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Deficiency Card

private struct DeficiencyCard: View {
    let deficiency: NutrientDeficiency

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(deficiency.nutrientName)
                    .font(.headline)

                Spacer()

                Text("\(Int(deficiency.deficitPercent))% below")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Capsule())
            }

            Text("\(Int(deficiency.currentAmount)) / \(Int(deficiency.recommendedAmount))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !deficiency.foodSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Try these foods:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(deficiency.foodSuggestions.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Meal Logger View

private struct MealLoggerView: View {
    @Bindable var viewModel: NutritionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMealType: MealType = .breakfast
    @State private var searchQuery = ""
    @State private var selectedFoods: [FoodItemEntry] = []
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal Type") {
                    Picker("Type", selection: $selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Search Food") {
                    TextField("Search...", text: $searchQuery)
                        .onChange(of: searchQuery) { _, newValue in
                            Task {
                                await viewModel.searchFood(query: newValue)
                            }
                        }

                    if !viewModel.searchResults.isEmpty {
                        ForEach(viewModel.searchResults) { food in
                            Button {
                                selectedFoods.append(FoodItemEntry(foodItem: food))
                            } label: {
                                Text(food.name)
                            }
                        }
                    }
                }

                if !selectedFoods.isEmpty {
                    Section("Selected Foods") {
                        ForEach(selectedFoods) { entry in
                            Text(entry.foodItem.name)
                        }
                        .onDelete { indexSet in
                            selectedFoods.remove(atOffsets: indexSet)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes...", text: $notes)
                }
            }
            .navigationTitle("Log Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.logMeal(selectedMealType, foodItems: selectedFoods, notes: notes.isEmpty ? nil : notes)
                            dismiss()
                        }
                    }
                    .disabled(selectedFoods.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NutritionDashboardView()
}
