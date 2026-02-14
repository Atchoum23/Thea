// ArtifactAndPermissionsTypesTests.swift
// Tests for standalone test doubles mirroring:
//   - Shared/Core/ArtifactManagerTypes.swift (Artifact, ArtifactType, CodeLanguage,
//     DocumentFormat, VisualizationType, DataFormat, ArtifactError)
//   - Shared/Core/Managers/PermissionsTypes.swift (PermissionStatus, PermissionCategory,
//     PermissionType, PermissionInfo)

import Foundation
import XCTest

final class ArtifactAndPermissionsTypesTests: XCTestCase {

    // =========================================================================
    // MARK: - Test Doubles — Artifact Types
    // =========================================================================

    enum CodeLanguage: String, Codable, Sendable, CaseIterable {
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

    enum DocumentFormat: String, Codable, Sendable, CaseIterable {
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

    enum VisualizationType: String, Codable, Sendable, CaseIterable {
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

    enum DataFormat: String, Codable, Sendable, CaseIterable {
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

    enum ArtifactType: Codable, Sendable, Hashable {
        case code(language: CodeLanguage)
        case document(format: DocumentFormat)
        case visualization(type: VisualizationType)
        case interactive
        case data(format: DataFormat)

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
            guard let category = parts.first else { return nil }
            switch category {
            case "code":
                guard parts.count > 1,
                      let language = CodeLanguage(rawValue: String(parts[1])) else { return nil }
                self = .code(language: language)
            case "document":
                guard parts.count > 1,
                      let format = DocumentFormat(rawValue: String(parts[1])) else { return nil }
                self = .document(format: format)
            case "visualization":
                guard parts.count > 1,
                      let type = VisualizationType(rawValue: String(parts[1])) else { return nil }
                self = .visualization(type: type)
            case "interactive":
                self = .interactive
            case "data":
                guard parts.count > 1,
                      let format = DataFormat(rawValue: String(parts[1])) else { return nil }
                self = .data(format: format)
            default:
                return nil
            }
        }
    }

    struct Artifact: Identifiable, Codable, Sendable {
        let id: UUID
        var title: String
        let type: ArtifactType
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
            type: ArtifactType,
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

    enum ArtifactError: Error, LocalizedError, Sendable {
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

    // =========================================================================
    // MARK: - Test Doubles — Permission Types
    // =========================================================================

    enum PermissionStatus: String, Codable, Sendable, CaseIterable {
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

    enum PermissionCategory: String, CaseIterable, Sendable {
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

    enum PermissionType: String, CaseIterable, Sendable {
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

        var category: PermissionCategory {
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

    struct PermissionInfo: Sendable {
        let id: String
        let type: PermissionType
        var status: PermissionStatus
        let category: PermissionCategory
        let permDescription: String

        var canRequest: Bool {
            status == .notDetermined && type.canRequestProgrammatically
        }

        var canOpenSettings: Bool {
            status == .denied || status == .restricted || status == .unknown
        }

        init(type: PermissionType, status: PermissionStatus) {
            self.id = type.rawValue
            self.type = type
            self.status = status
            self.category = type.category
            self.permDescription = type.rawValue
        }
    }

    // =========================================================================
    // MARK: - CodeLanguage Tests
    // =========================================================================

    func testCodeLanguageAllCasesCount() {
        XCTAssertEqual(CodeLanguage.allCases.count, 20)
    }

    func testCodeLanguageUniqueRawValues() {
        let rawValues = CodeLanguage.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count, "CodeLanguage raw values must be unique")
    }

    func testCodeLanguageRawValues() {
        XCTAssertEqual(CodeLanguage.swift.rawValue, "swift")
        XCTAssertEqual(CodeLanguage.python.rawValue, "python")
        XCTAssertEqual(CodeLanguage.javascript.rawValue, "javascript")
        XCTAssertEqual(CodeLanguage.typescript.rawValue, "typescript")
        XCTAssertEqual(CodeLanguage.java.rawValue, "java")
        XCTAssertEqual(CodeLanguage.kotlin.rawValue, "kotlin")
        XCTAssertEqual(CodeLanguage.rust.rawValue, "rust")
        XCTAssertEqual(CodeLanguage.go.rawValue, "go")
        XCTAssertEqual(CodeLanguage.cpp.rawValue, "cpp")
        XCTAssertEqual(CodeLanguage.csharp.rawValue, "csharp")
        XCTAssertEqual(CodeLanguage.html.rawValue, "html")
        XCTAssertEqual(CodeLanguage.css.rawValue, "css")
        XCTAssertEqual(CodeLanguage.sql.rawValue, "sql")
        XCTAssertEqual(CodeLanguage.bash.rawValue, "bash")
        XCTAssertEqual(CodeLanguage.ruby.rawValue, "ruby")
        XCTAssertEqual(CodeLanguage.php.rawValue, "php")
        XCTAssertEqual(CodeLanguage.scala.rawValue, "scala")
        XCTAssertEqual(CodeLanguage.haskell.rawValue, "haskell")
        XCTAssertEqual(CodeLanguage.elixir.rawValue, "elixir")
        XCTAssertEqual(CodeLanguage.clojure.rawValue, "clojure")
    }

