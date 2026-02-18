// VoiceIntegration.swift
// Thea V2
//
// Voice interaction integration using Speech and AVFoundation frameworks
// Provides speech recognition and synthesis capabilities

import Foundation
import OSLog

#if canImport(Speech)
import Speech
#endif

#if canImport(AVFoundation)
import AVFoundation
#endif

// MARK: - Voice Models

/// Represents a speech recognition result
public struct SpeechRecognitionResult: Sendable {
    public let transcription: String
    public let isFinal: Bool
    public let confidence: Float
    public let alternatives: [String]
    public let segments: [VoiceTranscriptionSegment]

    public init(
        transcription: String,
        isFinal: Bool = false,
        confidence: Float = 0,
        alternatives: [String] = [],
        segments: [VoiceTranscriptionSegment] = []
    ) {
        self.transcription = transcription
        self.isFinal = isFinal
        self.confidence = confidence
        self.alternatives = alternatives
        self.segments = segments
    }
}

/// Represents a segment of transcription
public struct VoiceTranscriptionSegment: Sendable {
    public let text: String
    public let timestamp: TimeInterval
    public let duration: TimeInterval
    public let confidence: Float

    public init(
        text: String,
        timestamp: TimeInterval,
        duration: TimeInterval,
        confidence: Float = 0
    ) {
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.confidence = confidence
    }
}

/// Configuration for speech recognition
public struct SpeechRecognitionConfig: Sendable {
    public var locale: Locale
    public var shouldReportPartialResults: Bool
    public var requiresOnDeviceRecognition: Bool
    public var contextualStrings: [String]
    public var taskHint: SpeechTaskHint

    public init(
        locale: Locale = .current,
        shouldReportPartialResults: Bool = true,
        requiresOnDeviceRecognition: Bool = false,
        contextualStrings: [String] = [],
        taskHint: SpeechTaskHint = .unspecified
    ) {
        self.locale = locale
        self.shouldReportPartialResults = shouldReportPartialResults
        self.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        self.contextualStrings = contextualStrings
        self.taskHint = taskHint
    }

    public static var `default`: SpeechRecognitionConfig {
        SpeechRecognitionConfig()
    }

    public static var dictation: SpeechRecognitionConfig {
        SpeechRecognitionConfig(taskHint: .dictation)
    }

    public static var commands: SpeechRecognitionConfig {
        SpeechRecognitionConfig(taskHint: .commands)
    }
}

/// Speech task hints
public enum SpeechTaskHint: String, Sendable {
    case unspecified
    case dictation
    case search
    case commands  // For voice commands/control
}

/// Configuration for speech synthesis
public struct SpeechSynthesisConfig: Sendable {
    public var voice: VoiceIdentifier?
    public var rate: Float      // 0.0 - 1.0
    public var pitch: Float     // 0.5 - 2.0
    public var volume: Float    // 0.0 - 1.0
    public var preUtteranceDelay: TimeInterval
    public var postUtteranceDelay: TimeInterval

    public init(
        voice: VoiceIdentifier? = nil,
        rate: Float = 0.5,
        pitch: Float = 1.0,
        volume: Float = 1.0,
        preUtteranceDelay: TimeInterval = 0,
        postUtteranceDelay: TimeInterval = 0
    ) {
        self.voice = voice
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
        self.preUtteranceDelay = preUtteranceDelay
        self.postUtteranceDelay = postUtteranceDelay
    }

    public static var `default`: SpeechSynthesisConfig {
        SpeechSynthesisConfig()
    }

    public static var slow: SpeechSynthesisConfig {
        SpeechSynthesisConfig(rate: 0.3)
    }

    public static var fast: SpeechSynthesisConfig {
        SpeechSynthesisConfig(rate: 0.7)
    }
}

/// Voice identifier
public struct VoiceIdentifier: Sendable, Codable, Equatable {
    public let identifier: String
    public let name: String
    public let language: String
    public let quality: VoiceQuality

    public init(
        identifier: String,
        name: String,
        language: String,
        quality: VoiceQuality = .default
    ) {
        self.identifier = identifier
        self.name = name
        self.language = language
        self.quality = quality
    }
}

/// Voice quality levels
public enum VoiceQuality: String, Sendable, Codable {
    case `default`
    case enhanced
    case premium
}

// MARK: - Voice Integration Actor

