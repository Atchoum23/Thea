// ProjectService.swift
// Service layer implementation - Concrete project operations
// Following 2025/2026 best practices: Service pattern with protocol conformance

import Foundation
import SwiftData

// MARK: - Project Service Implementation

/// Concrete implementation of ProjectServiceProtocol for production use.
/// Handles all project operations with SwiftData persistence.
@MainActor
public final class ProjectService: ProjectServiceProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - ProjectServiceProtocol

    public func createProject(title: String) async throws -> UUID {
        let project = Project(title: title)
        modelContext.insert(project)
        try modelContext.save()
        return project.id
    }

    public func deleteProject(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<Project>()
        let projects = try modelContext.fetch(descriptor)
        guard let project = projects.first(where: { $0.id == id }) else {
            throw ProjectServiceError.projectNotFound
        }
        modelContext.delete(project)
        try modelContext.save()
    }

    public func fetchProjects() async throws -> [ProjectSnapshot] {
        var descriptor = FetchDescriptor<Project>()
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        let projects = try modelContext.fetch(descriptor)
        return projects.map { $0.toSnapshot() }
    }

    public func updateProject(_ id: UUID, title: String?, description: String?) async throws {
        let descriptor = FetchDescriptor<Project>()
        let projects = try modelContext.fetch(descriptor)
        guard let project = projects.first(where: { $0.id == id }) else {
            throw ProjectServiceError.projectNotFound
        }

        if let title = title {
            project.title = title
        }
        if let description = description {
            project.projectDescription = description
        }
        project.updatedAt = Date()
        try modelContext.save()
    }

    public func linkConversation(_ conversationID: UUID, to projectID: UUID) async throws {
        let projectDescriptor = FetchDescriptor<Project>()
        let projects = try modelContext.fetch(projectDescriptor)
        guard let project = projects.first(where: { $0.id == projectID }) else {
            throw ProjectServiceError.projectNotFound
        }

        let conversationDescriptor = FetchDescriptor<Conversation>()
        let conversations = try modelContext.fetch(conversationDescriptor)
        guard let conversation = conversations.first(where: { $0.id == conversationID }) else {
            throw ProjectServiceError.conversationNotFound
        }

        conversation.project = project
        project.updatedAt = Date()
        try modelContext.save()
    }

    public func unlinkConversation(_ conversationID: UUID, from projectID: UUID) async throws {
        let conversationDescriptor = FetchDescriptor<Conversation>()
        let conversations = try modelContext.fetch(conversationDescriptor)
        guard let conversation = conversations.first(where: { $0.id == conversationID }) else {
            throw ProjectServiceError.conversationNotFound
        }

        guard conversation.project?.id == projectID else {
            throw ProjectServiceError.conversationNotLinked
        }

        conversation.project = nil
        try modelContext.save()
    }
}

// MARK: - Project Service Errors

public enum ProjectServiceError: Error, Sendable {
    case projectNotFound
    case conversationNotFound
    case conversationNotLinked
    case persistenceError(String)
}

// MARK: - Model Extensions for Snapshots

extension Project {
    func toSnapshot() -> ProjectSnapshot {
        ProjectSnapshot(
            id: id,
            title: title,
            description: projectDescription,
            createdAt: createdAt,
            updatedAt: updatedAt,
            conversationCount: conversations.count,
            rootPath: rootPath
        )
    }
}
