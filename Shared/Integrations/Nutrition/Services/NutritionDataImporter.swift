import Combine
import Foundation
import OSLog

/// Service for importing nutrition data from various sources (CSV, USDA API, barcode scanning)
public actor NutritionDataImporter {
    public static let shared = NutritionDataImporter()

    public enum ImportError: Error, Sendable, LocalizedError {
        case invalidFormat
        case fileNotFound
        case parsingFailed
        case unsupportedFileType
        case networkError
        case barcodeNotFound

        public var errorDescription: String? {
            switch self {
            case .invalidFormat:
                "The file format is invalid or corrupted"
            case .fileNotFound:
                "The specified file could not be found"
            case .parsingFailed:
                "Failed to parse the nutrition data"
            case .unsupportedFileType:
                "This file type is not supported"
            case .networkError:
                "Network error occurred while fetching data"
            case .barcodeNotFound:
                "No product found for this barcode"
            }
        }
    }

    public enum ImportSource: Sendable {
        case csv(URL)
        case json(URL)
        case usdaAPI(String) // Food name
        case barcode(String) // UPC/EAN code
    }

    private let logger = Logger(subsystem: "ai.thea.app", category: "NutritionDataImporter")

    private init() {}

    // MARK: - Public API

    /// Imports nutrition data from specified source
    public func importData(from source: ImportSource) async throws -> [FoodItem] {
        switch source {
        case let .csv(url):
            try await importFromCSV(url)
        case let .json(url):
            try await importFromJSON(url)
        case let .usdaAPI(foodName):
            try await importFromUSDA(foodName)
        case let .barcode(code):
            try await importFromBarcode(code)
        }
    }

    /// Exports nutrition data to CSV format
    public func exportToCSV(_ items: [FoodItem]) throws -> String {
        let headers = ["Name", "Calories", "Protein", "Carbs", "Fat", "Fiber", "Sugar"]
        var csv = headers.joined(separator: ",") + "\n"

        for item in items {
            let row = [
                escapeCSV(item.name),
                "\(item.nutrients.calories)",
                "\(item.nutrients.protein)",
                "\(item.nutrients.carbohydrates)",
                "\(item.nutrients.totalFat)",
                "\(item.nutrients.fiber)",
                "\(item.nutrients.sugars)"
            ]
            csv += row.joined(separator: ",") + "\n"
        }

        return csv
    }

    /// Exports nutrition data to JSON format
    public func exportToJSON(_ items: [FoodItem]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(items)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ImportError.parsingFailed
        }

        return jsonString
    }

    // MARK: - Import Methods

    private func importFromCSV(_ url: URL) async throws -> [FoodItem] {
        let csvData: String
        do {
            csvData = try String(contentsOf: url, encoding: .utf8)
        } catch {
            logger.error("Failed to read CSV file \(url.lastPathComponent): \(error.localizedDescription)")
            throw ImportError.fileNotFound
        }

        let lines = csvData.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else {
            throw ImportError.invalidFormat
        }

        // Skip header
        let dataLines = lines.dropFirst()
        var foodItems: [FoodItem] = []

        for line in dataLines {
            let fields = parseCSVLine(line)
            guard fields.count >= 7 else { continue }

            var nutrients = NutrientProfile()
            nutrients.calories = Double(fields[1]) ?? 0
            nutrients.protein = Double(fields[2]) ?? 0
            nutrients.carbohydrates = Double(fields[3]) ?? 0
            nutrients.totalFat = Double(fields[4]) ?? 0
            nutrients.fiber = Double(fields[5]) ?? 0
            nutrients.sugars = Double(fields[6]) ?? 0

            let foodItem = FoodItem(
                name: fields[0],
                brand: nil,
                servingSize: 100,
                servingUnit: .gram,
                nutrients: nutrients,
                barcode: nil
            )

            foodItems.append(foodItem)
        }

        return foodItems
    }

    private func importFromJSON(_ url: URL) async throws -> [FoodItem] {
        let jsonData: Data
        do {
            jsonData = try Data(contentsOf: url)
        } catch {
            logger.error("Failed to read JSON file \(url.lastPathComponent): \(error.localizedDescription)")
            throw ImportError.fileNotFound
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let foodItems = try decoder.decode([FoodItem].self, from: jsonData)
            return foodItems
        } catch {
            throw ImportError.parsingFailed
        }
    }

    // USDA FoodData Central API — free API key from fdc.nal.usda.gov
    // To go live: set your API key in SettingsManager.shared (key: "usdaApiKey")
    // Default "DEMO_KEY" has rate limits but works for testing
    private var usdaApiKey: String {
        // Check if owner has set a real key, otherwise use demo
        UserDefaults.standard.string(forKey: "usdaApiKey") ?? "DEMO_KEY"
    }

    private func importFromUSDA(_ foodName: String) async throws -> [FoodItem] {
        guard !foodName.isEmpty else {
            throw ImportError.invalidFormat
        }

        // Call USDA FoodData Central search API
        let query = foodName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? foodName
        guard let url = URL(string: "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=\(usdaApiKey)&query=\(query)&pageSize=5&dataType=Foundation,SR%20Legacy") else {
            throw ImportError.networkError
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ImportError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let foods = json["foods"] as? [[String: Any]] else {
            throw ImportError.parsingFailed
        }

        var foodItems: [FoodItem] = []
        for food in foods {
            let name = food["description"] as? String ?? foodName
            let brand = food["brandName"] as? String ?? food["brandOwner"] as? String
            let nutrients = parseUSDANutrients(food["foodNutrients"] as? [[String: Any]] ?? [])

            let item = FoodItem(
                name: name,
                brand: brand ?? "USDA",
                servingSize: 100,
                servingUnit: .gram,
                nutrients: nutrients,
                barcode: food["gtinUpc"] as? String,
                source: .usda
            )
            foodItems.append(item)
        }

        if foodItems.isEmpty {
            throw ImportError.parsingFailed
        }
        return foodItems
    }

    /// Parse USDA FoodData Central nutrient array into NutrientProfile
    private func parseUSDANutrients(_ nutrients: [[String: Any]]) -> NutrientProfile {
        var profile = NutrientProfile()
        // USDA nutrient IDs: https://fdc.nal.usda.gov/api-guide.html
        for nutrient in nutrients {
            guard let value = nutrient["value"] as? Double else { continue }
            let nutrientId = nutrient["nutrientId"] as? Int ?? 0
            let name = (nutrient["nutrientName"] as? String ?? "").lowercased()

            switch nutrientId {
            case 1008: profile.calories = value        // Energy (kcal)
            case 1003: profile.protein = value         // Protein
            case 1005: profile.carbohydrates = value   // Carbohydrate
            case 1079: profile.fiber = value           // Fiber
            case 1063: profile.sugars = value          // Total Sugars
            case 1004: profile.totalFat = value        // Total Fat
            case 1258: profile.saturatedFat = value    // Saturated Fat
            case 1257: profile.transFat = value        // Trans Fat
            case 1292: profile.monounsaturatedFat = value
            case 1293: profile.polyunsaturatedFat = value
            case 1106: profile.vitaminA = value        // Vitamin A
            case 1114: profile.vitaminD = value        // Vitamin D
            case 1109: profile.vitaminE = value        // Vitamin E
            case 1185: profile.vitaminK = value        // Vitamin K
            case 1162: profile.vitaminC = value        // Vitamin C
            case 1165: profile.thiamin = value         // Thiamin (B1)
            case 1166: profile.riboflavin = value      // Riboflavin (B2)
            case 1167: profile.niacin = value          // Niacin (B3)
            case 1170: profile.vitaminB6 = value       // Vitamin B6
            case 1177: profile.folate = value          // Folate
            case 1178: profile.vitaminB12 = value      // Vitamin B12
            case 1087: profile.calcium = value         // Calcium
            case 1089: profile.iron = value            // Iron
            case 1090: profile.magnesium = value       // Magnesium
            case 1091: profile.phosphorus = value      // Phosphorus
            case 1092: profile.potassium = value       // Potassium
            case 1093: profile.sodium = value          // Sodium
            case 1095: profile.zinc = value            // Zinc
            case 1098: profile.copper = value          // Copper
            case 1101: profile.manganese = value       // Manganese
            case 1103: profile.selenium = value        // Selenium
            case 1253: profile.cholesterol = value     // Cholesterol
            default:
                // Match by name for nutrients without standard IDs
                if name.contains("iron") { profile.iron = value }
            }
        }
        return profile
    }

    // Open Food Facts API — free, no API key needed
    // https://wiki.openfoodfacts.org/API
    private func importFromBarcode(_ barcode: String) async throws -> [FoodItem] {
        guard !barcode.isEmpty else {
            throw ImportError.invalidFormat
        }

        // Validate barcode format (UPC-A is 12 digits, EAN-13 is 13)
        guard barcode.count >= 8, barcode.count <= 13,
              barcode.allSatisfy(\.isNumber) else {
            throw ImportError.invalidFormat
        }

        // Call Open Food Facts API
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
            throw ImportError.networkError
        }

        var request = URLRequest(url: url)
        request.setValue("Thea/1.0 (macOS; contact: thea@app.com)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ImportError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any] else {
            throw ImportError.barcodeNotFound
        }

        let name = product["product_name"] as? String ?? "Unknown Product"
        let brand = product["brands"] as? String
        let nutriments = product["nutriments"] as? [String: Any] ?? [:]

        var nutrients = NutrientProfile()
        nutrients.calories = nutriments["energy-kcal_100g"] as? Double ?? 0
        nutrients.protein = nutriments["proteins_100g"] as? Double ?? 0
        nutrients.carbohydrates = nutriments["carbohydrates_100g"] as? Double ?? 0
        nutrients.fiber = nutriments["fiber_100g"] as? Double ?? 0
        nutrients.sugars = nutriments["sugars_100g"] as? Double ?? 0
        nutrients.totalFat = nutriments["fat_100g"] as? Double ?? 0
        nutrients.saturatedFat = nutriments["saturated-fat_100g"] as? Double ?? 0
        nutrients.sodium = nutriments["sodium_100g"] as? Double ?? 0
        nutrients.calcium = nutriments["calcium_100g"] as? Double ?? 0
        nutrients.iron = nutriments["iron_100g"] as? Double ?? 0
        nutrients.vitaminC = nutriments["vitamin-c_100g"] as? Double ?? 0
        nutrients.vitaminA = nutriments["vitamin-a_100g"] as? Double ?? 0
        nutrients.potassium = nutriments["potassium_100g"] as? Double ?? 0
        nutrients.cholesterol = nutriments["cholesterol_100g"] as? Double ?? 0
        nutrients.transFat = nutriments["trans-fat_100g"] as? Double ?? 0

        let servingSize = product["serving_quantity"] as? Double ?? 100

        let foodItem = FoodItem(
            name: name,
            brand: brand,
            servingSize: servingSize,
            servingUnit: .gram,
            nutrients: nutrients,
            barcode: barcode,
            source: .openFoodFacts
        )

        return [foodItem]
    }

    // MARK: - Helper Methods

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == ",", !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }

        // Add last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))

        return fields
    }

    private func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

