// Finding.swift
// Model for security audit findings

import Foundation

/// Represents a security finding from the audit
struct Finding: Codable, Identifiable, Sendable {
    let id: String
    let ruleID: String
    let severity: Severity
    let title: String
    let description: String
    let file: String
    let line: Int?
    let column: Int?
    let evidence: String?
    let recommendation: String
    let category: FindingCategory
    let cweID: String?
    let timestamp: Date

    init(
        ruleID: String,
        severity: Severity,
        title: String,
        description: String,
        file: String,
        line: Int? = nil,
        column: Int? = nil,
        evidence: String? = nil,
        recommendation: String,
        category: FindingCategory,
        cweID: String? = nil
    ) {
        self.id = UUID().uuidString
        self.ruleID = ruleID
        self.severity = severity
        self.title = title
        self.description = description
        self.file = file
        self.line = line
        self.column = column
        self.evidence = evidence
        self.recommendation = recommendation
        self.category = category
        self.cweID = cweID
        self.timestamp = Date()
    }

    /// Location string for display
    var location: String {
        if let line = line, let column = column {
            return "\(file):\(line):\(column)"
        } else if let line = line {
            return "\(file):\(line)"
        }
        return file
    }
}

/// Category of security finding
enum FindingCategory: String, Codable, CaseIterable, Sendable {
    case authentication = "Authentication"
    case authorization = "Authorization"
    case injection = "Injection"
    case cryptography = "Cryptography"
    case dataExposure = "Data Exposure"
    case configuration = "Configuration"
    case inputValidation = "Input Validation"
    case accessControl = "Access Control"
    case codeQuality = "Code Quality"
    case supplyChain = "Supply Chain"
    case agentSecurity = "Agent Security"

    var icon: String {
        switch self {
        case .authentication: return "person.badge.key"
        case .authorization: return "lock.shield"
        case .injection: return "syringe"
        case .cryptography: return "key"
        case .dataExposure: return "eye.slash"
        case .configuration: return "gearshape"
        case .inputValidation: return "checkmark.shield"
        case .accessControl: return "hand.raised"
        case .codeQuality: return "ladybug"
        case .supplyChain: return "shippingbox"
        case .agentSecurity: return "brain.head.profile"
        }
    }
}

/// Collection of findings with summary statistics
struct AuditReport: Codable, Sendable {
    let findings: [Finding]
    let summary: AuditSummary
    let metadata: AuditMetadata

    init(findings: [Finding], metadata: AuditMetadata) {
        self.findings = findings
        self.summary = AuditSummary(from: findings)
        self.metadata = metadata
    }
}

/// Summary statistics for an audit
struct AuditSummary: Codable, Sendable {
    let totalFindings: Int
    let criticalCount: Int
    let highCount: Int
    let mediumCount: Int
    let lowCount: Int
    let filesScanned: Int
    let categoryCounts: [String: Int]

    init(from findings: [Finding]) {
        self.totalFindings = findings.count
        self.criticalCount = findings.filter { $0.severity == .critical }.count
        self.highCount = findings.filter { $0.severity == .high }.count
        self.mediumCount = findings.filter { $0.severity == .medium }.count
        self.lowCount = findings.filter { $0.severity == .low }.count

        // Count unique files
        self.filesScanned = Set(findings.map { $0.file }).count

        // Count by category
        var categories: [String: Int] = [:]
        for finding in findings {
            categories[finding.category.rawValue, default: 0] += 1
        }
        self.categoryCounts = categories
    }
}

/// Metadata about the audit run
struct AuditMetadata: Codable, Sendable {
    let version: String
    let timestamp: Date
    let repositoryPath: String
    let deltaMode: Bool
    let baseBranch: String?
    let scannersUsed: [String]
    let duration: TimeInterval?

    init(
        repositoryPath: String,
        deltaMode: Bool = false,
        baseBranch: String? = nil,
        scannersUsed: [String] = [],
        duration: TimeInterval? = nil
    ) {
        self.version = "1.0.0"
        self.timestamp = Date()
        self.repositoryPath = repositoryPath
        self.deltaMode = deltaMode
        self.baseBranch = baseBranch
        self.scannersUsed = scannersUsed
        self.duration = duration
    }
}
