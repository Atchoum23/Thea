// ArtifactAndPermissionsTypesTests.swift
// Tests for standalone test doubles mirroring:
//   Shared/Core/ArtifactManagerTypes.swift (Artifact, ArtifactType, CodeLanguage,
//   DocumentFormat, VisualizationType, DataFormat, ArtifactError)

import Foundation
import XCTest

// MARK: - Test Doubles — Artifact Types

private enum TDCodeLanguage: String, Codable, Sendable, CaseIterable {
    case swift, python, javascript, typescript, java, kotlin, rust, go, cpp, csharp
    case html, css, sql, bash, ruby, php, scala, haskell, elixir, clojure

    var displayName: String {
        let names: [TDCodeLanguage: String] = [
            .swift: "Swift", .python: "Python", .javascript: "JavaScript",
            .typescript: "TypeScript", .java: "Java", .kotlin: "Kotlin",
            .rust: "Rust", .go: "Go", .cpp: "C++", .csharp: "C#",
            .html: "HTML", .css: "CSS", .sql: "SQL", .bash: "Bash",
            .ruby: "Ruby", .php: "PHP", .scala: "Scala", .haskell: "Haskell",
            .elixir: "Elixir", .clojure: "Clojure"
        ]
        return names[self]!
    }

    var fileExtension: String {
        let exts: [TDCodeLanguage: String] = [
            .swift: "swift", .python: "py", .javascript: "js", .typescript: "ts",
            .java: "java", .kotlin: "kt", .rust: "rs", .go: "go",
            .cpp: "cpp", .csharp: "cs", .html: "html", .css: "css",
            .sql: "sql", .bash: "sh", .ruby: "rb", .php: "php",
            .scala: "scala", .haskell: "hs", .elixir: "ex", .clojure: "clj"
        ]
        return exts[self]!
    }
}

private enum TDDocumentFormat: String, Codable, Sendable, CaseIterable {
    case markdown, plainText, html, latex, rst

    var displayName: String {
        switch self {
        case .markdown: "Markdown"
        case .plainText: "Plain Text"
        case .html: "HTML"
        case .latex: "LaTeX"
        case .rst: "reStructuredText"
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .plainText: "txt"
        case .html: "html"
        case .latex: "tex"
        case .rst: "rst"
        }
    }
}

private enum TDVisualizationType: String, Codable, Sendable, CaseIterable {
    case svg, chart, diagram, flowchart, mindmap

    var displayName: String {
        switch self {
        case .svg: "SVG"
        case .chart: "Chart"
        case .diagram: "Diagram"
        case .flowchart: "Flowchart"
        case .mindmap: "Mind Map"
        }
    }
}

private enum TDDataFormat: String, Codable, Sendable, CaseIterable {
    case json, csv, yaml, xml, toml

    var displayName: String {
        switch self {
        case .json: "JSON"
        case .csv: "CSV"
        case .yaml: "YAML"
        case .xml: "XML"
        case .toml: "TOML"
        }
    }

    var fileExtension: String { rawValue }
}

private enum TDArtifactType: Codable, Sendable, Hashable {
    case code(language: TDCodeLanguage)
    case document(format: TDDocumentFormat)
    case visualization(type: TDVisualizationType)
    case interactive
    case data(format: TDDataFormat)

    var category: String {
        switch self {
        case .code: "code"
        case .document: "document"
        case .visualization: "visualization"
        case .interactive: "interactive"
        case .data: "data"
        }
    }

    var displayName: String {
        switch self {
        case let .code(language): "Code (\(language.displayName))"
        case let .document(format): "Document (\(format.displayName))"
        case let .visualization(type): "Visualization (\(type.displayName))"
        case .interactive: "Interactive"
        case let .data(format): "Data (\(format.displayName))"
        }
    }

    var fileExtension: String {
        switch self {
        case let .code(language): language.fileExtension
        case let .document(format): format.fileExtension
        case .visualization: "svg"
        case .interactive: "html"
        case let .data(format): format.fileExtension
        }
    }

