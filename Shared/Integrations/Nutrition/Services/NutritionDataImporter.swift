import Foundation

import Combine

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
        guard let csvData = try? String(contentsOf: url, encoding: .utf8) else {
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
        guard let jsonData = try? Data(contentsOf: url) else {
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

    private func importFromUSDA(_ foodName: String) async throws -> [FoodItem] {
        // Would implement actual USDA FoodData Central API call
        // For now, return mock data

        guard !foodName.isEmpty else {
            throw ImportError.invalidFormat
        }

        // Simulate API call
        try await Task.sleep(for: .milliseconds(500))

        // Mock USDA API response
        var mockNutrients = NutrientProfile()
        mockNutrients.calories = 150.0
        mockNutrients.protein = 5.0
        mockNutrients.carbohydrates = 25.0
        mockNutrients.totalFat = 3.0
        mockNutrients.fiber = 3.0
        mockNutrients.sugars = 5.0

        let mockItem = FoodItem(
            name: foodName,
            brand: "USDA",
            servingSize: 100,
            servingUnit: .gram,
            nutrients: mockNutrients,
            barcode: nil
        )

        return [mockItem]
    }

    private func importFromBarcode(_ barcode: String) async throws -> [FoodItem] {
        // Would implement barcode lookup (Open Food Facts API, etc.)
        guard !barcode.isEmpty else {
            throw ImportError.invalidFormat
        }

        // Validate barcode format (UPC-A is 12 digits, EAN is 13)
        guard barcode.count == 12 || barcode.count == 13 else {
            throw ImportError.invalidFormat
        }

        // Simulate API call
        try await Task.sleep(for: .milliseconds(800))

        // Mock barcode lookup response
        var mockNutrients = NutrientProfile()
        mockNutrients.calories = 200.0
        mockNutrients.protein = 8.0
        mockNutrients.carbohydrates = 30.0
        mockNutrients.totalFat = 5.0
        mockNutrients.fiber = 4.0
        mockNutrients.sugars = 12.0

        let mockItem = FoodItem(
            name: "Scanned Product",
            brand: "Brand Name",
            servingSize: 100,
            servingUnit: .gram,
            nutrients: mockNutrients,
            barcode: barcode
        )

        return [mockItem]
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
