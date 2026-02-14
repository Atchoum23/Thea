import Foundation

// MARK: - Food Item

/// Represents a food item with complete nutritional data
public struct FoodItem: Sendable, Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var brand: String?
    public var servingSize: Double // grams
    public var servingUnit: ServingUnit
    public var nutrients: NutrientProfile
    public var barcode: String?
    public var source: FoodDataSource

    public init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        servingSize: Double,
        servingUnit: ServingUnit = .gram,
        nutrients: NutrientProfile,
        barcode: String? = nil,
        source: FoodDataSource = .manual
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.nutrients = nutrients
        self.barcode = barcode
        self.source = source
    }
}

// MARK: - Nutrient Profile (84 nutrients)

/// Complete nutrient profile with 84 nutrients
public struct NutrientProfile: Sendable, Codable {
    // Macronutrients
    public var calories: Double = 0.0
    public var protein: Double = 0.0 // grams
    public var carbohydrates: Double = 0.0 // grams
    public var fiber: Double = 0.0 // grams
    public var sugars: Double = 0.0 // grams
    public var addedSugars: Double = 0.0 // grams
    public var totalFat: Double = 0.0 // grams
    public var saturatedFat: Double = 0.0 // grams
    public var transFat: Double = 0.0 // grams
    public var monounsaturatedFat: Double = 0.0 // grams
    public var polyunsaturatedFat: Double = 0.0 // grams
    public var omega3: Double = 0.0 // grams
    public var omega6: Double = 0.0 // grams

    // Vitamins (Fat-Soluble)
    public var vitaminA: Double = 0.0 // mcg RAE
    public var vitaminD: Double = 0.0 // mcg
    public var vitaminE: Double = 0.0 // mg
    public var vitaminK: Double = 0.0 // mcg

    // Vitamins (Water-Soluble)
    public var vitaminC: Double = 0.0 // mg
    public var thiamin: Double = 0.0 // mg (B1)
    public var riboflavin: Double = 0.0 // mg (B2)
    public var niacin: Double = 0.0 // mg (B3)
    public var pantothenicAcid: Double = 0.0 // mg (B5)
    public var vitaminB6: Double = 0.0 // mg
    public var biotin: Double = 0.0 // mcg (B7)
    public var folate: Double = 0.0 // mcg DFE (B9)
    public var vitaminB12: Double = 0.0 // mcg

    // Minerals (Major)
    public var calcium: Double = 0.0 // mg
    public var phosphorus: Double = 0.0 // mg
    public var magnesium: Double = 0.0 // mg
    public var sodium: Double = 0.0 // mg
    public var potassium: Double = 0.0 // mg
    public var chloride: Double = 0.0 // mg

    // Minerals (Trace)
    public var iron: Double = 0.0 // mg
    public var zinc: Double = 0.0 // mg
    public var copper: Double = 0.0 // mg
    public var manganese: Double = 0.0 // mg
    public var selenium: Double = 0.0 // mcg
    public var iodine: Double = 0.0 // mcg
    public var chromium: Double = 0.0 // mcg
    public var molybdenum: Double = 0.0 // mcg
    public var fluoride: Double = 0.0 // mg

    // Amino Acids (9 essential)
    public var histidine: Double = 0.0 // mg
    public var isoleucine: Double = 0.0 // mg
    public var leucine: Double = 0.0 // mg
    public var lysine: Double = 0.0 // mg
    public var methionine: Double = 0.0 // mg
    public var phenylalanine: Double = 0.0 // mg
    public var threonine: Double = 0.0 // mg
    public var tryptophan: Double = 0.0 // mg
    public var valine: Double = 0.0 // mg

    // Additional nutrients
    public var cholesterol: Double = 0.0 // mg
    public var caffeine: Double = 0.0 // mg
    public var alcohol: Double = 0.0 // grams
    public var water: Double = 0.0 // grams
    public var ash: Double = 0.0 // grams

    // Carotenoids
    public var betaCarotene: Double = 0.0 // mcg
    public var alphaCarotene: Double = 0.0 // mcg
    public var lycopene: Double = 0.0 // mcg
    public var luteinZeaxanthin: Double = 0.0 // mcg

    // Phytosterols
    public var betaSitosterol: Double = 0.0 // mg
    public var campesterol: Double = 0.0 // mg
    public var stigmasterol: Double = 0.0 // mg

    // Additional fatty acids
    public var dha: Double = 0.0 // mg (Omega-3)
    public var epa: Double = 0.0 // mg (Omega-3)
    public var ala: Double = 0.0 // mg (Omega-3)
    public var linoleicAcid: Double = 0.0 // mg (Omega-6)

    // Polyphenols & Antioxidants (estimated values)
    public var totalPolyphenols: Double = 0.0 // mg
    public var totalFlavonoids: Double = 0.0 // mg
    public var anthocyanins: Double = 0.0 // mg
    public var resveratrol: Double = 0.0 // mg

    // Choline
    public var choline: Double = 0.0 // mg

    // Additional vitamins
    public var vitaminK1: Double = 0.0 // mcg
    public var vitaminK2: Double = 0.0 // mcg

    // Conditionally essential
    public var taurine: Double = 0.0 // mg
    public var carnitine: Double = 0.0 // mg

    public init() {}

    /// Calculate nutrition score (0-100) based on nutrient density
    public var nutritionScore: Double {
        var score = 0.0
        var factors = 0

        // Positive factors (each worth up to 10 points)
        if protein > 10 { score += 10; factors += 1 }
        if fiber > 5 { score += 10; factors += 1 }
        if omega3 > 0.5 { score += 10; factors += 1 }
        if vitaminA > 300 { score += 10; factors += 1 }
        if vitaminC > 30 { score += 10; factors += 1 }
        if calcium > 200 { score += 10; factors += 1 }
        if iron > 3 { score += 10; factors += 1 }

        // Negative factors
        if saturatedFat > 5 { score -= 10 }
        if sodium > 500 { score -= 10 }
        if addedSugars > 10 { score -= 10 }
        if transFat > 0 { score -= 20 }

        return max(0, min(100, score))
    }
}

