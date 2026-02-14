//
//  RemoteScreenMessages.swift
//  Thea
//
//  Screen sharing message types for remote server protocol
//

import CoreGraphics
import Foundation

// MARK: - Screen Messages

public enum ScreenRequest: Codable, Sendable {
    case captureFullScreen(quality: Float, scale: Float)
    case captureWindow(windowId: Int, quality: Float)
    case captureRegion(x: Int, y: Int, width: Int, height: Int, quality: Float)
    case startStream(fps: Int, quality: Float, scale: Float)
    case stopStream
    case getDisplayInfo
    case getWindowList
    // Multi-monitor support
    case captureDisplay(displayId: Int, quality: Float, scale: Float)
    case startStreamForDisplay(displayId: Int, fps: Int, quality: Float, scale: Float)
    // Video codec configuration
    case configureStream(codec: VideoCodec, profile: StreamQualityProfile)
}

public enum ScreenResponse: Codable, Sendable {
    case frame(ScreenFrame)
    case displayInfo(DisplayInfo)
    case windowList([RemoteWindowInfo])
    case streamStarted(streamId: String)
    case streamStopped
    case error(String)
}

public struct ScreenFrame: Codable, Sendable {
    public let timestamp: Date
    public let width: Int
    public let height: Int
    public let format: ImageFormat
    public let data: Data
    public let isKeyFrame: Bool
    public let cursorPosition: CGPoint?
    public let cursorVisible: Bool

    public enum ImageFormat: String, Codable, Sendable {
        case jpeg
        case png
        case heic
        case h264
        case h265
    }

    public init(timestamp: Date = Date(), width: Int, height: Int, format: ImageFormat, data: Data, isKeyFrame: Bool = true, cursorPosition: CGPoint? = nil, cursorVisible: Bool = true) {
        self.timestamp = timestamp
        self.width = width
        self.height = height
        self.format = format
        self.data = data
        self.isKeyFrame = isKeyFrame
        self.cursorPosition = cursorPosition
        self.cursorVisible = cursorVisible
    }
}

public struct DisplayInfo: Codable, Sendable {
    public let displays: [DisplayDetails]

    public struct DisplayDetails: Codable, Sendable {
        public let id: Int
        public let name: String
        public let width: Int
        public let height: Int
        public let scaleFactor: Double
        public let isMain: Bool
        public let frame: CGRect
    }
}

public struct RemoteWindowInfo: Codable, Sendable {
    public let id: Int
    public let title: String
    public let ownerName: String
    public let ownerPID: Int
    public let frame: CGRect
    public let isOnScreen: Bool
    public let layer: Int

    public init(id: Int, title: String, ownerName: String, ownerPID: Int, frame: CGRect, isOnScreen: Bool, layer: Int) {
        self.id = id
        self.title = title
        self.ownerName = ownerName
        self.ownerPID = ownerPID
        self.frame = frame
        self.isOnScreen = isOnScreen
        self.layer = layer
    }
}
