//
//  RemoteMediaMessages.swift
//  Thea
//
//  Recording and audio streaming message types for remote server protocol
//

import Foundation

// MARK: - Recording Messages

public enum RecordingRequest: Codable, Sendable {
    case startRecording(sessionId: String)
    case stopRecording
    case listRecordings
    case deleteRecording(id: String)
}

public enum RecordingResponse: Codable, Sendable {
    case recordingStarted(recordingId: String)
    case recordingStopped(recordingId: String, durationSeconds: Double, fileSizeBytes: Int64)
    case recordingList([RecordingMetadata])
    case error(String)
}

public struct RecordingMetadata: Codable, Sendable, Identifiable {
    public let id: String
    public let sessionId: String
    public let startTime: Date
    public let durationSeconds: Double
    public let fileSizeBytes: Int64
    public let resolution: String
    public let codec: String
    public let filePath: String

    public init(id: String, sessionId: String, startTime: Date, durationSeconds: Double, fileSizeBytes: Int64, resolution: String, codec: String, filePath: String) {
        self.id = id
        self.sessionId = sessionId
        self.startTime = startTime
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.resolution = resolution
        self.codec = codec
        self.filePath = filePath
    }
}

// MARK: - Audio Messages

public enum AudioRequest: Codable, Sendable {
    case startAudioStream(sampleRate: Int, channels: Int)
    case stopAudioStream
    case setAudioVolume(Float)
    case startMicrophoneForward
    case stopMicrophoneForward
}

public enum AudioResponse: Codable, Sendable {
    case audioFrame(AudioFrame)
    case audioStreamStarted
    case audioStreamStopped
    case error(String)
}

public struct AudioFrame: Codable, Sendable {
    public let data: Data
    public let codec: AudioCodecType
    public let sampleRate: Int
    public let channels: Int
    public let timestamp: Double

    public init(data: Data, codec: AudioCodecType, sampleRate: Int, channels: Int, timestamp: Double) {
        self.data = data
        self.codec = codec
        self.sampleRate = sampleRate
        self.channels = channels
        self.timestamp = timestamp
    }

    public enum AudioCodecType: String, Codable, Sendable {
        case opus
        case aac
        case pcm
    }
}
