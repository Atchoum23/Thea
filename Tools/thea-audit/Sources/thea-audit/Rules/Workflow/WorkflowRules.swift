// WorkflowRules.swift
// Security rules for GitHub Actions workflows

import Foundation

/// Rule that detects secrets exposed in environment variables
final class SecretsInEnvRule: RegexRule {
    init() {
        super.init(
            id: "WORKFLOW-SECRETS-001",
            name: "Secrets Exposed in Environment",
            description: """
            Detects secrets being exposed through environment variables in workflows.
            Secrets in env can be logged or accessed by child processes.
            """,
            severity: .high,
            category: .dataExposure,
            cweID: "CWE-200",
            recommendation: """
            Use secrets directly in steps that need them rather than exposing in env.
            Use GITHUB_TOKEN sparingly and with minimal permissions.
            Consider using OIDC for cloud provider authentication instead of long-lived secrets.
            """,
            patterns: [
                "env:.*\\$\\{\\{\\s*secrets\\.", // secrets in env block
                "export.*\\$\\{\\{\\s*secrets\\.", // export secrets
                "echo.*\\$\\{\\{\\s*secrets\\." // echo secrets
            ],
            excludePatterns: [
                "#.*secrets", // Comments
                "GITHUB_TOKEN" // GITHUB_TOKEN is generally safe
            ]
        )
    }
}

/// Rule that detects untrusted third-party actions
final class UntrustedActionRule: RegexRule {
    init() {
        super.init(
            id: "WORKFLOW-ACTION-001",
            name: "Untrusted Third-Party Action",
            description: """
            Detects usage of third-party GitHub Actions that:
            - Are not from verified publishers
            - Use mutable tags like @main or @master
            - Don't use commit SHA pinning
            """,
            severity: .medium,
            category: .supplyChain,
            cweID: "CWE-829",
            recommendation: """
            Pin third-party actions to specific commit SHAs.
            Prefer actions from verified publishers (github, actions/*).
            Review action source code before using.
            Consider vendoring critical actions.
            """,
            patterns: [
                "uses:.*@main",
                "uses:.*@master",
                "uses:.*@latest",
                "uses:.*@v\\d+$" // Major version only (not pinned to patch)
            ],
            excludePatterns: [
                "uses:\\s*actions/", // Official GitHub actions
                "uses:\\s*github/" // GitHub org actions
            ]
        )
    }
}

/// Rule that detects missing action version pinning
final class MissingPinningRule: ASTRule {
    init() {
        super.init(
            id: "WORKFLOW-PIN-001",
            name: "Missing Action Version Pinning",
            description: """
            Detects GitHub Actions that aren't pinned to a specific version.
            Using unpinned actions can lead to supply chain attacks.
            """,
            severity: .medium,
            category: .supplyChain,
            cweID: "CWE-829",
            recommendation: """
            Pin all actions to specific commit SHAs:
            - uses: actions/checkout@a5ac7e51b41094c92402da3b24376905380afc29 # v4.1.6
            Add comment with version for maintainability.
            """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []
        let lines = content.components(separatedBy: .newlines)

        // Regex to match action usage
        let usesPattern = try? NSRegularExpression(pattern: "uses:\\s*([^@]+)@(.+)", options: [])

        for (lineIndex, line) in lines.enumerated() {
            guard let regex = usesPattern,
                  let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line))
            else {
                continue
            }

            // Extract version part
            if let versionRange = Range(match.range(at: 2), in: line) {
                let version = String(line[versionRange]).trimmingCharacters(in: .whitespaces)

                // Check if it's a SHA (40 hex characters)
                let shaPattern = try? NSRegularExpression(pattern: "^[a-f0-9]{40}$", options: [])
                let isSHA = shaPattern?.firstMatch(in: version, options: [], range: NSRange(version.startIndex..., in: version)) != nil

                if !isSHA {
                    // Skip official actions for medium severity
                    if line.contains("actions/"), !line.contains("@main"), !line.contains("@master") {
                        continue
                    }

                    findings.append(Finding(
                        ruleID: id,
                        severity: severity,
                        title: name,
                        description: "Action not pinned to commit SHA: \(version)",
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

        return findings
    }
}

/// Rule that detects excessive permissions
final class ExcessivePermissionsRule: RegexRule {
    init() {
        super.init(
            id: "WORKFLOW-PERMS-001",
            name: "Excessive Workflow Permissions",
            description: """
            Detects workflows with excessive permissions:
            - write-all permission
            - Broad contents: write
            - Missing permission restrictions
            """,
            severity: .medium,
            category: .authorization,
            cweID: "CWE-250",
            recommendation: """
            Follow principle of least privilege:
            - Specify minimal required permissions
            - Use read-only permissions where possible
            - Avoid write-all permission
            """,
            patterns: [
                "permissions:\\s*write-all",
                "contents:\\s*write(?!.*#.*required)", // contents: write without justification
                "packages:\\s*write",
                "id-token:\\s*write" // OIDC token write (review needed)
            ],
            excludePatterns: [
                "#.*required",
                "#.*needed"
            ]
        )
    }
}

/// Rule that detects dangerous workflow triggers
final class DangerousTriggerRule: RegexRule {
    init() {
        super.init(
            id: "WORKFLOW-TRIGGER-001",
            name: "Dangerous Workflow Trigger",
            description: """
            Detects workflow triggers that could enable attacks:
            - pull_request_target with checkout
            - workflow_dispatch without input validation
            - issue_comment execution
            """,
            severity: .high,
            category: .injection,
            cweID: "CWE-94",
            recommendation: """
            For pull_request_target:
            - Never checkout PR code with write permissions
            - Use pull_request event instead where possible
            For workflow_dispatch:
            - Validate all inputs before use
            - Don't use inputs directly in shell commands
            """,
            patterns: [
                "pull_request_target:",
                "issue_comment:",
                "workflow_dispatch:(?!.*#.*validated)"
            ],
            excludePatterns: []
        )
    }
}
