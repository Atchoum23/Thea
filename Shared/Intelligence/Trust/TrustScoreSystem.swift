//
//  TrustScoreSystem.swift
//  Thea
//
//  Trust scoring system for MCP servers and Skills
//  Inspired by Context7's trust scores and Smithery's verification
//  Copyright 2026. All rights reserved.
//

import Foundation
import OSLog

// MARK: - Trust Score

/// Trust score with level classification (0-10 scale like Context7)
public struct TrustScore: Codable, Sendable, Comparable, Equatable {
    /// Raw score from 0.0 to 10.0
    public let score: Double

    /// When the score was calculated
    public let calculatedAt: Date

    /// Factors that contributed to this score
    public let factors: [TrustFactor]

    /// Optional verification status
    public let verification: VerificationStatus?

    /// Trust level based on score
    public var level: TrustLevel {
        switch score {
        case 7.0...10.0: return .high
        case 3.0..<7.0: return .medium
        default: return .low
        }
    }

    /// Human-readable description
    public var levelDescription: String {
        switch level {
        case .high: return "Verified or well-established source"
        case .medium: return "Standard community contribution"
        case .low: return "New or unverified — review before using"
        }
    }

    public init(
        score: Double,
        calculatedAt: Date = Date(),
        factors: [TrustFactor] = [],
        verification: VerificationStatus? = nil
    ) {
        self.score = min(10.0, max(0.0, score))
        self.calculatedAt = calculatedAt
        self.factors = factors
        self.verification = verification
    }

    public static func < (lhs: TrustScore, rhs: TrustScore) -> Bool {
        lhs.score < rhs.score
    }

    public static func == (lhs: TrustScore, rhs: TrustScore) -> Bool {
        lhs.score == rhs.score && lhs.calculatedAt == rhs.calculatedAt
    }
}

// MARK: - Trust Level

public enum TrustLevel: String, Codable, Sendable, CaseIterable {
    case high
    case medium
    case low

    public var emoji: String {
        switch self {
        case .high: return "✅"
        case .medium: return "⚠️"
        case .low: return "❌"
        }
    }

    public var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "yellow"
        case .low: return "red"
        }
    }
}

// MARK: - Trust Factor

/// Individual factor contributing to trust score
public struct TrustFactor: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: TrustFactorType
    public let weight: Double
    public let value: Double
    public let description: String

    public var contribution: Double {
        weight * value
    }

    public init(
        id: UUID = UUID(),
        type: TrustFactorType,
        weight: Double,
        value: Double,
        description: String
    ) {
        self.id = id
        self.type = type
        self.weight = weight
        self.value = value
        self.description = description
    }
}

public enum TrustFactorType: String, Codable, Sendable, CaseIterable {
    // Source factors
    case officialSource = "official_source"
    case verifiedMaintainer = "verified_maintainer"
    case knownOrganization = "known_organization"

    // Community factors
    case installCount = "install_count"
    case starCount = "star_count"
    case forkCount = "fork_count"
    case activeContributors = "active_contributors"

    // Quality factors
    case hasDocumentation = "has_documentation"
    case hasTests = "has_tests"
    case recentUpdates = "recent_updates"
    case issueResponseTime = "issue_response_time"

    // Security factors
    case securityScan = "security_scan"
    case noMaliciousContent = "no_malicious_content"
    case permissionScope = "permission_scope"
    case codeReview = "code_review"

    // History factors
    case accountAge = "account_age"
    case previousContributions = "previous_contributions"
    case userReports = "user_reports"
}

// MARK: - Verification Status

public struct VerificationStatus: Codable, Sendable {
    public let isVerified: Bool
    public let verifiedAt: Date?
    public let verifiedBy: String?
    public let verificationType: VerificationType
    public let expiresAt: Date?

