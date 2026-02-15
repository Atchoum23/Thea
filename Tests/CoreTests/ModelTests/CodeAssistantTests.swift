// CodeAssistantTests.swift
// Tests for CodeAssistant types and logic
// SPM-compatible — uses standalone test doubles mirroring production types

import Testing
import Foundation

// MARK: - Test Doubles

private enum TestCodeLanguageType: String, Codable, CaseIterable {
    case swift, python, javascript, typescript, go, rust, java, kotlin
    case c, cpp, ruby, php, html, css, shell, markdown, json, yaml, unknown

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

    static func detect(from ext: String) -> TestCodeLanguageType {
        let lowered = ext.lowercased()
        for lang in allCases where lang != .unknown {
            if lang.fileExtensions.contains(lowered) {
                return lang
            }
        }
        return .unknown
    }
}

private enum TestCodeOperation: String, Codable {
    case analyze, refactor, generateTests, explain, review
    case fixBug, optimize, addDocumentation, convertLanguage

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

private struct TestCodeProjectInfo: Codable, Identifiable {
    let id: UUID
    let name: String
    let path: String
    var fileCount: Int
    var totalLines: Int
    var languages: [String: Int]  // String key for Codable simplicity
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

    var primaryLanguage: String? {
        languages.max(by: { $0.value < $1.value })?.key
    }

    var formattedLines: String {
        if totalLines >= 1000 {
            return String(format: "%.1fK", Double(totalLines) / 1000)
        }
        return "\(totalLines)"
    }
}

private struct TestCodeFileEntry: Codable, Identifiable {
    let id: UUID
    let relativePath: String
    let language: TestCodeLanguageType
    let lineCount: Int
    let sizeBytes: Int64
    let lastModified: Date

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }
}

private struct TestCodeOperationResult: Codable, Identifiable {
    let id: UUID
    let operation: TestCodeOperation
    let input: String
    let output: String
    let language: TestCodeLanguageType
    let timestamp: Date
    let tokensUsed: Int?
    let model: String?

