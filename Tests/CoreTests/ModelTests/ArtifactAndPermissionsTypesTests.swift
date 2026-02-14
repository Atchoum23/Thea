// ArtifactAndPermissionsTypesTests.swift
// Tests for standalone test doubles mirroring:
//   - Shared/Core/ArtifactManagerTypes.swift (Artifact, ArtifactType, CodeLanguage,
//     DocumentFormat, VisualizationType, DataFormat, ArtifactError)
//   - Shared/Core/Managers/PermissionsTypes.swift (PermissionStatus, PermissionCategory,
//     PermissionType, PermissionInfo)
//
// Split into two test classes to stay under SwiftLint type_body_length.

import Foundation
import XCTest

// MARK: - Shared Test Doubles — Artifact Types

private enum TDCodeLanguage: String, Codable, Sendable, CaseIterable {
    case swift, python, javascript, typescript, java, kotlin, rust, go, cpp, csharp
    case html, css, sql, bash, ruby, php, scala, haskell, elixir, clojure

    var displayName: String {
        switch self {
        case .swift: "Swift"
        case .python: "Python"
        case .javascript: "JavaScript"
        case .typescript: "TypeScript"
        case .java: "Java"
        case .kotlin: "Kotlin"
        case .rust: "Rust"
        case .go: "Go"
        case .cpp: "C++"
        case .csharp: "C#"
        case .html: "HTML"
        case .css: "CSS"
        case .sql: "SQL"
        case .bash: "Bash"
        case .ruby: "Ruby"
        case .php: "PHP"
        case .scala: "Scala"
        case .haskell: "Haskell"
        case .elixir: "Elixir"
        case .clojure: "Clojure"
        }
    }

    var fileExtension: String {
        switch self {
        case .swift: "swift"
        case .python: "py"
        case .javascript: "js"
        case .typescript: "ts"
        case .java: "java"
        case .kotlin: "kt"
        case .rust: "rs"
        case .go: "go"
        case .cpp: "cpp"
        case .csharp: "cs"
        case .html: "html"
        case .css: "css"
        case .sql: "sql"
        case .bash: "sh"
        case .ruby: "rb"
        case .php: "php"
        case .scala: "scala"
        case .haskell: "hs"
        case .elixir: "ex"
        case .clojure: "clj"
        }
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

// MARK: - Shared Test Doubles — Permission Types

private enum TDPermissionStatus: String, Codable, Sendable, CaseIterable {
    case notDetermined = "Not Set"
    case authorized = "Authorized"
    case denied = "Denied"
    case restricted = "Restricted"
    case limited = "Limited"
    case provisional = "Provisional"
    case notAvailable = "Not Available"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .notDetermined: "questionmark.circle"
        case .authorized: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .restricted: "lock.circle.fill"
        case .limited: "circle.lefthalf.filled"
        case .provisional: "clock.circle"
        case .notAvailable: "minus.circle"
        case .unknown: "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .notDetermined: "gray"
        case .authorized: "green"
        case .denied: "red"
        case .restricted: "orange"
        case .limited: "yellow"
        case .provisional: "blue"
        case .notAvailable: "gray"
        case .unknown: "gray"
        }
    }

    var canRequest: Bool { self == .notDetermined }
}

private enum TDPermissionCategory: String, CaseIterable, Sendable {
    case dataPrivacy = "Data & Privacy"
    case securityAccess = "Security & Access"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dataPrivacy: "lock.shield.fill"
        case .securityAccess: "gearshape.fill"
        }
    }
}

// swiftlint:disable type_body_length
private enum TDPermissionType: String, CaseIterable, Sendable {
    // Data & Privacy
    case calendars = "Calendars"
    case contacts = "Contacts"
    case fullDiskAccess = "Full Disk Access"
    case homeKit = "Home"
    case mediaLibrary = "Media & Apple Music"
    case passkeys = "Passkeys Access for Web Browsers"
    case photoLibrary = "Photos"
    case reminders = "Reminders"
    case notes = "Notes"
    // Security & Access
    case accessibility = "Accessibility"
    case appManagement = "App Management"
    case automation = "Automation"
    case bluetooth = "Bluetooth"
    case camera = "Camera"
    case developerTools = "Developer Tools"
    case focusStatus = "Focus"
    case inputMonitoring = "Input Monitoring"
    case localNetwork = "Local Network"
    case microphone = "Microphone"
    case motionFitness = "Motion & Fitness"
    case remoteDesktop = "Remote Desktop"
    case screenRecording = "Screen & System Audio Recording"
    case speechRecognition = "Speech Recognition"
    // iOS-only
    case locationWhenInUse = "Location (When In Use)"
    case locationAlways = "Location (Always)"
    case notifications = "Notifications"
    case criticalAlerts = "Critical Alerts"
    case healthRead = "Health Data (Read)"
    case healthWrite = "Health Data (Write)"
    case photoLibraryAddOnly = "Photos (Add Only)"
    case siri = "Siri & Shortcuts"
    case faceID = "Face ID / Touch ID"