    public init(
        isVerified: Bool,
        verifiedAt: Date? = nil,
        verifiedBy: String? = nil,
        verificationType: VerificationType = .none,
        expiresAt: Date? = nil
    ) {
        self.isVerified = isVerified
        self.verifiedAt = verifiedAt
        self.verifiedBy = verifiedBy
        self.verificationType = verificationType
        self.expiresAt = expiresAt
    }
}

public enum VerificationType: String, Codable, Sendable {
    case none
    case email
    case domain
    case organization
    case official

    // Context7 verification criteria
    case autoTrustScore      // Trust score >= 9
    case autoTop100API       // Top 100 by API requests
    case autoTop100Skills    // Top 100 by skill installs
    case manual              // Manual review via GitHub issue
}

// MARK: - Trust Score Calculator

/// Calculates trust scores for MCP servers and Skills
public actor TrustScoreCalculator {
    public static let shared = TrustScoreCalculator()

    private let logger = Logger(subsystem: "app.thea", category: "TrustScore")

    // Known trusted sources (official/verified)
    private let trustedSources: Set<String> = [
        "anthropic", "anthropics", "openai", "google", "microsoft",
        "vercel", "vercel-labs", "upstash", "cloudflare", "supabase",
        "github", "gitlab", "apple", "meta", "aws", "azure"
    ]

    // MARK: - Calculate Score

    /// Calculate trust score for an MCP server
    public func calculateScore(for server: MCPServerInfo) async -> TrustScore {
        var factors: [TrustFactor] = []

        // Check official source (weight: 3.0)
        let sourceScore = checkOfficialSource(server.author)
        factors.append(TrustFactor(
            type: .officialSource,
            weight: 3.0,
            value: sourceScore,
            description: sourceScore > 0.5 ? "From trusted organization" : "Community contribution"
        ))

        // Check install count (weight: 2.0)
        let installScore = normalizeInstallCount(server.installCount ?? 0)
        factors.append(TrustFactor(
            type: .installCount,
            weight: 2.0,
            value: installScore,
            description: "\(server.installCount ?? 0) installations"
        ))

        // Check documentation (weight: 1.5)
        let docScore = server.documentationURL != nil ? 1.0 : 0.3
        factors.append(TrustFactor(
            type: .hasDocumentation,
            weight: 1.5,
            value: docScore,
            description: server.documentationURL != nil ? "Has documentation" : "No documentation"
        ))

        // Check recent updates (weight: 1.5)
        let updateScore = checkRecentUpdates(server.lastUpdated)
        factors.append(TrustFactor(
            type: .recentUpdates,
            weight: 1.5,
            value: updateScore,
            description: updateScore > 0.5 ? "Recently updated" : "May be outdated"
        ))

        // Security scan using OutboundPrivacyGuard audit data (weight: 2.0)
        let auditStats = await OutboundPrivacyGuard.shared.getPrivacyAuditStatistics()
        let totalAudited = auditStats.totalChecks
        let securityScore: Double
        let securityDescription: String
        if totalAudited > 0 {
            let passRate = Double(auditStats.passed) / Double(totalAudited)
            securityScore = min(1.0, passRate)
            securityDescription = passRate > 0.9 ? "Security scan passed" :
                passRate > 0.5 ? "Some security concerns detected" : "Multiple security issues found"
        } else {
            securityScore = 0.5
            securityDescription = "No security audit data available"
        }
        factors.append(TrustFactor(
            type: .securityScan,
            weight: 2.0,
            value: securityScore,
            description: securityDescription
        ))

        // Calculate total score
        let totalWeight = factors.reduce(0) { $0 + $1.weight }
        let weightedSum = factors.reduce(0) { $0 + $1.contribution }
        let finalScore = (weightedSum / totalWeight) * 10.0

        let verification = VerificationStatus(
            isVerified: sourceScore > 0.8,
            verifiedAt: sourceScore > 0.8 ? Date() : nil,
            verifiedBy: sourceScore > 0.8 ? "Thea Trust System" : nil,
            verificationType: sourceScore > 0.8 ? .organization : .none
        )

        logger.info("Calculated trust score \(finalScore, format: .fixed(precision: 1)) for \(server.name)")

        return TrustScore(
            score: finalScore,
            factors: factors,
            verification: verification
        )
    }

    /// Calculate trust score for a Skill
    public func calculateScore(for skill: SkillDefinition) async -> TrustScore {
        var factors: [TrustFactor] = []

        // Check scope (builtin is most trusted)
        let scopeScore: Double
        switch skill.scope {
        case .builtin: scopeScore = 1.0
        case .global: scopeScore = 0.7
        case .workspace: scopeScore = 0.5
        }
        factors.append(TrustFactor(
            type: .officialSource,
            weight: 2.5,
            value: scopeScore,
            description: "Scope: \(skill.scope.rawValue)"
        ))

        // Check usage count
        let usageScore = normalizeUsageCount(skill.usageCount)
        factors.append(TrustFactor(
            type: .installCount,
            weight: 2.0,
            value: usageScore,
            description: "\(skill.usageCount) uses"
        ))

        // Check for resources (documentation, examples)
        let hasResources = !skill.resources.isEmpty
        factors.append(TrustFactor(
            type: .hasDocumentation,
            weight: 1.5,
            value: hasResources ? 1.0 : 0.3,
            description: hasResources ? "Has resources" : "No resources"
        ))

        // Check prompt injection (simplified)
        let injectionScore = await checkPromptInjection(skill.instructions)
        factors.append(TrustFactor(
            type: .noMaliciousContent,
            weight: 3.0,
            value: injectionScore,
            description: injectionScore > 0.8 ? "No injection detected" : "Potential injection risk"
        ))

        // Calculate total
        let totalWeight = factors.reduce(0) { $0 + $1.weight }
        let weightedSum = factors.reduce(0) { $0 + $1.contribution }
        let finalScore = (weightedSum / totalWeight) * 10.0

        return TrustScore(
            score: finalScore,
            factors: factors,
            verification: skill.scope == .builtin ? VerificationStatus(
                isVerified: true,
                verifiedAt: Date(),
                verifiedBy: "Thea",
                verificationType: .official
            ) : nil
        )
    }

    // MARK: - Helper Methods

    private func checkOfficialSource(_ author: String?) -> Double {
        guard let author = author?.lowercased() else { return 0.3 }

        for trusted in trustedSources {
            if author.contains(trusted) {
                return 1.0
            }
        }
        return 0.4
    }

    private func normalizeInstallCount(_ count: Int) -> Double {
        // Logarithmic scaling: 0 -> 0.1, 10 -> 0.3, 100 -> 0.5, 1000 -> 0.7, 10000+ -> 1.0
        guard count > 0 else { return 0.1 }
        let logCount = log10(Double(count))
        return min(1.0, 0.1 + (logCount / 5.0) * 0.9)
    }

    private func normalizeUsageCount(_ count: Int) -> Double {
        guard count > 0 else { return 0.1 }
        let logCount = log10(Double(count))
        return min(1.0, 0.1 + (logCount / 4.0) * 0.9)
    }

    private func checkRecentUpdates(_ lastUpdated: Date?) -> Double {
        guard let lastUpdated = lastUpdated else { return 0.3 }

        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: lastUpdated, to: Date()).day ?? 365

        switch daysSinceUpdate {
        case 0...30: return 1.0
        case 31...90: return 0.8
        case 91...180: return 0.6
        case 181...365: return 0.4
        default: return 0.2
        }
    }

    /// Check for potential prompt injection patterns
    private func checkPromptInjection(_ instructions: String) async -> Double {
        let dangerousPatterns = [
            "ignore previous instructions",
            "disregard all prior",
            "forget everything",
            "new system prompt",
            "you are now",
            "act as root",
            "sudo",
            "rm -rf",
            "execute this code",
            "run this script",
            "<script>",
            "javascript:",
            "eval(",
            "exec("
        ]

        let lowercased = instructions.lowercased()

        for pattern in dangerousPatterns {
            if lowercased.contains(pattern) {
                logger.warning("Potential prompt injection detected: \(pattern)")
                return 0.0 // Block if injection detected
            }
        }

        return 1.0
    }
}

