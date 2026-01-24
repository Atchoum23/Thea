// AuditCommand.swift
// Main audit command with all CLI flags

import ArgumentParser
import Foundation

struct AuditCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Run security audit on the repository"
    )

    // MARK: - Arguments

    @Option(name: .shortAndLong, help: "Path to repository root")
    var path: String = "."

    @Option(name: .shortAndLong, help: "Output format (yaml, json, sarif, markdown)")
    var format: OutputFormat = .yaml

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String?

    @Option(name: .long, help: "Minimum severity to report (critical, high, medium, low)")
    var severity: Severity = .low

    @Flag(name: .long, help: "Delta mode - only scan changed files (requires git)")
    var delta: Bool = false

    @Flag(name: .long, help: "Strict mode - fail on any high or critical finding")
    var strict: Bool = false

    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false

    @Option(name: .long, help: "Policy file path for AgentSec evaluation")
    var policy: String?

    @Option(name: .long, help: "Base branch for delta mode comparison")
    var baseBranch: String = "main"

    // MARK: - Execution

    func run() throws {
        let startTime = Date()

        if verbose {
            print("thea-audit v1.0.0")
            print("================")
            print("Path: \(path)")
            print("Format: \(format.rawValue)")
            print("Severity: \(severity.rawValue)")
            print("Delta mode: \(delta)")
            print("Strict mode: \(strict)")
            print("")
        }

        // Initialize audit engine
        let engine = AuditEngine(
            repositoryPath: path,
            deltaMode: delta,
            baseBranch: baseBranch,
            minimumSeverity: severity,
            verbose: verbose
        )

        // Run the audit
        let findings = try engine.run()

        // Evaluate against policy if provided
        var policyResult: PolicyEvaluationResult?
        if let policyPath = policy {
            let evaluator = PolicyEvaluator(policyPath: policyPath)
            policyResult = try evaluator.evaluate(findings: findings)
        }

        // Generate output
        let outputPath = output ?? "thea-audit-report.\(format.fileExtension)"

        switch format {
        case .yaml:
            try YAMLWriter.write(findings: findings, policyResult: policyResult, to: outputPath)
        case .json:
            try JSONWriter.write(findings: findings, policyResult: policyResult, to: outputPath)
        case .sarif:
            try SARIFWriter.write(findings: findings, to: outputPath)
        case .markdown:
            try MarkdownWriter.write(findings: findings, policyResult: policyResult, to: outputPath)
        }

        // Generate markdown summary (unless markdown was the primary format)
        if format != .markdown {
            let markdownPath = outputPath.replacingOccurrences(of: ".\(format.fileExtension)", with: ".md")
            try MarkdownWriter.write(findings: findings, policyResult: policyResult, to: markdownPath)
        }

        // Print summary
        let duration = Date().timeIntervalSince(startTime)
        printSummary(findings: findings, policyResult: policyResult, duration: duration)

        // Strict mode: exit with error if high/critical findings
        if strict {
            let criticalCount = findings.filter { $0.severity == .critical }.count
            let highCount = findings.filter { $0.severity == .high }.count

            if criticalCount > 0 || highCount > 0 {
                throw AuditError.strictModeViolation(
                    critical: criticalCount,
                    high: highCount
                )
            }
        }
    }

    private func printSummary(findings: [Finding], policyResult: PolicyEvaluationResult?, duration: TimeInterval) {
        print("")
        print("Audit Summary")
        print("=============")
        print("Duration: \(String(format: "%.2f", duration))s")
        print("")

        let criticalCount = findings.filter { $0.severity == .critical }.count
        let highCount = findings.filter { $0.severity == .high }.count
        let mediumCount = findings.filter { $0.severity == .medium }.count
        let lowCount = findings.filter { $0.severity == .low }.count

        print("Findings:")
        print("  Critical: \(criticalCount)")
        print("  High:     \(highCount)")
        print("  Medium:   \(mediumCount)")
        print("  Low:      \(lowCount)")
        print("  Total:    \(findings.count)")

        if let result = policyResult {
            print("")
            print("Policy Compliance: \(result.compliant ? "PASS" : "FAIL")")
            if !result.violations.isEmpty {
                print("Violations: \(result.violations.count)")
                for violation in result.violations.prefix(5) {
                    print("  - \(violation)")
                }
                if result.violations.count > 5 {
                    print("  ... and \(result.violations.count - 5) more")
                }
            }
        }

        print("")

        if criticalCount > 0 {
            print("RESULT: CRITICAL issues found - immediate remediation required")
        } else if highCount > 0 {
            print("RESULT: HIGH severity issues found - remediation recommended")
        } else if mediumCount > 0 {
            print("RESULT: MEDIUM severity issues found - review recommended")
        } else {
            print("RESULT: PASS - no significant issues found")
        }
    }
}

// MARK: - Supporting Types

enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
    case yaml
    case json
    case sarif
    case markdown

    var fileExtension: String {
        switch self {
        case .yaml: return "yaml"
        case .json: return "json"
        case .sarif: return "sarif"
        case .markdown: return "md"
        }
    }
}

enum AuditError: Error, CustomStringConvertible {
    case strictModeViolation(critical: Int, high: Int)
    case fileNotFound(String)
    case invalidPolicy(String)
    case scannerError(String)

    var description: String {
        switch self {
        case .strictModeViolation(let critical, let high):
            return "Strict mode violation: \(critical) critical, \(high) high findings"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidPolicy(let reason):
            return "Invalid policy: \(reason)"
        case .scannerError(let reason):
            return "Scanner error: \(reason)"
        }
    }
}
