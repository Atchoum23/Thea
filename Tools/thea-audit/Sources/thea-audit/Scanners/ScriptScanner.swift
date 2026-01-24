// ScriptScanner.swift
// Scanner for shell script files

import Foundation

/// Scanner for shell script security issues
struct ScriptScanner: Scanner {
    let id = "script"
    let name = "Shell Script Scanner"
    let description = "Scans shell scripts for security vulnerabilities"

    let filePatterns = [
        "**/*.sh",
        "Scripts/*"
    ]

    let rules: [Rule] = [
        // Remote code execution rules
        CurlPipeRule(),

        // Privilege escalation rules
        SudoUsageRule(),

        // Credential rules
        HardcodedCredsRule(),

        // Injection rules
        UnsafeEvalRule(),
        UnquotedVariableRule(),

        // File operation rules
        DangerousFileOpsRule()
    ]
}
