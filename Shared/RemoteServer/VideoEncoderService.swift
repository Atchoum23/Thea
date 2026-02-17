//
//  VideoEncoderService.swift
//  Thea
//
//  Hardware-accelerated video encoding via VideoToolbox for remote desktop streaming
//

import Combine
import CoreMedia
import Foundation
#if os(macOS)
    import AppKit
    import CoreImage
    import VideoToolbox
#endif

// MARK: - Video Codec

public enum VideoCodec: String, Codable, Sendable, CaseIterable {
    case h264
    case h265
    case jpeg // Fallback

    public var displayName: String {
        switch self {
        case .h264: "H.264 (AVC)"
        case .h265: "H.265 (HEVC)"
        case .jpeg: "JPEG (Legacy)"
        }
    }

    #if os(macOS)
        var vtCodecType: CMVideoCodecType {
            switch self {
            case .h264: kCMVideoCodecType_H264
            case .h265: kCMVideoCodecType_HEVC
            case .jpeg: kCMVideoCodecType_JPEG
            }
        }
    #endif
}

// MARK: - Quality Profile

public enum StreamQualityProfile: String, Codable, Sendable, CaseIterable {
    case bestQuality
    case balanced
    case bestPerformance

    public var displayName: String {
        switch self {
        case .bestQuality: "Best Quality"
        case .balanced: "Balanced"
        case .bestPerformance: "Best Performance"
        }
    }

    var bitrateMbps: Double {
        switch self {
        case .bestQuality: 20.0
        case .balanced: 8.0
        case .bestPerformance: 3.0
        }
    }

    var keyFrameIntervalSeconds: Int {
        switch self {
        case .bestQuality: 2
        case .balanced: 3
        case .bestPerformance: 5
        }
    }

    var maxFPS: Int {
        switch self {
        case .bestQuality: 60
        case .balanced: 30
        case .bestPerformance: 15
        }
    }
}

// MARK: - Encoded Frame

public struct EncodedFrame: Sendable {
    public let data: Data
    public let isKeyFrame: Bool
    public let presentationTimestamp: Double
    public let codec: ScreenFrame.ImageFormat
    public let width: Int
    public let height: Int

    public init(data: Data, isKeyFrame: Bool, presentationTimestamp: Double, codec: ScreenFrame.ImageFormat, width: Int, height: Int) {
        self.data = data
        self.isKeyFrame = isKeyFrame
        self.presentationTimestamp = presentationTimestamp
        self.codec = codec
        self.width = width
        self.height = height
    }
}

// MARK: - Video Encoder Service

