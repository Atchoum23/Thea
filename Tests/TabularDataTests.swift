// TabularDataTests.swift
// Thea — ABA3: QA v2 — Wave 10 TabularData analysis
//
// Tests: TabularDataAnalyzer CSV parsing, summarization, financial analysis

import XCTest
import Foundation

#if os(macOS) && canImport(TabularData)
import TabularData
@testable import Thea

// MARK: - TabularDataAnalyzer Tests

final class TabularDataAnalyzerTests: XCTestCase {

    private var tempCSVURL: URL?

    override func tearDown() {
        super.tearDown()
        if let url = tempCSVURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Helpers

    private func writeTempCSV(_ content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("thea-test-\(UUID().uuidString).csv")
        try content.write(to: url, atomically: true, encoding: .utf8)
        tempCSVURL = url
        return url
    }

    // MARK: - Availability

    func testTabularDataAvailable() {
        XCTAssertTrue(TabularDataAnalyzer.isAvailable,
                      "TabularData should be available on macOS 13+")
    }

    // MARK: - CSV Loading

    func testAnalyzeCSVLoadsCorrectRowCount() throws {
        let csv = """
        name,value,category
        Alpha,10.0,A
        Beta,20.5,B
        Gamma,30.0,A
        """
        let url = try writeTempCSV(csv)
        let df = try TabularDataAnalyzer.analyzeCSV(at: url)
        XCTAssertEqual(df.rows.count, 3, "Should load exactly 3 data rows")
        XCTAssertEqual(df.columns.count, 3, "Should have 3 columns")
    }

    func testAnalyzeCSVColumnNames() throws {
        let csv = """
        date,amount,description
        2026-01-01,100.0,Coffee
        2026-01-02,-25.0,Transport
        """
        let url = try writeTempCSV(csv)
        let df = try TabularDataAnalyzer.analyzeCSV(at: url)
        let names = df.columns.map { $0.name }
        XCTAssertTrue(names.contains("date"), "Should have 'date' column")
        XCTAssertTrue(names.contains("amount"), "Should have 'amount' column")
        XCTAssertTrue(names.contains("description"), "Should have 'description' column")
    }

    // MARK: - Summarization

    func testSummarizeContainsRowCount() throws {
        let csv = """
        value
        1.0
        2.0
        3.0
        """
        let url = try writeTempCSV(csv)
        let df = try TabularDataAnalyzer.analyzeCSV(at: url)
        let summary = TabularDataAnalyzer.summarize(df)
        XCTAssertTrue(summary.contains("3"), "Summary should mention row count")
    }

    func testSummarizeContainsColumnNames() throws {
        let csv = """
        temperature,humidity
        22.5,60.0
        24.0,65.0
        """
        let url = try writeTempCSV(csv)
        let df = try TabularDataAnalyzer.analyzeCSV(at: url)
        let summary = TabularDataAnalyzer.summarize(df)
        XCTAssertTrue(summary.contains("temperature"), "Summary should mention column name 'temperature'")
        XCTAssertTrue(summary.contains("humidity"), "Summary should mention column name 'humidity'")
    }

    func testSummarizeContainsMinMaxAvg() throws {
        let csv = """
        amount
        10.0
        20.0
        30.0
        """
        let url = try writeTempCSV(csv)
        let df = try TabularDataAnalyzer.analyzeCSV(at: url)
        let summary = TabularDataAnalyzer.summarize(df)
        XCTAssertTrue(summary.contains("min"), "Summary should contain 'min' for numeric columns")
        XCTAssertTrue(summary.contains("max"), "Summary should contain 'max' for numeric columns")
        XCTAssertTrue(summary.contains("avg"), "Summary should contain 'avg' for numeric columns")
    }

    // MARK: - Financial CSV Analysis

    func testAnalyzeFinancialCSVComputesIncomeAndSpend() throws {
        let csv = """
        date,amount,merchant
        2026-01-01,1500.0,Salary
        2026-01-05,-80.0,Groceries
        2026-01-10,-120.0,Restaurant
        2026-01-15,200.0,Freelance
        """
        let url = try writeTempCSV(csv)
        let (_, _, income, spend) = try TabularDataAnalyzer.analyzeFinancialCSV(at: url)
        XCTAssertEqual(income, 1700.0, accuracy: 0.01, "Income should sum positive amounts")
        XCTAssertEqual(spend, 200.0, accuracy: 0.01, "Spend should sum absolute negative amounts")
    }

    func testFinancialCSVSummaryContainsNetLine() throws {
        let csv = """
        amount
        500.0
        -100.0
        """
        let url = try writeTempCSV(csv)
        let (_, summary, _, _) = try TabularDataAnalyzer.analyzeFinancialCSV(at: url)
        XCTAssertTrue(summary.contains("Net"), "Financial summary should contain Net line")
    }

    // MARK: - Health CSV Analysis

    func testAnalyzeHealthCSVReturnsSummary() throws {
        let csv = """
        date,steps,calories
        2026-01-01,8000.0,2100.0
        2026-01-02,10000.0,2300.0
        2026-01-03,7500.0,2000.0
        """
        let url = try writeTempCSV(csv)
        let (df, summary) = try TabularDataAnalyzer.analyzeHealthCSV(at: url)
        XCTAssertEqual(df.rows.count, 3, "Should load 3 health data rows")
        XCTAssertFalse(summary.isEmpty, "Health summary should not be empty")
        XCTAssertTrue(summary.contains("steps"), "Summary should mention 'steps'")
    }

    // MARK: - Error Handling

    func testInvalidFileThrows() {
        let badURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).csv")
        XCTAssertThrowsError(try TabularDataAnalyzer.analyzeCSV(at: badURL),
                             "analyzeCSV with invalid path should throw")
    }
}
#else

// Stub tests for platforms without TabularData
final class TabularDataAnalyzerTests: XCTestCase {
    func testTabularDataNotAvailableOnThisPlatform() {
        XCTAssertFalse(TabularDataAnalyzer.isAvailable,
                       "TabularData not available on this platform — expected")
    }
}
#endif
