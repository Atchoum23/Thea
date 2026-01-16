import Foundation
import SwiftUI

/// View model for nutrition dashboard
@MainActor
@Observable
public final class NutritionViewModel {

    // MARK: - Published State

    public var todaySummary: NutritionSummary?
    public var todayMeals: [MealEntry] = []
    public var nutritionGoals: NutritionGoals = NutritionGoals()
    public var insights: [NutritionInsight] = []
    public var deficiencies: [NutrientDeficiency] = []
    public var searchResults: [FoodItem] = []
    public var isLoading = false
    public var errorMessage: String?

    // MARK: - Dependencies

    private let nutritionService: NutritionService

    // MARK: - Initialization

    public init(nutritionService: NutritionService = NutritionService()) {
        self.nutritionService = nutritionService
    }

    // MARK: - Data Loading

    public func loadTodayData() async {
        isLoading = true
        errorMessage = nil

        do {
            let today = Date()

            // Load summary
            todaySummary = try await nutritionService.getDailySummary(for: today)

            // Load meals
            let dateRange = DateInterval(start: today.startOfDay, end: today.endOfDay)
            todayMeals = try await nutritionService.fetchMeals(for: dateRange)

            // Load goals
            nutritionGoals = try await nutritionService.fetchGoals()

            // Load insights
            insights = try await nutritionService.getInsights(for: today)

            // Load deficiencies
            deficiencies = try await nutritionService.getDeficiencies(for: today)

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func refreshData() async {
        await loadTodayData()
    }

    // MARK: - Meal Logging

    public func logMeal(_ mealType: MealType, foodItems: [FoodItemEntry], notes: String? = nil) async {
        let meal = MealEntry(
            timestamp: Date(),
            mealType: mealType,
            foodItems: foodItems,
            notes: notes
        )

        do {
            try await nutritionService.logMeal(meal)
            await loadTodayData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Food Search

    public func searchFood(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        do {
            searchResults = try await nutritionService.searchFood(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func searchByBarcode(_ barcode: String) async -> FoodItem? {
        do {
            return try await nutritionService.fetchFoodByBarcode(barcode)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Goals Management

    public func updateGoals(
        age: Int,
        biologicalSex: BiologicalSex,
        weightKg: Double,
        heightCm: Double,
        activityLevel: ActivityLevel,
        goal: NutritionGoal
    ) async {
        let calculatedGoals = NutritionGoals.calculate(
            age: age,
            biologicalSex: biologicalSex,
            weightKg: weightKg,
            heightCm: heightCm,
            activityLevel: activityLevel,
            goal: goal
        )

        do {
            try await nutritionService.updateGoals(calculatedGoals)
            nutritionGoals = calculatedGoals
            await loadTodayData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed Properties

    public var caloriesConsumed: Double {
        todaySummary?.caloriesConsumed ?? 0.0
    }

    public var caloriesRemaining: Double {
        todaySummary?.caloriesRemaining ?? nutritionGoals.dailyCalories
    }

    public var calorieProgress: Double {
        let consumed = caloriesConsumed
        let goal = nutritionGoals.dailyCalories
        return goal > 0 ? min(consumed / goal, 1.0) : 0.0
    }

    public var proteinProgress: Double {
        guard let summary = todaySummary else { return 0.0 }
        return min(summary.totalNutrients.protein / nutritionGoals.proteinGrams, 1.0)
    }

    public var carbsProgress: Double {
        guard let summary = todaySummary else { return 0.0 }
        return min(summary.totalNutrients.carbohydrates / nutritionGoals.carbsGrams, 1.0)
    }

    public var fatProgress: Double {
        guard let summary = todaySummary else { return 0.0 }
        return min(summary.totalNutrients.totalFat / nutritionGoals.fatGrams, 1.0)
    }

    public var hasDeficiencies: Bool {
        !deficiencies.isEmpty
    }

    public var criticalInsights: [NutritionInsight] {
        insights.filter { $0.severity == .critical }
    }
}
