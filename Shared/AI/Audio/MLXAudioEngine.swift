import Foundation

#if os(macOS)
import MLX
import MLXAudioTTS
import MLXAudioSTT
import MLXAudioCore

// MARK: - MLX Audio Engine
// Native on-device TTS and STT using mlx-audio-swift
// Enables private voice interaction without API calls

// Sendable wrapper for ML model references that are only accessed from @MainActor.
// @unchecked Sendable: generic wrapper transfers non-Sendable ML model refs across actor boundaries;
// safe because the contained model is exclusively accessed from @MainActor (MLXAudioEngine)
private struct SendableModelBox<T>: @unchecked Sendable {
    let model: T
}

@MainActor
@Observable
final class MLXAudioEngine {
    static let shared = MLXAudioEngine()

    // MARK: - State

    private var _ttsModel: SendableModelBox<any SpeechGenerationModel>?
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    var ttsModel: (any SpeechGenerationModel)? { _ttsModel?.model }
    private(set) var ttsModelID: String?
    private var _sttModel: SendableModelBox<GLMASRModel>?
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    var sttModel: GLMASRModel? { _sttModel?.model }
    private(set) var sttModelID: String?
    private(set) var isLoadingTTS = false
    private(set) var isLoadingSTT = false
    private(set) var lastError: Error?

    private init() {}

    // MARK: - TTS Model Loading

    func loadTTSModel(id modelID: String = "mlx-community/Soprano-80M-bf16") async throws {
        if ttsModelID == modelID, _ttsModel != nil { return }

        isLoadingTTS = true
        lastError = nil
        defer { isLoadingTTS = false }

        do {
            let model = try await TTSModelUtils.loadModel(modelRepo: modelID)
            _ttsModel = SendableModelBox(model: model)
            ttsModelID = modelID
            print("MLXAudioEngine: Loaded TTS model \(modelID)")
        } catch {
            lastError = error
            print("MLXAudioEngine: Failed to load TTS \(modelID): \(error)")
            throw error
        }
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func unloadTTSModel() {
        _ttsModel = nil
        ttsModelID = nil
    }

    // MARK: - STT Model Loading

    func loadSTTModel(id modelID: String = "mlx-community/GLM-ASR-Nano-2512-4bit") async throws {
        if sttModelID == modelID, _sttModel != nil { return }

        isLoadingSTT = true
        lastError = nil
        defer { isLoadingSTT = false }

        do {
            let model = try await GLMASRModel.fromPretrained(modelID)
            _sttModel = SendableModelBox(model: model)
            sttModelID = modelID
            print("MLXAudioEngine: Loaded STT model \(modelID)")
        } catch {
            lastError = error
            print("MLXAudioEngine: Failed to load STT \(modelID): \(error)")
            throw error
        }
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func unloadSTTModel() {
        _sttModel = nil
        sttModelID = nil
    }

    // MARK: - Text-to-Speech

    /// Generate speech audio from text (returns WAV file URL)
    func speak(text: String, voice: String? = nil) async throws -> URL {
        guard let box = _ttsModel else {
            throw MLXAudioError.noTTSModelLoaded
        }
        let model = box.model

        let audio = try await model.generate(
            text: text,
            voice: voice,
            refAudio: nil,
            refText: nil,
            language: nil,
            generationParameters: model.defaultGenerationParameters
        )

        // Convert MLXArray to WAV file using StreamingWAVWriter
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let samples: [Float] = audio.asArray(Float.self)
        let writer = try StreamingWAVWriter(url: tempURL, sampleRate: Double(model.sampleRate))
        try writer.writeChunk(samples)
        _ = writer.finalize()

        return tempURL
    }

    /// Stream speech generation events
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func speakStreaming(text: String, voice: String? = nil) throws -> AsyncThrowingStream<AudioGeneration, Error> {
        guard let box = _ttsModel else {
            throw MLXAudioError.noTTSModelLoaded
        }

        return box.model.generateStream(
            text: text,
            voice: voice,
            refAudio: nil,
            refText: nil,
            language: nil,
            generationParameters: box.model.defaultGenerationParameters
        )
    }

    // MARK: - Speech-to-Text

    /// Transcribe audio from a file URL
    func transcribe(audioURL: URL) async throws -> String {
        guard let box = _sttModel else {
            throw MLXAudioError.noSTTModelLoaded
        }

        let (_, audio) = try MLXAudioCore.loadAudioArray(from: audioURL)
        let output = box.model.generate(audio: audio)
        return output.text
    }

    /// Transcribe audio from an MLXArray (16kHz, mono)
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func transcribe(audioArray: MLXArray) throws -> String {
        guard let box = _sttModel else {
            throw MLXAudioError.noSTTModelLoaded
        }

        let output = box.model.generate(audio: audioArray)
        return output.text
    }

    /// Stream transcription events
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func transcribeStreaming(audioURL: URL) async throws -> AsyncThrowingStream<STTGeneration, Error> {
        guard let box = _sttModel else {
            throw MLXAudioError.noSTTModelLoaded
        }

        let (_, audio) = try MLXAudioCore.loadAudioArray(from: audioURL)
        return box.model.generateStream(audio: audio)
    }
}

// MARK: - Errors

enum MLXAudioError: Error, LocalizedError {
    case noTTSModelLoaded
    case noSTTModelLoaded
    case audioConversionFailed

    var errorDescription: String? {
        switch self {
        case .noTTSModelLoaded:
            "No TTS model loaded. Load a TTS model first."
        case .noSTTModelLoaded:
            "No STT model loaded. Load an STT model first."
        case .audioConversionFailed:
            "Failed to convert audio data."
        }
    }
}

#endif
