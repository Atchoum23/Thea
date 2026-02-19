import Combine
import Foundation
import os.log
@preconcurrency import SwiftData

private let projectLogger = Logger(subsystem: "ai.thea.app", category: "ProjectManager")

@MainActor
final class ProjectManager: ObservableObject {
    static let shared = ProjectManager()

    @Published private(set) var projects: [Project] = []
    @Published private(set) var activeProject: Project?

    private var modelContext: ModelContext?

    private init() {}

    // MARK: - Setup

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        loadProjects()
    }

    // MARK: - Project CRUD

    func createProject(title: String, customInstructions: String = "") -> Project {
        let project = Project(
            id: UUID(),
            title: title,
            customInstructions: customInstructions
        )

        modelContext?.insert(project)
        do { try modelContext?.save() } catch { projectLogger.error("Failed to save new project: \(error.localizedDescription)") }

        projects.insert(project, at: 0)
        return project
    }

    func updateProject(_ project: Project, title: String? = nil, customInstructions: String? = nil) {
        if let title {
            project.title = title
        }

        if let customInstructions {
            project.customInstructions = customInstructions
        }

        project.updatedAt = Date()
        do { try modelContext?.save() } catch { projectLogger.error("Failed to save project update: \(error.localizedDescription)") }
    }

    func deleteProject(_ project: Project) {
        modelContext?.delete(project)
        do { try modelContext?.save() } catch { projectLogger.error("Failed to save after deleting project: \(error.localizedDescription)") }

        projects.removeAll { $0.id == project.id }

        if activeProject?.id == project.id {
            activeProject = nil
        }
    }

    func clearAllData() {
        guard let context = modelContext else { return }

        for project in projects {
            context.delete(project)
        }
        do { try context.save() } catch { projectLogger.error("Failed to save after clearing all data: \(error.localizedDescription)") }

        projects.removeAll()
        activeProject = nil
    }

    func setActiveProject(_ project: Project?) {
        activeProject = project
    }

    // MARK: - Conversation Management

    func addConversation(_ conversation: Conversation, to project: Project) {
        conversation.projectID = project.id
        project.conversations.append(conversation)
        do { try modelContext?.save() } catch { projectLogger.error("Failed to save after adding conversation to project: \(error.localizedDescription)") }
    }

    func removeConversation(_ conversation: Conversation, from project: Project) {
        conversation.projectID = nil
        project.conversations.removeAll { $0.id == conversation.id }
        do { try modelContext?.save() } catch { projectLogger.error("Failed to save after removing conversation from project: \(error.localizedDescription)") }
    }

    // MARK: - File Management

    func addFile(to project: Project, name: String, path: String, size: Int64) {
        let file = ProjectFile(
            id: UUID(),
            name: name,
            path: path,
            size: size,
            addedAt: Date()
        )

        project.files.append(file)
        do { try modelContext?.save() } catch { projectLogger.error("Failed to save after adding file to project: \(error.localizedDescription)") }
    }

    func removeFile(from project: Project, fileID: UUID) {
        project.files.removeAll { $0.id == fileID }
        do { try modelContext?.save() } catch { projectLogger.error("Failed to save after removing file from project: \(error.localizedDescription)") }
    }

    // MARK: - Private Methods

    private func loadProjects() {
        guard let context = modelContext else { return }

        // Fetch all and sort in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<Project>()
        let allProjects: [Project]
        do {
            allProjects = try context.fetch(descriptor)
        } catch {
            projectLogger.error("Failed to fetch projects: \(error.localizedDescription)")
            allProjects = []
        }
        projects = allProjects.sorted { $0.updatedAt > $1.updatedAt }
    }
}
