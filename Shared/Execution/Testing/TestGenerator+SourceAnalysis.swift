// TestGenerator+SourceAnalysis.swift
// Thea V2
//
// Source code analysis for test generation

import Foundation

// MARK: - Analysis Types

struct SourceAnalysis {
    let functions: [FunctionInfo]
    let classes: [ClassInfo]
    let imports: [String]
    let hasAsyncCode: Bool
    let hasErrorHandling: Bool
    let complexity: Int
}

struct FunctionInfo {
    let name: String
    let parameters: [(name: String, type: String)]
    let returnType: String?
    let isAsync: Bool
    let canThrow: Bool
    let visibility: String
    let lineNumber: Int
}

struct ClassInfo {
    let name: String
    let methods: [FunctionInfo]
    let properties: [String]
    let protocols: [String]
}

// MARK: - Source Analysis

extension TestGenerator {

    func analyzeSourceCode(_ code: String, language: ProgrammingLanguage) -> SourceAnalysis {
        var functions: [FunctionInfo] = []
        var classes: [ClassInfo] = []
        var imports: [String] = []
        var hasAsync = false
        var hasErrorHandling = false

        let lines = code.components(separatedBy: .newlines)

        switch language {
        case .swift:
            analyzeSwiftSource(
                lines: lines,
                functions: &functions,
                classes: &classes,
                imports: &imports,
                hasAsync: &hasAsync,
                hasErrorHandling: &hasErrorHandling,
                language: language
            )

        case .python:
            analyzePythonSource(
                lines: lines,
                functions: &functions,
                classes: &classes,
                imports: &imports,
                hasAsync: &hasAsync,
                language: language
            )

        case .javascript, .typescript:
            analyzeJSSource(
                lines: lines,
                functions: &functions,
                classes: &classes,
                imports: &imports,
                hasAsync: &hasAsync,
                hasErrorHandling: &hasErrorHandling,
                language: language
            )

        default:
            break
        }

        return SourceAnalysis(
            functions: functions,
            classes: classes,
            imports: imports,
            hasAsyncCode: hasAsync,
            hasErrorHandling: hasErrorHandling,
            complexity: calculateComplexity(code)
        )
    }

    // MARK: - Swift Analysis

