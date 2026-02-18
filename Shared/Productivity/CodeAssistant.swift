// CodeAssistant.swift
// Thea — AI-powered code assistant
// Replaces: Cursor, Codex (for AI-assisted development)
//
// Project-aware code operations: git integration, code analysis,
// AI-powered refactoring, test generation, and build management.

import Foundation
import OSLog

// MARK: - Types

/// Supported programming languages.
enum CodeLanguageType: String, Codable, CaseIterable, Sendable {
    case swift
    case python
    case javascript
    case typescript
    case go
    case rust
    case java
    case kotlin
    case c
    case cpp
    case ruby
    case php
    case html
    case css
    case shell
    case markdown
    case json
    case yaml
    case unknown

    var displayName: String {
        switch self {
        case .swift: "Swift"
        case .python: "Python"
        case .javascript: "JavaScript"
        case .typescript: "TypeScript"
        case .go: "Go"
        case .rust: "Rust"
        case .java: "Java"
        case .kotlin: "Kotlin"
        case .c: "C"
        case .cpp: "C++"
        case .ruby: "Ruby"
        case .php: "PHP"
        case .html: "HTML"
        case .css: "CSS"
        case .shell: "Shell"
        case .markdown: "Markdown"
        case .json: "JSON"
        case .yaml: "YAML"
        case .unknown: "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .swift: "swift"
        case .python: "chevron.left.forwardslash.chevron.right"
        case .javascript, .typescript: "js"
        case .go: "g.circle"
        case .rust: "gearshape.2"
        case .java: "cup.and.saucer"
        case .kotlin: "k.circle"
        case .c, .cpp: "c.circle"
        case .ruby: "diamond"
        case .php: "p.circle"
        case .html: "globe"
        case .css: "paintbrush"
        case .shell: "terminal"
        case .markdown: "doc.text"
        case .json, .yaml: "curlybraces"
        case .unknown: "questionmark.circle"
        }
    }

    var fileExtensions: [String] {
        switch self {
        case .swift: ["swift"]
        case .python: ["py", "pyw"]
        case .javascript: ["js", "jsx", "mjs"]
        case .typescript: ["ts", "tsx"]
        case .go: ["go"]
        case .rust: ["rs"]
        case .java: ["java"]
        case .kotlin: ["kt", "kts"]
        case .c: ["c", "h"]
        case .cpp: ["cpp", "cxx", "cc", "hpp", "hxx"]
        case .ruby: ["rb"]
        case .php: ["php"]
        case .html: ["html", "htm"]
        case .css: ["css", "scss", "less"]
        case .shell: ["sh", "bash", "zsh", "fish"]
        case .markdown: ["md", "markdown"]
        case .json: ["json"]
        case .yaml: ["yml", "yaml"]
        case .unknown: []
        }
    }

    /// Detect language from file extension.
    static func detect(from extension: String) -> CodeLanguageType {
        let ext = `extension`.lowercased()
        for lang in allCases where lang != .unknown {
            if lang.fileExtensions.contains(ext) {
                return lang
            }
        }
        return .unknown
    }
}

/// Code operation types.
enum CodeOperation: String, Codable, Sendable {
    case analyze
    case refactor
    case generateTests
    case explain
    case review
    case fixBug
    case optimize
    case addDocumentation
    case convertLanguage

    var displayName: String {
        switch self {
        case .analyze: "Analyze"
        case .refactor: "Refactor"
        case .generateTests: "Generate Tests"
        case .explain: "Explain"
        case .review: "Code Review"
        case .fixBug: "Fix Bug"
        case .optimize: "Optimize"
        case .addDocumentation: "Add Documentation"
        case .convertLanguage: "Convert Language"
        }
    }

    var icon: String {
        switch self {
        case .analyze: "magnifyingglass"
        case .refactor: "arrow.triangle.2.circlepath"
        case .generateTests: "checkmark.seal"
        case .explain: "questionmark.circle"
        case .review: "eye"
        case .fixBug: "ladybug"
        case .optimize: "gauge.with.dots.needle.67percent"
        case .addDocumentation: "doc.text.magnifyingglass"
        case .convertLanguage: "arrow.left.arrow.right"
        }
    }
}