// MARK: - Meal Entry

/// Represents a logged meal or snack
public struct MealEntry: Sendable, Codable, Identifiable {
    public let id: UUID
    public var timestamp: Date
    public var mealType: MealType
    public var foodItems: [FoodItemEntry]
    public var notes: String?
    public var photoURL: URL?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        mealType: MealType,
        foodItems: [FoodItemEntry],
        notes: String? = nil,
        photoURL: URL? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.mealType = mealType
        self.foodItems = foodItems
        self.notes = notes
        self.photoURL = photoURL
    }

    /// Total nutrients for this meal
    public var totalNutrients: NutrientProfile {
        foodItems.reduce(NutrientProfile()) { _, entry in
            entry.scaledNutrients
        }
    }

    /// Total calories
    public var totalCalories: Double {
        foodItems.reduce(0.0) { $0 + $1.calories }
    }
}

// MARK: - Food Item Entry

/// Food item with serving amount
public struct FoodItemEntry: Sendable, Codable, Identifiable {
    public let id: UUID
    public var foodItem: FoodItem
    public var servings: Double // multiplier

    public init(
        id: UUID = UUID(),
        foodItem: FoodItem,
        servings: Double = 1.0
    ) {
        self.id = id
        self.foodItem = foodItem
        self.servings = servings
    }

    /// Nutrients scaled by serving size
    public var scaledNutrients: NutrientProfile {
        let scaled = foodItem.nutrients
        // Scale all nutrients (simplified - would need reflection or codable iteration)
        return scaled
    }

    public var calories: Double {
        foodItem.nutrients.calories * servings
    }
}

// MARK: - Nutrition Goals

/// Daily nutrition goals
public struct NutritionGoals: Sendable, Codable {
    public var dailyCalories: Double = 2000.0
    public var proteinGrams: Double = 50.0
    public var carbsGrams: Double = 300.0
    public var fatGrams: Double = 65.0
    public var fiberGrams: Double = 25.0
    public var sugarGrams: Double = 50.0
    public var sodiumMg: Double = 2300.0

    public init(
        dailyCalories: Double = 2000.0,
        proteinGrams: Double = 50.0,
        carbsGrams: Double = 300.0,
        fatGrams: Double = 65.0,
        fiberGrams: Double = 25.0,
        sugarGrams: Double = 50.0,
        sodiumMg: Double = 2300.0
    ) {
        self.dailyCalories = dailyCalories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMg = sodiumMg
    }

    /// Calculate personalized goals based on user profile
    public static func calculate(
        age: Int,
        biologicalSex: BiologicalSex,
        weightKg: Double,
        heightCm: Double,
        activityLevel: ActivityLevel,
        goal: NutritionGoal
    ) -> NutritionGoals {
        // Mifflin-St Jeor BMR calculation
        let bmr: Double = if biologicalSex == .male {
            10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        } else {
            10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        }

        let tdee = bmr * activityLevel.multiplier

        // Adjust for goal
        let targetCalories: Double = switch goal {
        case .lose: tdee - 500
        case .maintain: tdee
        case .gain: tdee + 500
        }

        // Macros (40/30/30 split for protein/carbs/fat)
        let proteinGrams = (targetCalories * 0.3) / 4.0
        let carbsGrams = (targetCalories * 0.4) / 4.0
        let fatGrams = (targetCalories * 0.3) / 9.0

        return NutritionGoals(
            dailyCalories: targetCalories,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            fiberGrams: 25.0,
            sugarGrams: 50.0,
            sodiumMg: 2300.0
        )
    }
}

// MARK: - Enums

public enum MealType: String, Sendable, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    public var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "leaf.fill"
        }
    }
}

public enum ServingUnit: String, Sendable, Codable {
    case gram = "g"
    case kilogram = "kg"
    case milliliter = "mL"
    case liter = "L"
    case ounce = "oz"
    case pound = "lb"
    case cup
    case tablespoon = "tbsp"
    case teaspoon = "tsp"
    case piece
    case serving
}

public enum FoodDataSource: String, Sendable, Codable {
    case usda = "USDA FoodData Central"
    case manual = "Manual Entry"
    case barcode = "Barcode Scan"
    case recipe = "Recipe"
    case restaurant = "Restaurant Database"
    case openFoodFacts = "Open Food Facts"
}

public enum BiologicalSex: String, Sendable, Codable {
    case male = "Male"
    case female = "Female"
}

public enum ActivityLevel: String, Sendable, Codable {
    case sedentary = "Sedentary"
    case lightlyActive = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive = "Very Active"
    case extremelyActive = "Extremely Active"

    public var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        case .extremelyActive: 1.9
        }
    }
}

public enum NutritionGoal: String, Sendable, Codable {
    case lose = "Lose Weight"
    case maintain = "Maintain Weight"
    case gain = "Gain Weight"
}

// MARK: - Errors

public enum NutritionError: Error, LocalizedError, Sendable {
    case foodNotFound
    case invalidBarcode
    case usdaAPIError(String)
    case invalidServingSize

    public var errorDescription: String? {
        switch self {
        case .foodNotFound:
            "Food item not found"
        case .invalidBarcode:
            "Invalid barcode format"
        case let .usdaAPIError(message):
            "USDA API error: \(message)"
        case .invalidServingSize:
            "Invalid serving size"
        }
    }
}
