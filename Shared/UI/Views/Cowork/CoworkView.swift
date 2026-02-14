#if os(macOS)
    import SwiftUI

    /// Main Cowork view - the agentic desktop assistant interface
    struct CoworkView: View {
        @State private var manager = CoworkManager.shared
        @State private var instructionText = ""
        @State private var showingFolderPicker = false
        @State private var showingPlanPreview = false
        @State private var selectedTab: CoworkTab = .progress

        enum CoworkTab: String, CaseIterable {
            case progress = "Progress"
            case artifacts = "Artifacts"
            case context = "Context"
            case queue = "Queue"
            case skills = "Skills"
        }

        var body: some View {
            HSplitView {
                // Left sidebar - Progress and controls
                CoworkSidebarView()
                    .frame(minWidth: 250, maxWidth: 350)

                // Main content area
                VStack(spacing: 0) {
                    // Tab bar
                    tabBar

                    Divider()

                    // Content based on selected tab
                    Group {
                        switch selectedTab {
                        case .progress:
                            CoworkProgressView()
                        case .artifacts:
                            CoworkArtifactsView()
                        case .context:
                            CoworkContextView()
                        case .queue:
                            CoworkQueueView()
                        case .skills:
                            CoworkSkillsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    // Instruction input area
                    instructionInputArea
                }
            }
            .frame(minWidth: 900, minHeight: 600)
            .toolbar {
                ToolbarItemGroup {
                    // Working directory button
                    Button {
                        showingFolderPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text(manager.currentSession?.workingDirectory.lastPathComponent ?? "Select Folder")
                                .lineLimit(1)
                        }
                    }
                    .help("Change working directory")

                    Divider()

                    // Session controls
                    if manager.isProcessing {
                        Button {
                            manager.pause()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                        }

                        Button {
                            manager.cancel()
                        } label: {
                            Label("Cancel", systemImage: "xmark.circle")
                        }
                    } else if manager.currentSession?.status == .paused {
                        Button {
                            Task { try? await manager.resume() }
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                        }
                    }

                    // New session
                    Button {
                        _ = manager.createSession()
                    } label: {
                        Label("New Session", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    manager.folderAccess.addAllowedFolder(url)
                    manager.currentSession?.workingDirectory = url
                    manager.currentSession?.context.workingDirectory = url
                }
            }
            .sheet(isPresented: $showingPlanPreview) {
                planPreviewSheet
            }
            .onAppear {
                if manager.currentSession == nil {
                    _ = manager.createSession()
                }
            }
        }

        // MARK: - Tab Bar

        private var tabBar: some View {
            HStack(spacing: 0) {
                ForEach(CoworkTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: iconForTab(tab))
                                .accessibilityHidden(true)
                            Text(tab.rawValue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
        }

        private func iconForTab(_ tab: CoworkTab) -> String {
            switch tab {
            case .progress: "list.bullet.clipboard"
            case .artifacts: "doc.on.doc"
            case .context: "info.circle"
            case .queue: "tray.full"
            case .skills: "star.circle"
            }
        }

        // MARK: - Instruction Input

        private var instructionInputArea: some View {
            VStack(spacing: 12) {
                HStack {
                    Text("What would you like me to work on?")
                        .font(.headline)
                    Spacer()
                    if let session = manager.currentSession {
                        StatusBadge(status: session.status)
                    }
                }

                HStack(spacing: 12) {
                    TextEditor(text: $instructionText)
                        .font(.body)
                        .frame(minHeight: 60, maxHeight: 100)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )

                    VStack(spacing: 8) {
                        Button {
                            startTask()
                        } label: {
                            Label("Start", systemImage: "play.fill")
                                .frame(width: 80)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(instructionText.isEmpty || manager.isProcessing)

                        Button {
                            queueTask()
                        } label: {
                            Label("Queue", systemImage: "plus.circle")
                                .frame(width: 80)
                        }
                        .buttonStyle(.bordered)
                        .disabled(instructionText.isEmpty)
                    }
                }

                // Quick actions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CoworkQuickActionButton(title: "Organize Downloads", icon: "folder.badge.gearshape") {
                            instructionText = "Organize my Downloads folder by file type"
                        }
                        CoworkQuickActionButton(title: "Clean Duplicates", icon: "doc.on.doc.fill") {
                            instructionText = "Find and remove duplicate files"
                        }
                        CoworkQuickActionButton(title: "Generate Report", icon: "doc.text.fill") {
                            instructionText = "Generate a summary report of the folder contents"
                        }
                        CoworkQuickActionButton(title: "Backup Important", icon: "externaldrive.fill.badge.plus") {
                            instructionText = "Create a backup of important documents"
                        }
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }

        // MARK: - Plan Preview Sheet

        private var planPreviewSheet: some View {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Review Plan Before Execution")
                        .font(.headline)

                    if let session = manager.currentSession {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(session.steps) { step in
                                    HStack(alignment: .top) {
                                        Text("\(step.stepNumber).")
                                            .font(.headline)
                                            .frame(width: 30)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(step.description)
                                                .font(.body)

                                            if !step.toolsUsed.isEmpty {
                                                Text("Tools: \(step.toolsUsed.joined(separator: ", "))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                        }
                    }
                }
                .padding()
                .frame(minWidth: 500, minHeight: 400)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingPlanPreview = false
                            manager.currentSession?.reset()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Execute") {
                            showingPlanPreview = false
                            Task {
                                try? await manager.executePlan()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }

        // MARK: - Actions

        private func startTask() {
            guard !instructionText.isEmpty else { return }

            Task {
                do {
                    _ = try await manager.createPlan(for: instructionText)

                    if manager.previewPlanBeforeExecution {
                        showingPlanPreview = true
                    } else {
                        try await manager.executePlan()
                    }

                    instructionText = ""
                } catch {
                    // Error handling
                }
            }
        }

        private func queueTask() {
            guard !instructionText.isEmpty else { return }
            manager.queueTask(instructionText)
            instructionText = ""
        }
    }

    // MARK: - Supporting Views

    struct StatusBadge: View {
        let status: CoworkSession.SessionStatus

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .accessibilityHidden(true)
                Text(status.rawValue)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorForStatus.opacity(0.2))
            .foregroundStyle(colorForStatus)
            .cornerRadius(4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Status: \(status.rawValue)")
        }

        private var colorForStatus: Color {
            switch status {
            case .idle: .secondary
            case .planning: .purple
            case .awaitingApproval: .yellow
            case .executing: .blue
            case .paused: .orange
            case .completed: .green
            case .failed: .red
            }
        }
    }

    struct CoworkQuickActionButton: View {
        let title: String
        let icon: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                    Text(title)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlColor))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }

    #Preview {
        CoworkView()
            .frame(width: 1000, height: 700)
    }

#endif
