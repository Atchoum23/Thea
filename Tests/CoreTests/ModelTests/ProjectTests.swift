@preconcurrency import SwiftData
@testable import TheaModels
import XCTest

@MainActor
final class ProjectTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([Project.self, Conversation.self, Message.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        await MainActor.run {
            modelContainer = nil
            modelContext = nil
        }
    }

    // MARK: - Project Creation

    func testProjectDefaultValues() {
        let project = Project(title: "Test Project")

        XCTAssertNotNil(project.id)
        XCTAssertEqual(project.title, "Test Project")
        XCTAssertEqual(project.customInstructions, "")
        XCTAssertEqual(project.projectDescription, "")
        XCTAssertEqual(project.iconName, "folder")
        XCTAssertEqual(project.colorHex, "#007AFF")
        XCTAssertNil(project.parentProjectID)
        XCTAssertTrue(project.conversations.isEmpty)
        XCTAssertTrue(project.files.isEmpty)
    }

    func testProjectCustomValues() {
        let parentID = UUID()
        let project = Project(
            title: "Custom Project",
            customInstructions: "Use formal tone",
            projectDescription: "A test project",
            iconName: "star",
            colorHex: "#FF5733",
            parentProjectID: parentID
        )

        XCTAssertEqual(project.title, "Custom Project")
        XCTAssertEqual(project.customInstructions, "Use formal tone")
        XCTAssertEqual(project.projectDescription, "A test project")
        XCTAssertEqual(project.iconName, "star")
        XCTAssertEqual(project.colorHex, "#FF5733")
        XCTAssertEqual(project.parentProjectID, parentID)
    }

    func testProjectDatesSetOnCreation() {
        let before = Date()
        let project = Project(title: "Timed")
        let after = Date()

        XCTAssertGreaterThanOrEqual(project.createdAt, before)
        XCTAssertLessThanOrEqual(project.createdAt, after)
        XCTAssertGreaterThanOrEqual(project.updatedAt, before)
        XCTAssertLessThanOrEqual(project.updatedAt, after)
    }

    // MARK: - Project Persistence

    func testProjectPersistence() throws {
        let project = Project(
            title: "Persistent",
            customInstructions: "Be concise",
            iconName: "doc"
        )
        modelContext.insert(project)
        try modelContext.save()

        let descriptor = FetchDescriptor<Project>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Persistent")
        XCTAssertEqual(fetched.first?.customInstructions, "Be concise")
        XCTAssertEqual(fetched.first?.iconName, "doc")
    }

    func testProjectUniqueID() throws {
        let id = UUID()
        let project1 = Project(id: id, title: "First")
        modelContext.insert(project1)
        try modelContext.save()

        let project2 = Project(id: id, title: "Second")
        modelContext.insert(project2)

        do {
            try modelContext.save()
            let descriptor = FetchDescriptor<Project>()
            let fetched = try modelContext.fetch(descriptor)
            XCTAssertEqual(fetched.count, 1)
        } catch {
            // Duplicate key constraint is acceptable
            XCTAssertTrue(true)
        }
    }

    // MARK: - Project-Conversation Relationship

    func testProjectConversationRelationship() throws {
        let project = Project(title: "With Conversations")
        let conv1 = Conversation(title: "Chat 1")
        let conv2 = Conversation(title: "Chat 2")

        project.conversations.append(contentsOf: [conv1, conv2])

        modelContext.insert(project)
        modelContext.insert(conv1)
        modelContext.insert(conv2)
        try modelContext.save()

        let descriptor = FetchDescriptor<Project>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.first?.conversations.count, 2)
    }

    func testProjectConversationNullifyOnDelete() throws {
        let project = Project(title: "Will Delete")
        let conversation = Conversation(title: "Orphan Chat")
        project.conversations.append(conversation)

        modelContext.insert(project)
        modelContext.insert(conversation)
        try modelContext.save()

        // Delete project — conversation should survive (nullify)
        modelContext.delete(project)
        try modelContext.save()

        let convDescriptor = FetchDescriptor<Conversation>()
        let conversations = try modelContext.fetch(convDescriptor)
        XCTAssertEqual(conversations.count, 1, "Conversation should survive project deletion")
    }

    // MARK: - Project Mutation

    func testProjectTitleUpdate() {
        let project = Project(title: "Original")
        project.title = "Updated"
        XCTAssertEqual(project.title, "Updated")
    }

    func testProjectInstructionsUpdate() {
        let project = Project(title: "Test")
        XCTAssertEqual(project.customInstructions, "")

        project.customInstructions = "Always use Swift 6 concurrency"
        XCTAssertEqual(project.customInstructions, "Always use Swift 6 concurrency")
    }

    // MARK: - ProjectFile

    func testProjectFileCreation() {
        let file = ProjectFile(
            name: "main.swift",
            path: "/Users/test/main.swift",
            size: 2048
        )

        XCTAssertNotNil(file.id)
        XCTAssertEqual(file.name, "main.swift")
        XCTAssertEqual(file.path, "/Users/test/main.swift")
        XCTAssertEqual(file.size, 2048)
    }

    func testProjectFileIdentifiable() {
        let file1 = ProjectFile(name: "a.swift", path: "/a", size: 100)
        let file2 = ProjectFile(name: "b.swift", path: "/b", size: 200)

        XCTAssertNotEqual(file1.id, file2.id)
    }

    func testProjectFileCodable() throws {
        let file = ProjectFile(name: "test.swift", path: "/test", size: 512)

        let encoder = JSONEncoder()
        let data = try encoder.encode(file)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProjectFile.self, from: data)

        XCTAssertEqual(decoded.name, file.name)
        XCTAssertEqual(decoded.path, file.path)
        XCTAssertEqual(decoded.size, file.size)
    }

    func testProjectFileAddedDate() {
        let before = Date()
        let file = ProjectFile(name: "new.swift", path: "/new", size: 0)
        let after = Date()

        XCTAssertGreaterThanOrEqual(file.addedAt, before)
        XCTAssertLessThanOrEqual(file.addedAt, after)
    }

    // MARK: - ProjectSettings

    func testProjectSettingsDefaults() {
        let settings = ProjectSettings()

        XCTAssertNil(settings.defaultModel)
        XCTAssertNil(settings.defaultProvider)
        XCTAssertEqual(settings.temperature, 1.0)
        XCTAssertNil(settings.maxTokens)
    }

    func testProjectSettingsCustomValues() {
        let settings = ProjectSettings(
            defaultModel: "claude-opus-4-6",
            defaultProvider: "anthropic",
            temperature: 0.7,
            maxTokens: 4096
        )

        XCTAssertEqual(settings.defaultModel, "claude-opus-4-6")
        XCTAssertEqual(settings.defaultProvider, "anthropic")
        XCTAssertEqual(settings.temperature, 0.7)
        XCTAssertEqual(settings.maxTokens, 4096)
    }

    func testProjectSettingsCodable() throws {
        let settings = ProjectSettings(
            defaultModel: "gpt-4o",
            temperature: 0.5,
            maxTokens: 8192
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProjectSettings.self, from: data)

        XCTAssertEqual(decoded.defaultModel, "gpt-4o")
        XCTAssertEqual(decoded.temperature, 0.5)
        XCTAssertEqual(decoded.maxTokens, 8192)
        XCTAssertNil(decoded.defaultProvider)
    }

    func testProjectSettingsTemperatureRange() {
        let cold = ProjectSettings(temperature: 0.0)
        XCTAssertEqual(cold.temperature, 0.0)

        let hot = ProjectSettings(temperature: 2.0)
        XCTAssertEqual(hot.temperature, 2.0)
    }

    // MARK: - Project with Settings and Files

    func testProjectWithFilesAndSettings() {
        let files = [
            ProjectFile(name: "a.swift", path: "/a", size: 100),
            ProjectFile(name: "b.swift", path: "/b", size: 200)
        ]
        let settings = ProjectSettings(
            defaultModel: "claude-opus-4-6",
            temperature: 0.8
        )

        let project = Project(
            title: "Full Project",
            files: files,
            settings: settings
        )

        XCTAssertEqual(project.files.count, 2)
        XCTAssertEqual(project.settings.defaultModel, "claude-opus-4-6")
        XCTAssertEqual(project.settings.temperature, 0.8)
    }
}
