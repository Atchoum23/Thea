// URLValidationRule.swift
// Detects missing URL validation in HTTP requests

import Foundation

/// Rule that detects missing URL validation in HTTP request tools
final class URLValidationRule: ASTRule {
    init() {
        super.init(
            id: "SWIFT-URL-001",
            name: "Missing URL Validation",
            description: """
            Detects HTTP request code that doesn't validate URLs:
            - No check for localhost/127.0.0.1
            - No check for metadata endpoints (169.254.169.254)
            - No check for internal IP ranges
            This can lead to SSRF (Server-Side Request Forgery) vulnerabilities.
            """,
            severity: .critical,
            category: .inputValidation,
            cweID: "CWE-918",
            recommendation: """
            Add URL validation before making any HTTP request:
            - Block localhost, 127.0.0.1, ::1
            - Block cloud metadata endpoints (169.254.169.254, metadata.google.internal)
            - Block private IP ranges (10.x, 172.16-31.x, 192.168.x)
            - Validate URL scheme (only allow https where possible)
            """
        )
    }

    override func check(file: String, content: String) -> [Finding] {
        var findings: [Finding] = []
        let lines = content.components(separatedBy: .newlines)

        // Patterns that indicate HTTP request handling
        let httpPatterns = [
            "URLSession",
            "URLRequest",
            "httpRequest",
            "HTTPRequestTool",
            "fetch\\(",
            "request\\.httpMethod"
        ]

        // Patterns that indicate URL validation
        let validationPatterns = [
            "localhost",
            "127\\.0\\.0\\.1",
            "169\\.254",
            "metadata",
            "isLocalhost",
            "isPrivateIP",
            "validateURL",
            "blockedHosts",
            "isAllowed"
        ]

        // Track if we're in an HTTP-related function/struct
        var inHTTPContext = false
        var httpContextStart = 0
        var httpContextContent = ""
        var braceCount = 0

        for (lineIndex, line) in lines.enumerated() {
            // Check if entering HTTP context
            for pattern in httpPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, options: [], range: range) != nil {
                        if !inHTTPContext {
                            inHTTPContext = true
                            httpContextStart = lineIndex
                            httpContextContent = ""
                            braceCount = 0
                        }
                    }
                }
            }

            if inHTTPContext {
                httpContextContent += line + "\n"
                braceCount += line.count(where: { $0 == "{" })
                braceCount -= line.count(where: { $0 == "}" })

                // End of context (function/struct closed)
                if braceCount <= 0, httpContextContent.count > 50 {
                    // Check if URL validation is present
                    var hasValidation = false
                    for validationPattern in validationPatterns {
                        if httpContextContent.contains(validationPattern) {
                            hasValidation = true
                            break
                        }
                    }

                    // If making HTTP requests without validation, report it
                    if !hasValidation,
                       httpContextContent.contains("URLSession") ||
                       httpContextContent.contains("URLRequest") ||
                       httpContextContent.contains("data(for:")
                    {
                        findings.append(Finding(
                            ruleID: id,
                            severity: severity,
                            title: name,
                            description: "HTTP request code without URL validation - potential SSRF vulnerability",
                            file: file,
                            line: httpContextStart + 1,
                            evidence: String(httpContextContent.prefix(200)),
                            recommendation: recommendation,
                            category: category,
                            cweID: cweID
                        ))
                    }

                    inHTTPContext = false
                }
            }
        }

        return findings
    }
}

/// Rule that detects hardcoded sensitive URLs
final class HardcodedURLRule: RegexRule {
    init() {
        super.init(
            id: "SWIFT-URL-002",
            name: "Hardcoded Sensitive URL",
            description: """
            Detects hardcoded URLs to sensitive endpoints:
            - Localhost URLs
            - Cloud metadata endpoints
            - Internal API endpoints
            """,
            severity: .high,
            category: .configuration,
            cweID: "CWE-798",
            recommendation: """
            Move URLs to configuration files.
            Add URL validation before use.
            Never hardcode internal endpoint URLs.
            """,
            patterns: [
                "\"http://localhost",
                "\"http://127\\.0\\.0\\.1",
                "\"http://0\\.0\\.0\\.0",
                "\"http://\\[::\\]",
                "\"http://169\\.254",
                "\"http://metadata",
                "\"http://10\\.",
                "\"http://172\\.(1[6-9]|2[0-9]|3[0-1])\\.",
                "\"http://192\\.168\\."
            ],
            excludePatterns: [
                "//.*http://localhost", // Comments
                "///.*http://localhost" // Doc comments
            ]
        )
    }
}
