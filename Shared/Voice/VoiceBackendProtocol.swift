import Foundation

// MARK: - Voice Backend Protocol
// Shared protocol for all voice backends (Apple Speech, MLX Audio, etc.)
// Enables swapping voice engines while keeping the same interface

protocol VoiceSynthesisBackend: Sendable {
    var isAvailable: Bool { get async }

    /// Speak text and return when finished
    func speak(text: String) async throws

    /// Stop any ongoing speech
    func stopSpeaking() async
}

protocol VoiceRecognitionBackend: Sendable {
    var isAvailable: Bool { get async }

    /// Start listening and return the transcribed text
    func listen(timeout: TimeInterval) async throws -> String

    /// Stop listening
    func stopListening() async
}
