// ScannerTests.swift
// Tests for security scanners

@testable import thea_audit
import XCTest

final class ScannerTests: XCTestCase {
    // MARK: - Finding Model Tests

    func testFindingCreation() {
        let finding = Finding(
            ruleID: "test-rule-001",
            severity: .high,
            title: "Test Finding",
            description: "This is a test finding",
            file: "test.swift",
            line: 42,
            recommendation: "Fix the issue",
            category: .injection
        )

        XCTAssertEqual(finding.ruleID, "test-rule-001")
        XCTAssertEqual(finding.severity, .high)
        XCTAssertEqual(finding.line, 42)
        XCTAssertEqual(finding.location, "test.swift:42")
    }

    func testFindingLocationWithColumn() {
        let finding = Finding(
            ruleID: "test-rule-001",
            severity: .medium,
            title: "Test Finding",
            description: "Description",
            file: "test.swift",
            line: 10,
            column: 5,
            recommendation: "Fix it",
            category: .codeQuality
        )

        XCTAssertEqual(finding.location, "test.swift:10:5")
    }

    // MARK: - Severity Tests

    func testSeverityComparison() {
        XCTAssertTrue(Severity.critical > Severity.high)
        XCTAssertTrue(Severity.high > Severity.medium)
        XCTAssertTrue(Severity.medium > Severity.low)
    }

    func testSeverityMeetsMinimum() {
        XCTAssertTrue(Severity.critical.meetsMinimum(.high))
        XCTAssertTrue(Severity.high.meetsMinimum(.high))
        XCTAssertFalse(Severity.medium.meetsMinimum(.high))
    }

    // MARK: - Scanner Registry Tests

    func testScannerRegistryInitialization() {
        let registry = ScannerRegistry()

        XCTAssertFalse(registry.scanners.isEmpty)
        XCTAssertEqual(registry.scanners.count, 4) // Swift, Workflow, Script, MCP
    }

    func testScannerLookupByID() {
        let registry = ScannerRegistry()

        let swiftScanner = registry.scanner(withID: "swift")
        XCTAssertNotNil(swiftScanner)
        XCTAssertEqual(swiftScanner?.name, "Swift Security Scanner")
    }

    // MARK: - Audit Summary Tests

    func testAuditSummaryCalculation() {
        let findings = [
            Finding(ruleID: "r1", severity: .critical, title: "T1", description: "D1", file: "f1.swift", recommendation: "R1", category: .injection),
            Finding(ruleID: "r2", severity: .high, title: "T2", description: "D2", file: "f2.swift", recommendation: "R2", category: .accessControl),
            Finding(ruleID: "r3", severity: .high, title: "T3", description: "D3", file: "f1.swift", recommendation: "R3", category: .injection),
            Finding(ruleID: "r4", severity: .medium, title: "T4", description: "D4", file: "f3.swift", recommendation: "R4", category: .configuration),
            Finding(ruleID: "r5", severity: .low, title: "T5", description: "D5", file: "f4.swift", recommendation: "R5", category: .codeQuality)
        ]

        let summary = AuditSummary(from: findings)

        XCTAssertEqual(summary.totalFindings, 5)
        XCTAssertEqual(summary.criticalCount, 1)
        XCTAssertEqual(summary.highCount, 2)
        XCTAssertEqual(summary.mediumCount, 1)
        XCTAssertEqual(summary.lowCount, 1)
        XCTAssertEqual(summary.filesScanned, 4)
    }
}
