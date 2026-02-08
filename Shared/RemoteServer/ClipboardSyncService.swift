//
//  ClipboardSyncService.swift
//  Thea
//
//  Bidirectional clipboard synchronization for remote desktop sessions
//

import Combine
import Foundation
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

// MARK: - Clipboard Sync Service

/// Manages bidirectional clipboard synchronization between local and remote machines
@MainActor
public class ClipboardSyncService: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var isSyncing = false
    @Published public private(set) var lastSyncTime: Date?
    @Published public private(set) var syncCount: Int64 = 0

    // MARK: - Configuration

    public var syncInterval: TimeInterval = 0.5
    public var maxClipboardSize: Int = 10_485_760 // 10MB
    public var syncImages = true
    public var syncFiles = false

    // MARK: - Callbacks

    public var onClipboardChanged: ((ClipboardData) -> Void)?
    public var onRemoteClipboardReceived: ((ClipboardData) -> Void)?

    // MARK: - Internal State

    #if os(macOS)
        private var lastChangeCount: Int = 0
    #endif
    private var monitorTask: Task<Void, Never>?
    private var lastLocalHash: Int = 0

    // MARK: - Initialization

    public init() {}

    // MARK: - Start / Stop

    /// Start monitoring local clipboard for changes
    public func startSync() {
        guard !isSyncing else { return }
        isSyncing = true

        #if os(macOS)
            lastChangeCount = NSPasteboard.general.changeCount
        #endif

        monitorTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(syncInterval * 1_000_000_000))
                await MainActor.run {
                    self.checkForClipboardChanges()
                }
            }
        }
    }

    /// Stop clipboard monitoring
    public func stopSync() {
        monitorTask?.cancel()
        monitorTask = nil
        isSyncing = false
    }

    // MARK: - Get Current Clipboard

    /// Get current clipboard contents as ClipboardData
    public func getCurrentClipboard() -> ClipboardData? {
        #if os(macOS)
            let pasteboard = NSPasteboard.general

            // Check for text
            if let text = pasteboard.string(forType: .string) {
                return ClipboardData(
                    type: .text,
                    data: Data(text.utf8)
                )
            }

            // Check for RTF
            if let rtfData = pasteboard.data(forType: .rtf) {
                return ClipboardData(
                    type: .rtf,
                    data: rtfData,
                    uti: "public.rtf"
                )
            }

            // Check for image
            if syncImages, let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
                guard imageData.count <= maxClipboardSize else { return nil }
                let uti = pasteboard.data(forType: .png) != nil ? "public.png" : "public.tiff"
                return ClipboardData(
                    type: .image,
                    data: imageData,
                    uti: uti
                )
            }

            return nil
        #else
            let pasteboard = UIPasteboard.general

            if let text = pasteboard.string {
                return ClipboardData(
                    type: .text,
                    data: Data(text.utf8)
                )
            }

            if syncImages, let image = pasteboard.image, let data = image.pngData() {
                guard data.count <= maxClipboardSize else { return nil }
                return ClipboardData(
                    type: .image,
                    data: data,
                    uti: "public.png"
                )
            }

            return nil
        #endif
    }

    // MARK: - Apply Remote Clipboard

    /// Apply clipboard data received from remote machine
    public func applyRemoteClipboard(_ clipboardData: ClipboardData) {
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            switch clipboardData.type {
            case .text:
                if let text = String(data: clipboardData.data, encoding: .utf8) {
                    pasteboard.setString(text, forType: .string)
                }

            case .image:
                let type: NSPasteboard.PasteboardType = clipboardData.uti == "public.png" ? .png : .tiff
                pasteboard.setData(clipboardData.data, forType: type)

            case .rtf:
                pasteboard.setData(clipboardData.data, forType: .rtf)

            case .fileReference:
                if let path = String(data: clipboardData.data, encoding: .utf8) {
                    pasteboard.setString(path, forType: .fileURL)
                }
            }

            // Update tracking to avoid echo
            lastChangeCount = pasteboard.changeCount
            lastLocalHash = clipboardData.data.hashValue
        #else
            let pasteboard = UIPasteboard.general

            switch clipboardData.type {
            case .text:
                if let text = String(data: clipboardData.data, encoding: .utf8) {
                    pasteboard.string = text
                }

            case .image:
                if let image = UIImage(data: clipboardData.data) {
                    pasteboard.image = image
                }

            case .rtf, .fileReference:
                break
            }
        #endif

        lastSyncTime = Date()
        syncCount += 1
        onRemoteClipboardReceived?(clipboardData)
    }

    // MARK: - Private

    private func checkForClipboardChanges() {
        #if os(macOS)
            let currentCount = NSPasteboard.general.changeCount
            guard currentCount != lastChangeCount else { return }
            lastChangeCount = currentCount
        #endif

        guard let clipboardData = getCurrentClipboard() else { return }

        // Avoid sending back what we just received
        let currentHash = clipboardData.data.hashValue
        guard currentHash != lastLocalHash else { return }
        lastLocalHash = currentHash

        lastSyncTime = Date()
        syncCount += 1
        onClipboardChanged?(clipboardData)
    }
}
