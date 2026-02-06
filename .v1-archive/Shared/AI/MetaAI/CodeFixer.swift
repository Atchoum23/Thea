#if os(macOS)
    import Foundation
    import OSLog

    // MARK: - CodeFixer

    // Applies fixes to code based on error analysis and fix strategies

    public actor CodeFixer {
        public static let shared = CodeFixer()

        private let logger = Logger(subsystem: "com.thea.metaai", category: "CodeFixer")

        private init() {}

        // MARK: - Public Types

        public struct FixResult: Sendable {
            public let applied: Bool
            public let fileModified: String
            public let changeDescription: String
            public let linesChanged: Int

            public init(applied: Bool, fileModified: String, changeDescription: String, linesChanged: Int) {
                self.applied = applied
                self.fileModified = fileModified
                self.changeDescription = changeDescription
                self.linesChanged = linesChanged
            }
        }

        public enum FixError: LocalizedError, Sendable {
            case fileNotFound(String)
            case cannotReadFile(String)
            case cannotWriteFile(String)
            case fixFailed(String)
            case unsupportedStrategy

            public var errorDescription: String? {
                switch self {
                case let .fileNotFound(path):
                    "File not found: \(path)"
                case let .cannotReadFile(path):
                    "Cannot read file: \(path)"
                case let .cannotWriteFile(path):
                    "Cannot write file: \(path)"
                case let .fixFailed(message):
                    "Fix failed: \(message)"
                case .unsupportedStrategy:
                    "Unsupported fix strategy"
                }
            }
        }

        // MARK: - Apply Fix

        public func applyFix(
            _ fix: ErrorKnowledgeBase.KnownFix,
            to error: ErrorParser.ParsedError
        ) async throws -> FixResult {
            logger.info("Applying fix strategy: \(fix.fixStrategy.rawValue) to \(error.file):\(error.line)")

            switch fix.fixStrategy {
            case .addPublicModifier:
                return try await addPublicModifier(to: error)
            case .addSendable:
                return try await addSendableConformance(to: error)
            case .addMainActor:
                return try await addMainActorAttribute(to: error)
            case .addAsyncAwait:
                return try await addAsyncAwait(to: error)
            case .fixImport:
                return try await fixImport(for: error)
            case .addInitializer:
                return try await fixInitializer(for: error)
            case .addIsolatedAttribute:
                return try await addIsolatedAttribute(to: error)
            case .useTaskDetached:
                return try await useTaskDetached(for: error)
            case .useAIGeneration:
                return try await generateFixWithAI(for: error)
            }
        }

        // MARK: - Fix Strategies

        private func addPublicModifier(to error: ErrorParser.ParsedError) async throws -> FixResult {
            let fileContent = try loadFile(error.file)
            let lines = fileContent.components(separatedBy: .newlines)

            guard error.line > 0, error.line <= lines.count else {
                throw FixError.fixFailed("Invalid line number")
            }

            var modifiedLines = lines
            let targetLine = modifiedLines[error.line - 1]

            // Add public modifier if not already present
            if !targetLine.contains("public ") {
                let indent = String(targetLine.prefix { $0.isWhitespace })
                let trimmedLine = targetLine.trimmingCharacters(in: .whitespaces)

                if trimmedLine.hasPrefix("private ") || trimmedLine.hasPrefix("internal ") {
                    // Replace existing modifier
                    modifiedLines[error.line - 1] = targetLine.replacingOccurrences(of: "private ", with: "public ")
                        .replacingOccurrences(of: "internal ", with: "public ")
                } else {
                    // Add public at the start
                    modifiedLines[error.line - 1] = indent + "public " + trimmedLine
                }

                try saveFile(error.file, content: modifiedLines.joined(separator: "\n"))

                return FixResult(
                    applied: true,
                    fileModified: error.file,
                    changeDescription: "Added 'public' modifier at line \(error.line)",
                    linesChanged: 1
                )
            }

            return FixResult(
                applied: false,
                fileModified: error.file,
                changeDescription: "Public modifier already present",
                linesChanged: 0
            )
        }

        private func addSendableConformance(to error: ErrorParser.ParsedError) async throws -> FixResult {
            let fileContent = try loadFile(error.file)
            var lines = fileContent.components(separatedBy: .newlines)

            guard error.line > 0, error.line <= lines.count else {
                throw FixError.fixFailed("Invalid line number")
            }

            // Find the type declaration (struct, class, enum, actor)
            var typeDeclarationLine = error.line - 1

            for i in max(0, error.line - 10) ..< min(lines.count, error.line + 5) {
                let line = lines[i]
                if line.contains("struct ") || line.contains("class ") ||
                    line.contains("enum ") || line.contains("actor ")
                {
                    typeDeclarationLine = i
                    break
                }
            }

            let targetLine = lines[typeDeclarationLine]

            if !targetLine.contains(": Sendable"), !targetLine.contains("Sendable") {
                // Add Sendable conformance
                if targetLine.contains(":") {
                    // Already has protocol conformances
                    lines[typeDeclarationLine] = targetLine.replacingOccurrences(of: "{", with: ", Sendable {")
                } else if targetLine.contains("{") {
                    // No protocol conformances yet
                    lines[typeDeclarationLine] = targetLine.replacingOccurrences(of: "{", with: ": Sendable {")
                }

                try saveFile(error.file, content: lines.joined(separator: "\n"))

                return FixResult(
                    applied: true,
                    fileModified: error.file,
                    changeDescription: "Added Sendable conformance at line \(typeDeclarationLine + 1)",
                    linesChanged: 1
                )
            }

            return FixResult(
                applied: false,
                fileModified: error.file,
                changeDescription: "Sendable already present",
                linesChanged: 0
            )
        }

        private func addMainActorAttribute(to error: ErrorParser.ParsedError) async throws -> FixResult {
            let fileContent = try loadFile(error.file)
            var lines = fileContent.components(separatedBy: .newlines)

            guard error.line > 0, error.line <= lines.count else {
                throw FixError.fixFailed("Invalid line number")
            }

            // Check if @MainActor is already present on previous line
            if error.line > 1, lines[error.line - 2].contains("@MainActor") {
                return FixResult(
                    applied: false,
                    fileModified: error.file,
                    changeDescription: "@MainActor already present",
                    linesChanged: 0
                )
            }

            // Add @MainActor attribute
            let indent = String(lines[error.line - 1].prefix { $0.isWhitespace })
            lines.insert(indent + "@MainActor", at: error.line - 1)

            try saveFile(error.file, content: lines.joined(separator: "\n"))

            return FixResult(
                applied: true,
                fileModified: error.file,
                changeDescription: "Added @MainActor attribute before line \(error.line)",
                linesChanged: 1
            )
        }

        private func addAsyncAwait(to error: ErrorParser.ParsedError) async throws -> FixResult {
            // Load the file and analyze for simple async/await patterns
            var lines = try loadFile(error.file).components(separatedBy: .newlines)

            guard error.line > 0 && error.line <= lines.count else {
                return FixResult(
                    applied: false,
                    fileModified: error.file,
                    changeDescription: "Invalid line number",
                    linesChanged: 0
                )
            }

            let lineIndex = error.line - 1
            var line = lines[lineIndex]

            // Check for common patterns and apply simple fixes

            // Pattern 1: Missing 'await' before async call
            if error.message.contains("'async'") && error.message.contains("synchronous context") {
                // Try adding 'await' before function calls
                if let match = line.range(of: #"\.\w+\("#, options: .regularExpression) {
                    let methodStart = line.index(match.lowerBound, offsetBy: 1)
                    line = String(line[..<methodStart]) + "await " + String(line[methodStart...])
                    lines[lineIndex] = line
                    try saveFile(error.file, content: lines.joined(separator: "\n"))

                    return FixResult(
                        applied: true,
                        fileModified: error.file,
                        changeDescription: "Added 'await' keyword before async call",
                        linesChanged: 1
                    )
                }
            }

            // Pattern 2: Missing 'async' in function signature
            if error.message.contains("'await' in a function that does not support concurrency") {
                // Find the containing function and add 'async'
                for i in stride(from: lineIndex, through: 0, by: -1) {
                    if lines[i].contains("func ") && lines[i].contains("->") && !lines[i].contains("async") {
                        // Add async before the return arrow
                        lines[i] = lines[i].replacingOccurrences(of: "->", with: "async ->")
                        try saveFile(error.file, content: lines.joined(separator: "\n"))

                        return FixResult(
                            applied: true,
                            fileModified: error.file,
                            changeDescription: "Added 'async' to function signature",
                            linesChanged: 1
                        )
                    } else if lines[i].contains("func ") && lines[i].contains("{") && !lines[i].contains("async") {
                        // Function without return type - add async before {
                        lines[i] = lines[i].replacingOccurrences(of: "{", with: "async {")
                        try saveFile(error.file, content: lines.joined(separator: "\n"))

                        return FixResult(
                            applied: true,
                            fileModified: error.file,
                            changeDescription: "Added 'async' to function signature",
                            linesChanged: 1
                        )
                    }
                }
            }

            // For complex cases, delegate to AI assistance
            return FixResult(
                applied: false,
                fileModified: error.file,
                changeDescription: "Complex async/await pattern requires AI assistance - use applyAIGeneratedFix",
                linesChanged: 0
            )
        }

        private func fixImport(for error: ErrorParser.ParsedError) async throws -> FixResult {
            // Extract the missing type from error message
            let message = error.message.lowercased()

            // Common module mappings
            let moduleMappings: [String: String] = [
                "swiftui": "import SwiftUI",
                "foundation": "import Foundation",
                "combine": "import Combine",
                "swiftdata": "import SwiftData"
            ]

            // Try to guess the module
            for (keyword, importStatement) in moduleMappings {
                if message.contains(keyword) {
                    // Add import at top of file
                    var lines = try loadFile(error.file).components(separatedBy: .newlines)

                    // Check if import already exists
                    if lines.contains(where: { $0.contains(importStatement) }) {
                        return FixResult(
                            applied: false,
                            fileModified: error.file,
                            changeDescription: "Import already present",
                            linesChanged: 0
                        )
                    }

                    // Find the right place to insert (after existing imports)
                    var insertIndex = 0
                    for (index, line) in lines.enumerated() {
                        if line.starts(with: "import ") {
                            insertIndex = index + 1
                        }
                    }

                    lines.insert(importStatement, at: insertIndex)
                    try saveFile(error.file, content: lines.joined(separator: "\n"))

                    return FixResult(
                        applied: true,
                        fileModified: error.file,
                        changeDescription: "Added \(importStatement)",
                        linesChanged: 1
                    )
                }
            }

            return FixResult(
                applied: false,
                fileModified: error.file,
                changeDescription: "Could not determine required import",
                linesChanged: 0
            )
        }

        private func fixInitializer(for error: ErrorParser.ParsedError) async throws -> FixResult {
            // Placeholder - requires AI assistance
            FixResult(
                applied: false,
                fileModified: error.file,
                changeDescription: "Initializer fixes require AI assistance",
                linesChanged: 0
            )
        }

        private func addIsolatedAttribute(to error: ErrorParser.ParsedError) async throws -> FixResult {
            // Placeholder - requires AI assistance
            FixResult(
                applied: false,
                fileModified: error.file,
                changeDescription: "Isolation fixes require AI assistance",
                linesChanged: 0
            )
        }

        private func useTaskDetached(for error: ErrorParser.ParsedError) async throws -> FixResult {
            // Placeholder - requires AI assistance
            FixResult(
                applied: false,
                fileModified: error.file,
                changeDescription: "Task.detached fixes require AI assistance",
                linesChanged: 0
            )
        }

        private func generateFixWithAI(for error: ErrorParser.ParsedError) async throws -> FixResult {
            logger.info("AI-generated fix requested for: \(error.message)")

            // Try to generate fix using AI
            do {
                // Load surrounding code for context
                let fileContent = try loadFile(error.file)
                let lines = fileContent.components(separatedBy: .newlines)

                // Get more context (50 lines around the error)
                let startLine = max(0, error.line - 25)
                let endLine = min(lines.count, error.line + 25)
                let contextLines = Array(lines[startLine ..< endLine])
                let surroundingCode = contextLines.joined(separator: "\n")

                // Call AI generator
                let generatedFix = try await AICodeFixGenerator.shared.generateFixWithContext(
                    error: error,
                    surroundingCode: surroundingCode
                )

                // Apply the AI-generated fix if we have valid fixed code
                guard !generatedFix.fixedCode.isEmpty else {
                    return FixResult(
                        applied: false,
                        fileModified: error.file,
                        changeDescription: "AI could not generate a fix: \(generatedFix.explanation)",
                        linesChanged: 0
                    )
                }

                // Apply the fix by replacing the surrounding code section
                let fixedLines = generatedFix.fixedCode.components(separatedBy: .newlines)
                var allLines = lines

                // Replace the lines from startLine to endLine with the fixed code
                let replaceRange = startLine ..< endLine
                allLines.replaceSubrange(replaceRange, with: fixedLines)

                // Save the modified file
                try saveFile(error.file, content: allLines.joined(separator: "\n"))

                let linesChanged = abs(fixedLines.count - (endLine - startLine))
                logger.info("Applied AI fix to \(error.file): \(generatedFix.explanation)")

                return FixResult(
                    applied: true,
                    fileModified: error.file,
                    changeDescription: "AI fix applied: \(generatedFix.explanation) (confidence: \(Int(generatedFix.confidence * 100))%)",
                    linesChanged: linesChanged
                )
            } catch let aiError {
                logger.warning("AI fix generation failed: \(aiError.localizedDescription)")

                return FixResult(
                    applied: false,
                    fileModified: "unknown",
                    changeDescription: "AI fix generation failed: \(aiError.localizedDescription)",
                    linesChanged: 0
                )
            }
        }

        // MARK: - File Operations

        private func loadFile(_ path: String) throws -> String {
            guard FileManager.default.fileExists(atPath: path) else {
                throw FixError.fileNotFound(path)
            }

            do {
                return try String(contentsOfFile: path, encoding: .utf8)
            } catch {
                throw FixError.cannotReadFile(path)
            }
        }

        private func saveFile(_ path: String, content: String) throws {
            do {
                try content.write(toFile: path, atomically: true, encoding: .utf8)
                logger.info("Saved modified file: \(path)")
            } catch {
                throw FixError.cannotWriteFile(path)
            }
        }
    }

#endif
