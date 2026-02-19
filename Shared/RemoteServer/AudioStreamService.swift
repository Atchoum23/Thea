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
import OSLog

private let logger = Logger(subsystem: "ai.thea.app", category: "AudioStreamService")
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

    /// Called when a new audio frame is captured (uses AudioFrame from RemoteMessages)
    public var onAudioFrame: ((AudioFrame) -> Void)?

    // MARK: - Capture State

    #if os(macOS)
        private var stream: SCStream?
        // periphery:ignore - Reserved: audioOutput property reserved for future feature activation
        private var audioOutput: AudioCaptureOutput?
    #endif

    // MARK: - Configuration

    public var sampleRate: Double = 48000
    public var channels: Int = 2

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
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

            let output = AudioCaptureOutput { [weak self] frame, peakLevel in
                Task { @MainActor in
                    guard let self, !self.isMuted else { return }
                    self.audioLevel = peakLevel
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
                do {
                    try await stream.stopCapture()
                } catch {
                    logger.error("Failed to stop audio capture: \(error.localizedDescription)")
                }
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

    /// Play received audio frames on the client side
    public func playAudioFrame(_ frame: AudioFrame) {
        #if os(macOS)
        guard !isMuted else { return }
        do {
            let audioData = frame.data
            guard !audioData.isEmpty else { return }
            // Play raw PCM audio using AVAudioPlayer (WAV header prepended for compatibility)
            var wavData = Data()
            // WAV header for raw PCM: 44.1kHz, 16-bit, mono
            let dataSize = UInt32(audioData.count)
            let fileSize = dataSize + 36
            wavData.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
            wavData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
            wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
            wavData.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
            wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
            wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
            wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // mono
            wavData.append(contentsOf: withUnsafeBytes(of: UInt32(44100).littleEndian) { Array($0) })
            wavData.append(contentsOf: withUnsafeBytes(of: UInt32(88200).littleEndian) { Array($0) })
            wavData.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })
            wavData.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })
            wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
            wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
            wavData.append(audioData)

            let player = try AVAudioPlayer(data: wavData)
            player.volume = volume
            player.play()
        } catch {
            // Audio playback failed — non-critical for remote session
        }
        #endif
    }
}

// MARK: - Audio Capture Output

#if os(macOS)
    private class AudioCaptureOutput: NSObject, SCStreamOutput {
        private let handler: (AudioFrame, Float) -> Void

        init(handler: @escaping (AudioFrame, Float) -> Void) {
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

            let peakLevel = calculatePeakLevel(data: data)

            let frame = AudioFrame(
                data: data,
                codec: .pcm,
                sampleRate: Int(sampleRate),
                channels: Int(channels),
                timestamp: timestamp.seconds
            )

            handler(frame, peakLevel)
        }

        private func calculatePeakLevel(data: Data) -> Float {
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
