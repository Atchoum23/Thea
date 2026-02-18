// CodeAssistantView.swift
// Thea — AI-powered code assistant UI
// Replaces: Cursor, Codex (for AI-assisted development)

import OSLog
import SwiftUI

private let codeAssistantViewLogger = Logger(subsystem: "ai.thea.app", category: "CodeAssistantView")

struct CodeAssistantView: View {
    @StateObject private var assistant = CodeAssistant.shared
    @State private var showAddProject = false
    @State private var selectedProject: CodeProjectInfo?
    @State private var codeInput = ""
    @State private var selectedLanguage = CodeLanguageType.swift
    @State private var selectedOperation = CodeOperation.analyze
    @State private var operationResult: CodeOperationResult?
    @State private var showSettings = false
    @State private var searchText = ""

    var body: some View {
        #if os(macOS)
        HSplitView {
            projectList
                .frame(minWidth: 220, maxWidth: 320)
            detailContent
                .frame(minWidth: 400)
        }
        #else
        NavigationStack {
            projectListContent
                .navigationTitle("Code Assistant")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showAddProject = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
        }
        #endif
    }

    // MARK: - Project List

    #if os(macOS)
    private var projectList: some View {
        VStack(spacing: 0) {
            projectListContent
        }
        .background(Color.controlBackground)
    }
    #endif

