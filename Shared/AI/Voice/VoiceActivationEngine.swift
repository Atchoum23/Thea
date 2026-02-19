import AVFoundation
import Foundation
import Speech

@MainActor
@Observable
final class VoiceActivationEngine {
    static let shared = VoiceActivationEngine()

    // State
    private(set) var isListening = false
    private(set) var isProcessing = false
    private(set) var conversationMode = false
    private(set) var lastTranscript = ""
    private(set) var isWakeWordEnabled = true

    // Speech Recognition
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    // periphery:ignore - Reserved: audioEngine property — reserved for future feature activation
    private let audioEngine = AVAudioEngine()

    // Speech Synthesis
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?

    // Configuration reference
    private var config: VoiceConfiguration {
        AppConfiguration.shared.voiceConfig
    }

    private var lastSpeechTime: Date?

    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: config.recognitionLanguage))
        isWakeWordEnabled = config.wakeWordEnabled
    }

    // MARK: - Configuration Updates

// periphery:ignore - Reserved: audioEngine property reserved for future feature activation

    func updateConfiguration() {
        // periphery:ignore - Reserved: speechSynthesizer property reserved for future feature activation
        // Re-initialize speech recognizer if language changed
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: config.recognitionLanguage))
        isWakeWordEnabled = config.wakeWordEnabled
    }

    // MARK: - Wake Word Detection

    // periphery:ignore - Reserved: startWakeWordDetection() instance method — reserved for future feature activation
    func startWakeWordDetection() async throws {
        guard !isListening else { return }

        // Request authorization
        let authStatus = await requestSpeechAuthorization()
        guard authStatus == .authorized else {
            throw VoiceEngineError.authorizationDenied
        }

        try startAudioEngine()
        isListening = true
    }

    // periphery:ignore - Reserved: stopWakeWordDetection() instance method — reserved for future feature activation
    func stopWakeWordDetection() {
        stopAudioEngine()
        isListening = false
        conversationMode = false
    // periphery:ignore - Reserved: startWakeWordDetection() instance method reserved for future feature activation
    }

    // periphery:ignore - Reserved: requestSpeechAuthorization() instance method — reserved for future feature activation
    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // periphery:ignore - Reserved: startAudioEngine() instance method — reserved for future feature activation
    private func startAudioEngine() throws {
        // Cancel any ongoing recognition
        // periphery:ignore - Reserved: stopWakeWordDetection() instance method reserved for future feature activation
        recognitionTask?.cancel()
        recognitionTask = nil

        #if os(iOS)
            // Configure audio session (iOS only)
            // periphery:ignore - Reserved: requestSpeechAuthorization() instance method reserved for future feature activation
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        // periphery:ignore - Reserved: startAudioEngine() instance method reserved for future feature activation
        guard let recognitionRequest else {
            throw VoiceEngineError.recognitionFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = config.requiresOnDeviceRecognition

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let bufferSize = AVAudioFrameCount(config.audioBufferSize)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard self != nil else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    let transcript = result.bestTranscription.formattedString.lowercased()
                    self.lastTranscript = transcript

                    // Check for wake word
                    if self.detectWakeWord(in: transcript) {
                        await self.handleWakeWordDetected(fullTranscript: transcript)
                    }

                    // In conversation mode, process continuous speech
                    if self.conversationMode {
                        self.lastSpeechTime = Date()

                        if result.isFinal {
                            await self.processVoiceCommand(transcript)
                        }
                    }
                }

                if error != nil {
                    self.stopAudioEngine()
                }
            }
        }
    }

    // periphery:ignore - Reserved: stopAudioEngine() instance method — reserved for future feature activation
    private func stopAudioEngine() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil
    }

    // MARK: - Wake Word Detection

    // periphery:ignore - Reserved: stopAudioEngine() instance method reserved for future feature activation
    private func detectWakeWord(in transcript: String) -> Bool {
        guard isWakeWordEnabled, !conversationMode else { return false }

        return config.wakeWords.contains { wakeWord in
            transcript.contains(wakeWord)
        }
    }

    // periphery:ignore - Reserved: handleWakeWordDetected(fullTranscript:) instance method — reserved for future feature activation
    private func handleWakeWordDetected(fullTranscript: String) async {
        // Play activation sound
        if config.activationSoundEnabled {
            playActivationSound()
        // periphery:ignore - Reserved: detectWakeWord(in:) instance method reserved for future feature activation
        }

        // Extract command after wake word
        var command = fullTranscript
        for wakeWord in config.wakeWords {
            command = command.replacingOccurrences(of: wakeWord, with: "")
        }
        // periphery:ignore - Reserved: handleWakeWordDetected(fullTranscript:) instance method reserved for future feature activation
        command = command.trimmingCharacters(in: .whitespacesAndNewlines)

        if command.isEmpty {
            // No command, enter conversation mode
            conversationMode = true
            await speak("How can I help you?")
            lastSpeechTime = Date()

            // Start silence detector
            startSilenceDetector()
        } else {
            // Process command immediately
            await processVoiceCommand(command)
        }
    }

    // MARK: - Voice Command Processing

    private func processVoiceCommand(_ command: String) async {
        guard !command.isEmpty else { return }

        isProcessing = true

        do {
            // Route to AI provider
            let response = try await routeToAI(command)

            // Speak response
            // periphery:ignore - Reserved: processVoiceCommand(_:) instance method reserved for future feature activation
            await speak(response)

            // If in conversation mode, wait for next input
            if conversationMode {
                lastSpeechTime = Date()
            } else {
                // Reset for next wake word
                isProcessing = false
            }
        } catch {
            await speak("Sorry, I encountered an error: \(error.localizedDescription)")
            isProcessing = false
        }
    }

    private func routeToAI(_ input: String) async throws -> String {
        // Get default provider
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw VoiceEngineError.noProvider
        }

        let voiceModel = config.voiceAssistantModel

        let message = AIMessage(
            // periphery:ignore - Reserved: routeToAI(_:) instance method reserved for future feature activation
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(input),
            timestamp: Date(),
            model: voiceModel
        )

        var response = ""
        let stream = try await provider.chat(messages: [message], model: voiceModel, stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text):
                response += text
            case .complete:
                break
            case let .error(error):
                throw error
            }
        }

        return response
    }

    // MARK: - Text-to-Speech

    func speak(_ text: String, rate: Float? = nil) async {
        let speechRate = rate ?? config.speechRate

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: config.speechLanguage)
        utterance.rate = speechRate
        utterance.pitchMultiplier = config.pitchMultiplier
        utterance.volume = config.volume

