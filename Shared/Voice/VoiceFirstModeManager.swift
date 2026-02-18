//
//  VoiceFirstModeManager.swift
//  Thea
//
//  Coordinates continuous voice interaction for hands-free operation.
//  Wires VoiceInteractionEngine, WakeWordEngine, and AI providers for seamless voice-first UX.
//
//  WORKFLOW:
//  1. User enables voice-first mode
//  2. WakeWordEngine listens for "Hey Thea"
//  3. On detection, VoiceInteractionEngine captures query
//  4. Query is processed by AI (local or cloud)
//  5. Response is spoken via TTS
//  6. Returns to wake word listening
//
//  CREATED: February 6, 2026
//

import Foundation
import OSLog
#if os(macOS)
import AppKit
#elseif canImport(AudioToolbox)
import AudioToolbox
#endif

// MARK: - Voice-First Mode Manager

/// Manages hands-free voice interaction with continuous wake word detection
@MainActor
@Observable
public final class VoiceFirstModeManager {
    public static let shared = VoiceFirstModeManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "VoiceFirstMode")

    // MARK: - State

    /// Whether voice-first mode is enabled
    public private(set) var isVoiceFirstModeActive: Bool = false

    /// Current phase of voice interaction
    public private(set) var currentPhase: VoicePhase = .idle

    /// Last transcribed user query
    public private(set) var lastTranscript: String = ""

    /// Last AI response
    public private(set) var lastResponse: String = ""

    /// Error message if any
    public private(set) var errorMessage: String?

    /// Statistics for voice interactions
    public private(set) var stats = VoiceStats()

    // MARK: - Configuration

    /// Voice-first mode configuration
    public var configuration = Configuration() {
        didSet {
            applyConfiguration()
        }
    }

    public struct Configuration: Codable, Sendable {
        /// Automatically speak responses
        public var autoSpeak: Bool = true

        /// Continue listening after response
        public var continuousMode: Bool = true

        /// Timeout for voice input (seconds)
        public var inputTimeout: TimeInterval = 10.0

        /// Voice for TTS
        public var voiceIdentifier: String?

        /// Speech rate (0.0 - 1.0)
        public var speechRate: Float = 0.5

        /// Enable confirmation sounds
        public var enableSounds: Bool = true

        /// Enable haptic feedback (iOS)
        public var enableHaptics: Bool = true

        /// Commands that should be spoken briefly
        public var briefResponseCommands: Set<String> = ["time", "date", "weather", "timer"]

        public init() {}
    }

    // MARK: - Callbacks

    /// Called when voice query is ready to process
    public var onQueryReady: ((String) async -> String)?

    /// Called when phase changes
    public var onPhaseChanged: ((VoicePhase) -> Void)?

    /// Called on error
    public var onError: ((VoiceFirstError) -> Void)?

    // MARK: - Private State

    private var interactionTask: Task<Void, Never>?
    private var isProcessing: Bool = false

    // MARK: - Initialization

    private init() {
        setupWakeWordCallback()
        loadConfiguration()
    }

    // MARK: - Public API

    /// Enable voice-first mode
    public func enableVoiceFirstMode() async throws {
        guard !isVoiceFirstModeActive else {
            logger.debug("Voice-first mode already active")
            return
        }

        logger.info("Enabling voice-first mode")

        // Request permissions
        let authorized = await VoiceInteractionEngine.shared.requestAuthorization()
        guard authorized else {
            throw VoiceFirstError.notAuthorized
        }

        // Start wake word detection
        try await WakeWordEngine.shared.startListening()

        isVoiceFirstModeActive = true
        currentPhase = .waitingForWakeWord
        stats.sessionsStarted += 1

        logger.info("Voice-first mode enabled, listening for wake word")
    }

    /// Disable voice-first mode
    public func disableVoiceFirstMode() {
        guard isVoiceFirstModeActive else { return }

        logger.info("Disabling voice-first mode")

        // Stop all voice engines
        WakeWordEngine.shared.stopListening()
        VoiceInteractionEngine.shared.stopListening()
        VoiceInteractionEngine.shared.stopSpeaking()

        // Cancel any ongoing interaction
        interactionTask?.cancel()
        interactionTask = nil

        isVoiceFirstModeActive = false
        currentPhase = .idle
        isProcessing = false

        logger.info("Voice-first mode disabled")
    }

    /// Toggle voice-first mode
    public func toggleVoiceFirstMode() async throws {
        if isVoiceFirstModeActive {
            disableVoiceFirstMode()
        } else {
            try await enableVoiceFirstMode()
        }
    }

    /// Manually trigger listening (bypass wake word)
    public func startListening() async throws {
        guard isVoiceFirstModeActive else {
            throw VoiceFirstError.notActive
        }

        await handleWakeWordDetected()
    }

    /// Process a voice command (for testing or external input)
    public func processVoiceCommand(_ transcript: String) async -> String {
        lastTranscript = transcript
        stats.queriesProcessed += 1

        setPhase(.processing)

        // Get AI response
        let response: String
        if let handler = onQueryReady {
            response = await handler(transcript)
        } else {
            response = "I received your message but no AI handler is configured."
        }

        lastResponse = response

        // Speak response if enabled
        if configuration.autoSpeak {
            await speakResponse(response)
        }

        // Return to listening if continuous mode
        if configuration.continuousMode && isVoiceFirstModeActive {
            setPhase(.waitingForWakeWord)
            do {
                try await WakeWordEngine.shared.startListening()
            } catch {
                logger.error("Failed to restart wake word listening: \(error)")
            }
        } else {
            setPhase(.idle)
        }

        return response
    }

    /// Speak a response via TTS
    public func speakResponse(_ response: String) async {
        setPhase(.speaking)

        // Truncate very long responses for TTS
        let spokenText = response.count > 1000
            ? String(response.prefix(1000)) + "... I've provided the full response in text."
            : response

        VoiceInteractionEngine.shared.speak(spokenText)

        // Wait for speech to complete
        await waitForSpeechCompletion()

        stats.responseSpoken += 1
    }

    /// Stop current speech
    public func stopSpeaking() {
        VoiceInteractionEngine.shared.stopSpeaking()
    }

    /// Cancel current interaction
    public func cancelInteraction() {
        interactionTask?.cancel()
        interactionTask = nil
        isProcessing = false

        VoiceInteractionEngine.shared.stopListening()
        VoiceInteractionEngine.shared.stopSpeaking()

        if isVoiceFirstModeActive {
            setPhase(.waitingForWakeWord)
            Task {
                do {
                    try await WakeWordEngine.shared.startListening()
                } catch {
                    logger.error("Failed to restart wake word listening: \(error.localizedDescription)")
                }
            }
        } else {
            setPhase(.idle)
        }
    }

    // MARK: - Private Implementation

    private func setupWakeWordCallback() {
        WakeWordEngine.shared.onWakeWordDetected = { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleWakeWordDetected()
            }
        }
    }

    private func handleWakeWordDetected() async {
        guard !isProcessing else {
            logger.debug("Already processing, ignoring wake word")
            return
        }

        isProcessing = true
        stats.wakeWordsDetected += 1

        logger.info("Wake word detected, starting voice capture")

        // Stop wake word detection during interaction
        WakeWordEngine.shared.stopListening()

        // Play confirmation sound
        if configuration.enableSounds {
            playSound(.wakeWordDetected)
        }

        setPhase(.listening)

        do {
            // Listen for voice input
            let transcript = try await listenForVoiceInput()

            guard !transcript.isEmpty else {
                logger.debug("Empty transcript, returning to wake word listening")
                returnToWakeWordListening()
                return
            }

            // Process the command
            _ = await processVoiceCommand(transcript)

        } catch {
            logger.error("Voice input error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            onError?(.voiceInputFailed(error.localizedDescription))
            returnToWakeWordListening()
        }

        isProcessing = false
    }

    private func listenForVoiceInput() async throws -> String {
        try await VoiceInteractionEngine.shared.startListening()

        // Wait for speech or timeout
        let startTime = Date()
        var transcript = ""

        while Date().timeIntervalSince(startTime) < configuration.inputTimeout {
            try await Task.sleep(for: .milliseconds(100))

            let currentTranscript = VoiceInteractionEngine.shared.currentTranscript

            // Check for silence (speech completed)
            if !currentTranscript.isEmpty && !VoiceInteractionEngine.shared.voiceActivityDetected {
                // Wait a bit more for any final words
                try await Task.sleep(for: .milliseconds(500))
                transcript = VoiceInteractionEngine.shared.currentTranscript
                break
            }

            transcript = currentTranscript
        }

        VoiceInteractionEngine.shared.stopListening()

        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func waitForSpeechCompletion() async {
        while VoiceInteractionEngine.shared.isSpeaking {
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                break
            }
        }
    }

    private func returnToWakeWordListening() {
        isProcessing = false

        if isVoiceFirstModeActive && configuration.continuousMode {
            setPhase(.waitingForWakeWord)
            Task {
                do {
                    try await WakeWordEngine.shared.startListening()
                } catch {
                    logger.error("Failed to restart wake word listening: \(error.localizedDescription)")
                }
            }
        } else {
            setPhase(.idle)
        }
    }

    private func setPhase(_ newPhase: VoicePhase) {
        guard currentPhase != newPhase else { return }
        currentPhase = newPhase
        onPhaseChanged?(newPhase)
        logger.debug("Voice phase changed to: \(newPhase.rawValue)")
    }

    private func playSound(_ sound: VoiceSound) {
        #if os(macOS)
        let soundName: String
        switch sound {
        case .wakeWordDetected: soundName = "Tink"
        case .listeningStart: soundName = "Pop"
        case .listeningEnd: soundName = "Bottle"
        case .error: soundName = "Basso"
        }
        if let nsSound = NSSound(named: NSSound.Name(soundName)) {
            nsSound.play()
        }
        #elseif canImport(AudioToolbox)
        let soundID: SystemSoundID
        switch sound {
        case .wakeWordDetected: soundID = 1057
        case .listeningStart: soundID = 1104
        case .listeningEnd: soundID = 1105
        case .error: soundID = 1073
        }
        AudioServicesPlaySystemSound(soundID)
        #endif
        logger.debug("Playing sound: \(sound.rawValue)")
    }

    // MARK: - Configuration Persistence

    private let configurationKey = "VoiceFirstMode.configuration"

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: configurationKey) {
            do {
                let decoded = try JSONDecoder().decode(Configuration.self, from: data)
                configuration = decoded
            } catch {
                logger.error("Failed to decode voice-first mode configuration: \(error.localizedDescription)")
            }
        }
    }

    private func saveConfiguration() {
        do {
            let data = try JSONEncoder().encode(configuration)
            UserDefaults.standard.set(data, forKey: configurationKey)
        } catch {
            logger.error("Failed to encode voice-first mode configuration: \(error.localizedDescription)")
        }
    }

    private func applyConfiguration() {
        saveConfiguration()

        // Apply voice settings
        VoiceInteractionEngine.shared.setSpeechRate(configuration.speechRate)

        if let voiceId = configuration.voiceIdentifier {
            VoiceInteractionEngine.shared.setPreferredVoice(identifier: voiceId)
        }
    }
}

