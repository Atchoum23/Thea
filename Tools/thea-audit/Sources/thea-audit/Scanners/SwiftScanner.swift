// SwiftScanner.swift
// Scanner for Swift source files

import Foundation

/// Scanner for Swift source code security issues
struct SwiftScanner: Scanner {
    let id = "swift"
    let name = "Swift Security Scanner"
    let description = "Scans Swift source files for security vulnerabilities and agent security issues"

    let filePatterns = [
        "**/*.swift"
    ]

    let rules: [Rule] = [
        // Approval and authorization rules
        ApprovalBypassRule(),
        MissingApprovalRule(),

        // Allowlist/blocklist rules
        AllowlistGapRule(),

        // URL and network rules
        URLValidationRule(),
        HardcodedURLRule(),

        // Path and file system rules
        PathValidationRule(),
        PathTraversalRule()
    ]
}
