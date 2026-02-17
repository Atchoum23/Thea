#if os(macOS)
    import SwiftUI

    /// Main Cowork view - the agentic desktop assistant interface
    struct CoworkView: View {
        @State private var manager = CoworkManager.shared
        @State private var instructionText = ""
        @State private var showingFolderPicker = false
        @State private var showingPlanPreview = false
        @State private var showingInlinePlan = false
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

                    // Inline plan checklist (shown when plan is ready for review)
                    if showingInlinePlan, let session = manager.currentSession, !session.steps.isEmpty {
                        InlinePlanChecklist(
                            session: session,
                            onApprove: { [session] in
                                showingInlinePlan = false
                                Task { try? await manager.executePlan() }
                            },
                            onCancel: { [session] in
                                showingInlinePlan = false
                                session.reset()
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        Divider()
                    }

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
                                .accessibilityHidden(true)
                            Text(manager.currentSession?.workingDirectory.lastPathComponent ?? "Select Folder")
                                .lineLimit(1)
                        }
                    }
                    .help("Change working directory")
                    .accessibilityLabel("Working directory")
                    .accessibilityHint("Opens folder picker to change working directory")

                    Divider()

                    // Session controls
                    if manager.isProcessing {
                        Button {
                            manager.pause()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                        }
                        .accessibilityLabel("Pause")
                        .accessibilityHint("Pauses the current task execution")

                        Button {
                            manager.cancel()
                        } label: {
                            Label("Cancel", systemImage: "xmark.circle")
                        }
                        .accessibilityLabel("Cancel")
                        .accessibilityHint("Cancels the current task execution")
                    } else if manager.currentSession?.status == .paused {
                        Button {
                            Task { try? await manager.resume() }
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                        }
                        .accessibilityLabel("Resume")
                        .accessibilityHint("Resumes the paused task execution")
                    }

                    // New session
                    Button {
                        _ = manager.createSession()
                    } label: {
                        Label("New Session", systemImage: "plus")
                    }
                    .accessibilityLabel("New Session")
                    .accessibilityHint("Creates a new cowork session")
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
                    .accessibilityLabel("\(tab.rawValue) tab")
                    .accessibilityHint("Switches to the \(tab.rawValue) tab")
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
                        .accessibilityLabel("Task instruction")
                        .accessibilityHint("Describe the task you want Thea to work on")

                    VStack(spacing: 8) {
                        Button {
                            startTask()
                        } label: {
                            Label("Start", systemImage: "play.fill")
                                .frame(width: 80)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(instructionText.isEmpty || manager.isProcessing)
                        .accessibilityLabel("Start task")
                        .accessibilityHint("Begins executing the task immediately")

                        Button {
                            queueTask()
                        } label: {
                            Label("Queue", systemImage: "plus.circle")
                                .frame(width: 80)
                        }
                        .buttonStyle(.bordered)
                        .disabled(instructionText.isEmpty)
                        .accessibilityLabel("Queue task")
                        .accessibilityHint("Adds the task to the execution queue")
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
                        .accessibilityLabel("Cancel plan")
                        .accessibilityHint("Cancels the plan and resets the session")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Execute") {
                            showingPlanPreview = false
                            Task {
                                try? await manager.executePlan()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Execute plan")
                        .accessibilityHint("Starts executing the planned steps")
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
                        // Show inline plan checklist instead of a modal sheet
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showingInlinePlan = true
                        }
                    } else {
                        try await manager.executePlan()
                    }

                    instructionText = ""
                } catch {
                    // Error handling — session stays in idle state
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
            case .awaitingApproval: .theaWarning
            case .executing: .theaInfo
            case .paused: .theaWarning
            case .completed: .theaSuccess
            case .failed: .theaError
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
                        .accessibilityHidden(true)
                    Text(title)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlColor))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityHint("Sets the task instruction to \(title)")
        }
    }

    // MARK: - Inline Plan Checklist

    /// Shows the task plan inline (replacing the old sheet) as an expandable
    /// DisclosureGroup checklist. High-risk steps require acknowledgement before
    /// the "Approve and Execute" button becomes active.
    struct InlinePlanChecklist: View {
        @Bindable var session: CoworkSession
        let onApprove: () -> Void
        let onCancel: () -> Void

        @State private var expandedStepID: UUID?

        private var highRiskSteps: [CoworkStep] {
            session.steps.filter(\.isHighRisk)
        }

        private var allHighRiskAcknowledged: Bool {
            highRiskSteps.allSatisfy(\.riskAcknowledged)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "checklist")
                        .accessibilityHidden(true)
                    Text("Review Plan — \(session.steps.count) step\(session.steps.count == 1 ? "" : "s")")
                        .font(.headline)
                    Spacer()

                    if !highRiskSteps.isEmpty {
                        Label("\(highRiskSteps.count) high-risk", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Plan review. \(session.steps.count) steps.")

                Divider()

                // Steps checklist
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(session.steps.indices, id: \.self) { index in
                            PlanStepRow(
                                step: $session.steps[index],
                                isExpanded: expandedStepID == session.steps[index].id,
                                onToggleExpand: {
                                    let stepID = session.steps[index].id
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedStepID = expandedStepID == stepID ? nil : stepID
                                    }
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)

                Divider()

                // Approve / Cancel bar
                HStack(spacing: 12) {
                    Button("Cancel Plan") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Cancel plan")
                    .accessibilityHint("Cancels the plan and resets the session")

                    Spacer()

                    if !highRiskSteps.isEmpty && !allHighRiskAcknowledged {
                        Text("Acknowledge all high-risk steps to proceed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        onApprove()
                    } label: {
                        Label("Approve and Execute", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!allHighRiskAcknowledged)
                    .accessibilityLabel("Approve and execute plan")
                    .accessibilityHint(
                        allHighRiskAcknowledged
                            ? "Starts executing all planned steps"
                            : "Acknowledge all high-risk steps first"
                    )
                }
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    // MARK: - Plan Step Row

    /// A single row in the inline plan checklist.
    private struct PlanStepRow: View {
        @Binding var step: CoworkStep
        let isExpanded: Bool
        let onToggleExpand: () -> Void

        @State private var notesText: String = ""

        var body: some View {
            DisclosureGroup(isExpanded: Binding(get: { isExpanded }, set: { _ in onToggleExpand() })) {
                // Expanded detail content
                VStack(alignment: .leading, spacing: 8) {
                    if !step.toolsUsed.isEmpty {
                        HStack(alignment: .top, spacing: 4) {
                            Text("Tools:")
                                .font(.caption.bold())
                            Text(step.toolsUsed.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Optional notes field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes:")
                            .font(.caption.bold())
                        TextField("Add notes for this step…", text: $notesText, axis: .vertical)
                            .font(.caption)
                            .lineLimit(2...4)
                            .padding(6)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onChange(of: notesText) { _, newValue in
                                step.notes = newValue.isEmpty ? nil : newValue
                            }
                            .accessibilityLabel("Notes for step \(step.stepNumber)")
                    }

                    // High-risk acknowledgement
                    if step.isHighRisk {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("High-risk step")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                                Text("This step may modify system state, delete files, or make irreversible changes.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("Acknowledge", isOn: $step.riskAcknowledged)
                                .toggleStyle(.checkbox)
                                .accessibilityLabel("Acknowledge risk for step \(step.stepNumber)")
                                .accessibilityHint("Check to acknowledge you understand the risk of this step")
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.leading, 28)
                .padding(.top, 6)
                .padding(.bottom, 4)
            } label: {
                HStack(spacing: 8) {
                    // Step status icon (pending = checkbox outline)
                    Image(systemName: step.status == .completed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(step.status == .completed ? .green : .secondary)
                        .imageScale(.medium)
                        .accessibilityHidden(true)

                    // Step number badge
                    Text("\(step.stepNumber)")
                        .font(.caption.bold())
                        .frame(width: 20, height: 20)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    // Step description
                    Text(step.description)
                        .font(.body)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // High-risk badge
                    if step.isHighRisk {
                        Image(systemName: step.riskAcknowledged ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(step.riskAcknowledged ? .green : .orange)
                            .imageScale(.small)
                            .accessibilityLabel(step.riskAcknowledged ? "Risk acknowledged" : "High risk - acknowledgement required")
                    }
                }
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                step.isHighRisk && !step.riskAcknowledged
                    ? Color.orange.opacity(0.04)
                    : Color(nsColor: .controlBackgroundColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        step.isHighRisk && !step.riskAcknowledged ? Color.orange.opacity(0.3) : Color(nsColor: .separatorColor),
                        lineWidth: 0.5
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Step \(step.stepNumber): \(step.description)\(step.isHighRisk ? ", high risk" : "")")
            .onAppear {
                notesText = step.notes ?? ""
            }
        }
    }

    #Preview {
        CoworkView()
            .frame(width: 1000, height: 700)
    }

#endif
