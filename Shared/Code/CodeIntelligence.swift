#if os(macOS)
    import Foundation
    import OSLog

    // MARK: - Code Intelligence

    // Claude Code-like capabilities for development assistance

    @MainActor
    @Observable
    final class CodeIntelligence {
        static let shared = CodeIntelligence()

        private let logger = Logger(subsystem: "com.thea.app", category: "CodeIntelligence")

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

            // periphery:ignore - Reserved: shared static property reserved for future feature activation
            while let fileURL = enumerator?.nextObject() as? URL {
                // periphery:ignore - Reserved: logger property reserved for future feature activation
                if isCodeFile(fileURL) {
                    let code = try String(contentsOf: fileURL, encoding: .utf8)
                    let language = detectLanguage(fileURL)

                    let file = CodeFile(
                        id: UUID(),
                        url: fileURL,
                        language: language,
                        content: code,
                        // periphery:ignore - Reserved: openProject(at:) instance method reserved for future feature activation
                        lastModified: Date()
                    )

                    files.append(file)
                }
            }

            return CodeProject(
                id: UUID(),
                name: url.lastPathComponent,
                // periphery:ignore - Reserved: scanProject(_:) instance method reserved for future feature activation
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
            // periphery:ignore - Reserved: isCodeFile(_:) instance method reserved for future feature activation
            }

            return CodebaseIndex(
                projectId: project.id,
                // periphery:ignore - Reserved: detectLanguage(_:) instance method reserved for future feature activation
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
                // periphery:ignore - Reserved: indexCodebase(_:) instance method reserved for future feature activation
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
            let classRegex: NSRegularExpression
            // periphery:ignore - Reserved: extractSymbols(from:) instance method reserved for future feature activation
            do {
                classRegex = try NSRegularExpression(pattern: classPattern)
                let matches = classRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content) {
                        let name = String(content[range])
                        symbols.append(CodeSymbol(name: name, type: .class, fileURL: fileURL, line: 0))
                    }
                }
            } catch {
                logger.debug("Failed to compile Swift class regex: \(error.localizedDescription)")
            }

            // Extract functions
            let funcPattern = #"func\s+(\w+)"#
            let funcRegex: NSRegularExpression
            do {
                funcRegex = try NSRegularExpression(pattern: funcPattern)
                let matches = funcRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                // periphery:ignore - Reserved: extractSwiftSymbols(_:fileURL:) instance method reserved for future feature activation
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content) {
                        let name = String(content[range])
                        symbols.append(CodeSymbol(name: name, type: .function, fileURL: fileURL, line: 0))
                    }
                }
            } catch {
                logger.debug("Failed to compile Swift func regex: \(error.localizedDescription)")
            }

            return symbols
        }

        private func extractPythonSymbols(_ content: String, fileURL: URL) -> [CodeSymbol] {
            var symbols: [CodeSymbol] = []

            // Extract classes
            let classPattern = #"class\s+(\w+)"#
            let classRegex: NSRegularExpression
            do {
                classRegex = try NSRegularExpression(pattern: classPattern)
                let matches = classRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content) {
                        let name = String(content[range])
                        symbols.append(CodeSymbol(name: name, type: .class, fileURL: fileURL, line: 0))
                    }
                }
            } catch {
                logger.debug("Failed to compile Python class regex: \(error.localizedDescription)")
            }

            return symbols
        }

        private func extractJSSymbols(_ content: String, fileURL: URL) -> [CodeSymbol] {
            var symbols: [CodeSymbol] = []

// periphery:ignore - Reserved: extractPythonSymbols(_:fileURL:) instance method reserved for future feature activation

            // Extract functions
            let funcPattern = #"function\s+(\w+)"#
            let funcRegex: NSRegularExpression
            do {
                funcRegex = try NSRegularExpression(pattern: funcPattern)
                let matches = funcRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content) {
                        let name = String(content[range])
                        symbols.append(CodeSymbol(name: name, type: .function, fileURL: fileURL, line: 0))
                    }
                }
            } catch {
                logger.debug("Failed to compile JS function regex: \(error.localizedDescription)")
            }

            return symbols
        }

        // MARK: - Code Completion