#if os(macOS)

    /// Hardware-accelerated video encoder using VideoToolbox
    @MainActor
    public class VideoEncoderService: ObservableObject {
        // MARK: - Published State

        @Published public private(set) var isEncoding = false
        @Published public private(set) var codec: VideoCodec = .h264
        @Published public private(set) var profile: StreamQualityProfile = .balanced
        @Published public private(set) var encodedFrameCount: Int64 = 0
        @Published public private(set) var encodedBytesTotal: Int64 = 0

        // MARK: - Compression Session

        // nonisolated(unsafe) allows deinit to access this property
        nonisolated(unsafe) private var compressionSession: VTCompressionSession?
        private var frameCallback: ((EncodedFrame) -> Void)?
        private var width: Int = 0
        private var height: Int = 0
        private var frameIndex: Int64 = 0

        // MARK: - Adaptive Bitrate

        private var currentBitrate: Int = 8_000_000
        private var targetBitrate: Int = 8_000_000

        // MARK: - Initialization

        public init() {}

        deinit {
            if let session = compressionSession {
                VTCompressionSessionInvalidate(session)
            }
        }

        // MARK: - Configuration

        /// Configure the encoder with codec, profile, and dimensions
        public func configure(
            codec: VideoCodec,
            profile: StreamQualityProfile,
            width: Int,
            height: Int
        ) throws {
            // Tear down existing session
            if let session = compressionSession {
                VTCompressionSessionInvalidate(session)
                compressionSession = nil
            }

            self.codec = codec
            self.profile = profile
            self.width = width
            self.height = height
            targetBitrate = Int(profile.bitrateMbps * 1_000_000)
            currentBitrate = targetBitrate
            frameIndex = 0

            guard codec != .jpeg else {
                // JPEG doesn't use VTCompressionSession
                return
            }

            var session: VTCompressionSession?
            let status = VTCompressionSessionCreate(
                allocator: kCFAllocatorDefault,
                width: Int32(width),
                height: Int32(height),
                codecType: codec.vtCodecType,
                encoderSpecification: [
                    kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder: true
                ] as CFDictionary,
                imageBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey: width,
                    kCVPixelBufferHeightKey: height
                ] as CFDictionary,
                compressedDataAllocator: nil,
                outputCallback: nil,
                refcon: nil,
                compressionSessionOut: &session
            )

            guard status == noErr, let session else {
                throw VideoEncoderError.sessionCreationFailed(status)
            }

            // Configure session properties
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: currentBitrate as CFNumber)
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: (profile.keyFrameIntervalSeconds * profile.maxFPS) as CFNumber)
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: profile.maxFPS as CFNumber)

            // Set profile level
            if codec == .h264 {
                VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel)
            }

            VTCompressionSessionPrepareToEncodeFrames(session)
            compressionSession = session
        }

        // MARK: - Encoding

        /// Set callback for receiving encoded frames
        public func setFrameCallback(_ callback: @escaping (EncodedFrame) -> Void) {
            frameCallback = callback
        }

        /// Encode a CVPixelBuffer from ScreenCaptureKit
        public func encode(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) async throws {
            guard codec != .jpeg else {
                try await encodeAsJPEG(pixelBuffer: pixelBuffer, presentationTime: presentationTime)
                return
            }

            guard let session = compressionSession else {
                throw VideoEncoderError.notConfigured
            }

            let frameProperties: [String: Any] = [:]

            var infoFlags = VTEncodeInfoFlags()

            let status = VTCompressionSessionEncodeFrame(
                session,
                imageBuffer: pixelBuffer,
                presentationTimeStamp: presentationTime,
                duration: .invalid,
                frameProperties: frameProperties as CFDictionary,
                infoFlagsOut: &infoFlags
            ) { [weak self] status, _, sampleBuffer in
                guard status == noErr, let sampleBuffer else { return }
                // CMSampleBuffer is a CF type safe to send across boundaries
                nonisolated(unsafe) let safeSampleBuffer = sampleBuffer
                Task { @MainActor in
                    self?.handleEncodedFrame(safeSampleBuffer)
                }
            }

            guard status == noErr else {
                throw VideoEncoderError.encodingFailed(status)
            }

            isEncoding = true
        }

        /// Encode a CMSampleBuffer directly from SCStream
        public func encode(sampleBuffer: CMSampleBuffer) async throws {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                throw VideoEncoderError.invalidInput
            }

            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            try await encode(pixelBuffer: pixelBuffer, presentationTime: pts)
        }

        /// Force a key frame on the next encode
        public func requestKeyFrame() {
            guard let session = compressionSession else { return }
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
        }

        // MARK: - Adaptive Bitrate

        /// Adjust bitrate based on network conditions
        public func adjustBitrate(networkBandwidthBps: Int64) {
            // Use 80% of available bandwidth
            let newBitrate = max(500_000, min(Int(Double(networkBandwidthBps) * 0.8), Int(profile.bitrateMbps * 1_000_000)))

            guard abs(newBitrate - currentBitrate) > currentBitrate / 10 else { return }

            currentBitrate = newBitrate

            if let session = compressionSession {
                VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: currentBitrate as CFNumber)
            }
        }

        // MARK: - Cleanup

        /// Stop encoding and release resources
        public func stop() {
            if let session = compressionSession {
                VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
                VTCompressionSessionInvalidate(session)
                compressionSession = nil
            }
            isEncoding = false
        }

        // MARK: - Private

        private func handleEncodedFrame(_ sampleBuffer: CMSampleBuffer) {
            guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

            var totalLength: Int = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)

            guard let dataPointer, totalLength > 0 else { return }

            let data = Data(bytes: dataPointer, count: totalLength)

            let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]]
            let isKeyFrame = !(attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool ?? false)

            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            let frame = EncodedFrame(
                data: data,
                isKeyFrame: isKeyFrame,
                presentationTimestamp: CMTimeGetSeconds(pts),
                codec: codec == .h265 ? .h265 : .h264,
                width: width,
                height: height
            )

            encodedFrameCount += 1
            encodedBytesTotal += Int64(data.count)

            frameCallback?(frame)
        }

        private func encodeAsJPEG(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) async throws {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()

            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                throw VideoEncoderError.encodingFailed(0)
            }

            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            let quality: Float = profile == .bestQuality ? 0.9 : profile == .balanced ? 0.7 : 0.5
            guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: quality)]) else {
                throw VideoEncoderError.encodingFailed(0)
            }

            let frame = EncodedFrame(
                data: data,
                isKeyFrame: true,
                presentationTimestamp: CMTimeGetSeconds(presentationTime),
                codec: .jpeg,
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            )

            encodedFrameCount += 1
            encodedBytesTotal += Int64(data.count)
            isEncoding = true

            frameCallback?(frame)
        }
    }

