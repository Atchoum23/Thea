//
//  SkillsRegistry.swift
//  Thea
//
//  Skills Registry and Marketplace inspired by Smithery and Context7
//  Provides searchable skills with reviews, votes, and dependency suggestions
//

import Foundation
import OSLog

// MARK: - Skills Registry Service

/// Central registry for discovering, installing, and managing skills
/// Inspired by Smithery's marketplace and Context7's skills system
@MainActor
public final class SkillsRegistryService: ObservableObject {
    public static let shared = SkillsRegistryService()

    private let logger = Logger(subsystem: "app.thea", category: "SkillsRegistry")

    // MARK: - Published State

    @Published public private(set) var marketplaceSkills: [MarketplaceSkill] = []
    @Published public private(set) var installedSkills: [InstalledSkill] = []
    @Published public private(set) var suggestedSkills: [MarketplaceSkill] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastSyncedAt: Date?

    // MARK: - Configuration

    private let cacheURL: URL
    private let installedSkillsURL: URL
    private var dependencyScanner: DependencyScanner?

    // MARK: - Initialization

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let theaDir = appSupport.appendingPathComponent("Thea/skills")

        cacheURL = theaDir.appendingPathComponent("marketplace_cache.json")
        installedSkillsURL = theaDir.appendingPathComponent("installed.json")

        // Create directories
        do {
            try FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create skills directory: \(error.localizedDescription)")
        }