    var id: String { rawValue }

    var category: TDPermissionCategory {
        switch self {
        case .calendars, .contacts, .fullDiskAccess, .homeKit,
             .mediaLibrary, .passkeys, .photoLibrary, .reminders, .notes:
            return .dataPrivacy
        case .accessibility, .appManagement, .automation, .bluetooth,
             .camera, .developerTools, .focusStatus, .inputMonitoring,
             .localNetwork, .microphone, .motionFitness, .remoteDesktop,
             .screenRecording, .speechRecognition:
            return .securityAccess
        case .locationWhenInUse, .locationAlways:
            return .securityAccess
        case .notifications, .criticalAlerts:
            return .securityAccess
        case .healthRead, .healthWrite:
            return .dataPrivacy
        case .photoLibraryAddOnly:
            return .dataPrivacy
        case .siri:
            return .securityAccess
        case .faceID:
            return .securityAccess
        }
    }

    var canRequestProgrammatically: Bool {
        switch self {
        case .camera, .microphone, .photoLibrary, .photoLibraryAddOnly,
             .contacts, .calendars, .reminders, .notifications, .criticalAlerts,
             .speechRecognition, .locationWhenInUse, .locationAlways,
             .healthRead, .healthWrite, .siri, .faceID:
            return true
        case .accessibility, .screenRecording:
            return true
        case .fullDiskAccess, .inputMonitoring, .automation, .bluetooth,
             .localNetwork, .homeKit, .appManagement, .developerTools,
             .focusStatus, .motionFitness, .remoteDesktop, .passkeys,
             .mediaLibrary, .notes:
            return false
        }
    }
}
// swiftlint:enable type_body_length

private struct TDPermissionInfo: Sendable {
    let id: String
    let type: TDPermissionType
    var status: TDPermissionStatus
    let category: TDPermissionCategory

    var canRequest: Bool {
        status == .notDetermined && type.canRequestProgrammatically
    }

    var canOpenSettings: Bool {
        status == .denied || status == .restricted || status == .unknown
    }

    init(type: TDPermissionType, status: TDPermissionStatus) {
        self.id = type.rawValue
        self.type = type
        self.status = status
        self.category = type.category
    }
}

// =============================================================================
// MARK: - ArtifactTypesTests (34 tests)
// =============================================================================

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

// =============================================================================
// MARK: - PermissionsTypesTests (26 tests)
// =============================================================================

final class PermissionsTypesTests: XCTestCase {

    // MARK: - PermissionStatus

    func testPermissionStatusAllCasesCount() {
        XCTAssertEqual(TDPermissionStatus.allCases.count, 8)
    }

    func testPermissionStatusRawValues() {
        XCTAssertEqual(TDPermissionStatus.notDetermined.rawValue, "Not Set")
        XCTAssertEqual(TDPermissionStatus.authorized.rawValue, "Authorized")
        XCTAssertEqual(TDPermissionStatus.denied.rawValue, "Denied")
        XCTAssertEqual(TDPermissionStatus.restricted.rawValue, "Restricted")
        XCTAssertEqual(TDPermissionStatus.limited.rawValue, "Limited")
        XCTAssertEqual(TDPermissionStatus.provisional.rawValue, "Provisional")
        XCTAssertEqual(TDPermissionStatus.notAvailable.rawValue, "Not Available")
        XCTAssertEqual(TDPermissionStatus.unknown.rawValue, "Unknown")
    }

