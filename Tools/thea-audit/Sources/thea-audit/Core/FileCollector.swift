// FileCollector.swift
// Utility for collecting files based on glob patterns

import Foundation

/// Collects files from a directory based on glob patterns
struct FileCollector: Sendable {
    let rootPath: String

    init(rootPath: String) {
        self.rootPath = rootPath
    }

    /// Collect files matching any of the given patterns
    func collect(patterns: [String]) throws -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath)

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            throw FileCollectorError.directoryNotFound(rootPath)
        }

        while let url = enumerator.nextObject() as? URL {
            guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true
            else {
                continue
            }

            let relativePath = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")

            // Skip common non-source directories
            if shouldSkip(path: relativePath) {
                continue
            }

            // Check if file matches any pattern
            for pattern in patterns {
                if matches(file: relativePath, pattern: pattern) {
                    files.append(relativePath)
                    break
                }
            }
        }

        return files.sorted()
    }

    /// Check if a path should be skipped
    private func shouldSkip(path: String) -> Bool {
        let skipPrefixes = [
            ".build/",
            ".git/",
            "node_modules/",
            "Pods/",
            "Carthage/",
            "DerivedData/",
            ".swiftpm/",
            "xcuserdata/"
        ]

        for prefix in skipPrefixes {
            if path.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }

    /// Match a file path against a glob pattern
    private func matches(file: String, pattern: String) -> Bool {
        // Handle common glob patterns
        var regexPattern = pattern

        // Escape special regex characters (except * and ?)
        regexPattern = regexPattern.replacingOccurrences(of: ".", with: "\\.")
        regexPattern = regexPattern.replacingOccurrences(of: "[", with: "\\[")
        regexPattern = regexPattern.replacingOccurrences(of: "]", with: "\\]")
        regexPattern = regexPattern.replacingOccurrences(of: "(", with: "\\(")
        regexPattern = regexPattern.replacingOccurrences(of: ")", with: "\\)")
        regexPattern = regexPattern.replacingOccurrences(of: "+", with: "\\+")

        // Convert glob patterns to regex
        regexPattern = regexPattern.replacingOccurrences(of: "**", with: "<<<DOUBLESTAR>>>")
        regexPattern = regexPattern.replacingOccurrences(of: "*", with: "[^/]*")
        regexPattern = regexPattern.replacingOccurrences(of: "<<<DOUBLESTAR>>>", with: ".*")
        regexPattern = regexPattern.replacingOccurrences(of: "?", with: ".")

        // Anchor the pattern
        regexPattern = "^" + regexPattern + "$"

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else {
            return false
        }

        let range = NSRange(file.startIndex..., in: file)
        return regex.firstMatch(in: file, options: [], range: range) != nil
    }

    /// Get all Swift files
    func collectSwiftFiles() throws -> [String] {
        try collect(patterns: ["**/*.swift"])
    }

    /// Get all YAML workflow files
    func collectWorkflowFiles() throws -> [String] {
        try collect(patterns: [".github/workflows/*.yml", ".github/workflows/*.yaml"])
    }

    /// Get all shell scripts
    func collectShellScripts() throws -> [String] {
        try collect(patterns: ["**/*.sh", "Scripts/*"])
    }

    /// Get all TypeScript files
    func collectTypeScriptFiles() throws -> [String] {
        try collect(patterns: ["**/*.ts", "**/*.tsx"])
    }
}

// MARK: - Errors

enum FileCollectorError: Error, CustomStringConvertible {
    case directoryNotFound(String)
    case accessDenied(String)

    var description: String {
        switch self {
        case let .directoryNotFound(path):
            "Directory not found: \(path)"
        case let .accessDenied(path):
            "Access denied: \(path)"
        }
    }
}
