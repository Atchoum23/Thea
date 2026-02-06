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

        // Configuration
        public var maxHistorySize: Int = 50
        public var pollingInterval: TimeInterval = 0.5

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

            // Check for text
            if types.contains(.string), let text = pasteboard.string(forType: .string) {
                // Check if it's a URL
                if let url = URL(string: text), url.scheme != nil {
                    return ClipboardItem(
                        contentType: .url,
                        textContent: text,
                        url: url,
                        imageData: nil,
                        fileURLs: nil,
                        sourceApp: getSourceApp()
                    )
                }

                return ClipboardItem(
                    contentType: .text,
                    textContent: text,
                    url: nil,
                    imageData: nil,
                    fileURLs: nil,
                    sourceApp: getSourceApp()
                )
            }

            // Check for URL
            if types.contains(.URL), let urlString = pasteboard.string(forType: .URL),
               let url = URL(string: urlString)
            {
                return ClipboardItem(
                    contentType: .url,
                    textContent: urlString,
                    url: url,
                    imageData: nil,
                    fileURLs: nil,
                    sourceApp: getSourceApp()
                )
            }

            // Check for image
            if types.contains(.tiff), let imageData = pasteboard.data(forType: .tiff) {
                return ClipboardItem(
                    contentType: .image,
                    textContent: nil,
                    url: nil,
                    imageData: imageData,
                    fileURLs: nil,
                    sourceApp: getSourceApp()
                )
            }

            if types.contains(.png), let imageData = pasteboard.data(forType: .png) {
                return ClipboardItem(
                    contentType: .image,
                    textContent: nil,
                    url: nil,
                    imageData: imageData,
                    fileURLs: nil,
                    sourceApp: getSourceApp()
                )
            }

            // Check for files
            if types.contains(.fileURL),
               let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty
            {
                return ClipboardItem(
                    contentType: .file,
                    textContent: urls.map(\.lastPathComponent).joined(separator: ", "),
                    url: nil,
                    imageData: nil,
                    fileURLs: urls,
                    sourceApp: getSourceApp()
                )
            }

            // Check for RTF
            if types.contains(.rtf), let rtfData = pasteboard.data(forType: .rtf) {
                if let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                    return ClipboardItem(
                        contentType: .richText,
                        textContent: attributedString.string,
                        url: nil,
                        imageData: nil,
                        fileURLs: nil,
                        sourceApp: getSourceApp()
                    )
                }
            }

            // Check for HTML
            if types.contains(.html), let htmlData = pasteboard.data(forType: .html) {
                if let htmlString = String(data: htmlData, encoding: .utf8) {
                    // Strip HTML for preview
                    let stripped = htmlString.replacingOccurrences(
                        of: "<[^>]+>",
                        with: "",
                        options: .regularExpression
                    )
                    return ClipboardItem(
                        contentType: .html,
                        textContent: stripped,
                        url: nil,
                        imageData: nil,
                        fileURLs: nil,
                        sourceApp: getSourceApp()
                    )
                }
            }

            return nil
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
