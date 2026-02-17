// VoiceProactivity.swift
// THEA - Contextual Voice Interactions
// Created by Claude - February 2026
//
// Main engine for proactive voice interactions. Manages context detection,
// speech synthesis, speech recognition, interaction delivery, and device relay.
//
// Related files:
//   VoiceProactivityModels.swift        — Model types (VoiceContext, VoiceInteraction, etc.)
//   VoiceProactivity+Interactions.swift — Public interaction API & driving-mode helpers
//   VoiceProactivity+Relay.swift        — Cross-device relay & direct messaging
//   VoiceProactivity+Convenience.swift  — High-level convenience methods & SpeechDelegate

import Foundation
import AVFoundation
import UserNotifications
#if canImport(Speech)
import Speech
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Voice Proactivity Engine

/// Main engine for proactive voice interactions.
///
/// `VoiceProactivity` manages the full lifecycle of voice interactions:
/// context detection, priority-based queue management, speech synthesis,
/// speech recognition (wake word + response capture), and cross-device
/// message relay.
///
/// Use the shared singleton via ``VoiceProactivity/shared``.
public actor VoiceProactivity {
    // MARK: - Singleton

    /// The shared voice proactivity engine.
    public static let shared = VoiceProactivity()

    // MARK: - Configuration

    /// Configuration for the voice proactivity engine.
    public struct Configuration: Sendable {
        /// Whether the engine is enabled.
        public var enabled: Bool = true
        /// Whether voice output (speech synthesis) is enabled.
        public var voiceEnabled: Bool = true
        /// Whether voice input (speech recognition) is enabled.
        public var listeningEnabled: Bool = true
        /// The preferred `AVSpeechSynthesisVoice` identifier.
        public var preferredVoice: String = "com.apple.voice.compact.en-US.Samantha"
        /// Speech rate (0.0–1.0).
        public var speechRate: Float = 0.5
        /// Base volume (0.0–1.0), capped by context volume.
        public var volume: Float = 0.7
        /// The phrase that activates voice listening.
        public var wakeWord: String = "Hey Thea"
        /// Whether to automatically detect context from activity/location.
        public var autoContextDetection: Bool = true
        /// The default context when auto-detection is unavailable.
        public var defaultContext: VoiceContext = .home
        /// Hour (0–23) when quiet hours begin.
        public var quietHoursStart: Int = 22 // 10 PM
        /// Hour (0–23) when quiet hours end.
        public var quietHoursEnd: Int = 7    // 7 AM
        /// Whether to relay commands through a Mac when direct send fails.
        public var macRelayEnabled: Bool = true
        /// Hostname of the Mac to relay commands to.
        public var macRelayHostname: String = ""
        /// Per-contact preferred messaging platform overrides.
        public var preferredPlatformByContact: [String: MessagingPlatform] = [:]

        public init() {}
    }

    // MARK: - Properties

    var configuration: Configuration
    private var currentContext: VoiceContext = .unknown
    private var isListening = false
    var isSpeaking = false
    var pendingInteractions: [VoiceInteraction] = []
    var activeInteraction: VoiceInteraction?
    var interactionHistory: [VoiceInteraction] = []

    // Speech
    let synthesizer = AVSpeechSynthesizer()
    #if canImport(Speech)
    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    #endif

    // Callbacks
    private var onContextChanged: ((VoiceContext) -> Void)?
    var onInteractionDelivered: ((VoiceInteraction) -> Void)?
    private var onResponseReceived: ((VoiceInteraction, VoiceResponse) -> Void)?
    private var onWakeWordDetected: (() -> Void)?
    var onDeviceRelayResult: ((DeviceRelayResult) -> Void)?

    // MARK: - Initialization

    private init() {
        self.configuration = Configuration()
        #if canImport(Speech)
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.audioEngine = AVAudioEngine()
        #endif
    }

    // MARK: - Configuration

    /// Apply a new configuration to the engine.
    /// - Parameter config: The configuration to apply.
    public func configure(_ config: Configuration) {
        self.configuration = config
    }

    /// Register event callbacks for voice interaction lifecycle events.
    /// - Parameters:
    ///   - onContextChanged: Called when the voice context changes.
    ///   - onInteractionDelivered: Called after an interaction is spoken.
    ///   - onResponseReceived: Called when a voice response is captured.
    ///   - onWakeWordDetected: Called when the wake word is recognized.
    ///   - onDeviceRelayResult: Called after a device relay attempt completes.
    public func configure(
        onContextChanged: @escaping @Sendable (VoiceContext) -> Void,
        onInteractionDelivered: @escaping @Sendable (VoiceInteraction) -> Void,
        onResponseReceived: @escaping @Sendable (VoiceInteraction, VoiceResponse) -> Void,
        onWakeWordDetected: @escaping @Sendable () -> Void,
        onDeviceRelayResult: @escaping @Sendable (DeviceRelayResult) -> Void
    ) {
        self.onContextChanged = onContextChanged
        self.onInteractionDelivered = onInteractionDelivered
        self.onResponseReceived = onResponseReceived
        self.onWakeWordDetected = onWakeWordDetected
        self.onDeviceRelayResult = onDeviceRelayResult
    }

    // MARK: - Lifecycle

    /// Start the voice proactivity engine.
    ///
    /// Begins context detection (if auto-detection is enabled), starts
    /// wake-word listening, and processes any pending interactions.
    public func start() async {
        guard configuration.enabled else { return }

        // Start context detection
        if configuration.autoContextDetection {
            await startContextDetection()
        }

        // Start wake word listening if enabled
        if configuration.listeningEnabled {
            await startListening()
        }

        // Process any pending interactions
        await processPendingInteractions()
    }

    /// Stop the voice proactivity engine.
    public func stop() async {
        await stopListening()
        isSpeaking = false
    }

    // MARK: - Context Management

    /// Set the current voice context.
    ///
    /// Triggers re-evaluation of pending interactions if the context changes.
    /// - Parameter context: The new context.
    public func setContext(_ context: VoiceContext) {
        let oldContext = currentContext
        currentContext = context

        if oldContext != context {
            onContextChanged?(context)

            // Re-evaluate pending interactions
            Task {
                await processPendingInteractions()
            }
        }
    }

    /// Get the current voice context.
    /// - Returns: The active ``VoiceContext``.
    public func getContext() -> VoiceContext {
        currentContext
    }

    // MARK: - Context Detection (Private)

    private func startContextDetection() async {
        // Would integrate with:
        // - CarPlay detection
        // - Activity recognition
        // - Location context
        // - Calendar events
        // For now, default to home
        currentContext = configuration.defaultContext
    }

    // MARK: - Speech Recognition (Private)

    private func startListening() async {
        #if canImport(Speech)
        guard !isListening, let recognizer = recognizer, recognizer.isAvailable else { return }

        isListening = true

        #if os(iOS)
        // Set up audio session (iOS only)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            isListening = false
            return
        }
        #endif

        // Start recognition
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.requiresOnDeviceRecognition = true // Privacy

        guard let audioEngine = audioEngine, let recognitionRequest = recognitionRequest else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcription = result.bestTranscription.formattedString.lowercased()
                let isFinal = result.isFinal

                // Use detached tasks to avoid sending closure data race issues
                Task.detached { [weak self] in
                    await self?.checkForWakeWord(transcription)
                }

                Task.detached { [weak self] in
                    await self?.processVoiceInput(transcription, isFinal: isFinal)
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                Task.detached { [weak self] in
                    await self?.restartListeningIfNeeded()
                }
            }
        }
        #endif
    }

    private func stopListening() async {
        #if canImport(Speech)
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isListening = false
        #endif
    }

    private func restartListeningIfNeeded() async {
        if configuration.listeningEnabled && !isListening {
            await startListening()
        }
    }

    private func checkForWakeWord(_ transcription: String) async {
        if transcription.contains(configuration.wakeWord.lowercased()) {
            onWakeWordDetected?()

            // Acknowledge
            await speakImmediate("Yes?", priority: .high)
        }
    }

    private func processVoiceInput(_ transcription: String, isFinal: Bool) async {
        guard let active = activeInteraction, active.type == .question || active.type == .request else {
            return
        }

        // Check against expected responses
        var matchedResponse: VoiceInteraction.ExpectedResponse?

        if let expected = active.expectedResponses {
            for response in expected {
                for keyword in response.keywords {
                    if transcription.contains(keyword.lowercased()) {
                        matchedResponse = response
                        break
                    }
                }
                if matchedResponse != nil { break }
            }
        }

        // If final or matched, record response
        if isFinal || matchedResponse != nil {
            let voiceResponse = VoiceResponse(
                transcription: transcription,
                confidence: matchedResponse != nil ? 0.9 : 0.7,
                matchedExpectation: matchedResponse
            )

            var updated = active
            updated.response = voiceResponse
            activeInteraction = updated

            onResponseReceived?(active, voiceResponse)

            // Process follow-up if any (using IDs)
            // Note: Follow-up interactions would need to be stored and retrieved by ID
        }
    }

    // MARK: - Interaction Delivery (Internal)

    /// Process pending interactions, delivering the highest-priority eligible one.
    func processPendingInteractions() async {
        guard !isSpeaking, activeInteraction == nil else { return }

        // Filter for current context
        let validInteractions = pendingInteractions.filter { interaction in
            // Check if priority allows in current context
            interaction.priority.allowedInContext.contains(currentContext) &&
            !interaction.isExpired &&
            shouldDeliverNow(interaction)
        }

        guard let next = validInteractions.first else { return }

        // Remove from pending
        pendingInteractions.removeAll { $0.id == next.id }

        await deliverInteraction(next)
    }

    private func shouldDeliverNow(_ interaction: VoiceInteraction) -> Bool {
        // Check quiet hours
        let hour = Calendar.current.component(.hour, from: Date())
        let inQuietHours = (hour >= configuration.quietHoursStart || hour < configuration.quietHoursEnd)

        if inQuietHours && interaction.priority < .urgent {
            return false
        }

        // Check interruption policy
        switch currentContext.interruptionPolicy {
        case .never:
            return false
        case .emergencyOnly:
            return interaction.priority == .emergency
        case .urgentOnly:
            return interaction.priority >= .urgent
        case .normal:
            return interaction.priority >= .normal
        case .always:
            return true
        }
    }

    /// Deliver an interaction via speech synthesis.
    ///
    /// Adjusts volume for the current context, speaks the message,
    /// records it in history, and processes the next queued interaction.
    /// - Parameter interaction: The interaction to deliver.
    func deliverInteraction(_ interaction: VoiceInteraction) async {
        isSpeaking = true
        activeInteraction = interaction

        // Adjust volume for context
        let volume = min(configuration.volume, currentContext.preferredVolume)

        // Speak the message
        let utterance = AVSpeechUtterance(string: interaction.message)
        utterance.voice = AVSpeechSynthesisVoice(identifier: configuration.preferredVoice)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = configuration.speechRate
        utterance.volume = volume

        // Use delegate pattern for completion
        await withCheckedContinuation { continuation in
            let delegate = VoiceProactivitySpeechDelegate {
                continuation.resume()
            }

            // Store delegate to prevent deallocation
            // In real implementation, use proper delegate management
            self.synthesizer.speak(utterance)

            // Simulate completion for now
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(interaction.message.count) * 0.05) {
                delegate.completion()
            }
        }

        // Update interaction
        var delivered = interaction
        delivered.deliveredAt = Date()

        // Move to history
        interactionHistory.append(delivered)
        if interactionHistory.count > 1000 {
            interactionHistory.removeFirst(interactionHistory.count - 1000)
        }

        onInteractionDelivered?(delivered)

        isSpeaking = false

        // If not expecting response, clear active
        if interaction.type == .notification || interaction.type == .alert {
            activeInteraction = nil
        }

        // Process next in queue
        await processPendingInteractions()
    }

    /// Wait for a spoken response to an active interaction.
    ///
    /// Polls ``activeInteraction`` until a response is captured or timeout.
    /// - Parameters:
    ///   - interaction: The interaction awaiting response.
    ///   - timeout: Maximum seconds to wait.
    /// - Returns: The captured response, or `nil` on timeout.
    func waitForResponse(interaction: VoiceInteraction, timeout: TimeInterval) async -> VoiceResponse? {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let response = activeInteraction?.response {
                activeInteraction = nil
                return response
            }
            try? await Task.sleep(for: .milliseconds(100)) // 100ms
        }

        // Timed out
        activeInteraction = nil
        return nil
    }
}