    func testCodeLanguageDisplayNames() {
        XCTAssertEqual(CodeLanguage.swift.displayName, "Swift")
        XCTAssertEqual(CodeLanguage.cpp.displayName, "C++")
        XCTAssertEqual(CodeLanguage.csharp.displayName, "C#")
        XCTAssertEqual(CodeLanguage.javascript.displayName, "JavaScript")
        XCTAssertEqual(CodeLanguage.typescript.displayName, "TypeScript")
        XCTAssertEqual(CodeLanguage.go.displayName, "Go")
    }

    func testCodeLanguageFileExtensions() {
        XCTAssertEqual(CodeLanguage.swift.fileExtension, "swift")
        XCTAssertEqual(CodeLanguage.python.fileExtension, "py")
        XCTAssertEqual(CodeLanguage.javascript.fileExtension, "js")
        XCTAssertEqual(CodeLanguage.typescript.fileExtension, "ts")
        XCTAssertEqual(CodeLanguage.kotlin.fileExtension, "kt")
        XCTAssertEqual(CodeLanguage.rust.fileExtension, "rs")
        XCTAssertEqual(CodeLanguage.cpp.fileExtension, "cpp")
        XCTAssertEqual(CodeLanguage.csharp.fileExtension, "cs")
        XCTAssertEqual(CodeLanguage.bash.fileExtension, "sh")
        XCTAssertEqual(CodeLanguage.ruby.fileExtension, "rb")
        XCTAssertEqual(CodeLanguage.haskell.fileExtension, "hs")
        XCTAssertEqual(CodeLanguage.elixir.fileExtension, "ex")
        XCTAssertEqual(CodeLanguage.clojure.fileExtension, "clj")
    }

    func testCodeLanguageCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for lang in CodeLanguage.allCases {
            let data = try encoder.encode(lang)
            let decoded = try decoder.decode(CodeLanguage.self, from: data)
            XCTAssertEqual(decoded, lang, "\(lang) should survive Codable roundtrip")
        }
    }

    func testCodeLanguageInitFromRawValue() {
        for lang in CodeLanguage.allCases {
            XCTAssertEqual(CodeLanguage(rawValue: lang.rawValue), lang)
        }
        XCTAssertNil(CodeLanguage(rawValue: "brainfuck"))
        XCTAssertNil(CodeLanguage(rawValue: ""))
    }

    // =========================================================================
    // MARK: - DocumentFormat Tests
    // =========================================================================

    func testDocumentFormatAllCasesCount() {
        XCTAssertEqual(DocumentFormat.allCases.count, 5)
    }

    func testDocumentFormatDisplayNames() {
        XCTAssertEqual(DocumentFormat.markdown.displayName, "Markdown")
        XCTAssertEqual(DocumentFormat.plainText.displayName, "Plain Text")
        XCTAssertEqual(DocumentFormat.html.displayName, "HTML")
        XCTAssertEqual(DocumentFormat.latex.displayName, "LaTeX")
        XCTAssertEqual(DocumentFormat.rst.displayName, "reStructuredText")
    }

    func testDocumentFormatFileExtensions() {
        XCTAssertEqual(DocumentFormat.markdown.fileExtension, "md")
        XCTAssertEqual(DocumentFormat.plainText.fileExtension, "txt")
        XCTAssertEqual(DocumentFormat.html.fileExtension, "html")
        XCTAssertEqual(DocumentFormat.latex.fileExtension, "tex")
        XCTAssertEqual(DocumentFormat.rst.fileExtension, "rst")
    }

