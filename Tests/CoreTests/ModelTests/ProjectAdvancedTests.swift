@preconcurrency import SwiftData
@testable import TheaModels
import XCTest

/// Advanced tests for Project: file management, settings, parent-child relationships,
/// conversation association, and Codable types.
@MainActor
final class ProjectAdvancedTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([Conversation.self, Message.self, Project.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - ProjectFile

    func testProjectFileCreation() {
        let file = ProjectFile(
            name: "main.swift",
            path: "/src/main.swift",
            size: 2048
        )
        XCTAssertEqual(file.name, "main.swift")
        XCTAssertEqual(file.path, "/src/main.swift")
        XCTAssertEqual(file.size, 2048)
    }

    func testProjectFileUniqueIDs() {
        let f1 = ProjectFile(name: "a", path: "/a", size: 0)
        let f2 = ProjectFile(name: "b", path: "/b", size: 0)
        XCTAssertNotEqual(f1.id, f2.id)
    }

    func testProjectFileCodableRoundtrip() throws {
        let file = ProjectFile(
            name: "data.json",
            path: "/project/data.json",
            size: 1500,
            addedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(ProjectFile.self, from: data)
        XCTAssertEqual(decoded.name, file.name)
        XCTAssertEqual(decoded.path, file.path)
        XCTAssertEqual(decoded.size, file.size)
    }

    func testProjectFileZeroSize() {
        let file = ProjectFile(name: "empty", path: "/empty", size: 0)
        XCTAssertEqual(file.size, 0)
    }

    func testProjectFileLargeSize() {
        let file = ProjectFile(name: "big", path: "/big", size: Int64.max)
        XCTAssertEqual(file.size, Int64.max)
    }

    // MARK: - ProjectSettings

    func testProjectSettingsDefaults() {
        let settings = ProjectSettings()
        XCTAssertNil(settings.defaultModel)
        XCTAssertNil(settings.defaultProvider)
        XCTAssertEqual(settings.temperature, 1.0)
        XCTAssertNil(settings.maxTokens)
    }

    func testProjectSettingsCustom() {
        let settings = ProjectSettings(
            defaultModel: "claude-4",
            defaultProvider: "anthropic",
            temperature: 0.7,
            maxTokens: 4096
        )
        XCTAssertEqual(settings.defaultModel, "claude-4")
        XCTAssertEqual(settings.defaultProvider, "anthropic")
        XCTAssertEqual(settings.temperature, 0.7)
        XCTAssertEqual(settings.maxTokens, 4096)
    }

    func testProjectSettingsCodableRoundtrip() throws {
        let settings = ProjectSettings(
            defaultModel: "gpt-4o",
            temperature: 0.3,
            maxTokens: 8192
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ProjectSettings.self, from: data)
        XCTAssertEqual(decoded.defaultModel, "gpt-4o")
        XCTAssertEqual(decoded.temperature, 0.3, accuracy: 0.001)
        XCTAssertEqual(decoded.maxTokens, 8192)
    }

    func testProjectSettingsTemperatureRange() {
        // Temperature should work at boundaries
        let cold = ProjectSettings(temperature: 0.0)
        XCTAssertEqual(cold.temperature, 0.0)

        let hot = ProjectSettings(temperature: 2.0)
        XCTAssertEqual(hot.temperature, 2.0)
    }

    // MARK: - Project Defaults

    func testProjectDefaults() {
        let project = Project(title: "My Project")
        XCTAssertEqual(project.title, "My Project")
        XCTAssertEqual(project.customInstructions, "")
        XCTAssertEqual(project.projectDescription, "")
        XCTAssertEqual(project.iconName, "folder")
        XCTAssertEqual(project.colorHex, "#007AFF")
        XCTAssertNil(project.parentProjectID)
        XCTAssertTrue(project.conversations.isEmpty)
    }

    func testProjectCustomValues() {
        let parentID = UUID()
        let project = Project(
            title: "Sub-Project",
            customInstructions: "Use Swift 6",
            projectDescription: "A child project",
            iconName: "gear",
            colorHex: "#FF5733",
            parentProjectID: parentID
        )
        XCTAssertEqual(project.customInstructions, "Use Swift 6")
        XCTAssertEqual(project.projectDescription, "A child project")
        XCTAssertEqual(project.iconName, "gear")
        XCTAssertEqual(project.colorHex, "#FF5733")
        XCTAssertEqual(project.parentProjectID, parentID)
    }

    // MARK: - Parent-Child Relationships

    func testParentProjectIDTracking() {
        let parentID = UUID()
        let child = Project(title: "Child", parentProjectID: parentID)
        XCTAssertEqual(child.parentProjectID, parentID)
    }

    func testOrphanProject() {
        let project = Project(title: "Orphan")
        XCTAssertNil(project.parentProjectID)
    }

    // MARK: - Persistence

    func testProjectPersists() throws {
        let project = Project(
            title: "Persistent Project",
            customInstructions: "Test instructions",
            iconName: "star"
        )
        modelContext.insert(project)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<Project>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Persistent Project")
        XCTAssertEqual(fetched[0].customInstructions, "Test instructions")
        XCTAssertEqual(fetched[0].iconName, "star")
    }

    func testProjectWithConversation() throws {
        let project = Project(title: "Code Project")
        modelContext.insert(project)

        let conv = Conversation(title: "Chat 1", projectID: project.id)
        modelContext.insert(conv)
        project.conversations.append(conv)

        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<Project>())
        XCTAssertEqual(fetched[0].conversations.count, 1)
    }

    func testDeleteProjectNullifiesConversations() throws {
        let project = Project(title: "To Delete")
        modelContext.insert(project)

        let conv = Conversation(title: "Linked Chat")
        modelContext.insert(conv)
        project.conversations.append(conv)
        try modelContext.save()

        modelContext.delete(project)
        try modelContext.save()

        // Conversation should still exist (nullify rule)
        let conversations = try modelContext.fetch(FetchDescriptor<Conversation>())
        XCTAssertEqual(conversations.count, 1)
    }

    // MARK: - Edge Cases

    func testEmptyTitle() {
        let project = Project(title: "")
        XCTAssertEqual(project.title, "")
    }

    func testUnicodeTitle() {
        let project = Project(title: "Projet 🇫🇷 日本語")
        XCTAssertEqual(project.title, "Projet 🇫🇷 日本語")
    }

    func testVeryLongInstructions() {
        let instructions = String(repeating: "Rule\n", count: 10_000)
        let project = Project(title: "Test", customInstructions: instructions)
        XCTAssertEqual(project.customInstructions.count, instructions.count)
    }
}
