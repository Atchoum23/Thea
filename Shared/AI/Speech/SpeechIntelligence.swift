// SpeechIntelligence.swift
// AI-powered speech recognition and synthesis capabilities

import Foundation
import OSLog
#if canImport(Speech)
    import Speech
#endif
#if canImport(AVFoundation)
    import AVFoundation
#endif

// MARK: - Speech Intelligence

/// AI-powered speech recognition and synthesis
@MainActor
public final class SpeechIntelligence: ObservableObject {
    public static let shared = SpeechIntelligence()

    private let logger = Logger(subsystem: "com.thea.app", category: "SpeechIntelligence")

    #if canImport(Speech)
        private var speechRecognizer: SFSpeechRecognizer?
        private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
        private var recognitionTask: SFSpeechRecognitionTask?
    #endif

    #if canImport(AVFoundation)
        private var audioEngine: AVAudioEngine?
        private var synthesizer: AVSpeechSynthesizer?
    #endif

    // MARK: - Published State

    @Published public private(set) var isRecognizing = false
    @Published public private(set) var isSpeaking = false
    @Published public private(set) var authorizationStatus: SpeechAuthStatus = .notDetermined
    @Published public private(set) var recognizedText = ""
    @Published public private(set) var availableVoices: [SpeechVoice] = []
    @Published public var selectedVoice: SpeechVoice?

    // MARK: - Initialization

    private init() {
        #if canImport(Speech)
            speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        #endif

        #if canImport(AVFoundation)
            audioEngine = AVAudioEngine()
            synthesizer = AVSpeechSynthesizer()
            loadAvailableVoices()
        #endif

        checkAuthorization()
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        #if canImport(Speech)
            authorizationStatus = SpeechAuthStatus(from: SFSpeechRecognizer.authorizationStatus())
        #else
            authorizationStatus = .notAvailable
        #endif
    }

    public func requestAuthorization() async -> Bool {
        #if canImport(Speech)
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    Task { @MainActor in
                        self.authorizationStatus = SpeechAuthStatus(from: status)
                        continuation.resume(returning: status == .authorized)
                    }
                }
            }
        #else
            return false
        #endif
    }

    // MARK: - Speech Recognition

    /// Start continuous speech recognition
    public func startRecognition(language _: String = "en-US") async throws {
        guard authorizationStatus == .authorized else {
            throw SpeechError.notAuthorized
        }

        #if canImport(Speech) && canImport(AVFoundation)
            guard let speechRecognizer, speechRecognizer.isAvailable else {
                throw SpeechError.recognizerUnavailable
            }

            // Stop any existing recognition
            stopRecognition()

            recognizedText = ""
            isRecognizing = true

            // Configure audio session (iOS/watchOS only)
            #if os(iOS) || os(watchOS)
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else {
                throw SpeechError.requestCreationFailed
            }

            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false

            // Configure audio engine
            guard let audioEngine else {
                throw SpeechError.audioEngineUnavailable
            }

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            // Start recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let result {
                        self.recognizedText = result.bestTranscription.formattedString
                    }

                    if error != nil || (result?.isFinal ?? false) {
                        self.stopRecognition()
                    }
                }
            }

            logger.info("Speech recognition started")
        #else
            throw SpeechError.notAvailable
        #endif
    }

    /// Stop speech recognition
    public func stopRecognition() {
        #if canImport(Speech) && canImport(AVFoundation)
            recognitionTask?.cancel()
            recognitionTask = nil

            recognitionRequest?.endAudio()
            recognitionRequest = nil

            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)

            isRecognizing = false
            logger.info("Speech recognition stopped")
        #endif
    }

    /// Transcribe audio data to text
    public func transcribe(audioData: Data, language: String = "en-US") async throws -> TranscriptionResult {
        guard authorizationStatus == .authorized else {
            throw SpeechError.notAuthorized
        }

        #if canImport(Speech)
            guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language)),
                  speechRecognizer.isAvailable
            else {
                throw SpeechError.recognizerUnavailable
            }

            // Create temporary file for audio
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
            try audioData.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            // Create recognition request
            let request = SFSpeechURLRecognitionRequest(url: tempURL)
            request.shouldReportPartialResults = false

            return try await withCheckedThrowingContinuation { continuation in
                speechRecognizer.recognitionTask(with: request) { result, error in
                    if let error {
                        continuation.resume(throwing: SpeechError.recognitionFailed(error.localizedDescription))
                        return
                    }

                    guard let result else {
                        continuation.resume(throwing: SpeechError.noResults)
                        return
                    }

                    let segments = result.bestTranscription.segments.map { segment in
                        TranscriptionSegment(
                            text: segment.substring,
                            timestamp: segment.timestamp,
                            duration: segment.duration,
                            confidence: segment.confidence
                        )
                    }

                    continuation.resume(returning: TranscriptionResult(
                        text: result.bestTranscription.formattedString,
                        segments: segments,
                        isFinal: result.isFinal
                    ))
                }
            }
        #else
            throw SpeechError.notAvailable
        #endif
    }

    // MARK: - Speech Synthesis

    /// Speak text using text-to-speech
    public func speak(_ text: String, voice: SpeechVoice? = nil, rate: Float = 0.5, pitch: Float = 1.0) async {
        #if canImport(AVFoundation)
            guard let synthesizer else { return }

            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = rate
            utterance.pitchMultiplier = pitch

            // Use selected voice or system default
            if let selectedVoice = voice ?? selectedVoice {
                utterance.voice = AVSpeechSynthesisVoice(identifier: selectedVoice.identifier)
            }

            isSpeaking = true
            synthesizer.speak(utterance)

            // Wait for completion
            await withCheckedContinuation { continuation in
                Task {
                    while synthesizer.isSpeaking {
                        try? await Task.sleep(for: .milliseconds(100)) // 100ms
                    }
                    await MainActor.run {
                        self.isSpeaking = false
                    }
                    continuation.resume()
                }
            }
        #endif
    }

    /// Stop speaking
    public func stopSpeaking() {
        #if canImport(AVFoundation)
            synthesizer?.stopSpeaking(at: .immediate)
            isSpeaking = false
        #endif
    }

    // MARK: - Voice Management

    private func loadAvailableVoices() {
        #if canImport(AVFoundation)
            availableVoices = AVSpeechSynthesisVoice.speechVoices().map { voice in
                SpeechVoice(
                    identifier: voice.identifier,
                    name: voice.name,
                    language: voice.language,
                    quality: SpeechVoiceQuality(from: voice.quality)
                )
            }

            // Select default voice
            if selectedVoice == nil, let defaultVoice = availableVoices.first(where: { $0.language.starts(with: "en") }) {
                selectedVoice = defaultVoice
            }
        #endif
    }

    /// Get voices for a specific language
    public func voices(for language: String) -> [SpeechVoice] {
        availableVoices.filter { $0.language.starts(with: language) }
    }

    /// Get premium/enhanced voices
    public func premiumVoices() -> [SpeechVoice] {
        availableVoices.filter { $0.quality == .enhanced || $0.quality == .premium }
    }
}

