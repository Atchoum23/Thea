import Foundation
@preconcurrency import SwiftData

// MARK: - Migration Engine

// Universal migration system for importing data from competitor apps

@MainActor
@Observable
final class MigrationEngine {
    static let shared = MigrationEngine()

    private(set) var availableSources: [any MigrationSource] = []
    private(set) var activeMigrations: [MigrationJob] = []
    private(set) var completedMigrations: [MigrationJob] = []

    private var modelContext: ModelContext?

    private init() {
        registerMigrationSources()
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    private func registerMigrationSources() {
        availableSources = [
            ClaudeAppMigration(),
            ChatGPTMigration(),
            CursorMigration(),
            PerplexityMigration(),
            ClaudeCodeCLIMigration()
        ]
    }

    // MARK: - Migration Discovery

    func detectInstalledApps() async -> [MigrationSourceInfo] {
        var detected: [MigrationSourceInfo] = []

        for source in availableSources {
            let isInstalled = await source.detectInstallation()

            if isInstalled {
                do {
                    let estimate = try await source.estimateMigrationSize()

                    detected.append(MigrationSourceInfo(
                        source: source,
                        estimate: estimate,
                        isInstalled: true
                    ))
                } catch {
                    print("Failed to estimate \(source.sourceName): \(error)")
                }
            }
        }

        return detected
    }

    // MARK: - Migration Execution

    func startMigration(
        from source: any MigrationSource,
        options: MigrationOptions = MigrationOptions()
    ) async throws -> UUID {
        let job = MigrationJob(
            id: UUID(),
            source: source.sourceName,
            startTime: Date(),
            status: .running,
            progress: MigrationProgress(
                stage: .scanning,
                currentItem: "",
                itemsProcessed: 0,
                totalItems: 0,
                percentage: 0
            )
        )

        activeMigrations.append(job)

        Task {
            do {
                let stream = try await source.migrate(options: options)

                for try await progress in stream {
                    job.progress = progress

                    // Store results as they come in
                    if let conversations = progress.conversations {
                        try await importConversations(conversations)
                    }

                    if let projects = progress.projects {
                        try await importProjects(projects)
                    }
                }

                job.status = .completed
                job.endTime = Date()

                activeMigrations.removeAll { $0.id == job.id }
                completedMigrations.append(job)
            } catch {
                job.status = .failed(error.localizedDescription)
                job.endTime = Date()

                activeMigrations.removeAll { $0.id == job.id }
                completedMigrations.append(job)
            }
        }

        return job.id
    }

    private func importConversations(_ conversations: [MigratedConversation]) async throws {
        guard let context = modelContext else {
            print("⚠️ ModelContext not set - cannot import conversations")
            throw MigrationError.noModelContext
        }

        for migratedConv in conversations {
            let conversation = Conversation(
                id: UUID(),
                title: migratedConv.title,
                createdAt: migratedConv.createdAt,
                updatedAt: migratedConv.updatedAt
            )

            context.insert(conversation)

            // Import messages for this conversation
            for migratedMsg in migratedConv.messages {
                let message = Message(
                    id: UUID(),
                    conversationID: conversation.id,
                    role: migratedMsg.role,
                    content: migratedMsg.content,
                    timestamp: migratedMsg.timestamp,
                    model: migratedConv.model
                )
                context.insert(message)
            }
        }

        try context.save()
        print("✅ Successfully imported \(conversations.count) conversations")
    }

    private func importProjects(_ projects: [MigratedProject]) async throws {
        guard let context = modelContext else {
            print("⚠️ ModelContext not set - cannot import projects")
            throw MigrationError.noModelContext
        }

        for migratedProj in projects {
            let project = Project(
                id: UUID(),
                title: migratedProj.name,
                customInstructions: migratedProj.instructions,
                createdAt: migratedProj.createdAt,
                updatedAt: migratedProj.updatedAt
            )
            context.insert(project)
        }

        try context.save()
        print("✅ Successfully imported \(projects.count) projects")
    }
}

// Types, protocols, migration sources, and errors are in MigrationEngineTypes.swift
