import Foundation

import Combine

public actor AssessmentDataExporter {
    public static let shared = AssessmentDataExporter()

    public enum ExportFormat: String, Sendable {
        case pdf = "PDF"
        case csv = "CSV"
        case json = "JSON"
        case text = "TXT"
    }

    public enum ExportError: Error, Sendable, LocalizedError {
        case noData
        case encodingFailed
        case fileCreationFailed
        case unsupportedFormat

        public var errorDescription: String? {
            switch self {
            case .noData:
                "No assessment data available to export"
            case .encodingFailed:
                "Failed to encode assessment data"
            case .fileCreationFailed:
                "Failed to create export file"
            case .unsupportedFormat:
                "Unsupported export format"
            }
        }
    }

    private init() {}

    // MARK: - Public API

    /// Exports a single assessment to specified format
    public func exportAssessment(_ assessment: Assessment, format: ExportFormat) async throws -> String {
        switch format {
        case .pdf:
            try await generatePDFReport(assessment)
        case .csv:
            try generateCSV([assessment])
        case .json:
            try generateJSON([assessment])
        case .text:
            generateTextReport(assessment)
        }
    }

    /// Exports multiple assessments to specified format
    public func exportAssessments(_ assessments: [Assessment], format: ExportFormat) async throws -> String {
        guard !assessments.isEmpty else {
            throw ExportError.noData
        }

        switch format {
        case .pdf:
            return try await generateBatchPDFReport(assessments)
        case .csv:
            return try generateCSV(assessments)
        case .json:
            return try generateJSON(assessments)
        case .text:
            return generateBatchTextReport(assessments)
        }
    }

    // MARK: - CSV Export

    private func generateCSV(_ assessments: [Assessment]) throws -> String {
        var csv = "Type,Date,Overall Score,Interpretation,Recommendations\n"

        for assessment in assessments {
            let row = [
                escapeCSV(assessment.type.rawValue),
                formatDate(assessment.completedDate),
                "\(assessment.score.overall)",
                escapeCSV(assessment.interpretation),
                escapeCSV(assessment.recommendations.joined(separator: "; "))
            ]
            csv += row.joined(separator: ",") + "\n"
        }

        return csv
    }

    // MARK: - JSON Export

    private func generateJSON(_ assessments: [Assessment]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(assessments),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            throw ExportError.encodingFailed
        }

        return jsonString
    }

    // MARK: - Text Report Export

    private func generateTextReport(_ assessment: Assessment) -> String {
        var report = """
        ================================================================================
        ASSESSMENT REPORT
        ================================================================================

        Assessment Type: \(assessment.type.rawValue)
        Completion Date: \(formatDateLong(assessment.completedDate))

        --------------------------------------------------------------------------------
        OVERALL SCORE
        --------------------------------------------------------------------------------
        \(Int(assessment.score.overall))/100

        Rating: \(getRating(assessment.score.overall))

        """

        // Add subscores if available
        if !assessment.score.subscores.isEmpty {
            report += """
            --------------------------------------------------------------------------------
            DETAILED SCORES
            --------------------------------------------------------------------------------

            """

            for (dimension, score) in assessment.score.subscores {
                report += "\(dimension): \(Int(score))/100\n"
            }

            report += "\n"
        }

        // Add interpretation
        report += """
        --------------------------------------------------------------------------------
        INTERPRETATION
        --------------------------------------------------------------------------------
        \(assessment.interpretation)

        """

        // Add recommendations
        if !assessment.recommendations.isEmpty {
            report += """
            --------------------------------------------------------------------------------
            RECOMMENDATIONS
            --------------------------------------------------------------------------------

            """

            for (index, recommendation) in assessment.recommendations.enumerated() {
                report += "\(index + 1). \(recommendation)\n"
            }

            report += "\n"
        }

        report += """
        ================================================================================
        End of Report
        ================================================================================
        """

        return report
    }

    private func generateBatchTextReport(_ assessments: [Assessment]) -> String {
        var report = """
        ================================================================================
        ASSESSMENT SUMMARY REPORT
        ================================================================================

        Total Assessments: \(assessments.count)
        Report Generated: \(formatDateLong(Date()))

        """

        for (index, assessment) in assessments.enumerated() {
            report += """

            [\(index + 1)] \(assessment.type.rawValue)
            Date: \(formatDateLong(assessment.completedDate))
            Score: \(Int(assessment.score.overall))/100 (\(getRating(assessment.score.overall)))

            """
        }

        report += """

        ================================================================================
        End of Summary Report
        ================================================================================
        """

        return report
    }

    // MARK: - PDF Export (Mock Implementation)

    private func generatePDFReport(_ assessment: Assessment) async throws -> String {
        // Would generate actual PDF using CoreGraphics/PDFKit
        // For now, return text-based representation
        try await Task.sleep(for: .milliseconds(500))

        return """
        PDF Export (Mock)

        This would be a formatted PDF document containing:
        - Assessment type and date
        - Graphical score visualization
        - Detailed subscores with charts
        - Full interpretation
        - Recommendations list
        - Historical trend if available

        Assessment: \(assessment.type.rawValue)
        Score: \(Int(assessment.score.overall))/100
        Date: \(formatDateLong(assessment.completedDate))
        """
    }

    private func generateBatchPDFReport(_ assessments: [Assessment]) async throws -> String {
        try await Task.sleep(for: .milliseconds(800))

        return """
        Batch PDF Export (Mock)

        Would include:
        - Executive summary
        - Individual assessment reports
        - Comparative analysis
        - Progress trends over time
        - Combined recommendations

        Total Assessments: \(assessments.count)
        """
    }

    // MARK: - Helper Methods

    private func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatDateLong(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func getRating(_ score: Double) -> String {
        if score >= 85 { return "Excellent" }
        if score >= 70 { return "Good" }
        if score >= 55 { return "Average" }
        if score >= 40 { return "Below Average" }
        return "Needs Improvement"
    }
}