        Task {
            await loadInstalledSkills()
            await loadMarketplaceCache()
        }
    }

    // MARK: - Search

    /// Search marketplace for skills
    public func search(query: String, category: MarketplaceSkillCategory? = nil, limit: Int = 20) async throws -> [MarketplaceSkill] {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)

        // Filter locally first (fast)
        var results = marketplaceSkills.filter { skill in
            let matchesQuery = normalizedQuery.isEmpty ||
                skill.name.lowercased().contains(normalizedQuery) ||
                skill.description.lowercased().contains(normalizedQuery) ||
                skill.tags.contains { $0.lowercased().contains(normalizedQuery) }

            let matchesCategory = category == nil || skill.category == category

            return matchesQuery && matchesCategory
        }

        // Sort by relevance (trust score + downloads)
        results.sort { lhs, rhs in
            let lhsScore = Double(lhs.trustScore) + log10(Double(max(1, lhs.downloads)))
            let rhsScore = Double(rhs.trustScore) + log10(Double(max(1, rhs.downloads)))
            return lhsScore > rhsScore
        }

        return Array(results.prefix(limit))
    }

    /// Get skill by ID
    public func getSkill(id: String) -> MarketplaceSkill? {
        marketplaceSkills.first { $0.id == id }
    }

    // MARK: - Dependency-Based Suggestions (Context7 Feature)

    /// Scan project dependencies and suggest relevant skills
    public func suggestSkillsForProject(at path: URL) async -> [MarketplaceSkill] {
        let scanner = DependencyScanner()
        let dependencies = await scanner.scanDependencies(at: path)

        var suggestions: [MarketplaceSkill] = []

        for dependency in dependencies {
            // Find skills that match this dependency
            let matches = marketplaceSkills.filter { skill in
                skill.relatedLibraries.contains { lib in
                    lib.lowercased() == dependency.name.lowercased()
                }
            }
            suggestions.append(contentsOf: matches)
        }

        // Remove duplicates and sort by trust score
        let uniqueSkills = Dictionary(grouping: suggestions, by: \.id)
            .compactMapValues { $0.first }
            .values
            .sorted { $0.trustScore > $1.trustScore }

        suggestedSkills = Array(uniqueSkills.prefix(10))
        return suggestedSkills
    }

    // MARK: - Install/Uninstall

    /// Install a skill from the marketplace
    public func install(_ skill: MarketplaceSkill, scope: SkillInstallScope = .global) async throws -> InstalledSkill {
        logger.info("Installing skill: \(skill.name) with scope: \(scope.rawValue)")

        // Create installed skill
        let installed = InstalledSkill(
            id: skill.id,
            marketplaceId: skill.id,
            name: skill.name,
            description: skill.description,
            instructions: skill.instructions,
            scope: scope,
            installedAt: Date(),
            version: skill.version,
            trustScore: skill.trustScore
        )

        // Save to appropriate location
        switch scope {
        case .global:
            installedSkills.append(installed)
            try saveInstalledSkills()

        case .project(let path):
            try await saveToProject(installed, at: URL(fileURLWithPath: path))
        }

        // Register with SkillRegistry
        let definition = installed.toSkillDefinition()
        SkillRegistry.shared.register(definition)

        logger.info("Successfully installed skill: \(skill.name)")
        return installed
    }

    /// Uninstall a skill
    public func uninstall(skillId: String) async throws {
        installedSkills.removeAll { $0.id == skillId }
        try saveInstalledSkills()
        logger.info("Uninstalled skill: \(skillId)")
    }

    // MARK: - Reviews & Votes (Smithery Feature)

    /// Get reviews for a skill
    public func getReviews(skillId: String) async throws -> [SkillReview] {
        // In production, this would fetch from API
        []
    }

    /// Submit a vote for a skill
    public func vote(skillId: String, voteType: VoteType) async throws {
        // In production, this would submit to API
        logger.info("Submitted \(voteType.rawValue) vote for skill: \(skillId)")
    }

    /// Submit a review for a skill
    public func submitReview(skillId: String, rating: Int, comment: String) async throws {
        // In production, this would submit to API
        logger.info("Submitted review for skill: \(skillId) with rating: \(rating)")
    }

    // MARK: - Sync & Cache

    /// Sync marketplace from remote
    public func syncMarketplace() async throws {
        isLoading = true
        defer { isLoading = false }

        // In production, fetch from Smithery/Context7 APIs
        // For now, use built-in skills as marketplace
        marketplaceSkills = getBuiltinMarketplaceSkills()
        lastSyncedAt = Date()

        try saveMarketplaceCache()
        logger.info("Synced marketplace: \(self.marketplaceSkills.count) skills")
    }

    private func loadMarketplaceCache() async {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            // Load defaults
            marketplaceSkills = getBuiltinMarketplaceSkills()
            return
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            let cache = try JSONDecoder().decode(MarketplaceCache.self, from: data)
            marketplaceSkills = cache.skills
            lastSyncedAt = cache.syncedAt
        } catch {
            logger.error("Failed to load marketplace cache: \(error.localizedDescription)")
            marketplaceSkills = getBuiltinMarketplaceSkills()
        }
    }

    private func saveMarketplaceCache() throws {
        let cache = MarketplaceCache(skills: marketplaceSkills, syncedAt: Date())
        let data = try JSONEncoder().encode(cache)
        try data.write(to: cacheURL)
    }

    private func loadInstalledSkills() async {
        guard FileManager.default.fileExists(atPath: installedSkillsURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: installedSkillsURL)
            installedSkills = try JSONDecoder().decode([InstalledSkill].self, from: data)
        } catch {
            logger.error("Failed to load installed skills: \(error.localizedDescription)")
        }
    }

    private func saveInstalledSkills() throws {
        let data = try JSONEncoder().encode(installedSkills)
        try data.write(to: installedSkillsURL)
    }

    private func saveToProject(_ skill: InstalledSkill, at projectPath: URL) async throws {
        let skillsDir = projectPath.appendingPathComponent(".thea/skills/\(skill.id)")
        try FileManager.default.createDirectory(at: skillsDir, withIntermediateDirectories: true)

        // Create SKILL.md file
        let skillMd = """
        ---
        name: \(skill.name)
        description: \(skill.description)
        version: \(skill.version)
        trustScore: \(skill.trustScore)
        ---

        \(skill.instructions)
        """

        let skillFile = skillsDir.appendingPathComponent("SKILL.md")
        try skillMd.write(to: skillFile, atomically: true, encoding: .utf8)
    }

    // MARK: - Built-in Marketplace Skills

    private func getBuiltinMarketplaceSkills() -> [MarketplaceSkill] {
        makeCodingSkills() + makeWorkflowSkills() + makeDocumentationSkills()
    }

    private func makeCodingSkills() -> [MarketplaceSkill] {
        [
            MarketplaceSkill(
                id: "swift-best-practices",
                name: "Swift Best Practices",
                description: "Apply Swift 6 best practices including strict concurrency, actors, and modern patterns",
                category: .coding,
                tags: ["swift", "ios", "macos", "concurrency", "best-practices"],
                author: "Thea",
                version: "1.0.0",
                downloads: 1500,
                trustScore: 9,
                relatedLibraries: ["swift", "swiftui", "combine"],
                instructions: """
                When writing Swift code:
                1. Use strict concurrency with actors for shared mutable state
                2. Prefer async/await over completion handlers
                3. Use value types (structs) over reference types when possible
                4. Apply proper error handling with typed throws
                5. Follow Swift API design guidelines for naming
                6. Use property wrappers appropriately
                """
            ),
            MarketplaceSkill(
                id: "react-patterns",
                name: "React Patterns",
                description: "Modern React patterns including hooks, suspense, and server components",
                category: .coding,
                tags: ["react", "javascript", "typescript", "frontend"],
                author: "Thea",
                version: "1.0.0",
                downloads: 2500,
                trustScore: 9,
                relatedLibraries: ["react", "next", "nextjs", "react-dom"],
                instructions: """
                When writing React code:
                1. Use functional components with hooks
                2. Apply proper state management (useState, useReducer)
                3. Use useEffect correctly with proper dependencies
                4. Implement proper memoization (useMemo, useCallback)
                5. Handle loading and error states appropriately
                6. Use TypeScript for type safety
                """
            ),
            MarketplaceSkill(
                id: "api-design",
                name: "REST API Design",
                description: "Design clean, consistent REST APIs following best practices",
                category: .architecture,
                tags: ["api", "rest", "http", "backend"],
                author: "Thea",
                version: "1.0.0",
                downloads: 1200,
                trustScore: 8,
                relatedLibraries: ["express", "fastify", "vapor", "flask"],
                instructions: """
                When designing REST APIs:
                1. Use proper HTTP methods (GET, POST, PUT, DELETE, PATCH)
                2. Return appropriate status codes
                3. Use consistent naming conventions (plural nouns for collections)
                4. Implement proper pagination for lists
                5. Version your API appropriately
                6. Document with OpenAPI/Swagger
                """
            )
        ]
    }

    private func makeWorkflowSkills() -> [MarketplaceSkill] {
        [
            MarketplaceSkill(
                id: "git-workflow",
                name: "Git Workflow",
                description: "Professional git workflow with conventional commits and branching",
                category: .devops,
                tags: ["git", "version-control", "workflow"],
                author: "Thea",
                version: "1.0.0",
                downloads: 3000,
                trustScore: 9,
                relatedLibraries: [],
                instructions: """
                When working with git:
                1. Use conventional commits (feat:, fix:, docs:, etc.)
                2. Keep commits atomic and focused
                3. Write descriptive commit messages
                4. Use feature branches for new work
                5. Rebase to keep history clean
                6. Use pull requests for code review
                """
            ),
            MarketplaceSkill(
                id: "security-review",
                name: "Security Review",
                description: "Review code for common security vulnerabilities",
                category: .security,
                tags: ["security", "owasp", "vulnerabilities"],
                author: "Thea",
                version: "1.0.0",
                downloads: 800,
                trustScore: 9,
                relatedLibraries: [],
                instructions: """
                When reviewing code for security:
                1. Check for injection vulnerabilities (SQL, XSS, command)
                2. Verify proper authentication and authorization
                3. Look for sensitive data exposure
                4. Check for insecure cryptography
                5. Verify input validation
                6. Check for security misconfigurations
                """
            )
        ]
    }

    private func makeDocumentationSkills() -> [MarketplaceSkill] {
        [
            MarketplaceSkill(
                id: "documentation-writer",
                name: "Documentation Writer",
                description: "Generate clear, comprehensive documentation",
                category: .documentation,
                tags: ["docs", "readme", "api-docs"],
                author: "Thea",
                version: "1.0.0",
                downloads: 1800,
                trustScore: 8,
                relatedLibraries: [],
                instructions: """
                When writing documentation:
                1. Start with a clear overview/summary
                2. Include installation/setup instructions
                3. Provide usage examples with code
                4. Document all public APIs
                5. Include troubleshooting section
                6. Keep documentation up-to-date with code
                """
            )
        ]
    }
}
