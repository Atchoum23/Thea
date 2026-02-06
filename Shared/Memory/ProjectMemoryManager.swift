//
//  ProjectMemoryManager.swift
//  Thea
//
//  Persistent Project Memory - remembers project context, patterns,
//  and preferences across sessions for intelligent assistance.
//
//  Copyright 2026. All rights reserved.
//

import Foundation
import SwiftUI
import os.log

// MARK: - Project Memory Types

/// Represents a remembered project/codebase
public struct ProjectMemory: Identifiable, Codable, Sendable, Hashable {
    public static func == (lhs: ProjectMemory, rhs: ProjectMemory) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public let id: UUID
    public var name: String
    public var path: String
    public var lastAccessed: Date
    public var accessCount: Int
    public var metadata: ProjectMetadata
    public var learnedPatterns: [LearnedPattern]
    public var keyFacts: [KeyFact]
    public var preferences: ProjectPreferences
    public var recentTopics: [String]
    public var relatedProjects: [UUID]

    public init(
        id: UUID = UUID(),
        name: String,
        path: String
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.lastAccessed = Date()
        self.accessCount = 1
        self.metadata = ProjectMetadata()
        self.learnedPatterns = []
        self.keyFacts = []
        self.preferences = ProjectPreferences()
        self.recentTopics = []
        self.relatedProjects = []
    }

    public mutating func recordAccess() {
        lastAccessed = Date()
        accessCount += 1
    }
}

/// Metadata about a project
public struct ProjectMetadata: Codable, Sendable {
    public var projectType: ProjectType = .unknown
    public var primaryLanguage: String?
    public var frameworks: [String] = []
    public var buildSystem: String?
    public var versionControl: String?
    public var teamSize: TeamSize = .unknown
    public var estimatedComplexity: Complexity = .unknown
    public var lastAnalyzed: Date?

    public enum ProjectType: String, Codable, Sendable {
        case ios, macos, watchos, tvos
        case web, backend, fullstack
        case library, framework
        case cli, script
        case dataScience, ml
        case unknown
    }

    public enum TeamSize: String, Codable, Sendable {
        case solo, small, medium, large, enterprise, unknown
    }

    public enum Complexity: String, Codable, Sendable {
        case simple, moderate, complex, veryComplex, unknown
    }
}

/// A pattern learned from user interactions
public struct LearnedPattern: Identifiable, Codable, Sendable {
    public let id: UUID
    public var patternType: PatternType
    public var description: String
    public var examples: [String]
    public var confidence: Double
    public var timesApplied: Int
    public var lastApplied: Date?
    public var createdAt: Date

    public enum PatternType: String, Codable, Sendable {
        case codingStyle       // How they write code
        case namingConvention  // Variable/function naming
        case errorHandling     // How they handle errors
        case testing          // Testing preferences
        case documentation    // Comment/doc style
        case architecture     // Design patterns used
        case workflow         // How they work
        case communication    // How they like responses
    }

    public init(
        id: UUID = UUID(),
        patternType: PatternType,
        description: String,
        examples: [String] = []
    ) {
        self.id = id
        self.patternType = patternType
        self.description = description
        self.examples = examples
        self.confidence = 0.5
        self.timesApplied = 0
        self.createdAt = Date()
    }

    public mutating func recordApplication() {
        timesApplied += 1
        lastApplied = Date()
        confidence = min(0.95, confidence + 0.05)
    }
}

/// A key fact remembered about a project
public struct KeyFact: Identifiable, Codable, Sendable {
    public let id: UUID
    public var category: FactCategory
    public var fact: String
    public var source: String?
    public var importance: Importance
    public var createdAt: Date
    public var confirmedAt: Date?
    public var isStale: Bool = false

    public enum FactCategory: String, Codable, Sendable {
        case architecture
        case dependency
        case convention
        case bug
        case todo
        case decision
        case context
        case person
        case deadline
        case other
    }

    public enum Importance: String, Codable, Sendable, Comparable {
        case low, medium, high, critical

        public static func < (lhs: Importance, rhs: Importance) -> Bool {
            let order: [Importance] = [.low, .medium, .high, .critical]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }

    public init(
        id: UUID = UUID(),
        category: FactCategory,
        fact: String,
        source: String? = nil,
        importance: Importance = .medium
    ) {
        self.id = id
        self.category = category
        self.fact = fact
        self.source = source
        self.importance = importance
        self.createdAt = Date()
    }
}

/// User preferences specific to a project
public struct ProjectPreferences: Codable, Sendable {
    public var preferredModel: String?
    public var responseStyle: ResponseStyle = .balanced
    public var detailLevel: DetailLevel = .standard
    public var codeBlockLanguage: String?
    public var autoFormat: Bool = true
    public var includeTodos: Bool = true
    public var suggestTests: Bool = true

    public enum ResponseStyle: String, Codable, Sendable {
        case concise, balanced, detailed, educational
    }

    public enum DetailLevel: String, Codable, Sendable {
        case minimal, standard, comprehensive
    }
}

// MARK: - Memory Summary

/// Summary of project memory for context injection
public struct MemorySummary: Sendable {
    public let projectName: String
    public let projectType: ProjectMetadata.ProjectType
    public let primaryLanguage: String?
    public let frameworks: [String]
    public let keyPatterns: [String]
    public let importantFacts: [String]
    public let recentTopics: [String]
    public let preferences: ProjectPreferences

    public var contextString: String {
        var parts: [String] = []

        parts.append("Project: \(projectName)")
        if let lang = primaryLanguage {
            parts.append("Language: \(lang)")
        }
        if !frameworks.isEmpty {
            parts.append("Frameworks: \(frameworks.joined(separator: ", "))")
        }
        if !keyPatterns.isEmpty {
            parts.append("Patterns: \(keyPatterns.joined(separator: "; "))")
        }
        if !importantFacts.isEmpty {
            parts.append("Key facts: \(importantFacts.joined(separator: "; "))")
        }
        if !recentTopics.isEmpty {
            parts.append("Recent topics: \(recentTopics.joined(separator: ", "))")
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - Project Memory Manager

/// Manages persistent project memory across sessions
@MainActor
public final class ProjectMemoryManager: ObservableObject {
    public static let shared = ProjectMemoryManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ProjectMemory")

    // MARK: - Published State

    @Published public private(set) var projects: [ProjectMemory] = []
    @Published public private(set) var currentProject: ProjectMemory?
    @Published public var isEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published public var maxFactsPerProject: Int = 100 {
        didSet { saveSettings() }
    }
    @Published public var maxPatternsPerProject: Int = 50 {
        didSet { saveSettings() }
    }

    // MARK: - Private State

    private let fileManager = FileManager.default
    private var autoSaveTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        loadProjects()
        loadSettings()
        startAutoSave()
        logger.info("ProjectMemoryManager initialized with \(self.projects.count) projects")
    }

    // MARK: - Public API

    /// Get or create a project memory
    public func getOrCreateProject(name: String, path: String) -> ProjectMemory {
        // Check if project already exists
        if let existingIndex = projects.firstIndex(where: { $0.path == path }) {
            projects[existingIndex].recordAccess()
            currentProject = projects[existingIndex]
            saveProjects()
            return projects[existingIndex]
        }

        // Create new project
        let newProject = ProjectMemory(name: name, path: path)
        projects.append(newProject)
        currentProject = newProject
        saveProjects()
        logger.info("Created new project memory: \(name)")
        return newProject
    }

    /// Set the current active project
    public func setCurrentProject(_ projectId: UUID) {
        if let index = projects.firstIndex(where: { $0.id == projectId }) {
            projects[index].recordAccess()
            currentProject = projects[index]
            saveProjects()
        }
    }

    /// Add a key fact to the current project
    public func addFact(_ fact: KeyFact) {
        guard isEnabled else { return }
        guard var project = currentProject else { return }

        // Check for duplicate
        if project.keyFacts.contains(where: { $0.fact.lowercased() == fact.fact.lowercased() }) {
            return
        }

        project.keyFacts.append(fact)

        // Trim to max
        if project.keyFacts.count > maxFactsPerProject {
            // Keep important facts, remove oldest low-importance ones
            project.keyFacts.sort { $0.importance > $1.importance }
            project.keyFacts = Array(project.keyFacts.prefix(maxFactsPerProject))
        }

        updateProject(project)
        logger.info("Added fact to \(project.name): \(fact.fact.prefix(50))")
    }

    /// Add a learned pattern to the current project
    public func addPattern(_ pattern: LearnedPattern) {
        guard isEnabled else { return }
        guard var project = currentProject else { return }

        // Update existing or add new
        if let existingIndex = project.learnedPatterns.firstIndex(where: {
            $0.patternType == pattern.patternType && $0.description == pattern.description
        }) {
            project.learnedPatterns[existingIndex].recordApplication()
        } else {
            project.learnedPatterns.append(pattern)
        }

        // Trim to max
        if project.learnedPatterns.count > maxPatternsPerProject {
            project.learnedPatterns.sort { $0.confidence > $1.confidence }
            project.learnedPatterns = Array(project.learnedPatterns.prefix(maxPatternsPerProject))
        }

        updateProject(project)
        logger.info("Added pattern to \(project.name): \(pattern.description.prefix(50))")
    }

    /// Update project metadata
    public func updateMetadata(_ metadata: ProjectMetadata) {
        guard var project = currentProject else { return }
        project.metadata = metadata
        updateProject(project)
    }

    /// Update project preferences
    public func updatePreferences(_ preferences: ProjectPreferences) {
        guard var project = currentProject else { return }
        project.preferences = preferences
        updateProject(project)
    }

    /// Record a topic discussed in the project
    public func recordTopic(_ topic: String) {
        guard isEnabled else { return }
        guard var project = currentProject else { return }

        // Add to recent topics, keeping last 20
        project.recentTopics.removeAll { $0.lowercased() == topic.lowercased() }
        project.recentTopics.insert(topic, at: 0)
        if project.recentTopics.count > 20 {
            project.recentTopics = Array(project.recentTopics.prefix(20))
        }

        updateProject(project)
    }

    /// Get a summary of project memory for context injection
    public func getMemorySummary() -> MemorySummary? {
        guard let project = currentProject else { return nil }

        return MemorySummary(
            projectName: project.name,
            projectType: project.metadata.projectType,
            primaryLanguage: project.metadata.primaryLanguage,
            frameworks: project.metadata.frameworks,
            keyPatterns: project.learnedPatterns
                .filter { $0.confidence > 0.7 }
                .map { $0.description },
            importantFacts: project.keyFacts
                .filter { $0.importance >= .medium && !$0.isStale }
                .map { $0.fact },
            recentTopics: Array(project.recentTopics.prefix(5)),
            preferences: project.preferences
        )
    }

    /// Search for relevant facts
    public func searchFacts(query: String) -> [KeyFact] {
        guard let project = currentProject else { return [] }

        let lowercasedQuery = query.lowercased()
        return project.keyFacts.filter {
            $0.fact.lowercased().contains(lowercasedQuery) ||
            $0.category.rawValue.contains(lowercasedQuery)
        }
    }

    /// Mark a fact as stale
    public func markFactStale(_ factId: UUID) {
        guard var project = currentProject else { return }

        if let index = project.keyFacts.firstIndex(where: { $0.id == factId }) {
            project.keyFacts[index].isStale = true
            updateProject(project)
        }
    }

    /// Confirm a fact is still accurate
    public func confirmFact(_ factId: UUID) {
        guard var project = currentProject else { return }

        if let index = project.keyFacts.firstIndex(where: { $0.id == factId }) {
            project.keyFacts[index].confirmedAt = Date()
            project.keyFacts[index].isStale = false
            updateProject(project)
        }
    }

    /// Delete a project
    public func deleteProject(_ projectId: UUID) {
        projects.removeAll { $0.id == projectId }
        if currentProject?.id == projectId {
            currentProject = nil
        }
        saveProjects()
        logger.info("Deleted project: \(projectId)")
    }

    /// Clear all memory for a project
    public func clearProjectMemory(_ projectId: UUID) {
        if let index = projects.firstIndex(where: { $0.id == projectId }) {
            projects[index].learnedPatterns = []
            projects[index].keyFacts = []
            projects[index].recentTopics = []
            saveProjects()
            logger.info("Cleared memory for project: \(projectId)")
        }
    }

    /// Export project memory as JSON
    public func exportProject(_ projectId: UUID) -> Data? {
        guard let project = projects.first(where: { $0.id == projectId }) else { return nil }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(project)
    }

    /// Import project memory from JSON
    public func importProject(from data: Data) throws {
        let decoder = JSONDecoder()
        var project = try decoder.decode(ProjectMemory.self, from: data)

        // Generate new ID to avoid conflicts
        project = ProjectMemory(
            id: UUID(),
            name: project.name + " (Imported)",
            path: project.path
        )

        projects.append(project)
        saveProjects()
        logger.info("Imported project: \(project.name)")
    }

    // MARK: - Private Methods

    private func updateProject(_ project: ProjectMemory) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            if currentProject?.id == project.id {
                currentProject = project
            }
        }
    }

