//
//  ServicesHandler.swift
//  Thea
//
//  Created by Thea
//

#if os(macOS)
    import AppKit
    import os.log

    /// Handles macOS Services menu requests
    /// Registers as a service provider for text-based actions
    @MainActor
    public final class ServicesHandler: NSObject {
        public static let shared = ServicesHandler()

        private let logger = Logger(subsystem: "app.thea.services", category: "ServicesHandler")

        // Callbacks for service actions
        public var onAskAboutSelection: ((String) -> Void)?
        public var onSummarize: ((String) -> Void)?
        public var onTranslate: ((String) -> Void)?
        public var onAddToMemory: ((String, URL?) -> Void)?
        public var onExplainCode: ((String) -> Void)?

        override private init() {
            super.init()
        }

        // MARK: - Registration

        /// Register this object as a service provider
        public func register() {
            NSApp.servicesProvider = self
            NSUpdateDynamicServices()
            logger.info("Services handler registered")
        }

        // MARK: - Service Methods

        /// Ask Thea about the selected text
        @objc public func askTheaAboutSelection(
            _ pboard: NSPasteboard,
            userData _: String?,
            error: AutoreleasingUnsafeMutablePointer<NSString?>
        ) {
            guard let text = extractText(from: pboard) else {
                error.pointee = "Could not read text from selection" as NSString
                logger.error("Failed to extract text for Ask Thea service")
                return
            }

            logger.info("Ask Thea service invoked with \(text.count) characters")

            // Bring app to front
            NSApp.activate(ignoringOtherApps: true)

            // Invoke callback
            onAskAboutSelection?(text)
        }

        /// Summarize the selected text
        @objc public func summarizeWithThea(
            _ pboard: NSPasteboard,
            userData _: String?,
            error: AutoreleasingUnsafeMutablePointer<NSString?>
        ) {
            guard let text = extractText(from: pboard) else {
                error.pointee = "Could not read text from selection" as NSString
                logger.error("Failed to extract text for Summarize service")
                return
            }

            logger.info("Summarize service invoked with \(text.count) characters")

            NSApp.activate(ignoringOtherApps: true)
            onSummarize?(text)
        }

        /// Translate the selected text
        @objc public func translateWithThea(
            _ pboard: NSPasteboard,
            userData _: String?,
            error: AutoreleasingUnsafeMutablePointer<NSString?>
        ) {
            guard let text = extractText(from: pboard) else {
                error.pointee = "Could not read text from selection" as NSString
                logger.error("Failed to extract text for Translate service")
                return
            }

            logger.info("Translate service invoked with \(text.count) characters")

            NSApp.activate(ignoringOtherApps: true)
            onTranslate?(text)
        }

        /// Add selected content to Thea's memory
        @objc public func addToTheaMemory(
            _ pboard: NSPasteboard,
            userData _: String?,
            error: AutoreleasingUnsafeMutablePointer<NSString?>
        ) {
            let text = extractText(from: pboard)
            let url = extractURL(from: pboard)

            guard text != nil || url != nil else {
                error.pointee = "Could not read content from selection" as NSString
                logger.error("Failed to extract content for Add to Memory service")
                return
            }

            logger.info("Add to Memory service invoked")

            NSApp.activate(ignoringOtherApps: true)
            onAddToMemory?(text ?? "", url)
        }

        /// Explain selected code
        @objc public func explainCodeWithThea(
            _ pboard: NSPasteboard,
            userData _: String?,
            error: AutoreleasingUnsafeMutablePointer<NSString?>
        ) {
            guard let code = extractText(from: pboard) else {
                error.pointee = "Could not read code from selection" as NSString
                logger.error("Failed to extract code for Explain Code service")
                return
            }

            logger.info("Explain Code service invoked with \(code.count) characters")

            NSApp.activate(ignoringOtherApps: true)
            onExplainCode?(code)
        }

        // MARK: - Helpers

        private func extractText(from pboard: NSPasteboard) -> String? {
            // Try plain text first
            if let text = pboard.string(forType: .string), !text.isEmpty {
                return text
            }

            // Try RTF
            if let rtfData = pboard.data(forType: .rtf) {
                if let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                    let text = attributedString.string
                    if !text.isEmpty {
                        return text
                    }
                }
            }

            // Try HTML
            if let htmlData = pboard.data(forType: .html) {
                if let htmlString = String(data: htmlData, encoding: .utf8) {
                    // Strip HTML tags for plain text
                    let stripped = htmlString.replacingOccurrences(
                        of: "<[^>]+>",
                        with: "",
                        options: .regularExpression
                    )
                    if !stripped.isEmpty {
                        return stripped
                    }
                }
            }

            return nil
        }

        private func extractURL(from pboard: NSPasteboard) -> URL? {
            // Try URL type
            if let urlString = pboard.string(forType: .URL) {
                return URL(string: urlString)
            }

            // Try file URL
            if let urls = pboard.readObjects(forClasses: [NSURL.self]) as? [URL], let url = urls.first {
                return url
            }

            return nil
        }
    }

    // MARK: - Service Request Models

    public struct ServiceRequest: Sendable {
        public let type: TheaServiceType
        public let text: String
        public let url: URL?
        public let timestamp: Date

        public init(type: TheaServiceType, text: String, url: URL? = nil) {
            self.type = type
            self.text = text
            self.url = url
            timestamp = Date()
        }
    }

    public enum TheaServiceType: String, Sendable {
        case ask
        case summarize
        case translate
        case addToMemory
        case explainCode
    }
#endif