    init(operation: TestCodeOperation, input: String, output: String, language: TestCodeLanguageType, tokensUsed: Int? = nil, model: String? = nil) {
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

private struct TestGitStatusInfo: Codable {
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

private enum TestCodeAssistantError: Error, LocalizedError {
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

// MARK: - Language Detection Tests

@Suite("CodeLanguageType")
struct CodeLanguageTypeTests {
    @Test("All 19 cases exist")
    func allCases() {
        #expect(TestCodeLanguageType.allCases.count == 19)
    }

    @Test("Display names")
    func displayNames() {
        #expect(TestCodeLanguageType.swift.displayName == "Swift")
        #expect(TestCodeLanguageType.cpp.displayName == "C++")
        #expect(TestCodeLanguageType.javascript.displayName == "JavaScript")
        #expect(TestCodeLanguageType.typescript.displayName == "TypeScript")
        #expect(TestCodeLanguageType.unknown.displayName == "Unknown")
    }

    @Test("Swift detection from extension")
    func detectSwift() {
        #expect(TestCodeLanguageType.detect(from: "swift") == .swift)
    }

    @Test("Python detection from py and pyw")
    func detectPython() {
        #expect(TestCodeLanguageType.detect(from: "py") == .python)
        #expect(TestCodeLanguageType.detect(from: "pyw") == .python)
    }

    @Test("JavaScript detection from js, jsx, mjs")
    func detectJS() {
        #expect(TestCodeLanguageType.detect(from: "js") == .javascript)
        #expect(TestCodeLanguageType.detect(from: "jsx") == .javascript)
        #expect(TestCodeLanguageType.detect(from: "mjs") == .javascript)
    }

    @Test("TypeScript detection from ts, tsx")
    func detectTS() {
        #expect(TestCodeLanguageType.detect(from: "ts") == .typescript)
        #expect(TestCodeLanguageType.detect(from: "tsx") == .typescript)
    }

    @Test("C++ detection from multiple extensions")
    func detectCpp() {
        for ext in ["cpp", "cxx", "cc", "hpp", "hxx"] {
            #expect(TestCodeLanguageType.detect(from: ext) == .cpp)
        }
    }

    @Test("Shell detection from sh, bash, zsh, fish")
    func detectShell() {
        for ext in ["sh", "bash", "zsh", "fish"] {
            #expect(TestCodeLanguageType.detect(from: ext) == .shell)
        }
    }

    @Test("YAML detection from yml and yaml")
    func detectYaml() {
        #expect(TestCodeLanguageType.detect(from: "yml") == .yaml)
        #expect(TestCodeLanguageType.detect(from: "yaml") == .yaml)
    }

    @Test("CSS detection from css, scss, less")
    func detectCSS() {
        #expect(TestCodeLanguageType.detect(from: "css") == .css)
        #expect(TestCodeLanguageType.detect(from: "scss") == .css)
        #expect(TestCodeLanguageType.detect(from: "less") == .css)
    }

    @Test("Unknown for unrecognized extension")
    func detectUnknown() {
        #expect(TestCodeLanguageType.detect(from: "xyz") == .unknown)
        #expect(TestCodeLanguageType.detect(from: "") == .unknown)
        #expect(TestCodeLanguageType.detect(from: "docx") == .unknown)
    }

    @Test("Case-insensitive detection")
    func caseInsensitive() {
        #expect(TestCodeLanguageType.detect(from: "SWIFT") == .swift)
        #expect(TestCodeLanguageType.detect(from: "Py") == .python)
        #expect(TestCodeLanguageType.detect(from: "JS") == .javascript)
    }

    @Test("Each language has an icon")
    func icons() {
        for lang in TestCodeLanguageType.allCases {
            #expect(!lang.icon.isEmpty)
        }
    }

    @Test("Unknown has empty file extensions")
    func unknownNoExtensions() {
        #expect(TestCodeLanguageType.unknown.fileExtensions.isEmpty)
    }

    @Test("JS and TS share icon")
    func sharedIcon() {
        #expect(TestCodeLanguageType.javascript.icon == TestCodeLanguageType.typescript.icon)
    }

    @Test("C and C++ share icon")
    func cCppSharedIcon() {
        #expect(TestCodeLanguageType.c.icon == TestCodeLanguageType.cpp.icon)
    }

    @Test("Kotlin detection from kt, kts")
    func detectKotlin() {
        #expect(TestCodeLanguageType.detect(from: "kt") == .kotlin)
        #expect(TestCodeLanguageType.detect(from: "kts") == .kotlin)
    }

    @Test("Go, Rust, Java, Ruby, PHP detection")
    func detectOthers() {
        #expect(TestCodeLanguageType.detect(from: "go") == .go)
        #expect(TestCodeLanguageType.detect(from: "rs") == .rust)
        #expect(TestCodeLanguageType.detect(from: "java") == .java)
        #expect(TestCodeLanguageType.detect(from: "rb") == .ruby)
        #expect(TestCodeLanguageType.detect(from: "php") == .php)
    }

    @Test("HTML detection from html, htm")
    func detectHTML() {
        #expect(TestCodeLanguageType.detect(from: "html") == .html)
        #expect(TestCodeLanguageType.detect(from: "htm") == .html)
    }

    @Test("Markdown detection from md, markdown")
    func detectMarkdown() {
        #expect(TestCodeLanguageType.detect(from: "md") == .markdown)
        #expect(TestCodeLanguageType.detect(from: "markdown") == .markdown)
    }

    @Test("JSON detection")
    func detectJSON() {
        #expect(TestCodeLanguageType.detect(from: "json") == .json)
    }

    @Test("C detects from c and h")
    func detectC() {
        #expect(TestCodeLanguageType.detect(from: "c") == .c)
        #expect(TestCodeLanguageType.detect(from: "h") == .c)
    }
}

// MARK: - Code Operation Tests

@Suite("CodeOperation")
struct CodeOperationTests {
    @Test("All 9 operations have display names")
    func displayNames() {
        let ops: [TestCodeOperation] = [.analyze, .refactor, .generateTests, .explain, .review, .fixBug, .optimize, .addDocumentation, .convertLanguage]
        for op in ops {
            #expect(!op.displayName.isEmpty)
        }
    }

    @Test("All operations have icons")
    func icons() {
        let ops: [TestCodeOperation] = [.analyze, .refactor, .generateTests, .explain, .review, .fixBug, .optimize, .addDocumentation, .convertLanguage]
        for op in ops {
            #expect(!op.icon.isEmpty)
        }
    }

    @Test("Specific display names")
    func specificNames() {
        #expect(TestCodeOperation.analyze.displayName == "Analyze")
        #expect(TestCodeOperation.generateTests.displayName == "Generate Tests")
        #expect(TestCodeOperation.fixBug.displayName == "Fix Bug")
        #expect(TestCodeOperation.review.displayName == "Code Review")
        #expect(TestCodeOperation.convertLanguage.displayName == "Convert Language")
        #expect(TestCodeOperation.addDocumentation.displayName == "Add Documentation")
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let op = TestCodeOperation.refactor
        let data = try JSONEncoder().encode(op)
        let decoded = try JSONDecoder().decode(TestCodeOperation.self, from: data)
        #expect(decoded == op)
    }
}

// MARK: - Project Info Tests

@Suite("CodeProjectInfo")
struct CodeProjectInfoTests {
    @Test("Init with name and path")
    func initDefaults() {
        let project = TestCodeProjectInfo(name: "MyApp", path: "/Users/dev/MyApp")
        #expect(project.name == "MyApp")
        #expect(project.path == "/Users/dev/MyApp")
        #expect(project.fileCount == 0)
        #expect(project.totalLines == 0)
        #expect(project.languages.isEmpty)
        #expect(project.hasUncommittedChanges == false)
        #expect(project.gitBranch == nil)
        #expect(project.gitRemote == nil)
    }

    @Test("Primary language is most lines")
    func primaryLanguage() {
        var project = TestCodeProjectInfo(name: "Test", path: "/test")
        project.languages = ["swift": 5000, "python": 200, "json": 50]
        #expect(project.primaryLanguage == "swift")
    }

    @Test("Primary language nil when empty")
    func primaryLanguageEmpty() {
        let project = TestCodeProjectInfo(name: "Test", path: "/test")
        #expect(project.primaryLanguage == nil)
    }

    @Test("Formatted lines under 1000")
    func formattedLinesSmall() {
        var project = TestCodeProjectInfo(name: "Test", path: "/test")
        project.totalLines = 500
        #expect(project.formattedLines == "500")
    }

    @Test("Formatted lines over 1000")
    func formattedLinesLarge() {
        var project = TestCodeProjectInfo(name: "Test", path: "/test")
        project.totalLines = 15200
        #expect(project.formattedLines == "15.2K")
    }

    @Test("Formatted lines exactly 1000")
    func formattedLinesExact() {
        var project = TestCodeProjectInfo(name: "Test", path: "/test")
        project.totalLines = 1000
        #expect(project.formattedLines == "1.0K")
    }

    @Test("Formatted lines zero")
    func formattedLinesZero() {
        let project = TestCodeProjectInfo(name: "Test", path: "/test")
        #expect(project.formattedLines == "0")
    }

    @Test("Codable roundtrip")
    func codable() throws {
        var project = TestCodeProjectInfo(name: "App", path: "/app")
        project.fileCount = 42
        project.totalLines = 3500
        project.languages = ["swift": 3000, "json": 500]
        project.gitBranch = "main"
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(TestCodeProjectInfo.self, from: data)
        #expect(decoded.name == "App")
        #expect(decoded.fileCount == 42)
        #expect(decoded.totalLines == 3500)
        #expect(decoded.gitBranch == "main")
    }

    @Test("Identifiable with unique IDs")
    func uniqueIDs() {
        let a = TestCodeProjectInfo(name: "A", path: "/a")
        let b = TestCodeProjectInfo(name: "B", path: "/b")
        #expect(a.id != b.id)
    }
}

// MARK: - File Entry Tests

@Suite("CodeFileEntry")
struct CodeFileEntryTests {
    @Test("Formatted size for small files")
    func smallFile() {
        let entry = TestCodeFileEntry(
            id: UUID(), relativePath: "main.swift",
            language: .swift, lineCount: 50, sizeBytes: 1500,
            lastModified: Date()
        )
        let formatted = entry.formattedSize
        #expect(formatted.contains("KB") || formatted.contains("bytes") || formatted.contains("B"))
    }

    @Test("Formatted size for large files")
    func largeFile() {
        let entry = TestCodeFileEntry(
            id: UUID(), relativePath: "big.swift",
            language: .swift, lineCount: 5000, sizeBytes: 2_500_000,
            lastModified: Date()
        )
        #expect(entry.formattedSize.contains("MB"))
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let entry = TestCodeFileEntry(
            id: UUID(), relativePath: "src/app.py",
            language: .python, lineCount: 200, sizeBytes: 8000,
            lastModified: Date()
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TestCodeFileEntry.self, from: data)
        #expect(decoded.relativePath == "src/app.py")
        #expect(decoded.language == .python)
        #expect(decoded.lineCount == 200)
    }

    @Test("Identifiable")
    func identifiable() {
        let id = UUID()
        let entry = TestCodeFileEntry(
            id: id, relativePath: "test.rs",
            language: .rust, lineCount: 10, sizeBytes: 500,
            lastModified: Date()
        )
        #expect(entry.id == id)
    }
}

// MARK: - Operation Result Tests

@Suite("CodeOperationResult")
struct CodeOperationResultTests {
    @Test("Init with defaults")
    func initDefaults() {
        let result = TestCodeOperationResult(
            operation: .analyze,
            input: "func foo() {}",
            output: "Simple function definition",
            language: .swift
        )
        #expect(result.operation == .analyze)
        #expect(result.input == "func foo() {}")
        #expect(result.output == "Simple function definition")
        #expect(result.language == .swift)
        #expect(result.tokensUsed == nil)
        #expect(result.model == nil)
    }

    @Test("Init with tokens and model")
    func initWithTokens() {
        let result = TestCodeOperationResult(
            operation: .refactor,
            input: "old code",
            output: "new code",
            language: .python,
            tokensUsed: 450,
            model: "claude-3-opus"
        )
        #expect(result.tokensUsed == 450)
        #expect(result.model == "claude-3-opus")
    }

    @Test("Identifiable with unique IDs")
    func uniqueIDs() {
        let a = TestCodeOperationResult(operation: .analyze, input: "a", output: "b", language: .swift)
        let b = TestCodeOperationResult(operation: .analyze, input: "a", output: "b", language: .swift)
        #expect(a.id != b.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let result = TestCodeOperationResult(
            operation: .generateTests,
            input: "class Foo",
            output: "test cases",
            language: .java,
            tokensUsed: 100
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TestCodeOperationResult.self, from: data)
        #expect(decoded.operation == .generateTests)
        #expect(decoded.language == .java)
        #expect(decoded.tokensUsed == 100)
    }

    @Test("Timestamp is set on creation")
    func timestampSet() {
        let before = Date()
        let result = TestCodeOperationResult(operation: .review, input: "x", output: "y", language: .go)
        let after = Date()
        #expect(result.timestamp >= before)
        #expect(result.timestamp <= after)
    }
}

// MARK: - Git Status Tests

@Suite("GitStatusInfo")
struct GitStatusInfoTests {
    @Test("Total changes computed correctly")
    func totalChanges() {
        let status = TestGitStatusInfo(
            branch: "main",
            remote: "origin",
            aheadBy: 2,
            behindBy: 0,
            stagedFiles: ["a.swift", "b.swift"],
            modifiedFiles: ["c.swift"],
            untrackedFiles: ["d.swift", "e.txt", "f.json"],
            hasUncommittedChanges: true
        )
        #expect(status.totalChanges == 6)
    }

    @Test("Zero total changes when all empty")
    func noChanges() {
        let status = TestGitStatusInfo(
            branch: "feature/x",
            remote: nil,
            aheadBy: 0,
            behindBy: 0,
            stagedFiles: [],
            modifiedFiles: [],
            untrackedFiles: [],
            hasUncommittedChanges: false
        )
        #expect(status.totalChanges == 0)
        #expect(status.hasUncommittedChanges == false)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let status = TestGitStatusInfo(
            branch: "develop",
            remote: "upstream",
            aheadBy: 1,
            behindBy: 3,
            stagedFiles: ["x.py"],
            modifiedFiles: [],
            untrackedFiles: ["new.txt"],
            hasUncommittedChanges: true
        )
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(TestGitStatusInfo.self, from: data)
        #expect(decoded.branch == "develop")
        #expect(decoded.remote == "upstream")
        #expect(decoded.aheadBy == 1)
        #expect(decoded.behindBy == 3)
        #expect(decoded.totalChanges == 2)
    }

    @Test("Remote can be nil")
    func nilRemote() {
        let status = TestGitStatusInfo(
            branch: "local",
            remote: nil,
            aheadBy: 0,
            behindBy: 0,
            stagedFiles: [],
            modifiedFiles: [],
            untrackedFiles: [],
            hasUncommittedChanges: false
        )
        #expect(status.remote == nil)
    }

    @Test("Ahead and behind tracking")
    func aheadBehind() {
        let status = TestGitStatusInfo(
            branch: "main",
            remote: "origin",
            aheadBy: 5,
            behindBy: 2,
            stagedFiles: [],
            modifiedFiles: [],
            untrackedFiles: [],
            hasUncommittedChanges: false
        )
        #expect(status.aheadBy == 5)
        #expect(status.behindBy == 2)
    }
}

// MARK: - Error Tests

@Suite("CodeAssistantError")
struct CodeAssistantErrorTests {
    @Test("Project not found error description")
    func projectNotFound() {
        let error = TestCodeAssistantError.projectNotFound("/missing/path")
        #expect(error.errorDescription?.contains("/missing/path") == true)
    }

    @Test("Git not available error description")
    func gitNotAvailable() {
        let error = TestCodeAssistantError.gitNotAvailable
        #expect(error.errorDescription?.contains("Git") == true)
    }

    @Test("Scan failed error description")
    func scanFailed() {
        let error = TestCodeAssistantError.scanFailed("permission denied")
        #expect(error.errorDescription?.contains("permission denied") == true)
    }

    @Test("Operation failed error description")
    func operationFailed() {
        let error = TestCodeAssistantError.operationFailed("timeout")
        #expect(error.errorDescription?.contains("timeout") == true)
    }

    @Test("File not readable error description")
    func fileNotReadable() {
        let error = TestCodeAssistantError.fileNotReadable("/secret/file.txt")
        #expect(error.errorDescription?.contains("/secret/file.txt") == true)
    }
}

// MARK: - Ignored Directories Logic Tests

@Suite("IgnoredDirectories")
struct IgnoredDirectoriesTests {
    private static let ignoredDirs: Set<String> = [
        "node_modules", ".build", "DerivedData", "build", "dist",
        ".git", "Pods", "vendor", "__pycache__"
    ]

    @Test("Common ignored directories")
    func commonIgnored() {
        #expect(Self.ignoredDirs.contains("node_modules"))
        #expect(Self.ignoredDirs.contains(".build"))
        #expect(Self.ignoredDirs.contains("DerivedData"))
        #expect(Self.ignoredDirs.contains(".git"))
        #expect(Self.ignoredDirs.contains("Pods"))
    }

    @Test("Source directories not ignored")
    func sourceNotIgnored() {
        #expect(!Self.ignoredDirs.contains("src"))
        #expect(!Self.ignoredDirs.contains("Sources"))
        #expect(!Self.ignoredDirs.contains("Tests"))
        #expect(!Self.ignoredDirs.contains("lib"))
    }

    @Test("All 8 standard ignored dirs")
    func count() {
        #expect(Self.ignoredDirs.count == 8)
    }
}
