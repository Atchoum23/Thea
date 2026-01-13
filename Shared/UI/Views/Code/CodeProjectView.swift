import SwiftUI

// MARK: - Code Project View
// IDE-like interface for code intelligence and project management

struct CodeProjectView: View {
    @State private var codeIntelligence = CodeIntelligence.shared
    @State private var selectedProject: CodeProject?
    @State private var selectedFile: CodeFile?
    @State private var showingProjectPicker = false
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            // Sidebar - Projects list
            projectSidebar
                .navigationTitle("Code Projects")
        } content: {
            // Middle - File list
            if let project = selectedProject {
                fileList(project: project)
            } else {
                emptyProjectState
            }
        } detail: {
            // Detail - Code viewer/editor
            if let file = selectedFile {
                codeViewer(file: file)
            } else {
                emptyFileState
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingProjectPicker = true }) {
                    Label("Open Project", systemImage: "folder.badge.plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showingProjectPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleProjectSelection(result)
        }
    }

    // MARK: - Project Sidebar

    private var projectSidebar: some View {
        List(codeIntelligence.activeProjects, selection: $selectedProject) { project in
            ProjectRow(project: project)
                .tag(project)
        }
        .listStyle(.sidebar)
        .overlay {
            if codeIntelligence.activeProjects.isEmpty {
                ContentUnavailableView(
                    "No Projects Open",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Open a code project to start")
                )
            }
        }
    }

    // MARK: - File List

    private func fileList(project: CodeProject) -> some View {
        List(filteredFiles(project), selection: $selectedFile) { file in
            FileRow(file: file)
                .tag(file)
        }
        .navigationTitle(project.name)
        .searchable(text: $searchText, prompt: "Search files...")
    }

    private func filteredFiles(_ project: CodeProject) -> [CodeFile] {
        if searchText.isEmpty {
            return project.files
        } else {
            return project.files.filter { file in
                file.url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Code Viewer

    private func codeViewer(file: CodeFile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                codeFileHeader(file)

                Divider()

                // Code content
                Text(file.content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    private func codeFileHeader(_ file: CodeFile) -> some View {
        HStack {
            Image(systemName: iconForLanguage(file.language))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.url.lastPathComponent)
                    .font(.headline)

                Text(file.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(languageLabel(file.language))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(colorForLanguage(file.language).opacity(0.2))
                .foregroundColor(colorForLanguage(file.language))
                .cornerRadius(4)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Empty States

    private var emptyProjectState: some View {
        ContentUnavailableView(
            "Select a Project",
            systemImage: "folder",
            description: Text("Choose a project from the sidebar")
        )
    }

    private var emptyFileState: some View {
        ContentUnavailableView(
            "Select a File",
            systemImage: "doc",
            description: Text("Choose a file to view its contents")
        )
    }

    // MARK: - Helper Methods

    private func handleProjectSelection(_ result: Result<[URL], Error>) {
        Task {
            do {
                guard let url = try result.get().first else { return }

                let project = try await codeIntelligence.openProject(at: url)
                selectedProject = project
            } catch {
                print("Failed to open project: \(error)")
            }
        }
    }

    private func iconForLanguage(_ language: ProgrammingLanguage) -> String {
        switch language {
        case .swift: return "swift"
        case .python: return "text.word.spacing"
        case .javascript, .typescript: return "text.curlybraces"
        case .go, .rust, .java, .kotlin: return "chevron.left.forwardslash.chevron.right"
        case .unknown: return "doc.text"
        }
    }

    private func languageLabel(_ language: ProgrammingLanguage) -> String {
        switch language {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .go: return "Go"
        case .rust: return "Rust"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .unknown: return "Unknown"
        }
    }

    private func colorForLanguage(_ language: ProgrammingLanguage) -> Color {
        switch language {
        case .swift: return .orange
        case .python: return .blue
        case .javascript: return .yellow
        case .typescript: return .blue
        case .go: return .cyan
        case .rust: return .orange
        case .java: return .red
        case .kotlin: return .purple
        case .unknown: return .gray
        }
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: CodeProject

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)

                Text(project.name)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Text("\(project.files.count) files")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Opened \(project.openedAt, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - File Row

struct FileRow: View {
    let file: CodeFile

    var body: some View {
        HStack {
            Image(systemName: iconForExtension(file.url.pathExtension))
                .foregroundStyle(colorForExtension(file.url.pathExtension))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.lastPathComponent)
                    .font(.caption)

                Text(file.url.deletingLastPathComponent().lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func iconForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "swift": return "swift"
        case "py": return "text.word.spacing"
        case "js", "ts", "jsx", "tsx": return "text.curlybraces"
        case "md": return "text.document"
        case "json": return "curlybraces"
        case "yaml", "yml": return "text.alignleft"
        default: return "doc.text"
        }
    }

    private func colorForExtension(_ ext: String) -> Color {
        switch ext.lowercased() {
        case "swift": return .orange
        case "py": return .blue
        case "js", "jsx": return .yellow
        case "ts", "tsx": return .blue
        case "md": return .gray
        case "json": return .green
        case "yaml", "yml": return .red
        default: return .secondary
        }
    }
}

#Preview {
    CodeProjectView()
}