    private func startAutoSave() {
        autoSaveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await MainActor.run {
                    self.saveProjects()
                }
            }
        }
    }

    // MARK: - Persistence

    private var projectsURL: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Thea")
            .appendingPathComponent("project_memories.json")
    }

    private func saveProjects() {
        guard let url = projectsURL else { return }

        // Ensure directory exists
        try? fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(projects)
            try data.write(to: url)
        } catch {
            logger.error("Failed to save projects: \(error.localizedDescription)")
        }
    }

    private func loadProjects() {
        guard let url = projectsURL,
              fileManager.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            projects = try decoder.decode([ProjectMemory].self, from: data)
        } catch {
            logger.error("Failed to load projects: \(error.localizedDescription)")
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "thea.memory.enabled")
        UserDefaults.standard.set(maxFactsPerProject, forKey: "thea.memory.maxFacts")
        UserDefaults.standard.set(maxPatternsPerProject, forKey: "thea.memory.maxPatterns")
    }

    private func loadSettings() {
        if UserDefaults.standard.object(forKey: "thea.memory.enabled") != nil {
            isEnabled = UserDefaults.standard.bool(forKey: "thea.memory.enabled")
        }
        maxFactsPerProject = UserDefaults.standard.integer(forKey: "thea.memory.maxFacts")
        if maxFactsPerProject == 0 { maxFactsPerProject = 100 }
        maxPatternsPerProject = UserDefaults.standard.integer(forKey: "thea.memory.maxPatterns")
        if maxPatternsPerProject == 0 { maxPatternsPerProject = 50 }
    }
}

