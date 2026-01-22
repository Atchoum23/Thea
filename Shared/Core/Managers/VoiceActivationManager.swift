import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class VoiceActivationManager {
    static let shared = VoiceActivationManager()

    var isEnabled: Bool = false
    var isListening: Bool = false
    var transcriptionText: String = ""
    var wakeWord: String = "Hey Thea"
    var conversationMode: Bool = false
    var onTranscriptionComplete: ((String) -> Void)?

    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        // Load saved preferences
        if let savedWakeWord = UserDefaults.standard.string(forKey: "wakeWord") {
            wakeWord = savedWakeWord
        }
        conversationMode = UserDefaults.standard.bool(forKey: "conversationMode")
    }

    // MARK: - Permissions

    func requestPermissions() async throws {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw VoiceError.speechRecognitionNotAuthorized
        }

        // Request microphone permission
        let micStatus = await AVAudioApplication.requestRecordPermission()
        guard micStatus else {
            throw VoiceError.microphoneNotAuthorized
        }

        isEnabled = true
    }

    // MARK: - Wake Word Detection

    func startWakeWordDetection() throws {
        guard isEnabled else { return }
        // Wake word detection implementation would go here
        // For now, this is a stub
    }

    func stopWakeWordDetection() {
        // Stop wake word detection
    }

    // MARK: - Voice Commands

    func startVoiceCommand() throws {
        guard isEnabled else { throw VoiceError.notEnabled }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceError.recognizerNotAvailable
        }

        audioEngine = AVAudioEngine()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let audioEngine = audioEngine,
              let request = recognitionRequest else {
            throw VoiceError.setupFailed
        }

        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        transcriptionText = ""

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let result = result {
                    self.transcriptionText = result.bestTranscription.formattedString

                    if result.isFinal {
                        self.stopVoiceCommand()
                        self.onTranscriptionComplete?(self.transcriptionText)
                    }
                }

                if error != nil {
                    self.stopVoiceCommand()
                }
            }
        }
    }

    func stopVoiceCommand() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil

        isListening = false
    }

    // MARK: - Persistence

    func savePreferences() {
        UserDefaults.standard.set(wakeWord, forKey: "wakeWord")
        UserDefaults.standard.set(conversationMode, forKey: "conversationMode")
    }
}

// MARK: - Errors

enum VoiceError: Error, LocalizedError {
    case notEnabled
    case speechRecognitionNotAuthorized
    case microphoneNotAuthorized
    case recognizerNotAvailable
    case setupFailed

    var errorDescription: String? {
        switch self {
        case .notEnabled:
            return "Voice activation is not enabled"
        case .speechRecognitionNotAuthorized:
            return "Speech recognition not authorized"
        case .microphoneNotAuthorized:
            return "Microphone access not authorized"
        case .recognizerNotAvailable:
            return "Speech recognizer not available"
        case .setupFailed:
            return "Failed to setup voice recognition"
        }
    }
}
