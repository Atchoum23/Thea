//
//  VoiceModeController.swift
//  Thea
//
//  Voice Mode Controller - enables hands-free interaction with THEA
//  using wake word detection ("Hey THEA") and continuous voice input.
//
//  Based on 2026 voice assistant best practices.
//
//  Copyright 2026. All rights reserved.
//

import Foundation
import SwiftUI
import Speech
import AVFoundation
import os.log

// MARK: - Voice Mode State

/// Current state of voice mode
public enum VoiceModeState: Equatable, Sendable {
    case idle                    // Voice mode off
    case listening               // Listening for wake word
    case activated               // Wake word detected, ready for command
    case processing              // Processing voice input
    case responding              // THEA is responding
    case error(String)           // Error occurred

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

// MARK: - Voice Mode Controller

/// Main controller for voice-based interaction with THEA
@MainActor
public final class VoiceModeController: NSObject, ObservableObject {
    public static let shared = VoiceModeController()

    private let logger = Logger(subsystem: "ai.thea.app", category: "VoiceMode")

    // MARK: - Published State

    @Published public private(set) var state: VoiceModeState = .idle
    @Published public private(set) var transcribedText: String = ""
    @Published public private(set) var audioLevel: Float = 0.0
    @Published public private(set) var isVoiceModeEnabled: Bool = false
    @Published public var settings: VoiceSettings = .default {
        didSet { saveSettings() }
    }

    /// Whether we have necessary permissions
    @Published public private(set) var hasMicrophonePermission: Bool = false
    @Published public private(set) var hasSpeechPermission: Bool = false

    // MARK: - Audio Components

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechSynthesizer = AVSpeechSynthesizer()

    // MARK: - Internal State

    private var wakeWordDetected = false
    private var silenceTimer: Timer?
    private var commandBuffer: String = ""
    private var lastAudioTime = Date()

    // MARK: - Callbacks

    /// Called when a voice command is ready to be processed
    public var onCommand: ((String) -> Void)?

    /// Called when THEA should speak a response
    public var onSpeak: ((String) -> Void)?

    // MARK: - Initialization

    override private init() {
        super.init()
        loadSettings()

        // Initialize speech recognizer with preferred language
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: settings.preferredLanguage))
        speechSynthesizer.delegate = self

        Task {
            await checkPermissions()
        }

