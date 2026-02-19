// VoiceModeControllerTypes.swift
// Supporting types and views for VoiceModeController

import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "ai.thea.app", category: "VoiceModeControllerTypes")

// MARK: - Voice Mode State

/// Current state of voice mode
public enum VoiceModeState: Equatable, Sendable {
    case idle
    case listening
    case activated
    case processing
    case responding
    case error(String)

    var displayName: String {
        switch self {
        case .idle: return "Off"
        case .listening: return "Listening..."
        case .activated: return "Speak now"
        case .processing: return "Processing..."
        case .responding: return "Responding..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var icon: String {
        switch self {
        case .idle: return "mic.slash"
        case .listening: return "waveform"
        case .activated: return "mic.fill"
        case .processing: return "brain.head.profile"
        case .responding: return "speaker.wave.3.fill"
        case .error: return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .secondary
        case .listening: return .blue
        case .activated: return .green
        case .processing: return .orange
        case .responding: return .purple
        case .error: return .red
        }
    }
}

// MARK: - Voice Settings

/// Configuration for voice mode
public struct VoiceSettings: Codable, Sendable {
    public var wakeWord: String = "Hey THEA"
    public var sensitivity: WakeWordSensitivity = .medium
    public var confirmActivation: Bool = true
    public var voiceFeedback: Bool = true
    public var continuousListening: Bool = false
    public var silenceTimeout: TimeInterval = 3.0
    public var preferredLanguage: String = "en-US"

    public enum WakeWordSensitivity: String, Codable, Sendable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var threshold: Float {
            switch self {
            case .low: return 0.85
            case .medium: return 0.75
            case .high: return 0.65
            }
        }
    }

    public static let `default` = VoiceSettings()
}

// MARK: - Errors

public enum VoiceModeError: LocalizedError {
    case permissionDenied
    case speechRecognizerUnavailable
    case recognitionRequestFailed
    case audioEngineError

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone or speech recognition permission denied"
        case .speechRecognizerUnavailable:
            return "Speech recognizer is not available"
        case .recognitionRequestFailed:
            return "Failed to create recognition request"
        case .audioEngineError:
            return "Audio engine error"
        }
    }
}

// MARK: - Voice Mode Button

/// Floating button for voice mode activation
public struct VoiceModeButton: View {
    @ObservedObject var controller = VoiceModeController.shared
    @State private var isAnimating = false

    public init() {}

    public var body: some View {
        Button {
            Task {
                if controller.isVoiceModeEnabled {
                    controller.stopVoiceMode()
                } else {
                    do {
                        try await controller.startVoiceMode()
                    } catch {
                        logger.error("Failed to start voice mode: \(error.localizedDescription)")
                    }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(controller.state.color.opacity(0.2))
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .opacity(isAnimating ? 0 : 0.5)

                Circle()
                    .fill(controller.state.color.gradient)
                    .frame(width: 56, height: 56)

                Image(systemName: controller.state.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .repeating, isActive: controller.state == .listening)
            }
        }
        .buttonStyle(.plain)
        .onChange(of: controller.state) { _, newState in
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = (newState == .listening)
            }
        }
        .help(controller.state.displayName)
    }
}

// MARK: - Voice Waveform View

/// Animated waveform visualization for audio input
public struct VoiceWaveformView: View {
    @ObservedObject var controller = VoiceModeController.shared
    let barCount: Int = 5

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    level: controller.audioLevel,
                    delay: Double(index) * 0.1
                )
            }
        }
        .frame(height: 32)
    }
}

private struct WaveformBar: View {
    let level: Float
    let delay: Double

    @State private var height: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor.gradient)
            .frame(width: 4, height: height)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.5)
                    .delay(delay),
                value: height
            )
            .onChange(of: level) { _, newLevel in
                let targetHeight = 4 + CGFloat(newLevel) * 28
                height = max(4, min(32, targetHeight))
            }
    }
}

// MARK: - Voice Mode Settings View

/// Settings panel for voice mode
public struct VoiceModeSettingsView: View {
    @ObservedObject var controller = VoiceModeController.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Wake Word") {
                TextField("Wake word", text: $controller.settings.wakeWord)
                    .textFieldStyle(.roundedBorder)

                Picker("Sensitivity", selection: $controller.settings.sensitivity) {
                    ForEach(VoiceSettings.WakeWordSensitivity.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Play activation sound", isOn: $controller.settings.confirmActivation)
                Toggle("Voice feedback (TTS)", isOn: $controller.settings.voiceFeedback)
                Toggle("Continuous listening", isOn: $controller.settings.continuousListening)

                HStack {
                    Text("Silence timeout")
                    Spacer()
                    Text("\(controller.settings.silenceTimeout, specifier: "%.1f")s")
                        .foregroundStyle(.secondary)
                    Stepper("", value: $controller.settings.silenceTimeout, in: 1...10, step: 0.5)
                        .labelsHidden()
                }
            }

            Section("Language") {
                Picker("Language", selection: $controller.settings.preferredLanguage) {
                    Text("English (US)").tag("en-US")
                    Text("English (UK)").tag("en-GB")
                    Text("Spanish").tag("es-ES")
                    Text("French").tag("fr-FR")
                    Text("German").tag("de-DE")
                    Text("Italian").tag("it-IT")
                    Text("Japanese").tag("ja-JP")
                    Text("Chinese").tag("zh-CN")
                }
            }

            Section("Permissions") {
                PermissionRow(
                    title: "Microphone",
                    isGranted: controller.hasMicrophonePermission
                )

                PermissionRow(
                    title: "Speech Recognition",
                    isGranted: controller.hasSpeechPermission
                )

                if !controller.hasMicrophonePermission || !controller.hasSpeechPermission {
                    Button("Request Permissions") {
                        Task {
                            await controller.requestPermissions()
                        }
                    }
                }
            }
        }
        .navigationTitle("Voice Mode")
    }
}

private struct PermissionRow: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isGranted ? .green : .red)
        }
    }
}

// MARK: - Voice Overlay View

/// Full-screen overlay when voice mode is active
public struct VoiceModeOverlay: View {
    @ObservedObject var controller = VoiceModeController.shared
    // periphery:ignore - Reserved: colorScheme property reserved for future feature activation
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if controller.state != .idle {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        controller.stopVoiceMode()
                    }

                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        ZStack {
                            ForEach(0..<3) { i in
                                Circle()
                                    .stroke(controller.state.color.opacity(0.3), lineWidth: 2)
                                    .scaleEffect(1.0 + CGFloat(i) * 0.3)
                                    .animation(
                                        .easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.2),
                                        value: controller.state
                                    )
                            }

                            TheaSpiralIconView(
                                size: 80,
                                isThinking: controller.state == .processing,
                                showGlow: controller.state == .activated
                            )
                        }
                        .frame(width: 160, height: 160)

                        Text(controller.state.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    if controller.state == .listening || controller.state == .activated {
                        VoiceWaveformView()
                            .frame(height: 48)
                            .padding(.horizontal, 60)
                    }

                    if !controller.transcribedText.isEmpty {
                        Text(controller.transcribedText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .transition(.opacity)
                    }

                    Button("Cancel") {
                        controller.stopVoiceMode()
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.secondary)
                }
            }
            .transition(.opacity)
            .animation(.easeInOut, value: controller.state)
        }
    }
}
