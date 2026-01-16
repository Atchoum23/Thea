import SwiftData
import SwiftUI

struct iOSProjectsView: View {
    @State private var projectManager = ProjectManager.shared
    @State private var showingNewProject = false
    @State private var selectedProject: Project?

    var body: some View {
        Group {
            if projectManager.projects.isEmpty {
                emptyStateView
            } else {
                projectList
            }
        }
        .sheet(isPresented: $showingNewProject) {
            iOSNewProjectView()
        }
        .sheet(item: $selectedProject) { project in
            iOSProjectDetailView(project: project)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.fill")
                .font(.system(size: 64))
                .foregroundStyle(.theaPrimary)

            Text("No Projects Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Organize your conversations into projects")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingNewProject = true
            } label: {
                Label("New Project", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.theaPrimary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    private var projectList: some View {
        List {
            ForEach(projectManager.projects) { project in
                Button {
                    selectedProject = project
                } label: {
                    ProjectRow(project: project)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        projectManager.deleteProject(project)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 16) {
                Label("\(project.conversations.count)", systemImage: "message.fill")
                Label("\(project.files.count)", systemImage: "doc.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(project.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - New Project View

struct iOSNewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var projectManager = ProjectManager.shared

    @State private var title = ""
    @State private var customInstructions = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Title") {
                    TextField("Enter title...", text: $title)
                }

                Section("Custom Instructions") {
                    TextEditor(text: $customInstructions)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func createProject() {
        projectManager.createProject(title: title, customInstructions: customInstructions)
        dismiss()
    }
}

// MARK: - Project Detail View

struct iOSProjectDetailView: View {
    let project: Project

    @Environment(\.dismiss) private var dismiss
    @State private var projectManager = ProjectManager.shared
    @State private var chatManager = ChatManager.shared

    @State private var isEditing = false
    @State private var editedTitle: String
    @State private var editedInstructions: String
    @State private var showingShareSheet = false
    @State private var exportedData: Data?

    init(project: Project) {
        self.project = project
        _editedTitle = State(initialValue: project.title)
        _editedInstructions = State(initialValue: project.customInstructions)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isEditing {
                    editingSection
                } else {
                    detailSection
                }

                conversationsSection
                filesSection
                actionsSection
            }
            .navigationTitle(project.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveChanges()
                        }
                        isEditing.toggle()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let data = exportedData {
                    ShareSheet(items: [data])
                }
            }
        }
    }

    private var editingSection: some View {
        Section("Project Details") {
            TextField("Title", text: $editedTitle)

            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Instructions")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $editedInstructions)
                    .frame(minHeight: 120)
            }
        }
    }

    private var detailSection: some View {
        Section("Project Details") {
            LabeledContent("Title", value: project.title)
            LabeledContent("Created", value: project.createdAt, format: .dateTime)
            LabeledContent("Updated", value: project.updatedAt, format: .relative(presentation: .named))

            if !project.customInstructions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Instructions")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(project.customInstructions)
                        .font(.body)
                }
            }
        }
    }

    private var conversationsSection: some View {
        Section {
            ForEach(project.conversations) { conversation in
                NavigationLink(destination: iOSChatView(conversation: conversation)) {
                    ConversationRow(conversation: conversation)
                }
            }
        } header: {
            Text("Conversations (\(project.conversations.count))")
        }
    }

    private var filesSection: some View {
        Section {
            ForEach(project.files) { file in
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.theaPrimary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.body)

                        Text("\(file.size) bytes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Files (\(project.files.count))")
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                exportProject()
            } label: {
                Label("Export Project", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                projectManager.deleteProject(project)
                dismiss()
            } label: {
                Label("Delete Project", systemImage: "trash")
            }
        } header: {
            Text("Actions")
        }
    }

    private func saveChanges() {
        project.title = editedTitle
        project.customInstructions = editedInstructions
        project.updatedAt = Date()
    }

    private func exportProject() {
        do {
            let data = try $projectManager.exportProject(project)
            exportedData = data
            showingShareSheet = true
        } catch {
            print("Export failed: \(error)")
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