    func testPermissionStatusUniqueRawValues() {
        let rawValues = TDPermissionStatus.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count,
                       "PermissionStatus raw values must be unique")
    }

    func testPermissionStatusIcons() {
        XCTAssertEqual(TDPermissionStatus.notDetermined.icon, "questionmark.circle")
        XCTAssertEqual(TDPermissionStatus.authorized.icon, "checkmark.circle.fill")
        XCTAssertEqual(TDPermissionStatus.denied.icon, "xmark.circle.fill")
        XCTAssertEqual(TDPermissionStatus.restricted.icon, "lock.circle.fill")
        XCTAssertEqual(TDPermissionStatus.limited.icon, "circle.lefthalf.filled")
        XCTAssertEqual(TDPermissionStatus.provisional.icon, "clock.circle")
        XCTAssertEqual(TDPermissionStatus.notAvailable.icon, "minus.circle")
        XCTAssertEqual(TDPermissionStatus.unknown.icon, "questionmark.circle")
    }

    func testPermissionStatusColors() {
        XCTAssertEqual(TDPermissionStatus.notDetermined.color, "gray")
        XCTAssertEqual(TDPermissionStatus.authorized.color, "green")
        XCTAssertEqual(TDPermissionStatus.denied.color, "red")
        XCTAssertEqual(TDPermissionStatus.restricted.color, "orange")
        XCTAssertEqual(TDPermissionStatus.limited.color, "yellow")
        XCTAssertEqual(TDPermissionStatus.provisional.color, "blue")
        XCTAssertEqual(TDPermissionStatus.notAvailable.color, "gray")
        XCTAssertEqual(TDPermissionStatus.unknown.color, "gray")
    }

    func testPermissionStatusCanRequest() {
        XCTAssertTrue(TDPermissionStatus.notDetermined.canRequest)
        XCTAssertFalse(TDPermissionStatus.authorized.canRequest)
        XCTAssertFalse(TDPermissionStatus.denied.canRequest)
        XCTAssertFalse(TDPermissionStatus.restricted.canRequest)
        XCTAssertFalse(TDPermissionStatus.limited.canRequest)
        XCTAssertFalse(TDPermissionStatus.provisional.canRequest)
        XCTAssertFalse(TDPermissionStatus.notAvailable.canRequest)
        XCTAssertFalse(TDPermissionStatus.unknown.canRequest)
    }

    func testPermissionStatusCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for status in TDPermissionStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(TDPermissionStatus.self, from: data)
            XCTAssertEqual(decoded, status, "\(status) should survive Codable roundtrip")
        }
    }

    // MARK: - PermissionCategory

    func testPermissionCategoryAllCasesCount() {
        XCTAssertEqual(TDPermissionCategory.allCases.count, 2)
    }

    func testPermissionCategoryRawValues() {
        XCTAssertEqual(TDPermissionCategory.dataPrivacy.rawValue, "Data & Privacy")
        XCTAssertEqual(TDPermissionCategory.securityAccess.rawValue, "Security & Access")
    }

    func testPermissionCategoryIdEqualsRawValue() {
        for cat in TDPermissionCategory.allCases {
            XCTAssertEqual(cat.id, cat.rawValue)
        }
    }

    func testPermissionCategoryIcons() {
        XCTAssertEqual(TDPermissionCategory.dataPrivacy.icon, "lock.shield.fill")
        XCTAssertEqual(TDPermissionCategory.securityAccess.icon, "gearshape.fill")
    }

    // MARK: - PermissionType

    func testPermissionTypeAllCasesCount() {
        XCTAssertEqual(TDPermissionType.allCases.count, 32)
    }

    func testPermissionTypeUniqueRawValues() {
        let rawValues = TDPermissionType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count,
                       "PermissionType raw values must be unique")
    }

    func testPermissionTypeDataPrivacyCategoryMapping() {
        let dataPrivacyTypes: [TDPermissionType] = [
            .calendars, .contacts, .fullDiskAccess, .homeKit,
            .mediaLibrary, .passkeys, .photoLibrary, .reminders, .notes,
            .healthRead, .healthWrite, .photoLibraryAddOnly
        ]
        for permType in dataPrivacyTypes {
            XCTAssertEqual(permType.category, .dataPrivacy,
                           "\(permType) should be in dataPrivacy category")
        }
    }

    func testPermissionTypeSecurityAccessCategoryMapping() {
        let securityTypes: [TDPermissionType] = [
            .accessibility, .appManagement, .automation, .bluetooth,
            .camera, .developerTools, .focusStatus, .inputMonitoring,
            .localNetwork, .microphone, .motionFitness, .remoteDesktop,
            .screenRecording, .speechRecognition,
            .locationWhenInUse, .locationAlways,
            .notifications, .criticalAlerts,
            .siri, .faceID
        ]
        for permType in securityTypes {
            XCTAssertEqual(permType.category, .securityAccess,
                           "\(permType) should be in securityAccess category")
        }
    }

    func testPermissionTypeProgrammaticallyRequestable() {
        let requestable: [TDPermissionType] = [
            .camera, .microphone, .photoLibrary, .photoLibraryAddOnly,
            .contacts, .calendars, .reminders, .notifications, .criticalAlerts,
            .speechRecognition, .locationWhenInUse, .locationAlways,
            .healthRead, .healthWrite, .siri, .faceID,
            .accessibility, .screenRecording
        ]
        for permType in requestable {
            XCTAssertTrue(permType.canRequestProgrammatically,
                          "\(permType) should be programmatically requestable")
        }
    }

    func testPermissionTypeNotProgrammaticallyRequestable() {
        let notRequestable: [TDPermissionType] = [
            .fullDiskAccess, .inputMonitoring, .automation, .bluetooth,
            .localNetwork, .homeKit, .appManagement, .developerTools,
            .focusStatus, .motionFitness, .remoteDesktop, .passkeys,
            .mediaLibrary, .notes
        ]
        for permType in notRequestable {
            XCTAssertFalse(permType.canRequestProgrammatically,
                           "\(permType) should NOT be programmatically requestable")
        }
    }

    func testPermissionTypeIdEqualsRawValue() {
        for permType in TDPermissionType.allCases {
            XCTAssertEqual(permType.id, permType.rawValue)
        }
    }

    // MARK: - PermissionInfo

    func testPermissionInfoCreation() {
        let info = TDPermissionInfo(type: .camera, status: .notDetermined)
        XCTAssertEqual(info.id, "Camera")
        XCTAssertEqual(info.type, .camera)
        XCTAssertEqual(info.status, .notDetermined)
        XCTAssertEqual(info.category, .securityAccess)
    }

    func testPermissionInfoCanRequestWhenNotDeterminedAndProgrammatic() {
        let info = TDPermissionInfo(type: .camera, status: .notDetermined)
        XCTAssertTrue(info.canRequest, "Camera + notDetermined should be requestable")
    }

    func testPermissionInfoCannotRequestWhenAuthorized() {
        let info = TDPermissionInfo(type: .camera, status: .authorized)
        XCTAssertFalse(info.canRequest, "Already authorized should not be requestable")
    }

    func testPermissionInfoCannotRequestWhenNotProgrammatic() {
        let info = TDPermissionInfo(type: .fullDiskAccess, status: .notDetermined)
        XCTAssertFalse(info.canRequest,
                       "fullDiskAccess not programmatically requestable even when notDetermined")
    }

    func testPermissionInfoCanOpenSettingsWhenDenied() {
        let info = TDPermissionInfo(type: .microphone, status: .denied)
        XCTAssertTrue(info.canOpenSettings)
    }

    func testPermissionInfoCanOpenSettingsWhenRestricted() {
        let info = TDPermissionInfo(type: .contacts, status: .restricted)
        XCTAssertTrue(info.canOpenSettings)
    }

    func testPermissionInfoCanOpenSettingsWhenUnknown() {
        let info = TDPermissionInfo(type: .bluetooth, status: .unknown)
        XCTAssertTrue(info.canOpenSettings)
    }

    func testPermissionInfoCannotOpenSettingsWhenAuthorized() {
        let info = TDPermissionInfo(type: .camera, status: .authorized)
        XCTAssertFalse(info.canOpenSettings)
    }

    func testPermissionInfoCannotOpenSettingsWhenNotDetermined() {
        let info = TDPermissionInfo(type: .camera, status: .notDetermined)
        XCTAssertFalse(info.canOpenSettings)
    }

    func testPermissionInfoCategoryInheritsFromType() {
        let dataInfo = TDPermissionInfo(type: .contacts, status: .authorized)
        XCTAssertEqual(dataInfo.category, .dataPrivacy)

        let secInfo = TDPermissionInfo(type: .camera, status: .authorized)
        XCTAssertEqual(secInfo.category, .securityAccess)
    }
}
