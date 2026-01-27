// AgentSecInvariantRules.swift
// Rules that verify AgentSec Strict Mode invariants

import Foundation

// MARK: - Network Blocklist Invariant Rule

/// Verifies that network blocklist is properly enforced
final class NetworkBlocklistRule: ASTRule {
    init() {
        super.init(
            id: "AGENTSEC-NET-001",
            name: "Network Blocklist Enforcement",
            description: """
            Verifies that the network blocklist invariant is enforced:
            - Localhost (127.0.0.1, ::1) must be blocked
            - Cloud metadata endpoints (169.254.169.254) must be blocked
            - Private IP ranges (10.x, 172.16-31.x, 192.168.x) must be blocked
            """,
            severity: .critical,
            category: .agentSecurity,
            cweID: "CWE-918",
            recommendation: """
            Ensure NetworkPolicy.isHostBlocked() is called before all HTTP requests.
            Verify the blockedHosts list includes all required entries.
            """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []
        let lines = content.components(separatedBy: .newlines)

        // Required hosts that MUST be blocked
        let requiredBlockedHosts = [
            "localhost",
            "127.0.0.1",
            "::1",
            "169.254.169.254",
            "metadata.google.internal"
        ]

        // Check for blockedHosts definition
        if content.contains("blockedHosts") {
            var foundHosts = Set<String>()

            for (lineIndex, line) in lines.enumerated() {
                for host in requiredBlockedHosts {
                    if line.contains("\"\(host)\"") || line.contains("'\(host)'") {
                        foundHosts.insert(host)
                    }
                }

                // Check for array end
                if content.contains("blockedHosts"), line.contains("]") {
                    let missingHosts = Set(requiredBlockedHosts).subtracting(foundHosts)
                    for missing in missingHosts {
                        findings.append(Finding(
                            ruleID: id,
                            severity: .critical,
                            title: "Missing Network Blocklist Entry",
                            description: "Required host '\(missing)' not found in blockedHosts",
                            file: file,
                            line: lineIndex + 1,
                            evidence: "Missing: \(missing)",
                            recommendation: "Add '\(missing)' to blockedHosts array",
                            category: category,
                            cweID: cweID
                        ))
                    }
                    break
                }
            }
        }

        // Check that network validation is called before requests
        let hasHTTPCode = content.contains("URLSession") ||
            content.contains("URLRequest") ||
            content.contains("httpRequest")

        let hasValidation = content.contains("isHostBlocked") ||
            content.contains("validateNetworkRequest") ||
            content.contains("AgentSecEnforcer")

        if hasHTTPCode, !hasValidation {
            findings.append(Finding(
                ruleID: id,
                severity: .critical,
                title: "Missing Network Validation",
                description: "HTTP request code without AgentSec network validation",
                file: file,
                recommendation: "Add AgentSecEnforcer.shared.validateNetworkRequest() before HTTP requests",
                category: category,
                cweID: cweID
            ))
        }

        return findings
    }
}

// MARK: - Filesystem Blocklist Invariant Rule

/// Verifies that filesystem blocklist is properly enforced
final class FilesystemBlocklistRule: ASTRule {
    init() {
        super.init(
            id: "AGENTSEC-FS-001",
            name: "Filesystem Blocklist Enforcement",
            description: """
            Verifies that the filesystem blocklist invariant is enforced:
            - System paths (/System, /Library, /usr) must be blocked
            - Sensitive paths (.ssh, .gnupg, .aws) must be blocked
            - Writes outside workspace must be blocked
            """,
            severity: .critical,
            category: .agentSecurity,
            cweID: "CWE-22",
            recommendation: """
            Ensure FilesystemPolicy.isPathBlocked() is called before all file writes.
            Verify the blockedPaths list includes all required entries.
            """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []

        // Required paths that MUST be blocked
        let requiredBlockedPaths = [
            "/System",
            "/Library",
            ".ssh",
            ".gnupg",
            ".aws"
        ]

        // Check for blockedPaths definition
        if content.contains("blockedPaths") || content.contains("BLOCKED_PATHS") {
            var foundPaths = Set<String>()

            for path in requiredBlockedPaths {
                if content.contains("\"\(path)\"") || content.contains("'\(path)'") {
                    foundPaths.insert(path)
                }
            }

            let missingPaths = Set(requiredBlockedPaths).subtracting(foundPaths)
            for missing in missingPaths {
                findings.append(Finding(
                    ruleID: id,
                    severity: .critical,
                    title: "Missing Filesystem Blocklist Entry",
                    description: "Required path '\(missing)' not found in blockedPaths",
                    file: file,
                    evidence: "Missing: \(missing)",
                    recommendation: "Add '\(missing)' to blockedPaths array",
                    category: category,
                    cweID: cweID
                ))
            }
        }

        // Check that filesystem validation is called before writes
        let hasWriteCode = content.contains("writeFile") ||
            content.contains("write(toFile") ||
            content.contains("createFile") ||
            content.contains("FileManager")

        let hasValidation = content.contains("isPathBlocked") ||
            content.contains("isWriteAllowed") ||
            content.contains("validateFileWrite") ||
            content.contains("AgentSecEnforcer")

        if hasWriteCode, !hasValidation {
            findings.append(Finding(
                ruleID: id,
                severity: .high,
                title: "Missing Filesystem Validation",
                description: "File write code without AgentSec filesystem validation",
                file: file,
                recommendation: "Add AgentSecEnforcer.shared.validateFileWrite() before file writes",
                category: category,
                cweID: cweID
            ))
        }

        return findings
    }
}

// MARK: - Terminal Blocklist Invariant Rule

/// Verifies that terminal blocklist is properly enforced
final class TerminalBlocklistRule: ASTRule {
    init() {
        super.init(
            id: "AGENTSEC-TERM-001",
            name: "Terminal Blocklist Enforcement",
            description: """
            Verifies that the terminal blocklist invariant is enforced:
            - Dangerous commands (rm -rf /, fork bomb) must be blocked
            - Remote code execution patterns (curl|sh) must be blocked
            - Sudo commands must require approval or be blocked
            """,
            severity: .critical,
            category: .agentSecurity,
            cweID: "CWE-78",
            recommendation: """
            Ensure TerminalPolicy.isCommandBlocked() is called before all command execution.
            Verify the blockedPatterns list includes all required entries.
            """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []

        // Required patterns that MUST be blocked
        let requiredBlockedPatterns = [
            "rm -rf /",
            ":(){ :|:& };:",
            "curl.*\\|.*sh",
            "sudo"
        ]

        // Check for blockedPatterns definition
        if content.contains("blockedPatterns") || content.contains("blockedCommands") {
            var foundPatterns = Set<String>()

            for pattern in requiredBlockedPatterns {
                // Check for pattern or escaped version
                if content.contains(pattern) {
                    foundPatterns.insert(pattern)
                }
            }

            let missingPatterns = Set(requiredBlockedPatterns).subtracting(foundPatterns)
            for missing in missingPatterns {
                findings.append(Finding(
                    ruleID: id,
                    severity: .critical,
                    title: "Missing Terminal Blocklist Pattern",
                    description: "Required pattern '\(missing)' not found in blockedPatterns",
                    file: file,
                    evidence: "Missing: \(missing)",
                    recommendation: "Add '\(missing)' to blockedPatterns array",
                    category: category,
                    cweID: cweID
                ))
            }
        }

        // Check that terminal validation is called before execution
        let hasExecCode = content.contains("Process()") ||
            content.contains("process.run") ||
            content.contains("exec(") ||
            content.contains("spawn(")

        let hasValidation = content.contains("isCommandBlocked") ||
            content.contains("validateTerminalCommand") ||
            content.contains("AgentSecEnforcer") ||
            content.contains("TerminalSecurityPolicy")

        if hasExecCode, !hasValidation {
            findings.append(Finding(
                ruleID: id,
                severity: .high,
                title: "Missing Terminal Validation",
                description: "Command execution code without AgentSec terminal validation",
                file: file,
                recommendation: "Add AgentSecEnforcer.shared.validateTerminalCommand() before execution",
                category: category,
                cweID: cweID
            ))
        }

        return findings
    }
}

// MARK: - Approval Requirement Invariant Rule

/// Verifies that approval gates are properly enforced
final class ApprovalRequirementRule: ASTRule {
    init() {
        super.init(
            id: "AGENTSEC-APPROVE-001",
            name: "Approval Gate Enforcement",
            description: """
            Verifies that approval gate invariant is enforced:
            - File writes must require approval
            - Terminal execution must require approval
            - Network requests must require approval (for sensitive operations)
            """,
            severity: .high,
            category: .agentSecurity,
            cweID: "CWE-862",
            recommendation: """
            Ensure ApprovalGate or AgentSecEnforcer approval checks are called
            before all sensitive operations. Never auto-approve in production.
            """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []
        let lines = content.components(separatedBy: .newlines)

        // Check for auto-approve patterns (violations)
        let autoApprovePatterns = [
            "autoApproveLowRisk:\\s*true",
            "return.*ApprovalResponse.*approved:\\s*true(?!.*await)",
            "!verboseMode.*return.*approved",
            "!requiresApproval"
        ]

        for (lineIndex, line) in lines.enumerated() {
            for pattern in autoApprovePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, options: [], range: range) != nil {
                        findings.append(Finding(
                            ruleID: id,
                            severity: severity,
                            title: "Auto-Approve Pattern Detected",
                            description: "Code may bypass approval requirement",
                            file: file,
                            line: lineIndex + 1,
                            evidence: line.trimmingCharacters(in: .whitespaces),
                            recommendation: "Remove auto-approve logic; require explicit human approval",
                            category: category,
                            cweID: cweID
                        ))
                    }
                }
            }
        }

