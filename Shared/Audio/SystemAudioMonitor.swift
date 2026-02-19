// SystemAudioMonitor.swift
// Standalone system audio monitoring for live interpretation
// Captures system audio output using ScreenCaptureKit (macOS 13+)
// Separate from voice recognition for independent operation

import Foundation
import AVFoundation
import OSLog

private let audioMonitorLogger = Logger(subsystem: "ai.thea.app", category: "SystemAudioMonitor")
import Combine
#if os(macOS)
import ScreenCaptureKit
import OSLog
#endif

// MARK: - Audio Monitor Types

/// Audio capture configuration
struct AudioCaptureConfig: Sendable {
    var sampleRate: Double = 16000  // Standard for speech recognition
    var channelCount: Int = 1       // Mono for speech
    var bufferSize: Int = 1024
    var enableVAD: Bool = true      // Voice activity detection
    var vadThreshold: Float = 0.01  // Minimum amplitude for voice

    static let `default` = AudioCaptureConfig()
    // periphery:ignore - Reserved: audioMonitorLogger global var reserved for future feature activation
    static let highQuality = AudioCaptureConfig(sampleRate: 44100, channelCount: 2)
}

/// Audio source type
enum AudioSourceType: String, Sendable {
    case systemOutput = "System Output"
    case microphone = "Microphone"
    case application = "Application"
    case combined = "Combined"
}

/// Audio buffer with metadata
struct AudioBuffer: Sendable {
    let samples: [Float]
    // periphery:ignore - Reserved: timestamp property — reserved for future feature activation
    let timestamp: Date
    // periphery:ignore - Reserved: sampleRate property — reserved for future feature activation
    let sampleRate: Double
    // periphery:ignore - Reserved: channelCount property — reserved for future feature activation
    let channelCount: Int
    // periphery:ignore - Reserved: highQuality static property reserved for future feature activation
    let duration: TimeInterval
    // periphery:ignore - Reserved: hasVoiceActivity property — reserved for future feature activation
    let hasVoiceActivity: Bool

    // periphery:ignore - Reserved: rmsLevel property — reserved for future feature activation
    var rmsLevel: Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
}

/// Audio monitoring session info
struct AudioMonitoringSession: Identifiable, Sendable {
    let id: UUID
    // periphery:ignore - Reserved: timestamp property reserved for future feature activation
    // periphery:ignore - Reserved: sampleRate property reserved for future feature activation
    // periphery:ignore - Reserved: channelCount property reserved for future feature activation
    let startTime: Date
    // periphery:ignore - Reserved: hasVoiceActivity property reserved for future feature activation
    var endTime: Date?
    // periphery:ignore - Reserved: rmsLevel property reserved for future feature activation
    var source: AudioSourceType
    var totalDuration: TimeInterval
    var bufferCount: Int
    var voiceActivityDuration: TimeInterval
}

// MARK: - System Audio Monitor

// periphery:ignore - Reserved: startTime property reserved for future feature activation
// periphery:ignore - Reserved: endTime property reserved for future feature activation
// periphery:ignore - Reserved: source property reserved for future feature activation
/// Standalone audio monitor for system audio capture
@MainActor
@Observable
final class SystemAudioMonitor {
    static let shared = SystemAudioMonitor()

    // State
    private(set) var isMonitoring = false
    private(set) var currentSource: AudioSourceType = .systemOutput
    private(set) var currentLevel: Float = 0
    private(set) var hasVoiceActivity = false
    private(set) var currentSession: AudioMonitoringSession?

// periphery:ignore - Reserved: shared static property reserved for future feature activation

    // Configuration
    private(set) var config = AudioCaptureConfig.default

    // Callbacks
    var onAudioBuffer: ((AudioBuffer) -> Void)?
    var onVoiceActivityChange: ((Bool) -> Void)?
    var onError: ((Error) -> Void)?

    // Internal
    #if os(macOS)
    private var streamOutput: SCStreamOutput?
    private var stream: SCStream?
    #endif
    private var audioEngine: AVAudioEngine?
    private var sessionId: UUID?

