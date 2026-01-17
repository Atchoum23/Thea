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
        self.modelContext = context
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

// MARK: - Migration Protocol

protocol MigrationSource: Sendable {
    var sourceName: String { get }
    var sourceIcon: String { get }
    var sourceDescription: String { get }

    func detectInstallation() async -> Bool
    func estimateMigrationSize() async throws -> MigrationEstimate
    func migrate(options: MigrationOptions) async throws -> AsyncThrowingStream<MigrationProgress, Error>
}

// MARK: - Migration Models

struct MigrationOptions: Sendable {
    var includeConversations = true
    var includeProjects = true
    var includeSettings = true
    var includeAttachments = true
    var deduplicateConversations = true
}

struct MigrationEstimate: Sendable {
    let conversationCount: Int
    let projectCount: Int
    let attachmentCount: Int
    let totalSizeBytes: Int64
    let estimatedDurationSeconds: Int
}

struct MigrationProgress: Sendable {
    let stage: MigrationStage
    let currentItem: String
    let itemsProcessed: Int
    let totalItems: Int
    let percentage: Double

    var conversations: [MigratedConversation]?
    var projects: [MigratedProject]?
}

struct MigrationStats: Sendable {
    let conversationCount: Int
    let messageCount: Int
    let projectCount: Int
    let attachmentCount: Int
}

enum MigrationStage: String, Sendable {
    case scanning = "Scanning"
    case conversations = "Migrating Conversations"
    case projects = "Migrating Projects"
    case attachments = "Migrating Attachments"
    case settings = "Migrating Settings"
    case finalizing = "Finalizing"
    case complete = "Complete"
}

struct MigratedConversation: Sendable {
    let title: String
    let messages: [MigratedMessage]
    let createdAt: Date
    let updatedAt: Date
    let model: String
    let provider: String
}

struct MigratedMessage: Sendable {
    let role: MessageRole
    let content: MessageContent
    let timestamp: Date
}

struct MigratedProject: Sendable {
    let name: String
    let description: String
    let instructions: String
    let createdAt: Date
    let updatedAt: Date
}

struct MigrationSourceInfo {
    let source: any MigrationSource
    let estimate: MigrationEstimate
    let isInstalled: Bool
}

class MigrationJob: Identifiable, @unchecked Sendable {
    let id: UUID
    let source: String
    let startTime: Date
    var endTime: Date?
    var status: MigrationStatus
    var progress: MigrationProgress

    init(id: UUID, source: String, startTime: Date, status: MigrationStatus, progress: MigrationProgress) {
        self.id = id
        self.source = source
        self.startTime = startTime
        self.status = status
        self.progress = progress
    }
}

enum MigrationStatus {
    case running
    case completed
    case failed(String)
}

// MARK: - Claude.app Migration

struct ClaudeAppMigration: MigrationSource {
    let sourceName = "Claude.app"
    let sourceIcon = "brain"
    let sourceDescription = "Anthropic Claude Desktop App"

    private var claudeDataPath: URL {
        #if os(macOS)
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude")
        #else
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Claude") ?? FileManager.default.temporaryDirectory
        #endif
    }

    func detectInstallation() async -> Bool {
        FileManager.default.fileExists(atPath: claudeDataPath.path)
    }

