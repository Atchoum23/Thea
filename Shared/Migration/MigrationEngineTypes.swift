// MigrationEngineTypes.swift
// Supporting types for MigrationEngine

import Foundation

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

// @unchecked Sendable: mutable state (endTime, status, progress) is updated exclusively from the
// MigrationEngine actor context; class is used as a reference-typed progress container
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

// MARK: - Errors

enum MigrationError: LocalizedError {
    case manualExportRequired
    case webBasedApp
    case sourceNotSupported(String)
    case noModelContext

    var errorDescription: String? {
        switch self {
        case .manualExportRequired:
            "This app requires manual export. Please export your data and import the file."
        case .webBasedApp:
            "This is a web-based app. Migration not supported."
        case let .sourceNotSupported(name):
            "Migration from \(name) is not yet supported"
        case .noModelContext:
            "Database context not available. Please restart Thea and try again."
        }
    }
}

// MARK: - Migration Sources

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
        var conversationCount = 0
        var projectCount = 0
        var totalSize: Int64 = 0

        let conversationsPath = claudeDataPath.appendingPathComponent("conversations")
        let projectsPath = claudeDataPath.appendingPathComponent("projects")

        if FileManager.default.fileExists(atPath: conversationsPath.path) {
            let conversations = try FileManager.default.contentsOfDirectory(
                at: conversationsPath,
                includingPropertiesForKeys: [.fileSizeKey]
            )
            conversationCount = conversations.count

            for conv in conversations {
                do {
                    if let size = try conv.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(size)
                    }
                } catch {
                    // Non-critical: skip size for this file
                }
            }
        }

        if FileManager.default.fileExists(atPath: projectsPath.path) {
            let projects = try FileManager.default.contentsOfDirectory(
                at: projectsPath,
                includingPropertiesForKeys: []
            )
            projectCount = projects.count
        }

        return MigrationEstimate(
            conversationCount: conversationCount,
            projectCount: projectCount,
            attachmentCount: 0,
            totalSizeBytes: totalSize,
            estimatedDurationSeconds: conversationCount / 10
        )
    }

    func migrate(options: MigrationOptions) async throws -> AsyncThrowingStream<MigrationProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var migratedConversations: [MigratedConversation] = []

                    continuation.yield(MigrationProgress(
                        stage: .scanning, currentItem: "Scanning Claude data",
                        itemsProcessed: 0, totalItems: 0, percentage: 0
                    ))

                    if options.includeConversations {
                        let conversationsPath = claudeDataPath.appendingPathComponent("conversations")

                        if FileManager.default.fileExists(atPath: conversationsPath.path) {
                            let conversationFiles = try FileManager.default.contentsOfDirectory(
                                at: conversationsPath,
                                includingPropertiesForKeys: []
                            )

                            for (index, file) in conversationFiles.enumerated() {
                                let conversation = try await parseClaudeConversation(file)
                                migratedConversations.append(conversation)

                                continuation.yield(MigrationProgress(
                                    stage: .conversations, currentItem: conversation.title,
                                    itemsProcessed: index + 1, totalItems: conversationFiles.count,
                                    percentage: Double(index + 1) / Double(conversationFiles.count),
                                    conversations: [conversation], projects: nil
                                ))
                            }
                        }
                    }

                    continuation.yield(MigrationProgress(
                        stage: .complete, currentItem: "Migration complete",
                        itemsProcessed: migratedConversations.count,
                        totalItems: migratedConversations.count, percentage: 1.0
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
                  let content = msgJSON["content"] as? String
            else { return nil }

            return MigratedMessage(
                role: role == "user" ? .user : .assistant,
                content: .text(content),
                timestamp: Date()
            )
        }

        return MigratedConversation(
            title: title, messages: messages, createdAt: Date(), updatedAt: Date(),
            model: "claude-3-5-sonnet-20241022", provider: "anthropic"
        )
    }
}

struct ChatGPTMigration: MigrationSource {
    let sourceName = "ChatGPT"
    let sourceIcon = "message.circle"
    let sourceDescription = "OpenAI ChatGPT Export"

    func detectInstallation() async -> Bool { false }

    func estimateMigrationSize() async throws -> MigrationEstimate {
        throw MigrationError.manualExportRequired
    }

    func migrate(options _: MigrationOptions) async throws -> AsyncThrowingStream<MigrationProgress, Error> {
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
                            stage: .conversations, currentItem: conversation.title,
                            itemsProcessed: index + 1, totalItems: json.count,
                            percentage: Double(index + 1) / Double(json.count),
                            conversations: [conversation], projects: nil
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
               let roleValue = role["role"]
            {
                let msgRole: MessageRole = roleValue == "user" ? .user : .assistant
                let text = parts.joined(separator: "\n")
                messages.append(MigratedMessage(role: msgRole, content: .text(text), timestamp: Date()))
            }
        }

        return MigratedConversation(
            title: title, messages: messages, createdAt: Date(), updatedAt: Date(),
            model: "gpt-4", provider: "openai"
        )
    }
}

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
        MigrationEstimate(conversationCount: 0, projectCount: 0, attachmentCount: 0,
                          totalSizeBytes: 0, estimatedDurationSeconds: 0)
    }

    func migrate(options _: MigrationOptions) async throws -> AsyncThrowingStream<MigrationProgress, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(MigrationProgress(
                stage: .complete, currentItem: "Cursor migration not yet implemented",
                itemsProcessed: 0, totalItems: 0, percentage: 1.0
            ))
            continuation.finish()
        }
    }
}

struct PerplexityMigration: MigrationSource {
    let sourceName = "Perplexity"
    let sourceIcon = "magnifyingglass.circle"
    let sourceDescription = "Perplexity AI"

    func detectInstallation() async -> Bool { false }

    func estimateMigrationSize() async throws -> MigrationEstimate {
        throw MigrationError.webBasedApp
    }

    func migrate(options _: MigrationOptions) async throws -> AsyncThrowingStream<MigrationProgress, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: MigrationError.webBasedApp)
        }
    }
}

struct ClaudeCodeCLIMigration: MigrationSource {
    let sourceName = "Claude Code CLI"
    let sourceIcon = "terminal"
    let sourceDescription = "Claude Code conversation exports"

    func detectInstallation() async -> Bool { true }

    func estimateMigrationSize() async throws -> MigrationEstimate {
        MigrationEstimate(conversationCount: 0, projectCount: 0, attachmentCount: 0,
                          totalSizeBytes: 0, estimatedDurationSeconds: 0)
    }

    func migrate(options _: MigrationOptions) async throws -> AsyncThrowingStream<MigrationProgress, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: MigrationError.manualExportRequired)
        }
    }
}
