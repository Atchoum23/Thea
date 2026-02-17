import Foundation
import AVFoundation

#if os(macOS)

// MARK: - MLX Voice Backend
// Wraps MLXAudioEngine to provide VoiceSynthesisBackend conformance
// Uses Soprano-80M for TTS and GLM-ASR-Nano for STT

// @unchecked Sendable: audioPlayer only accessed sequentially within async methods
final class MLXVoiceBackend: VoiceSynthesisBackend, VoiceRecognitionBackend, @unchecked Sendable {

    private var audioPlayer: AVAudioPlayer?

    var isAvailable: Bool {
        get async {
            true // MLX models can always be loaded on macOS
        }
    }

    // MARK: - Synthesis

    func speak(text: String) async throws {
        let engine = await MLXAudioEngine.shared

        // Ensure TTS model is loaded
        if await engine.ttsModelID == nil {
            try await engine.loadTTSModel()
        }

        let audioURL = try await engine.speak(text: text)

        // Play audio using AVAudioPlayer with error propagation
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @MainActor in
                do {
                    let player = try AVAudioPlayer(contentsOf: audioURL)
                    self.audioPlayer = player
                    let delegate = AudioPlayerCompletionDelegate { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                    player.delegate = delegate
                    // Hold reference to delegate to keep it alive
                    objc_setAssociatedObject(player, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
                    player.play()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stopSpeaking() async {
        await MainActor.run {
            audioPlayer?.stop()
            audioPlayer = nil
        }
    }

    // MARK: - Recognition

    func listen(timeout: TimeInterval) async throws -> String {
        let engine = await MLXAudioEngine.shared

        // Ensure STT model is loaded
        if await engine.sttModelID == nil {
            try await engine.loadSTTModel()
        }

        // Record audio using AVAudioEngine, then transcribe
        let audioURL = try await recordAudio(duration: timeout)
        return try await engine.transcribe(audioURL: audioURL)
    }

    func stopListening() async {
        // Recording would be stopped by the timeout in listen()
    }

    // MARK: - Audio Recording

    private func recordAudio(duration: TimeInterval) async throws -> URL {
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let audioFile = try AVAudioFile(
            forWriting: tempURL,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false
            ]
        )

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            try? audioFile.write(from: buffer)
        }

        try audioEngine.start()

        try await Task.sleep(for: .seconds(duration))

        audioEngine.stop()
        inputNode.removeTap(onBus: 0)

        return tempURL
    }
}

// MARK: - Audio Player Completion Delegate

// @unchecked Sendable: NSObject delegate with immutable @Sendable closure set during init
private final class AudioPlayerCompletionDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    private let onComplete: @Sendable (Error?) -> Void

    init(onComplete: @escaping @Sendable (Error?) -> Void) {
        self.onComplete = onComplete
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onComplete(flag ? nil : MLXVoiceError.playbackFailed)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        onComplete(error ?? MLXVoiceError.decodeError)
    }
}

enum MLXVoiceError: LocalizedError {
    case playbackFailed
    case decodeError

    var errorDescription: String? {
        switch self {
        case .playbackFailed: "Audio playback did not complete successfully"
        case .decodeError: "Audio decode error occurred during playback"
        }
    }
}

#endif