    func estimateMigrationSize() async throws -> MigrationEstimate {
        // Scan Claude data directory
        var conversationCount = 0
        var projectCount = 0
        var totalSize: Int64 = 0

        let conversationsPath = claudeDataPath.appendingPathComponent("conversations")
        let projectsPath = claudeDataPath.appendingPathComponent("projects")

        if FileManager.default.fileExists(atPath: conversationsPath.path) {
            let conversations = try FileManager.default.contentsOfDirectory(at: conversationsPath, includingPropertiesForKeys: [.fileSizeKey])
            conversationCount = conversations.count

            for conv in conversations {
                if let size = try? conv.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        if FileManager.default.fileExists(atPath: projectsPath.path) {
            let projects = try FileManager.default.contentsOfDirectory(at: projectsPath, includingPropertiesForKeys: [])
            projectCount = projects.count
        }

        return MigrationEstimate(
            conversationCount: conversationCount,
            projectCount: projectCount,
            attachmentCount: 0,
            totalSizeBytes: totalSize,
            estimatedDurationSeconds: conversationCount / 10 // ~10 conversations per second
        )
    }

    func migrate(options: MigrationOptions) async throws -> AsyncThrowingStream<MigrationProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var migratedConversations: [MigratedConversation] = []

                    // Phase 1: Scan
                    continuation.yield(MigrationProgress(
                        stage: .scanning,
                        currentItem: "Scanning Claude data",
                        itemsProcessed: 0,
                        totalItems: 0,
                        percentage: 0
                    ))

                    // Phase 2: Migrate conversations
                    if options.includeConversations {
                        let conversationsPath = claudeDataPath.appendingPathComponent("conversations")

                        if FileManager.default.fileExists(atPath: conversationsPath.path) {
                            let conversationFiles = try FileManager.default.contentsOfDirectory(at: conversationsPath, includingPropertiesForKeys: [])

                            for (index, file) in conversationFiles.enumerated() {
                                let conversation = try await parseClaudeConversation(file)
                                migratedConversations.append(conversation)

                                continuation.yield(MigrationProgress(
                                    stage: .conversations,
                                    currentItem: conversation.title,
                                    itemsProcessed: index + 1,
                                    totalItems: conversationFiles.count,
                                    percentage: Double(index + 1) / Double(conversationFiles.count),
                                    conversations: [conversation],
                                    projects: nil
                                ))
                            }
                        }
                    }

                    // Phase 3: Complete
                    continuation.yield(MigrationProgress(
                        stage: .complete,
                        currentItem: "Migration complete",
                        itemsProcessed: migratedConversations.count,
                        totalItems: migratedConversations.count,
                        percentage: 1.0
                    ))

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func parseClaudeConversation(_ file: URL) async throws -> MigratedConversation {
        let data = try Data(contentsOf: file)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        let title = json["title"] as? String ?? "Untitled"
        let messagesJSON = json["messages"] as? [[String: Any]] ?? []

        let messages = messagesJSON.compactMap { msgJSON -> MigratedMessage? in
            guard let role = msgJSON["role"] as? String,
                  let content = msgJSON["content"] as? String else {
                return nil
            }

            return MigratedMessage(
                role: role == "user" ? .user : .assistant,
                content: .text(content),
                timestamp: Date()
            )
        }

        return MigratedConversation(
            title: title,
            messages: messages,
            createdAt: Date(),
            updatedAt: Date(),
            model: "claude-3-5-sonnet-20241022",
            provider: "anthropic"
        )
    }
}

// MARK: - ChatGPT Migration

struct ChatGPTMigration: MigrationSource {
    let sourceName = "ChatGPT"
    let sourceIcon = "message.circle"
    let sourceDescription = "OpenAI ChatGPT Export"

    func detectInstallation() async -> Bool {
        // ChatGPT requires manual export
        false
    }

    func estimateMigrationSize() async throws -> MigrationEstimate {
        throw MigrationError.manualExportRequired
    }

    func migrate(options: MigrationOptions) async throws -> AsyncThrowingStream<MigrationProgress, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: MigrationError.manualExportRequired)
        }
    }

    func importFromExport(fileURL: URL) async throws -> AsyncThrowingStream<MigrationProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

                    for (index, convJSON) in json.enumerated() {
                        let conversation = try parseChatGPTConversation(convJSON)

                        continuation.yield(MigrationProgress(
                            stage: .conversations,
                            currentItem: conversation.title,
                            itemsProcessed: index + 1,
                            totalItems: json.count,
                            percentage: Double(index + 1) / Double(json.count),
                            conversations: [conversation],
                            projects: nil
                        ))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func parseChatGPTConversation(_ json: [String: Any]) throws -> MigratedConversation {
        let title = json["title"] as? String ?? "Untitled"
        let mapping = json["mapping"] as? [String: [String: Any]] ?? [:]

        var messages: [MigratedMessage] = []

        for (_, nodeData) in mapping {
            if let message = nodeData["message"] as? [String: Any],
               let content = message["content"] as? [String: Any],
               let parts = content["parts"] as? [String],
               let role = message["author"] as? [String: String],
               let roleValue = role["role"] {
                let msgRole: MessageRole = roleValue == "user" ? .user : .assistant
                let text = parts.joined(separator: "\n")

                messages.append(MigratedMessage(
                    role: msgRole,
                    content: .text(text),
                    timestamp: Date()
                ))
            }
        }

        return MigratedConversation(
            title: title,
            messages: messages,
            createdAt: Date(),
            updatedAt: Date(),
            model: "gpt-4",
            provider: "openai"
        )
    }
}

