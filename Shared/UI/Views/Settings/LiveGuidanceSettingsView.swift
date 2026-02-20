import SwiftUI

#if os(macOS)

// MARK: - Live Guidance Settings View
// UI for configuring and controlling the live screen monitoring and voice guidance system

struct LiveGuidanceSettingsView: View {
    @State private var guidance = LocalVisionGuidance.shared

    @State private var enableLiveMonitoring: Bool = false
    @State private var enableVoiceGuidance: Bool = true
    @State private var selectedCaptureMode: Int = 0 // 0=Full Screen, 1=Active Window, 2=Region
    @State private var currentTaskText: String = ""
    @State private var allowControlHandoff: Bool = false
    @State private var analyzeInterval: Double = 2.0

    @State private var isLoadingModel: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        Form {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "eye.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text("Live Screen Monitoring")
                                .font(.title)
                            Text("Real-time visual guidance powered by on-device AI")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if guidance.visionModelLoaded {
                        Label("Qwen2-VL 7B loaded", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 8)
            }

            // Status
            Section("Status") {
                HStack {
                    Text("Guidance Active")
                    Spacer()
                    Text(guidance.isGuiding ? "Running" : "Stopped")
                        .foregroundStyle(guidance.isGuiding ? .green : .secondary)
                }

                if guidance.isGuiding {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Task")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(guidance.currentTask)
                            .font(.body)
                    }

                    if !guidance.currentInstruction.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latest Instruction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        Text(guidance.currentInstruction)
                                .font(.body)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }

            // Settings
            Section("Configuration") {
                Toggle("Enable voice guidance", isOn: $enableVoiceGuidance)
                    .onChange(of: enableVoiceGuidance) { _, newValue in
                        guidance.voiceGuidanceEnabled = newValue
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $selectedCaptureMode) {
                        Text("Full Screen").tag(0)
                        Text("Active Window").tag(1)
                        Text("Selected Area").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedCaptureMode) { _, newValue in
                        updateCaptureMode(newValue)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Analysis Interval: \(String(format: "%.1f", analyzeInterval))s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $analyzeInterval, in: 1.0...10.0, step: 0.5)
                        .onChange(of: analyzeInterval) { _, newValue in
                            guidance.guidanceIntervalSeconds = newValue
                        }
                }

                Toggle("Allow Thea to perform actions (control handoff)", isOn: $allowControlHandoff)
                    .onChange(of: allowControlHandoff) { _, newValue in
                        guidance.allowControlHandoff = newValue
                    }
            }

            // Task Input
            Section("Task") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Describe the task you want guidance for")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("e.g., Clean up expired certificates in Apple Developer Portal", text: $currentTaskText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.textBackground)
                        .cornerRadius(6)
                        .lineLimit(3...6)
                }
            }

            // Actions
            Section {
                VStack(spacing: 12) {
                    if !guidance.isGuiding {
                        Button(action: startGuidance) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Guidance")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(currentTaskText.isEmpty || isLoadingModel)

                        if isLoadingModel {
                            ProgressView("Loading Qwen2-VL model...")
                                .font(.caption)
                        }
                    } else {
                        Button(action: stopGuidance) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Stop Guidance")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            }

            // Permissions
            Section("Permissions") {
                permissionRow(
                    title: "Screen Recording",
                    granted: guidance.screenCaptureIsAuthorized
                ) {
                    Task {
                        do {
                            try await guidance.requestScreenCapturePermission()
                        } catch {
                            errorMessage = "Failed to request screen recording permission: \(error.localizedDescription)"
                            showError = true
                        }
                    }
                }

                permissionRow(
                    title: "Accessibility (Pointer Tracking)",
                    granted: guidance.pointerTrackerHasPermission
                ) {
                    guidance.requestPointerPermission()
                }

                permissionRow(
                    title: "Accessibility (Control Handoff)",
                    granted: guidance.actionExecutorHasPermission
                ) {
                    guidance.requestActionExecutorPermission()
                }
            }

            // Info
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Privacy-First", systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("All vision processing runs on-device using Qwen2-VL. No screenshots are sent to cloud APIs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadInitialSettings()
        }
    }

    // MARK: - Helper Views

    private func permissionRow(title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Actions

    private func loadInitialSettings() {
        enableVoiceGuidance = guidance.voiceGuidanceEnabled
        allowControlHandoff = guidance.allowControlHandoff
        analyzeInterval = guidance.guidanceIntervalSeconds

        switch guidance.captureMode {
        case .fullScreen:
            selectedCaptureMode = 0
        case .activeWindow:
            selectedCaptureMode = 1
        case .window:
            selectedCaptureMode = 1  // Treat specific window like active window
        case .region:
            selectedCaptureMode = 2
        }
    }

    private func updateCaptureMode(_ mode: Int) {
        switch mode {
        case 0:
            guidance.captureMode = .fullScreen
        case 1:
            guidance.captureMode = .activeWindow
        case 2:
            // TODO: Show region selection UI
            guidance.captureMode = .region(CGRect(x: 0, y: 0, width: 800, height: 600))
        default:
            break
        }
    }

    private func startGuidance() {
        isLoadingModel = true

        Task {
            do {
                try await guidance.startGuidance(task: currentTaskText)
                isLoadingModel = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isLoadingModel = false
            }
        }
    }

    private func stopGuidance() {
        Task {
            await guidance.stopGuidance()
        }
    }
}

#Preview {
    LiveGuidanceSettingsView()
        .frame(width: 600, height: 800)
}

#endif