/// Actor for managing voice operations
/// Thread-safe access to Speech and AVFoundation frameworks
@available(macOS 10.15, iOS 13.0, *)
public actor VoiceIntegration {
    public static let shared = VoiceIntegration()

    private let logger = Logger(subsystem: "com.thea.integrations", category: "Voice")

    #if canImport(AVFoundation)
    private let synthesizer = AVSpeechSynthesizer()
    private var synthesizerDelegate: SynthesizerDelegate?
    #endif

    #if canImport(Speech)
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    #endif

    private var isRecognizing = false

    private init() {
        #if canImport(AVFoundation)
        synthesizerDelegate = SynthesizerDelegate()
        synthesizer.delegate = synthesizerDelegate
        #endif
    }

    // MARK: - Authorization

    /// Check speech recognition authorization status
    public var recognitionAuthorizationStatus: VoiceAuthorizationStatus {
        #if canImport(Speech)
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
        #else
        return .unavailable
        #endif
    }

    /// Request speech recognition authorization
    public func requestRecognitionAuthorization() async -> Bool {
        #if canImport(Speech)
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let granted = status == .authorized
                self.logger.info("Speech recognition authorization: \(granted ? "granted" : "denied")")
                continuation.resume(returning: granted)
            }
        }
        #else
        return false
        #endif
    }

    // MARK: - Speech Recognition

    /// Start listening for speech
    public func startListening(
        config: SpeechRecognitionConfig = .default,
        resultHandler: @escaping @Sendable (SpeechRecognitionResult) -> Void
    ) async throws {
        #if canImport(Speech) && canImport(AVFoundation)
        guard recognitionAuthorizationStatus == .authorized else {
            throw VoiceIntegrationError.notAuthorized
        }

        guard !isRecognizing else {
            throw VoiceIntegrationError.alreadyRecognizing
        }

        // Create recognizer for locale
        recognizer = SFSpeechRecognizer(locale: config.locale)

        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw VoiceIntegrationError.recognizerUnavailable
        }

        isRecognizing = true

        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw VoiceIntegrationError.audioEngineError
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw VoiceIntegrationError.requestCreationFailed
        }

        request.shouldReportPartialResults = config.shouldReportPartialResults
        if #available(macOS 13.0, iOS 16.0, *) {
            request.addsPunctuation = true
        }

        // Configure task hint
        if #available(macOS 13.0, iOS 16.0, *) {
            switch config.taskHint {
            case .dictation:
                request.taskHint = .dictation
            case .search:
                request.taskHint = .search
            case .commands:
                request.taskHint = .confirmation
            case .unspecified:
                request.taskHint = .unspecified
            }
        }

        // Add contextual strings
        request.contextualStrings = config.contextualStrings

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let segments = result.bestTranscription.segments.map { segment in
                    VoiceTranscriptionSegment(
                        text: segment.substring,
                        timestamp: segment.timestamp,
                        duration: segment.duration,
                        confidence: segment.confidence
                    )
                }

                let alternatives = result.transcriptions.dropFirst().prefix(3).map { $0.formattedString }

                let recognitionResult = SpeechRecognitionResult(
                    transcription: result.bestTranscription.formattedString,
                    isFinal: result.isFinal,
                    confidence: segments.first?.confidence ?? 0,
                    alternatives: Array(alternatives),
                    segments: segments
                )

                resultHandler(recognitionResult)

                if result.isFinal {
                    Task {
                        await self.stopListening()
                    }
                }
            }

            if let error = error {
                self.logger.error("Recognition error: \(error.localizedDescription)")
                Task {
                    await self.stopListening()
                }
            }
        }

        // Configure audio session
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        logger.info("Started listening for speech")
        #else
        throw VoiceIntegrationError.unavailable
        #endif
    }

    /// Stop listening for speech
    public func stopListening() {
        #if canImport(Speech) && canImport(AVFoundation)
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        audioEngine = nil
        isRecognizing = false

        logger.info("Stopped listening for speech")
        #endif
    }

    /// Recognize speech from audio file
    public func recognizeAudioFile(
        url: URL,
        config: SpeechRecognitionConfig = .default
    ) async throws -> SpeechRecognitionResult {
        #if canImport(Speech)
        guard recognitionAuthorizationStatus == .authorized else {
            throw VoiceIntegrationError.notAuthorized
        }

        recognizer = SFSpeechRecognizer(locale: config.locale)

        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw VoiceIntegrationError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    let segments = result.bestTranscription.segments.map { segment in
                        VoiceTranscriptionSegment(
                            text: segment.substring,
                            timestamp: segment.timestamp,
                            duration: segment.duration,
                            confidence: segment.confidence
                        )
                    }

                    let recognitionResult = SpeechRecognitionResult(
                        transcription: result.bestTranscription.formattedString,
                        isFinal: true,
                        confidence: segments.first?.confidence ?? 0,
                        alternatives: [],
                        segments: segments
                    )

                    continuation.resume(returning: recognitionResult)
                }
            }
        }
        #else
        throw VoiceIntegrationError.unavailable
        #endif
    }

    // MARK: - Speech Synthesis

    /// Speak text
    public func speak(
        text: String,
        config: SpeechSynthesisConfig = .default
    ) async throws {
        #if canImport(AVFoundation)
        let utterance = AVSpeechUtterance(string: text)

        // Apply configuration
        utterance.rate = config.rate
        utterance.pitchMultiplier = config.pitch
        utterance.volume = config.volume
        utterance.preUtteranceDelay = config.preUtteranceDelay
        utterance.postUtteranceDelay = config.postUtteranceDelay

        // Set voice
        if let voiceId = config.voice {
            if let voice = AVSpeechSynthesisVoice(identifier: voiceId.identifier) {
                utterance.voice = voice
            }
        }

        // Speak and wait for completion
        return try await withCheckedThrowingContinuation { continuation in
            self.synthesizerDelegate?.completionHandler = {
                continuation.resume()
            }
            self.synthesizerDelegate?.errorHandler = { error in
                continuation.resume(throwing: error)
            }

            self.synthesizer.speak(utterance)
        }
        #else
        throw VoiceIntegrationError.unavailable
        #endif
    }

    /// Stop speaking
    public func stopSpeaking(boundary: SpeechBoundary = .immediate) {
        #if canImport(AVFoundation)
        let avBoundary: AVSpeechBoundary
        switch boundary {
        case .immediate:
            avBoundary = .immediate
        case .word:
            avBoundary = .word
        }
        synthesizer.stopSpeaking(at: avBoundary)
        #endif
    }

    /// Pause speaking
    public func pauseSpeaking(boundary: SpeechBoundary = .immediate) {
        #if canImport(AVFoundation)
        let avBoundary: AVSpeechBoundary
        switch boundary {
        case .immediate:
            avBoundary = .immediate
        case .word:
            avBoundary = .word
        }
        synthesizer.pauseSpeaking(at: avBoundary)
        #endif
    }

    /// Continue speaking
    public func continueSpeaking() {
        #if canImport(AVFoundation)
        synthesizer.continueSpeaking()
        #endif
    }

    /// Check if currently speaking
    public var isSpeaking: Bool {
        #if canImport(AVFoundation)
        return synthesizer.isSpeaking
        #else
        return false
        #endif
    }

    // MARK: - Available Voices

    /// Get all available voices
    public func availableVoices(for language: String? = nil) -> [VoiceIdentifier] {
        #if canImport(AVFoundation)
        var voices = AVSpeechSynthesisVoice.speechVoices()

        if let language = language {
            voices = voices.filter { $0.language.hasPrefix(language) }
        }

        return voices.map { voice in
            let quality: VoiceQuality
            switch voice.quality {
            case .enhanced:
                quality = .enhanced
            case .premium:
                quality = .premium
            default:
                quality = .default
            }

            return VoiceIdentifier(
                identifier: voice.identifier,
                name: voice.name,
                language: voice.language,
                quality: quality
            )
        }
        #else
        return []
        #endif
    }

    /// Get available languages for speech recognition
    public func availableRecognitionLanguages() -> [Locale] {
        #if canImport(Speech)
        return Array(SFSpeechRecognizer.supportedLocales())
        #else
        return []
        #endif
    }

    /// Check if on-device recognition is available
    public func isOnDeviceRecognitionAvailable(for locale: Locale = .current) -> Bool {
        #if canImport(Speech)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return false
        }
        if #available(macOS 13.0, iOS 16.0, *) {
            return recognizer.supportsOnDeviceRecognition
        }
        return false
        #else
        return false
        #endif
    }
}