    func testDocumentFormatCodableRoundtrip() throws {
        for fmt in DocumentFormat.allCases {
            let data = try JSONEncoder().encode(fmt)
            let decoded = try JSONDecoder().decode(DocumentFormat.self, from: data)
            XCTAssertEqual(decoded, fmt)
        }
    }

    // =========================================================================
    // MARK: - VisualizationType Tests
    // =========================================================================

    func testVisualizationTypeAllCasesCount() {
        XCTAssertEqual(VisualizationType.allCases.count, 5)
    }

    func testVisualizationTypeDisplayNames() {
        XCTAssertEqual(VisualizationType.svg.displayName, "SVG")
        XCTAssertEqual(VisualizationType.chart.displayName, "Chart")
        XCTAssertEqual(VisualizationType.diagram.displayName, "Diagram")
        XCTAssertEqual(VisualizationType.flowchart.displayName, "Flowchart")
        XCTAssertEqual(VisualizationType.mindmap.displayName, "Mind Map")
    }

    func testVisualizationTypeCodableRoundtrip() throws {
        for viz in VisualizationType.allCases {
            let data = try JSONEncoder().encode(viz)
            let decoded = try JSONDecoder().decode(VisualizationType.self, from: data)
            XCTAssertEqual(decoded, viz)
        }
    }

    func testVisualizationTypeUniqueRawValues() {
        let rawValues = VisualizationType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    // =========================================================================
    // MARK: - DataFormat Tests
    // =========================================================================

    func testDataFormatAllCasesCount() {
        XCTAssertEqual(DataFormat.allCases.count, 5)
    }

    func testDataFormatDisplayNames() {
        XCTAssertEqual(DataFormat.json.displayName, "JSON")
        XCTAssertEqual(DataFormat.csv.displayName, "CSV")
        XCTAssertEqual(DataFormat.yaml.displayName, "YAML")
        XCTAssertEqual(DataFormat.xml.displayName, "XML")
        XCTAssertEqual(DataFormat.toml.displayName, "TOML")
    }

    func testDataFormatFileExtensionEqualsRawValue() {
        for fmt in DataFormat.allCases {
            XCTAssertEqual(fmt.fileExtension, fmt.rawValue,
                           "DataFormat.\(fmt) fileExtension should equal rawValue")
        }
    }

    func testDataFormatCodableRoundtrip() throws {
        for fmt in DataFormat.allCases {
            let data = try JSONEncoder().encode(fmt)
            let decoded = try JSONDecoder().decode(DataFormat.self, from: data)
            XCTAssertEqual(decoded, fmt)
        }
    }

    // =========================================================================
    // MARK: - ArtifactType Tests
    // =========================================================================

    func testArtifactTypeCategories() {
        XCTAssertEqual(ArtifactType.code(language: .swift).category, "code")
        XCTAssertEqual(ArtifactType.document(format: .markdown).category, "document")
        XCTAssertEqual(ArtifactType.visualization(type: .chart).category, "visualization")
        XCTAssertEqual(ArtifactType.interactive.category, "interactive")
        XCTAssertEqual(ArtifactType.data(format: .json).category, "data")
    }

    func testArtifactTypeDisplayNames() {
        XCTAssertEqual(ArtifactType.code(language: .python).displayName, "Code (Python)")
        XCTAssertEqual(ArtifactType.document(format: .latex).displayName, "Document (LaTeX)")
        XCTAssertEqual(ArtifactType.visualization(type: .mindmap).displayName, "Visualization (Mind Map)")
        XCTAssertEqual(ArtifactType.interactive.displayName, "Interactive")
        XCTAssertEqual(ArtifactType.data(format: .csv).displayName, "Data (CSV)")
    }

    func testArtifactTypeFileExtensions() {
        XCTAssertEqual(ArtifactType.code(language: .rust).fileExtension, "rs")
        XCTAssertEqual(ArtifactType.document(format: .markdown).fileExtension, "md")
        XCTAssertEqual(ArtifactType.visualization(type: .svg).fileExtension, "svg")
        XCTAssertEqual(ArtifactType.visualization(type: .flowchart).fileExtension, "svg")
        XCTAssertEqual(ArtifactType.interactive.fileExtension, "html")
        XCTAssertEqual(ArtifactType.data(format: .yaml).fileExtension, "yaml")
    }

    func testArtifactTypeRawValueRoundtrip() {
        let cases: [ArtifactType] = [
            .code(language: .swift),
            .code(language: .clojure),
            .document(format: .html),
            .document(format: .rst),
            .visualization(type: .diagram),
            .interactive,
            .data(format: .toml),
        ]
        for type in cases {
            let raw = type.rawValue
            let restored = ArtifactType(rawValue: raw)
            XCTAssertNotNil(restored, "Should parse rawValue '\(raw)'")
            XCTAssertEqual(restored, type, "'\(raw)' should roundtrip to same value")
        }
    }

    func testArtifactTypeRawValueInvalid() {
        XCTAssertNil(ArtifactType(rawValue: ""))
        XCTAssertNil(ArtifactType(rawValue: "unknown"))
        XCTAssertNil(ArtifactType(rawValue: "code:"))
        XCTAssertNil(ArtifactType(rawValue: "code:brainfuck"))
        XCTAssertNil(ArtifactType(rawValue: "document:pdf"))
        XCTAssertNil(ArtifactType(rawValue: "data:sqlite"))
    }

    func testArtifactTypeCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let cases: [ArtifactType] = [
            .code(language: .typescript),
            .document(format: .plainText),
            .visualization(type: .chart),
            .interactive,
            .data(format: .xml),
        ]
        for type in cases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(ArtifactType.self, from: data)
            XCTAssertEqual(decoded, type, "\(type) should survive Codable roundtrip")
        }
    }

