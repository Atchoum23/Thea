// AuditEngine.swift
// Main orchestrator for the security audit

import Foundation

/// Main audit engine that orchestrates scanners and collects findings
final class AuditEngine: Sendable {
    let repositoryPath: String
    let deltaMode: Bool
    let baseBranch: String
    let minimumSeverity: Severity
    let verbose: Bool

    private let scannerRegistry: ScannerRegistry

    init(
        repositoryPath: String,
        deltaMode: Bool = false,
        baseBranch: String = "main",
        minimumSeverity: Severity = .low,
        verbose: Bool = false
    ) {
        self.repositoryPath = repositoryPath
        self.deltaMode = deltaMode
        self.baseBranch = baseBranch
        self.minimumSeverity = minimumSeverity
        self.verbose = verbose
        scannerRegistry = ScannerRegistry()
    }

    /// Run the audit and return all findings
    func run() throws -> [Finding] {
        var allFindings: [Finding] = []

        // Get files to scan
        let files: [String]
        if deltaMode {
            files = try getChangedFiles()
            if verbose {
                print("Delta mode: scanning \(files.count) changed files")
            }
        } else {
            files = try getAllFiles()
            if verbose {
                print("Full mode: scanning \(files.count) files")
            }
        }

        // Run each scanner
        for scanner in scannerRegistry.scanners {
            if verbose {
                print("Running scanner: \(scanner.name)")
            }

            // Filter files for this scanner
            let relevantFiles = files.filter { file in
                scanner.filePatterns.contains { pattern in
                    matchesGlob(file: file, pattern: pattern)
                }
            }

            if verbose, !relevantFiles.isEmpty {
                print("  Found \(relevantFiles.count) relevant files")
            }

            // Scan each file
            for file in relevantFiles {
                let fullPath = (repositoryPath as NSString).appendingPathComponent(file)

                do {
                    let content = try String(contentsOfFile: fullPath, encoding: .utf8)
                    let findings = scanner.scan(file: file, content: content)

                    // Filter by severity
                    let filteredFindings = findings.filter { $0.severity >= minimumSeverity }
                    allFindings.append(contentsOf: filteredFindings)

                    if verbose, !filteredFindings.isEmpty {
                        print("  \(file): \(filteredFindings.count) findings")
                    }
                } catch {
                    if verbose {
                        print("  Warning: Could not read \(file): \(error.localizedDescription)")
                    }
                }
            }
        }

        // Sort findings by severity (critical first)
        allFindings.sort { $0.severity > $1.severity }

        return allFindings
    }

    /// Get list of changed files in delta mode
    private func getChangedFiles() throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["diff", "--name-only", baseBranch, "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: repositoryPath)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output
            .split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    /// Get all files in the repository
    private func getAllFiles() throws -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default
        let repoURL = URL(fileURLWithPath: repositoryPath)

        guard let enumerator = fileManager.enumerator(
            at: repoURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw AuditError.fileNotFound(repositoryPath)
        }

        while let url = enumerator.nextObject() as? URL {
            // Skip directories
            guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true
            else {
                continue
            }

            // Get relative path
            let relativePath = url.path.replacingOccurrences(of: repoURL.path + "/", with: "")

            // Skip build directories and dependencies
            if relativePath.hasPrefix(".build/") ||
                relativePath.hasPrefix("node_modules/") ||
                relativePath.hasPrefix("Pods/") ||
                relativePath.hasPrefix(".git/")
            {
                continue
            }

            files.append(relativePath)
        }

        return files
    }

    /// Simple glob pattern matching
    private func matchesGlob(file: String, pattern: String) -> Bool {
        // Convert glob to regex
        var regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "**/", with: "(.*/)?")
            .replacingOccurrences(of: "*", with: "[^/]*")

        regexPattern = "^" + regexPattern + "$"

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else {
            return false
        }

        let range = NSRange(file.startIndex..., in: file)
        return regex.firstMatch(in: file, options: [], range: range) != nil
    }
}
