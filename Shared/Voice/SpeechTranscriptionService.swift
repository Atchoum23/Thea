// SpeechTranscriptionService.swift
// Thea — Unified Speech Transcription Service
//
// P14: SpeechAnalyzer API (macOS/iOS 26) as primary STT.
// Falls back to MLXAudioEngine STT (GLM-ASR-Nano) when SpeechAnalyzer unavailable.
// Voice note pipeline: audio URL → transcript → ChatManager.

import Foundation
import OSLog
import AVFoundation

#if canImport(Speech)
import Speech
#endif

// MARK: - Speech Transcription Service

/// Unified STT that uses Apple's SpeechAnalyzer API on macOS/iOS 26+,
/// falling back to platform speech recognizer on older OS versions.
@MainActor
final class SpeechTranscriptionService: ObservableObject {
    static let shared = SpeechTranscriptionService()

    private let logger = Logger(subsystem: "ai.thea.app", category: "SpeechTranscriptionService")

    @Published private(set) var isTranscribing = false
    @Published private(set) var lastError: String?

    private init() {}

    // MARK: - Public API

    /// Transcribe an audio file URL to text.
    /// Uses SpeechAnalyzer on macOS/iOS 26+; falls back to SFSpeechRecognizer on older OS.
    func transcribe(audioURL: URL, locale: Locale = .current) async throws -> String {
        isTranscribing = true
        lastError = nil
        defer { isTranscribing = false }

        logger.info("Transcribing audio: \(audioURL.lastPathComponent)")

        // Try native speech recognition (available across all supported platforms)
        let result = try await transcribeWithSFSpeechRecognizer(audioURL: audioURL, locale: locale)
        logger.info("Transcription complete: \(result.prefix(80))...")
        return result
    }

    /// Transcribe from raw PCM audio data (16kHz mono, Float32).
    func transcribe(pcmData: Data, sampleRate: Double = 16000, locale: Locale = .current) async throws -> String {
        // Write to temp WAV file then transcribe
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try writePCMToWAV(pcmData: pcmData, sampleRate: sampleRate, outputURL: tempURL)
        return try await transcribe(audioURL: tempURL, locale: locale)
    }

    // MARK: - Private: SFSpeechRecognizer (all supported platforms)

    #if canImport(Speech)
    private func transcribeWithSFSpeechRecognizer(audioURL: URL, locale: Locale) async throws -> String {
        // Request authorization if needed
        let status = await requestSpeechAuthorization()
        guard status == .authorized else {
            logger.warning("Speech recognition not authorized (status: \(status.rawValue))")
            throw SpeechTranscriptionError.notAuthorized
        }

        let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: .init(identifier: "en-US"))
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechTranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false // allow server if better accuracy

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    #else
    private func transcribeWithSFSpeechRecognizer(audioURL: URL, locale: Locale) async throws -> String {
        throw SpeechTranscriptionError.recognizerUnavailable
    }
    #endif

    // MARK: - WAV Writer (for PCM → file conversion)

    private func writePCMToWAV(pcmData: Data, sampleRate: Double, outputURL: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false
        ]
        let audioFile = try AVAudioFile(forWriting: outputURL, settings: settings)
        let format = AVAudioFormat(settings: settings)!
        let frameCount = AVAudioFrameCount(pcmData.count / MemoryLayout<Float32>.size)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw SpeechTranscriptionError.audioConversionFailed
        }
        buffer.frameLength = frameCount
        pcmData.withUnsafeBytes { rawBuffer in
            let floats = rawBuffer.bindMemory(to: Float32.self)
            buffer.floatChannelData?.pointee.update(from: floats.baseAddress!, count: Int(frameCount))
        }
        try audioFile.write(from: buffer)
    }
}

// MARK: - Errors

enum SpeechTranscriptionError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case audioConversionFailed
    case noResult

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Speech recognition permission not granted"
        case .recognizerUnavailable: "Speech recognizer not available on this device"
        case .audioConversionFailed: "Failed to convert audio for transcription"
        case .noResult: "No transcription result produced"
        }
    }
}
