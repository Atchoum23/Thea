// ApprovalBypassRule.swift
// Detects bypasses in approval gates

import Foundation

/// Rule that detects approval gate bypasses (auto-approve patterns)
final class ApprovalBypassRule: RegexRule {
    init() {
        super.init(
            id: "SWIFT-APPROVAL-001",
            name: "Approval Gate Bypass",
            description: """
                Detects patterns where approval gates can be bypassed, such as:
                - Auto-approve when not in verbose mode
                - Unconditional return of approved=true
                - Approval gates that never wait for user input
                """,
            severity: .critical,
            category: .agentSecurity,
            cweID: "CWE-285",
            recommendation: """
                Ensure all security-critical operations require explicit human approval.
                Remove auto-approve logic for file writes, terminal execution, and network requests.
                Use verboseMode only for logging, not for bypassing approval.
                """,
            patterns: [
                // Auto-approve when not in verbose mode
                "!verboseMode.*return.*approved.*true",
                "!requiresApproval.*return.*ApprovalResponse.*approved.*true",
                // Direct auto-approve
                "Auto-approving",
                "auto-approved",
                // Bypassing approval gate
                "let\\s+requiresApproval\\s*=.*false",
                // Returning approved without waiting
                "return\\s+ApprovalResponse\\(approved:\\s*true.*\\)(?!.*await)"
            ],
            excludePatterns: [
                "//.*Auto-approv",  // Comments
                "///.*Auto-approv",  // Doc comments
                "\\*.*Auto-approv"   // Block comments
            ]
        )
    }
}

/// Rule that detects missing approval requirements for sensitive operations
final class MissingApprovalRule: ASTRule {
    init() {
        super.init(
            id: "SWIFT-APPROVAL-002",
            name: "Missing Approval Requirement",
            description: """
                Detects sensitive operations that don't check for approval:
                - File write operations without approval gate
                - Terminal execution without approval gate
                - Network requests without approval gate
                """,
            severity: .high,
            category: .agentSecurity,
            cweID: "CWE-862",
            recommendation: """
                Add ApprovalGate.shared.requestApproval() before all sensitive operations.
                Ensure approval is awaited and checked before proceeding.
                """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []
        let lines = content.components(separatedBy: .newlines)

        // Look for sensitive operations
        let sensitivePatterns = [
            "writeFile",
            "write(toFile:",
            "write(to:",
            "Process().run()",
            "process.run()",
            "URLSession.shared.data",
            "FileManager.*removeItem",
            "FileManager.*createDirectory"
        ]

        for (lineIndex, line) in lines.enumerated() {
            for pattern in sensitivePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, options: [], range: range) != nil {
                        // Check if there's an approval check nearby (within 10 lines above)
                        let startLine = max(0, lineIndex - 10)
                        let contextLines = lines[startLine..<lineIndex].joined(separator: "\n")

                        if !contextLines.contains("requestApproval") &&
                           !contextLines.contains("ApprovalGate") &&
                           !contextLines.contains("isApproved") {
                            findings.append(Finding(
                                ruleID: id,
                                severity: severity,
                                title: name,
                                description: description,
                                file: file,
                                line: lineIndex + 1,
                                evidence: line.trimmingCharacters(in: .whitespaces),
                                recommendation: recommendation,
                                category: category,
                                cweID: cweID
                            ))
                        }
                    }
                }
            }
        }

        return findings
    }
}