// MARK: - Speech Auth Status

public enum SpeechAuthStatus: String, Sendable {
    case notDetermined
    case denied
    case restricted
    case authorized
    case notAvailable

    #if canImport(Speech)
        init(from status: SFSpeechRecognizerAuthorizationStatus) {
            switch status {
            case .notDetermined: self = .notDetermined
            case .denied: self = .denied
            case .restricted: self = .restricted
            case .authorized: self = .authorized
            @unknown default: self = .notDetermined
            }
        }
    #endif
}

// MARK: - Speech Error

public enum SpeechError: Error, LocalizedError {
    case notAvailable
    case notAuthorized
    case recognizerUnavailable
    case requestCreationFailed
    case audioEngineUnavailable
    case recognitionFailed(String)
    case noResults

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            "Speech recognition is not available on this device"
        case .notAuthorized:
            "Speech recognition is not authorized"
        case .recognizerUnavailable:
            "Speech recognizer is currently unavailable"
        case .requestCreationFailed:
            "Failed to create speech recognition request"
        case .audioEngineUnavailable:
            "Audio engine is unavailable"
        case let .recognitionFailed(reason):
            "Speech recognition failed: \(reason)"
        case .noResults:
            "No speech recognition results"
        }
    }
}

// MARK: - Result Types

public struct TranscriptionResult: Sendable {
    public let text: String
    public let segments: [TranscriptionSegment]
    public let isFinal: Bool
}

public struct TranscriptionSegment: Sendable {
    public let text: String
    public let timestamp: TimeInterval
    public let duration: TimeInterval
    public let confidence: Float
}

public struct SpeechVoice: Identifiable, Hashable, Sendable {
    public let identifier: String
    public let name: String
    public let language: String
    public let quality: SpeechVoiceQuality

    public var id: String { identifier }

    public var displayName: String {
        "\(name) (\(language))"
    }
}

public enum SpeechVoiceQuality: String, Sendable {
    case standard
    case enhanced
    case premium

    #if canImport(AVFoundation)
        init(from quality: AVSpeechSynthesisVoiceQuality) {
            switch quality {
            case .default: self = .standard
            case .enhanced: self = .enhanced
            case .premium: self = .premium
            @unknown default: self = .standard
            }
        }
    #endif
}
