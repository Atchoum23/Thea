//
//  TabularDataAnalyzer.swift
//  Thea — AAI3-3
//
//  CSV/tabular data analysis using Apple's TabularData framework (no SPM dependency).
//  Wired into financial transaction analysis and health CSV import.
//
//  TabularData is available on: macOS 12+, iOS 15+, tvOS 15+, watchOS 8+
//

import Foundation
import TabularData
import os.log

private let logger = Logger(subsystem: "app.thea", category: "TabularDataAnalyzer")

// MARK: - TabularDataAnalyzer

/// Analyzes CSV files and DataFrames for financial and health insights.
struct TabularDataAnalyzer {

    // MARK: - CSV Loading

    /// Load a CSV file into a DataFrame.
    static func analyzeCSV(at url: URL) throws -> DataFrame {
        logger.info("TabularDataAnalyzer: loading CSV at \(url.lastPathComponent)")
        return try DataFrame(contentsOfCSVFile: url)
    }

    /// Load CSV from a string (e.g. from API response body).
    static func analyzeCSVString(_ csvString: String) throws -> DataFrame {
        guard let data = csvString.data(using: .utf8) else {
            throw TabularError.invalidInput("Could not encode CSV string as UTF-8")
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".csv")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try DataFrame(contentsOfCSVFile: tempURL)
    }

    // MARK: - Summary Statistics

    /// One-line summary: row/column counts + column names.
    static func summarize(_ df: DataFrame) -> String {
        let colNames = df.columns.map(\.name).joined(separator: ", ")
        return "Rows: \(df.rows.count), Cols: \(df.columns.count) [\(colNames)]"
    }

    /// Detailed column-level statistics for numeric columns.
    static func columnStats(_ df: DataFrame) -> [ColumnStat] {
        df.columns.compactMap { column -> ColumnStat? in
            guard let doubles = column.assumingType(Double.self) else { return nil }

            let values = doubles.compactMap { $0 }
            guard !values.isEmpty else { return nil }

            let sorted = values.sorted()
            let count = Double(values.count)
            let sum = values.reduce(0, +)
            let mean = sum / count
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / count
            let stddev = sqrt(variance)
            let median = sorted.count % 2 == 0
                ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
                : sorted[sorted.count / 2]

            return ColumnStat(
                name: column.name,
                count: values.count,
                min: sorted.first ?? 0,
                max: sorted.last ?? 0,
                mean: mean,
                median: median,
                stddev: stddev,
                sum: sum
            )
        }
    }

    // MARK: - Financial Analysis

    /// Analyse financial transaction CSV (typical columns: date, amount, description, category).
    /// Returns per-category spending totals and top transactions.
    static func analyzeFinancialCSV(at url: URL) throws -> FinancialAnalysisResult {
        let df = try analyzeCSV(at: url)
        return analyzeFinancialDataFrame(df)
    }

    static func analyzeFinancialDataFrame(_ df: DataFrame) -> FinancialAnalysisResult {
        // Try to locate amount and category columns (case-insensitive)
        let amountCol = findColumn(df, names: ["amount", "Amount", "AMOUNT", "debit", "credit", "value"])
        let categoryCol = findColumn(df, names: ["category", "Category", "CATEGORY", "type", "Type"])
        let descCol = findColumn(df, names: ["description", "Description", "memo", "Memo", "name", "Name"])

        var categoryTotals: [String: Double] = [:]
        var topExpenses: [(desc: String, amount: Double)] = []

        for row in df.rows {
            let amount = amountValue(row: row, column: amountCol)
            let category = stringValue(row: row, column: categoryCol) ?? "Uncategorized"
            let desc = stringValue(row: row, column: descCol) ?? ""

            if amount < 0 { // Negative = expense
                categoryTotals[category, default: 0] += abs(amount)
                topExpenses.append((desc: desc, amount: abs(amount)))
            }
        }

        let top5 = topExpenses.sorted { $0.amount > $1.amount }.prefix(5).map {
            TopTransaction(description: $0.desc, amount: $0.amount)
        }

        return FinancialAnalysisResult(
            rowCount: df.rows.count,
            columnCount: df.columns.count,
            categoryTotals: categoryTotals,
            topExpenses: Array(top5),
            totalSpend: categoryTotals.values.reduce(0, +)
        )
    }

    // MARK: - Health CSV Import

    /// Parse a health export CSV (e.g. Apple Health export or Whoop export).
    /// Returns cleaned DataFrame ready for HealthKit import.
    static func parseHealthCSV(at url: URL) throws -> HealthCSVResult {
        let df = try analyzeCSV(at: url)

        let dateCol = findColumn(df, names: ["date", "Date", "DATE", "timestamp", "Timestamp", "startDate"])
        let valueCol = findColumn(df, names: ["value", "Value", "VALUE", "quantity", "Quantity", "steps", "Steps"])
        let typeCol = findColumn(df, names: ["type", "Type", "TYPE", "metric", "Metric", "name", "Name"])

        var records: [HealthCSVRecord] = []

        for row in df.rows {
            let dateStr = stringValue(row: row, column: dateCol) ?? ""
            let value = amountValue(row: row, column: valueCol)
            let type_ = stringValue(row: row, column: typeCol) ?? "unknown"

            guard !dateStr.isEmpty, value != 0 else { continue }

            records.append(HealthCSVRecord(
                dateString: dateStr,
                value: value,
                metricType: type_
            ))
        }

        logger.info("TabularDataAnalyzer: parsed \(records.count) health records from \(url.lastPathComponent)")

        return HealthCSVResult(
            sourceFile: url.lastPathComponent,
            rowCount: df.rows.count,
            validRecords: records
        )
    }

    // MARK: - Private Helpers

    private static func findColumn(_ df: DataFrame, names: [String]) -> String? {
        names.first { name in df.columns.contains { $0.name == name } }
    }

    private static func stringValue(row: DataFrame.Rows.Element, column: String?) -> String? {
        guard let col = column else { return nil }
        return row[col, String.self]
    }

    private static func amountValue(row: DataFrame.Rows.Element, column: String?) -> Double {
        guard let col = column else { return 0 }
        if let d = row[col, Double.self] { return d }
        if let s = row[col, String.self], let d = Double(s.replacingOccurrences(of: ",", with: "")) { return d }
        return 0
    }
}

// MARK: - Result Types

struct ColumnStat: Sendable {
    let name: String
    let count: Int
    let min: Double
    let max: Double
    let mean: Double
    let median: Double
    let stddev: Double
    let sum: Double
}

struct FinancialAnalysisResult: Sendable {
    let rowCount: Int
    let columnCount: Int
    let categoryTotals: [String: Double]   // Category → total spend
    let topExpenses: [TopTransaction]
    let totalSpend: Double
}

struct TopTransaction: Sendable {
    let description: String
    let amount: Double
}

struct HealthCSVResult: Sendable {
    let sourceFile: String
    let rowCount: Int
    let validRecords: [HealthCSVRecord]
}

struct HealthCSVRecord: Sendable {
    let dateString: String    // ISO 8601 or locale date string
    let value: Double
    let metricType: String    // e.g. "steps", "heartRate", "activeEnergy"
}

// MARK: - Error

enum TabularError: LocalizedError {
    case invalidInput(String)
    case missingColumn(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let msg):   return "TabularData input error: \(msg)"
        case .missingColumn(let name): return "Required column '\(name)' not found in CSV"
        }
    }
}
