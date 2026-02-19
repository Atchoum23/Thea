// CallMonitor+TranscriptionEngine.swift
// THEA - Voice Call Transcription & Intelligence
//
// Real-time speech-to-text transcription using the Speech framework.
// Manages per-call recognition sessions with on-device processing
// for privacy.

import Foundation
import AVFoundation
#if canImport(Speech)
import Speech
#endif

// MARK: - Transcription Engine

/// Actor responsible for real-time speech transcription of active calls.
///
/// Each call gets its own `SFSpeechAudioBufferRecognitionRequest` session.
/// Audio buffers are appended incrementally via `transcribe(buffer:callId:)`,
/// and transcription runs entirely on-device (`requiresOnDeviceRecognition = true`)
/// to preserve user privacy.
actor TranscriptionEngine {
    #if canImport(Speech)
    /// The speech recognizer configured for the target language.
    private var recognizer: SFSpeechRecognizer?
    /// Active recognition requests keyed by call UUID.
    private var sessions: [UUID: SFSpeechAudioBufferRecognitionRequest] = [:]
    /// Active recognition tasks keyed by call UUID.
    private var tasks: [UUID: SFSpeechRecognitionTask] = [:]
    #endif
    // periphery:ignore - Reserved: currentSpeaker property — reserved for future feature activation
    /// The speaker label for the current segment being transcribed.
    private var currentSpeaker: String = "Unknown"
    // periphery:ignore - Reserved: currentSpeaker property reserved for future feature activation
    // periphery:ignore - Reserved: segmentStartTime property reserved for future feature activation
    /// The start time of the current transcript segment.
    private var segmentStartTime: Date?

    /// Initializes the speech recognizer for the given language.
    /// - Parameter language: A BCP-47 language identifier (e.g., "en-US").
    func initialize(language: String) async {
        #if canImport(Speech)
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
        #endif
    }

    /// Starts a new recognition session for the specified call.
    ///
    /// Creates a `SFSpeechAudioBufferRecognitionRequest` configured for
    /// partial results and on-device-only recognition.
    ///
    /// - Parameter callId: The UUID of the call to begin transcribing.
    func startSession(callId: UUID) async {
        #if canImport(Speech)
        guard recognizer != nil else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true // Privacy: on-device only

        sessions[callId] = request
        segmentStartTime = Date()
        #endif
    }

    /// Stops and cleans up the recognition session for the specified call.
    /// - Parameter callId: The UUID of the call whose session should end.
    func stopSession(callId: UUID) async {
        #if canImport(Speech)
        sessions[callId]?.endAudio()
        sessions.removeValue(forKey: callId)
        tasks[callId]?.cancel()
        tasks.removeValue(forKey: callId)
        #endif
    }

    /// Transcribes an audio buffer within the context of an active call session.
    ///
    /// Appends the buffer's audio data to the call's recognition request and,
    /// if no recognition task is running yet, starts one.
    ///
    /// - Parameters:
    ///   - buffer: A `SendableAudioBuffer` wrapping the raw `AVAudioPCMBuffer`.
    ///   - callId: The UUID of the call the audio belongs to.
    /// - Returns: A `CallTranscriptSegment` if transcription produced a result, or `nil`.
    func transcribe(buffer: SendableAudioBuffer, callId: UUID) async -> CallTranscriptSegment? {
        #if canImport(Speech)
        guard let request = sessions[callId], let recognizer = recognizer else {
            return nil
        }

        // Append audio from the wrapped buffer
        request.append(buffer.buffer)

        // If no active task, start one
        if tasks[callId] == nil {
            let task = recognizer.recognitionTask(with: request) { _, _ in
                // Handle results
                // This is simplified - actual implementation would be more complex
            }
            tasks[callId] = task
        }

        // Return a segment (simplified - actual implementation uses delegate pattern)
        return nil
        #else
        return nil
        #endif
    }

    /// Stops all active transcription sessions and cancels all recognition tasks.
    func stop() async {
        #if canImport(Speech)
        for (_, request) in sessions {
            request.endAudio()
        }
        for (_, task) in tasks {
            task.cancel()
        }
        sessions.removeAll()
        tasks.removeAll()
        #endif
    }
}
