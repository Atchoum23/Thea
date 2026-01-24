// YAMLWriter.swift
// YAML output writer for audit findings

import Foundation
import Yams

/// Writes audit findings to YAML format
struct YAMLWriter {
    /// Write findings and optional policy result to a YAML file
    static func write(findings: [Finding], policyResult: PolicyEvaluationResult?, to path: String) throws {
        let report = AuditReport(
            findings: findings,
            metadata: AuditMetadata(repositoryPath: ".")
        )

        // Create output structure
        var output: [String: Any] = [:]

        // Metadata
        output["metadata"] = [
            "version": report.metadata.version,
            "timestamp": ISO8601DateFormatter().string(from: report.metadata.timestamp),
            "repositoryPath": report.metadata.repositoryPath,
            "deltaMode": report.metadata.deltaMode
        ]

        // Summary
        output["summary"] = [
            "totalFindings": report.summary.totalFindings,
            "critical": report.summary.criticalCount,
            "high": report.summary.highCount,
            "medium": report.summary.mediumCount,
            "low": report.summary.lowCount,
            "filesScanned": report.summary.filesScanned,
            "categoryCounts": report.summary.categoryCounts
        ]

        // Findings
        output["findings"] = findings.map { finding -> [String: Any] in
            var findingDict: [String: Any] = [
                "id": finding.id,
                "ruleID": finding.ruleID,
                "severity": finding.severity.rawValue,
                "title": finding.title,
                "description": finding.description,
                "file": finding.file,
                "recommendation": finding.recommendation,
                "category": finding.category.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: finding.timestamp)
            ]

            if let line = finding.line {
                findingDict["line"] = line
            }
            if let column = finding.column {
                findingDict["column"] = column
            }
            if let evidence = finding.evidence {
                findingDict["evidence"] = evidence
            }
            if let cweID = finding.cweID {
                findingDict["cweID"] = cweID
            }

            return findingDict
        }

        // Policy result if available
        if let result = policyResult {
            output["policy"] = [
                "compliant": result.compliant,
                "violations": result.violations,
                "checkedInvariants": result.checkedInvariants
            ]
        }

        // Convert to YAML
        let yamlString = try Yams.dump(object: output, allowUnicode: true)

        // Write to file
        try yamlString.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