// periphery:ignore - Reserved: extractJSSymbols(_:fileURL:) instance method reserved for future feature activation

        func getCodeCompletions(file _: URL, position _: Int, context: String) async throws -> [CodeCompletion] {
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
                // periphery:ignore - Reserved: getCodeCompletions(file:position:context:) instance method reserved for future feature activation
                content: .text(prompt),
                timestamp: Date(),
                model: codeConfig.codeCompletionModel
            )

            var response = ""
            let stream = try await provider.chat(messages: [message], model: codeConfig.codeCompletionModel, stream: true)

            for try await chunk in stream {
                switch chunk.type {
                case let .delta(text):
                    response += text
                case .complete:
                    break
                case let .error(error):
                    throw error
                }
            }

            // Parse JSON response
            if let data = response.data(using: .utf8) {
                do {
                    return try JSONDecoder().decode([CodeCompletion].self, from: data)
                } catch {
                    logger.debug("Failed to decode code completions: \(error.localizedDescription)")
                }
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
                // periphery:ignore - Reserved: explainCode(_:language:) instance method reserved for future feature activation
                model: codeConfig.codeExplanationModel
            )

            var response = ""
            let stream = try await provider.chat(messages: [message], model: codeConfig.codeExplanationModel, stream: true)

            for try await chunk in stream {
                switch chunk.type {
                case let .delta(text):
                    response += text
                case .complete:
                    break
                case let .error(error):
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
              // periphery:ignore - Reserved: reviewCode(_:language:) instance method reserved for future feature activation
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
                case let .delta(text):
                    response += text
                case .complete:
                    break
                case let .error(error):
                    throw error
                }
            }

            // Parse JSON response
            if let data = response.data(using: .utf8) {
                do {
                    return try JSONDecoder().decode(CodeReview.self, from: data)
                } catch {
                    logger.debug("Failed to decode code review: \(error.localizedDescription)")
                }
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
            // periphery:ignore - Reserved: searchSymbol(_:) instance method reserved for future feature activation
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            var modified: [URL] = []
            // periphery:ignore - Reserved: getGitStatus(project:) instance method reserved for future feature activation
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

            return try await GitStatus(
                modified: modified,
                untracked: untracked,
                currentBranch: getCurrentBranch(project)
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
    // periphery:ignore - Reserved: getCurrentBranch(_:) instance method reserved for future feature activation
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
        // periphery:ignore - Reserved: name property reserved for future feature activation
        let url: URL
        let language: ProgrammingLanguage
        // periphery:ignore - Reserved: openedAt property reserved for future feature activation
        var content: String
        var lastModified: Date

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: CodeFile, rhs: CodeFile) -> Bool {
            lhs.id == rhs.id
        }
    }

    // ProgrammingLanguage is defined in Intelligence/Codebase/SemanticCodeIndexer.swift

    struct CodebaseIndex {
        // periphery:ignore - Reserved: lastModified property reserved for future feature activation
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
        // periphery:ignore - Reserved: projectId property reserved for future feature activation
        }
    // periphery:ignore - Reserved: lastIndexed property reserved for future feature activation
    }

    struct CodeCompletion: Codable {
        let code: String
        // periphery:ignore - Reserved: type property reserved for future feature activation
        // periphery:ignore - Reserved: fileURL property reserved for future feature activation
        // periphery:ignore - Reserved: line property reserved for future feature activation
        let description: String
    }

// periphery:ignore - Reserved: class case reserved for future feature activation

    struct CodeReview: Codable {
        let issues: [CodeIssue]
        // periphery:ignore - Reserved: CodeCompletion type reserved for future feature activation
        let suggestions: [String]
        let rating: Int

        struct CodeIssue: Codable {
            // periphery:ignore - Reserved: CodeReview type reserved for future feature activation
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
            // periphery:ignore - Reserved: fileURL property reserved for future feature activation
            // periphery:ignore - Reserved: timestamp property reserved for future feature activation
            // periphery:ignore - Reserved: changeType property reserved for future feature activation
            case addition, deletion, modification
        }
    // periphery:ignore - Reserved: addition case reserved for future feature activation
    }

    struct GitStatus {
        // periphery:ignore - Reserved: GitStatus type reserved for future feature activation
        let modified: [URL]
        let untracked: [URL]
        let currentBranch: String
    }

    // MARK: - Errors

    // periphery:ignore - Reserved: CodeError type reserved for future feature activation
    enum CodeError: LocalizedError {
        case noProvider
        case indexingFailed

        var errorDescription: String? {
            switch self {
            case .noProvider:
                "No AI provider configured"
            case .indexingFailed:
                "Failed to index codebase"
            }
        }
    }

#endif