/// A scanned code project.
struct CodeProjectInfo: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let path: String
    var fileCount: Int
    var totalLines: Int
    var languages: [CodeLanguageType: Int]
    var lastScannedAt: Date
    var gitBranch: String?
    var gitRemote: String?
    var hasUncommittedChanges: Bool

    init(name: String, path: String) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.fileCount = 0
        self.totalLines = 0
        self.languages = [:]
        self.lastScannedAt = Date()
        self.hasUncommittedChanges = false
    }

    var primaryLanguage: CodeLanguageType? {
        languages.max { $0.value < $1.value }?.key
    }

    var formattedLines: String {
        if totalLines >= 1000 {
            return String(format: "%.1fK", Double(totalLines) / 1000)
        }
        return "\(totalLines)"
    }
}

/// A code file entry with metadata.
struct CodeFileEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let relativePath: String
    let language: CodeLanguageType
    let lineCount: Int
    let sizeBytes: Int64
    let lastModified: Date

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }
}

/// Result of a code operation.
struct CodeOperationResult: Codable, Identifiable, Sendable {
    let id: UUID
    let operation: CodeOperation
    let input: String
    let output: String
    let language: CodeLanguageType
    let timestamp: Date
    let tokensUsed: Int?
    let model: String?

    init(operation: CodeOperation, input: String, output: String, language: CodeLanguageType, tokensUsed: Int? = nil, model: String? = nil) {
        self.id = UUID()
        self.operation = operation
        self.input = input
        self.output = output
        self.language = language
        self.timestamp = Date()
        self.tokensUsed = tokensUsed
        self.model = model
    }
}

/// Git status information.
struct GitStatusInfo: Codable, Sendable {
    let branch: String
    let remote: String?
    let aheadBy: Int
    let behindBy: Int
    let stagedFiles: [String]
    let modifiedFiles: [String]
    let untrackedFiles: [String]
    let hasUncommittedChanges: Bool

    var totalChanges: Int {
        stagedFiles.count + modifiedFiles.count + untrackedFiles.count
    }
}

/// Code assistant errors.
enum CodeAssistantError: Error, LocalizedError, Sendable {
    case projectNotFound(String)
    case gitNotAvailable
    case scanFailed(String)
    case operationFailed(String)
    case fileNotReadable(String)

    var errorDescription: String? {
        switch self {
        case .projectNotFound(let path): "Project not found at: \(path)"
        case .gitNotAvailable: "Git is not available on this system"
        case .scanFailed(let reason): "Project scan failed: \(reason)"
        case .operationFailed(let reason): "Operation failed: \(reason)"
        case .fileNotReadable(let path): "Cannot read file: \(path)"
        }
    }
}

// MARK: - Code Assistant Service

/// AI-powered code assistant with project scanning, git integration,
/// and code operations (analysis, refactoring, test generation, etc.).
@MainActor
final class CodeAssistant: ObservableObject {
    static let shared = CodeAssistant()

    private let logger = Logger(subsystem: "com.thea.app", category: "CodeAssistant")

    // MARK: - Published State

    @Published private(set) var projects: [CodeProjectInfo] = []
    @Published private(set) var recentOperations: [CodeOperationResult] = []
    @Published private(set) var isScanning = false

    // MARK: - Persistence

