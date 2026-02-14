// WorkflowScanner.swift
// Scanner for GitHub Actions workflow files

import Foundation

/// Scanner for GitHub Actions workflow security issues
struct WorkflowScanner: Scanner {
    let id = "workflow"
    let name = "GitHub Workflow Scanner"
    let description = "Scans GitHub Actions workflow files for security vulnerabilities"

    let filePatterns = [
        ".github/workflows/*.yml",
        ".github/workflows/*.yaml"
    ]

    let rules: [Rule] = [
        // Secrets and credential rules
        SecretsInEnvRule(),

        // Supply chain rules
        UntrustedActionRule(),
        MissingPinningRule(),

        // Permission rules
        ExcessivePermissionsRule(),

        // Trigger rules
        DangerousTriggerRule()
    ]
}
