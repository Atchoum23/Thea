import SwiftUI

#if os(macOS)

// MARK: - Live Guidance Settings View
// Complete UI for configuring and controlling live screen monitoring + voice guidance

struct LiveGuidanceSettingsView: View {
    @State private var guidance = LocalVisionGuidance.shared
    @State private var screenCapture = ScreenCaptureManager.shared
    @State private var pointerTracker = PointerTracker.shared
    @State private var actionExecutor = ActionExecutor.shared

    @State private var isMonitoringEnabled = false
    @State private var isVoiceEnabled = true
    @State private var currentTask = ""
    @State private var selectedCaptureMode: ScreenCaptureManager.CaptureMode = .fullScreen
    @State private var allowControlHandoff = false

    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""

    @State private var isStartingGuidance = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            // Status Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: guidance.isGuiding ? "eye.fill" : "eye.slash")
                            .foregroundStyle(guidance.isGuiding ? .green : .secondary)
                        Text(guidance.isGuiding ? "Live Guidance Active" : "Live Guidance Inactive")
                            .font(.headline)
                        Spacer()
                        if guidance.isLoadingModels {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    if guidance.modelsReady {
                        Label("Models Ready", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Label("Models Not Loaded", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }

                    if guidance.isGuiding && !guidance.currentInstruction.isEmpty {
                        Text("Current Instruction:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(guidance.currentInstruction)
                            .font(.body)
                            .padding(8)
                            .background(Color.theaPrimaryDefault.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            } header: {
                Text("Status")
            }

            // Permissions Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // Screen Recording Permission
                    HStack {
                        Image(systemName: screenCapture.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(screenCapture.isAuthorized ? .green : .red)
                        Text("Screen Recording")
                        Spacer()
                        if !screenCapture.isAuthorized {
                            Button("Grant Permission") {
                                Task {
                                    try? await screenCapture.requestAuthorization()
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    // Accessibility Permission (for pointer tracking + actions)
                    if allowControlHandoff {
                        HStack {
                            Image(systemName: actionExecutor.hasPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(actionExecutor.hasPermission ? .green : .red)
                            Text("Accessibility (for control handoff)")
                            Spacer()
                            if !actionExecutor.hasPermission {
                                Button("Grant Permission") {
                                    actionExecutor.requestPermission()
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Text("Live Guidance requires Screen Recording permission to capture your screen. Control handoff requires Accessibility permission to simulate user actions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Permissions")
            }

            // Configuration Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // Enable Live Monitoring Toggle
                    Toggle("Enable live screen monitoring", isOn: $isMonitoringEnabled)

                    // Enable Voice Guidance Toggle
                    Toggle("Enable voice guidance", isOn: $isVoiceEnabled)
                        .disabled(!isMonitoringEnabled)

                    // Capture Mode Picker
                    Picker("Capture mode", selection: $selectedCaptureMode) {
                        Text("Full Screen").tag(ScreenCaptureManager.CaptureMode.fullScreen)
                        Text("Active Window").tag(ScreenCaptureManager.CaptureMode.activeWindow)
                    }
                    .disabled(!isMonitoringEnabled)

                    // Allow Control Handoff Toggle
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Allow control handoff", isOn: $allowControlHandoff)
                            .disabled(!isMonitoringEnabled)

                        Text("When enabled, Thea can perform actions on your behalf (click, type, etc.)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Configuration")
            }

            // Task Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Describe what you want to accomplish:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("e.g., Clean up expired certificates in Apple Developer Portal", text: $currentTask)
                        .textFieldStyle(.roundedBorder)
                        .disabled(guidance.isGuiding)

                    HStack {
                        if guidance.isGuiding {
                            Button("Stop Guidance") {
                                Task {
                                    await guidance.stopGuidance()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                            Button("Start Guidance") {
                                Task {
                                    await startGuidance()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(currentTask.isEmpty || !isMonitoringEnabled || isStartingGuidance)

                            if isStartingGuidance {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }

                        Spacer()

                        if !guidance.modelsReady && !guidance.isLoadingModels {
                            Button("Load Models") {
                                Task {
                                    await loadModels()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            } header: {
                Text("Current Task")
            }

            // Advanced Settings
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Guidance interval:")
                        Spacer()
                        Text("\(Int(guidance.guidanceIntervalSeconds))s")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $guidance.guidanceIntervalSeconds, in: 1...10, step: 1)
                        .disabled(guidance.isGuiding)

                    Text("How often Thea analyzes the screen and provides guidance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Advanced")
            }

            // Model Info
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Vision Model:")
                        Spacer()
                        if guidance.visionModelLoaded {
                            Label("Qwen2-VL 7B", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text("Not loaded")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }

                    HStack {
                        Text("Voice Model:")
                        Spacer()
                        if guidance.voiceModelLoaded {
                            Label("Soprano-80M", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text("Not loaded")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }

                    Text("All processing happens on-device. No API calls or internet required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Models")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 600, minHeight: 700)
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(permissionAlertMessage)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: isVoiceEnabled) { _, newValue in
            guidance.voiceGuidanceEnabled = newValue
        }
        .onChange(of: selectedCaptureMode) { _, newValue in
            guidance.captureMode = newValue
        }
        .onChange(of: allowControlHandoff) { _, newValue in
            guidance.allowControlHandoff = newValue
        }
    }

    // MARK: - Actions

    private func loadModels() async {
        do {
            try await guidance.loadModels()
        } catch {
            errorMessage = "Failed to load models: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func startGuidance() async {
        // Check permissions
        guard screenCapture.isAuthorized else {
            permissionAlertMessage = "Screen Recording permission is required. Please grant permission in System Settings → Privacy & Security → Screen Recording."
            showingPermissionAlert = true
            return
        }

        if allowControlHandoff && !actionExecutor.hasPermission {
            permissionAlertMessage = "Accessibility permission is required for control handoff. Please grant permission in System Settings → Privacy & Security → Accessibility."
            showingPermissionAlert = true
            return
        }

        isStartingGuidance = true
        defer { isStartingGuidance = false }

        do {
            try await guidance.startGuidance(task: currentTask)
        } catch {
            errorMessage = "Failed to start guidance: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    LiveGuidanceSettingsView()
        .frame(width: 700, height: 800)
}

#endif
