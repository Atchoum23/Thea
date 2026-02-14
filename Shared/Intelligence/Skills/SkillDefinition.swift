// SkillDefinition.swift
// Thea V2
//
// Skills system for extending agent capabilities
// Inspired by:
// - Claude Code: Skills with SKILL.md files
// - Antigravity: Agent Skills open standard
// - Codex: AGENTS.md custom instructions
// - Cursor: Custom subagent configuration

import Foundation
import OSLog

// MARK: - Skill Definition

/// A skill that extends agent capabilities
/// Skills are reusable packages of knowledge and instructions
public struct SkillDefinition: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let instructions: String
    public let scope: SkillScope
    public let triggers: [SkillTrigger]
    public let resources: [SkillResource]
    public let createdAt: Date
    public var lastUsed: Date?
    public var usageCount: Int

    public init(
        id: String? = nil,
        name: String,
        description: String,
        instructions: String,
        scope: SkillScope = .workspace,
        triggers: [SkillTrigger] = [],
        resources: [SkillResource] = [],
        createdAt: Date = Date(),
        lastUsed: Date? = nil,
        usageCount: Int = 0
    ) {
        self.id = id ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.description = description
        self.instructions = instructions
        self.scope = scope
        self.triggers = triggers
        self.resources = resources
        self.createdAt = createdAt
        self.lastUsed = lastUsed
        self.usageCount = usageCount
    }
}

// MARK: - Skill Scope

/// Where the skill is available
public enum SkillScope: String, Codable, Sendable {
    /// Available only in a specific workspace/project
    case workspace

    /// Available globally across all projects
    case global

    /// Built-in skill provided by Thea
    case builtin
}

// MARK: - Skill Trigger

/// What activates the skill
public struct SkillTrigger: Codable, Sendable {
    public let type: TriggerType
    public let pattern: String

    public init(type: TriggerType, pattern: String) {
        self.type = type
        self.pattern = pattern
    }

    public enum TriggerType: String, Codable, Sendable {
        /// Explicit slash command (e.g., /review)
        case slashCommand

        /// Keyword in user query
        case keyword

        /// Task type classification
        case taskType

        /// File pattern (glob)
        case filePattern

        /// Always active
        case always
    }
}

// MARK: - Skill Resource

/// Additional resources available to the skill
public struct SkillResource: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let type: ResourceType
    public let source: ResourceSource
    public let description: String?

    public init(
        name: String,
        type: ResourceType,
        source: ResourceSource,
        description: String? = nil
    ) {
        self.name = name
        self.type = type
        self.source = source
        self.description = description
    }

    /// Convenience initializer for file-based resources
    public init(type: ResourceType, path: String, description: String? = nil) {
        self.name = URL(fileURLWithPath: path).lastPathComponent
        self.type = type
        self.source = .file(path: path)
        self.description = description
    }

    public enum ResourceType: String, Codable, Sendable {
        /// Script file
        case script

        /// Example file
        case example

        /// Template file
        case template

        /// Documentation
        case documentation
    }

    public enum ResourceSource: Codable, Sendable, Equatable {
        /// Resource stored in a file
        case file(path: String)

        /// Resource with embedded content
        case embedded(content: String)

        /// Resource at a URL
        case url(URL)
    }
}

// MARK: - Skill Registry

/// Central registry for all available skills
@MainActor
public final class SkillRegistry: ObservableObject {
    public static let shared = SkillRegistry()

    private let logger = Logger(subsystem: "com.thea.v2", category: "SkillRegistry")

    @Published public private(set) var skills: [String: SkillDefinition] = [:]
    @Published public private(set) var globalSkills: [SkillDefinition] = []
    @Published public private(set) var workspaceSkills: [String: [SkillDefinition]] = [:]

    /// Global skills directory
    private var globalSkillsPath: URL {
        #if os(macOS)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".thea/skills")
        #else
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea/skills")
        #endif
    }

    private init() {
        Task {
            await loadBuiltinSkills()
            await loadGlobalSkills()
        }
    }

    // MARK: - Loading

    /// Load built-in skills
    private func loadBuiltinSkills() async {
        let builtinSkills = makeCodeReviewSkills() + makeGenerationSkills() + makeDocumentationSkills()

        for skill in builtinSkills {
            skills[skill.id] = skill
        }

        logger.info("Loaded \(builtinSkills.count) built-in skills")
    }

