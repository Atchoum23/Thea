// PathValidationRule.swift
// Detects missing path validation in file operations

import Foundation

/// Rule that detects missing path validation in file operations
final class PathValidationRule: ASTRule {
    init() {
        super.init(
            id: "SWIFT-PATH-001",
            name: "Missing Path Validation",
            description: """
            Detects file operations without proper path validation:
            - No check for blocked paths (/System, /Library, etc.)
            - No workspace boundary enforcement
            - No path traversal protection
            This can lead to unauthorized file access or modification.
            """,
            severity: .high,
            category: .accessControl,
            cweID: "CWE-22",
            recommendation: """
            Add path validation before all file operations:
            - Check against blocklist of sensitive paths
            - Ensure path is within allowed workspace
            - Resolve symlinks before validation
            - Reject paths with .. traversal attempts
            """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []
        let lines = content.components(separatedBy: .newlines)

        // File operation patterns
        let fileOpPatterns = [
            "writeFile",
            "write\\(toFile:",
            "write\\(to:",
            "createFile",
            "createDirectory",
            "removeItem",
            "moveItem",
            "copyItem",
            "contentsOfFile",
            "FileManager.*write",
            "try.*write\\("
        ]

        // Path validation patterns
        let validationPatterns = [
            "blockedPath",
            "isPathAllowed",
            "isDirectoryAllowed",
            "validatePath",
            "sandboxedDirectories",
            "expandingTildeInPath",
            "standardizedFileURL",
            "hasPrefix.*System",
            "hasPrefix.*Library",
            "contains.*\\.\\."
        ]

        for (lineIndex, line) in lines.enumerated() {
            for filePattern in fileOpPatterns {
                guard let regex = try? NSRegularExpression(pattern: filePattern, options: []) else {
                    continue
                }

                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, options: [], range: range) != nil {
                    // Look for validation in context (10 lines before)
                    let startLine = max(0, lineIndex - 10)
                    let contextLines = lines[startLine ..< lineIndex].joined(separator: "\n")

                    var hasValidation = false
                    for validationPattern in validationPatterns {
                        if contextLines.contains(validationPattern) ||
                            line.contains(validationPattern)
                        {
                            hasValidation = true
                            break
                        }
                    }

                    // Also check if in a function that has validation
                    if contextLines.contains("guard"), contextLines.contains("path") {
                        hasValidation = true
                    }

                    if !hasValidation {
                        findings.append(Finding(
                            ruleID: id,
                            severity: severity,
                            title: name,
                            description: "File operation without path validation",
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

        return findings
    }
}

/// Rule that detects path traversal patterns
final class PathTraversalRule: RegexRule {
    init() {
        super.init(
            id: "SWIFT-PATH-002",
            name: "Potential Path Traversal",
            description: """
            Detects patterns that might allow path traversal attacks:
            - Direct use of user input in file paths
            - String concatenation for paths without validation
            - Use of .. in path construction
            """,
            severity: .high,
            category: .inputValidation,
            cweID: "CWE-23",
            recommendation: """
            Sanitize and validate all path inputs:
            - Use URL/path APIs that resolve traversal
            - Reject paths containing ..
            - Validate resolved path is within allowed directory
            - Use canonicalized path comparison
            """,
            patterns: [
                "\\+.*\"/\".*\\+", // String concatenation for paths
                "\"\\.\\.\"", // Literal parent directory
                "\\$\\(.*\\)/", // Shell-style variable in path
                "path\\s*\\+\\s*[^\\s]", // Direct path concatenation
                "appendingPathComponent.*input" // User input in path
            ],
            excludePatterns: [
                "//.*\\.\\.", // Comments
                "contains.*\\.\\." // Validation check
            ]
        )
    }
}