    private var projectListContent: some View {
        List(selection: $selectedProject) {
            statsSection
            projectsSection
            recentOpsSection
        }
        .searchable(text: $searchText, prompt: "Search projects")
        .fileImporter(isPresented: $showAddProject, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                Task {
                    do {
                        _ = try await assistant.scanProject(at: url)
                    } catch {
                        codeAssistantViewLogger.error("Failed to scan project at \(url.path): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        Section("Overview") {
            let stats = assistant.getProjectStats()
            Label("\(stats.totalProjects) projects", systemImage: "folder")
                .accessibilityLabel("\(stats.totalProjects) tracked projects")
            Label("\(stats.totalFiles) files", systemImage: "doc")
                .accessibilityLabel("\(stats.totalFiles) code files")
            Label("\(formatLines(stats.totalLines)) lines", systemImage: "text.alignleft")
                .accessibilityLabel("\(stats.totalLines) lines of code")
            if !stats.primaryLanguages.isEmpty {
                Label(stats.primaryLanguages.map(\.displayName).joined(separator: ", "), systemImage: "chevron.left.forwardslash.chevron.right")
                    .lineLimit(2)
                    .font(.caption)
                    .accessibilityLabel("Languages: \(stats.primaryLanguages.map(\.displayName).joined(separator: ", "))")
            }
        }
    }

    // MARK: - Projects

    private var projectsSection: some View {
        Section {
            if filteredProjects.isEmpty {
                ContentUnavailableView {
                    Label("No Projects", systemImage: "folder.badge.questionmark")
                } description: {
                    Text("Add a project folder to get started.")
                } actions: {
                    Button("Add Project") { showAddProject = true }
                }
            } else {
                ForEach(filteredProjects) { project in
                    projectRow(project)
                        .tag(project)
                }
                .onDelete { indices in
                    let projects = filteredProjects
                    for index in indices {
                        assistant.removeProject(id: projects[index].id)
                    }
                }
            }
        } header: {
            HStack {
                Text("Projects")
                Spacer()
                Button {
                    showAddProject = true
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add project")
            }
        }
    }

    private func projectRow(_ project: CodeProjectInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: project.primaryLanguage?.icon ?? "folder")
                    .foregroundStyle(.secondary)
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text("\(project.formattedLines) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(project.fileCount) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let branch = project.gitBranch {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                if project.hasUncommittedChanges {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Has uncommitted changes")
                }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Rescan") {
                Task {
                    do {
                        _ = try await assistant.scanProject(at: URL(fileURLWithPath: project.path))
                    } catch {
                        codeAssistantViewLogger.error("Failed to rescan project: \(error.localizedDescription)")
                    }
                }
            }
            #if os(macOS)
            Button("Open in Finder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
            }
            Button("Open in Terminal") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
            }
            #endif
            Divider()
            Button("Remove", role: .destructive) {
                assistant.removeProject(id: project.id)
            }
        }
    }

    // MARK: - Recent Operations

    private var recentOpsSection: some View {
        Section("Recent Operations") {
            if assistant.recentOperations.isEmpty {
                Text("No operations yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(assistant.recentOperations.prefix(10)) { op in
                    HStack {
                        Image(systemName: op.operation.icon)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(op.operation.displayName)
                                .font(.caption)
                            Text(op.language.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(op.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                if assistant.recentOperations.count > 10 {
                    Button("Clear History") {
                        assistant.clearHistory()
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        if let project = selectedProject {
            projectDetail(project)
        } else {
            codeWorkbench
        }
    }

    // MARK: - Project Detail

    private func projectDetail(_ project: CodeProjectInfo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(project.name)
                            .font(.title2.bold())
                        Text(project.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button {
                        Task {
                            do {
                                _ = try await assistant.scanProject(at: URL(fileURLWithPath: project.path))
                            } catch {
                                codeAssistantViewLogger.error("Failed to rescan project: \(error.localizedDescription)")
                            }
                        }
                    } label: {
                        Label(assistant.isScanning ? "Scanning..." : "Rescan", systemImage: "arrow.clockwise")
                    }
                    .disabled(assistant.isScanning)
                }

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    statCard("Files", "\(project.fileCount)", icon: "doc")
                    statCard("Lines", project.formattedLines, icon: "text.alignleft")
                    statCard("Languages", "\(project.languages.count)", icon: "chevron.left.forwardslash.chevron.right")
                    if let branch = project.gitBranch {
                        statCard("Branch", branch, icon: "arrow.triangle.branch")
                    }
                }

                // Language breakdown
                if !project.languages.isEmpty {
                    GroupBox("Language Breakdown") {
                        ForEach(project.languages.sorted(by: { $0.value > $1.value }), id: \.key) { lang, lines in
                            HStack {
                                Image(systemName: lang.icon)
                                    .frame(width: 20)
                                Text(lang.displayName)
                                Spacer()
                                Text(formatLines(lines))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.callout)
                        }
                    }
                }

                // Git info
                #if os(macOS)
                if project.gitBranch != nil {
                    GroupBox("Git Status") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let remote = project.gitRemote {
                                HStack {
                                    Text("Remote:")
                                        .foregroundStyle(.secondary)
                                    Text(remote)
                                        .textSelection(.enabled)
                                }
                                .font(.callout)
                            }
                            HStack {
                                Circle()
                                    .fill(project.hasUncommittedChanges ? Color.orange : Color.green)
                                    .frame(width: 8, height: 8)
                                Text(project.hasUncommittedChanges ? "Uncommitted changes" : "Clean working tree")
                                    .font(.callout)
                            }
                        }
                    }
                }
                #endif
            }
            .padding()
        }
    }

    private func statCard(_ title: String, _ value: String, icon: String) -> some View {
        GroupBox {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text(value)
                    .font(.title3.monospacedDigit().bold())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Code Workbench

    private var codeWorkbench: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Code Workbench")
                    .font(.title2.bold())

                // Operation selector
                GroupBox("Operation") {
                    HStack {
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(CodeLanguageType.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .frame(maxWidth: 150)

                        Picker("Operation", selection: $selectedOperation) {
                            ForEach(CodeOperation.allCases, id: \.self) { op in
                                Label(op.displayName, systemImage: op.icon).tag(op)
                            }
                        }
                        .frame(maxWidth: 200)

                        Spacer()

                        Button {
                            guard !codeInput.isEmpty else { return }
                            operationResult = assistant.analyzeCode(codeInput, language: selectedLanguage)
                        } label: {
                            Label("Run", systemImage: "play.fill")
                        }
                        .disabled(codeInput.isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                    }
                }

                // Code input
                GroupBox("Code Input") {
                    TextEditor(text: $codeInput)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                        .accessibilityLabel("Code input editor")
                }

                // Result
                if let result = operationResult {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: result.operation.icon)
                                    .foregroundStyle(.blue)
                                Text(result.operation.displayName)
                                    .font(.headline)
                                Text("(\(result.language.displayName))")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(result.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Divider()
                            Text(result.output)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    } label: {
                        Text("Result")
                    }
                }

                #if os(macOS)
                // Settings link
                GroupBox("Configuration") {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Label("Code Intelligence Settings", systemImage: "gearshape")
                    }
                    .sheet(isPresented: $showSettings) {
                        CodeIntelligenceConfigurationView()
                            .frame(minWidth: 500, minHeight: 400)
                    }
                }
                #endif
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private var filteredProjects: [CodeProjectInfo] {
        if searchText.isEmpty {
            return assistant.projects
        }
        return assistant.projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func formatLines(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - CodeOperation CaseIterable

extension CodeOperation: CaseIterable {
    static var allCases: [CodeOperation] {
        [.analyze, .refactor, .generateTests, .explain, .review, .fixBug, .optimize, .addDocumentation, .convertLanguage]
    }
}

// MARK: - CodeProjectInfo Hashable

extension CodeProjectInfo: Hashable {
    static func == (lhs: CodeProjectInfo, rhs: CodeProjectInfo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