// MARK: - Export Coordinator

@MainActor
public final class AssessmentExportCoordinator: ObservableObject {
    @Published public var isExporting = false
    @Published public var exportedContent: String?
    @Published public var errorMessage: String?

    private let exporter = AssessmentDataExporter.shared

    public init() {}

    public func exportSingle(_ assessment: Assessment, format: AssessmentDataExporter.ExportFormat) async {
        isExporting = true
        errorMessage = nil

        do {
            let content = try await exporter.exportAssessment(assessment, format: format)
            exportedContent = content
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    public func exportMultiple(_ assessments: [Assessment], format: AssessmentDataExporter.ExportFormat) async {
        isExporting = true
        errorMessage = nil

        do {
            let content = try await exporter.exportAssessments(assessments, format: format)
            exportedContent = content
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    public func saveToFile(_ content: String, filename: String) throws {
        // Would implement file saving to user's directory
        // Mock implementation
        print("Saving to file: \(filename)")
        print("Content length: \(content.count) characters")
    }

    public func shareContent(_ content: String) {
        // Would implement system share sheet
        exportedContent = content
    }
}

// MARK: - Assessment Comparison Utility

public actor AssessmentComparison {
    public static let shared = AssessmentComparison()

    private init() {}

    /// Compares two assessments of the same type
    public func compare(_ first: Assessment, _ second: Assessment) async throws -> ComparisonReport {
        guard first.type == second.type else {
            throw AssessmentDataExporter.ExportError.unsupportedFormat
        }

        let scoreDifference = second.score.overall - first.score.overall
        let percentageChange = (scoreDifference / first.score.overall) * 100

        var subscoreChanges: [String: Double] = [:]
        for (dimension, firstScore) in first.score.subscores {
            if let secondScore = second.score.subscores[dimension] {
                subscoreChanges[dimension] = secondScore - firstScore
            }
        }

        return ComparisonReport(
            firstAssessment: first,
            secondAssessment: second,
            overallChange: scoreDifference,
            percentageChange: percentageChange,
            subscoreChanges: subscoreChanges,
            improvement: scoreDifference > 0
        )
    }

    /// Generates a trend report from multiple assessments
    public func analyzeTrend(_ assessments: [Assessment]) async throws -> TrendReport {
        guard assessments.count >= 2 else {
            throw AssessmentDataExporter.ExportError.noData
        }

        let sorted = assessments.sorted { $0.completedDate < $1.completedDate }

        // SAFETY: Use guard to safely unwrap first and last elements
        guard let firstAssessment = sorted.first, let lastAssessment = sorted.last else {
            throw AssessmentDataExporter.ExportError.noData
        }

        let scores = sorted.map(\.score.overall)

        let firstScore = scores.first ?? 0
        let lastScore = scores.last ?? 0
        let change = lastScore - firstScore

        // Calculate trend direction
        let recentScores = Array(scores.suffix(3))
        let isImproving = recentScores.last ?? 0 > recentScores.first ?? 0

        return TrendReport(
            assessmentCount: assessments.count,
            dateRange: (firstAssessment.completedDate, lastAssessment.completedDate),
            initialScore: firstScore,
            currentScore: lastScore,
            totalChange: change,
            averageScore: scores.reduce(0, +) / Double(scores.count),
            trend: isImproving ? "Improving" : "Declining"
        )
    }
}

public struct ComparisonReport: Sendable {
    public let firstAssessment: Assessment
    public let secondAssessment: Assessment
    public let overallChange: Double
    public let percentageChange: Double
    public let subscoreChanges: [String: Double]
    public let improvement: Bool
}

public struct TrendReport: Sendable {
    public let assessmentCount: Int
    public let dateRange: (start: Date, end: Date)
    public let initialScore: Double
    public let currentScore: Double
    public let totalChange: Double
    public let averageScore: Double
    public let trend: String
}