// MARK: - Project Memory View

/// UI for viewing and managing project memory
public struct ProjectMemoryView: View {
    @ObservedObject var manager = ProjectMemoryManager.shared
    @State private var selectedProject: ProjectMemory?
    @State private var searchText = ""

    public init() {}

    public var body: some View {
        NavigationSplitView {
            projectList
        } detail: {
            if let project = selectedProject {
                ProjectDetailView(project: project)
            } else {
                ContentUnavailableView(
                    "Select a Project",
                    systemImage: "folder",
                    description: Text("Choose a project to view its memory")
                )
            }
        }
        .navigationTitle("Project Memory")
    }

    private var projectList: some View {
        List(selection: $selectedProject) {
            ForEach(filteredProjects) { project in
                ProjectMemoryRow(project: project)
                    .tag(project)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    manager.deleteProject(filteredProjects[index].id)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $manager.isEnabled) {
                    Image(systemName: manager.isEnabled ? "brain.fill" : "brain")
                }
                .help(manager.isEnabled ? "Memory enabled" : "Memory disabled")
            }
        }
    }

    private var filteredProjects: [ProjectMemory] {
        if searchText.isEmpty {
            return manager.projects.sorted { $0.lastAccessed > $1.lastAccessed }
        }
        return manager.projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.path.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Project Memory Row

private struct ProjectMemoryRow: View {
    let project: ProjectMemory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForProjectType(project.metadata.projectType))
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.headline)

                Text(project.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(project.keyFacts.count)", systemImage: "lightbulb")
                    Label("\(project.learnedPatterns.count)", systemImage: "sparkles")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForProjectType(_ type: ProjectMetadata.ProjectType) -> String {
        switch type {
        case .ios: return "iphone"
        case .macos: return "laptopcomputer"
        case .watchos: return "applewatch"
        case .tvos: return "appletv"
        case .web: return "globe"
        case .backend: return "server.rack"
        case .fullstack: return "square.stack.3d.up"
        case .library: return "books.vertical"
        case .framework: return "cube"
        case .cli: return "terminal"
        case .script: return "scroll"
        case .dataScience: return "chart.bar.xaxis"
        case .ml: return "brain"
        case .unknown: return "folder"
        }
    }
}

