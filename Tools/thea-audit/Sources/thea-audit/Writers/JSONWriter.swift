// JSONWriter.swift
// JSON output writer for audit findings

import Foundation

/// Writes audit findings to JSON format
enum JSONWriter {
    /// Write findings and optional policy result to a JSON file
    static func write(findings: [Finding], policyResult: PolicyEvaluationResult?, to path: String) throws {
        let report = AuditReport(
            findings: findings,
            metadata: AuditMetadata(repositoryPath: ".")
        )

        // Create encoder
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        // Create combined output
        struct CombinedOutput: Codable {
            let report: AuditReport
            let policy: PolicyEvaluationResult?
        }

        let output = CombinedOutput(report: report, policy: policyResult)

        // Encode and write
        let data = try encoder.encode(output)
        try data.write(to: URL(fileURLWithPath: path))
    }
}
