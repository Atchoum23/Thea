import Foundation

// MARK: - Nutrition Service

/// Complete nutrition tracking service
public actor NutritionService: NutritionServiceProtocol {
    // MARK: - Properties

    private var mealEntries: [UUID: MealEntry] = [:]
    private var foodDatabase: [UUID: FoodItem] = [:]
    private var currentGoals = NutritionGoals()

    private let usdaService: USDAFoodDatabaseService
    private let analysisEngine: NutritionAnalysisEngine

    // MARK: - Initialization

    public init(
        usdaService: USDAFoodDatabaseService = USDAFoodDatabaseService(),
        analysisEngine: NutritionAnalysisEngine = NutritionAnalysisEngine()
    ) {
        self.usdaService = usdaService
        self.analysisEngine = analysisEngine
    }

    // MARK: - Meal Management

    public func logMeal(_ entry: MealEntry) async throws {
        mealEntries[entry.id] = entry
    }

    public func fetchMeals(for dateRange: DateInterval) async throws -> [MealEntry] {
        mealEntries.values.filter { entry in
            dateRange.contains(entry.timestamp)
        }.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Food Search

    public func searchFood(query: String) async throws -> [FoodItem] {
        // First search local database
        let localResults = foodDatabase.values.filter { food in
            food.name.localizedCaseInsensitiveContains(query)
        }

        // Then search USDA database
        let usdaResults = try await usdaService.searchUSDA(query: query, pageSize: 20)

        // Cache USDA results
        for food in usdaResults {
            foodDatabase[food.id] = food
        }

        return Array(localResults) + usdaResults
    }

    public func fetchFoodByBarcode(_ barcode: String) async throws -> FoodItem? {
        // Check local cache first
        if let cached = foodDatabase.values.first(where: { $0.barcode == barcode }) {
            return cached
        }

        // Query USDA branded food database
        if let food = try await usdaService.fetchBrandedFood(barcode: barcode) {
            foodDatabase[food.id] = food
            return food
        }

        return nil
    }

    // MARK: - Daily Summary

    public func getDailySummary(for date: Date) async throws -> NutritionSummary {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        let dateRange = DateInterval(start: startOfDay, end: endOfDay)

        let meals = try await fetchMeals(for: dateRange)

        // Calculate total nutrients
        var totalNutrients = NutrientProfile()
        var totalCalories = 0.0

        for meal in meals {
            totalCalories += meal.totalCalories
            // In production, would properly aggregate all nutrients
        }

        totalNutrients.calories = totalCalories

        // Analyze macro balance
        let macroBalance = try await analysisEngine.analyzeMacroBalance(nutrients: totalNutrients)

        let caloriesRemaining = currentGoals.dailyCalories - totalCalories

        return NutritionSummary(
            date: date,
            totalNutrients: totalNutrients,
            meals: meals,
            caloriesConsumed: totalCalories,
            caloriesRemaining: max(0, caloriesRemaining),
            macroBalance: macroBalance
        )
    }

    // MARK: - Goals Management

    public func updateGoals(_ goals: NutritionGoals) async throws {
        currentGoals = goals
    }

    public func fetchGoals() async throws -> NutritionGoals {
        currentGoals
    }

    // MARK: - Insights

    public func getInsights(for date: Date) async throws -> [NutritionInsight] {
        let summary = try await getDailySummary(for: date)
        return try await analysisEngine.generateInsights(dailySummary: summary, goals: currentGoals)
    }

    public func getDeficiencies(for date: Date) async throws -> [NutrientDeficiency] {
        let summary = try await getDailySummary(for: date)
        return try await analysisEngine.identifyDeficiencies(summary: summary, goals: currentGoals)
    }
}

// MARK: - USDA Food Database Service

/// Service for querying USDA FoodData Central API
public actor USDAFoodDatabaseService: USDAFoodDatabaseProtocol {
    // MARK: - Properties

    private let apiKey: String?
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"

    // MARK: - Initialization

    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }

    // MARK: - API Methods

    public func searchUSDA(query: String, pageSize: Int = 20) async throws -> [FoodItem] {
        let params = [
            "query": query,
            "pageSize": String(pageSize),
            "dataType": "Foundation,SR Legacy"
        ]
        let data = try await makeRequest(endpoint: "/foods/search", parameters: params)

        struct USDASearchResponse: Decodable {
            let foods: [USDAFoodResult]?
        }
        struct USDAFoodResult: Decodable {
            let fdcId: Int
            let description: String
            let brandName: String?
            let foodNutrients: [USDANutrient]?
            let servingSize: Double?
        }
        struct USDANutrient: Decodable {
            let nutrientId: Int?
            let nutrientName: String?
            let value: Double?
            let unitName: String?
        }

        let response = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        return (response.foods ?? []).map { food in
            var profile = NutrientProfile()
            for nutrient in food.foodNutrients ?? [] {
                let val = nutrient.value ?? 0
                switch nutrient.nutrientId {
                case 1008: profile.calories = val
                case 1003: profile.protein = val
                case 1005: profile.carbohydrates = val
                case 1079: profile.fiber = val
                case 2000: profile.sugars = val
                case 1004: profile.totalFat = val
                case 1258: profile.saturatedFat = val
                case 1257: profile.transFat = val
                case 1292: profile.monounsaturatedFat = val
                case 1293: profile.polyunsaturatedFat = val
                case 1106: profile.vitaminA = val
                case 1114: profile.vitaminD = val
                case 1109: profile.vitaminE = val
                case 1185: profile.vitaminK = val
                case 1162: profile.vitaminC = val
                case 1165: profile.thiamin = val
                case 1166: profile.riboflavin = val
                case 1167: profile.niacin = val
                case 1170: profile.vitaminB6 = val
                case 1177: profile.folate = val
                case 1178: profile.vitaminB12 = val
                case 1087: profile.calcium = val
                case 1089: profile.iron = val
                case 1090: profile.magnesium = val
                case 1091: profile.phosphorus = val
                case 1092: profile.potassium = val
                case 1093: profile.sodium = val
                case 1095: profile.zinc = val
                case 1098: profile.copper = val
                case 1101: profile.manganese = val
                case 1103: profile.selenium = val
                case 1253: profile.cholesterol = val
                default: break
                }
            }
            return FoodItem(
                name: food.description,
                brand: food.brandName,
                servingSize: food.servingSize ?? 100,
                nutrients: profile,
                source: .usda
            )
        }
    }

    public func fetchFoodDetails(fdcID: String) async throws -> FoodItem {
        let data = try await makeRequest(endpoint: "/food/\(fdcID)")

        struct USDAFoodDetail: Decodable {
            let fdcId: Int
            let description: String
            let brandName: String?
            let foodNutrients: [USDADetailNutrient]?
            let servingSize: Double?
        }
        struct USDADetailNutrient: Decodable {
            let nutrient: USDANutrientInfo?
            let amount: Double?
        }
        struct USDANutrientInfo: Decodable {
            let id: Int
            let name: String?
            let unitName: String?
        }

        let detail = try JSONDecoder().decode(USDAFoodDetail.self, from: data)
        var profile = NutrientProfile()
        for nutrient in detail.foodNutrients ?? [] {
            let val = nutrient.amount ?? 0
            switch nutrient.nutrient?.id {
            case 1008: profile.calories = val
            case 1003: profile.protein = val
            case 1005: profile.carbohydrates = val
            case 1079: profile.fiber = val
            case 2000: profile.sugars = val
            case 1004: profile.totalFat = val
            case 1258: profile.saturatedFat = val
            case 1162: profile.vitaminC = val
            case 1087: profile.calcium = val
            case 1089: profile.iron = val
            case 1093: profile.sodium = val
            case 1092: profile.potassium = val
            default: break
            }
        }
        return FoodItem(
            name: detail.description,
            brand: detail.brandName,
            servingSize: detail.servingSize ?? 100,
            nutrients: profile,
            source: .usda
        )
    }

    public func fetchBrandedFood(barcode: String) async throws -> FoodItem? {
        let params = [
            "query": barcode,
            "dataType": "Branded"
        ]
        let data = try await makeRequest(endpoint: "/foods/search", parameters: params)

        struct USDASearchResponse: Decodable {
            let foods: [USDABrandedResult]?
        }
        struct USDABrandedResult: Decodable {
            let fdcId: Int
            let description: String
            let brandName: String?
            let gtinUpc: String?
            let foodNutrients: [USDABrandedNutrient]?
            let servingSize: Double?
        }
        struct USDABrandedNutrient: Decodable {
            let nutrientId: Int?
            let value: Double?
        }

        let response = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        guard let match = response.foods?.first(where: { $0.gtinUpc == barcode }) ?? response.foods?.first else {
            return nil
        }
        var profile = NutrientProfile()
        for nutrient in match.foodNutrients ?? [] {
            let val = nutrient.value ?? 0
            switch nutrient.nutrientId {
            case 1008: profile.calories = val
            case 1003: profile.protein = val
            case 1005: profile.carbohydrates = val
            case 1004: profile.totalFat = val
            case 1093: profile.sodium = val
            default: break
            }
        }
        return FoodItem(
            name: match.description,
            brand: match.brandName,
            servingSize: match.servingSize ?? 100,
            nutrients: profile,
            barcode: match.gtinUpc,
            source: .usda
        )
    }

    // MARK: - Private Helpers

    /// Make a secure API request with API key in header (not URL parameters)
    /// Security: API keys in URL parameters are logged in server access logs and browser history
    private func makeRequest(endpoint: String, parameters: [String: String] = [:]) async throws -> Data {
        // Use provided API key, or fall back to DEMO_KEY (limited: 30 req/hour, 50/day)
        let effectiveKey = apiKey ?? "DEMO_KEY"

        var components = URLComponents(string: "\(baseURL)\(endpoint)")
        // Only add non-sensitive query parameters
        components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components?.url else {
            throw NutritionError.usdaAPIError("Invalid URL")
        }

        // Create request with API key in header (more secure than URL parameter)
        var request = URLRequest(url: url)
        request.setValue(effectiveKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw NutritionError.usdaAPIError("HTTP error")
        }

        return data
    }
}

