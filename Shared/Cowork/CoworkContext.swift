import Foundation

/// Context information for a Cowork session
/// Tracks files accessed, URLs visited, and environmental data
struct CoworkContext: Codable, Equatable {
    var accessedFiles: [FileAccess]
    var accessedURLs: [URLAccess]
    var activeConnectors: [String]
    var environmentVariables: [String: String]
    var userInstructions: String
    var systemPromptAdditions: String
    var customRules: [Rule]
    var workingDirectory: URL?

    struct FileAccess: Codable, Identifiable, Equatable {
        let id: UUID
        let url: URL
        let accessType: AccessType
        let accessedAt: Date
        var wasModified: Bool

        enum AccessType: String, Codable {
            case read, write, execute, delete
        }

        init(url: URL, accessType: AccessType, wasModified: Bool = false) {
            self.id = UUID()
            self.url = url
            self.accessType = accessType
            self.accessedAt = Date()
            self.wasModified = wasModified
        }
    }

    struct URLAccess: Codable, Identifiable, Equatable {
        let id: UUID
        let url: URL
        let accessedAt: Date
        var title: String?
        var wasCached: Bool

        init(url: URL, title: String? = nil, wasCached: Bool = false) {
            self.id = UUID()
            self.url = url
            self.accessedAt = Date()
            self.title = title
            self.wasCached = wasCached
        }
    }

    struct Rule: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        var description: String
        var isEnabled: Bool
        var priority: Int

        init(name: String, description: String, isEnabled: Bool = true, priority: Int = 0) {
            self.id = UUID()
            self.name = name
            self.description = description
            self.isEnabled = isEnabled
            self.priority = priority
        }
    }

    init(
        accessedFiles: [FileAccess] = [],
        accessedURLs: [URLAccess] = [],
        activeConnectors: [String] = [],
        environmentVariables: [String: String] = [:],
        userInstructions: String = "",
        systemPromptAdditions: String = "",
        customRules: [Rule] = [],
        workingDirectory: URL? = nil
    ) {
        self.accessedFiles = accessedFiles
        self.accessedURLs = accessedURLs
        self.activeConnectors = activeConnectors
        self.environmentVariables = environmentVariables
        self.userInstructions = userInstructions
        self.systemPromptAdditions = systemPromptAdditions
        self.customRules = customRules
        self.workingDirectory = workingDirectory
    }

    // MARK: - File Tracking

    mutating func trackFileRead(_ url: URL) {
        let access = FileAccess(url: url, accessType: .read)
        accessedFiles.append(access)
    }

    mutating func trackFileWrite(_ url: URL) {
        let access = FileAccess(url: url, accessType: .write, wasModified: true)
        accessedFiles.append(access)
    }

    mutating func trackFileDelete(_ url: URL) {
        let access = FileAccess(url: url, accessType: .delete, wasModified: true)
        accessedFiles.append(access)
    }

    // MARK: - URL Tracking

    mutating func trackURLAccess(_ url: URL, title: String? = nil) {
        let access = URLAccess(url: url, title: title)
        accessedURLs.append(access)
    }

    // MARK: - Connectors

    mutating func activateConnector(_ name: String) {
        if !activeConnectors.contains(name) {
            activeConnectors.append(name)
        }
    }

    mutating func deactivateConnector(_ name: String) {
        activeConnectors.removeAll { $0 == name }
    }

    // MARK: - Rules

    mutating func addRule(_ rule: Rule) {
        customRules.append(rule)
    }

    mutating func removeRule(_ ruleId: UUID) {
        customRules.removeAll { $0.id == ruleId }
    }

    var enabledRules: [Rule] {
        customRules.filter { $0.isEnabled }.sorted { $0.priority > $1.priority }
    }

    // MARK: - Summary

    var uniqueFilesAccessed: [URL] {
        Array(Set(accessedFiles.map(\.url)))
    }

    var modifiedFiles: [URL] {
        accessedFiles.filter(\.wasModified).map(\.url)
    }

    var uniqueURLsAccessed: [URL] {
        Array(Set(accessedURLs.map(\.url)))
    }

    /// Build context string for LLM prompt
    func buildContextPrompt() -> String {
        var parts: [String] = []

        if !userInstructions.isEmpty {
            parts.append("## User Instructions\n\(userInstructions)")
        }

        if !systemPromptAdditions.isEmpty {
            parts.append("## Additional Context\n\(systemPromptAdditions)")
        }

        if !enabledRules.isEmpty {
            let rulesText = enabledRules.map { "- \($0.name): \($0.description)" }.joined(separator: "\n")
            parts.append("## Active Rules\n\(rulesText)")
        }

        if let dir = workingDirectory {
            parts.append("## Working Directory\n\(dir.path)")
        }

        if !uniqueFilesAccessed.isEmpty {
            let filesText = uniqueFilesAccessed.prefix(20).map { "- \($0.lastPathComponent)" }.joined(separator: "\n")
            parts.append("## Recently Accessed Files\n\(filesText)")
        }

        if !activeConnectors.isEmpty {
            parts.append("## Active Connectors\n\(activeConnectors.joined(separator: ", "))")
        }

        return parts.joined(separator: "\n\n")
    }
}

// MARK: - Default Rules

extension CoworkContext.Rule {
    static var defaultRules: [CoworkContext.Rule] {
        [
            Rule(
                name: "Safe File Operations",
                description: "Always confirm before deleting files",
                isEnabled: true,
                priority: 100
            ),
            Rule(
                name: "Backup Before Modify",
                description: "Create backup before modifying important files",
                isEnabled: true,
                priority: 90
            ),
            Rule(
                name: "Respect .gitignore",
                description: "Don't process files listed in .gitignore",
                isEnabled: true,
                priority: 80
            ),
            Rule(
                name: "Skip Hidden Files",
                description: "Don't process files starting with .",
                isEnabled: false,
                priority: 70
            )
        ]
    }
}
