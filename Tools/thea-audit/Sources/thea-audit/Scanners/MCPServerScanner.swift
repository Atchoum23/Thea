// MCPServerScanner.swift
// Scanner for MCP server TypeScript files

import Foundation

/// Scanner for MCP server security issues
struct MCPServerScanner: Scanner {
    let id = "mcp"
    let name = "MCP Server Scanner"
    let description = "Scans MCP server files for security vulnerabilities"

    let filePatterns = [
        "Tools/**/*.ts",
        "Tools/**/*.tsx"
    ]

    let rules: [Rule] = [
        // Path and file security rules
        PathRestrictionRule(),

        // Injection rules
        CommandInjectionRule(),

        // Code quality rules
        UnsafeTypeScriptRule(),

        // Input validation rules
        MissingInputValidationRule()
    ]
}