    private func makeCodeReviewSkills() -> [SkillDefinition] {
        [
            SkillDefinition(
                name: "Code Review",
                description: "Reviews code for best practices, bugs, and improvements",
                instructions: """
                When reviewing code:
                1. Check for common bugs and logic errors
                2. Evaluate code style and readability
                3. Look for security vulnerabilities
                4. Suggest performance improvements
                5. Verify error handling
                6. Check for proper documentation
                """,
                scope: .builtin,
                triggers: [
                    SkillTrigger(type: .slashCommand, pattern: "review"),
                    SkillTrigger(type: .keyword, pattern: "review code"),
                    SkillTrigger(type: .keyword, pattern: "code review")
                ]
            ),
            SkillDefinition(
                name: "Explain Code",
                description: "Explains code using visual diagrams and analogies",
                instructions: """
                When explaining code:
                1. Start with a high-level overview
                2. Use analogies to explain complex concepts
                3. Break down the code into logical sections
                4. Explain the data flow
                5. Highlight key patterns and techniques
                """,
                scope: .builtin,
                triggers: [
                    SkillTrigger(type: .slashCommand, pattern: "explain"),
                    SkillTrigger(type: .keyword, pattern: "explain this"),
                    SkillTrigger(type: .keyword, pattern: "how does this work")
                ]
            )
        ]
    }

    private func makeGenerationSkills() -> [SkillDefinition] {
        [
            SkillDefinition(
                name: "Generate Tests",
                description: "Generates unit tests for code",
                instructions: """
                When generating tests:
                1. Identify the function/method to test
                2. List all possible inputs and edge cases
                3. Write test cases for happy paths
                4. Write test cases for error conditions
                5. Follow the project's testing conventions
                6. Use appropriate assertion methods
                """,
                scope: .builtin,
                triggers: [
                    SkillTrigger(type: .slashCommand, pattern: "test"),
                    SkillTrigger(type: .keyword, pattern: "generate tests"),
                    SkillTrigger(type: .keyword, pattern: "write tests"),
                    SkillTrigger(type: .taskType, pattern: "testGeneration")
                ]
            ),
            SkillDefinition(
                name: "Refactor Code",
                description: "Refactors code for better structure and maintainability",
                instructions: """
                When refactoring:
                1. Understand the current code's purpose
                2. Identify code smells and issues
                3. Plan the refactoring approach
                4. Make incremental changes
                5. Ensure behavior is preserved
                6. Update related documentation
                """,
                scope: .builtin,
                triggers: [
                    SkillTrigger(type: .slashCommand, pattern: "refactor"),
                    SkillTrigger(type: .taskType, pattern: "codeRefactoring")
                ]
            )
        ]
    }

    private func makeDocumentationSkills() -> [SkillDefinition] {
        [
            SkillDefinition(
                name: "Document Code",
                description: "Generates documentation for code",
                instructions: """
                When documenting:
                1. Write clear, concise descriptions
                2. Document parameters and return values
                3. Include usage examples
                4. Note any side effects or preconditions
                5. Follow the project's documentation style
                """,
                scope: .builtin,
                triggers: [
                    SkillTrigger(type: .slashCommand, pattern: "document"),
                    SkillTrigger(type: .keyword, pattern: "add documentation")
                ]
            )
        ]
    }

    /// Load global skills from ~/.thea/skills/
    private func loadGlobalSkills() async {
        guard FileManager.default.fileExists(atPath: globalSkillsPath.path) else {
            logger.debug("Global skills directory not found, skipping")
            return
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: globalSkillsPath,
                includingPropertiesForKeys: [.isDirectoryKey]
            )

            for itemURL in contents {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    if let skill = await loadSkillFromDirectory(itemURL, scope: .global) {
                        skills[skill.id] = skill
                        globalSkills.append(skill)
                    }
                }
            }