// MARK: - Supporting Types

/// Speech boundary for stopping/pausing
public enum SpeechBoundary: Sendable {
    case immediate
    case word
}

/// Authorization status for voice
public enum VoiceAuthorizationStatus: String, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined
    case unavailable
}

/// Errors for voice operations
public enum VoiceIntegrationError: LocalizedError {
    case unavailable
    case notAuthorized
    case recognizerUnavailable
    case alreadyRecognizing
    case audioEngineError
    case requestCreationFailed
    case synthesisError(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "Voice framework not available on this platform"
        case .notAuthorized:
            "Speech recognition not authorized"
        case .recognizerUnavailable:
            "Speech recognizer not available"
        case .alreadyRecognizing:
            "Already recognizing speech"
        case .audioEngineError:
            "Audio engine error"
        case .requestCreationFailed:
            "Failed to create recognition request"
        case .synthesisError(let message):
            "Speech synthesis error: \(message)"
        }
    }
}

// MARK: - Synthesizer Delegate

#if canImport(AVFoundation)
// @unchecked Sendable: NSObject subclass bridging AVSpeechSynthesizerDelegate; AVSpeechSynthesizer
// dispatches callbacks on main thread; stored closures are only called from those callbacks
private class SynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var completionHandler: (() -> Void)?
    var errorHandler: ((Error) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completionHandler?()
        completionHandler = nil
        errorHandler = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completionHandler?()
        completionHandler = nil
        errorHandler = nil
    }
}
#endif