    var rawValue: String {
        switch self {
        case let .code(language): "code:\(language.rawValue)"
        case let .document(format): "document:\(format.rawValue)"
        case let .visualization(type): "visualization:\(type.rawValue)"
        case .interactive: "interactive"
        case let .data(format): "data:\(format.rawValue)"
        }
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":")
        guard let cat = parts.first else { return nil }
        switch cat {
        case "code":
            guard parts.count > 1,
                  let lang = TDCodeLanguage(rawValue: String(parts[1])) else { return nil }
            self = .code(language: lang)
        case "document":
            guard parts.count > 1,
                  let fmt = TDDocumentFormat(rawValue: String(parts[1])) else { return nil }
            self = .document(format: fmt)
        case "visualization":
            guard parts.count > 1,
                  let vType = TDVisualizationType(rawValue: String(parts[1])) else { return nil }
            self = .visualization(type: vType)
        case "interactive":
            self = .interactive
        case "data":
            guard parts.count > 1,
                  let fmt = TDDataFormat(rawValue: String(parts[1])) else { return nil }
            self = .data(format: fmt)
        default:
            return nil
        }
    }
}

private struct TDArtifact: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    let type: TDArtifactType
    var content: String
    var description: String?
    var tags: [String]
    var conversationId: String?
    let createdAt: Date
    var modifiedAt: Date
    var version: Int
    var contentPath: String?

    init(
        id: UUID = UUID(),
        title: String,
        type: TDArtifactType,
        content: String,
        description: String? = nil,
        tags: [String] = [],
        conversationId: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        version: Int = 1,
        contentPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.content = content
        self.description = description
        self.tags = tags
        self.conversationId = conversationId
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.version = version
        self.contentPath = contentPath
    }
}

private enum TDArtifactError: Error, LocalizedError, Sendable {
    case notFound
    case saveFailed(String)
    case invalidContent
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound: "Artifact not found"
        case let .saveFailed(reason): "Failed to save artifact: \(reason)"
        case .invalidContent: "Invalid artifact content"
        case let .exportFailed(reason): "Failed to export artifact: \(reason)"
        }
    }
}

// MARK: - ArtifactTypesTests (34 tests)

final class ArtifactTypesTests: XCTestCase {

    // MARK: - CodeLanguage

    func testCodeLanguageAllCasesCount() {
        XCTAssertEqual(TDCodeLanguage.allCases.count, 20)
    }