// MARK: - Nutrition Analysis Engine

/// Engine for analyzing nutrition data
public actor NutritionAnalysisEngine: NutritionAnalysisProtocol {
    public init() {}

    // MARK: - Scoring

    public func calculateNutritionScore(nutrients: NutrientProfile) async throws -> Double {
        nutrients.nutritionScore
    }

    // MARK: - Insights

    public func generateInsights(
        dailySummary: NutritionSummary,
        goals: NutritionGoals
    ) async throws -> [NutritionInsight] {
        var insights: [NutritionInsight] = []

        // Calorie analysis
        let calorieDeficit = goals.dailyCalories - dailySummary.caloriesConsumed
        if calorieDeficit > 500 {
            insights.append(NutritionInsight(
                type: .calorieDeficit,
                title: "Low Calorie Intake",
                message: "You're \(Int(calorieDeficit)) calories below your goal. Consider adding a healthy snack.",
                severity: .warning
            ))
        } else if calorieDeficit < -500 {
            insights.append(NutritionInsight(
                type: .calorieSurplus,
                title: "Calorie Surplus",
                message: "You've exceeded your calorie goal by \(Int(abs(calorieDeficit))) calories.",
                severity: .warning
            ))
        }

        // Macro balance
        if !dailySummary.macroBalance.isBalanced {
            insights.append(NutritionInsight(
                type: .macroImbalance,
                title: "Macro Imbalance",
                message: "Your macros are: \(Int(dailySummary.macroBalance.proteinPercent))% protein, \(Int(dailySummary.macroBalance.carbsPercent))% carbs, \(Int(dailySummary.macroBalance.fatPercent))% fat.",
                severity: .info
            ))
        }

        // Fiber check
        if dailySummary.totalNutrients.fiber < goals.fiberGrams * 0.5 {
            insights.append(NutritionInsight(
                type: .lowFiber,
                title: "Low Fiber",
                message: "You've consumed \(Int(dailySummary.totalNutrients.fiber))g of fiber. Aim for \(Int(goals.fiberGrams))g daily.",
                severity: .warning
            ))
        }

        // Sodium check
        if dailySummary.totalNutrients.sodium > goals.sodiumMg {
            insights.append(NutritionInsight(
                type: .highSodium,
                title: "High Sodium",
                message: "You've exceeded your sodium goal. Current: \(Int(dailySummary.totalNutrients.sodium))mg, Goal: \(Int(goals.sodiumMg))mg.",
                severity: .warning
            ))
        }

        // Perfect day
        if abs(calorieDeficit) < 100, dailySummary.macroBalance.isBalanced {
            insights.append(NutritionInsight(
                type: .excellentDay,
                title: "Excellent Nutrition!",
                message: "You've met your goals with balanced macros. Keep it up!",
                severity: .info
            ))
        }

        return insights
    }

    // MARK: - Macro Analysis

    public func analyzeMacroBalance(nutrients: NutrientProfile) async throws -> MacroBalance {
        let totalCalories = nutrients.calories

        guard totalCalories > 0 else {
            return MacroBalance(proteinPercent: 0, carbsPercent: 0, fatPercent: 0)
        }

        let proteinCalories = nutrients.protein * 4.0
        let carbsCalories = nutrients.carbohydrates * 4.0
        let fatCalories = nutrients.totalFat * 9.0

        let proteinPercent = (proteinCalories / totalCalories) * 100.0
        let carbsPercent = (carbsCalories / totalCalories) * 100.0
        let fatPercent = (fatCalories / totalCalories) * 100.0

        return MacroBalance(
            proteinPercent: proteinPercent,
            carbsPercent: carbsPercent,
            fatPercent: fatPercent
        )
    }

    // MARK: - Deficiency Detection

    public func identifyDeficiencies(
        summary: NutritionSummary,
        goals: NutritionGoals
    ) async throws -> [NutrientDeficiency] {
        var deficiencies: [NutrientDeficiency] = []

        // Protein deficiency
        if summary.totalNutrients.protein < goals.proteinGrams * 0.7 {
            deficiencies.append(NutrientDeficiency(
                nutrientName: "Protein",
                currentAmount: summary.totalNutrients.protein,
                recommendedAmount: goals.proteinGrams,
                deficitPercent: ((goals.proteinGrams - summary.totalNutrients.protein) / goals.proteinGrams) * 100,
                foodSuggestions: ["Chicken breast", "Greek yogurt", "Lentils", "Tofu"]
            ))
        }

        // Fiber deficiency
        if summary.totalNutrients.fiber < goals.fiberGrams * 0.7 {
            deficiencies.append(NutrientDeficiency(
                nutrientName: "Fiber",
                currentAmount: summary.totalNutrients.fiber,
                recommendedAmount: goals.fiberGrams,
                deficitPercent: ((goals.fiberGrams - summary.totalNutrients.fiber) / goals.fiberGrams) * 100,
                foodSuggestions: ["Broccoli", "Oats", "Black beans", "Raspberries"]
            ))
        }

        // Vitamin D deficiency (common)
        if summary.totalNutrients.vitaminD < 15.0 { // 15 mcg daily recommendation
            deficiencies.append(NutrientDeficiency(
                nutrientName: "Vitamin D",
                currentAmount: summary.totalNutrients.vitaminD,
                recommendedAmount: 15.0,
                deficitPercent: ((15.0 - summary.totalNutrients.vitaminD) / 15.0) * 100,
                foodSuggestions: ["Salmon", "Fortified milk", "Egg yolks", "Mushrooms"]
            ))
        }

        // Omega-3 deficiency
        if summary.totalNutrients.omega3 < 1.6 { // 1.6g daily recommendation
            deficiencies.append(NutrientDeficiency(
                nutrientName: "Omega-3",
                currentAmount: summary.totalNutrients.omega3,
                recommendedAmount: 1.6,
                deficitPercent: ((1.6 - summary.totalNutrients.omega3) / 1.6) * 100,
                foodSuggestions: ["Salmon", "Walnuts", "Chia seeds", "Flaxseed oil"]
            ))
        }

        return deficiencies
    }
}
