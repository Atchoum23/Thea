// SARIFWriter.swift
// Writes findings in SARIF format for GitHub Security integration

import Foundation

/// Writes audit findings in SARIF (Static Analysis Results Interchange Format)
struct SARIFWriter {
    /// Write findings to a SARIF file
    static func write(findings: [Finding], to path: String) throws {
        let sarif = generateSARIF(findings: findings)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(sarif)
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// Generate SARIF structure from findings
    private static func generateSARIF(findings: [Finding]) -> SARIF {
        let rules = generateRules(from: findings)
        let results = findings.map { finding -> SARIFResult in
            SARIFResult(
                ruleId: finding.ruleID,
                ruleIndex: rules.firstIndex { $0.id == finding.ruleID } ?? 0,
                level: severityToLevel(finding.severity),
                message: SARIFMessage(text: finding.description),
                locations: [
                    SARIFLocation(
                        physicalLocation: SARIFPhysicalLocation(
                            artifactLocation: SARIFArtifactLocation(uri: finding.file),
                            region: SARIFRegion(
                                startLine: finding.line ?? 1,
                                startColumn: finding.column ?? 1
                            )
                        )
                    )
                ],
                fixes: finding.recommendation.map { rec in
                    [SARIFFix(description: SARIFMessage(text: rec))]
                }
            )
        }

        let run = SARIFRun(
            tool: SARIFTool(
                driver: SARIFDriver(
                    name: "thea-audit",
                    version: "1.0.0",
                    informationUri: "https://github.com/your-org/thea",
                    rules: rules
                )
            ),
            results: results
        )

        return SARIF(
            schema: "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
            version: "2.1.0",
            runs: [run]
        )
    }

    /// Generate unique rules from findings
    private static func generateRules(from findings: [Finding]) -> [SARIFRule] {
        var seenRules = Set<String>()
        var rules: [SARIFRule] = []

        for finding in findings {
            guard !seenRules.contains(finding.ruleID) else { continue }
            seenRules.insert(finding.ruleID)

            rules.append(SARIFRule(
                id: finding.ruleID,
                name: finding.title,
                shortDescription: SARIFMessage(text: finding.title),
                fullDescription: SARIFMessage(text: finding.description),
                help: SARIFHelp(
                    text: finding.recommendation ?? "Review and fix this security issue",
                    markdown: finding.recommendation.map { "**Recommendation:** \($0)" }
                ),
                properties: SARIFRuleProperties(
                    category: finding.category.rawValue,
                    security_severity: severityToScore(finding.severity),
                    cwe: finding.cweID
                )
            ))
        }

        return rules
    }

    /// Convert severity to SARIF level
    private static func severityToLevel(_ severity: Severity) -> String {
        switch severity {
        case .critical: return "error"
        case .high: return "error"
        case .medium: return "warning"
        case .low: return "note"
        }
    }

    /// Convert severity to security score (0-10)
    private static func severityToScore(_ severity: Severity) -> String {
        switch severity {
        case .critical: return "9.0"
        case .high: return "7.0"
        case .medium: return "5.0"
        case .low: return "3.0"
        }
    }
}

// MARK: - SARIF Data Structures

struct SARIF: Codable {
    let schema: String
    let version: String
    let runs: [SARIFRun]

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case version
        case runs
    }
}

struct SARIFRun: Codable {
    let tool: SARIFTool
    let results: [SARIFResult]
}

struct SARIFTool: Codable {
    let driver: SARIFDriver
}

struct SARIFDriver: Codable {
    let name: String
    let version: String
    let informationUri: String
    let rules: [SARIFRule]
}

struct SARIFRule: Codable {
    let id: String
    let name: String
    let shortDescription: SARIFMessage
    let fullDescription: SARIFMessage
    let help: SARIFHelp
    let properties: SARIFRuleProperties
}

struct SARIFMessage: Codable {
    let text: String
}

struct SARIFHelp: Codable {
    let text: String
    let markdown: String?
}

struct SARIFRuleProperties: Codable {
    let category: String
    let security_severity: String
    let cwe: String?

    enum CodingKeys: String, CodingKey {
        case category
        case security_severity = "security-severity"
        case cwe
    }
}

struct SARIFResult: Codable {
    let ruleId: String
    let ruleIndex: Int
    let level: String
    let message: SARIFMessage
    let locations: [SARIFLocation]
    let fixes: [SARIFFix]?
}

struct SARIFLocation: Codable {
    let physicalLocation: SARIFPhysicalLocation
}

struct SARIFPhysicalLocation: Codable {
    let artifactLocation: SARIFArtifactLocation
    let region: SARIFRegion
}

struct SARIFArtifactLocation: Codable {
    let uri: String
}

struct SARIFRegion: Codable {
    let startLine: Int
    let startColumn: Int
}

struct SARIFFix: Codable {
    let description: SARIFMessage
}
