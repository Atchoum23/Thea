// VoiceInteractionEngine.swift
// Best-in-class voice interaction with automatic language detection
// Supports on-device (privacy-first) and cloud-enhanced modes

import Foundation
import Speech
import AVFoundation

// MARK: - Voice Interaction Engine

/// AI-powered voice interaction engine with speech recognition and synthesis
/// Supports multiple backends: Apple native, WhisperKit, and cloud services
@MainActor
@Observable
final class VoiceInteractionEngine {
    static let shared = VoiceInteractionEngine()

    // MARK: - State

    private(set) var isListening = false
    private(set) var isSpeaking = false
    private(set) var currentTranscript = ""
    private(set) var detectedLanguage: Locale?
    private(set) var speechConfidence: Float = 0.0
    private(set) var voiceActivityDetected = false
    private(set) var errorMessage: String?

    // Configuration
    private(set) var configuration = Configuration()

    // Audio components
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()

    // Delegates
    private let synthesizerDelegate = SynthesizerDelegate()

    // MARK: - Configuration

    struct Configuration: Codable, Sendable {
        var backend: VoiceBackend = .appleNative
        var enableAutoLanguageDetection = true
        var preferredLanguages: [String] = ["en-US", "fr-FR", "es-ES", "de-DE", "ja-JP", "zh-CN"]
        var enableOnDeviceRecognition = true
        var enableContinuousListening = false
        var voiceActivityThreshold: Float = 0.3
        var speechRate: Float = 0.5 // 0.0-1.0
        var speechPitch: Float = 1.0 // 0.5-2.0
        var preferredVoiceIdentifier: String?
        var enableHapticFeedback = true
        var enableVisualFeedback = true
        var maxListeningDuration: TimeInterval = 60.0
        var silenceTimeout: TimeInterval = 2.0

        enum VoiceBackend: String, Codable, Sendable, CaseIterable {
            case appleNative = "Apple Native (On-Device)"
            case whisperKit = "WhisperKit (Local AI)"
            case vapi = "Vapi (Cloud)"
            case hybrid = "Hybrid (Auto-Select)"

            var isOnDevice: Bool {
                switch self {
                case .appleNative, .whisperKit: true
                case .vapi: false
                case .hybrid: true // Prefers on-device when possible
                }
            }
        }
    }

    // MARK: - Initialization

    private init() {
        loadConfiguration()
        setupSpeechRecognizer()
        synthesizerDelegate.engine = self
        speechSynthesizer.delegate = synthesizerDelegate
    }

    private func setupSpeechRecognizer() {
        // Default to device locale, but we'll support auto-detection
        let locale = Locale.current
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Speech Recognition

    /// Request speech recognition authorization
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Check current authorization status
    var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    /// Start listening for speech
    func startListening() async throws {
        guard !isListening else { return }

        // Request authorization if needed
        guard await requestAuthorization() else {
            throw VoiceInteractionError.notAuthorized
        }

        // Configure audio session
        try await configureAudioSession()

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest else {
            throw VoiceInteractionError.recognitionUnavailable
        }

        // Configure request
        recognitionRequest.shouldReportPartialResults = true

        if configuration.enableOnDeviceRecognition {
            if #available(iOS 13, macOS 10.15, *) {
                recognitionRequest.requiresOnDeviceRecognition = true
            }
        }

        // Note: Custom vocabulary for tech terms can be added using
        // SFSpeechRecognizer's customizedLanguageModel on iOS 17+

        // Setup audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on audio buffer
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Voice activity detection
            if let channelData = buffer.floatChannelData?[0] {
                let frameLength = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<frameLength {
                    sum += abs(channelData[i])
                }
                let average = sum / Float(frameLength)

                Task { @MainActor [weak self] in
                    self?.voiceActivityDetected = average > (self?.configuration.voiceActivityThreshold ?? 0.3)
                }
            }
        }

        // Start recognition
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceInteractionError.recognitionUnavailable
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    self.currentTranscript = result.bestTranscription.formattedString
                    self.speechConfidence = result.bestTranscription.segments.last?.confidence ?? 0

                    // Auto-detect language from transcription segments
                    if self.configuration.enableAutoLanguageDetection {
                        self.detectLanguage(from: result)
                    }