    private let storageURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea")
            .appendingPathComponent("CodeAssistant")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Logger(subsystem: "com.thea.app", category: "CodeAssistant").debug("Could not create CodeAssistant directory: \(error.localizedDescription)")
        }
        return dir
    }()

    private var projectsFileURL: URL {
        storageURL.appendingPathComponent("projects.json")
    }

    private var operationsFileURL: URL {
        storageURL.appendingPathComponent("operations.json")
    }

    // MARK: - Init

    private init() {
        loadState()
    }

    // MARK: - Project Management

    /// Scan a directory as a code project.
    func scanProject(at url: URL) async throws -> CodeProjectInfo {
        isScanning = true
        defer { isScanning = false }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CodeAssistantError.projectNotFound(url.path)
        }

        var project = CodeProjectInfo(name: url.lastPathComponent, path: url.path)
        var languageCounts: [CodeLanguageType: Int] = [:]
        var totalLines = 0
        var fileCount = 0

        let fm = FileManager.default
        let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        let ignoredDirs = Set(["node_modules", ".build", "DerivedData", "build", "dist", ".git", "Pods", "vendor", "__pycache__"])

        while let fileURL = enumerator?.nextObject() as? URL {
            let dirName = fileURL.lastPathComponent
            if ignoredDirs.contains(dirName) {
                enumerator?.skipDescendants()
                continue
            }

            let isFile: Bool = { do { return try fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile ?? false } catch { return false } }()
            guard isFile else { continue }

            let lang = CodeLanguageType.detect(from: fileURL.pathExtension)
            guard lang != .unknown else { continue }

            // Count lines
            let lineCount: Int
            if let data = fm.contents(atPath: fileURL.path),
               let content = String(data: data, encoding: .utf8) {
                lineCount = content.components(separatedBy: .newlines).count
            } else {
                lineCount = 0
            }

            totalLines += lineCount
            fileCount += 1
            languageCounts[lang, default: 0] += lineCount
        }

        project.fileCount = fileCount
        project.totalLines = totalLines
        project.languages = languageCounts
        project.lastScannedAt = Date()

        // Get git info
        #if os(macOS)
        let gitInfo = await getGitStatus(at: url.path)
        project.gitBranch = gitInfo?.branch
        project.gitRemote = gitInfo?.remote
        project.hasUncommittedChanges = gitInfo?.hasUncommittedChanges ?? false
        #endif

        // Update or add project
        if let index = projects.firstIndex(where: { $0.path == project.path }) {
            projects[index] = project
        } else {
            projects.insert(project, at: 0)
        }

        saveState()
        return project
    }

    /// Remove a project from tracking.
    func removeProject(id: UUID) {
        projects.removeAll { $0.id == id }
        saveState()
    }

    /// List files in a project, sorted by language.
    func listFiles(in project: CodeProjectInfo, language: CodeLanguageType? = nil) throws -> [CodeFileEntry] {
        let url = URL(fileURLWithPath: project.path)
        guard FileManager.default.fileExists(atPath: project.path) else {
            throw CodeAssistantError.projectNotFound(project.path)
        }

        var entries: [CodeFileEntry] = []
        let fm = FileManager.default
        let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        let ignoredDirs = Set(["node_modules", ".build", "DerivedData", "build", "dist", ".git", "Pods", "vendor", "__pycache__"])

        while let fileURL = enumerator?.nextObject() as? URL {
            if ignoredDirs.contains(fileURL.lastPathComponent) {
                enumerator?.skipDescendants()
                continue
            }

            let isFile: Bool = { do { return try fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile ?? false } catch { return false } }()
            guard isFile else { continue }

            let lang = CodeLanguageType.detect(from: fileURL.pathExtension)
            guard lang != .unknown else { continue }

            if let language, lang != language { continue }

            var attrs: URLResourceValues?
            do { attrs = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) } catch { attrs = nil }
            let lineCount: Int
            if let data = fm.contents(atPath: fileURL.path),
               let content = String(data: data, encoding: .utf8) {
                lineCount = content.components(separatedBy: .newlines).count
            } else {
                lineCount = 0
            }

            let relativePath = fileURL.path.replacingOccurrences(of: project.path + "/", with: "")
            entries.append(CodeFileEntry(
                id: UUID(),
                relativePath: relativePath,
                language: lang,
                lineCount: lineCount,
                sizeBytes: Int64(attrs?.fileSize ?? 0),
                lastModified: attrs?.contentModificationDate ?? Date()
            ))
        }

        return entries.sorted { $0.relativePath < $1.relativePath }
    }

    // MARK: - Git Operations

    #if os(macOS)
    /// Get git status for a directory.
    func getGitStatus(at path: String) async -> GitStatusInfo? {
        // Check if git is available
        guard let gitPath = findExecutable("git") else { return nil }

        // Get branch
        let branch = await runCommand(gitPath, args: ["rev-parse", "--abbrev-ref", "HEAD"], in: path)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"

        // Get remote
        let remote = await runCommand(gitPath, args: ["remote", "get-url", "origin"], in: path)?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Get ahead/behind
        let revList = await runCommand(gitPath, args: ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"], in: path)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\t")
        let ahead = Int(revList?.first ?? "") ?? 0
        let behind = Int(revList?.last ?? "") ?? 0

        // Get status
        let statusOutput = await runCommand(gitPath, args: ["status", "--porcelain"], in: path) ?? ""
        let statusLines = statusOutput.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var staged: [String] = []
        var modified: [String] = []
        var untracked: [String] = []

        for line in statusLines {
            guard line.count >= 3 else { continue }
            let indexStatus = line[line.startIndex]
            let workStatus = line[line.index(line.startIndex, offsetBy: 1)]
            let file = String(line.dropFirst(3))

            if indexStatus != " " && indexStatus != "?" {
                staged.append(file)
            }
            if workStatus != " " && workStatus != "?" {
                modified.append(file)
            }
            if indexStatus == "?" {
                untracked.append(file)
            }
        }

        return GitStatusInfo(
            branch: branch,
            remote: remote,
            aheadBy: ahead,
            behindBy: behind,
            stagedFiles: staged,
            modifiedFiles: modified,
            untrackedFiles: untracked,
            hasUncommittedChanges: !staged.isEmpty || !modified.isEmpty || !untracked.isEmpty
        )
    }

    /// Generate an AI commit message from staged changes.
    func generateCommitMessage(at path: String) async -> String? {
        guard let gitPath = findExecutable("git") else { return nil }
        let diff = await runCommand(gitPath, args: ["diff", "--cached", "--stat"], in: path)
        guard let diff, !diff.isEmpty else { return nil }

        // Simple heuristic commit message from diff stat
        let lines = diff.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let summary = lines.last else { return nil }

        // Extract file count and change counts
        if summary.contains("changed") {
            let files = lines.dropLast().map { line -> String in
                let parts = line.components(separatedBy: "|")
                return parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
            }

            if files.count == 1 {
                return "Update \(files[0])"
            } else if files.count <= 3 {
                return "Update \(files.joined(separator: ", "))"
            } else {
                return "Update \(files.count) files"
            }
        }

        return "Update code"
    }

    /// Run git commit with message.
    func commit(at path: String, message: String) async throws {
        guard let gitPath = findExecutable("git") else {
            throw CodeAssistantError.gitNotAvailable
        }

        let result = await runCommand(gitPath, args: ["commit", "-m", message], in: path)
        if result == nil {
            throw CodeAssistantError.operationFailed("Git commit failed")
        }
    }

    // MARK: - Process Helpers

    private func findExecutable(_ name: String) -> String? {
        let paths = ["/usr/bin/\(name)", "/usr/local/bin/\(name)", "/opt/homebrew/bin/\(name)"]
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func runCommand(_ executable: String, args: [String], in directory: String) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: directory)

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)
                continuation.resume(returning: process.terminationStatus == 0 ? output : nil)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    #endif

    // MARK: - Code Operations

    /// Read a file's content.
    func readFile(path: String) throws -> String {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CodeAssistantError.fileNotReadable(path)
        }
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            throw CodeAssistantError.fileNotReadable(path)
        }
        return content
    }

    /// Analyze code and produce a summary.
    func analyzeCode(_ code: String, language: CodeLanguageType) -> CodeOperationResult {
        var analysis: [String] = []

        let lines = code.components(separatedBy: .newlines)
        analysis.append("Total lines: \(lines.count)")

        // Count blanks, comments, code
        var blankLines = 0
        var commentLines = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                blankLines += 1
            } else if isComment(trimmed, language: language) {
                commentLines += 1
            }
        }
        let codeLines = lines.count - blankLines - commentLines
        analysis.append("Code lines: \(codeLines)")
        analysis.append("Comment lines: \(commentLines)")
        analysis.append("Blank lines: \(blankLines)")

        // Complexity indicators
        let functionCount = countPattern(code, pattern: functionPattern(for: language))
        analysis.append("Functions/methods: \(functionCount)")

        let classCount = countPattern(code, pattern: classPattern(for: language))
        analysis.append("Classes/structs: \(classCount)")

        // Code health
        let commentRatio = !lines.isEmpty ? Double(commentLines) / Double(lines.count) * 100 : 0
        analysis.append(String(format: "Comment ratio: %.1f%%", commentRatio))

        let avgLineLength = codeLines > 0 ? lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map(\.count).reduce(0, +) / max(codeLines, 1) : 0
        analysis.append("Avg line length: \(avgLineLength) chars")

        // Warnings
        if avgLineLength > 120 {
            analysis.append("⚠️ Long lines detected (avg > 120 chars)")
        }
        if commentRatio < 5 && codeLines > 50 {
            analysis.append("⚠️ Low comment ratio for a file with \(codeLines) code lines")
        }
        if codeLines > 500 {
            analysis.append("⚠️ Large file — consider splitting")
        }

        let result = CodeOperationResult(
            operation: .analyze,
            input: String(code.prefix(200)),
            output: analysis.joined(separator: "\n"),
            language: language
        )
        addOperation(result)
        return result
    }

    /// Get project statistics summary.
    func getProjectStats() -> (totalProjects: Int, totalFiles: Int, totalLines: Int, primaryLanguages: [CodeLanguageType]) {
        let totalFiles = projects.reduce(0) { $0 + $1.fileCount }
        let totalLines = projects.reduce(0) { $0 + $1.totalLines }
        let primaryLangs = projects.compactMap(\.primaryLanguage)
        return (projects.count, totalFiles, totalLines, Array(Set(primaryLangs)))
    }

    // MARK: - Code Pattern Helpers

    private func isComment(_ line: String, language: CodeLanguageType) -> Bool {
        switch language {
        case .swift, .java, .kotlin, .go, .rust, .c, .cpp, .javascript, .typescript, .php:
            return line.hasPrefix("//") || line.hasPrefix("/*") || line.hasPrefix("*")
        case .python, .ruby, .shell:
            return line.hasPrefix("#")
        case .html:
            return line.hasPrefix("<!--")
        case .css:
            return line.hasPrefix("/*")
        default:
            return line.hasPrefix("//") || line.hasPrefix("#")
        }
    }

    private func functionPattern(for language: CodeLanguageType) -> String {
        switch language {
        case .swift: "func "
        case .python: "def "
        case .javascript, .typescript: "function "
        case .go: "func "
        case .rust: "fn "
        case .java, .kotlin: "(public|private|protected|internal|static|override|fun)\\s+"
        case .ruby: "def "
        case .php: "function "
        default: "func "
        }
    }

    private func classPattern(for language: CodeLanguageType) -> String {
        switch language {
        case .swift: "(class|struct|enum|protocol|actor) "
        case .python: "class "
        case .javascript, .typescript: "(class|interface) "
        case .go: "type .+ struct"
        case .rust: "(struct|enum|trait|impl) "
        case .java, .kotlin: "(class|interface|enum) "
        case .ruby: "(class|module) "
        case .php: "(class|interface|trait) "
        default: "class "
        }
    }

    private func countPattern(_ code: String, pattern: String) -> Int {
        // Simple line-by-line keyword count
        let lines = code.components(separatedBy: .newlines)
        return lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Use simple prefix/contains matching for non-regex patterns
            if pattern.contains("(") {
                // For complex patterns, use regex
                do {
                    let regex = try NSRegularExpression(pattern: pattern)
                    return regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
                } catch {
                    return false
                }
            }
            return trimmed.contains(pattern)
        }.count
    }

    // MARK: - Operations History

    /// Record an operation result.
    private func addOperation(_ result: CodeOperationResult) {
        recentOperations.insert(result, at: 0)
        if recentOperations.count > 100 {
            recentOperations = Array(recentOperations.prefix(100))
        }
        saveState()
    }

    /// Clear operation history.
    func clearHistory() {
        recentOperations.removeAll()
        saveState()
    }

    // MARK: - Persistence

    private func loadState() {
        let fm = FileManager.default
        if fm.fileExists(atPath: projectsFileURL.path) {
            do {
                let data = try Data(contentsOf: projectsFileURL)
                projects = try JSONDecoder().decode([CodeProjectInfo].self, from: data)
            } catch {
                ErrorLogger.log(error, context: "CodeAssistant.loadProjects")
            }
        }
        if fm.fileExists(atPath: operationsFileURL.path) {
            do {
                let data = try Data(contentsOf: operationsFileURL)
                recentOperations = try JSONDecoder().decode([CodeOperationResult].self, from: data)
            } catch {
                ErrorLogger.log(error, context: "CodeAssistant.loadOperations")
            }
        }
    }

    private func saveState() {
        do {
            let projectData = try JSONEncoder().encode(projects)
            try projectData.write(to: projectsFileURL, options: .atomic)
            let opData = try JSONEncoder().encode(recentOperations)
            try opData.write(to: operationsFileURL, options: .atomic)
        } catch {
            ErrorLogger.log(error, context: "CodeAssistant.saveState")
        }
    }
}