    private func analyzeSwiftSource(
        lines: [String],
        functions: inout [FunctionInfo],
        classes: inout [ClassInfo],
        imports: inout [String],
        hasAsync: inout Bool,
        hasErrorHandling: inout Bool,
        language: ProgrammingLanguage
    ) {
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("import ") {
                imports.append(String(trimmed.dropFirst(7)))
            }

            if trimmed.range(of: #"(public |private |internal |fileprivate )?(func |init)"#, options: .regularExpression) != nil {
                let funcName = extractFunctionName(from: trimmed, language: language)
                let isAsync = trimmed.contains("async")
                let canThrowError = trimmed.contains("throws")

                if isAsync { hasAsync = true }
                if canThrowError { hasErrorHandling = true }

                functions.append(FunctionInfo(
                    name: funcName,
                    parameters: extractParameters(from: trimmed, language: language),
                    returnType: extractReturnType(from: trimmed, language: language),
                    isAsync: isAsync,
                    canThrow: canThrowError,
                    visibility: extractVisibility(from: trimmed),
                    lineNumber: index + 1
                ))
            }

            if trimmed.contains("class ") || trimmed.contains("struct ") {
                let className = extractClassName(from: trimmed)
                classes.append(ClassInfo(
                    name: className,
                    methods: [],
                    properties: [],
                    protocols: []
                ))
            }
        }
    }

    // MARK: - Python Analysis

    private func analyzePythonSource(
        lines: [String],
        functions: inout [FunctionInfo],
        classes: inout [ClassInfo],
        imports: inout [String],
        hasAsync: inout Bool,
        language: ProgrammingLanguage
    ) {
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("import ") || trimmed.hasPrefix("from ") {
                imports.append(trimmed)
            }

            if trimmed.hasPrefix("def ") || trimmed.hasPrefix("async def ") {
                let isAsync = trimmed.hasPrefix("async def ")
                if isAsync { hasAsync = true }

                let funcName = extractFunctionName(from: trimmed, language: language)
                functions.append(FunctionInfo(
                    name: funcName,
                    parameters: extractParameters(from: trimmed, language: language),
                    returnType: extractReturnType(from: trimmed, language: language),
                    isAsync: isAsync,
                    canThrow: false,
                    visibility: funcName.hasPrefix("_") ? "private" : "public",
                    lineNumber: index + 1
                ))
            }

            if trimmed.hasPrefix("class ") {
                let className = extractClassName(from: trimmed)
                classes.append(ClassInfo(
                    name: className,
                    methods: [],
                    properties: [],
                    protocols: []
                ))
            }
        }
    }

    // MARK: - JavaScript/TypeScript Analysis

    private func analyzeJSSource(
        lines: [String],
        functions: inout [FunctionInfo],
        classes: inout [ClassInfo],
        imports: inout [String],
        hasAsync: inout Bool,
        hasErrorHandling: inout Bool,
        language: ProgrammingLanguage
    ) {
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("import ") || trimmed.contains("require(") {
                imports.append(trimmed)
            }

            if trimmed.contains("function ") || trimmed.contains("async function ") ||
               trimmed.contains("=> {") || trimmed.contains("=> (") {
                let isAsync = trimmed.contains("async")
                if isAsync { hasAsync = true }

                let funcName = extractFunctionName(from: trimmed, language: language)
                functions.append(FunctionInfo(
                    name: funcName,
                    parameters: extractParameters(from: trimmed, language: language),
                    returnType: nil,
                    isAsync: isAsync,
                    canThrow: false,
                    visibility: "public",
                    lineNumber: index + 1
                ))
            }

            if trimmed.contains("class ") {
                let className = extractClassName(from: trimmed)
                classes.append(ClassInfo(
                    name: className,
                    methods: [],
                    properties: [],
                    protocols: []
                ))
            }

            if trimmed.contains("try ") || trimmed.contains("catch ") {
                hasErrorHandling = true
            }
        }
    }

    // MARK: - Extraction Helpers

    func extractFunctionName(from line: String, language: ProgrammingLanguage) -> String {
        switch language {
        case .swift:
            if let match = line.firstMatch(of: /func\s+(\w+)/) {
                return String(match.1)
            }
            if line.contains("init") {
                return "init"
            }
        case .python:
            if let match = line.firstMatch(of: /def\s+(\w+)/) {
                return String(match.1)
            }
        case .javascript, .typescript:
            if let match = line.firstMatch(of: /function\s+(\w+)/) {
                return String(match.1)
            }
            if let match = line.firstMatch(of: /(\w+)\s*[=:]\s*(async\s+)?(\([^)]*\)|[^=])\s*=>/) {
                return String(match.1)
            }
        default:
            break
        }
        return "unknown"
    }

    func extractParameters(from line: String, language: ProgrammingLanguage) -> [(name: String, type: String)] {
        // Simplified parameter extraction
        []
    }

    func extractReturnType(from line: String, language: ProgrammingLanguage) -> String? {
        switch language {
        case .swift:
            if let match = line.firstMatch(of: /->\s*(\w+)/) {
                return String(match.1)
            }
        case .python:
            if let match = line.firstMatch(of: /->\s*(\w+)/) {
                return String(match.1)
            }
        default:
            break
        }
        return nil
    }

    func extractVisibility(from line: String) -> String {
        if line.contains("public ") { return "public" }
        if line.contains("private ") { return "private" }
        if line.contains("internal ") { return "internal" }
        if line.contains("fileprivate ") { return "fileprivate" }
        return "internal"
    }

    func extractClassName(from line: String) -> String {
        if let match = line.firstMatch(of: /(class|struct)\s+(\w+)/) {
            return String(match.2)
        }
        return "Unknown"
    }

    func calculateComplexity(_ code: String) -> Int {
        var complexity = 1
        let controlFlow = ["if ", "else ", "for ", "while ", "switch ", "case ", "guard ", "catch "]
        for keyword in controlFlow {
            complexity += code.components(separatedBy: keyword).count - 1
        }
        return complexity
    }
}
