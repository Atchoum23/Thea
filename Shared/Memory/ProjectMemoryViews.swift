//
//  ProjectMemoryViews.swift
//  Thea
//
//  Views for ProjectMemoryManager
//

import Foundation
import SwiftUI

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

// MARK: - Preview

#Preview("Project Memory") {
    NavigationStack {
        ProjectMemoryView()
    }
}
