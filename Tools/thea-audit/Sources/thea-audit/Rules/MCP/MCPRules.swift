// MCPRules.swift
// Security rules for MCP server TypeScript files

import Foundation

/// Rule that validates path restriction implementation
final class PathRestrictionRule: ASTRule {
    init() {
        super.init(
            id: "MCP-PATH-001",
            name: "MCP Path Restriction Validation",
            description: """
                Validates that MCP servers properly implement path restrictions:
                - ALLOWED_DIRECTORIES list exists
                - BLOCKED_PATHS list exists
                - isPathAllowed function is implemented
                - Path validation is called before file operations
                """,
            severity: .critical,
            category: .accessControl,
            cweID: "CWE-22",
            recommendation: """
                Implement comprehensive path restrictions:
                - Define ALLOWED_DIRECTORIES allowlist
                - Define BLOCKED_PATHS blocklist
                - Create isPathAllowed() validation function
                - Call isPathAllowed() before all file operations
                - Resolve paths before validation to prevent bypass
                """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []
        let lines = content.components(separatedBy: .newlines)

        // Check for required security constructs
        let hasAllowedDirs = content.contains("ALLOWED_DIRECTORIES")
        let hasBlockedPaths = content.contains("BLOCKED_PATHS") || content.contains("blockedPaths")
        let hasPathValidation = content.contains("isPathAllowed") || content.contains("validatePath")

        // Check for file operations
        let hasFileOps = content.contains("fs.") ||
                         content.contains("readFile") ||
                         content.contains("writeFile") ||
                         content.contains("unlink") ||
                         content.contains("mkdir")

        if hasFileOps {
            if !hasAllowedDirs {
                findings.append(Finding(
                    ruleID: id,
                    severity: .high,
                    title: "Missing ALLOWED_DIRECTORIES",
                    description: "MCP server performs file operations but lacks ALLOWED_DIRECTORIES allowlist",
                    file: file,
                    recommendation: recommendation,
                    category: category,
                    cweID: cweID
                ))
            }

            if !hasBlockedPaths {
                findings.append(Finding(
                    ruleID: id,
                    severity: .high,
                    title: "Missing BLOCKED_PATHS",
                    description: "MCP server performs file operations but lacks BLOCKED_PATHS blocklist",
                    file: file,
                    recommendation: recommendation,
                    category: category,
                    cweID: cweID
                ))
            }

            if !hasPathValidation {
                findings.append(Finding(
                    ruleID: id,
                    severity: .critical,
                    title: "Missing Path Validation Function",
                    description: "MCP server performs file operations without path validation function",
                    file: file,
                    recommendation: recommendation,
                    category: category,
                    cweID: cweID
                ))
            }
        }

        // Check that path validation is actually used
        if hasPathValidation {
            // Find file operation calls and verify they use validation
            let fileOpPatterns = [
                "readFile\\(",
                "writeFile\\(",
                "readdir\\(",
                "mkdir\\(",
                "unlink\\(",
                "rmdir\\(",
                "copyFile\\(",
                "rename\\("
            ]

            for (lineIndex, line) in lines.enumerated() {
                for pattern in fileOpPatterns {
                    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                        continue
                    }

                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, options: [], range: range) != nil {
                        // Check context for path validation
                        let startLine = max(0, lineIndex - 5)
                        let contextLines = lines[startLine..<lineIndex].joined(separator: "\n")

                        if !contextLines.contains("isPathAllowed") &&
                           !contextLines.contains("validatePath") &&
                           !line.contains("isPathAllowed") {
                            findings.append(Finding(
                                ruleID: id,
                                severity: .high,
                                title: "File Operation Without Path Validation",
                                description: "File operation found without preceding path validation check",
                                file: file,
                                line: lineIndex + 1,
                                evidence: line.trimmingCharacters(in: .whitespaces),
                                recommendation: "Add isPathAllowed() check before this file operation",
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

/// Rule that detects command injection risks in MCP servers
final class CommandInjectionRule: RegexRule {
    init() {
        super.init(
            id: "MCP-INJECT-001",
            name: "MCP Command Injection Risk",
            description: """
                Detects patterns that could lead to command injection:
                - Unsanitized input to shell commands
                - Template literals with user input in exec
                - Direct variable interpolation in commands
                """,
            severity: .critical,
            category: .injection,
            cweID: "CWE-78",
            recommendation: """
                Prevent command injection:
                - Use parameterized command execution
                - Validate and sanitize all inputs
                - Use allow-lists for command arguments
                - Avoid shell: true in spawn/exec
                - Use execFile instead of exec where possible
                """,
            patterns: [
                "exec\\(`",                          // Template literal in exec
                "exec\\(.*\\$\\{",                   // Variable interpolation in exec
                "spawn\\(.*shell:\\s*true",          // spawn with shell
                "execSync\\(`",                      // Template literal in execSync
                "child_process.*\\$\\{",             // Variable in child_process
                "\\.exec\\(.*\\+.*\\)",              // String concatenation in exec
                "command\\s*:\\s*`"                  // Template literal command
            ],
            excludePatterns: [
                "//.*exec",    // Comments
                "/\\*.*exec"   // Block comments
            ]
        )
    }
}

/// Rule that detects unsafe TypeScript patterns
final class UnsafeTypeScriptRule: RegexRule {
    init() {
        super.init(
            id: "MCP-TS-001",
            name: "Unsafe TypeScript Pattern",
            description: """
                Detects unsafe TypeScript patterns:
                - eval() usage
                - Function constructor
                - Unsafe type assertions
                - any type in security-critical code
                """,
            severity: .high,
            category: .codeQuality,
            cweID: "CWE-94",
            recommendation: """
                Avoid unsafe TypeScript patterns:
                - Never use eval() with user input
                - Avoid new Function() constructor
                - Use proper TypeScript types instead of any
                - Add runtime validation for external input
                """,
            patterns: [
                "\\beval\\s*\\(",
                "new\\s+Function\\s*\\(",
                "as\\s+any(?![a-zA-Z])",
                ":\\s*any(?![a-zA-Z])",
                "JSON\\.parse\\([^)]*\\)(?!.*catch)"  // JSON.parse without error handling
            ],
            excludePatterns: [
                "//.*eval",     // Comments
                "/\\*.*eval"    // Block comments
            ]
        )
    }
}

/// Rule that detects missing input validation
final class MissingInputValidationRule: ASTRule {
    init() {
        super.init(
            id: "MCP-INPUT-001",
            name: "Missing Input Validation",
            description: """
                Detects MCP tool handlers without proper input validation:
                - Missing Zod schema validation
                - Direct use of request parameters
                - Missing type guards
                """,
            severity: .high,
            category: .inputValidation,
            cweID: "CWE-20",
            recommendation: """
                Add input validation to all MCP tool handlers:
                - Use Zod schemas to validate input
                - Add runtime type checking
                - Validate string lengths and patterns
                - Sanitize before using in operations
                """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []
        let lines = content.components(separatedBy: .newlines)

        // Look for tool handlers
        let handlerPatterns = [
            "handler\\s*:",
            "\\.handle\\(",
            "async.*=>.*\\{",
            "execute\\s*\\("
        ]

        // Validation patterns
        let validationPatterns = [
            "\\.parse\\(",
            "\\.safeParse\\(",
            "z\\.",
            "validate",
            "typeof\\s+.*===",
            "instanceof"
        ]

        var inHandler = false
        var handlerStart = 0
        var handlerContent = ""
        var braceCount = 0

        for (lineIndex, line) in lines.enumerated() {
            // Detect handler start
            for pattern in handlerPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, options: [], range: range) != nil {
                        if !inHandler {
                            inHandler = true
                            handlerStart = lineIndex
                            handlerContent = ""
                            braceCount = 0
                        }
                    }
                }
            }

            if inHandler {
                handlerContent += line + "\n"
                braceCount += line.filter { $0 == "{" }.count
                braceCount -= line.filter { $0 == "}" }.count

                // Handler ended
                if braceCount <= 0 && handlerContent.count > 20 {
                    // Check for validation
                    var hasValidation = false
                    for validationPattern in validationPatterns {
                        if handlerContent.contains(validationPattern) {
                            hasValidation = true
                            break
                        }
                    }

                    // Check if handler uses parameters
                    let usesParams = handlerContent.contains("params") ||
                                    handlerContent.contains("args") ||
                                    handlerContent.contains("input") ||
                                    handlerContent.contains("request")

                    if usesParams && !hasValidation {
                        findings.append(Finding(
                            ruleID: id,
                            severity: severity,
                            title: name,
                            description: "MCP handler uses parameters without validation",
                            file: file,
                            line: handlerStart + 1,
                            evidence: String(handlerContent.prefix(100)),
                            recommendation: recommendation,
                            category: category,
                            cweID: cweID
                        ))
                    }

                    inHandler = false
                }
            }
        }

        return findings
    }
}
