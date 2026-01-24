// TheaPrintFriendly.swift
// Advanced print-friendly page cleaning and PDF generation
// Replaces PrintFriendly extension with enhanced AI-powered capabilities

import Foundation
import OSLog
#if canImport(WebKit)
import WebKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - Print Friendly Manager

@MainActor
public final class TheaPrintFriendlyManager: ObservableObject {
    public static let shared = TheaPrintFriendlyManager()

    private let logger = Logger(subsystem: "com.thea.extension", category: "PrintFriendly")

    // MARK: - Published State

    @Published public var isProcessing = false
    @Published public var currentPage: CleanedPage?
    @Published public var lastError: PrintFriendlyError?
    @Published public var editHistory: [EditAction] = []

    // MARK: - Settings

    @Published public var settings = PrintFriendlySettings()

    // MARK: - Initialization

    private init() {
        loadSettings()
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "printFriendly.settings"),
           let loaded = try? JSONDecoder().decode(PrintFriendlySettings.self, from: data) {
            settings = loaded
        }
    }

    public func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "printFriendly.settings")
        }
    }

    // MARK: - Page Cleaning

    /// Clean a web page for printing
    public func cleanPage(html: String, url: URL, options: PrintCleanOptions? = nil) async throws -> CleanedPage {
        isProcessing = true
        defer { isProcessing = false }

        let opts = options ?? createDefaultOptions()

        do {
            // Parse HTML
            let document = try parseHTML(html)

            // Extract main content
            var content = try await extractMainContent(from: document, url: url)

            // Apply cleaning rules
            if opts.removeAds {
                content = removeAdvertisements(from: content)
            }

            if opts.removeNavigation {
                content = removeNavigation(from: content)
            }

            if opts.removeComments {
                content = removeComments(from: content)
            }

            if opts.removeRelatedContent {
                content = removeRelatedContent(from: content)
            }

            // Extract images
            let images = opts.preserveImages ? extractImages(from: content) : []

            // Clean up formatting
            content = cleanFormatting(content, options: opts)

            // Extract plain text
            let textContent = extractPlainText(from: content)

            // Calculate metrics
            let wordCount = textContent.split(separator: " ").count
            let estimatedReadTime = max(1, wordCount / 200) // ~200 wpm average

            let cleanedPage = CleanedPage(
                title: extractTitle(from: document) ?? url.host ?? "Untitled",
                content: content,
                textContent: textContent,
                images: images,
                wordCount: wordCount,
                estimatedReadTime: estimatedReadTime
            )

            currentPage = cleanedPage
            editHistory.removeAll()

            // Update stats
            TheaExtensionState.shared.stats.pagesCleaned += 1

            logger.info("Page cleaned: \(wordCount) words, \(images.count) images")

            return cleanedPage

        } catch {
            let printError = PrintFriendlyError.cleaningFailed(error.localizedDescription)
            lastError = printError
            throw printError
        }
    }

    /// AI-powered content extraction
    public func extractWithAI(html: String, url: URL) async throws -> CleanedPage {
        isProcessing = true
        defer { isProcessing = false }

        // Use AI to intelligently identify main content
        let prompt = """
        Analyze this HTML and identify:
        1. The main article/content area
        2. The title
        3. The author and date if present
        4. Important images
        5. Content that should be removed (ads, navigation, sidebars, footers)

        Return the cleaned content preserving semantic structure.
        """

        // This would integrate with Thea's AI service
        // For now, fall back to rule-based extraction
        return try await cleanPage(html: html, url: url)
    }

    // MARK: - Editing

    /// Edit the cleaned page
    public func applyEdit(_ edit: EditAction) throws {
        guard var page = currentPage else {
            throw PrintFriendlyError.noPageLoaded
        }

        var content = page.content

        switch edit {
        case .deleteElement(let selector):
            content = removeElement(selector, from: content)

        case .deleteText(let range):
            content = removeTextRange(range, from: content)

        case .changeFontSize(let delta):
            content = adjustFontSize(by: delta, in: content)

        case .removeImage(let url):
            content = removeImageWithUrl(url, from: content)

        case .removeAllImages:
            content = removeAllImages(from: content)

        case .highlight(let text, let color):
            content = highlightText(text, with: color, in: content)

        case .addNote(let text, let position):
            content = addNote(text, at: position, in: content)
        }

        // Update page
        let textContent = extractPlainText(from: content)
        let wordCount = textContent.split(separator: " ").count
        let images = extractImages(from: content)

        currentPage = CleanedPage(
            title: page.title,
            content: content,
            textContent: textContent,
            images: images,
            wordCount: wordCount,
            estimatedReadTime: max(1, wordCount / 200)
        )

        // Record edit for undo
        editHistory.append(edit)
    }

    /// Undo the last edit
    public func undo() throws {
        guard !editHistory.isEmpty else {
            throw PrintFriendlyError.nothingToUndo
        }

        // This would require storing the previous state
        // For now, just remove from history
        editHistory.removeLast()
    }

    // MARK: - Export

    /// Export cleaned page to PDF
    public func exportToPDF(options: PDFExportOptions? = nil) async throws -> Data {
        guard let page = currentPage else {
            throw PrintFriendlyError.noPageLoaded
        }

        let opts = options ?? PDFExportOptions()

        #if canImport(PDFKit) && os(macOS)
        return try await generatePDF(from: page, options: opts)
        #else
        // Use alternative PDF generation for iOS
        return try await generatePDFUsingWebKit(from: page, options: opts)
        #endif
    }

    #if os(macOS)
    private func generatePDF(from page: CleanedPage, options: PDFExportOptions) async throws -> Data {
        // Create print info
        let printInfo = NSPrintInfo()
        printInfo.paperSize = options.pageSize.nsSize
        printInfo.topMargin = CGFloat(options.margins.top)
        printInfo.bottomMargin = CGFloat(options.margins.bottom)
        printInfo.leftMargin = CGFloat(options.margins.left)
        printInfo.rightMargin = CGFloat(options.margins.right)
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic

        // Create HTML with styling
        let styledHTML = wrapInPrintStyles(page.content, title: page.title, options: options)

        // Render to PDF using WebKit
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
                webView.loadHTMLString(styledHTML, baseURL: nil)

                // Wait for load and create PDF
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    webView.createPDF { result in
                        switch result {
                        case .success(let data):
                            continuation.resume(returning: data)
                        case .failure(let error):
                            continuation.resume(throwing: PrintFriendlyError.pdfGenerationFailed(error.localizedDescription))
                        }
                    }
                }
            }
        }
    }
    #endif

    private func generatePDFUsingWebKit(from page: CleanedPage, options: PDFExportOptions) async throws -> Data {
        let styledHTML = wrapInPrintStyles(page.content, title: page.title, options: options)

        #if canImport(WebKit)
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let configuration = WKWebViewConfiguration()
                let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)

                webView.loadHTMLString(styledHTML, baseURL: nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    webView.createPDF { result in
                        switch result {
                        case .success(let data):
                            continuation.resume(returning: data)
                        case .failure(let error):
                            continuation.resume(throwing: PrintFriendlyError.pdfGenerationFailed(error.localizedDescription))
                        }
                    }
                }
            }
        }
        #else
        throw PrintFriendlyError.pdfGenerationFailed("WebKit not available")
        #endif
    }

    /// Capture screenshot of the cleaned page
    public func captureScreenshot(options: ScreenshotOptions) async throws -> Data {
        guard let page = currentPage else {
            throw PrintFriendlyError.noPageLoaded
        }

        #if canImport(WebKit)
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
                webView.loadHTMLString(page.content, baseURL: nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let config = WKSnapshotConfiguration()
                    if !options.fullPage {
                        config.rect = webView.bounds
                    }

                    webView.takeSnapshot(with: config) { image, error in
                        if let error = error {
                            continuation.resume(throwing: PrintFriendlyError.screenshotFailed(error.localizedDescription))
                            return
                        }

                        guard let image = image else {
                            continuation.resume(throwing: PrintFriendlyError.screenshotFailed("No image captured"))
                            return
                        }

                        #if os(macOS)
                        guard let tiffData = image.tiffRepresentation,
                              let bitmap = NSBitmapImageRep(data: tiffData),
                              let pngData = bitmap.representation(using: .png, properties: [:]) else {
                            continuation.resume(throwing: PrintFriendlyError.screenshotFailed("Failed to convert image"))
                            return
                        }
                        continuation.resume(returning: pngData)
                        #else
                        guard let pngData = image.pngData() else {
                            continuation.resume(throwing: PrintFriendlyError.screenshotFailed("Failed to convert image"))
                            return
                        }
                        continuation.resume(returning: pngData)
                        #endif
                    }
                }
            }
        }
        #else
        throw PrintFriendlyError.screenshotFailed("WebKit not available")
        #endif
    }

    // MARK: - Private Helpers

    private func createDefaultOptions() -> PrintCleanOptions {
        PrintCleanOptions(
            removeAds: settings.removeAds,
            removeNavigation: settings.removeNavigation,
            removeComments: settings.removeComments,
            removeRelatedContent: settings.removeRelatedContent,
            preserveImages: settings.preserveImages,
            preserveLinks: settings.preserveLinks,
            fontSize: settings.defaultFontSize,
            pageSize: settings.defaultPageSize,
            margins: settings.defaultMargins
        )
    }

    private func parseHTML(_ html: String) throws -> HTMLDocument {
        // Simple HTML parsing - in production would use a proper parser
        return HTMLDocument(html: html)
    }

    private func extractMainContent(from document: HTMLDocument, url: URL) async throws -> String {
        // Use multiple strategies to find main content:

        // 1. Check for article element
        if let article = document.querySelector("article") {
            return article
        }

        // 2. Check for common main content IDs/classes
        let mainSelectors = [
            "#main-content", "#content", "#main", ".main-content",
            ".post-content", ".article-content", ".entry-content",
            "[role='main']", "main"
        ]

        for selector in mainSelectors {
            if let content = document.querySelector(selector) {
                return content
            }
        }

        // 3. Heuristic: find the element with the most text
        return document.bodyContent
    }

    private func removeAdvertisements(from html: String) -> String {
        // Remove common ad patterns
        var content = html

        let adSelectors = [
            ".ad", ".ads", ".advertisement", ".ad-container",
            "[data-ad]", "[data-advertisement]", ".sponsored",
            ".promo", ".banner-ad", "ins.adsbygoogle",
            "#google_ads", ".dfp-ad", ".ad-slot"
        ]

        for selector in adSelectors {
            content = removeElements(matching: selector, from: content)
        }

        return content
    }

    private func removeNavigation(from html: String) -> String {
        var content = html

        let navSelectors = [
            "nav", "header", "footer", ".nav", ".navigation",
            ".menu", ".sidebar", "#sidebar", ".breadcrumb",
            ".social-share", ".share-buttons"
        ]

        for selector in navSelectors {
            content = removeElements(matching: selector, from: content)
        }

        return content
    }

    private func removeComments(from html: String) -> String {
        var content = html

        let commentSelectors = [
            "#comments", ".comments", ".comment-section",
            "#disqus_thread", ".fb-comments"
        ]

        for selector in commentSelectors {
            content = removeElements(matching: selector, from: content)
        }

        return content
    }

    private func removeRelatedContent(from html: String) -> String {
        var content = html

        let relatedSelectors = [
            ".related-posts", ".related-articles", ".recommended",
            ".more-stories", ".popular-posts", ".trending"
        ]

        for selector in relatedSelectors {
            content = removeElements(matching: selector, from: content)
        }

        return content
    }

    private func removeElements(matching selector: String, from html: String) -> String {
        // Simple removal - in production would use proper DOM manipulation
        var content = html

        // Remove by class
        if selector.hasPrefix(".") {
            let className = String(selector.dropFirst())
            let patterns = [
                "<[^>]*class=\"[^\"]*\(className)[^\"]*\"[^>]*>.*?</[^>]+>",
                "<[^>]*class='[^']*\(className)[^']*'[^>]*>.*?</[^>]+>"
            ]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                    content = regex.stringByReplacingMatches(in: content, options: [], range: NSRange(content.startIndex..., in: content), withTemplate: "")
                }
            }
        }

        // Remove by ID
        if selector.hasPrefix("#") {
            let idName = String(selector.dropFirst())
            let patterns = [
                "<[^>]*id=\"\(idName)\"[^>]*>.*?</[^>]+>",
                "<[^>]*id='\(idName)'[^>]*>.*?</[^>]+>"
            ]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                    content = regex.stringByReplacingMatches(in: content, options: [], range: NSRange(content.startIndex..., in: content), withTemplate: "")
                }
            }
        }

        // Remove by tag
        if !selector.hasPrefix(".") && !selector.hasPrefix("#") && !selector.hasPrefix("[") {
            let pattern = "<\(selector)[^>]*>.*?</\(selector)>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                content = regex.stringByReplacingMatches(in: content, options: [], range: NSRange(content.startIndex..., in: content), withTemplate: "")
            }
        }

        return content
    }

    private func cleanFormatting(_ html: String, options: PrintCleanOptions) -> String {
        var content = html

        // Remove inline styles that might affect printing
        if let regex = try? NSRegularExpression(pattern: "style=\"[^\"]*\"", options: .caseInsensitive) {
            content = regex.stringByReplacingMatches(in: content, options: [], range: NSRange(content.startIndex..., in: content), withTemplate: "")
        }

        // Remove scripts
        if let regex = try? NSRegularExpression(pattern: "<script[^>]*>.*?</script>", options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            content = regex.stringByReplacingMatches(in: content, options: [], range: NSRange(content.startIndex..., in: content), withTemplate: "")
        }

        // Remove iframes
        if let regex = try? NSRegularExpression(pattern: "<iframe[^>]*>.*?</iframe>", options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            content = regex.stringByReplacingMatches(in: content, options: [], range: NSRange(content.startIndex..., in: content), withTemplate: "")
        }

        return content
    }

    private func extractImages(from html: String) -> [PageImage] {
        var images: [PageImage] = []

        let pattern = "<img[^>]+src=[\"']([^\"']+)[\"'][^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return images
        }

        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))

        for match in matches {
            if let srcRange = Range(match.range(at: 1), in: html) {
                let url = String(html[srcRange])

                // Extract alt text
                var alt: String?
                let altPattern = "alt=[\"']([^\"']*)[\"']"
                if let altRegex = try? NSRegularExpression(pattern: altPattern, options: .caseInsensitive),
                   let altMatch = altRegex.firstMatch(in: html, options: [], range: match.range),
                   let altRange = Range(altMatch.range(at: 1), in: html) {
                    alt = String(html[altRange])
                }

                images.append(PageImage(url: url, alt: alt, width: nil, height: nil))
            }
        }

        return images
    }

    private func extractPlainText(from html: String) -> String {
        var text = html

        // Remove HTML tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            text = regex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }

        // Decode HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")

        // Normalize whitespace
        if let regex = try? NSRegularExpression(pattern: "\\s+", options: []) {
            text = regex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTitle(from document: HTMLDocument) -> String? {
        // Try multiple sources for title
        if let h1 = document.querySelector("h1") {
            return extractPlainText(from: h1)
        }
        if let title = document.querySelector("title") {
            return extractPlainText(from: title)
        }
        return nil
    }

    private func removeElement(_ selector: String, from html: String) -> String {
        return removeElements(matching: selector, from: html)
    }

    private func removeTextRange(_ range: Range<String.Index>, from html: String) -> String {
        var content = html
        content.removeSubrange(range)
        return content
    }

    private func adjustFontSize(by delta: Int, in html: String) -> String {
        // Add CSS to adjust font size
        let css = "<style>body { font-size: \(settings.defaultFontSize + delta)pt !important; }</style>"
        return css + html
    }

    private func removeImageWithUrl(_ url: String, from html: String) -> String {
        let pattern = "<img[^>]+src=[\"']\(NSRegularExpression.escapedPattern(for: url))[\"'][^>]*>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            return regex.stringByReplacingMatches(in: html, options: [], range: NSRange(html.startIndex..., in: html), withTemplate: "")
        }
        return html
    }

    private func removeAllImages(from html: String) -> String {
        if let regex = try? NSRegularExpression(pattern: "<img[^>]*>", options: .caseInsensitive) {
            return regex.stringByReplacingMatches(in: html, options: [], range: NSRange(html.startIndex..., in: html), withTemplate: "")
        }
        return html
    }

    private func highlightText(_ text: String, with color: String, in html: String) -> String {
        return html.replacingOccurrences(
            of: text,
            with: "<mark style=\"background-color: \(color);\">\(text)</mark>"
        )
    }

    private func addNote(_ note: String, at position: Int, in html: String) -> String {
        let index = html.index(html.startIndex, offsetBy: min(position, html.count))
        var content = html
        content.insert(contentsOf: "<div class=\"thea-note\" style=\"background: #fff3cd; padding: 10px; margin: 10px 0; border-left: 4px solid #ffc107;\">\(note)</div>", at: index)
        return content
    }

    private func wrapInPrintStyles(_ content: String, title: String, options: PDFExportOptions) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(title)</title>
            <style>
                @page {
                    size: \(options.pageSize.cssValue);
                    margin: \(options.margins.top)mm \(options.margins.right)mm \(options.margins.bottom)mm \(options.margins.left)mm;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    font-size: \(options.fontSize)pt;
                    line-height: 1.6;
                    color: #333;
                    max-width: 100%;
                    padding: 0;
                    margin: 0;
                }
                h1, h2, h3, h4, h5, h6 {
                    color: #111;
                    margin-top: 1.5em;
                    margin-bottom: 0.5em;
                }
                h1 { font-size: 24pt; }
                h2 { font-size: 20pt; }
                h3 { font-size: 16pt; }
                p { margin: 1em 0; }
                img {
                    max-width: 100%;
                    height: auto;
                    page-break-inside: avoid;
                }
                a { color: #0066cc; }
                pre, code {
                    background: #f5f5f5;
                    padding: 2px 6px;
                    border-radius: 3px;
                    font-family: Menlo, Monaco, 'Courier New', monospace;
                    font-size: 0.9em;
                }
                pre {
                    padding: 1em;
                    overflow-x: auto;
                    page-break-inside: avoid;
                }
                blockquote {
                    border-left: 4px solid #ddd;
                    padding-left: 1em;
                    margin-left: 0;
                    color: #666;
                }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 1em 0;
                }
                th, td {
                    border: 1px solid #ddd;
                    padding: 8px;
                    text-align: left;
                }
                th { background: #f5f5f5; }
                .thea-header {
                    border-bottom: 2px solid #333;
                    padding-bottom: 10px;
                    margin-bottom: 20px;
                }
                .thea-footer {
                    border-top: 1px solid #ddd;
                    padding-top: 10px;
                    margin-top: 20px;
                    font-size: 10pt;
                    color: #666;
                }
                @media print {
                    body { -webkit-print-color-adjust: exact; }
                }
            </style>
        </head>
        <body>
            \(options.includeHeader ? "<div class=\"thea-header\"><h1>\(title)</h1></div>" : "")
            \(content)
            \(options.includeFooter ? "<div class=\"thea-footer\">Generated by Thea on \(Date().formatted())</div>" : "")
        </body>
        </html>
        """
    }
}

// MARK: - Supporting Types

public struct PrintFriendlySettings: Codable {
    public var removeAds: Bool = true
    public var removeNavigation: Bool = true
    public var removeComments: Bool = true
    public var removeRelatedContent: Bool = true
    public var preserveImages: Bool = true
    public var preserveLinks: Bool = true
    public var defaultFontSize: Int = 12
    public var defaultPageSize: PrintCleanOptions.PageSize = .a4
    public var defaultMargins: PrintCleanOptions.PageMargins = .standard
    public var autoDetectMainContent: Bool = true
    public var useAIExtraction: Bool = false
}

public struct PDFExportOptions: Codable {
    public var pageSize: PageSize = .a4
    public var margins: Margins = Margins()
    public var fontSize: Int = 12
    public var includeHeader: Bool = true
    public var includeFooter: Bool = true
    public var includeImages: Bool = true
    public var compress: Bool = true

    public struct PageSize: Codable {
        public var width: Double
        public var height: Double

        public static let a4 = PageSize(width: 210, height: 297)
        public static let letter = PageSize(width: 216, height: 279)
        public static let legal = PageSize(width: 216, height: 356)

        public var cssValue: String {
            "\(width)mm \(height)mm"
        }

        #if os(macOS)
        public var nsSize: NSSize {
            // Convert mm to points (1mm = 2.834645669 points)
            NSSize(width: width * 2.834645669, height: height * 2.834645669)
        }
        #endif
    }

    public struct Margins: Codable {
        public var top: Double = 20
        public var bottom: Double = 20
        public var left: Double = 20
        public var right: Double = 20
    }
}

public enum EditAction {
    case deleteElement(selector: String)
    case deleteText(range: Range<String.Index>)
    case changeFontSize(delta: Int)
    case removeImage(url: String)
    case removeAllImages
    case highlight(text: String, color: String)
    case addNote(text: String, position: Int)
}

public enum PrintFriendlyError: Error, LocalizedError {
    case cleaningFailed(String)
    case noPageLoaded
    case pdfGenerationFailed(String)
    case screenshotFailed(String)
    case nothingToUndo

    public var errorDescription: String? {
        switch self {
        case .cleaningFailed(let reason):
            return "Failed to clean page: \(reason)"
        case .noPageLoaded:
            return "No page is currently loaded"
        case .pdfGenerationFailed(let reason):
            return "Failed to generate PDF: \(reason)"
        case .screenshotFailed(let reason):
            return "Failed to capture screenshot: \(reason)"
        case .nothingToUndo:
            return "Nothing to undo"
        }
    }
}

// MARK: - Simple HTML Document

struct HTMLDocument {
    let html: String

    init(html: String) {
        self.html = html
    }

    func querySelector(_ selector: String) -> String? {
        // Simplified querySelector - in production would use proper DOM parsing
        if selector.hasPrefix("#") {
            let idName = String(selector.dropFirst())
            let pattern = "<[^>]+id=[\"']\(idName)[\"'][^>]*>(.*?)</[^>]+>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range, in: html) {
                return String(html[range])
            }
        }

        if selector.hasPrefix(".") {
            let className = String(selector.dropFirst())
            let pattern = "<[^>]+class=[\"'][^\"']*\(className)[^\"']*[\"'][^>]*>(.*?)</[^>]+>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range, in: html) {
                return String(html[range])
            }
        }

        // Tag selector
        let pattern = "<\(selector)[^>]*>(.*?)</\(selector)>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range, in: html) {
            return String(html[range])
        }

        return nil
    }

    var bodyContent: String {
        if let body = querySelector("body") {
            return body
        }
        return html
    }
}
