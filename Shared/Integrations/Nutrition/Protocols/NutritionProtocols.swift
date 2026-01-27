import Foundation

// MARK: - Nutrition Service Protocol

/// Protocol for nutrition tracking service
public protocol NutritionServiceProtocol: Actor {
    /// Log a meal entry
    func logMeal(_ entry: MealEntry) async throws

    /// Fetch meal entries for a date range
    func fetchMeals(for dateRange: DateInterval) async throws -> [MealEntry]

    /// Search for food items
    func searchFood(query: String) async throws -> [FoodItem]

    /// Fetch food by barcode
    func fetchFoodByBarcode(_ barcode: String) async throws -> FoodItem?

    /// Get daily nutrition summary
    func getDailySummary(for date: Date) async throws -> NutritionSummary

    /// Update nutrition goals
    func updateGoals(_ goals: NutritionGoals) async throws

    /// Fetch current nutrition goals
    func fetchGoals() async throws -> NutritionGoals
}

// MARK: - USDA Food Database Protocol

/// Protocol for USDA FoodData Central API
public protocol USDAFoodDatabaseProtocol: Actor {
    /// Search USDA database
    func searchUSDA(query: String, pageSize: Int) async throws -> [FoodItem]

    /// Fetch food details by FDC ID
    func fetchFoodDetails(fdcID: String) async throws -> FoodItem

    /// Fetch branded food by barcode
    func fetchBrandedFood(barcode: String) async throws -> FoodItem?
}

// MARK: - Nutrition Analysis Protocol

/// Protocol for analyzing nutrition data
public protocol NutritionAnalysisProtocol: Actor {
    /// Calculate nutrition score (0-100)
    func calculateNutritionScore(nutrients: NutrientProfile) async throws -> Double

    /// Generate nutrition insights
    func generateInsights(dailySummary: NutritionSummary, goals: NutritionGoals) async throws -> [NutritionInsight]

    /// Analyze macro balance
    func analyzeMacroBalance(nutrients: NutrientProfile) async throws -> MacroBalance

    /// Identify nutrient deficiencies
    func identifyDeficiencies(summary: NutritionSummary, goals: NutritionGoals) async throws -> [NutrientDeficiency]
}

// MARK: - Supporting Types

/// Daily nutrition summary
public struct NutritionSummary: Sendable, Codable {
    public var date: Date
    public var totalNutrients: NutrientProfile
    public var meals: [MealEntry]
    public var caloriesConsumed: Double
    public var caloriesRemaining: Double
    public var macroBalance: MacroBalance

    public init(
        date: Date,
        totalNutrients: NutrientProfile,
        meals: [MealEntry],
        caloriesConsumed: Double,
        caloriesRemaining: Double,
        macroBalance: MacroBalance
    ) {
        self.date = date
        self.totalNutrients = totalNutrients
        self.meals = meals
        self.caloriesConsumed = caloriesConsumed
        self.caloriesRemaining = caloriesRemaining
        self.macroBalance = macroBalance
    }
}

/// Macro balance analysis
public struct MacroBalance: Sendable, Codable {
    public var proteinPercent: Double
    public var carbsPercent: Double
    public var fatPercent: Double
    public var isBalanced: Bool

    public init(
        proteinPercent: Double,
        carbsPercent: Double,
        fatPercent: Double
    ) {
        self.proteinPercent = proteinPercent
        self.carbsPercent = carbsPercent
        self.fatPercent = fatPercent

        // Consider balanced if within 10% of ideal ratios
        let proteinTarget = 30.0
        let carbsTarget = 40.0
        let fatTarget = 30.0

        isBalanced = abs(proteinPercent - proteinTarget) < 10 &&
            abs(carbsPercent - carbsTarget) < 10 &&
            abs(fatPercent - fatTarget) < 10
    }
}

/// Nutrition insight
public struct NutritionInsight: Sendable, Codable, Identifiable {
    public let id: UUID
    public var type: NutritionInsightType
    public var title: String
    public var message: String
    public var severity: NutritionInsightSeverity

    public init(
        id: UUID = UUID(),
        type: NutritionInsightType,
        title: String,
        message: String,
        severity: NutritionInsightSeverity
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.severity = severity
    }
}

public enum NutritionInsightType: String, Sendable, Codable {
    case calorieDeficit = "Calorie Deficit"
    case calorieSurplus = "Calorie Surplus"
    case macroImbalance = "Macro Imbalance"
    case nutrientDeficiency = "Nutrient Deficiency"
    case highSodium = "High Sodium"
    case lowFiber = "Low Fiber"
    case excellentDay = "Excellent Day"
}

public enum NutritionInsightSeverity: String, Sendable, Codable {
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"

    public var color: String {
        switch self {
        case .info: "blue"
        case .warning: "orange"
        case .critical: "red"
        }
    }
}

/// Nutrient deficiency
public struct NutrientDeficiency: Sendable, Codable, Identifiable {
    public let id: UUID
    public var nutrientName: String
    public var currentAmount: Double
    public var recommendedAmount: Double
    public var deficitPercent: Double
    public var foodSuggestions: [String]

    public init(
        id: UUID = UUID(),
        nutrientName: String,
        currentAmount: Double,
        recommendedAmount: Double,
        deficitPercent: Double,
        foodSuggestions: [String]
    ) {
        self.id = id
        self.nutrientName = nutrientName
        self.currentAmount = currentAmount
        self.recommendedAmount = recommendedAmount
        self.deficitPercent = deficitPercent
        self.foodSuggestions = foodSuggestions
    }
}
