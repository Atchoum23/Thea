// Rule.swift
// Protocol for security rules

import Foundation

/// Protocol for security rules that check for specific vulnerabilities
protocol Rule: Sendable {
    /// Unique identifier for this rule
    var id: String { get }

    /// Human-readable name
    var name: String { get }

    /// Description of what this rule checks
    var description: String { get }

    /// Default severity for findings from this rule
    var severity: Severity { get }

    /// Category of findings from this rule
    var category: FindingCategory { get }

    /// CWE ID if applicable
    var cweID: String? { get }

    /// Recommendation for fixing findings
    var recommendation: String { get }

    /// Check a file for violations of this rule
    func check(file: String, content: String) -> [Finding]
}

// MARK: - Base Rule Implementation

// @unchecked Sendable: all properties (id, name, patterns, etc.) are let constants set at init;
// RegexRule is immutable after construction and safe to use from concurrent audit scan tasks
/// Base class for regex-based rules
class RegexRule: Rule, @unchecked Sendable {
    let id: String
    let name: String
    let description: String
    let severity: Severity
    let category: FindingCategory
    let cweID: String?
    let recommendation: String

    /// Patterns to search for (findings are created for matches)
    let patterns: [String]

    /// Patterns that indicate a false positive (matches are ignored)
    let excludePatterns: [String]

    init(
        id: String,
        name: String,
        description: String,
        severity: Severity,
        category: FindingCategory,
        cweID: String? = nil,
        recommendation: String,
        patterns: [String],
        excludePatterns: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.severity = severity
        self.category = category
        self.cweID = cweID
        self.recommendation = recommendation
        self.patterns = patterns
        self.excludePatterns = excludePatterns
    }

    func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []
        let lines = content.components(separatedBy: .newlines)

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            for (lineIndex, line) in lines.enumerated() {
                let range = NSRange(line.startIndex..., in: line)
                let matches = regex.matches(in: line, options: [], range: range)

                for match in matches {
                    // Check if this is a false positive
                    if isExcluded(line: line) {
                        continue
                    }

                    // Extract matched text for evidence
                    let matchRange = Range(match.range, in: line)
                    let evidence = matchRange.map { String(line[$0]) }

                    findings.append(Finding(
                        ruleID: id,
                        severity: severity,
                        title: name,
                        description: description,
                        file: file,
                        line: lineIndex + 1,
                        evidence: evidence,
                        recommendation: recommendation,
                        category: category,
                        cweID: cweID
                    ))
                }
            }
        }

        return findings
    }

    /// Check if a line matches any exclude pattern
    private func isExcluded(line: String) -> Bool {
        for pattern in excludePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(line.startIndex..., in: line)
            if regex.firstMatch(in: line, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }
}

// MARK: - AST-based Rule (for Swift)

// @unchecked Sendable: all properties are let constants set at init; ASTRule is immutable after
// construction and safe for concurrent use in parallel audit scan tasks
/// Base class for AST-based rules that analyze Swift code structure
class ASTRule: Rule, @unchecked Sendable {
    let id: String
    let name: String
    let description: String
    let severity: Severity
    let category: FindingCategory
    let cweID: String?
    let recommendation: String

    init(
        id: String,
        name: String,
        description: String,
        severity: Severity,
        category: FindingCategory,
        cweID: String? = nil,
        recommendation: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.severity = severity
        self.category = category
        self.cweID = cweID
        self.recommendation = recommendation
    }

    /// Override in subclass to implement AST-based checking
    func check(file _: String, content _: String) -> [Finding] {
        // Default implementation does nothing
        // Subclasses should override to implement actual checking
        []
    }
}
