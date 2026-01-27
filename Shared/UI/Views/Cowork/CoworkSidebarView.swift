#if os(macOS)
    import SwiftUI

    /// Sidebar view showing working folder, progress, and context summary
    struct CoworkSidebarView: View {
        @State private var manager = CoworkManager.shared
        @State private var showingFolderPicker = false

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Working folder section
                workingFolderSection

                Divider()

                // Progress section
                progressSection

                Divider()

                // Context section
                contextSection

                Divider()

                // Queue section
                queueSection

                Spacer()
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .fileImporter(
                isPresented: $showingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    manager.folderAccess.addAllowedFolder(url)
                    manager.currentSession?.workingDirectory = url
                }
            }
        }

        // MARK: - Working Folder Section

        private var workingFolderSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    Text("Working Folder")
                        .font(.headline)
                }

                if let session = manager.currentSession {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.workingDirectory.lastPathComponent)
                            .font(.body)
                            .lineLimit(1)

                        Text(session.workingDirectory.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("No folder selected")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Button("Change") {
                    showingFolderPicker = true
                }
                .buttonStyle(.link)
            }
            .padding()
        }

        // MARK: - Progress Section

        private var progressSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .foregroundStyle(.purple)
                    Text("Progress")
                        .font(.headline)
                    Spacer()
                }

                if let session = manager.currentSession, !session.steps.isEmpty {
                    // Progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: session.progress)

                        HStack {
                            Text("\(session.completedSteps.count)/\(session.steps.count) steps")
                                .font(.caption)
                            Spacer()
                            Text("\(Int(session.progress * 100))%")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // Step list
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(session.steps) { step in
                                stepRow(step)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                } else {
                    Text("No active task")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }

        private func stepRow(_ step: CoworkStep) -> some View {
            HStack(spacing: 8) {
                Image(systemName: step.status.icon)
                    .foregroundStyle(colorForStepStatus(step.status))
                    .frame(width: 16)

                Text("Step \(step.stepNumber)")
                    .font(.caption.bold())

                Text(step.description)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }

        private func colorForStepStatus(_ status: CoworkStep.StepStatus) -> Color {
            switch status {
            case .pending: .secondary
            case .inProgress: .blue
            case .completed: .green
            case .failed: .red
            case .skipped: .orange
            }
        }

        // MARK: - Context Section

        private var contextSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.cyan)
                    Text("Context")
                        .font(.headline)
                }

                if let session = manager.currentSession {
                    VStack(alignment: .leading, spacing: 4) {
                        contextRow(icon: "doc", label: "Files accessed", value: "\(session.context.uniqueFilesAccessed.count)")
                        contextRow(icon: "link", label: "URLs visited", value: "\(session.context.uniqueURLsAccessed.count)")
                        contextRow(icon: "puzzlepiece", label: "Connectors", value: "\(session.context.activeConnectors.count)")
                    }
                }
            }
            .padding()
        }

        private func contextRow(icon: String, label: String, value: String) -> some View {
            HStack {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(label)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }

        // MARK: - Queue Section

        private var queueSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "tray.full.fill")
                        .foregroundStyle(.orange)
                    Text("Queue")
                        .font(.headline)

                    Spacer()

                    if let session = manager.currentSession, session.taskQueue.pendingCount > 0 {
                        Text("\(session.taskQueue.pendingCount)")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                if let session = manager.currentSession {
                    let queuedTasks = session.taskQueue.queuedTasks
                    if queuedTasks.isEmpty {
                        Text("No queued tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(queuedTasks.prefix(5)) { task in
                                    HStack {
                                        Image(systemName: task.priority.icon)
                                            .foregroundStyle(colorForPriority(task.priority))
                                            .frame(width: 16)
                                        Text(task.instruction)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 100)
                    }
                }
            }
            .padding()
        }

        private func colorForPriority(_ priority: CoworkTask.TaskPriority) -> Color {
            switch priority {
            case .low: .secondary
            case .normal: .blue
            case .high: .orange
            case .urgent: .red
            }
        }
    }

    #Preview {
        CoworkSidebarView()
            .frame(width: 300, height: 600)
    }

#endif
