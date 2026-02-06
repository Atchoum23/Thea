// MockProjectService.swift
// Mock implementation for testing - No SwiftData dependency
// Following 2025/2026 best practices: In-memory mock for fast unit tests

import Foundation
import TheaInterfaces

// MARK: - Mock Project Service

/// In-memory mock implementation of ProjectServiceProtocol for testing.
/// No SwiftData dependency - enables fast unit tests in Swift Package.
public actor MockProjectService: ProjectServiceProtocol {
    public private(set) var projects: [UUID: MockProject] = [:]
    public private(set) var linkedConversations: [UUID: Set<UUID>] = [:] // projectID -> conversationIDs

    public init() {}

    // MARK: - Test Helpers

    public func reset() {
        projects.removeAll()
        linkedConversations.removeAll()
    }

    public var projectCount: Int {
        projects.count
    }

    public func getProject(_ id: UUID) -> MockProject? {
        projects[id]
    }

    // MARK: - ProjectServiceProtocol

    public func createProject(title: String) async throws -> UUID {
        let id = UUID()
        let project = MockProject(
            id: id,
            title: title,
            createdAt: Date(),
            updatedAt: Date()
        )
        projects[id] = project
        linkedConversations[id] = []
        return id
    }

    public func deleteProject(_ id: UUID) async throws {
        guard projects[id] != nil else {
            throw MockProjectServiceError.projectNotFound
        }
        projects.removeValue(forKey: id)
        linkedConversations.removeValue(forKey: id)
    }

    public func fetchProjects() async throws -> [ProjectSnapshot] {
        projects.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { $0.toSnapshot(conversationCount: linkedConversations[$0.id]?.count ?? 0) }
    }

    public func updateProject(_ id: UUID, title: String?, description: String?) async throws {
        guard var project = projects[id] else {
            throw MockProjectServiceError.projectNotFound
        }

        if let title = title {
            project.title = title
        }
        if let description = description {
            project.description = description
        }
        project.updatedAt = Date()
        projects[id] = project
    }

    public func linkConversation(_ conversationID: UUID, to projectID: UUID) async throws {
        guard projects[projectID] != nil else {
            throw MockProjectServiceError.projectNotFound
        }

        var conversations = linkedConversations[projectID] ?? []
        conversations.insert(conversationID)
        linkedConversations[projectID] = conversations

        if var project = projects[projectID] {
            project.updatedAt = Date()
            projects[projectID] = project
        }
    }

    public func unlinkConversation(_ conversationID: UUID, from projectID: UUID) async throws {
        guard projects[projectID] != nil else {
            throw MockProjectServiceError.projectNotFound
        }

        var conversations = linkedConversations[projectID] ?? []
        guard conversations.contains(conversationID) else {
            throw MockProjectServiceError.conversationNotLinked
        }
        conversations.remove(conversationID)
        linkedConversations[projectID] = conversations
    }
}

// MARK: - Mock Project

public struct MockProject: Sendable {
    public let id: UUID
    public var title: String
    public var description: String?
    public let createdAt: Date
    public var updatedAt: Date
    public var rootPath: String?

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        rootPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.rootPath = rootPath
    }

    public func toSnapshot(conversationCount: Int) -> ProjectSnapshot {
        ProjectSnapshot(
            id: id,
            title: title,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt,
            conversationCount: conversationCount,
            rootPath: rootPath
        )
    }
}

// MARK: - Mock Errors

public enum MockProjectServiceError: Error, Sendable {
    case projectNotFound
    case conversationNotLinked
}
