// Scanner.swift
// Protocol for security scanners

import Foundation

/// Protocol for security scanners
protocol Scanner: Sendable {
    /// Unique identifier for this scanner
    var id: String { get }

    /// Human-readable name
    var name: String { get }

    /// Description of what this scanner checks
    var description: String { get }

    /// File patterns this scanner applies to (glob patterns)
    var filePatterns: [String] { get }

    /// Rules this scanner applies
    var rules: [Rule] { get }

    /// Scan a file and return findings
    func scan(file: String, content: String) -> [Finding]
}

// MARK: - Default Implementation

extension Scanner {
    /// Default scan implementation that runs all rules
    func scan(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []

        for rule in rules {
            let ruleFindings = rule.check(file: file, content: content)
            findings.append(contentsOf: ruleFindings)
        }

        return findings
    }
}

// MARK: - Scanner Categories

enum ScannerCategory: String, CaseIterable, Sendable {
    case swift = "Swift"
    case workflow = "GitHub Workflows"
    case script = "Shell Scripts"
    case mcp = "MCP Server"
    case configuration = "Configuration"
}
