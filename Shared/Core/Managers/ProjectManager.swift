import Combine
import Foundation
@preconcurrency import SwiftData

@MainActor
final class ProjectManager: ObservableObject {
    static let shared = ProjectManager()

    @Published private(set) var projects: [Project] = []
    @Published private(set) var activeProject: Project?

    private var modelContext: ModelContext?

    private init() {}

    // MARK: - Setup

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
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
        try? modelContext?.save()

        projects.insert(project, at: 0)
        return project
    }

    func updateProject(_ project: Project, title: String? = nil, customInstructions: String? = nil) {
        if let title = title {
            project.title = title
        }

        if let customInstructions = customInstructions {
            project.customInstructions = customInstructions
        }

        project.updatedAt = Date()
        try? modelContext?.save()
    }

    func deleteProject(_ project: Project) {
        modelContext?.delete(project)
        try? modelContext?.save()

        projects.removeAll { $0.id == project.id }

        if activeProject?.id == project.id {
            activeProject = nil
        }
    }

    func setActiveProject(_ project: Project?) {
        activeProject = project
    }

    // MARK: - Conversation Management

    func addConversation(_ conversation: Conversation, to project: Project) {
        conversation.projectID = project.id
        project.conversations.append(conversation)
        try? modelContext?.save()
    }

    func removeConversation(_ conversation: Conversation, from project: Project) {
        conversation.projectID = nil
        project.conversations.removeAll { $0.id == conversation.id }
        try? modelContext?.save()
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
        try? modelContext?.save()
    }

    func removeFile(from project: Project, fileID: UUID) {
        project.files.removeAll { $0.id == fileID }
        try? modelContext?.save()
    }

    // MARK: - Private Methods

    private func loadProjects() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<Project>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        projects = (try? context.fetch(descriptor)) ?? []
    }
}