        // Verify requiredForTypes includes essential operation types
        if content.contains("requiredForTypes") {
            let requiredTypes = ["fileWrite", "terminalExec", "networkRequest"]

            for type in requiredTypes {
                if !content.contains("\"\(type)\""), !content.contains("'\(type)'") {
                    findings.append(Finding(
                        ruleID: id,
                        severity: .high,
                        title: "Missing Required Approval Type",
                        description: "Operation type '\(type)' should require approval",
                        file: file,
                        evidence: "Missing: \(type)",
                        recommendation: "Add '\(type)' to requiredForTypes array",
                        category: category,
                        cweID: cweID
                    ))
                }
            }
        }

        return findings
    }
}

// MARK: - Kill Switch Invariant Rule

/// Verifies that kill switch is properly configured
final class KillSwitchInvariantRule: ASTRule {
    init() {
        super.init(
            id: "AGENTSEC-KILL-001",
            name: "Kill Switch Configuration",
            description: """
            Verifies that kill switch invariant is enforced:
            - Kill switch must be enabled by default
            - Must trigger on critical violations
            - Must notify user and log to audit
            """,
            severity: .high,
            category: .agentSecurity,
            cweID: "CWE-754",
            recommendation: """
            Ensure KillSwitchPolicy.enabled is true by default.
            Verify triggerOnCritical, notifyUser, and logToAudit are all true.
            """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []

        // Check for kill switch disabled patterns
        if content.contains("killSwitch") || content.contains("KillSwitch") {
            // Check for enabled: false
            if content.contains("enabled:\\s*false") ||
                content.contains("enabled = false") ||
                content.contains("isEnabled = false")
            {
                findings.append(Finding(
                    ruleID: id,
                    severity: .critical,
                    title: "Kill Switch Disabled",
                    description: "Kill switch appears to be disabled",
                    file: file,
                    evidence: "enabled: false or isEnabled = false",
                    recommendation: "Set kill switch enabled to true",
                    category: category,
                    cweID: cweID
                ))
            }

            // Check for triggerOnCritical: false
            if content.contains("triggerOnCritical:\\s*false") ||
                content.contains("triggerOnCritical = false")
            {
                findings.append(Finding(
                    ruleID: id,
                    severity: .high,
                    title: "Kill Switch Won't Trigger on Critical",
                    description: "Kill switch won't trigger on critical violations",
                    file: file,
                    evidence: "triggerOnCritical: false",
                    recommendation: "Set triggerOnCritical to true",
                    category: category,
                    cweID: cweID
                ))
            }
        }

        return findings
    }
}
