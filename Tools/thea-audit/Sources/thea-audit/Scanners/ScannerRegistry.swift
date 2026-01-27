// ScannerRegistry.swift
// Registry of all security scanners

import Foundation

/// Registry that holds all available scanners
final class ScannerRegistry: Sendable {
    /// All registered scanners
    let scanners: [any Scanner]

    init() {
        scanners = [
            SwiftScanner(),
            WorkflowScanner(),
            ScriptScanner(),
            MCPServerScanner(),
            AgentSecScanner()
        ]
    }

    /// Get a scanner by ID
    func scanner(withID id: String) -> (any Scanner)? {
        scanners.first { $0.id == id }
    }

    /// Get scanners for a specific file
    func scanners(for file: String) -> [any Scanner] {
        scanners.filter { scanner in
            scanner.filePatterns.contains { pattern in
                matchesPattern(file: file, pattern: pattern)
            }
        }
    }

    /// Match a file against a glob pattern
    private func matchesPattern(file: String, pattern: String) -> Bool {
        var regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "**", with: "<<<DOUBLESTAR>>>")
            .replacingOccurrences(of: "*", with: "[^/]*")
            .replacingOccurrences(of: "<<<DOUBLESTAR>>>", with: ".*")

        regexPattern = "^" + regexPattern + "$"

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else {
            return false
        }

        let range = NSRange(file.startIndex..., in: file)
        return regex.firstMatch(in: file, options: [], range: range) != nil
    }
}
