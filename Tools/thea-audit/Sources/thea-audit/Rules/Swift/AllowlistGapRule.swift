// AllowlistGapRule.swift
// Detects gaps in allowlists and blocklists

import Foundation

/// Rule that detects missing entries in security allowlists/blocklists
final class AllowlistGapRule: ASTRule {
    init() {
        super.init(
            id: "SWIFT-ALLOWLIST-001",
            name: "Security Allowlist/Blocklist Gap",
            description: """
                Detects gaps in security allowlists and blocklists:
                - Missing dangerous commands in blocklists
                - Empty or permissive allowlists
                - Missing sensitive path patterns
                """,
            severity: .high,
            category: .accessControl,
            cweID: "CWE-183",
            recommendation: """
                Review and update allowlists/blocklists to include all known dangerous patterns.
                Use comprehensive blocklists from security best practices.
                Prefer allowlists over blocklists where possible.
                """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []
        let lines = content.components(separatedBy: .newlines)

        // Required blocked commands
        let requiredBlockedCommands = [
            "rm -rf /",
            "rm -rf /*",
            ":(){ :|:& };:",  // Fork bomb
            "sudo",
            "curl.*\\|.*sh",
            "wget.*\\|.*bash"
        ]

        // Required blocked paths
        let requiredBlockedPaths = [
            "/System",
            "/Library",
            ".ssh",
            ".gnupg",
            ".aws",
            "Keychain"
        ]

        // Check for blocklist definitions
        var inBlocklist = false
        var blocklistContent = ""
        var blocklistStartLine = 0

        for (lineIndex, line) in lines.enumerated() {
            // Detect blocklist array start
            if line.contains("blockedCommands") || line.contains("blockedPatterns") || line.contains("blockedPaths") || line.contains("BLOCKED_PATHS") {
                inBlocklist = true
                blocklistStartLine = lineIndex
                blocklistContent = ""
            }

            if inBlocklist {
                blocklistContent += line + "\n"

                // Detect array end
                if line.contains("]") && !line.contains("[") {
                    // Check for missing patterns
                    if blocklistContent.contains("blockedCommands") || blocklistContent.contains("blockedPatterns") {
                        for required in requiredBlockedCommands {
                            // Escape regex special chars for literal search
                            let searchPattern = required.replacingOccurrences(of: "(", with: "\\(")
                                .replacingOccurrences(of: ")", with: "\\)")
                                .replacingOccurrences(of: "*", with: "\\*")

                            if !blocklistContent.contains(searchPattern.replacingOccurrences(of: "\\", with: "")) &&
                               !blocklistContent.contains(required) {
                                findings.append(Finding(
                                    ruleID: id,
                                    severity: .high,
                                    title: "Missing Blocked Command Pattern",
                                    description: "Blocklist is missing critical dangerous pattern: \(required)",
                                    file: file,
                                    line: blocklistStartLine + 1,
                                    evidence: "Missing: \(required)",
                                    recommendation: "Add '\(required)' to the blocklist",
                                    category: category,
                                    cweID: cweID
                                ))
                            }
                        }
                    }

                    if blocklistContent.contains("blockedPaths") || blocklistContent.contains("BLOCKED_PATHS") {
                        for required in requiredBlockedPaths {
                            if !blocklistContent.contains(required) {
                                findings.append(Finding(
                                    ruleID: id,
                                    severity: .high,
                                    title: "Missing Blocked Path Pattern",
                                    description: "Path blocklist is missing critical pattern: \(required)",
                                    file: file,
                                    line: blocklistStartLine + 1,
                                    evidence: "Missing: \(required)",
                                    recommendation: "Add '\(required)' to the blocked paths",
                                    category: category,
                                    cweID: cweID
                                ))
                            }
                        }
                    }

                    inBlocklist = false
                }
            }
        }

        // Check for empty allowlists that should have restrictions
        for (lineIndex, line) in lines.enumerated() {
            if line.contains("allowedCommands") && line.contains("[]") {
                findings.append(Finding(
                    ruleID: id,
                    severity: .medium,
                    title: "Empty Command Allowlist",
                    description: "Empty allowlist means all commands are allowed. Consider using explicit allowlist.",
                    file: file,
                    line: lineIndex + 1,
                    evidence: line.trimmingCharacters(in: .whitespaces),
                    recommendation: "Define an explicit list of allowed commands instead of allowing all",
                    category: category,
                    cweID: cweID
                ))
            }
        }

        return findings
    }
}
