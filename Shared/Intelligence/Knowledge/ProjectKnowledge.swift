// ProjectKnowledge.swift
// Thea V2
//
// Hierarchical project knowledge management system
// Inspired by:
// - Bolt: Project Knowledge, Account Knowledge, Teams Knowledge
// - Lovable: Custom Knowledge with project context
// - Claude Code: CLAUDE.md files at different scopes

import Foundation
import OSLog

// MARK: - Project Knowledge Scope

/// Scope hierarchy for knowledge items
/// Priority: Project > Workspace > Account > Global
public enum ProjectKnowledgeScope: String, Codable, Sendable, CaseIterable {
    /// Specific to current project/folder
    case project

    /// Specific to workspace (may contain multiple projects)
    case workspace

    /// User's account-wide settings
    case account

    /// Global defaults from Thea
    case global

    public var displayName: String {
        switch self {
        case .project: return "Project"
        case .workspace: return "Workspace"
        case .account: return "Account"
        case .global: return "Global"
        }
    }

    public var priority: Int {
        switch self {
        case .project: return 4
        case .workspace: return 3
        case .account: return 2
        case .global: return 1
        }
    }
}

// MARK: - Project Knowledge Item

/// A piece of knowledge/instruction for the agent
public struct ProjectKnowledgeItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var content: String
    public var scope: ProjectKnowledgeScope
    public var category: ProjectKnowledgeCategory
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var tags: [String]
    public var appliesTo: [String]  // File patterns this knowledge applies to

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        scope: ProjectKnowledgeScope,
        category: ProjectKnowledgeCategory = .general,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = [],
        appliesTo: [String] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.scope = scope
        self.category = category
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.appliesTo = appliesTo
    }
}

public enum ProjectKnowledgeCategory: String, Codable, Sendable, CaseIterable {
    case general
    case guidelines       // Project guidelines and priorities
    case personas         // User personas and target audience
    case design          // Design assets, colors, typography
    case coding          // Coding conventions and patterns
    case security        // Security practices
    case compliance      // Legal/regulatory requirements
    case architecture    // Architecture decisions
    case integrations    // External APIs and tools
    case testing         // Testing requirements
    case documentation   // Documentation standards

    public var displayName: String {
        switch self {
        case .general: return "General"
        case .guidelines: return "Guidelines"
        case .personas: return "User Personas"
        case .design: return "Design"
        case .coding: return "Coding"
        case .security: return "Security"
        case .compliance: return "Compliance"
        case .architecture: return "Architecture"
        case .integrations: return "Integrations"
        case .testing: return "Testing"
        case .documentation: return "Documentation"
        }
    }

    public var icon: String {
        switch self {
        case .general: return "doc.text"
        case .guidelines: return "checklist"
        case .personas: return "person.2"
        case .design: return "paintbrush"
        case .coding: return "curlybraces"
        case .security: return "lock.shield"
        case .compliance: return "checkmark.seal"
        case .architecture: return "building.2"
        case .integrations: return "link"
        case .testing: return "testtube.2"
        case .documentation: return "doc.richtext"
        }
    }
}

// MARK: - Knowledge Manager

/// Central manager for all knowledge across scopes
@MainActor
public final class ProjectKnowledgeManager: ObservableObject {
    public static let shared = ProjectKnowledgeManager()

    private let logger = Logger(subsystem: "com.thea.v2", category: "ProjectKnowledgeManager")

    /// All knowledge items indexed by scope
    @Published public private(set) var knowledge: [ProjectKnowledgeScope: [ProjectKnowledgeItem]] = [
        .project: [],
        .workspace: [],
        .account: [],
        .global: []
    ]

    /// Currently active project path
    @Published public var currentProjectPath: URL?

    /// Currently active workspace path
    @Published public var currentWorkspacePath: URL?

    // Paths
    private var globalKnowledgePath: URL {
        #if os(macOS)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".thea/knowledge")
        #else
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea/knowledge")
        #endif
    }

    private var accountKnowledgePath: URL {
        #if os(macOS)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".thea/account_knowledge.json")
        #else
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea/account_knowledge.json")
        #endif
    }

    private init() {
        Task {
            await loadGlobalKnowledge()
            await loadAccountKnowledge()
        }
    }

    // MARK: - Loading

