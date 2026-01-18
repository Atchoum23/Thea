#if os(macOS)
import Foundation

// MARK: - Code Intelligence
// Claude Code-like capabilities for development assistance

@MainActor
@Observable
final class CodeIntelligence {
    static let shared = CodeIntelligence()

    private(set) var activeProjects: [CodeProject] = []
    private(set) var recentEdits: [CodeEdit] = []
    private(set) var codebaseIndex: CodebaseIndex?

    private init() {}

    // MARK: - Project Management

    func openProject(at url: URL) async throws -> CodeProject {
        let project = try await scanProject(url)

        activeProjects.append(project)

        // Index codebase
        codebaseIndex = try await indexCodebase(project)

        return project
    }

    private func scanProject(_ url: URL) async throws -> CodeProject {
        let fileManager = FileManager.default

        var files: [CodeFile] = []
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            if isCodeFile(fileURL) {
                let code = try String(contentsOf: fileURL, encoding: .utf8)
                let language = detectLanguage(fileURL)

                let file = CodeFile(
                    id: UUID(),
                    url: fileURL,
                    language: language,
                    content: code,
                    lastModified: Date()
                )

                files.append(file)
            }
        }

        return CodeProject(
            id: UUID(),
            name: url.lastPathComponent,
            rootURL: url,
            files: files,
            openedAt: Date()
        )
    }

    private func isCodeFile(_ url: URL) -> Bool {
        let codeExtensions = AppConfiguration.shared.codeIntelligenceConfig.codeFileExtensions
        return codeExtensions.contains(url.pathExtension.lowercased())
    }

    private func detectLanguage(_ url: URL) -> ProgrammingLanguage {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "swift": return .swift
        case "py": return .python
        case "js", "jsx": return .javascript
        case "ts", "tsx": return .typescript
        case "go": return .go
        case "rs": return .rust
        case "java": return .java
        case "kt": return .kotlin
        default: return .unknown
        }
    }

    // MARK: - Codebase Indexing

    private func indexCodebase(_ project: CodeProject) async throws -> CodebaseIndex {
        var symbols: [CodeSymbol] = []

        for file in project.files {
            let fileSymbols = try await extractSymbols(from: file)
            symbols.append(contentsOf: fileSymbols)
        }

        return CodebaseIndex(
            projectId: project.id,
            symbols: symbols,
            lastIndexed: Date()
        )
    }

    private func extractSymbols(from file: CodeFile) async throws -> [CodeSymbol] {
        var symbols: [CodeSymbol] = []

        // Simple regex-based extraction (in production, use proper AST parsing)
        let content = file.content

        switch file.language {
        case .swift:
            symbols.append(contentsOf: extractSwiftSymbols(content, fileURL: file.url))
        case .python:
            symbols.append(contentsOf: extractPythonSymbols(content, fileURL: file.url))
        case .javascript, .typescript:
            symbols.append(contentsOf: extractJSSymbols(content, fileURL: file.url))
        default:
            break
        }

        return symbols
    }

    private func extractSwiftSymbols(_ content: String, fileURL: URL) -> [CodeSymbol] {
        var symbols: [CodeSymbol] = []

        // Extract classes
        let classPattern = #"class\s+(\w+)"#
        if let regex = try? NSRegularExpression(pattern: classPattern) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

            for match in matches {
                if let range = Range(match.range(at: 1), in: content) {
                    let name = String(content[range])
                    symbols.append(CodeSymbol(
                        name: name,
                        type: .class,
                        fileURL: fileURL,
                        line: 0
                    ))
                }
            }
        }

        // Extract functions
        let funcPattern = #"func\s+(\w+)"#
        if let regex = try? NSRegularExpression(pattern: funcPattern) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

            for match in matches {
                if let range = Range(match.range(at: 1), in: content) {
                    let name = String(content[range])
                    symbols.append(CodeSymbol(
                        name: name,
                        type: .function,
                        fileURL: fileURL,
                        line: 0
                    ))
                }
            }
        }

        return symbols
    }

    private func extractPythonSymbols(_ content: String, fileURL: URL) -> [CodeSymbol] {
        var symbols: [CodeSymbol] = []

        // Extract classes
        let classPattern = #"class\s+(\w+)"#
        if let regex = try? NSRegularExpression(pattern: classPattern) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

            for match in matches {
                if let range = Range(match.range(at: 1), in: content) {
                    let name = String(content[range])
                    symbols.append(CodeSymbol(
                        name: name,
                        type: .class,
                        fileURL: fileURL,
                        line: 0
                    ))
                }
            }
        }

        return symbols
    }

    private func extractJSSymbols(_ content: String, fileURL: URL) -> [CodeSymbol] {
        var symbols: [CodeSymbol] = []

        // Extract functions
        let funcPattern = #"function\s+(\w+)"#
        if let regex = try? NSRegularExpression(pattern: funcPattern) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

            for match in matches {
                if let range = Range(match.range(at: 1), in: content) {
                    let name = String(content[range])
                    symbols.append(CodeSymbol(
                        name: name,
                        type: .function,
                        fileURL: fileURL,
                        line: 0
                    ))
                }
            }
        }

        return symbols
    }

    // MARK: - Code Completion

    func getCodeCompletions(file: URL, position: Int, context: String) async throws -> [CodeCompletion] {
        // Use AI to suggest code completions
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw CodeError.noProvider
        }

        let prompt = """
        You are a code completion assistant. Given the following context, suggest the next lines of code.

        Context:
        \(context)

        Provide 3-5 code completion suggestions in JSON format:
        [{"code": "...", "description": "..."}]
        """

        let codeConfig = AppConfiguration.shared.codeIntelligenceConfig

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: codeConfig.codeCompletionModel
        )

        var response = ""
        let stream = try await provider.chat(messages: [message], model: codeConfig.codeCompletionModel, stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case .delta(let text):
                response += text
            case .complete:
                break
            case .error(let error):
                throw error
            }
        }

        // Parse JSON response
        if let data = response.data(using: .utf8),
           let completions = try? JSONDecoder().decode([CodeCompletion].self, from: data) {
            return completions
        }

        return []
    }

    // MARK: - Code Explanation

    func explainCode(_ code: String, language: ProgrammingLanguage) async throws -> String {
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw CodeError.noProvider
        }

        let prompt = """
        Explain this \(language.rawValue) code in clear, concise terms:

        ```\(language.rawValue)
        \(code)
        ```
        """

        let codeConfig = AppConfiguration.shared.codeIntelligenceConfig

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: codeConfig.codeExplanationModel
        )

        var response = ""
        let stream = try await provider.chat(messages: [message], model: codeConfig.codeExplanationModel, stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case .delta(let text):
                response += text
            case .complete:
                break
            case .error(let error):
                throw error
            }
        }

        return response
    }

    // MARK: - Code Review

    func reviewCode(_ code: String, language: ProgrammingLanguage) async throws -> CodeReview {
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw CodeError.noProvider
        }

        let prompt = """
        Review this \(language.rawValue) code for:
        1. Potential bugs
        2. Performance issues
        3. Best practices
        4. Security vulnerabilities

        Code:
        ```\(language.rawValue)
        \(code)
        ```

        Provide feedback in JSON format:
        {
          "issues": [{"severity": "high/medium/low", "description": "...", "line": 0}],
          "suggestions": ["..."],
          "rating": 0-10
        }
        """

        let codeConfig = AppConfiguration.shared.codeIntelligenceConfig

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: codeConfig.codeReviewModel
        )

        var response = ""
        let stream = try await provider.chat(messages: [message], model: codeConfig.codeReviewModel, stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case .delta(let text):
                response += text
            case .complete:
                break
            case .error(let error):
                throw error
            }
        }

        // Parse JSON response
        if let data = response.data(using: .utf8),
           let review = try? JSONDecoder().decode(CodeReview.self, from: data) {
            return review
        }

        return CodeReview(issues: [], suggestions: [], rating: 5)
    }

    // MARK: - Symbol Search

    func searchSymbol(_ query: String) -> [CodeSymbol] {
        guard let index = codebaseIndex else { return [] }

        return index.symbols.filter { symbol in
            symbol.name.lowercased().contains(query.lowercased())
        }
    }

    // MARK: - Git Integration

    func getGitStatus(project: CodeProject) async throws -> GitStatus {
        let codeConfig = AppConfiguration.shared.codeIntelligenceConfig

        let process = Process()
        process.currentDirectoryURL = project.rootURL
        process.executableURL = URL(fileURLWithPath: codeConfig.gitExecutablePath)
        process.arguments = ["status", "--porcelain"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        var modified: [URL] = []
        var untracked: [URL] = []

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let status = String(parts[0])
            let filePath = String(parts[1])
            let fileURL = project.rootURL.appendingPathComponent(filePath)

            if status.contains("M") {
                modified.append(fileURL)
            } else if status.contains("??") {
                untracked.append(fileURL)
            }
        }

        return GitStatus(
            modified: modified,
            untracked: untracked,
            currentBranch: try await getCurrentBranch(project)
        )
    }

    private func getCurrentBranch(_ project: CodeProject) async throws -> String {
        let codeConfig = AppConfiguration.shared.codeIntelligenceConfig

        let process = Process()
        process.currentDirectoryURL = project.rootURL
        process.executableURL = URL(fileURLWithPath: codeConfig.gitExecutablePath)
        process.arguments = ["branch", "--show-current"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "main"
    }
}