    private init() {}

    // MARK: - Public API

    /// Start monitoring system audio
    func startMonitoring(source: AudioSourceType = .systemOutput, config: AudioCaptureConfig = .default) async throws {
        guard !isMonitoring else { return }

        self.config = config
        self.currentSource = source

        #if os(macOS)
        // periphery:ignore - Reserved: startMonitoring(source:config:) instance method reserved for future feature activation
        if source == .systemOutput {
            try await startSystemAudioCapture()
        } else {
            try await startMicrophoneCapture()
        }
        #else
        try await startMicrophoneCapture()
        #endif

        isMonitoring = true
        sessionId = UUID()
        currentSession = AudioMonitoringSession(
            id: sessionId!,
            startTime: Date(),
            source: source,
            totalDuration: 0,
            bufferCount: 0,
            voiceActivityDuration: 0
        )
    }

    /// Stop monitoring
    func stopMonitoring() async {
        guard isMonitoring else { return }

        #if os(macOS)
        if let stream = stream {
            do {
                // periphery:ignore - Reserved: stopMonitoring() instance method reserved for future feature activation
                try await stream.stopCapture()
            } catch {
                audioMonitorLogger.error("Failed to stop audio capture: \(error.localizedDescription)")
            }
            self.stream = nil
        }
        #endif

        audioEngine?.stop()
        audioEngine = nil

        isMonitoring = false
        currentSession?.endTime = Date()
        sessionId = nil
    }

    /// Update configuration
    func updateConfig(_ newConfig: AudioCaptureConfig) {
        config = newConfig
    }

    // MARK: - macOS System Audio Capture

// periphery:ignore - Reserved: updateConfig(_:) instance method reserved for future feature activation

    #if os(macOS)
    @available(macOS 13.0, *)
    private func startSystemAudioCapture() async throws {
        // Get shareable content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // periphery:ignore - Reserved: startSystemAudioCapture() instance method reserved for future feature activation
        // Get the display to capture audio from
        guard let display = content.displays.first else {
            throw AudioMonitorError.noDisplayAvailable
        }

        // Create stream configuration
        let streamConfig = SCStreamConfiguration()
        streamConfig.capturesAudio = true
        streamConfig.excludesCurrentProcessAudio = false
        streamConfig.sampleRate = Int(config.sampleRate)
        streamConfig.channelCount = config.channelCount

        // We only want audio, not video
        streamConfig.width = 1
        streamConfig.height = 1

        // Create content filter for the display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Create the stream
        stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)

        // Create stream output handler
        let output = AudioStreamOutput(monitor: self)
        streamOutput = output
        try stream?.addStreamOutput(output, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))

        // Start capture
        try await stream?.startCapture()
    }
    #endif

    // MARK: - Microphone Capture

    private func startMicrophoneCapture() async throws {
        audioEngine = AVAudioEngine()

        // periphery:ignore - Reserved: startMicrophoneCapture() instance method reserved for future feature activation
        guard let engine = audioEngine else {
            throw AudioMonitorError.engineCreationFailed
        }

        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(config.bufferSize), format: format) { [weak self] buffer, time in
            Task { @MainActor in
                self?.processAudioBuffer(buffer, time: time)
            }
        }

        // Start the engine
        try engine.start()
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData else { return }

