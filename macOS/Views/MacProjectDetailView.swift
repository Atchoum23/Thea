@preconcurrency import SwiftData
import SwiftUI

// MARK: - macOS Project Detail View

/// Project details view for macOS showing project info, conversations, and files.
/// Uses auto-saving via `.onChange` instead of Cancel/OK pattern.
struct MacProjectDetailView: View {
    let project: Project

    @StateObject private var projectManager = ProjectManager.shared

    @State private var isEditing = false
    @State private var editedTitle: String
    @State private var editedInstructions: String

    init(project: Project) {
        self.project = project
        _editedTitle = State(initialValue: project.title)
        _editedInstructions = State(initialValue: project.customInstructions)
    }

    var body: some View {
        Form {
            if isEditing {
                editingSection
            } else {
                readOnlySection
            }

            conversationsSection
            filesSection
        }
        .formStyle(.grouped)
        .navigationTitle(project.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if isEditing {
                        saveChanges()
                    }
                    withAnimation(TheaAnimation.standard) {
                        isEditing.toggle()
                    }
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                }
            }
        }
    }

    // MARK: - Editing Section

    private var editingSection: some View {
        Section("Project Details") {
            TextField("Title", text: $editedTitle)

            VStack(alignment: .leading, spacing: TheaSpacing.sm) {
                Text("Custom Instructions")
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)

                TextEditor(text: $editedInstructions)
                    .frame(minHeight: 200)
                    .font(.theaBody)
            }
        }
    }

    // MARK: - Read-Only Section

    private var readOnlySection: some View {
        Section("Project Details") {
            LabeledContent("Title", value: project.title)
            LabeledContent("Created", value: project.createdAt, format: .dateTime)
            LabeledContent("Conversations", value: "\(project.conversations.count)")
            LabeledContent("Files", value: "\(project.files.count)")

            if !project.customInstructions.isEmpty {
                VStack(alignment: .leading, spacing: TheaSpacing.sm) {
                    Text("Custom Instructions")
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)

                    Text(project.customInstructions)
                        .font(.theaBody)
                }
            }
        }
    }

    // MARK: - Conversations Section

    private var conversationsSection: some View {
        Section("Conversations") {
            if project.conversations.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start a conversation in this project.")
                )
            } else {
                ForEach(project.conversations) { conversation in
                    NavigationLink(destination: MacChatDetailView(conversation: conversation)) {
                        ConversationRow(conversation: conversation)
                    }
                }
            }
        }
    }

    // MARK: - Files Section

    private var filesSection: some View {
        Section("Files") {
            if project.files.isEmpty {
                ContentUnavailableView(
                    "No Files",
                    systemImage: "doc",
                    description: Text("Add files to this project.")
                )
            } else {
                ForEach(project.files) { file in
                    HStack(spacing: TheaSpacing.md) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(Color.theaPrimaryDefault)

                        VStack(alignment: .leading, spacing: TheaSpacing.xxs) {
                            Text(file.name)
                                .font(.theaBody)

                            Text("\(file.size) bytes")
                                .font(.theaCaption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveChanges() {
        project.title = editedTitle
        project.customInstructions = editedInstructions
        project.updatedAt = Date()
    }
}
