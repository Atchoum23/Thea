#if os(macOS)
// SelfExecutionView.swift
import SwiftUI

@MainActor
public struct SelfExecutionView: View {
    @State private var selectedPhase: Int = 6
    @State private var executionMode: SelfExecutionService.ExecutionMode = .supervised
    @State private var isExecuting = false
    @State private var progress: String = ""
    @State private var showApprovalSheet = false
    @State private var pendingApproval: ApprovalGate.ApprovalRequest?
    @State private var readinessCheck: (ready: Bool, missingRequirements: [String]) = (false, [])

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                headerSection

                Divider()

                // Readiness Check
                readinessSection

                Divider()

                // Phase Selection
                phaseSelectionSection

                // Execution Mode
                executionModeSection

                Divider()

                // Progress
                if isExecuting {
                    progressSection
                }

                Spacer()

                // Execute Button
                executeButton
            }
            .padding()
            .navigationTitle("Self-Execution")
            .task {
                await checkReadiness()
            }
            .onReceive(NotificationCenter.default.publisher(for: .approvalRequested)) { notification in
                if let request = notification.userInfo?["request"] as? ApprovalGate.ApprovalRequest {
                    pendingApproval = request
                    showApprovalSheet = true
                }
            }
            .sheet(isPresented: $showApprovalSheet) {
                approvalSheet
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Thea Self-Execution Engine")
                .font(.headline)
            Text("Execute phases from THEA_MASTER_SPEC.md autonomously")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readinessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: readinessCheck.ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(readinessCheck.ready ? .green : .orange)
                Text(readinessCheck.ready ? "Ready to Execute" : "Setup Required")
                    .font(.subheadline.bold())
            }

            if !readinessCheck.ready {
                ForEach(readinessCheck.missingRequirements, id: \.self) { item in
                    Text("• \(item)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var phaseSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Phase")
                .font(.subheadline.bold())

            Picker("Phase", selection: $selectedPhase) {
                ForEach(6...15, id: \.self) { phase in
                    Text("Phase \(phase)").tag(phase)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var executionModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Execution Mode")
                .font(.subheadline.bold())

            Picker("Mode", selection: $executionMode) {
                Text("Supervised").tag(SelfExecutionService.ExecutionMode.supervised)
                Text("Automatic").tag(SelfExecutionService.ExecutionMode.automatic)
                Text("Dry Run").tag(SelfExecutionService.ExecutionMode.dryRun)
            }
            .pickerStyle(.segmented)

            Text(modeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modeDescription: String {
        switch executionMode {
        case .supervised:
            return "Approval required before each major step"
        case .automatic:
            return "Minimal interruptions, approval only for phase start/end"
        case .dryRun:
            return "Simulate execution without making changes"
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.subheadline.bold())

            Text(progress)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
        }
    }

    private var executeButton: some View {
        Button {
            Task {
                await executePhase()
            }
        } label: {
            HStack {
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Text(isExecuting ? "Executing..." : "Execute Phase \(selectedPhase)")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!readinessCheck.ready || isExecuting)
    }

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
}

#endif
