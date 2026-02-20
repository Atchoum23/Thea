// TabularDataAnalyzer.swift
// Thea — AAI3-3: Tabular Data Analysis
//
// DataFrame-backed CSV analysis for financial + health data.
// Uses Apple's TabularData framework (iOS 16.4+, macOS 13+).
// Wire in: FinancialIntelligenceService.analyzeCSV() + ChatManager context injection.

import Foundation
import OSLog

#if canImport(TabularData)
import TabularData
#endif

// MARK: - Tabular Data Analyzer

/// Analyzes CSV files using Apple's TabularData framework.
/// Provides financial and health data analysis with natural-language summaries.
struct TabularDataAnalyzer {

    private static let logger = Logger(subsystem: "app.thea", category: "TabularDataAnalyzer")

    // MARK: - CSV Analysis

#if canImport(TabularData)

    /// Load a CSV file into a DataFrame for analysis.
    /// - Parameter url: Local file URL pointing to a CSV file.
    /// - Returns: A `DataFrame` for further processing.
    /// - Throws: `TabularDataError` or file-not-found errors.
    static func analyzeCSV(at url: URL) throws -> DataFrame {
        let options = CSVReadingOptions(hasHeaderRow: true, ignoresEmptyLines: true)
        let df = try DataFrame(contentsOfCSVFile: url, options: options)
        logger.info("Loaded CSV '\(url.lastPathComponent)': \(df.rows.count) rows, \(df.columns.count) columns")
        return df
    }

    /// Produce a natural-language summary of a DataFrame.
    /// Covers row/column counts, column names, numeric statistics (min/max/mean).
    /// - Parameter df: The DataFrame to summarize.
    /// - Returns: Multiline summary string suitable for AI context injection.
    static func summarize(_ df: DataFrame) -> String {
        var lines: [String] = [
            "CSV Analysis — \(df.rows.count) rows × \(df.columns.count) columns"
        ]

        // Column overview
        let columnNames = df.columns.map { $0.name }.joined(separator: ", ")
        lines.append("Columns: \(columnNames)")

        // Numeric column statistics (col.assumingType returns Column<T>, not optional)
        for col in df.columns {
            let doubles = col.assumingType(Double.self)
            let values = doubles.compactMap { $0 }
            guard !values.isEmpty else { continue }
            let min = values.min()!
            let max = values.max()!
            let mean = values.reduce(0, +) / Double(values.count)
            lines.append(
                "\(col.name): min=\(String(format: "%.2f", min))  max=\(String(format: "%.2f", max))  avg=\(String(format: "%.2f", mean))"
            )
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Financial CSV Analysis

    /// Specialized analysis for financial transaction CSVs.
    /// Looks for amount/total columns and computes spend/income breakdown.
    /// - Parameter url: Local file URL pointing to a financial CSV.
    /// - Returns: Tuple of (DataFrame, summary string, income, spend).
    static func analyzeFinancialCSV(at url: URL) throws -> (DataFrame, String, Double, Double) {
        let df = try analyzeCSV(at: url)

        // Heuristic: find an "amount" or "total" column
        let amountColName = df.columns.first {
            let lower = $0.name.lowercased()
            return lower.contains("amount") || lower.contains("total") || lower.contains("value")
        }?.name

        var income: Double = 0
        var spend: Double = 0

        if let name = amountColName,
           let col = df.columns.first(where: { $0.name == name }) {
            let typed = col.assumingType(Double.self)
            for val in typed {
                let v = val ?? 0
                if v >= 0 { income += v } else { spend += abs(v) }
            }
        }

        var summary = summarize(df)
        if amountColName != nil {
            summary += "\nIncome: \(String(format: "%.2f", income))  Spend: \(String(format: "%.2f", spend))  Net: \(String(format: "%.2f", income - spend))"
        }

        logger.info("Financial CSV summary computed — income=\(income) spend=\(spend)")
        return (df, summary, income, spend)
    }

    // MARK: - Health CSV Analysis

    /// Specialized analysis for health data CSVs (e.g., Apple Health exports).
    /// Focuses on date + value columns for trend detection.
    /// - Parameter url: Local file URL pointing to a health CSV.
    /// - Returns: Tuple of (DataFrame, summary string).
    static func analyzeHealthCSV(at url: URL) throws -> (DataFrame, String) {
        let df = try analyzeCSV(at: url)
        let summary = summarize(df)
        logger.info("Health CSV summary computed for '\(url.lastPathComponent)'")
        return (df, summary)
    }

#else

    // MARK: - Fallback Stubs (TabularData not available)

    static func analyzeCSV(at url: URL) throws -> Never {
        throw TabularDataAnalyzerError.frameworkUnavailable
    }

    static func summarize(_ placeholder: Never) -> String { "" }

    static func analyzeFinancialCSV(at url: URL) throws -> Never {
        throw TabularDataAnalyzerError.frameworkUnavailable
    }

    static func analyzeHealthCSV(at url: URL) throws -> Never {
        throw TabularDataAnalyzerError.frameworkUnavailable
    }

#endif

    // MARK: - Availability Check

    /// Returns true if TabularData is available on this platform.
    static var isAvailable: Bool {
#if canImport(TabularData)
        return true
#else
        return false
#endif
    }
}

// MARK: - Error

enum TabularDataAnalyzerError: Error, LocalizedError {
    case frameworkUnavailable
    case noAmountColumn
    case parseFailure(String)

    var errorDescription: String? {
        switch self {
        case .frameworkUnavailable: return "TabularData framework not available on this platform."
        case .noAmountColumn:       return "No amount/total column found in CSV."
        case .parseFailure(let m):  return "CSV parse failure: \(m)"
        }
    }
}
