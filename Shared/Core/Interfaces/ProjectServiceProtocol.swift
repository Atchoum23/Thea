// ProjectServiceProtocol.swift
// Interface module - Protocol for project operations
// Following 2025/2026 best practices: Abstract modules contain only interfaces

import Foundation

// MARK: - Project Service Protocol

/// Protocol defining the core project operations.
/// Enables dependency injection and testability.
public protocol ProjectServiceProtocol: Sendable {
    /// Creates a new project with the given title
    func createProject(title: String) async throws -> UUID

    /// Deletes a project by its ID
    func deleteProject(_ id: UUID) async throws

    /// Fetches all projects
    func fetchProjects() async throws -> [ProjectSnapshot]

    /// Updates project metadata
    func updateProject(_ id: UUID, title: String?, description: String?) async throws

    /// Links a conversation to a project
    func linkConversation(_ conversationID: UUID, to projectID: UUID) async throws

    /// Unlinks a conversation from a project
    func unlinkConversation(_ conversationID: UUID, from projectID: UUID) async throws
}

// MARK: - Snapshot Types

/// A sendable snapshot of a project for interface boundaries
public struct ProjectSnapshot: Sendable, Identifiable, Codable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let conversationCount: Int
    public let rootPath: String?

    public init(
        id: UUID,
        title: String,
        description: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        conversationCount: Int = 0,
        rootPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.conversationCount = conversationCount
        self.rootPath = rootPath
    }
}