// periphery:ignore - Reserved: speak(_:rate:) instance method reserved for future feature activation

        currentUtterance = utterance

        await withCheckedContinuation { continuation in
            let delegate = SpeechDelegate {
                continuation.resume()
            }

            speechSynthesizer.delegate = delegate
            speechSynthesizer.speak(utterance)
        }
    }

    // periphery:ignore - Reserved: stopSpeaking() instance method — reserved for future feature activation
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        currentUtterance = nil
    }

    // MARK: - Conversation Mode

    // periphery:ignore - Reserved: stopSpeaking() instance method reserved for future feature activation
    private func startSilenceDetector() {
        let silenceThreshold = config.silenceThresholdSeconds

        Task {
            while conversationMode {
                do {
                    // periphery:ignore - Reserved: startSilenceDetector() instance method reserved for future feature activation
                    try await Task.sleep(nanoseconds: UInt64(silenceThreshold * 1_000_000_000))
                } catch {
                    break // Task cancelled — silence detector stopping
                }

                if let lastSpeech = lastSpeechTime,
                   Date().timeIntervalSince(lastSpeech) >= silenceThreshold
                {
                    // Exit conversation mode after silence
                    await exitConversationMode()
                    break
                }
            }
        }
    }

    private func exitConversationMode() async {
        conversationMode = false
        isProcessing = false
        await speak("Goodbye!")
    }

// periphery:ignore - Reserved: exitConversationMode() instance method reserved for future feature activation

    // MARK: - Audio Feedback

    private func playActivationSound() {
        AudioServicesPlaySystemSound(config.activationSoundID)
    }

    // periphery:ignore - Reserved: playActivationSound() instance method reserved for future feature activation
    // MARK: - Voice Commands

    func handleVoiceCommand(_ command: VoiceCommand) async {
        switch command {
        case .newConversation:
            // periphery:ignore - Reserved: handleVoiceCommand(_:) instance method reserved for future feature activation
            await speak("Creating a new conversation")
            // Trigger new conversation in app

        case .listConversations:
            await speak("Here are your recent conversations")
            // Read out conversation titles

        case .openSettings:
            await speak("Opening settings")
            // Navigate to settings

        case .enableConversationMode:
            conversationMode = true
            await speak("Conversation mode enabled")

        case .disableConversationMode:
            await exitConversationMode()

        case let .custom(text):
            await processVoiceCommand(text)
        }
    }
}

// MARK: - Speech Delegate

// @unchecked Sendable: NSObject subclass bridging AVSpeechSynthesizerDelegate; AVSpeechSynthesizer
// dispatches callbacks on the main thread; the captured onComplete closure is safely invoked there
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let onComplete: () -> Void

// periphery:ignore - Reserved: SpeechDelegate type reserved for future feature activation

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        onComplete()
    }
}

// MARK: - Voice Commands

enum VoiceCommand {
    // periphery:ignore - Reserved: VoiceCommand type reserved for future feature activation
    case newConversation
    case listConversations
    case openSettings
    case enableConversationMode
    case disableConversationMode
    case custom(String)
}

// MARK: - Errors

// periphery:ignore - Reserved: VoiceEngineError type reserved for future feature activation
enum VoiceEngineError: LocalizedError {
    case authorizationDenied
    case recognitionFailed
    case noProvider

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            "Speech recognition authorization denied"
        case .recognitionFailed:
            "Speech recognition failed to start"
        case .noProvider:
            "No AI provider configured"
        }
    }
}
