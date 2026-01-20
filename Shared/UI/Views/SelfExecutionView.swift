import SwiftUI

// MARK: - Self-Execution Settings View
// Configure and execute phases from THEA_MASTER_SPEC.md autonomously

#if os(macOS)

struct SelfExecutionView: View {
    @State private var selectedPhase: Int = 6
    @State private var executionMode: SelfExecutionService.ExecutionMode = .supervised
    @State private var executeAllPhases = false
    @State private var isExecuting = false
    @State private var progress: String = ""
    @State private var showApprovalSheet = false
    @State private var pendingApproval: ApprovalGate.ApprovalRequest?
    @State private var readinessCheck: (ready: Bool, missingRequirements: [String]) = (false, [])
    @State private var currentExecutingPhase: Int = 0

    var body: some View {
        Form {
            statusSection
            phaseSelectionSection
            executionModeSection

            if isExecuting || !progress.isEmpty {
                progressSection
            }

            actionSection
        }
        .formStyle(.grouped)
        .padding()
        .task {
            await checkReadiness()
        }
        .onReceive(NotificationCenter.default.publisher(for: .approvalRequested)) { notification in
            if let request = notification.userInfo?["request"] as? ApprovalGate.ApprovalRequest {
                // In fullAuto mode, auto-approve everything
                if executionMode == .fullAuto {
                    Task {
                        await ApprovalGate.shared.approve()
                    }
                } else {
                    pendingApproval = request
                    showApprovalSheet = true
                }
            }
        }
        .sheet(isPresented: $showApprovalSheet) {
            approvalSheet
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Image(systemName: readinessCheck.ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(readinessCheck.ready ? .green : .orange)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(readinessCheck.ready ? "Ready to Execute" : "Setup Required")
                        .font(.headline)
                    Text("Execute phases from THEA_MASTER_SPEC.md autonomously")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Refresh") {
                    Task {
                        await checkReadiness()
                    }
                }
                .buttonStyle(.bordered)
            }

            if !readinessCheck.ready {
                ForEach(readinessCheck.missingRequirements, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red)
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Phase Selection Section

    private var phaseSelectionSection: some View {
        Section("Phase Selection") {
            Toggle("Execute All Remaining Phases (6-15)", isOn: $executeAllPhases)

            if !executeAllPhases {
                HStack {
                    Text("Phase to Execute")
                    Spacer()
                    Picker("", selection: $selectedPhase) {
                        ForEach(6...15, id: \.self) { phase in
                            Text("Phase \(phase)").tag(phase)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                Text(phaseDescription(for: selectedPhase))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Will execute phases 6 through 15 sequentially")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func phaseDescription(for phase: Int) -> String {
        switch phase {
        case 6: return "Testing infrastructure and debugging"
        case 7: return "Storage optimization"
        case 8: return "AI orchestration"
        case 9: return "Voice activation"
        case 10: return "Life tracking integration"
        case 11: return "Local LLM integration"
        case 12: return "iOS support"
        case 13: return "Desktop widget"
        case 14: return "Accessibility and localization"
        case 15: return "Release preparation"
        default: return "Phase \(phase) implementation"
        }
    }

    // MARK: - Execution Mode Section

    private var executionModeSection: some View {
        Section("Execution Mode") {
            Picker("Mode", selection: $executionMode) {
                Text("Supervised").tag(SelfExecutionService.ExecutionMode.supervised)
                Text("Automatic").tag(SelfExecutionService.ExecutionMode.automatic)
                Text("Full Auto").tag(SelfExecutionService.ExecutionMode.fullAuto)
                Text("Dry Run").tag(SelfExecutionService.ExecutionMode.dryRun)
            }
            .pickerStyle(.segmented)

            Text(modeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            if executionMode == .fullAuto {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Full Auto mode will execute without any approval prompts. Use with caution!")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.top, 4)
            }
        }
    }

    private var modeDescription: String {
        switch executionMode {
        case .supervised:
            return "Approval required before each major step"
        case .automatic:
            return "Minimal interruptions, approval only for phase start/end"
        case .fullAuto:
            return "No interruptions - all approvals auto-granted"
        case .dryRun:
            return "Simulate execution without making changes"
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        Section("Progress") {
            if isExecuting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    if executeAllPhases {
                        Text("Executing Phase \(currentExecutingPhase) of 15...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Executing Phase \(selectedPhase)...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ScrollView {
                Text(progress)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 200)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        Section {
            HStack {
                Spacer()

                if executeAllPhases {
                    Button {
                        Task {
                            await executeAllPhasesSequentially()
                        }
                    } label: {
                        HStack {
                            if isExecuting {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "bolt.horizontal.fill")
                            }
                            Text(isExecuting ? "Executing All..." : "Execute All Phases (6-15)")
                        }
                        .frame(minWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                    .disabled(!readinessCheck.ready || isExecuting)
                } else {
                    Button {
                        Task {
                            await executePhase()
                        }
                    } label: {
                        HStack {
                            if isExecuting {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "bolt.fill")
                            }
                            Text(isExecuting ? "Executing..." : "Execute Phase \(selectedPhase)")
                        }
                        .frame(minWidth: 180)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!readinessCheck.ready || isExecuting)
                }

                Spacer()
            }

            if isExecuting {
                HStack {
                    Spacer()
                    Button("Cancel Execution") {
                        Task {
                            await SelfExecutionService.shared.cancelExecution()
                            isExecuting = false
                            progress += "\n⚠️ Execution cancelled by user"
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Approval Sheet

    private var approvalSheet: some View {
        VStack(spacing: 20) {
            if let approval = pendingApproval {
                Text("Approval Required")
                    .font(.headline)

                Text(approval.description)
                    .font(.body)

                Text(approval.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)

                HStack(spacing: 20) {
                    Button("Reject") {
                        Task {
                            await ApprovalGate.shared.reject(reason: "User rejected")
                            showApprovalSheet = false
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Approve") {
                        Task {
                            await ApprovalGate.shared.approve()
                            showApprovalSheet = false
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Approve All") {
                        Task {
                            executionMode = .fullAuto
                            await ApprovalGate.shared.approve()
                            showApprovalSheet = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
        }
        .padding()
        .frame(minWidth: 400)
    }

    // MARK: - Actions

    private func checkReadiness() async {
        readinessCheck = await SelfExecutionService.shared.checkReadiness()
    }

    private func executePhase() async {
        isExecuting = true
        currentExecutingPhase = selectedPhase
        progress = "Starting Phase \(selectedPhase)...\n"

        do {
            let request = SelfExecutionService.ExecutionRequest(
                phaseNumber: selectedPhase,
                mode: executionMode
            )

            let result = try await SelfExecutionService.shared.execute(request: request)

            progress += """

            ✅ Phase \(selectedPhase) Complete!
            Files created: \(result.filesCreated)
            Errors fixed: \(result.errorsFixed)
            Duration: \(Int(result.duration / 60)) minutes
            """

            if let dmg = result.dmgPath {
                progress += "\nDMG: \(dmg)"
            }
        } catch {
            progress += "\n❌ Error: \(error.localizedDescription)"
        }

        isExecuting = false
    }

    private func executeAllPhasesSequentially() async {
        isExecuting = true
        progress = "🚀 Starting execution of all phases (6-15)...\n"
        progress += "Mode: \(executionMode == .fullAuto ? "Full Auto (no interruptions)" : executionMode.rawValue)\n\n"

        var totalFilesCreated = 0
        var totalErrorsFixed = 0
        let startTime = Date()

        for phase in 6...15 {
            currentExecutingPhase = phase
            progress += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            progress += "📦 Phase \(phase): \(phaseDescription(for: phase))\n"

            do {
                let request = SelfExecutionService.ExecutionRequest(
                    phaseNumber: phase,
                    mode: executionMode
                )

                let result = try await SelfExecutionService.shared.execute(request: request)

                totalFilesCreated += result.filesCreated
                totalErrorsFixed += result.errorsFixed

                progress += "✅ Phase \(phase) Complete!\n"
                progress += "   Files: \(result.filesCreated), Errors fixed: \(result.errorsFixed)\n\n"

                if let dmg = result.dmgPath {
                    progress += "   DMG: \(dmg)\n"
                }
            } catch {
                progress += "❌ Phase \(phase) Failed: \(error.localizedDescription)\n"
                progress += "⚠️ Stopping execution due to error.\n"
                break
            }
        }

        let totalDuration = Date().timeIntervalSince(startTime)
        progress += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        progress += "🎉 ALL PHASES COMPLETE!\n"
        progress += "Total files created: \(totalFilesCreated)\n"
        progress += "Total errors fixed: \(totalErrorsFixed)\n"
        progress += "Total duration: \(Int(totalDuration / 60)) minutes\n"

        isExecuting = false
    }
}

// MARK: - Preview

#Preview {
    SelfExecutionView()
        .frame(width: 600, height: 700)
}

#endif
