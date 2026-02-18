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

// Supporting types in ProjectMemoryTypes.swift
// Views in ProjectMemoryViews.swift

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
        do {
            return try encoder.encode(project)
        } catch {
            logger.error("Failed to export project '\(project.name)': \(error.localizedDescription)")
            return nil
        }
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
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    break
                }
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
        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("Failed to create project memories directory: \(error.localizedDescription)")
        }

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
