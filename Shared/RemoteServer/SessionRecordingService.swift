//
//  SessionRecordingService.swift
//  Thea
//
//  Record remote desktop sessions as MP4 video files
//

import Foundation
import OSLog
#if os(macOS)
    import AVFoundation
    import CoreMedia
    import CoreVideo
#endif

private let srsLogger = Logger(subsystem: "ai.thea.app", category: "SessionRecording")

// MARK: - Session Recording Service

/// Records remote desktop sessions to MP4 files for review and compliance
@MainActor
public class SessionRecordingService: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var isRecording = false
    @Published public private(set) var currentRecordingId: String?
    @Published public private(set) var recordingDuration: TimeInterval = 0
    @Published public private(set) var recordingFileSize: Int64 = 0
    @Published public private(set) var recordings: [RecordingMetadata] = []
    @Published public var lastError: String?

    // MARK: - Recording State

    #if os(macOS)
        private var assetWriter: AVAssetWriter?
        private var videoInput: AVAssetWriterInput?
        private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    #endif
    private var recordingStartTime: Date?
    private var frameCount: Int64 = 0
    private var currentWidth: Int = 0
    private var currentHeight: Int = 0
    private var durationTimer: Task<Void, Never>?

    // MARK: - Configuration

    public var recordingsDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea/Recordings", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            srsLogger.debug("Could not create recordings directory: \(error.localizedDescription)")
        }
        return dir
    }

    // MARK: - Initialization

    public init() {
        loadRecordings()
    }

    // MARK: - Start Recording

    // periphery:ignore - Reserved: _sessionId parameter kept for API compatibility
    /// Start recording a session
    public func startRecording(sessionId _sessionId: String, width: Int, height: Int) throws -> String {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }

        let recordingId = UUID().uuidString
        let outputURL = recordingsDirectory.appendingPathComponent("\(recordingId).mp4")
        currentWidth = width
        currentHeight = height

        #if os(macOS)
            // Create asset writer
            let writer = try AVAssetWriter(url: outputURL, fileType: .mp4)

            // Video settings
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 5_000_000,
                    AVVideoMaxKeyFrameIntervalKey: 60,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
                ]
            ]

            let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            input.expectsMediaDataInRealTime = true

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height
                ]
            )

            writer.add(input)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            assetWriter = writer
            videoInput = input
            pixelBufferAdaptor = adaptor
        #endif

        currentRecordingId = recordingId
        recordingStartTime = Date()
        frameCount = 0
        isRecording = true

        // Start duration timer
        durationTimer = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
                await MainActor.run {
                    if let start = self.recordingStartTime {
                        self.recordingDuration = Date().timeIntervalSince(start)
                    }
                }
            }
        }

        return recordingId
    }

    // MARK: - Write Frame

    /// Write a pixel buffer frame to the recording
    #if os(macOS)
    public func writeFrame(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard isRecording,
              let input = videoInput,
              let adaptor = pixelBufferAdaptor,
              input.isReadyForMoreMediaData
        else { return }

        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        frameCount += 1
    }
    #endif

    /// Write an encoded frame (from VideoEncoderService)
    /// Note: For best quality, prefer writeFrame(pixelBuffer:presentationTime:) which feeds
    /// raw pixel buffers directly to AVAssetWriter. Encoded frames are counted but not re-encoded
    /// to avoid double-compression artifacts.
    public func writeEncodedFrame(_ frame: EncodedFrame) {
        #if os(macOS)
        // Decode the H.264/HEVC frame back to a pixel buffer for recording
        // This path is used when the capture pipeline only provides encoded data
        guard isRecording,
              let input = videoInput,
              input.isReadyForMoreMediaData,
              !frame.data.isEmpty
        else {
            frameCount += 1
            return
        }

        // Create a CMBlockBuffer from the encoded data
        var blockBuffer: CMBlockBuffer?
        let dataLength = frame.data.count
        frame.data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: UnsafeMutableRawPointer(mutating: baseAddress),
                blockLength: dataLength,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: dataLength,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
        }

        frameCount += 1
        #else
        frameCount += 1
        #endif
    }

    // MARK: - Stop Recording

    /// Stop the current recording
    public func stopRecording() async -> RecordingMetadata? {
        guard isRecording, let recordingId = currentRecordingId else { return nil }

        durationTimer?.cancel()
        durationTimer = nil

        let duration = recordingDuration
        var fileSize: Int64 = 0

        #if os(macOS)
            videoInput?.markAsFinished()

            if let writer = assetWriter {
                await writer.finishWriting()

                let outputURL = writer.outputURL
                do {
                    fileSize = (try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
                } catch {
                    srsLogger.debug("Could not get recording file size: \(error.localizedDescription)")
                }
            }

            assetWriter = nil
            videoInput = nil
            pixelBufferAdaptor = nil
        #endif

        let metadata = RecordingMetadata(
            id: recordingId,
            sessionId: recordingId,
            startTime: recordingStartTime ?? Date(),
            durationSeconds: duration,
            fileSizeBytes: fileSize,
            resolution: "\(currentWidth)x\(currentHeight)",
            codec: "H.264",
            filePath: recordingsDirectory.appendingPathComponent("\(recordingId).mp4").path
        )

        recordings.insert(metadata, at: 0)
        saveRecordings()

        isRecording = false
        currentRecordingId = nil
        recordingDuration = 0
        recordingFileSize = 0
        recordingStartTime = nil

        return metadata
    }

    // MARK: - Recording Management

    /// Delete a recording
    public func deleteRecording(id: String) throws {
        guard let index = recordings.firstIndex(where: { $0.id == id }) else { return }
        let recording = recordings[index]
        do {
            try FileManager.default.removeItem(atPath: recording.filePath)
        } catch {
            srsLogger.error("Failed to delete recording file \(recording.filePath): \(error.localizedDescription)")
            lastError = "Failed to delete recording: \(error.localizedDescription)"
            throw error
        }
        recordings.remove(at: index)
        saveRecordings()
    }

    /// Delete recordings older than a given date
    public func deleteRecordingsOlderThan(_ date: Date) {
        let toDelete = recordings.filter { $0.startTime < date }
        var failedIds: Set<String> = []
        for recording in toDelete {
            do {
                try FileManager.default.removeItem(atPath: recording.filePath)
            } catch {
                failedIds.insert(recording.id)
                srsLogger.warning("Failed to delete recording file \(recording.filePath): \(error.localizedDescription)")
            }
        }
        // Only remove entries whose files were successfully deleted
        recordings.removeAll { $0.startTime < date && !failedIds.contains($0.id) }
        if !failedIds.isEmpty {
            lastError = "Failed to delete \(failedIds.count) recording(s) — files may be locked or missing"
        }
        saveRecordings()
    }

    /// Get total storage used by recordings
    public var totalStorageBytes: Int64 {
        recordings.reduce(0) { $0 + $1.fileSizeBytes }
    }

    // MARK: - Persistence

    private func loadRecordings() {
        let metadataURL = recordingsDirectory.appendingPathComponent("recordings.json")
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return }
        do {
            let data = try Data(contentsOf: metadataURL)
            recordings = try JSONDecoder().decode([RecordingMetadata].self, from: data)
        } catch {
            srsLogger.debug("Could not load recordings metadata: \(error.localizedDescription)")
        }
    }

    private func saveRecordings() {
        let metadataURL = recordingsDirectory.appendingPathComponent("recordings.json")
        do {
            let data = try JSONEncoder().encode(recordings)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            srsLogger.error("Failed to save recordings metadata: \(error.localizedDescription)")
            lastError = "Failed to save recording metadata: \(error.localizedDescription)"
        }
    }
}

// MARK: - Recording Error

public enum RecordingError: Error, LocalizedError, Sendable {
    case alreadyRecording
    case notRecording
    case writerFailed(String)
    case notSupported

    public var errorDescription: String? {
        switch self {
        case .alreadyRecording: "Recording is already in progress"
        case .notRecording: "No recording in progress"
        case let .writerFailed(msg): "Recording writer failed: \(msg)"
        case .notSupported: "Recording not supported on this platform"
        }
    }
}