            logger.info("Loaded \(self.globalSkills.count) global skills")
        } catch {
            logger.error("Failed to load global skills: \(error.localizedDescription)")
        }
    }

    /// Load workspace skills from <workspace>/.thea/skills/
    public func loadWorkspaceSkills(from workspacePath: URL) async {
        let skillsPath = workspacePath.appendingPathComponent(".thea/skills")

        guard FileManager.default.fileExists(atPath: skillsPath.path) else {
            return
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: skillsPath,
                includingPropertiesForKeys: [.isDirectoryKey]
            )

            var loadedSkills: [SkillDefinition] = []

            for itemURL in contents {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    if let skill = await loadSkillFromDirectory(itemURL, scope: .workspace) {
                        skills[skill.id] = skill
                        loadedSkills.append(skill)
                    }
                }
            }

            workspaceSkills[workspacePath.path] = loadedSkills
            logger.info("Loaded \(loadedSkills.count) workspace skills from \(workspacePath.lastPathComponent)")
        } catch {
            logger.error("Failed to load workspace skills: \(error.localizedDescription)")
        }
    }

    /// Load a skill from a directory containing SKILL.md
    private func loadSkillFromDirectory(_ directory: URL, scope: SkillScope) async -> SkillDefinition? {
        let skillFile = directory.appendingPathComponent("SKILL.md")

        guard FileManager.default.fileExists(atPath: skillFile.path) else {
            // Also check for lowercase
            let altFile = directory.appendingPathComponent("skill.md")
            guard FileManager.default.fileExists(atPath: altFile.path) else {
                return nil
            }
            return await parseSkillFile(altFile, scope: scope)
        }

        return await parseSkillFile(skillFile, scope: scope)
    }

    /// Parse a SKILL.md file
    private func parseSkillFile(_ file: URL, scope: SkillScope) async -> SkillDefinition? {
        do {
            let content = try String(contentsOf: file, encoding: .utf8)

            // Parse YAML frontmatter
            let (frontmatter, body) = parseMarkdownWithFrontmatter(content)

            let name = frontmatter["name"] ?? file.deletingLastPathComponent().lastPathComponent
            let description = frontmatter["description"] ?? "Custom skill"

            // Parse triggers from frontmatter
            var triggers: [SkillTrigger] = []
            if let triggerStrings = frontmatter["triggers"]?.components(separatedBy: ",") {
                for trigger in triggerStrings {
                    let trimmed = trigger.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("/") {
                        triggers.append(SkillTrigger(type: .slashCommand, pattern: String(trimmed.dropFirst())))
                    } else {
                        triggers.append(SkillTrigger(type: .keyword, pattern: trimmed))
                    }
                }
            }

            // Load resources
            let resources = await loadSkillResources(from: file.deletingLastPathComponent())

            return SkillDefinition(
                id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
                name: name,
                description: description,
                instructions: body,
                scope: scope,
                triggers: triggers,
                resources: resources
            )
        } catch {
            logger.error("Failed to parse skill file \(file.path): \(error.localizedDescription)")
            return nil
        }
    }

    /// Parse markdown with YAML frontmatter
    private func parseMarkdownWithFrontmatter(_ content: String) -> ([String: String], String) {
        var frontmatter: [String: String] = [:]
        var body = content

        if content.hasPrefix("---") {
            let lines = content.components(separatedBy: .newlines)
            var inFrontmatter = false
            var frontmatterEnd = 0

            for (index, line) in lines.enumerated() {
                if line == "---" {
                    if inFrontmatter {
                        frontmatterEnd = index
                        break
                    } else {
                        inFrontmatter = true
                        continue
                    }
                }

                if inFrontmatter {
                    let parts = line.components(separatedBy: ":")
                    if parts.count >= 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespaces)
                        let value = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                        frontmatter[key] = value
                    }
                }
            }

            if frontmatterEnd > 0 {
                body = lines.dropFirst(frontmatterEnd + 1).joined(separator: "\n")
            }
        }

        return (frontmatter, body)
    }

    /// Load additional resources from skill directory
    private func loadSkillResources(from directory: URL) async -> [SkillResource] {
        var resources: [SkillResource] = []

        let subdirs = ["scripts", "examples", "templates", "resources"]
        let typeMap: [String: SkillResource.ResourceType] = [
            "scripts": .script,
            "examples": .example,
            "templates": .template,
            "resources": .documentation
        ]

        for subdir in subdirs {
            let subdirPath = directory.appendingPathComponent(subdir)
            guard FileManager.default.fileExists(atPath: subdirPath.path) else { continue }

            do {
                let files = try FileManager.default.contentsOfDirectory(at: subdirPath, includingPropertiesForKeys: nil)
                for file in files {
                    resources.append(SkillResource(
                        type: typeMap[subdir] ?? .documentation,
                        path: file.path,
                        description: file.lastPathComponent
                    ))
                }
            } catch {
                continue
            }
        }

        return resources
    }

    // MARK: - Skill Matching

    /// Find matching skills for a query
    public func findMatchingSkills(
        for query: String,
        taskType: TaskType? = nil,
        currentFile: String? = nil
    ) -> [SkillDefinition] {
        var matches: [SkillDefinition] = []

        for skill in skills.values {
            for trigger in skill.triggers {
                let isMatch: Bool

                switch trigger.type {
                case .slashCommand:
                    isMatch = query.lowercased().hasPrefix("/\(trigger.pattern)")

                case .keyword:
                    isMatch = query.lowercased().contains(trigger.pattern.lowercased())

                case .taskType:
                    isMatch = taskType?.rawValue == trigger.pattern

                case .filePattern:
                    if let file = currentFile {
                        // Simple glob matching
                        isMatch = matchGlob(pattern: trigger.pattern, against: file)
                    } else {
                        isMatch = false
                    }

                case .always:
                    isMatch = true
                }

                if isMatch {
                    matches.append(skill)
                    break
                }
            }
        }

        return matches
    }

    /// Simple glob matching
    private func matchGlob(pattern: String, against string: String) -> Bool {
        let regex = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")

        return string.range(of: "^\(regex)$", options: .regularExpression) != nil
    }

    // MARK: - Skill Management

    /// Register a new skill
    public func register(_ skill: SkillDefinition) {
        skills[skill.id] = skill

        switch skill.scope {
        case .global:
            if !globalSkills.contains(where: { $0.id == skill.id }) {
                globalSkills.append(skill)
            }
        case .workspace:
            // Would need workspace path to properly categorize
            break
        case .builtin:
            break
        }

        logger.info("Registered skill: \(skill.name)")
    }

    /// Get skill by ID
    public func skill(id: String) -> SkillDefinition? {
        skills[id]
    }

    /// Get skill by slash command
    public func skill(forCommand command: String) -> SkillDefinition? {
        skills.values.first { skill in
            skill.triggers.contains { trigger in
                trigger.type == .slashCommand && trigger.pattern == command
            }
        }
    }

    /// Record skill usage
    public func recordUsage(skillId: String) {
        if var skill = skills[skillId] {
            skill.lastUsed = Date()
            skill.usageCount += 1
            skills[skillId] = skill
        }
    }

    /// Get all available skills sorted by usage
    public var sortedSkills: [SkillDefinition] {
        Array(skills.values).sorted { ($0.usageCount, $0.name) > ($1.usageCount, $1.name) }
    }

    // MARK: - Extended Skill Matching (for IntelligenceOrchestrator)

    /// Find matching skills for a task type
    public func findMatchingSkills(for taskType: TaskType) -> [SkillDefinition] {
        skills.values.filter { skill in
            skill.triggers.contains { trigger in
                trigger.type == .taskType && trigger.pattern == taskType.rawValue
            }
        }
    }

    /// Find matching skills for a file pattern
    public func findMatchingSkills(forFile file: String) -> [SkillDefinition] {
        skills.values.filter { skill in
            skill.triggers.contains { trigger in
                trigger.type == .filePattern && matchGlob(pattern: trigger.pattern, against: file)
            }
        }
    }

    /// Find matching skills by keywords in a query
    public func findMatchingSkills(forQuery query: String) -> [SkillDefinition] {
        let lowercasedQuery = query.lowercased()
        return skills.values.filter { skill in
            skill.triggers.contains { trigger in
                switch trigger.type {
                case .slashCommand:
                    return lowercasedQuery.hasPrefix("/\(trigger.pattern)")
                case .keyword:
                    return lowercasedQuery.contains(trigger.pattern.lowercased())
                case .always:
                    return true
                default:
                    return false
                }
            }
        }
    }

    /// Get all skills that are always active
    public func getAlwaysActiveSkills() -> [SkillDefinition] {
        skills.values.filter { skill in
            skill.triggers.contains { $0.type == .always }
        }
    }
}
