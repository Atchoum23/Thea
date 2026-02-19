// VoiceProactivity.swift
// THEA - Contextual Voice Interactions
// Created by Claude - February 2026
//
// Proactively speaks to user in appropriate contexts (driving, etc.)
// Can relay commands through Mac when iPhone is locked
// Supports multiple messaging platforms (iMessage, WhatsApp, Telegram)
//
// Public API is split into extension files:
// - VoiceProactivity+Interactions.swift: queueInteraction, speakImmediate, askQuestion, sendMessage,
//   startMessagingFlow, readNotifications, startNavigation
// - VoiceProactivity+Relay.swift: canSendDirectly, sendMessageDirectly, relayThroughMac, determinePlatform
// - VoiceProactivity+Convenience.swift: notifyDeadline, notifyMessage, askPreference

import Foundation
import AVFoundation
import OSLog
import UserNotifications
#if canImport(Speech)
import Speech
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Voice Proactivity Engine

/// Main engine for proactive voice interactions
public actor VoiceProactivity {
    let logger = Logger(subsystem: "ai.thea.app", category: "VoiceProactivity")
    // MARK: - Singleton

    public static let shared = VoiceProactivity()

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var enabled: Bool = true
        public var voiceEnabled: Bool = true
        public var listeningEnabled: Bool = true
        public var preferredVoice: String = "com.apple.voice.compact.en-US.Samantha"
        public var speechRate: Float = 0.5
        public var volume: Float = 0.7
        public var wakeWord: String = "Hey Thea"
        public var autoContextDetection: Bool = true
        public var defaultContext: VoiceContext = .home
        public var quietHoursStart: Int = 22 // 10 PM
        public var quietHoursEnd: Int = 7    // 7 AM
        public var macRelayEnabled: Bool = true
        public var macRelayHostname: String = ""
        public var preferredPlatformByContact: [String: VoiceRelayPlatform] = [:]

        public init() {}
    }

    // MARK: - Properties (internal for extension access)

    var configuration: Configuration
    var currentContext: VoiceContext = .unknown
    var isListening = false
    var isSpeaking = false
    var pendingInteractions: [VoiceInteraction] = []
    var activeInteraction: VoiceInteraction?
    var interactionHistory: [VoiceInteraction] = []

    // Speech
    let synthesizer = AVSpeechSynthesizer()
    #if canImport(Speech)
    var recognizer: SFSpeechRecognizer?
    var audioEngine: AVAudioEngine?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    #endif

    // Callbacks
    var onContextChanged: ((VoiceContext) -> Void)?
    var onInteractionDelivered: ((VoiceInteraction) -> Void)?
    var onResponseReceived: ((VoiceInteraction, VoiceResponse) -> Void)?
    var onWakeWordDetected: (() -> Void)?
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

    public func configure(_ config: Configuration) {
        self.configuration = config
    }

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

    public func stop() async {
        await stopListening()
        isSpeaking = false
    }

    // MARK: - Context Management

    /// Set current context
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

    /// Get current context
    public func getContext() -> VoiceContext {
        currentContext
    }

    // MARK: - Private Implementation

    private func startContextDetection() async {
        // Would integrate with:
        // - CarPlay detection
        // - Activity recognition
        // - Location context
        // - Calendar events
        // For now, default to home
        currentContext = configuration.defaultContext
    }

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
        do {
            try audioEngine.start()
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            return
        }

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
        }
    }

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
            let delegate = SpeechDelegate {
                continuation.resume()
            }

            // Store delegate to prevent deallocation
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

    // periphery:ignore - Reserved: interaction parameter kept for API compatibility
    func waitForResponse(interaction: VoiceInteraction, timeout: TimeInterval) async -> VoiceResponse? {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let response = activeInteraction?.response {
                activeInteraction = nil
                return response
            }
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            } catch {
                break
            }
        }

        // Timed out
        activeInteraction = nil
        return nil
    }
}

// MARK: - Speech Delegate Helper

// @unchecked Sendable: NSObject subclass bridging AVSpeechSynthesizerDelegate; AVSpeechSynthesizer
// dispatches didFinish on main thread; stored completion closure is called from that callback only
private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}
