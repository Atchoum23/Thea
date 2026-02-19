// WebClipper.swift
// Thea — Clean article extraction + save to knowledge base
// Replaces: PrintFriendly
//
// Extracts readable content from HTML, strips ads/nav/footer.
// Saves to PersonalKnowledgeGraph. Supports PDF/Markdown export.

import Foundation
import OSLog

private let wcLogger = Logger(subsystem: "ai.thea.app", category: "WebClipper")

// MARK: - Data Types

struct ClippedArticle: Codable, Sendable, Identifiable {
    let id: UUID
    let url: String
    let title: String
    let content: String
    let excerpt: String
    let author: String?
    let publishDate: Date?
    let siteName: String?
    let wordCount: Int
    let readingTimeMinutes: Int
    let clippedAt: Date
    var tags: [String]
    var isFavorite: Bool

    init(
        url: String,
        title: String,
        content: String,
        excerpt: String = "",
        author: String? = nil,
        publishDate: Date? = nil,
        siteName: String? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.content = content
        self.excerpt = excerpt.isEmpty ? String(content.prefix(200)) : excerpt
        self.author = author
        self.publishDate = publishDate
        self.siteName = siteName
        self.wordCount = content.split(separator: " ").count
        self.readingTimeMinutes = max(1, self.wordCount / 200)
        self.clippedAt = Date()
        self.tags = tags
        self.isFavorite = false
    }
}

enum ClipExportFormat: String, Codable, Sendable, CaseIterable {
    case markdown
    case plainText
    case html

    var displayName: String {
        switch self {
        case .markdown: "Markdown"
        case .plainText: "Plain Text"
        case .html: "HTML"
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .plainText: "txt"
        case .html: "html"
        }
    }
}

// MARK: - HTML Extraction Engine

struct HTMLExtractor: Sendable {

    static func extractReadableContent(from html: String, url: String) -> ClippedArticle {
        let title = extractTitle(from: html)
        let author = extractMeta(from: html, name: "author")
        let siteName = extractMeta(from: html, property: "og:site_name") ?? extractDomain(from: url)
        let excerpt = extractMeta(from: html, property: "og:description")
            ?? extractMeta(from: html, name: "description")
            ?? ""
        let dateString = extractMeta(from: html, property: "article:published_time")
            ?? extractMeta(from: html, name: "date")
        let publishDate = parseDate(dateString)

        let content = extractMainContent(from: html)
        let tags = extractTags(from: html, title: title, content: content)

        return ClippedArticle(
            url: url,
            title: title,
            content: content,
            excerpt: excerpt,
            author: author,
            publishDate: publishDate,
            siteName: siteName,
            tags: tags
        )
    }