    func testArtifactTypeHashable() {
        var set = Set<ArtifactType>()
        set.insert(.code(language: .swift))
        set.insert(.code(language: .swift))
        set.insert(.code(language: .python))
        set.insert(.interactive)
        set.insert(.interactive)
        XCTAssertEqual(set.count, 3, "Set should deduplicate equal ArtifactType values")
    }

    // =========================================================================
    // MARK: - Artifact Struct Tests
    // =========================================================================

    func testArtifactCreationDefaults() {
        let artifact = Artifact(title: "Hello", type: .code(language: .swift), content: "print(1)")
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
        let artifact = Artifact(
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
        let artifact = Artifact(
            title: "Test",
            type: .data(format: .json),
            content: "{\"key\":\"value\"}",
            tags: ["a", "b"]
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(artifact)
        let decoded = try decoder.decode(Artifact.self, from: data)
        XCTAssertEqual(decoded.id, artifact.id)
        XCTAssertEqual(decoded.title, artifact.title)
        XCTAssertEqual(decoded.type, artifact.type)
        XCTAssertEqual(decoded.content, artifact.content)
        XCTAssertEqual(decoded.tags, artifact.tags)
        XCTAssertEqual(decoded.version, artifact.version)
    }

    func testArtifactMutability() {
        var artifact = Artifact(title: "Old", type: .interactive, content: "<html>")
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

    // =========================================================================
    // MARK: - ArtifactError Tests
    // =========================================================================

    func testArtifactErrorDescriptions() {
        XCTAssertEqual(ArtifactError.notFound.errorDescription, "Artifact not found")
        XCTAssertEqual(ArtifactError.invalidContent.errorDescription, "Invalid artifact content")
        XCTAssertEqual(ArtifactError.saveFailed("disk full").errorDescription,
                       "Failed to save artifact: disk full")
        XCTAssertEqual(ArtifactError.exportFailed("no permission").errorDescription,
                       "Failed to export artifact: no permission")
    }

    func testArtifactErrorConformsToError() {
        let error: Error = ArtifactError.notFound
        XCTAssertNotNil(error.localizedDescription)
    }

    // =========================================================================
    // MARK: - PermissionStatus Tests
    // =========================================================================

    func testPermissionStatusAllCasesCount() {
        XCTAssertEqual(PermissionStatus.allCases.count, 8)
    }

    func testPermissionStatusRawValues() {
        XCTAssertEqual(PermissionStatus.notDetermined.rawValue, "Not Set")
        XCTAssertEqual(PermissionStatus.authorized.rawValue, "Authorized")
        XCTAssertEqual(PermissionStatus.denied.rawValue, "Denied")
        XCTAssertEqual(PermissionStatus.restricted.rawValue, "Restricted")
        XCTAssertEqual(PermissionStatus.limited.rawValue, "Limited")
        XCTAssertEqual(PermissionStatus.provisional.rawValue, "Provisional")
        XCTAssertEqual(PermissionStatus.notAvailable.rawValue, "Not Available")
        XCTAssertEqual(PermissionStatus.unknown.rawValue, "Unknown")
    }

    func testPermissionStatusUniqueRawValues() {
        let rawValues = PermissionStatus.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count, "PermissionStatus raw values must be unique")
    }

    func testPermissionStatusIcons() {
        XCTAssertEqual(PermissionStatus.notDetermined.icon, "questionmark.circle")
        XCTAssertEqual(PermissionStatus.authorized.icon, "checkmark.circle.fill")
        XCTAssertEqual(PermissionStatus.denied.icon, "xmark.circle.fill")
        XCTAssertEqual(PermissionStatus.restricted.icon, "lock.circle.fill")
        XCTAssertEqual(PermissionStatus.limited.icon, "circle.lefthalf.filled")
        XCTAssertEqual(PermissionStatus.provisional.icon, "clock.circle")
        XCTAssertEqual(PermissionStatus.notAvailable.icon, "minus.circle")
        XCTAssertEqual(PermissionStatus.unknown.icon, "questionmark.circle")
    }

    func testPermissionStatusColors() {
        XCTAssertEqual(PermissionStatus.notDetermined.color, "gray")
        XCTAssertEqual(PermissionStatus.authorized.color, "green")
        XCTAssertEqual(PermissionStatus.denied.color, "red")
        XCTAssertEqual(PermissionStatus.restricted.color, "orange")
        XCTAssertEqual(PermissionStatus.limited.color, "yellow")
        XCTAssertEqual(PermissionStatus.provisional.color, "blue")
        XCTAssertEqual(PermissionStatus.notAvailable.color, "gray")
        XCTAssertEqual(PermissionStatus.unknown.color, "gray")
    }

    func testPermissionStatusCanRequest() {
        XCTAssertTrue(PermissionStatus.notDetermined.canRequest)
        XCTAssertFalse(PermissionStatus.authorized.canRequest)
        XCTAssertFalse(PermissionStatus.denied.canRequest)
        XCTAssertFalse(PermissionStatus.restricted.canRequest)
        XCTAssertFalse(PermissionStatus.limited.canRequest)
        XCTAssertFalse(PermissionStatus.provisional.canRequest)
        XCTAssertFalse(PermissionStatus.notAvailable.canRequest)
        XCTAssertFalse(PermissionStatus.unknown.canRequest)
    }

    func testPermissionStatusCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for status in PermissionStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(PermissionStatus.self, from: data)
            XCTAssertEqual(decoded, status, "\(status) should survive Codable roundtrip")
        }
    }

