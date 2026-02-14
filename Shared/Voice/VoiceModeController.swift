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

// Types (VoiceModeState, VoiceSettings, VoiceModeError) and views
// (VoiceModeButton, VoiceWaveformView, VoiceModeSettingsView, VoiceModeOverlay)
// are in VoiceModeControllerTypes.swift

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

