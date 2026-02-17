//
//  ClipboardObserver.swift
//  Thea
//
//  Created by Thea
//

#if os(macOS)
    import AppKit
    import os.log

    /// Observes clipboard changes on macOS
    /// Maintains a history of clipboard items for context awareness
    @MainActor
    public final class ClipboardObserver {
        public static let shared = ClipboardObserver()

        private let logger = Logger(subsystem: "app.thea.clipboard", category: "ClipboardObserver")

        // Configuration — base 5s (was 0.5s); EnergyAdaptiveThrottler scales at runtime
        public var maxHistorySize: Int = 50
        public var pollingInterval: TimeInterval = 5.0

        // Callbacks
        public var onClipboardChanged: ((ClipboardItem) -> Void)?

        // State
        public private(set) var history: [ClipboardItem] = []
        private var lastChangeCount: Int = 0
        private var pollingTimer: Timer?

        private init() {}

        // MARK: - Lifecycle

        public func start() {
            lastChangeCount = NSPasteboard.general.changeCount

            // Poll for changes since NSPasteboard doesn't have proper notifications
            pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.checkForChanges()
                }
            }

            logger.info("Clipboard observer started")
        }

        public func stop() {
            pollingTimer?.invalidate()
            pollingTimer = nil
            logger.info("Clipboard observer stopped")
        }

        // MARK: - Clipboard Monitoring

        private func checkForChanges() {
            let pasteboard = NSPasteboard.general
            let currentChangeCount = pasteboard.changeCount

            guard currentChangeCount != lastChangeCount else { return }
            lastChangeCount = currentChangeCount

            // Extract clipboard content
            if let item = extractClipboardItem(from: pasteboard) {
                addToHistory(item)
                onClipboardChanged?(item)
                logger.debug("Clipboard changed: \(item.contentType.rawValue)")
            }
        }

        private func extractClipboardItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
            let types = pasteboard.types ?? []
            let source = getSourceApp()

            return extractText(from: pasteboard, types: types, source: source)
                ?? extractURL(from: pasteboard, types: types, source: source)
                ?? extractImage(from: pasteboard, types: types, source: source)
                ?? extractFiles(from: pasteboard, types: types, source: source)
                ?? extractRichText(from: pasteboard, types: types, source: source)
                ?? extractHTML(from: pasteboard, types: types, source: source)
        }

        private func extractText(from pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType], source: String?) -> ClipboardItem? {
            guard types.contains(.string), let text = pasteboard.string(forType: .string) else { return nil }
            if let url = URL(string: text), url.scheme != nil {
                return ClipboardItem(contentType: .url, textContent: text, url: url, imageData: nil, fileURLs: nil, sourceApp: source)
            }
            return ClipboardItem(contentType: .text, textContent: text, url: nil, imageData: nil, fileURLs: nil, sourceApp: source)
        }

        private func extractURL(from pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType], source: String?) -> ClipboardItem? {
            guard types.contains(.URL), let urlString = pasteboard.string(forType: .URL), let url = URL(string: urlString) else { return nil }
            return ClipboardItem(contentType: .url, textContent: urlString, url: url, imageData: nil, fileURLs: nil, sourceApp: source)
        }

        private func extractImage(from pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType], source: String?) -> ClipboardItem? {
            if types.contains(.tiff), let data = pasteboard.data(forType: .tiff) {
                return ClipboardItem(contentType: .image, textContent: nil, url: nil, imageData: data, fileURLs: nil, sourceApp: source)
            }
            if types.contains(.png), let data = pasteboard.data(forType: .png) {
                return ClipboardItem(contentType: .image, textContent: nil, url: nil, imageData: data, fileURLs: nil, sourceApp: source)
            }
            return nil
        }

        private func extractFiles(from pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType], source: String?) -> ClipboardItem? {
            guard types.contains(.fileURL),
                  let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty else { return nil }
            return ClipboardItem(contentType: .file, textContent: urls.map(\.lastPathComponent).joined(separator: ", "), url: nil, imageData: nil, fileURLs: urls, sourceApp: source)
        }

        private func extractRichText(from pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType], source: String?) -> ClipboardItem? {
            guard types.contains(.rtf), let rtfData = pasteboard.data(forType: .rtf),
                  let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) else { return nil }
            return ClipboardItem(contentType: .richText, textContent: attributedString.string, url: nil, imageData: nil, fileURLs: nil, sourceApp: source)
        }

        private func extractHTML(from pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType], source: String?) -> ClipboardItem? {
            guard types.contains(.html), let htmlData = pasteboard.data(forType: .html),
                  let htmlString = String(data: htmlData, encoding: .utf8) else { return nil }
            let stripped = htmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            return ClipboardItem(contentType: .html, textContent: stripped, url: nil, imageData: nil, fileURLs: nil, sourceApp: source)
        }

        private func getSourceApp() -> String? {
            // Try to get the frontmost app (likely the source)
            NSWorkspace.shared.frontmostApplication?.localizedName
        }

        // MARK: - History Management

        private func addToHistory(_ item: ClipboardItem) {
            // Avoid duplicates (same content type and content)
            if let lastItem = history.first,
               lastItem.contentType == item.contentType,
               lastItem.textContent == item.textContent
            {
                return
            }

            history.insert(item, at: 0)

            // Trim history if needed
            if history.count > maxHistorySize {
                history.removeLast()
            }
        }

        /// Clear clipboard history
        public func clearHistory() {
            history.removeAll()
            logger.info("Clipboard history cleared")
        }

        /// Get recent text items from history
        public func recentTextItems(limit: Int = 10) -> [String] {
            history
                .filter { $0.contentType == .text || $0.contentType == .richText }
                .prefix(limit)
                .compactMap(\.textContent)
        }

        /// Search history for matching items
        public func search(query: String) -> [ClipboardItem] {
            let lowercaseQuery = query.lowercased()
            return history.filter { item in
                if let text = item.textContent?.lowercased() {
                    return text.contains(lowercaseQuery)
                }
                return false
            }
        }
    }

    // MARK: - Models

    public struct ClipboardItem: Identifiable, Sendable, Equatable {
        public let id: UUID
        public let contentType: MacClipboardContentType
        public let textContent: String?
        public let url: URL?
        public let imageData: Data?
        public let fileURLs: [URL]?
        public let sourceApp: String?
        public let timestamp: Date

        init(
            contentType: MacClipboardContentType,
            textContent: String?,
            url: URL?,
            imageData: Data?,
            fileURLs: [URL]?,
            sourceApp: String?
        ) {
            id = UUID()
            self.contentType = contentType
            self.textContent = textContent
            self.url = url
            self.imageData = imageData
            self.fileURLs = fileURLs
            self.sourceApp = sourceApp
            timestamp = Date()
        }

        public var preview: String {
            switch contentType {
            case .text, .richText, .html:
                if let text = textContent {
                    return String(text.prefix(100))
                }
            case .url:
                return url?.absoluteString ?? textContent ?? "URL"
            case .image:
                return "Image"
            case .file:
                return fileURLs?.map(\.lastPathComponent).joined(separator: ", ") ?? "File"
            }
            return "Unknown"
        }
    }

    public enum MacClipboardContentType: String, Sendable {
        case text = "Text"
        case richText = "Rich Text"
        case html = "HTML"
        case url = "URL"
        case image = "Image"
        case file = "File"
    }
#endif