    // =========================================================================
    // MARK: - PermissionCategory Tests
    // =========================================================================

    func testPermissionCategoryAllCasesCount() {
        XCTAssertEqual(PermissionCategory.allCases.count, 2)
    }

    func testPermissionCategoryRawValues() {
        XCTAssertEqual(PermissionCategory.dataPrivacy.rawValue, "Data & Privacy")
        XCTAssertEqual(PermissionCategory.securityAccess.rawValue, "Security & Access")
    }

    func testPermissionCategoryIdEqualsRawValue() {
        for cat in PermissionCategory.allCases {
            XCTAssertEqual(cat.id, cat.rawValue)
        }
    }

    func testPermissionCategoryIcons() {
        XCTAssertEqual(PermissionCategory.dataPrivacy.icon, "lock.shield.fill")
        XCTAssertEqual(PermissionCategory.securityAccess.icon, "gearshape.fill")
    }

    // =========================================================================
    // MARK: - PermissionType Tests
    // =========================================================================

    func testPermissionTypeAllCasesCount() {
        XCTAssertEqual(PermissionType.allCases.count, 32)
    }

    func testPermissionTypeUniqueRawValues() {
        let rawValues = PermissionType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count, "PermissionType raw values must be unique")
    }

    func testPermissionTypeDataPrivacyCategoryMapping() {
        let dataPrivacyTypes: [PermissionType] = [
            .calendars, .contacts, .fullDiskAccess, .homeKit,
            .mediaLibrary, .passkeys, .photoLibrary, .reminders, .notes,
            .healthRead, .healthWrite, .photoLibraryAddOnly,
        ]
        for type in dataPrivacyTypes {
            XCTAssertEqual(type.category, .dataPrivacy,
                           "\(type) should be in dataPrivacy category")
        }
    }