    /// Load global knowledge (defaults from Thea)
    private func loadGlobalKnowledge() async {
        // Built-in global knowledge
        let builtins = [
            ProjectKnowledgeItem(
                title: "Error Handling",
                content: """
                Always include proper error handling:
                - Use Swift's Result type or throws for functions that can fail
                - Provide meaningful error messages
                - Log errors for debugging
                - Never silently fail
                """,
                scope: .global,
                category: .coding
            ),
            ProjectKnowledgeItem(
                title: "Documentation Standards",
                content: """
                Follow these documentation standards:
                - Add /// documentation comments to public APIs
                - Include parameter descriptions and return values
                - Provide usage examples for complex functions
                - Keep comments up to date with code changes
                """,
                scope: .global,
                category: .documentation
            ),
            ProjectKnowledgeItem(
                title: "Security Best Practices",
                content: """
                Follow security best practices:
                - Never hardcode credentials or API keys
                - Use Keychain for sensitive data storage
                - Validate all user input
                - Use HTTPS for all network requests
                - Implement proper authentication and authorization
                """,
                scope: .global,
                category: .security
            )
        ]

        knowledge[.global] = builtins
        logger.info("Loaded \(builtins.count) global knowledge items")
    }

    /// Load account-level knowledge
    private func loadAccountKnowledge() async {
        guard FileManager.default.fileExists(atPath: accountKnowledgePath.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: accountKnowledgePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([ProjectKnowledgeItem].self, from: data)
            knowledge[.account] = items
            logger.info("Loaded \(items.count) account knowledge items")
        } catch {
            logger.error("Failed to load account knowledge: \(error.localizedDescription)")
        }
    }