// periphery:ignore - Reserved: processAudioBuffer(_:time:) instance method reserved for future feature activation

        let frameCount = Int(buffer.frameLength)
        var samples: [Float] = []

        // Extract samples (mono mix if stereo)
        for frame in 0..<frameCount {
            var sample: Float = 0
            for channel in 0..<Int(buffer.format.channelCount) {
                sample += channelData[channel][frame]
            }
            sample /= Float(buffer.format.channelCount)
            samples.append(sample)
        }

        // Calculate RMS level
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(samples.count))
        currentLevel = rms

        // Voice activity detection
        let hasVoice = config.enableVAD && rms > config.vadThreshold
        if hasVoice != hasVoiceActivity {
            hasVoiceActivity = hasVoice
            onVoiceActivityChange?(hasVoice)
        }

        // Create buffer
        let audioBuffer = AudioBuffer(
            samples: samples,
            timestamp: Date(),
            sampleRate: buffer.format.sampleRate,
            channelCount: Int(buffer.format.channelCount),
            duration: Double(frameCount) / buffer.format.sampleRate,
            hasVoiceActivity: hasVoice
        )

        // Update session
        if var session = currentSession {
            session.bufferCount += 1
            session.totalDuration += audioBuffer.duration
            if hasVoice {
                session.voiceActivityDuration += audioBuffer.duration
            }
            currentSession = session
        }

        // Callback
        onAudioBuffer?(audioBuffer)
    }

    func handleAudioSamples(_ samples: [Float], sampleRate: Double, channelCount: Int) {
        // Calculate RMS level
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(samples.count))
        currentLevel = rms

        // Voice activity detection
        let hasVoice = config.enableVAD && rms > config.vadThreshold
        if hasVoice != hasVoiceActivity {
            hasVoiceActivity = hasVoice
            onVoiceActivityChange?(hasVoice)
        }

        let duration = Double(samples.count) / sampleRate / Double(channelCount)

        let audioBuffer = AudioBuffer(
            samples: samples,
            timestamp: Date(),
            sampleRate: sampleRate,
            channelCount: channelCount,
            duration: duration,
            hasVoiceActivity: hasVoice
        )

        // Update session
        if var session = currentSession {
            session.bufferCount += 1
            session.totalDuration += audioBuffer.duration
            if hasVoice {
                session.voiceActivityDuration += audioBuffer.duration
            }
            currentSession = session
        }

        onAudioBuffer?(audioBuffer)
    }
}

// MARK: - Stream Output Handler

#if os(macOS)
@available(macOS 13.0, *)
// @unchecked Sendable: NSObject subclass required for SCStreamOutput protocol; SCStream delivers
// callbacks on its own internal queue; weak monitor reference avoids retain cycles
private class AudioStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    // periphery:ignore - Reserved: AudioStreamOutput type reserved for future feature activation
    private weak var monitor: SystemAudioMonitor?

    init(monitor: SystemAudioMonitor) {
        self.monitor = monitor
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio else { return }

        // Extract audio data from sample buffer
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard status == kCMBlockBufferNoErr, let data = dataPointer else { return }

        // Get format description
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return }

        let sampleRate = asbd.pointee.mSampleRate
        let channelCount = Int(asbd.pointee.mChannelsPerFrame)
        let bytesPerFrame = Int(asbd.pointee.mBytesPerFrame)

        // Convert to float samples
        let sampleCount = length / bytesPerFrame
        var samples: [Float] = []

        if asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            // Already float
            data.withMemoryRebound(to: Float.self, capacity: sampleCount) { floatPtr in
                samples = Array(UnsafeBufferPointer(start: floatPtr, count: sampleCount))
            }
        } else if asbd.pointee.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0 {
            // Convert from Int16
            let bitsPerChannel = asbd.pointee.mBitsPerChannel
            if bitsPerChannel == 16 {
                data.withMemoryRebound(to: Int16.self, capacity: sampleCount) { int16Ptr in
                    samples = (0..<sampleCount).map { Float(int16Ptr[$0]) / Float(Int16.max) }
                }
            }
        }

        // Process on main thread
        Task { @MainActor in
            self.monitor?.handleAudioSamples(samples, sampleRate: sampleRate, channelCount: channelCount)
        }
    }
}
#endif

// MARK: - Errors

// periphery:ignore - Reserved: AudioMonitorError type reserved for future feature activation
enum AudioMonitorError: Error, LocalizedError {
    case noDisplayAvailable
    case engineCreationFailed
    case capturePermissionDenied
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .noDisplayAvailable:
            return "No display available for audio capture"
        case .engineCreationFailed:
            return "Failed to create audio engine"
        case .capturePermissionDenied:
            return "Audio capture permission denied"
        case .unsupportedPlatform:
            return "System audio capture not supported on this platform"
        }
    }
}