    private static func extractTitle(from html: String) -> String {
        if let ogTitle = extractMeta(from: html, property: "og:title"), !ogTitle.isEmpty {
            return ogTitle
        }

        let titlePattern = #"<title[^>]*>([^<]+)</title>"#
        if let range = html.range(of: titlePattern, options: .regularExpression),
           let contentRange = html[range].range(of: #">([^<]+)<"#, options: .regularExpression) {
            let match = html[contentRange]
            let cleaned = String(match.dropFirst().dropLast())
            return decodeHTMLEntities(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return "Untitled"
    }

    static func extractMeta(from html: String, name: String? = nil, property: String? = nil) -> String? {
        let attr: String
        let value: String
        if let name = name {
            attr = "name"
            value = name
        } else if let property = property {
            attr = "property"
            value = property
        } else {
            return nil
        }

        let patterns = [
            "<meta[^>]+\(attr)=\"\(value)\"[^>]+content=\"([^\"]*)\"",
            "<meta[^>]+content=\"([^\"]*)\"[^>]+\(attr)=\"\(value)\""
        ]

        for pattern in patterns {
            if let range = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let match = String(html[range])
                if let contentRange = match.range(of: #"content="([^"]*)"#, options: .regularExpression) {
                    let contentMatch = String(match[contentRange])
                    let extracted = String(contentMatch.dropFirst(9).dropLast())
                    if !extracted.isEmpty {
                        return decodeHTMLEntities(extracted)
                    }
                }
            }
        }

        return nil
    }

    private static func extractMainContent(from html: String) -> String {
        var text = html

        // Remove scripts, styles, nav, footer, header, aside, forms
        let removeTags = ["script", "style", "nav", "footer", "header", "aside", "form", "noscript", "iframe"]
        for tag in removeTags {
            let pattern = "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
            text = text.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }

        // Try to find main/article content
        if let articleContent = extractTagContent(from: text, tag: "article") {
            text = articleContent
        } else if let mainContent = extractTagContent(from: text, tag: "main") {
            text = mainContent
        }

        // Remove remaining HTML tags
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<h[1-6][^>]*>", with: "\n## ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "</h[1-6]>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode HTML entities
        text = decodeHTMLEntities(text)

        // Clean up whitespace
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Collapse spaces on each line
        let lines = text.components(separatedBy: "\n").map {
            $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
        text = lines.joined(separator: "\n")
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractTagContent(from html: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>([\\s\\S]*?)</\(tag)>"
        guard let range = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let match = String(html[range])
        let openEnd = match.firstIndex(of: ">").map { match.index(after: $0) } ?? match.startIndex
        let closeStart = match.range(of: "</\(tag)>", options: .caseInsensitive)?.lowerBound ?? match.endIndex
        let content = String(match[openEnd..<closeStart])
        return content.isEmpty ? nil : content
    }

    static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&nbsp;", " "), ("&ndash;", "–"), ("&mdash;", "—"),
            ("&lsquo;", "'"), ("&rsquo;", "'"),
            ("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"),
            ("&hellip;", "…"), ("&copy;", "©"), ("&reg;", "®"),
            ("&trade;", "™"), ("&euro;", "€"), ("&pound;", "£")
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // Numeric entities
        let numericPattern = "&#(\\d+);"
        do {
            let regex = try NSRegularExpression(pattern: numericPattern)
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange).reversed()
            for match in matches {
                if let codeRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[codeRange]),
                   let scalar = Unicode.Scalar(code) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        } catch {
            wcLogger.debug("Invalid numeric entity regex: \(error.localizedDescription)")
        }
        return result
    }

    private static func extractDomain(from url: String) -> String? {
        guard let components = URLComponents(string: url) else { return nil }
        return components.host?.replacingOccurrences(of: "www.", with: "")
    }

    private static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatters: [DateFormatter] = {
            let f1 = DateFormatter()
            f1.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            let f2 = DateFormatter()
            f2.dateFormat = "yyyy-MM-dd"
            let f3 = DateFormatter()
            f3.dateFormat = "MMMM d, yyyy"
            f3.locale = Locale(identifier: "en_US")
            return [f1, f2, f3]
        }()

        for formatter in formatters {
            if let date = formatter.date(from: dateString) { return date }
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: dateString)
    }

    // periphery:ignore - Reserved: title parameter — kept for API compatibility
    private static func extractTags(from html: String, title: String, content: String) -> [String] {
        var tags: [String] = []

// periphery:ignore - Reserved: title parameter kept for API compatibility

        if let keywords = extractMeta(from: html, name: "keywords") {
            let kw = keywords.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            tags.append(contentsOf: kw.prefix(5))
        }

        if let section = extractMeta(from: html, property: "article:section"), !section.isEmpty {
            tags.append(section)
        }

        return Array(Set(tags)).sorted()
    }
}

// MARK: - WebClipper Service

@MainActor
@Observable
final class WebClipper {
    static let shared = WebClipper()

    private(set) var articles: [ClippedArticle] = []
    private(set) var isClipping = false