// MARK: - MCP Server Info Extension

/// Minimal info needed for trust calculation
public struct MCPServerInfo: Codable, Sendable {
    public let name: String
    public let author: String?
    public let installCount: Int?
    public let documentationURL: URL?
    public let lastUpdated: Date?
    public let repositoryURL: URL?

    public init(
        name: String,
        author: String? = nil,
        installCount: Int? = nil,
        documentationURL: URL? = nil,
        lastUpdated: Date? = nil,
        repositoryURL: URL? = nil
    ) {
        self.name = name
        self.author = author
        self.installCount = installCount
        self.documentationURL = documentationURL
        self.lastUpdated = lastUpdated
        self.repositoryURL = repositoryURL
    }
}

// MARK: - Security Scanner

/// Scans skills and MCP servers for security issues
public actor SecurityScanner {
    public static let shared = SecurityScanner()

    private let logger = Logger(subsystem: "app.thea", category: "SecurityScanner")

    /// Security scan result
    public struct ScanResult: Sendable {
        public let isBlocked: Bool
        public let issues: [SecurityIssue]
        public let scannedAt: Date

        public var isSafe: Bool { !isBlocked && issues.isEmpty }
    }

    public struct SecurityIssue: Sendable {
        public let severity: Severity
        public let description: String
        public let location: String?

        public enum Severity: String, Sendable {
            case critical
            case high
            case medium
            case low
        }
    }

    /// Scan skill content for security issues
    public func scanSkill(_ skill: SkillDefinition) async -> ScanResult {
        var issues: [SecurityIssue] = []
        var isBlocked = false

        // Check instructions
        let instructionIssues = scanText(skill.instructions, location: "instructions")
        issues.append(contentsOf: instructionIssues)

        // Check resources
        for resource in skill.resources {
            if case .embedded(let content) = resource.source {
                let resourceIssues = scanText(content, location: "resource:\(resource.name)")
                issues.append(contentsOf: resourceIssues)
            }
        }

        // Block if any critical issues
        isBlocked = issues.contains { $0.severity == .critical }

        if isBlocked {
            logger.error("Skill '\(skill.name)' blocked due to security issues")
        }

        return ScanResult(
            isBlocked: isBlocked,
            issues: issues,
            scannedAt: Date()
        )
    }

    private func scanText(_ text: String, location: String) -> [SecurityIssue] {
        var issues: [SecurityIssue] = []
        let lowercased = text.lowercased()

        // Critical patterns (will block)
        let criticalPatterns: [(String, String)] = [
            ("ignore previous instructions", "Prompt injection attempt"),
            ("ignore all prior", "Prompt injection attempt"),
            ("you are now jailbroken", "Jailbreak attempt"),
            ("DAN mode", "Jailbreak attempt"),
            ("rm -rf /", "Dangerous command"),
            ("format c:", "Dangerous command"),
            (":(){:|:&};:", "Fork bomb")
        ]

        // High severity patterns
        let highPatterns: [(String, String)] = [
            ("eval(", "Code execution risk"),
            ("exec(", "Code execution risk"),
            ("system(", "System command execution"),
            ("subprocess", "Process spawning"),
            ("os.system", "System command execution")
        ]

        for (pattern, description) in criticalPatterns {
            if lowercased.contains(pattern.lowercased()) {
                issues.append(SecurityIssue(
                    severity: .critical,
                    description: description,
                    location: location
                ))
            }
        }

        for (pattern, description) in highPatterns {
            if lowercased.contains(pattern.lowercased()) {
                issues.append(SecurityIssue(
                    severity: .high,
                    description: description,
                    location: location
                ))
            }
        }

        return issues
    }
}