// MARK: - Models

struct CodeProject: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rootURL: URL
    var files: [CodeFile]
    let openedAt: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CodeProject, rhs: CodeProject) -> Bool {
        lhs.id == rhs.id
    }
}

struct CodeFile: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let language: ProgrammingLanguage
    var content: String
    var lastModified: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CodeFile, rhs: CodeFile) -> Bool {
        lhs.id == rhs.id
    }
}

enum ProgrammingLanguage: String, Codable {
    case swift = "Swift"
    case python = "Python"
    case javascript = "JavaScript"
    case typescript = "TypeScript"
    case go = "Go"
    case rust = "Rust"
    case java = "Java"
    case kotlin = "Kotlin"
    case unknown = "Unknown"
}

struct CodebaseIndex {
    let projectId: UUID
    var symbols: [CodeSymbol]
    let lastIndexed: Date
}

struct CodeSymbol {
    let name: String
    let type: SymbolType
    let fileURL: URL
    let line: Int

    enum SymbolType {
        case `class`, function, variable, `enum`, `protocol`, `struct`
    }
}

struct CodeCompletion: Codable {
    let code: String
    let description: String
}

struct CodeReview: Codable {
    let issues: [CodeIssue]
    let suggestions: [String]
    let rating: Int

    struct CodeIssue: Codable {
        let severity: String
        let description: String
        let line: Int
    }
}

struct CodeEdit {
    let fileURL: URL
    let timestamp: Date
    let changeType: ChangeType

    enum ChangeType {
        case addition, deletion, modification
    }
}

struct GitStatus {
    let modified: [URL]
    let untracked: [URL]
    let currentBranch: String
}

// MARK: - Errors

enum CodeError: LocalizedError {
    case noProvider
    case indexingFailed

    var errorDescription: String? {
        switch self {
        case .noProvider:
            return "No AI provider configured"
        case .indexingFailed:
            return "Failed to index codebase"
        }
    }
}

#endif