// MARK: - Project Detail View

private struct ProjectDetailView: View {
    let project: ProjectMemory
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Facts Tab
            FactsListView(facts: project.keyFacts)
                .tabItem {
                    Label("Facts", systemImage: "lightbulb")
                }
                .tag(0)

            // Patterns Tab
            PatternsListView(patterns: project.learnedPatterns)
                .tabItem {
                    Label("Patterns", systemImage: "sparkles")
                }
                .tag(1)

            // Metadata Tab
            MetadataView(metadata: project.metadata, preferences: project.preferences)
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(2)
        }
        .navigationTitle(project.name)
    }
}

// MARK: - Facts List View

private struct FactsListView: View {
    let facts: [KeyFact]

    var body: some View {
        List {
            ForEach(KeyFact.FactCategory.allCases, id: \.self) { category in
                let categoryFacts = facts.filter { $0.category == category && !$0.isStale }
                if !categoryFacts.isEmpty {
                    Section(category.rawValue.capitalized) {
                        ForEach(categoryFacts) { fact in
                            FactRow(fact: fact)
                        }
                    }
                }
            }
        }
    }
}

private struct FactRow: View {
    let fact: KeyFact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fact.fact)
                .font(.body)

            HStack {
                Text(fact.createdAt, style: .relative)
                if let source = fact.source {
                    Text("• \(source)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Patterns List View

private struct PatternsListView: View {
    let patterns: [LearnedPattern]

    var body: some View {
        List {
            ForEach(LearnedPattern.PatternType.allCases, id: \.self) { type in
                let typePatterns = patterns.filter { $0.patternType == type }
                if !typePatterns.isEmpty {
                    Section(type.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized) {
                        ForEach(typePatterns) { pattern in
                            PatternRow(pattern: pattern)
                        }
                    }
                }
            }
        }
    }
}

private struct PatternRow: View {
    let pattern: LearnedPattern

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pattern.description)
                .font(.body)

            HStack {
                Text("Confidence: \(Int(pattern.confidence * 100))%")
                Text("• Applied \(pattern.timesApplied) times")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metadata View

private struct MetadataView: View {
    let metadata: ProjectMetadata
    let preferences: ProjectPreferences

    var body: some View {
        Form {
            Section("Project Info") {
                LabeledContent("Type", value: metadata.projectType.rawValue.capitalized)
                if let lang = metadata.primaryLanguage {
                    LabeledContent("Language", value: lang)
                }
                if !metadata.frameworks.isEmpty {
                    LabeledContent("Frameworks", value: metadata.frameworks.joined(separator: ", "))
                }
                if let build = metadata.buildSystem {
                    LabeledContent("Build System", value: build)
                }
            }

            Section("Preferences") {
                LabeledContent("Response Style", value: preferences.responseStyle.rawValue.capitalized)
                LabeledContent("Detail Level", value: preferences.detailLevel.rawValue.capitalized)
                Toggle("Auto Format", isOn: .constant(preferences.autoFormat))
                    .disabled(true)
                Toggle("Suggest Tests", isOn: .constant(preferences.suggestTests))
                    .disabled(true)
            }
        }
    }
}

// MARK: - Extensions

extension KeyFact.FactCategory: CaseIterable {
    public static let allCases: [KeyFact.FactCategory] = [
        .architecture, .dependency, .convention, .bug, .todo,
        .decision, .context, .person, .deadline, .other
    ]
}

extension LearnedPattern.PatternType: CaseIterable {
    public static let allCases: [LearnedPattern.PatternType] = [
        .codingStyle, .namingConvention, .errorHandling, .testing,
        .documentation, .architecture, .workflow, .communication
    ]
}

// MARK: - Preview

#Preview("Project Memory") {
    NavigationStack {
        ProjectMemoryView()
    }
}
