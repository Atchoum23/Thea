// WakeWordSettingsView.swift
// Settings UI for "Hey, Thea" wake word detection

import SwiftUI

struct WakeWordSettingsView: View {
    @State private var wakeWordEngine = WakeWordEngine.shared
    @State private var configuration = WakeWordEngine.shared.configuration
    @State private var isTrainingSpeaker = false
    @State private var trainingProgress: Double = 0
    @State private var trainingSamples: [Data] = []
    @State private var showingTrainingSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        Form {
            // Status Section
            Section {
                HStack {
                    statusIndicator
                    VStack(alignment: .leading, spacing: 4) {
                        Text(wakeWordEngine.isListening ? "Listening" : "Not Listening")
                            .font(.headline)
                        Text(wakeWordEngine.isActive ? "Active and ready" : "Paused or stopped")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { wakeWordEngine.isListening },
                        set: { newValue in
                            Task {
                                if newValue {
                                    try? await wakeWordEngine.startListening()
                                } else {
                                    wakeWordEngine.stopListening()
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                }

                if let lastDetection = wakeWordEngine.lastDetectedWakeWord {
                    HStack {
                        Text("Last Detection")
                            .foregroundStyle(.secondary)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(lastDetection.wakeWord.displayName)
                                .font(.headline)
                            Text(lastDetection.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Confidence")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(lastDetection.confidence * 100))%")
                            .foregroundStyle(confidenceColor(lastDetection.confidence))
                    }
                }
            } header: {
                Text("Status")
            } footer: {
                Text("Wake word detection runs continuously in the background with minimal battery impact.")
            }

            // Wake Words Section
            Section {
                ForEach(WakeWordEngine.WakeWord.allCases, id: \.rawValue) { wakeWord in
                    Toggle(wakeWord.displayName, isOn: Binding(
                        get: { configuration.enabledWakeWords.contains(wakeWord.rawValue) },
                        set: { enabled in
                            if enabled {
                                configuration.enabledWakeWords.insert(wakeWord.rawValue)
                            } else {
                                configuration.enabledWakeWords.remove(wakeWord.rawValue)
                            }
                            saveConfiguration()
                        }
                    ))
                }
            } header: {
                Text("Wake Words")
            } footer: {
                Text("Enable the phrases that will activate Thea. You can use both \"Hey, Thea\" and just \"Thea\".")
            }

            // Sensitivity Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Detection Sensitivity")
                        Spacer()
                        Text(sensitivityLabel)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $configuration.sensitivity, in: 0...1, step: 0.05)
                        .onChange(of: configuration.sensitivity) { _, _ in
                            saveConfiguration()
                        }

                    HStack {
                        Text("Strict")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Permissive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Power Mode", selection: $configuration.powerMode) {
                    ForEach(WakeWordEngine.PowerLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .onChange(of: configuration.powerMode) { _, _ in
                    saveConfiguration()
                }
            } header: {
                Text("Detection Settings")
            } footer: {
                Text("Higher sensitivity means fewer missed wake words but may have more false activations. \(configuration.powerMode.description)")
            }

            // Speaker Verification Section
            Section {
                Toggle("Enable Speaker Verification", isOn: $configuration.enableSpeakerVerification)
                    .onChange(of: configuration.enableSpeakerVerification) { _, _ in
                        saveConfiguration()
                    }

                if configuration.enableSpeakerVerification {
                    Button {
                        showingTrainingSheet = true
                    } label: {
                        HStack {
                            Label("Train Voice Recognition", systemImage: "waveform.badge.plus")
                            Spacer()
                            if isTrainingSpeaker {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isTrainingSpeaker)
                }
            } header: {
                Text("Personalization")
            } footer: {
                Text("Speaker verification ensures only you can activate Thea. Train with your voice for best results.")
            }

            // Feedback Section
            Section {
                Toggle("Haptic Feedback", isOn: $configuration.enableHapticFeedback)
                    .onChange(of: configuration.enableHapticFeedback) { _, _ in
                        saveConfiguration()
                    }

                Toggle("Audio Feedback", isOn: $configuration.enableAudioFeedback)
                    .onChange(of: configuration.enableAudioFeedback) { _, _ in
                        saveConfiguration()
                    }

                Toggle("Continuous Listening", isOn: $configuration.continuousListening)
                    .onChange(of: configuration.continuousListening) { _, _ in
                        saveConfiguration()
                    }
            } header: {
                Text("Feedback")
            } footer: {
                Text("Continuous listening keeps wake word detection active even during conversations.")
            }

            // Advanced Section
            Section {
                HStack {
                    Text("Timeout After Detection")
                    Spacer()
                    Text("\(Int(configuration.timeoutAfterDetection))s")
                        .foregroundStyle(.secondary)
                }

                Stepper("Timeout: \(Int(configuration.timeoutAfterDetection))s",
                        value: $configuration.timeoutAfterDetection,
                        in: 5...60,
                        step: 5)
                .onChange(of: configuration.timeoutAfterDetection) { _, _ in
                    saveConfiguration()
                }

                HStack {
                    Text("Cooldown Between Detections")
                    Spacer()
                    Text("\(String(format: "%.1f", configuration.cooldownBetweenDetections))s")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $configuration.cooldownBetweenDetections, in: 0.5...5, step: 0.5)
                    .onChange(of: configuration.cooldownBetweenDetections) { _, _ in
                        saveConfiguration()
                    }
            } header: {
                Text("Advanced")
            }

            // Statistics Section
            Section {
                HStack {
                    Text("Total Detections")
                    Spacer()
                    Text("\(wakeWordEngine.totalDetections)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("False Rejections")
                    Spacer()
                    Text("\(wakeWordEngine.falseRejections)")
                        .foregroundStyle(wakeWordEngine.falseRejections > 0 ? Color.theaWarning : .secondary)
                }

                HStack {
                    Text("False Acceptances")
                    Spacer()
                    Text("\(wakeWordEngine.falseAcceptances)")
                        .foregroundStyle(wakeWordEngine.falseAcceptances > 0 ? .red : .secondary)
                }

                Button("Report False Rejection") {
                    wakeWordEngine.reportFalseRejection()
                }

                Button("Report False Acceptance") {
                    wakeWordEngine.reportFalseAcceptance()
                }
            } header: {
                Text("Statistics & Feedback")
            } footer: {
                Text("Help improve detection accuracy by reporting when wake word detection fails or triggers incorrectly.")
            }

            // Test Section
            Section {
                Button {
                    wakeWordEngine.simulateWakeWordDetection(.heyThea)
                } label: {
                    Label("Test \"Hey, Thea\"", systemImage: "play.circle")
                }

                Button {
                    wakeWordEngine.simulateWakeWordDetection(.thea)
                } label: {
                    Label("Test \"Thea\"", systemImage: "play.circle")
                }
            } header: {
                Text("Testing")
            } footer: {
                Text("Simulate wake word detection to test your feedback and integration settings.")
            }
        }
        .navigationTitle("Wake Word")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingTrainingSheet) {
            SpeakerTrainingView(
                isTraining: $isTrainingSpeaker,
                progress: $trainingProgress,
                samples: $trainingSamples
            ) { samples in
                Task {
                    do {
                        try await wakeWordEngine.trainSpeakerVerification(samples: samples)
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            configuration = wakeWordEngine.configuration
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay {
                if wakeWordEngine.isActive {
                    Circle()
                        .stroke(statusColor, lineWidth: 2)
                        .scaleEffect(1.5)
                        .opacity(0.5)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: wakeWordEngine.isActive)
                }
            }
    }

    private var statusColor: Color {
        if wakeWordEngine.isListening && wakeWordEngine.isActive {
            return .green
        } else if wakeWordEngine.isListening {
            return .yellow
        } else {
            return .gray
        }
    }

    private var sensitivityLabel: String {
        switch configuration.sensitivity {
        case 0..<0.3: return "Very Strict"
        case 0.3..<0.5: return "Strict"
        case 0.5..<0.7: return "Balanced"
        case 0.7..<0.9: return "Permissive"
        default: return "Very Permissive"
        }
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.9...: return .green
        case 0.7..<0.9: return .blue
        case 0.5..<0.7: return .orange
        default: return .red
        }
    }

    private func saveConfiguration() {
        wakeWordEngine.updateConfiguration(configuration)
    }
}

// MARK: - Speaker Training View

struct SpeakerTrainingView: View {
    @Binding var isTraining: Bool
    @Binding var progress: Double
    @Binding var samples: [Data]
    let onComplete: ([Data]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var isRecording = false
    @State private var recordedSamples: [Data] = []

    private let requiredSamples = 5
    private let prompts = [
        "Say \"Hey, Thea\" clearly",
        "Say \"Hey, Thea\" again",
        "Now say just \"Thea\"",
        "Say \"Hey, Thea\" one more time",
        "Final sample: \"Hey, Thea\""
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Progress indicator
                ProgressView(value: Double(currentStep), total: Double(requiredSamples))
                    .progressViewStyle(.linear)
                    .padding(.horizontal)

                Text("Sample \(currentStep + 1) of \(requiredSamples)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Recording indicator
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 150, height: 150)

                    Circle()
                        .fill(isRecording ? Color.red : Color.gray)
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)
                }

                Spacer()

                // Instruction
                Text(currentStep < requiredSamples ? prompts[currentStep] : "Training complete!")
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(isRecording ? "Recording..." : "Tap the button to record")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Record button
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRecording ? Color.red : Color.theaPrimary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(currentStep >= requiredSamples)

                if currentStep >= requiredSamples {
                    Button {
                        onComplete(recordedSamples)
                        dismiss()
                    } label: {
                        Text("Complete Training")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("Voice Training")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func startRecording() {
        isRecording = true
        isTraining = true
        // In a real implementation, start audio recording here
    }

    private func stopRecording() {
        isRecording = false

        // Simulate recorded sample (in real implementation, get actual audio data)
        let mockSample = Data(repeating: 0, count: 16000 * 2) // 1 second at 16kHz
        recordedSamples.append(mockSample)

        currentStep += 1
        progress = Double(currentStep) / Double(requiredSamples)

        if currentStep >= requiredSamples {
            isTraining = false
            samples = recordedSamples
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WakeWordSettingsView()
    }
}