    func testCodeLanguageUniqueRawValues() {
        let rawValues = TDCodeLanguage.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count,
                       "CodeLanguage raw values must be unique")
    }

    func testCodeLanguageRawValues() {
        XCTAssertEqual(TDCodeLanguage.swift.rawValue, "swift")
        XCTAssertEqual(TDCodeLanguage.python.rawValue, "python")
        XCTAssertEqual(TDCodeLanguage.javascript.rawValue, "javascript")
        XCTAssertEqual(TDCodeLanguage.typescript.rawValue, "typescript")
        XCTAssertEqual(TDCodeLanguage.java.rawValue, "java")
        XCTAssertEqual(TDCodeLanguage.kotlin.rawValue, "kotlin")
        XCTAssertEqual(TDCodeLanguage.rust.rawValue, "rust")
        XCTAssertEqual(TDCodeLanguage.go.rawValue, "go")
        XCTAssertEqual(TDCodeLanguage.cpp.rawValue, "cpp")
        XCTAssertEqual(TDCodeLanguage.csharp.rawValue, "csharp")
        XCTAssertEqual(TDCodeLanguage.html.rawValue, "html")
        XCTAssertEqual(TDCodeLanguage.css.rawValue, "css")
        XCTAssertEqual(TDCodeLanguage.sql.rawValue, "sql")
        XCTAssertEqual(TDCodeLanguage.bash.rawValue, "bash")
        XCTAssertEqual(TDCodeLanguage.ruby.rawValue, "ruby")
        XCTAssertEqual(TDCodeLanguage.php.rawValue, "php")
        XCTAssertEqual(TDCodeLanguage.scala.rawValue, "scala")
        XCTAssertEqual(TDCodeLanguage.haskell.rawValue, "haskell")
        XCTAssertEqual(TDCodeLanguage.elixir.rawValue, "elixir")
        XCTAssertEqual(TDCodeLanguage.clojure.rawValue, "clojure")
    }

    func testCodeLanguageDisplayNames() {
        XCTAssertEqual(TDCodeLanguage.swift.displayName, "Swift")
        XCTAssertEqual(TDCodeLanguage.cpp.displayName, "C++")
        XCTAssertEqual(TDCodeLanguage.csharp.displayName, "C#")
        XCTAssertEqual(TDCodeLanguage.javascript.displayName, "JavaScript")
        XCTAssertEqual(TDCodeLanguage.typescript.displayName, "TypeScript")
        XCTAssertEqual(TDCodeLanguage.go.displayName, "Go")
    }

    func testCodeLanguageFileExtensions() {
        XCTAssertEqual(TDCodeLanguage.swift.fileExtension, "swift")
        XCTAssertEqual(TDCodeLanguage.python.fileExtension, "py")
        XCTAssertEqual(TDCodeLanguage.javascript.fileExtension, "js")
        XCTAssertEqual(TDCodeLanguage.typescript.fileExtension, "ts")
        XCTAssertEqual(TDCodeLanguage.kotlin.fileExtension, "kt")
        XCTAssertEqual(TDCodeLanguage.rust.fileExtension, "rs")
        XCTAssertEqual(TDCodeLanguage.cpp.fileExtension, "cpp")
        XCTAssertEqual(TDCodeLanguage.csharp.fileExtension, "cs")
        XCTAssertEqual(TDCodeLanguage.bash.fileExtension, "sh")
        XCTAssertEqual(TDCodeLanguage.ruby.fileExtension, "rb")
        XCTAssertEqual(TDCodeLanguage.haskell.fileExtension, "hs")
        XCTAssertEqual(TDCodeLanguage.elixir.fileExtension, "ex")
        XCTAssertEqual(TDCodeLanguage.clojure.fileExtension, "clj")
    }

    func testCodeLanguageCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for lang in TDCodeLanguage.allCases {
            let data = try encoder.encode(lang)
            let decoded = try decoder.decode(TDCodeLanguage.self, from: data)
            XCTAssertEqual(decoded, lang, "\(lang) should survive Codable roundtrip")
        }
    }

    func testCodeLanguageInitFromRawValue() {
        for lang in TDCodeLanguage.allCases {
            XCTAssertEqual(TDCodeLanguage(rawValue: lang.rawValue), lang)
        }
        XCTAssertNil(TDCodeLanguage(rawValue: "brainfuck"))
        XCTAssertNil(TDCodeLanguage(rawValue: ""))
    }

    // MARK: - DocumentFormat

    func testDocumentFormatAllCasesCount() {
        XCTAssertEqual(TDDocumentFormat.allCases.count, 5)
    }

    func testDocumentFormatDisplayNames() {
        XCTAssertEqual(TDDocumentFormat.markdown.displayName, "Markdown")
        XCTAssertEqual(TDDocumentFormat.plainText.displayName, "Plain Text")
        XCTAssertEqual(TDDocumentFormat.html.displayName, "HTML")
        XCTAssertEqual(TDDocumentFormat.latex.displayName, "LaTeX")
        XCTAssertEqual(TDDocumentFormat.rst.displayName, "reStructuredText")
    }

    func testDocumentFormatFileExtensions() {
        XCTAssertEqual(TDDocumentFormat.markdown.fileExtension, "md")
        XCTAssertEqual(TDDocumentFormat.plainText.fileExtension, "txt")
        XCTAssertEqual(TDDocumentFormat.html.fileExtension, "html")
        XCTAssertEqual(TDDocumentFormat.latex.fileExtension, "tex")
        XCTAssertEqual(TDDocumentFormat.rst.fileExtension, "rst")
    }

    func testDocumentFormatCodableRoundtrip() throws {
        for fmt in TDDocumentFormat.allCases {
            let data = try JSONEncoder().encode(fmt)
            let decoded = try JSONDecoder().decode(TDDocumentFormat.self, from: data)
            XCTAssertEqual(decoded, fmt)
        }
    }

    // MARK: - VisualizationType

    func testVisualizationTypeAllCasesCount() {
        XCTAssertEqual(TDVisualizationType.allCases.count, 5)
    }

    func testVisualizationTypeDisplayNames() {
        XCTAssertEqual(TDVisualizationType.svg.displayName, "SVG")
        XCTAssertEqual(TDVisualizationType.chart.displayName, "Chart")
        XCTAssertEqual(TDVisualizationType.diagram.displayName, "Diagram")
        XCTAssertEqual(TDVisualizationType.flowchart.displayName, "Flowchart")
        XCTAssertEqual(TDVisualizationType.mindmap.displayName, "Mind Map")
    }

    func testVisualizationTypeCodableRoundtrip() throws {
        for viz in TDVisualizationType.allCases {
            let data = try JSONEncoder().encode(viz)
            let decoded = try JSONDecoder().decode(TDVisualizationType.self, from: data)
            XCTAssertEqual(decoded, viz)
        }
    }

    func testVisualizationTypeUniqueRawValues() {
        let rawValues = TDVisualizationType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    // MARK: - DataFormat

    func testDataFormatAllCasesCount() {
        XCTAssertEqual(TDDataFormat.allCases.count, 5)
    }

    func testDataFormatDisplayNames() {
        XCTAssertEqual(TDDataFormat.json.displayName, "JSON")
        XCTAssertEqual(TDDataFormat.csv.displayName, "CSV")
        XCTAssertEqual(TDDataFormat.yaml.displayName, "YAML")
        XCTAssertEqual(TDDataFormat.xml.displayName, "XML")
        XCTAssertEqual(TDDataFormat.toml.displayName, "TOML")
    }

    func testDataFormatFileExtensionEqualsRawValue() {
        for fmt in TDDataFormat.allCases {
            XCTAssertEqual(fmt.fileExtension, fmt.rawValue,
                           "DataFormat.\(fmt) fileExtension should equal rawValue")
        }
    }

    func testDataFormatCodableRoundtrip() throws {
        for fmt in TDDataFormat.allCases {
            let data = try JSONEncoder().encode(fmt)
            let decoded = try JSONDecoder().decode(TDDataFormat.self, from: data)
            XCTAssertEqual(decoded, fmt)
        }
    }

    // MARK: - ArtifactType

    func testArtifactTypeCategories() {
        XCTAssertEqual(TDArtifactType.code(language: .swift).category, "code")
        XCTAssertEqual(TDArtifactType.document(format: .markdown).category, "document")
        XCTAssertEqual(TDArtifactType.visualization(type: .chart).category, "visualization")
        XCTAssertEqual(TDArtifactType.interactive.category, "interactive")
        XCTAssertEqual(TDArtifactType.data(format: .json).category, "data")
    }

    func testArtifactTypeDisplayNames() {
        XCTAssertEqual(TDArtifactType.code(language: .python).displayName, "Code (Python)")
        XCTAssertEqual(TDArtifactType.document(format: .latex).displayName, "Document (LaTeX)")
        XCTAssertEqual(TDArtifactType.visualization(type: .mindmap).displayName,
                       "Visualization (Mind Map)")
        XCTAssertEqual(TDArtifactType.interactive.displayName, "Interactive")
        XCTAssertEqual(TDArtifactType.data(format: .csv).displayName, "Data (CSV)")
    }

    func testArtifactTypeFileExtensions() {
        XCTAssertEqual(TDArtifactType.code(language: .rust).fileExtension, "rs")
        XCTAssertEqual(TDArtifactType.document(format: .markdown).fileExtension, "md")
        XCTAssertEqual(TDArtifactType.visualization(type: .svg).fileExtension, "svg")
        XCTAssertEqual(TDArtifactType.visualization(type: .flowchart).fileExtension, "svg")
        XCTAssertEqual(TDArtifactType.interactive.fileExtension, "html")
        XCTAssertEqual(TDArtifactType.data(format: .yaml).fileExtension, "yaml")
    }

    func testArtifactTypeRawValueRoundtrip() {
        let cases: [TDArtifactType] = [
            .code(language: .swift),
            .code(language: .clojure),
            .document(format: .html),
            .document(format: .rst),
            .visualization(type: .diagram),
            .interactive,
            .data(format: .toml)
        ]
        for artType in cases {
            let raw = artType.rawValue
            let restored = TDArtifactType(rawValue: raw)
            XCTAssertNotNil(restored, "Should parse rawValue '\(raw)'")
            XCTAssertEqual(restored, artType, "'\(raw)' should roundtrip")
        }
    }

    func testArtifactTypeRawValueInvalid() {
        XCTAssertNil(TDArtifactType(rawValue: ""))
        XCTAssertNil(TDArtifactType(rawValue: "unknown"))
        XCTAssertNil(TDArtifactType(rawValue: "code:"))
        XCTAssertNil(TDArtifactType(rawValue: "code:brainfuck"))
        XCTAssertNil(TDArtifactType(rawValue: "document:pdf"))
        XCTAssertNil(TDArtifactType(rawValue: "data:sqlite"))
    }

    func testArtifactTypeCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let cases: [TDArtifactType] = [
            .code(language: .typescript),
            .document(format: .plainText),
            .visualization(type: .chart),
            .interactive,
            .data(format: .xml)
        ]
        for artType in cases {
            let data = try encoder.encode(artType)
            let decoded = try decoder.decode(TDArtifactType.self, from: data)
            XCTAssertEqual(decoded, artType, "\(artType) should survive Codable roundtrip")
        }
    }

    func testArtifactTypeHashable() {
        var set = Set<TDArtifactType>()
        set.insert(.code(language: .swift))
        set.insert(.code(language: .swift))
        set.insert(.code(language: .python))
        set.insert(.interactive)
        set.insert(.interactive)
        XCTAssertEqual(set.count, 3, "Set should deduplicate equal ArtifactType values")
    }

    // MARK: - Artifact Struct

    func testArtifactCreationDefaults() {
        let artifact = TDArtifact(title: "Hello", type: .code(language: .swift), content: "print(1)")
        XCTAssertEqual(artifact.title, "Hello")
        XCTAssertEqual(artifact.type, .code(language: .swift))
        XCTAssertEqual(artifact.content, "print(1)")
        XCTAssertNil(artifact.description)
        XCTAssertTrue(artifact.tags.isEmpty)
        XCTAssertNil(artifact.conversationId)
        XCTAssertEqual(artifact.version, 1)
        XCTAssertNil(artifact.contentPath)
    }

    func testArtifactCreationFullFields() {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let fixedID = UUID()
        let artifact = TDArtifact(
            id: fixedID,
            title: "My Doc",
            type: .document(format: .markdown),
            content: "# Hello",
            description: "A test document",
            tags: ["doc", "test"],
            conversationId: "conv-123",
            createdAt: fixedDate,
            modifiedAt: fixedDate,
            version: 3,
            contentPath: "/tmp/test.md"
        )
        XCTAssertEqual(artifact.id, fixedID)
        XCTAssertEqual(artifact.title, "My Doc")
        XCTAssertEqual(artifact.type, .document(format: .markdown))
        XCTAssertEqual(artifact.content, "# Hello")
        XCTAssertEqual(artifact.description, "A test document")
        XCTAssertEqual(artifact.tags, ["doc", "test"])
        XCTAssertEqual(artifact.conversationId, "conv-123")
        XCTAssertEqual(artifact.createdAt, fixedDate)
        XCTAssertEqual(artifact.modifiedAt, fixedDate)
        XCTAssertEqual(artifact.version, 3)
        XCTAssertEqual(artifact.contentPath, "/tmp/test.md")
    }

    func testArtifactCodableRoundtrip() throws {
        let artifact = TDArtifact(
            title: "Test",
            type: .data(format: .json),
            content: "{\"key\":\"value\"}",
            tags: ["a", "b"]
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(artifact)
        let decoded = try decoder.decode(TDArtifact.self, from: data)
        XCTAssertEqual(decoded.id, artifact.id)
        XCTAssertEqual(decoded.title, artifact.title)
        XCTAssertEqual(decoded.type, artifact.type)
        XCTAssertEqual(decoded.content, artifact.content)
        XCTAssertEqual(decoded.tags, artifact.tags)
        XCTAssertEqual(decoded.version, artifact.version)
    }

    func testArtifactMutability() {
        var artifact = TDArtifact(title: "Old", type: .interactive, content: "<html>")
        artifact.title = "New"
        artifact.content = "<body>updated</body>"
        artifact.description = "Updated desc"
        artifact.tags = ["updated"]
        artifact.version = 2
        XCTAssertEqual(artifact.title, "New")
        XCTAssertEqual(artifact.content, "<body>updated</body>")
        XCTAssertEqual(artifact.description, "Updated desc")
        XCTAssertEqual(artifact.tags, ["updated"])
        XCTAssertEqual(artifact.version, 2)
    }

    // MARK: - ArtifactError

    func testArtifactErrorDescriptions() {
        XCTAssertEqual(TDArtifactError.notFound.errorDescription, "Artifact not found")
        XCTAssertEqual(TDArtifactError.invalidContent.errorDescription, "Invalid artifact content")
        XCTAssertEqual(TDArtifactError.saveFailed("disk full").errorDescription,
                       "Failed to save artifact: disk full")
        XCTAssertEqual(TDArtifactError.exportFailed("no permission").errorDescription,
                       "Failed to export artifact: no permission")
    }

    func testArtifactErrorConformsToError() {
        let error: Error = TDArtifactError.notFound
        XCTAssertNotNil(error.localizedDescription)
    }
}