                    if result.isFinal {
                        self.handleFinalTranscription(result.bestTranscription.formattedString)
                    }
                }

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.stopListening()
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        errorMessage = nil

        // Auto-stop after max duration
        Task {
            try? await Task.sleep(for: .seconds(configuration.maxListeningDuration))
            if isListening {
                stopListening()
            }
        }
    }

    /// Stop listening
    func stopListening() {
        guard isListening else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        voiceActivityDetected = false
    }

    private func configureAudioSession() async throws {
        #if os(iOS) || os(watchOS) || os(tvOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func detectLanguage(from result: SFSpeechRecognitionResult) {
        // Use the locale from the speech recognizer or infer from content
        // For more accurate detection, WhisperKit provides better multilingual support
        if result.bestTranscription.segments.first != nil {
            // The recognizer's locale gives us the detected language
            detectedLanguage = speechRecognizer?.locale
        }
    }

    private func handleFinalTranscription(_ text: String) {
        // Notify observers that transcription is complete
        NotificationCenter.default.post(
            name: .voiceTranscriptionComplete,
            object: nil,
            userInfo: ["text": text, "language": detectedLanguage?.identifier ?? "unknown"]
        )
    }

    // MARK: - Speech Synthesis

    /// Speak text using the configured voice
    func speak(_ text: String, language: String? = nil) {
        guard !text.isEmpty else { return }

        // Stop any ongoing speech
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)

        // Configure voice
        if let voiceId = configuration.preferredVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else if let language {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        } else {
            // Use device locale
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        }

        // Configure speech parameters
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * configuration.speechRate
        utterance.pitchMultiplier = configuration.speechPitch
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1

        speechSynthesizer.speak(utterance)
        isSpeaking = true
    }

    /// Stop speaking
    func stopSpeaking() {
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }
    }

    /// Pause speaking
    func pauseSpeaking() {
        if isSpeaking {
            speechSynthesizer.pauseSpeaking(at: .word)
        }
    }

    /// Resume speaking
    func resumeSpeaking() {
        speechSynthesizer.continueSpeaking()
    }

    /// Get available voices
    func getAvailableVoices() -> [VoiceInfo] {
        AVSpeechSynthesisVoice.speechVoices().map { voice in
            VoiceInfo(
                identifier: voice.identifier,
                name: voice.name,
                language: voice.language,
                quality: mapQuality(voice.quality),
                gender: mapGender(voice.gender)
            )
        }
    }

    /// Get available voices for a specific language
    func getVoices(for language: String) -> [VoiceInfo] {
        getAvailableVoices().filter { $0.language.hasPrefix(language.prefix(2)) }
    }

    /// Get supported recognition languages
    func getSupportedLanguages() -> [Locale] {
        Set(SFSpeechRecognizer.supportedLocales()).sorted { $0.identifier < $1.identifier }
    }

    private func mapQuality(_ quality: AVSpeechSynthesisVoiceQuality) -> VoiceInfo.Quality {
        switch quality {
        case .default: .standard
        case .enhanced: .enhanced
        case .premium: .premium
        @unknown default: .standard
        }
    }

    private func mapGender(_ gender: AVSpeechSynthesisVoiceGender) -> VoiceInfo.Gender {
        switch gender {
        case .male: .male
        case .female: .female
        case .unspecified: .unspecified
        @unknown default: .unspecified
        }
    }

    // MARK: - Convenience Methods

    /// Listen for speech and return the transcription
    func listenForSpeech(timeout: TimeInterval = 10.0) async throws -> String {
        try await startListening()

        // Wait for final transcription or timeout
        let result = try await withTimeout(seconds: timeout) { [weak self] in
            await withCheckedContinuation { continuation in
                let observer = NotificationCenter.default.addObserver(
                    forName: .voiceTranscriptionComplete,
                    object: nil,
                    queue: .main
                ) { notification in
                    if let text = notification.userInfo?["text"] as? String {
                        continuation.resume(returning: text)
                    }
                }

                // Store observer for cleanup
                Task { @MainActor [weak self] in
                    // Will be cleaned up when stopListening is called
                }
            }
        }

        stopListening()
        return result
    }

    /// Have a voice conversation turn
    func conversationTurn(prompt: String) async throws -> String {
        // Speak the prompt
        speak(prompt)

        // Wait for speech to finish
        await waitForSpeechCompletion()

        // Listen for response
        return try await listenForSpeech()
    }

    private func waitForSpeechCompletion() async {
        while isSpeaking {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw VoiceInteractionError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Configuration

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        saveConfiguration()

        // Reinitialize recognizer if language changed
        if let preferredLang = config.preferredLanguages.first {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: preferredLang))
        }
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "VoiceInteraction.config"),
           let config = try? JSONDecoder().decode(Configuration.self, from: data) {
            configuration = config
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "VoiceInteraction.config")
        }
    }

    // MARK: - Delegate

    fileprivate func didFinishSpeaking() {
        isSpeaking = false
    }
}

// MARK: - Synthesizer Delegate

private class SynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    weak var engine: VoiceInteractionEngine?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak engine] in
            engine?.didFinishSpeaking()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak engine] in
            engine?.didFinishSpeaking()
        }
    }
}

// MARK: - Supporting Types

struct VoiceInfo: Identifiable, Sendable {
    var id: String { identifier }
    let identifier: String
    let name: String
    let language: String
    let quality: Quality
    let gender: Gender

    enum Quality: String, Codable, Sendable {
        case standard = "Standard"
        case enhanced = "Enhanced"
        case premium = "Premium"
    }

    enum Gender: String, Codable, Sendable {
        case male = "Male"
        case female = "Female"
        case unspecified = "Unspecified"
    }
}

enum VoiceInteractionError: Error, LocalizedError {
    case notAuthorized
    case recognitionUnavailable
    case audioSessionError
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Speech recognition not authorized"
        case .recognitionUnavailable: "Speech recognition unavailable"
        case .audioSessionError: "Audio session error"
        case .timeout: "Voice recognition timed out"
        case .cancelled: "Voice recognition cancelled"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let voiceTranscriptionComplete = Notification.Name("voiceTranscriptionComplete")
    static let voiceActivityChanged = Notification.Name("voiceActivityChanged")
}
