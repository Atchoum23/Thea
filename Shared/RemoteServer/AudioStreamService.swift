//
//  AudioStreamService.swift
//  Thea
//
//  Audio capture and streaming for remote desktop sessions
//

import Foundation
#if os(macOS)
    import AVFoundation
    import CoreMedia
    import ScreenCaptureKit
#endif

// MARK: - Audio Stream Service

/// Captures and streams system audio during remote desktop sessions
@MainActor
public class AudioStreamService: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var isCapturing = false
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var isMuted = false
    @Published public var volume: Float = 1.0

    // MARK: - Callbacks

    public var onAudioFrame: ((AudioFrame) -> Void)?

    // MARK: - Capture State

    #if os(macOS)
        private var stream: SCStream?
        private var audioOutput: AudioCaptureOutput?
    #endif

    // MARK: - Configuration

    public var sampleRate: Double = 48000
    public var channels: Int = 2
    public var codec: AudioCodec = .aac

    // MARK: - Initialization

    public init() {}

    // MARK: - Start Capture

    /// Start capturing system audio
    public func startCapture() async throws {
        guard !isCapturing else { return }

        #if os(macOS)
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            )

            guard let display = content.displays.first else {
                throw AudioStreamError.noDisplayFound
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()

            // Enable audio capture
            config.capturesAudio = true
            config.sampleRate = Int(sampleRate)
            config.channelCount = channels

            // Disable video to save resources (audio-only stream)
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 FPS minimum

            let output = AudioCaptureOutput { [weak self] frame in
                Task { @MainActor in
                    guard let self, !self.isMuted else { return }
                    self.audioLevel = frame.peakLevel
                    self.onAudioFrame?(frame)
                }
            }

            let captureStream = SCStream(filter: filter, configuration: config, delegate: nil)
            try captureStream.addStreamOutput(output, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
            try await captureStream.startCapture()

            stream = captureStream
            audioOutput = output
            isCapturing = true
        #else
            throw AudioStreamError.notSupported
        #endif
    }

    // MARK: - Stop Capture

    /// Stop capturing audio
    public func stopCapture() async {
        #if os(macOS)
            if let stream {
                try? await stream.stopCapture()
            }
            stream = nil
            audioOutput = nil
        #endif

        isCapturing = false
        audioLevel = 0
    }

    // MARK: - Mute/Unmute

    /// Toggle mute state
    public func toggleMute() {
        isMuted.toggle()
        if isMuted {
            audioLevel = 0
        }
    }

    /// Set mute state
    public func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted {
            audioLevel = 0
        }
    }

    // MARK: - Playback (Client Side)

    /// Play received audio frames
    public func playAudioFrame(_ frame: AudioFrame) {
        #if os(macOS)
            // Client-side audio playback would use AVAudioEngine
            // This is a placeholder for the receiving end
        #endif
    }
}

// MARK: - Audio Capture Output

#if os(macOS)
    private class AudioCaptureOutput: NSObject, SCStreamOutput {
        private let handler: (AudioFrame) -> Void

        init(handler: @escaping (AudioFrame) -> Void) {
            self.handler = handler
        }

        func stream(_: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
            guard type == .audio else { return }

            guard let formatDesc = sampleBuffer.formatDescription,
                  let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
            else { return }

            let sampleRate = audioStreamBasicDescription.pointee.mSampleRate
            let channels = audioStreamBasicDescription.pointee.mChannelsPerFrame
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            // Get audio data
            guard let blockBuffer = sampleBuffer.dataBuffer else { return }
            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

            guard let dataPointer, length > 0 else { return }
            let data = Data(bytes: dataPointer, count: length)

            // Calculate peak level
            let peakLevel = calculatePeakLevel(data: data)

            let frame = AudioFrame(
                data: data,
                sampleRate: sampleRate,
                channels: Int(channels),
                codec: .pcm,
                timestamp: timestamp.seconds,
                peakLevel: peakLevel,
                sequenceNumber: 0
            )

            handler(frame)
        }

        private func calculatePeakLevel(data: Data) -> Float {
            // Assuming 32-bit float PCM
            let floatCount = data.count / 4
            guard floatCount > 0 else { return 0 }

            return data.withUnsafeBytes { buffer -> Float in
                guard let floats = buffer.baseAddress?.assumingMemoryBound(to: Float.self) else { return 0 }
                var peak: Float = 0
                for i in 0 ..< floatCount {
                    let abs = Swift.abs(floats[i])
                    if abs > peak { peak = abs }
                }
                return min(peak, 1.0)
            }
        }
    }
#endif

// MARK: - Audio Codec

public enum AudioCodec: String, Codable, Sendable {
    case pcm
    case aac
    case opus
}

// MARK: - Audio Stream Error

public enum AudioStreamError: Error, LocalizedError, Sendable {
    case notSupported
    case noDisplayFound
    case captureError(String)
    case encodingError(String)

    public var errorDescription: String? {
        switch self {
        case .notSupported: "Audio streaming not supported on this platform"
        case .noDisplayFound: "No display found for audio capture"
        case let .captureError(msg): "Audio capture error: \(msg)"
        case let .encodingError(msg): "Audio encoding error: \(msg)"
        }
    }
}