// MARK: - Cursor Migration

struct CursorMigration: MigrationSource {
    let sourceName = "Cursor"
    let sourceIcon = "chevron.left.forwardslash.chevron.right"
    let sourceDescription = "Cursor AI Code Editor"

    func detectInstallation() async -> Bool {
        #if os(macOS)
        let cursorPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor")
        #else
        let cursorPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Cursor") ?? FileManager.default.temporaryDirectory
        #endif

        return FileManager.default.fileExists(atPath: cursorPath.path)
    }

    func estimateMigrationSize() async throws -> MigrationEstimate {
        MigrationEstimate(
            conversationCount: 0,
            projectCount: 0,
            attachmentCount: 0,
            totalSizeBytes: 0,
            estimatedDurationSeconds: 0
        )
    }

    func migrate(options: MigrationOptions) async throws -> AsyncThrowingStream<MigrationProgress, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(MigrationProgress(
                stage: .complete,
                currentItem: "Cursor migration not yet implemented",
                itemsProcessed: 0,
                totalItems: 0,
                percentage: 1.0
            ))
            continuation.finish()
        }
    }
}

// MARK: - Perplexity Migration

struct PerplexityMigration: MigrationSource {
    let sourceName = "Perplexity"
    let sourceIcon = "magnifyingglass.circle"
    let sourceDescription = "Perplexity AI"

    func detectInstallation() async -> Bool {
        false // Perplexity is web-based
    }

    func estimateMigrationSize() async throws -> MigrationEstimate {
        throw MigrationError.webBasedApp
    }

    func migrate(options: MigrationOptions) async throws -> AsyncThrowingStream<MigrationProgress, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: MigrationError.webBasedApp)
        }
    }
}

// MARK: - Claude Code CLI Migration

struct ClaudeCodeCLIMigration: MigrationSource {
    let sourceName = "Claude Code CLI"
    let sourceIcon = "terminal"
    let sourceDescription = "Claude Code conversation exports"

    func detectInstallation() async -> Bool {
        true // Can always import exports
    }

    func estimateMigrationSize() async throws -> MigrationEstimate {
        MigrationEstimate(
            conversationCount: 0,
            projectCount: 0,
            attachmentCount: 0,
            totalSizeBytes: 0,
            estimatedDurationSeconds: 0
        )
    }

    func migrate(options: MigrationOptions) async throws -> AsyncThrowingStream<MigrationProgress, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: MigrationError.manualExportRequired)
        }
    }
}

// MARK: - Errors

enum MigrationError: LocalizedError {
    case manualExportRequired
    case webBasedApp
    case notImplemented
    case noModelContext

    var errorDescription: String? {
        switch self {
        case .manualExportRequired:
            return "This app requires manual export. Please export your data and import the file."
        case .webBasedApp:
            return "This is a web-based app. Migration not supported."
        case .notImplemented:
            return "Migration for this app is not yet implemented"
        case .noModelContext:
            return "Database context not available. Please restart Thea and try again."
        }
    }
}