    private let fileManager = FileManager.default
    private let storageDir: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("Thea/WebClips")
        do {
            try fileManager.createDirectory(at: storageDir, withIntermediateDirectories: true)
        } catch {
            wcLogger.debug("Could not create WebClips storage directory: \(error.localizedDescription)")
        }
        loadArticles()
    }

    // MARK: - Clipping

    func clipFromURL(_ urlString: String) async -> ClippedArticle? {
        guard let url = URL(string: urlString) else {
            wcLogger.error("Invalid URL: \(urlString)")
            return nil
        }

        isClipping = true
        defer { isClipping = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                wcLogger.error("Failed to decode HTML from \(urlString)")
                return nil
            }

            let article = HTMLExtractor.extractReadableContent(from: html, url: urlString)
            articles.insert(article, at: 0)
            saveArticles()
            wcLogger.info("Clipped: \(article.title) (\(article.wordCount) words)")
            return article
        } catch {
            wcLogger.error("Failed to fetch URL \(urlString): \(error.localizedDescription)")
            return nil
        }
    }

    // periphery:ignore - Reserved: clipFromHTML(_:url:) instance method — reserved for future feature activation
    func clipFromHTML(_ html: String, url: String) -> ClippedArticle {
        // periphery:ignore - Reserved: clipFromHTML(_:url:) instance method reserved for future feature activation
        let article = HTMLExtractor.extractReadableContent(from: html, url: url)
        articles.insert(article, at: 0)
        saveArticles()
        return article
    }

    // MARK: - Export

    func export(_ article: ClippedArticle, format: ClipExportFormat) -> String {
        switch format {
        case .markdown:
            return exportMarkdown(article)
        case .plainText:
            return exportPlainText(article)
        case .html:
            return exportHTML(article)
        }
    }

    private func exportMarkdown(_ article: ClippedArticle) -> String {
        var md = "# \(article.title)\n\n"
        if let author = article.author { md += "> By \(author)\n\n" }
        if let site = article.siteName { md += "Source: [\(site)](\(article.url))\n\n" }
        if let date = article.publishDate {
            let f = DateFormatter()
            f.dateStyle = .long
            md += "Published: \(f.string(from: date))\n\n"
        }
        md += "---\n\n"
        md += article.content
        md += "\n\n---\n*Clipped by Thea on \(DateFormatter.localizedString(from: article.clippedAt, dateStyle: .short, timeStyle: .short))*\n"
        return md
    }

    private func exportPlainText(_ article: ClippedArticle) -> String {
        var text = "\(article.title)\n\n"
        if let author = article.author { text += "By \(author)\n" }
        if let site = article.siteName { text += "Source: \(site) — \(article.url)\n" }
        text += "\n"
        text += article.content
        return text
    }

    private func exportHTML(_ article: ClippedArticle) -> String {
        var html = "<!DOCTYPE html><html><head><meta charset=\"utf-8\">"
        html += "<title>\(article.title)</title>"
        html += "<style>body{font-family:system-ui;max-width:700px;margin:40px auto;padding:0 20px;line-height:1.6;}</style>"
        html += "</head><body>"
        html += "<h1>\(article.title)</h1>"
        if let author = article.author { html += "<p><em>By \(author)</em></p>" }
        let paragraphs = article.content.components(separatedBy: "\n\n")
        for p in paragraphs where !p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if p.hasPrefix("## ") {
                html += "<h2>\(p.dropFirst(3))</h2>"
            } else {
                html += "<p>\(p)</p>"
            }
        }
        html += "</body></html>"
        return html
    }

    // MARK: - CRUD

    func deleteArticle(_ article: ClippedArticle) {
        articles.removeAll { $0.id == article.id }
        saveArticles()
    }

    func toggleFavorite(_ articleID: UUID) {
        guard let index = articles.firstIndex(where: { $0.id == articleID }) else { return }
        articles[index].isFavorite.toggle()
        saveArticles()
    }

    // periphery:ignore - Reserved: updateTags(_:tags:) instance method reserved for future feature activation
    func updateTags(_ articleID: UUID, tags: [String]) {
        guard let index = articles.firstIndex(where: { $0.id == articleID }) else { return }
        articles[index].tags = tags
        saveArticles()
    }

    func searchArticles(query: String) -> [ClippedArticle] {
        guard !query.isEmpty else { return articles }
        let q = query.lowercased()
        return articles.filter {
            $0.title.lowercased().contains(q) ||
            $0.content.lowercased().contains(q) ||
            $0.tags.contains { $0.lowercased().contains(q) } ||
            ($0.siteName?.lowercased().contains(q) ?? false)
        }
    }

    // MARK: - Persistence

    private var storageFile: URL { storageDir.appendingPathComponent("articles.json") }

    private func loadArticles() {
        guard FileManager.default.fileExists(atPath: storageFile.path) else { return }
        do {
            let data = try Data(contentsOf: storageFile)
            self.articles = try JSONDecoder().decode([ClippedArticle].self, from: data)
        } catch {
            wcLogger.debug("Could not load clipped articles: \(error.localizedDescription)")
        }
    }

    private func saveArticles() {
        do {
            let data = try JSONEncoder().encode(articles)
            try data.write(to: storageFile)
        } catch {
            wcLogger.error("Failed to save clipped articles: \(error.localizedDescription)")
        }
    }
}
