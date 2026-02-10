//
//  SessionRecordingService.swift
//  Thea
//
//  Record remote desktop sessions as MP4 video files
//

import Foundation
#if os(macOS)
    import AVFoundation
    import CoreMedia
    import CoreVideo
#endif

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
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Initialization

    public init() {
        loadRecordings()
    }

    // MARK: - Start Recording

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
                try? await Task.sleep(nanoseconds: 1_000_000_000)
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

    /// Write an encoded frame (from VideoEncoderService) - converts to pixel buffer first
    public func writeEncodedFrame(_ frame: EncodedFrame) {
        // For recordings, we need the raw pixel buffer, not the encoded data
        // This method is a placeholder - the recording should tap into the raw capture pipeline
        frameCount += 1
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
                fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
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
    public func deleteRecording(id: String) {
        if let index = recordings.firstIndex(where: { $0.id == id }) {
            let recording = recordings[index]
            try? FileManager.default.removeItem(atPath: recording.filePath)
            recordings.remove(at: index)
            saveRecordings()
        }
    }

    /// Delete recordings older than a given date
    public func deleteRecordingsOlderThan(_ date: Date) {
        let toDelete = recordings.filter { $0.startTime < date }
        for recording in toDelete {
            try? FileManager.default.removeItem(atPath: recording.filePath)
        }
        recordings.removeAll { $0.startTime < date }
        saveRecordings()
    }

    /// Get total storage used by recordings
    public var totalStorageBytes: Int64 {
        recordings.reduce(0) { $0 + $1.fileSizeBytes }
    }

    // MARK: - Persistence

    private func loadRecordings() {
        let metadataURL = recordingsDirectory.appendingPathComponent("recordings.json")
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([RecordingMetadata].self, from: data)
        else { return }
        recordings = decoded
    }

    private func saveRecordings() {
        let metadataURL = recordingsDirectory.appendingPathComponent("recordings.json")
        guard let data = try? JSONEncoder().encode(recordings) else { return }
        try? data.write(to: metadataURL)
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