        logger.info("VoiceModeController initialized")
    }

    // MARK: - Public API

    /// Start voice mode (begin listening for wake word)
    public func startVoiceMode() async throws {
        guard hasMicrophonePermission && hasSpeechPermission else {
            throw VoiceModeError.permissionDenied
        }

        guard speechRecognizer?.isAvailable == true else {
            throw VoiceModeError.speechRecognizerUnavailable
        }

        isVoiceModeEnabled = true
        state = .listening

        try await startListening()
        logger.info("Voice mode started")
    }

    /// Stop voice mode completely
    public func stopVoiceMode() {
        stopListening()
        isVoiceModeEnabled = false
        state = .idle
        logger.info("Voice mode stopped")
    }

    /// Temporarily pause listening
    public func pauseListening() {
        stopListening()
        if isVoiceModeEnabled {
            state = .idle
        }
    }

    /// Resume listening after pause
    public func resumeListening() async throws {
        guard isVoiceModeEnabled else { return }
        try await startListening()
    }

    /// Manually trigger activation (bypass wake word)
    public func manualActivate() {
        wakeWordDetected = true
        state = .activated
        transcribedText = ""
        commandBuffer = ""

        if settings.voiceFeedback {
            playActivationSound()
        }
    }

    /// Speak a response using text-to-speech
    public func speak(_ text: String) {
        state = .responding

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: settings.preferredLanguage)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        speechSynthesizer.speak(utterance)
        logger.info("Speaking response: \(text.prefix(50))...")
    }

    /// Stop speaking
    public func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        if isVoiceModeEnabled {
            state = .listening
        }
    }

    /// Request permissions
    public func requestPermissions() async {
        await requestMicrophonePermission()
        await requestSpeechPermission()
    }

    // MARK: - Private Methods

    private func checkPermissions() async {
        #if os(macOS)
        // Check microphone on macOS
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            hasMicrophonePermission = true
        default:
            hasMicrophonePermission = false
        }
        #else
        // Check microphone on iOS
        hasMicrophonePermission = await AVAudioApplication.requestRecordPermission()
        #endif

        // Check speech recognition
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            hasSpeechPermission = true
        default:
            hasSpeechPermission = false
        }
    }

    private func requestMicrophonePermission() async {
        #if os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            await MainActor.run {
                hasMicrophonePermission = granted
            }
        }
        #else
        hasMicrophonePermission = await AVAudioApplication.requestRecordPermission()
        #endif
    }

    private func requestSpeechPermission() async {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    Task { @MainActor in
                        self.hasSpeechPermission = (status == .authorized)
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func startListening() async throws {
        // Configure audio session
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        // Create and configure the speech recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw VoiceModeError.recognitionRequestFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Use server for better accuracy

        // Get the audio input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on the input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.updateAudioLevel(buffer: buffer)
        }

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }

        // Start the audio engine
        audioEngine.prepare()
        try audioEngine.start()

        state = .listening
    }

    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioLevel = 0.0
    }

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error {
            logger.error("Recognition error: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
            return
        }

        guard let result else { return }

        let transcript = result.bestTranscription.formattedString.lowercased()

        // Update UI with transcribed text
        transcribedText = result.bestTranscription.formattedString

        if !wakeWordDetected {
            // Check for wake word
            if isWakeWordDetected(in: transcript) {
                wakeWordDetected = true
                state = .activated
                commandBuffer = ""

                if settings.voiceFeedback {
                    playActivationSound()
                }

                logger.info("Wake word detected!")
            }
        } else {
            // Accumulate command after wake word
            let afterWakeWord = extractCommandAfterWakeWord(transcript)
            commandBuffer = afterWakeWord

            // Reset silence timer
            lastAudioTime = Date()
            resetSilenceTimer()
        }

        // If final result and we have a command, process it
        if result.isFinal && wakeWordDetected && !commandBuffer.isEmpty {
            processCommand(commandBuffer)
        }
    }

    private func isWakeWordDetected(in transcript: String) -> Bool {
        let normalizedWakeWord = settings.wakeWord.lowercased()
        let variations = [
            normalizedWakeWord,
            normalizedWakeWord.replacingOccurrences(of: "thea", with: "theia"),
            normalizedWakeWord.replacingOccurrences(of: "thea", with: "thayer"),
            normalizedWakeWord.replacingOccurrences(of: "hey", with: "hay"),
            "hey thea",
            "hey theia",
            "hi thea",
            "okay thea"
        ]

        for variation in variations {
            if transcript.contains(variation) {
                return true
            }
        }
        return false
    }

    private func extractCommandAfterWakeWord(_ transcript: String) -> String {
        let patterns = ["hey thea", "hey theia", "hi thea", "okay thea", settings.wakeWord.lowercased()]
        var command = transcript.lowercased()

        for pattern in patterns {
            if let range = command.range(of: pattern) {
                command = String(command[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        return command
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: settings.silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleSilenceTimeout()
            }
        }
    }

    private func handleSilenceTimeout() {
        if wakeWordDetected && !commandBuffer.isEmpty {
            processCommand(commandBuffer)
        } else if wakeWordDetected {
            // Timeout without command - return to listening
            wakeWordDetected = false
            state = .listening
        }
    }

    private func processCommand(_ command: String) {
        guard !command.isEmpty else { return }

        state = .processing
        wakeWordDetected = false
        silenceTimer?.invalidate()

        logger.info("Processing voice command: \(command)")
        onCommand?(command)

        // Return to listening if continuous mode
        if settings.continuousListening {
            state = .listening
        } else {
            state = .idle
        }
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0

        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }

        let average = sum / Float(frameLength)
        let normalizedLevel = min(1.0, average * 10) // Amplify for visualization

        Task { @MainActor in
            withAnimation(.linear(duration: 0.05)) {
                self.audioLevel = normalizedLevel
            }
        }
    }

    private func playActivationSound() {
        #if os(macOS)
        NSSound(named: "Pop")?.play()
        #else
        // Use AudioToolbox for iOS
        AudioServicesPlaySystemSound(1054) // Keyboard click sound
        #endif
    }

    // MARK: - Persistence

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "thea.voice.settings")
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "thea.voice.settings"),
           let decoded = try? JSONDecoder().decode(VoiceSettings.self, from: data) {
            settings = decoded
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceModeController: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.isVoiceModeEnabled && self.settings.continuousListening {
                self.state = .listening
                try? await self.startListening()
            } else {
                self.state = .idle
            }
        }
    }
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
                    try? await controller.startVoiceMode()
                }
            }
        } label: {
            ZStack {
                // Background with pulse animation when listening
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
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if controller.state != .idle {
            ZStack {
                // Background
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        controller.stopVoiceMode()
                    }

                VStack(spacing: 32) {
                    // Status indicator
                    VStack(spacing: 16) {
                        ZStack {
                            // Animated rings
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

                            // THEA spiral
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

                    // Waveform
                    if controller.state == .listening || controller.state == .activated {
                        VoiceWaveformView()
                            .frame(height: 48)
                            .padding(.horizontal, 60)
                    }

                    // Transcription
                    if !controller.transcribedText.isEmpty {
                        Text(controller.transcribedText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .transition(.opacity)
                    }

                    // Cancel button
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

// MARK: - Preview

#Preview("Voice Mode Button") {
    VoiceModeButton()
        .padding()
}

#Preview("Voice Mode Settings") {
    NavigationStack {
        VoiceModeSettingsView()
    }
}