    func testPermissionTypeSecurityAccessCategoryMapping() {
        let securityTypes: [PermissionType] = [
            .accessibility, .appManagement, .automation, .bluetooth,
            .camera, .developerTools, .focusStatus, .inputMonitoring,
            .localNetwork, .microphone, .motionFitness, .remoteDesktop,
            .screenRecording, .speechRecognition,
            .locationWhenInUse, .locationAlways,
            .notifications, .criticalAlerts,
            .siri, .faceID,
        ]
        for type in securityTypes {
            XCTAssertEqual(type.category, .securityAccess,
                           "\(type) should be in securityAccess category")
        }
    }

    func testPermissionTypeProgrammaticallyRequestable() {
        let requestable: [PermissionType] = [
            .camera, .microphone, .photoLibrary, .photoLibraryAddOnly,
            .contacts, .calendars, .reminders, .notifications, .criticalAlerts,
            .speechRecognition, .locationWhenInUse, .locationAlways,
            .healthRead, .healthWrite, .siri, .faceID,
            .accessibility, .screenRecording,
        ]
        for type in requestable {
            XCTAssertTrue(type.canRequestProgrammatically,
                          "\(type) should be programmatically requestable")
        }
    }

    func testPermissionTypeNotProgrammaticallyRequestable() {
        let notRequestable: [PermissionType] = [
            .fullDiskAccess, .inputMonitoring, .automation, .bluetooth,
            .localNetwork, .homeKit, .appManagement, .developerTools,
            .focusStatus, .motionFitness, .remoteDesktop, .passkeys,
            .mediaLibrary, .notes,
        ]
        for type in notRequestable {
            XCTAssertFalse(type.canRequestProgrammatically,
                           "\(type) should NOT be programmatically requestable")
        }
    }

    func testPermissionTypeIdEqualsRawValue() {
        for type in PermissionType.allCases {
            XCTAssertEqual(type.id, type.rawValue)
        }
    }

    // =========================================================================
    // MARK: - PermissionInfo Tests
    // =========================================================================

    func testPermissionInfoCreation() {
        let info = PermissionInfo(type: .camera, status: .notDetermined)
        XCTAssertEqual(info.id, "Camera")
        XCTAssertEqual(info.type, .camera)
        XCTAssertEqual(info.status, .notDetermined)
        XCTAssertEqual(info.category, .securityAccess)
    }

    func testPermissionInfoCanRequestWhenNotDeterminedAndProgrammatic() {
        let info = PermissionInfo(type: .camera, status: .notDetermined)
        XCTAssertTrue(info.canRequest, "Camera + notDetermined should be requestable")
    }

    func testPermissionInfoCannotRequestWhenAuthorized() {
        let info = PermissionInfo(type: .camera, status: .authorized)
        XCTAssertFalse(info.canRequest, "Already authorized should not be requestable")
    }

    func testPermissionInfoCannotRequestWhenNotProgrammatic() {
        let info = PermissionInfo(type: .fullDiskAccess, status: .notDetermined)
        XCTAssertFalse(info.canRequest,
                       "fullDiskAccess is not programmatically requestable even when notDetermined")
    }

    func testPermissionInfoCanOpenSettingsWhenDenied() {
        let info = PermissionInfo(type: .microphone, status: .denied)
        XCTAssertTrue(info.canOpenSettings)
    }

    func testPermissionInfoCanOpenSettingsWhenRestricted() {
        let info = PermissionInfo(type: .contacts, status: .restricted)
        XCTAssertTrue(info.canOpenSettings)
    }

    func testPermissionInfoCanOpenSettingsWhenUnknown() {
        let info = PermissionInfo(type: .bluetooth, status: .unknown)
        XCTAssertTrue(info.canOpenSettings)
    }

    func testPermissionInfoCannotOpenSettingsWhenAuthorized() {
        let info = PermissionInfo(type: .camera, status: .authorized)
        XCTAssertFalse(info.canOpenSettings)
    }

    func testPermissionInfoCannotOpenSettingsWhenNotDetermined() {
        let info = PermissionInfo(type: .camera, status: .notDetermined)
        XCTAssertFalse(info.canOpenSettings)
    }

    func testPermissionInfoCategoryInheritsFromType() {
        let dataInfo = PermissionInfo(type: .contacts, status: .authorized)
        XCTAssertEqual(dataInfo.category, .dataPrivacy)

        let secInfo = PermissionInfo(type: .camera, status: .authorized)
        XCTAssertEqual(secInfo.category, .securityAccess)
    }
}
