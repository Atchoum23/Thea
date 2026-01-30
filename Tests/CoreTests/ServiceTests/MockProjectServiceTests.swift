// MockProjectServiceTests.swift
// Tests for MockProjectService - Fast unit tests without SwiftData

import Foundation
@testable import TheaServices
@testable import TheaInterfaces
import XCTest

final class MockProjectServiceTests: XCTestCase {

    var projectService: MockProjectService!

    override func setUp() async throws {
        projectService = MockProjectService()
    }

    override func tearDown() async throws {
        await projectService.reset()
        projectService = nil
    }

    // MARK: - Project CRUD Tests

    func testCreateProject() async throws {
        let id = try await projectService.createProject(title: "Test Project")

        XCTAssertNotNil(id)
        let count = await projectService.projectCount
        XCTAssertEqual(count, 1)
    }

    func testCreateMultipleProjects() async throws {
        _ = try await projectService.createProject(title: "Project A")
        _ = try await projectService.createProject(title: "Project B")
        _ = try await projectService.createProject(title: "Project C")

        let count = await projectService.projectCount
        XCTAssertEqual(count, 3)
    }

    func testFetchProjects() async throws {
        _ = try await projectService.createProject(title: "Alpha")
        _ = try await projectService.createProject(title: "Beta")

        let projects = try await projectService.fetchProjects()

        XCTAssertEqual(projects.count, 2)
        // Most recent first
        XCTAssertEqual(projects.first?.title, "Beta")
    }

    func testDeleteProject() async throws {
        let id = try await projectService.createProject(title: "To Delete")

        try await projectService.deleteProject(id)

        let count = await projectService.projectCount
        XCTAssertEqual(count, 0)
    }

    func testDeleteNonexistentProject() async {
        let fakeID = UUID()

        do {
            try await projectService.deleteProject(fakeID)
            XCTFail("Should throw projectNotFound")
        } catch MockProjectServiceError.projectNotFound {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Update Tests

    func testUpdateProjectTitle() async throws {
        let id = try await projectService.createProject(title: "Old Title")

        try await projectService.updateProject(id, title: "New Title", description: nil)

        let projects = try await projectService.fetchProjects()
        XCTAssertEqual(projects.first?.title, "New Title")
    }

    func testUpdateProjectDescription() async throws {
        let id = try await projectService.createProject(title: "My Project")

        try await projectService.updateProject(id, title: nil, description: "A great description")

        let project = await projectService.getProject(id)
        XCTAssertEqual(project?.description, "A great description")
    }

    func testUpdateNonexistentProject() async {
        let fakeID = UUID()

        do {
            try await projectService.updateProject(fakeID, title: "Title", description: nil)
            XCTFail("Should throw projectNotFound")
        } catch MockProjectServiceError.projectNotFound {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Conversation Linking Tests

    func testLinkConversation() async throws {
        let projectID = try await projectService.createProject(title: "Project")
        let conversationID = UUID()

        try await projectService.linkConversation(conversationID, to: projectID)

        let projects = try await projectService.fetchProjects()
        XCTAssertEqual(projects.first?.conversationCount, 1)
    }

    func testLinkMultipleConversations() async throws {
        let projectID = try await projectService.createProject(title: "Project")

        try await projectService.linkConversation(UUID(), to: projectID)
        try await projectService.linkConversation(UUID(), to: projectID)
        try await projectService.linkConversation(UUID(), to: projectID)

        let projects = try await projectService.fetchProjects()
        XCTAssertEqual(projects.first?.conversationCount, 3)
    }

    func testUnlinkConversation() async throws {
        let projectID = try await projectService.createProject(title: "Project")
        let conversationID = UUID()

        try await projectService.linkConversation(conversationID, to: projectID)
        try await projectService.unlinkConversation(conversationID, from: projectID)

        let projects = try await projectService.fetchProjects()
        XCTAssertEqual(projects.first?.conversationCount, 0)
    }

    func testUnlinkNonLinkedConversation() async throws {
        let projectID = try await projectService.createProject(title: "Project")
        let conversationID = UUID()

        do {
            try await projectService.unlinkConversation(conversationID, from: projectID)
            XCTFail("Should throw conversationNotLinked")
        } catch MockProjectServiceError.conversationNotLinked {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testLinkConversationToNonexistentProject() async {
        let fakeProjectID = UUID()
        let conversationID = UUID()

        do {
            try await projectService.linkConversation(conversationID, to: fakeProjectID)
            XCTFail("Should throw projectNotFound")
        } catch MockProjectServiceError.projectNotFound {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Reset Tests

    func testReset() async throws {
        _ = try await projectService.createProject(title: "One")
        _ = try await projectService.createProject(title: "Two")

        await projectService.reset()

        let count = await projectService.projectCount
        XCTAssertEqual(count, 0)
    }
}
