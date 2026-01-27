import Foundation
import os.log
#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif

// MARK: - Clipboard Context Provider

/// Provides context about clipboard content
public actor ClipboardContextProvider: ContextProvider {
    public let providerId = "clipboard"
    public let displayName = "Clipboard"

    private let logger = Logger(subsystem: "app.thea", category: "ClipboardProvider")

    private var state: ContextProviderState = .idle
    private var continuation: AsyncStream<ContextUpdate>.Continuation?
    private var _updates: AsyncStream<ContextUpdate>?
    private var updateTask: Task<Void, Never>?

    // Track clipboard changes
    #if os(macOS)
        private var lastChangeCount: Int = 0
    #endif

    // Clipboard history (privacy-conscious - only metadata)
    private var clipboardHistory: [ClipboardHistoryEntry] = []
    private let maxHistoryCount = 20

    private struct ClipboardHistoryEntry: Sendable {
        let timestamp: Date
        let contentType: ClipboardContext.ClipboardContentType
        let preview: String?
        let size: Int
    }

    public var isActive: Bool { state == .running }

    public var updates: AsyncStream<ContextUpdate> {
        if let existing = _updates {
            return existing
        }
        let (stream, cont) = AsyncStream<ContextUpdate>.makeStream()
        _updates = stream
        continuation = cont
        return stream
    }

    public init() {}

    public func start() async throws {
        guard state != .running else {
            throw ContextProviderError.alreadyRunning
        }

        state = .starting

        #if os(macOS)
            lastChangeCount = await MainActor.run { NSPasteboard.general.changeCount }
        #endif

        // Start polling for clipboard changes
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkClipboard()
                try? await Task.sleep(for: .seconds(1))
            }
        }

        state = .running
        logger.info("Clipboard provider started")
    }

    public func stop() async {
        guard state == .running else { return }

        state = .stopping
        updateTask?.cancel()
        updateTask = nil

        continuation?.finish()
        continuation = nil
        _updates = nil

        state = .stopped
        logger.info("Clipboard provider stopped")
    }

    public func getCurrentContext() async -> ContextUpdate? {
        let context = await buildClipboardContext()
        return ContextUpdate(
            providerId: providerId,
            updateType: .clipboard(context),
            priority: .low
        )
    }

    // MARK: - Private Methods

    private func checkClipboard() async {
        #if os(macOS)
            await checkMacOSClipboard()
        #elseif os(iOS)
            await checkIOSClipboard()
        #endif
    }

    #if os(macOS)
        private func checkMacOSClipboard() async {
            // Get current change count on MainActor
            let currentCount = await MainActor.run { NSPasteboard.general.changeCount }

            guard currentCount != lastChangeCount else { return }
            lastChangeCount = currentCount

            // Build context on MainActor
            let context = await MainActor.run { buildMacOSClipboardContext() }

            // Add to history
            if let entry = createHistoryEntry(from: context) {
                addToHistory(entry)
            }

            let update = ContextUpdate(
                providerId: providerId,
                updateType: .clipboard(context),
                priority: .low
            )
            continuation?.yield(update)
        }

        @MainActor
        private func buildMacOSClipboardContext() -> ClipboardContext {
            let pasteboard = NSPasteboard.general
            let types = pasteboard.types ?? []

            var contentType: ClipboardContext.ClipboardContentType?
            var textPreview: String?
            var contentSize: Int?

            if types.contains(.URL) || types.contains(.fileURL) {
                contentType = .url
                if let url = pasteboard.string(forType: .URL) ?? pasteboard.string(forType: .string) {
                    textPreview = String(url.prefix(100))
                    contentSize = url.utf8.count
                }
            } else if types.contains(.html) {
                contentType = .html
                if let html = pasteboard.string(forType: .html) {
                    textPreview = String(html.prefix(100))
                    contentSize = html.utf8.count
                }
            } else if types.contains(.rtf) {
                contentType = .richText
                if let rtf = pasteboard.data(forType: .rtf) {
                    contentSize = rtf.count
                    textPreview = "[Rich Text]"
                }
            } else if types.contains(.string) {
                contentType = .text
                if let text = pasteboard.string(forType: .string) {
                    textPreview = String(text.prefix(100))
                    contentSize = text.utf8.count
                }
            } else if types.contains(.tiff) || types.contains(.png) {
                contentType = .image
                if let data = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
                    contentSize = data.count
                    textPreview = "[Image]"
                }
            } else if types.contains(.fileContents) || types.contains(NSPasteboard.PasteboardType("public.file-url")) {
                contentType = .file
                textPreview = "[File]"
            }

            return ClipboardContext(
                hasContent: !types.isEmpty,
                contentType: contentType,
                textPreview: textPreview,
                contentSize: contentSize,
                lastCopiedDate: Date()
            )
        }
    #endif

    #if os(iOS)
        private func checkIOSClipboard() async {
            // Build context on MainActor
            let context = await MainActor.run { buildIOSClipboardContext() }

            let update = ContextUpdate(
                providerId: providerId,
                updateType: .clipboard(context),
                priority: .low
            )
            continuation?.yield(update)
        }

        @MainActor
        private func buildIOSClipboardContext() -> ClipboardContext {
            let pasteboard = UIPasteboard.general

            var contentType: ClipboardContext.ClipboardContentType?
            var textPreview: String?
            var contentSize: Int?

            if pasteboard.hasURLs {
                contentType = .url
                if let url = pasteboard.url {
                    textPreview = url.absoluteString.prefix(100).description
                    contentSize = url.absoluteString.utf8.count
                }
            } else if pasteboard.hasStrings {
                contentType = .text
                if let text = pasteboard.string {
                    textPreview = String(text.prefix(100))
                    contentSize = text.utf8.count
                }
            } else if pasteboard.hasImages {
                contentType = .image
                textPreview = "[Image]"
            }

            return ClipboardContext(
                hasContent: pasteboard.hasStrings || pasteboard.hasURLs || pasteboard.hasImages,
                contentType: contentType,
                textPreview: textPreview,
                contentSize: contentSize,
                lastCopiedDate: Date()
            )
        }
    #endif

    private func buildClipboardContext() async -> ClipboardContext {
        #if os(macOS)
            return await MainActor.run { buildMacOSClipboardContext() }
        #elseif os(iOS)
            return await MainActor.run { buildIOSClipboardContext() }
        #else
            return ClipboardContext()
        #endif
    }

    private func createHistoryEntry(from context: ClipboardContext) -> ClipboardHistoryEntry? {
        guard context.hasContent, let contentType = context.contentType else { return nil }

        return ClipboardHistoryEntry(
            timestamp: Date(),
            contentType: contentType,
            preview: context.textPreview,
            size: context.contentSize ?? 0
        )
    }

    private func addToHistory(_ entry: ClipboardHistoryEntry) {
        clipboardHistory.insert(entry, at: 0)
        if clipboardHistory.count > maxHistoryCount {
            clipboardHistory = Array(clipboardHistory.prefix(maxHistoryCount))
        }
    }

    /// Get clipboard history (metadata only, not content)
    public func getHistory() -> [(timestamp: Date, type: ClipboardContext.ClipboardContentType, preview: String?)] {
        clipboardHistory.map { ($0.timestamp, $0.contentType, $0.preview) }
    }
}