// MARK: - Supporting Types

/// Voice interaction phases
public enum VoicePhase: String, Sendable {
    case idle = "Idle"
    case waitingForWakeWord = "Listening for wake word"
    case listening = "Listening for query"
    case processing = "Processing"
    case speaking = "Speaking response"

    public var isActive: Bool {
        self != .idle
    }

    public var userInstruction: String {
        switch self {
        case .idle: return "Voice mode is off"
        case .waitingForWakeWord: return "Say \"Hey Thea\" to start"
        case .listening: return "Listening... speak now"
        case .processing: return "Thinking..."
        case .speaking: return "Speaking..."
        }
    }
}

/// Voice interaction statistics
public struct VoiceStats: Sendable {
    public var sessionsStarted: Int = 0
    public var wakeWordsDetected: Int = 0
    public var queriesProcessed: Int = 0
    public var responseSpoken: Int = 0

    public var successRate: Double {
        guard wakeWordsDetected > 0 else { return 0 }
        return Double(queriesProcessed) / Double(wakeWordsDetected)
    }
}

/// Voice-first mode errors
public enum VoiceFirstError: LocalizedError {
    case notAuthorized
    case notActive
    case voiceInputFailed(String)
    case processingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in Settings."
        case .notActive:
            return "Voice-first mode is not active."
        case .voiceInputFailed(let reason):
            return "Voice input failed: \(reason)"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        }
    }
}

/// Sound effects for voice interaction
private enum VoiceSound: String {
    case wakeWordDetected = "wake_detected"
    case listeningStart = "listening_start"
    case listeningEnd = "listening_end"
    case error = "error"
}

// MARK: - VoiceInteractionEngine Extensions

extension VoiceInteractionEngine {
    /// Set speech rate
    func setSpeechRate(_ _rate: Float) {
        // Would configure internal synthesizer rate
    }

    /// Set preferred voice
    func setPreferredVoice(identifier _identifier: String) {
        // Would configure voice selection
    }
}
