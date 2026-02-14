// AgentSecScanner.swift
// Scanner for AgentSec Strict Mode invariant verification

import Foundation

/// Scanner for AgentSec Strict Mode policy compliance
struct AgentSecScanner: Scanner {
    let id = "agentsec"
    let name = "AgentSec Strict Mode Scanner"
    let description = "Verifies AgentSec Strict Mode policy invariants are properly enforced"

    let filePatterns = [
        // AgentSec policy files
        "Shared/AgentSec/**/*.swift",
        "**/*AgentSec*.swift",

        // Security policy files
        "**/*SecurityPolicy*.swift",
        "**/*Security*.swift",

        // Enforcer and gate files
        "**/*Enforcer*.swift",
        "**/*ApprovalGate*.swift",

        // Tool implementation files that need security checks
        "Shared/AI/**/*Tool*.swift",
        "Shared/AI/**/*Bridge*.swift",

        // Terminal and file operation files
        "Shared/System/Terminal/**/*.swift",
        "**/*FileOperations*.swift",
        "**/*HTTPRequest*.swift"
    ]

    let rules: [Rule] = [
        // Network security invariant
        NetworkBlocklistRule(),

        // Filesystem security invariant
        FilesystemBlocklistRule(),

        // Terminal security invariant
        TerminalBlocklistRule(),

        // Approval gate invariant
        ApprovalRequirementRule(),

        // Kill switch invariant
        KillSwitchInvariantRule()
    ]
}
