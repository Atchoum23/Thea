import Foundation
import Testing
#if SWIFT_PACKAGE
@testable import TheaCore
#else
@testable import Thea
#endif

/// Tests for nutrition service
@Suite("Nutrition Service Tests")
struct NutritionServiceTests {
    // MARK: - Meal Logging Tests

    @Test("Log meal successfully")
    func testLogMeal() async throws {
        let service = NutritionService()

        let foodItem = FoodItem(
            name: "Apple",
            servingSize: 100,
            nutrients: NutrientProfile(),
            source: .manual
        )

        let entry = MealEntry(
            mealType: .breakfast,
            foodItems: [FoodItemEntry(foodItem: foodItem, servings: 1.0)]
        )

        try await service.logMeal(entry)

        let meals = try await service.fetchMeals(for: DateInterval(start: Date().startOfDay, end: Date().endOfDay))
        #expect(!meals.isEmpty)
        #expect(meals.first?.mealType == .breakfast)
    }

    @Test("Fetch meals for date range")
    func testFetchMeals() async throws {
        let service = NutritionService()

        let today = Date()
        let meal1 = MealEntry(mealType: .breakfast, foodItems: [])
        let meal2 = MealEntry(mealType: .lunch, foodItems: [])

        try await service.logMeal(meal1)
        try await service.logMeal(meal2)

        let dateRange = DateInterval(start: today.startOfDay, end: today.endOfDay)
        let meals = try await service.fetchMeals(for: dateRange)

        #expect(meals.count >= 2)
    }

    // MARK: - Food Search Tests

    @Test("Search food returns results")
    func testSearchFood() async throws {
        let service = NutritionService()

        let results = try await service.searchFood(query: "apple")

        #expect(!results.isEmpty)
        #expect(results.contains { $0.name.localizedCaseInsensitiveContains("apple") })
    }

    @Test("Search by barcode")
    func testSearchByBarcode() async throws {
        let service = NutritionService()

        let result = try await service.fetchFoodByBarcode("12345678")

        // May be nil for unknown barcodes
        #expect(result == nil || result?.source == .barcode)
    }

    // MARK: - Daily Summary Tests

    @Test("Get daily summary")
    func testGetDailySummary() async throws {
        let service = NutritionService()

        let foodItem = FoodItem(
            name: "Test Food",
            servingSize: 100,
            nutrients: NutrientProfile(),
            source: .manual
        )

        let meal = MealEntry(
            mealType: .breakfast,
            foodItems: [FoodItemEntry(foodItem: foodItem)]
        )

        try await service.logMeal(meal)

        let summary = try await service.getDailySummary(for: Date())

        #expect(summary.date.startOfDay == Date().startOfDay)
        #expect(!summary.meals.isEmpty)
    }

    // MARK: - Goals Tests

    @Test("Update and fetch goals")
    func testGoalsManagement() async throws {
        let service = NutritionService()

        let newGoals = NutritionGoals(
            dailyCalories: 2_500,
            proteinGrams: 150,
            carbsGrams: 250,
            fatGrams: 70
        )

        try await service.updateGoals(newGoals)

        let fetchedGoals = try await service.fetchGoals()

        #expect(fetchedGoals.dailyCalories == 2_500)
        #expect(fetchedGoals.proteinGrams == 150)
    }

    @Test("Calculate personalized goals")
    func testPersonalizedGoals() {
        let goals = NutritionGoals.calculate(
            age: 30,
            biologicalSex: .male,
            weightKg: 75,
            heightCm: 175,
            activityLevel: .moderatelyActive,
            goal: .maintain
        )

        #expect(goals.dailyCalories > 0)
        #expect(goals.proteinGrams > 0)
        #expect(goals.carbsGrams > 0)
        #expect(goals.fatGrams > 0)
    }

    // MARK: - Nutrition Analysis Tests

    @Test("Calculate nutrition score")
    func testCalculateNutritionScore() async throws {
        let engine = NutritionAnalysisEngine()

        var nutrients = NutrientProfile()
        nutrients.protein = 20
        nutrients.fiber = 10
        nutrients.vitaminC = 50
        nutrients.saturatedFat = 2

        let score = try await engine.calculateNutritionScore(nutrients: nutrients)

        #expect(score >= 0 && score <= 100)
    }

    @Test("Analyze macro balance")
    func testAnalyzeMacroBalance() async throws {
        let engine = NutritionAnalysisEngine()

        var nutrients = NutrientProfile()
        nutrients.calories = 2_000
        nutrients.protein = 150 // 600 cal = 30%
        nutrients.carbohydrates = 200 // 800 cal = 40%
        nutrients.totalFat = 67 // 603 cal = 30%

        let balance = try await engine.analyzeMacroBalance(nutrients: nutrients)

        #expect(abs(balance.proteinPercent - 30.0) < 5)
        #expect(abs(balance.carbsPercent - 40.0) < 5)
        #expect(abs(balance.fatPercent - 30.0) < 5)
    }

    @Test("Generate insights")
    func testGenerateInsights() async throws {
        let engine = NutritionAnalysisEngine()

        var nutrients = NutrientProfile()
        nutrients.calories = 2_000
        nutrients.protein = 50
        nutrients.carbohydrates = 250
        nutrients.totalFat = 70
        nutrients.fiber = 10

        let summary = NutritionSummary(
            date: Date(),
            totalNutrients: nutrients,
            meals: [],
            caloriesConsumed: 2_000,
            caloriesRemaining: 0,
            macroBalance: MacroBalance(proteinPercent: 25, carbsPercent: 50, fatPercent: 25)
        )

        let goals = NutritionGoals()
        let insights = try await engine.generateInsights(dailySummary: summary, goals: goals)

        #expect(!insights.isEmpty)
    }

    @Test("Identify deficiencies")
    func testIdentifyDeficiencies() async throws {
        let engine = NutritionAnalysisEngine()

        var nutrients = NutrientProfile()
        nutrients.protein = 20 // Low
        nutrients.fiber = 5 // Low
        nutrients.vitaminD = 2 // Low

        let summary = NutritionSummary(
            date: Date(),
            totalNutrients: nutrients,
            meals: [],
            caloriesConsumed: 1_500,
            caloriesRemaining: 500,
            macroBalance: MacroBalance(proteinPercent: 20, carbsPercent: 50, fatPercent: 30)
        )

        let goals = NutritionGoals()
        let deficiencies = try await engine.identifyDeficiencies(summary: summary, goals: goals)

        #expect(!deficiencies.isEmpty)
        #expect(deficiencies.contains { $0.nutrientName == "Protein" })
    }

    // MARK: - Nutrient Profile Tests

    @Test("Nutrition score calculation")
    func testNutritionScoreCalculation() {
        var highQuality = NutrientProfile()
        highQuality.protein = 25
        highQuality.fiber = 10
        highQuality.omega3 = 1.0
        highQuality.vitaminA = 500
        highQuality.vitaminC = 50
        highQuality.saturatedFat = 2
        highQuality.sodium = 200

        let highScore = highQuality.nutritionScore
        #expect(highScore >= 50)

        var lowQuality = NutrientProfile()
        lowQuality.saturatedFat = 20
        lowQuality.sodium = 2_000
        lowQuality.addedSugars = 50
        lowQuality.transFat = 5

        let lowScore = lowQuality.nutritionScore
        #expect(lowScore < 50)
    }
}