    /// Load workspace knowledge from .thea/knowledge/
    public func loadWorkspaceKnowledge(from workspacePath: URL) async {
        currentWorkspacePath = workspacePath
        let knowledgePath = workspacePath.appendingPathComponent(".thea/knowledge.json")

        guard FileManager.default.fileExists(atPath: knowledgePath.path) else {
            // Also try loading from THEA.md if knowledge.json doesn't exist
            await loadFromTheaMd(in: workspacePath, scope: .workspace)
            return
        }

        do {
            let data = try Data(contentsOf: knowledgePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([ProjectKnowledgeItem].self, from: data)
            knowledge[.workspace] = items
            logger.info("Loaded \(items.count) workspace knowledge items")
        } catch {
            logger.error("Failed to load workspace knowledge: \(error.localizedDescription)")
        }
    }

    /// Load project knowledge from current directory
    public func loadProjectKnowledge(from projectPath: URL) async {
        currentProjectPath = projectPath
        let knowledgePath = projectPath.appendingPathComponent(".thea/knowledge.json")

        guard FileManager.default.fileExists(atPath: knowledgePath.path) else {
            // Try loading from THEA.md
            await loadFromTheaMd(in: projectPath, scope: .project)
            return
        }

        do {
            let data = try Data(contentsOf: knowledgePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([ProjectKnowledgeItem].self, from: data)
            knowledge[.project] = items
            logger.info("Loaded \(items.count) project knowledge items")
        } catch {
            logger.error("Failed to load project knowledge: \(error.localizedDescription)")
        }
    }

    /// Load knowledge from THEA.md file (similar to CLAUDE.md)
    private func loadFromTheaMd(in directory: URL, scope: ProjectKnowledgeScope) async {
        let theaMdPath = directory.appendingPathComponent("THEA.md")

        guard FileManager.default.fileExists(atPath: theaMdPath.path) else {
            return
        }

        do {
            let content = try String(contentsOf: theaMdPath, encoding: .utf8)
            let item = ProjectKnowledgeItem(
                title: "THEA.md Instructions",
                content: content,
                scope: scope,
                category: .general
            )
            knowledge[scope] = [item]
            logger.info("Loaded THEA.md for \(scope.displayName)")
        } catch {
            logger.error("Failed to load THEA.md: \(error.localizedDescription)")
        }
    }

    // MARK: - Saving

    /// Save knowledge for a scope
    public func save(scope: ProjectKnowledgeScope) async throws {
        let items = knowledge[scope] ?? []
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(items)

        let path: URL
        switch scope {
        case .global:
            // Create directory if needed
            if !FileManager.default.fileExists(atPath: globalKnowledgePath.path) {
                try FileManager.default.createDirectory(
                    at: globalKnowledgePath,
                    withIntermediateDirectories: true
                )
            }
            path = globalKnowledgePath.appendingPathComponent("knowledge.json")

        case .account:
            path = accountKnowledgePath

        case .workspace:
            guard let workspace = currentWorkspacePath else {
                throw ProjectKnowledgeError.noWorkspaceSet
            }
            let theaDir = workspace.appendingPathComponent(".thea")
            if !FileManager.default.fileExists(atPath: theaDir.path) {
                try FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
            }
            path = theaDir.appendingPathComponent("knowledge.json")

        case .project:
            guard let project = currentProjectPath else {
                throw ProjectKnowledgeError.noProjectSet
            }
            let theaDir = project.appendingPathComponent(".thea")
            if !FileManager.default.fileExists(atPath: theaDir.path) {
                try FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
            }
            path = theaDir.appendingPathComponent("knowledge.json")
        }

        try data.write(to: path)
        logger.info("Saved \(items.count) \(scope.displayName) knowledge items")
    }

    // MARK: - CRUD Operations

    /// Add a knowledge item
    public func add(_ item: ProjectKnowledgeItem) {
        var items = knowledge[item.scope] ?? []
        items.append(item)
        knowledge[item.scope] = items
        logger.info("Added knowledge item: \(item.title)")
    }

    /// Update a knowledge item
    public func update(_ item: ProjectKnowledgeItem) {
        guard var items = knowledge[item.scope] else { return }

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updated = item
            updated.updatedAt = Date()
            items[index] = updated
            knowledge[item.scope] = items
            logger.info("Updated knowledge item: \(item.title)")
        }
    }

    /// Delete a knowledge item
    public func delete(_ item: ProjectKnowledgeItem) {
        guard var items = knowledge[item.scope] else { return }

        items.removeAll { $0.id == item.id }
        knowledge[item.scope] = items
        logger.info("Deleted knowledge item: \(item.title)")
    }

    /// Toggle enabled state
    public func toggleEnabled(_ item: ProjectKnowledgeItem) {
        var updated = item
        updated.isEnabled = !item.isEnabled
        update(updated)
    }

    // MARK: - Query

    /// Get all enabled knowledge for current context, merged by priority
    public func activeKnowledge(for filePath: String? = nil) -> [ProjectKnowledgeItem] {
        var result: [ProjectKnowledgeItem] = []

        // Add items from all scopes, higher priority first
        for scope in ProjectKnowledgeScope.allCases.sorted(by: { $0.priority > $1.priority }) {
            guard let items = knowledge[scope] else { continue }

            for item in items where item.isEnabled {
                // Check if item applies to this file
                if let path = filePath, !item.appliesTo.isEmpty {
                    let matches = item.appliesTo.contains { pattern in
                        matchesGlob(pattern: pattern, path: path)
                    }
                    if !matches { continue }
                }

                result.append(item)
            }
        }

        return result
    }

    /// Get knowledge by category
    public func knowledge(category: ProjectKnowledgeCategory) -> [ProjectKnowledgeItem] {
        ProjectKnowledgeScope.allCases.flatMap { scope in
            (knowledge[scope] ?? []).filter { $0.category == category }
        }
    }

    /// Get knowledge by tag
    public func knowledge(withTag tag: String) -> [ProjectKnowledgeItem] {
        ProjectKnowledgeScope.allCases.flatMap { scope in
            (knowledge[scope] ?? []).filter { $0.tags.contains(tag) }
        }
    }

    /// Build system prompt additions from active knowledge
    public func buildSystemPromptAdditions(for filePath: String? = nil) -> String {
        let items = activeKnowledge(for: filePath)

        guard !items.isEmpty else { return "" }

        var prompt = "\n\n## Custom Instructions\n\n"

        // Group by category
        let grouped = Dictionary(grouping: items) { $0.category }

        for (category, categoryItems) in grouped.sorted(by: { $0.key.displayName < $1.key.displayName }) {
            prompt += "### \(category.displayName)\n\n"
            for item in categoryItems {
                prompt += "\(item.content)\n\n"
            }
        }

        return prompt
    }

    // MARK: - Helpers

    private func matchesGlob(pattern: String, path: String) -> Bool {
        let regex = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")

        return path.range(of: "^\(regex)$", options: .regularExpression) != nil
    }
}

// MARK: - Errors

public enum ProjectKnowledgeError: Error, LocalizedError {
    case noWorkspaceSet
    case noProjectSet
    case saveFailed(String)
    case loadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noWorkspaceSet:
            return "No workspace path set"
        case .noProjectSet:
            return "No project path set"
        case .saveFailed(let reason):
            return "Failed to save knowledge: \(reason)"
        case .loadFailed(let reason):
            return "Failed to load knowledge: \(reason)"
        }
    }
}