// MARK: - Batch Import Coordinator

@MainActor
public final class NutritionImportCoordinator: ObservableObject {
    @Published public var isImporting = false
    @Published public var importProgress: Double = 0.0
    @Published public var importedItems: [FoodItem] = []
    @Published public var errorMessage: String?

    private let importer = NutritionDataImporter.shared

    public init() {}

    public func importFromFile(_ url: URL) async {
        isImporting = true
        importProgress = 0.0
        errorMessage = nil

        do {
            let fileExtension = url.pathExtension.lowercased()

            let source: NutritionDataImporter.ImportSource
            switch fileExtension {
            case "csv":
                source = .csv(url)
            case "json":
                source = .json(url)
            default:
                throw NutritionDataImporter.ImportError.unsupportedFileType
            }

            importProgress = 0.3

            let items = try await importer.importData(from: source)
            importProgress = 0.8

            importedItems = items
            importProgress = 1.0
        } catch {
            errorMessage = error.localizedDescription
        }

        isImporting = false
    }

    public func searchUSDA(_ foodName: String) async {
        isImporting = true
        errorMessage = nil

        do {
            let items = try await importer.importData(from: .usdaAPI(foodName))
            importedItems = items
        } catch {
            errorMessage = error.localizedDescription
        }

        isImporting = false
    }

    public func scanBarcode(_ barcode: String) async {
        isImporting = true
        errorMessage = nil

        do {
            let items = try await importer.importData(from: .barcode(barcode))
            importedItems = items
        } catch {
            errorMessage = error.localizedDescription
        }

        isImporting = false
    }

    public func exportData(format: NutritionExportFormat) async throws -> String {
        switch format {
        case .csv:
            try await importer.exportToCSV(importedItems)
        case .json:
            try await importer.exportToJSON(importedItems)
        }
    }

    public func clearImportedData() {
        importedItems = []
        errorMessage = nil
        importProgress = 0.0
    }
}

public enum NutritionExportFormat: String, Sendable {
    case csv = "CSV"
    case json = "JSON"
}
