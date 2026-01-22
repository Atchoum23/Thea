//
//  RemoteScreenService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
import Combine
#if os(macOS)
import AppKit
import ScreenCaptureKit
import CoreMedia
#else
import UIKit
#endif

// MARK: - Remote Screen Service

/// Provides screen sharing capabilities for remote access
@MainActor
public class RemoteScreenService: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isStreaming = false
    @Published public private(set) var activeStreamId: String?
    @Published public private(set) var frameRate: Double = 0
    @Published public private(set) var bandwidth: Int64 = 0

    // MARK: - Stream Configuration

    private var streamConfiguration: StreamConfiguration?
    private var frameCallback: ((ScreenFrame) -> Void)?
    private var streamTask: Task<Void, Never>?

    #if os(macOS)
    private var captureStream: SCStream?
    private var streamOutput: ScreenCaptureOutput?
    #endif

    // MARK: - Initialization

    public init() {}

    // MARK: - Request Handling

    public func handleRequest(_ request: ScreenRequest) async throws -> ScreenResponse {
        switch request {
        case .captureFullScreen(let quality, let scale):
            return try await captureFullScreen(quality: quality, scale: scale)

        case .captureWindow(let windowId, let quality):
            return try await captureWindow(windowId: windowId, quality: quality)

        case .captureRegion(let x, let y, let width, let height, let quality):
            return try await captureRegion(x: x, y: y, width: width, height: height, quality: quality)

        case .startStream(let fps, let quality, let scale):
            return try await startStream(fps: fps, quality: quality, scale: scale)

        case .stopStream:
            return await stopStream()

        case .getDisplayInfo:
            return try await getDisplayInfo()

        case .getWindowList:
            return try await getWindowList()
        }
    }

    // MARK: - Full Screen Capture

    private func captureFullScreen(quality: Float, scale: Float) async throws -> ScreenResponse {
        #if os(macOS)
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            return .error("Screen recording permission required")
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            return .error("No display available")
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.width = Int(CGFloat(display.width) * CGFloat(scale))
        config.height = Int(CGFloat(display.height) * CGFloat(scale))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.scalesToFit = true

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        let data = try encodeImage(image, quality: quality)

        let cursorPos = NSEvent.mouseLocation
        let screenHeight = CGFloat(display.height)

        return .frame(ScreenFrame(
            width: config.width,
            height: config.height,
            format: .jpeg,
            data: data,
            cursorPosition: CGPoint(x: cursorPos.x, y: screenHeight - cursorPos.y),
            cursorVisible: true
        ))
        #else
        return .error("Screen capture not available on this platform")
        #endif
    }

    // MARK: - Window Capture

    private func captureWindow(windowId: Int, quality: Float) async throws -> ScreenResponse {
        #if os(macOS)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let window = content.windows.first(where: { Int($0.windowID) == windowId }) else {
            return .error("Window not found")
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)

        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        let data = try encodeImage(image, quality: quality)

        return .frame(ScreenFrame(
            width: config.width,
            height: config.height,
            format: .jpeg,
            data: data
        ))
        #else
        return .error("Window capture not available on this platform")
        #endif
    }

    // MARK: - Region Capture

    private func captureRegion(x: Int, y: Int, width: Int, height: Int, quality: Float) async throws -> ScreenResponse {
        #if os(macOS)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            return .error("No display available")
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.sourceRect = CGRect(x: x, y: y, width: width, height: height)
        config.width = width
        config.height = height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        let data = try encodeImage(image, quality: quality)

        return .frame(ScreenFrame(
            width: width,
            height: height,
            format: .jpeg,
            data: data
        ))
        #else
        return .error("Region capture not available on this platform")
        #endif
    }

    // MARK: - Streaming

    private func startStream(fps: Int, quality: Float, scale: Float) async throws -> ScreenResponse {
        guard !isStreaming else {
            return .error("Stream already active")
        }

        #if os(macOS)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            return .error("No display available")
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.width = Int(CGFloat(display.width) * CGFloat(scale))
        config.height = Int(CGFloat(display.height) * CGFloat(scale))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.scalesToFit = true
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))

        streamConfiguration = StreamConfiguration(
            fps: fps,
            quality: quality,
            scale: scale,
            width: config.width,
            height: config.height
        )

        let streamId = UUID().uuidString
        activeStreamId = streamId
        isStreaming = true

        // Start frame capture loop
        streamTask = Task {
            await self.streamCaptureLoop(display: display, filter: filter, config: config, fps: fps, quality: quality)
        }

        return .streamStarted(streamId: streamId)
        #else
        return .error("Streaming not available on this platform")
        #endif
    }

    #if os(macOS)
    private func streamCaptureLoop(display: SCDisplay, filter: SCContentFilter, config: SCStreamConfiguration, fps: Int, quality: Float) async {
        let frameInterval = 1.0 / Double(fps)

        while isStreaming && !Task.isCancelled {
            do {
                let startTime = Date()

                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                let data = try encodeImage(image, quality: quality)

                let cursorPos = await MainActor.run { NSEvent.mouseLocation }
                let screenHeight = CGFloat(display.height)

                let frame = ScreenFrame(
                    width: config.width,
                    height: config.height,
                    format: .jpeg,
                    data: data,
                    cursorPosition: CGPoint(x: cursorPos.x, y: screenHeight - cursorPos.y),
                    cursorVisible: true
                )

                await MainActor.run {
                    self.frameCallback?(frame)
                    self.bandwidth = Int64(data.count)
                }

                let elapsed = Date().timeIntervalSince(startTime)
                let sleepTime = max(0, frameInterval - elapsed)
                if sleepTime > 0 {
                    try await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                }

                await MainActor.run {
                    self.frameRate = 1.0 / Date().timeIntervalSince(startTime)
                }

            } catch {
                if !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms retry delay
                }
            }
        }
    }
    #endif

    private func stopStream() async -> ScreenResponse {
        streamTask?.cancel()
        streamTask = nil

        isStreaming = false
        activeStreamId = nil
        frameRate = 0
        bandwidth = 0
        streamConfiguration = nil

        #if os(macOS)
        try? captureStream?.stopCapture()
        captureStream = nil
        streamOutput = nil
        #endif

        return .streamStopped
    }

    /// Set callback for receiving stream frames
    public func setFrameCallback(_ callback: @escaping (ScreenFrame) -> Void) {
        self.frameCallback = callback
    }

    // MARK: - Display Information

    private func getDisplayInfo() async throws -> ScreenResponse {
        #if os(macOS)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        let displays = content.displays.enumerated().map { index, display in
            DisplayInfo.DisplayDetails(
                id: Int(display.displayID),
                name: "Display \(index + 1)",
                width: display.width,
                height: display.height,
                scaleFactor: 1.0, // Would need to query NSScreen for actual scale
                isMain: index == 0,
                frame: display.frame
            )
        }

        return .displayInfo(DisplayInfo(displays: displays))
        #else
        let screen = UIScreen.main
        let display = DisplayInfo.DisplayDetails(
            id: 0,
            name: "Main Display",
            width: Int(screen.bounds.width * screen.scale),
            height: Int(screen.bounds.height * screen.scale),
            scaleFactor: screen.scale,
            isMain: true,
            frame: screen.bounds
        )
        return .displayInfo(DisplayInfo(displays: [display]))
        #endif
    }

    // MARK: - Window List

    private func getWindowList() async throws -> ScreenResponse {
        #if os(macOS)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        let windows = content.windows.compactMap { window -> WindowInfo? in
            guard let title = window.title, !title.isEmpty else { return nil }

            return WindowInfo(
                id: Int(window.windowID),
                title: title,
                ownerName: window.owningApplication?.applicationName ?? "Unknown",
                ownerPID: Int(window.owningApplication?.processID ?? 0),
                frame: window.frame,
                isOnScreen: window.isOnScreen,
                layer: Int(window.windowLayer)
            )
        }

        return .windowList(windows)
        #else
        return .windowList([])
        #endif
    }

    // MARK: - Image Encoding

    #if os(macOS)
    private func encodeImage(_ image: CGImage, quality: Float) throws -> Data {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: quality)]) else {
            throw RemoteScreenError.encodingFailed
        }
        return data
    }
    #endif

    // MARK: - Types

    private struct StreamConfiguration {
        let fps: Int
        let quality: Float
        let scale: Float
        let width: Int
        let height: Int
    }
}

// MARK: - Screen Capture Output

#if os(macOS)
private class ScreenCaptureOutput: NSObject, SCStreamOutput {
    var frameHandler: ((CMSampleBuffer) -> Void)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        frameHandler?(sampleBuffer)
    }
}
#endif

// MARK: - Remote Screen Error

public enum RemoteScreenError: Error, LocalizedError, Sendable {
    case permissionDenied
    case displayNotFound
    case windowNotFound
    case captureFailedError
    case encodingFailed
    case streamNotActive

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Screen recording permission denied"
        case .displayNotFound: return "Display not found"
        case .windowNotFound: return "Window not found"
        case .captureFailedError: return "Screen capture failed"
        case .encodingFailed: return "Image encoding failed"
        case .streamNotActive: return "No active stream"
        }
    }
}