#else

    /// Stub for non-macOS platforms
    @MainActor
    public class VideoEncoderService: ObservableObject {
        @Published public private(set) var isEncoding = false
        @Published public private(set) var codec: VideoCodec = .h264
        @Published public private(set) var profile: StreamQualityProfile = .balanced
        @Published public private(set) var encodedFrameCount: Int64 = 0
        @Published public private(set) var encodedBytesTotal: Int64 = 0

        public init() {}

        /// Configure the encoder with codec, profile, and dimensions.
        /// - Parameters:
        ///   - codec: The video codec to use.
        ///   - profile: The quality profile controlling bitrate and frame rate.
        ///   - width: Frame width in pixels.
        ///   - height: Frame height in pixels.
        /// - Throws: ``VideoEncoderError/notSupported`` unconditionally on non-macOS platforms.
        public func configure(codec _: VideoCodec, profile _: StreamQualityProfile, width _: Int, height _: Int) throws {
            throw VideoEncoderError.notSupported
        }

        /// Set callback for receiving encoded frames. No-op on non-macOS platforms.
        /// - Parameter callback: A closure invoked with each ``EncodedFrame`` after encoding.
        public func setFrameCallback(_: @escaping (EncodedFrame) -> Void) {}

        /// Force a key frame on the next encode. No-op on non-macOS platforms.
        public func requestKeyFrame() {}

        /// Adjust bitrate based on network conditions. No-op on non-macOS platforms.
        /// - Parameter networkBandwidthBps: The estimated network bandwidth in bits per second.
        public func adjustBitrate(networkBandwidthBps _: Int64) {}

        /// Stop encoding and release resources. No-op on non-macOS platforms.
        public func stop() {}
    }

#endif

// MARK: - Video Encoder Error

public enum VideoEncoderError: Error, LocalizedError, Sendable {
    case sessionCreationFailed(OSStatus)
    case notConfigured
    case encodingFailed(OSStatus)
    case invalidInput
    case notSupported

    public var errorDescription: String? {
        switch self {
        case let .sessionCreationFailed(status): "Failed to create compression session: \(status)"
        case .notConfigured: "Encoder not configured"
        case let .encodingFailed(status): "Encoding failed: \(status)"
        case .invalidInput: "Invalid input buffer"
        case .notSupported: "Video encoding not supported on this platform"
        }
    }
}
