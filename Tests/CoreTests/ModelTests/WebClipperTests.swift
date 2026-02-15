// WebClipperTests.swift
// Tests for WebClipper HTML extraction, article clipping, and export

import Foundation
import Testing

// MARK: - Test Doubles

private struct TestClippedArticle: Sendable {
    let url: String
    let title: String
    let content: String
    let excerpt: String
    let author: String?
    let siteName: String?
    let wordCount: Int
    let readingTimeMinutes: Int
    var tags: [String]
    var isFavorite: Bool

    init(url: String, title: String, content: String, excerpt: String = "", author: String? = nil, siteName: String? = nil, tags: [String] = []) {
        self.url = url
        self.title = title
        self.content = content
        self.excerpt = excerpt.isEmpty ? String(content.prefix(200)) : excerpt
        self.author = author
        self.siteName = siteName
        self.wordCount = content.split(separator: " ").count
        self.readingTimeMinutes = max(1, self.wordCount / 200)
        self.tags = tags
        self.isFavorite = false
    }
}

private enum TestExportFormat: String, CaseIterable, Sendable {
    case markdown, plainText, html

    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .plainText: "txt"
        case .html: "html"
        }
    }

    var displayName: String {
        switch self {
        case .markdown: "Markdown"
        case .plainText: "Plain Text"
        case .html: "HTML"
        }
    }
}

private func decodeHTMLEntities(_ text: String) -> String {
    var result = text
    let entities: [(String, String)] = [
        ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
        ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
        ("&nbsp;", " "), ("&ndash;", "–"), ("&mdash;", "—"),
        ("&hellip;", "…"), ("&copy;", "©"), ("&euro;", "€")
    ]
    for (entity, replacement) in entities {
        result = result.replacingOccurrences(of: entity, with: replacement)
    }
    return result
}

private func extractTitle(from html: String) -> String {
    // og:title first
    let ogPattern = "<meta[^>]+property=\"og:title\"[^>]+content=\"([^\"]*)\""
    if let range = html.range(of: ogPattern, options: .regularExpression) {
        let match = String(html[range])
        if let contentRange = match.range(of: "content=\"([^\"]*)\"", options: .regularExpression) {
            let content = String(match[contentRange].dropFirst(9).dropLast())
            if !content.isEmpty { return decodeHTMLEntities(content) }
        }
    }

    let titlePattern = "<title[^>]*>([^<]+)</title>"
    if let range = html.range(of: titlePattern, options: .regularExpression) {
        let match = String(html[range])
        if let contentRange = match.range(of: ">([^<]+)<", options: .regularExpression) {
            let content = String(match[contentRange].dropFirst().dropLast())
            return decodeHTMLEntities(content).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    return "Untitled"
}

private func extractDomain(from url: String) -> String? {
    guard let components = URLComponents(string: url) else { return nil }
    return components.host?.replacingOccurrences(of: "www.", with: "")
}

// MARK: - HTML Entity Decoding Tests

@Suite("WebClipper — HTML Entity Decoding")
struct HTMLEntityTests {
    @Test("Decode common entities")
    func commonEntities() {
        #expect(decodeHTMLEntities("Tom &amp; Jerry") == "Tom & Jerry")
        #expect(decodeHTMLEntities("&lt;div&gt;") == "<div>")
        #expect(decodeHTMLEntities("He said &quot;hi&quot;") == "He said \"hi\"")
    }

    @Test("Decode typographic entities")
    func typographicEntities() {
        #expect(decodeHTMLEntities("A&mdash;B") == "A—B")
        #expect(decodeHTMLEntities("A&ndash;B") == "A–B")
        #expect(decodeHTMLEntities("Wait&hellip;") == "Wait…")
    }

    @Test("Decode currency and symbol entities")
    func currencyEntities() {
        #expect(decodeHTMLEntities("&euro;100") == "€100")
        #expect(decodeHTMLEntities("&copy; 2026") == "© 2026")
    }

    @Test("No entities to decode")
    func noEntities() {
        #expect(decodeHTMLEntities("Hello World") == "Hello World")
    }

    @Test("Apostrophe entities")
    func apostropheEntities() {
        #expect(decodeHTMLEntities("it&#39;s") == "it's")
        #expect(decodeHTMLEntities("it&apos;s") == "it's")
    }
}

// MARK: - Title Extraction Tests

@Suite("WebClipper — Title Extraction")
struct TitleExtractionTests {
    @Test("Extract from <title> tag")
    func titleTag() {
        let html = "<html><head><title>My Article</title></head></html>"
        #expect(extractTitle(from: html) == "My Article")
    }

    @Test("Prefer og:title over <title>")
    func ogTitlePreferred() {
        let html = """
        <html><head>
        <meta property="og:title" content="OG Title">
        <title>Regular Title</title>
        </head></html>
        """
        #expect(extractTitle(from: html) == "OG Title")
    }

    @Test("Decode entities in title")
    func entitiesInTitle() {
        let html = "<html><head><title>Tom &amp; Jerry</title></head></html>"
        #expect(extractTitle(from: html) == "Tom & Jerry")
    }

    @Test("Fallback to Untitled")
    func untitled() {
        let html = "<html><head></head></html>"
        #expect(extractTitle(from: html) == "Untitled")
    }
}

// MARK: - Domain Extraction Tests

@Suite("WebClipper — Domain Extraction")
struct DomainExtractionTests {
    @Test("Extract domain from URL")
    func basicDomain() {
        #expect(extractDomain(from: "https://example.com/article") == "example.com")
    }

    @Test("Strip www prefix")
    func stripWWW() {
        #expect(extractDomain(from: "https://www.example.com/path") == "example.com")
    }

    @Test("Extract subdomain")
    func subdomain() {
        #expect(extractDomain(from: "https://blog.example.com") == "blog.example.com")
    }

    @Test("Invalid URL returns nil")
    func invalidURL() {
        #expect(extractDomain(from: "not a url") == nil)
    }
}

// MARK: - Article Model Tests

@Suite("WebClipper — Article Model")
struct ArticleModelTests {
    @Test("Word count calculated correctly")
    func wordCount() {
        let article = TestClippedArticle(url: "https://test.com", title: "Test", content: "This is a test article with eight words")
        #expect(article.wordCount == 8)
    }

    @Test("Reading time minimum is 1 minute")
    func readingTimeMinimum() {
        let article = TestClippedArticle(url: "https://test.com", title: "Test", content: "Short")
        #expect(article.readingTimeMinutes == 1)
    }

    @Test("Reading time for long article")
    func readingTimeLong() {
        let words = Array(repeating: "word", count: 600).joined(separator: " ")
        let article = TestClippedArticle(url: "https://test.com", title: "Test", content: words)
        #expect(article.readingTimeMinutes == 3)
    }

    @Test("Excerpt auto-generated from content")
    func autoExcerpt() {
        let content = String(repeating: "x", count: 300)
        let article = TestClippedArticle(url: "https://test.com", title: "Test", content: content)
        #expect(article.excerpt.count == 200)
    }

    @Test("Custom excerpt preserved")
    func customExcerpt() {
        let article = TestClippedArticle(url: "https://test.com", title: "Test", content: "Long content", excerpt: "Custom excerpt")
        #expect(article.excerpt == "Custom excerpt")
    }

    @Test("Default state is not favorite")
    func defaultNotFavorite() {
        let article = TestClippedArticle(url: "https://test.com", title: "Test", content: "Content")
        #expect(!article.isFavorite)
    }

    @Test("Tags preserved")
    func tagsPreserved() {
        let article = TestClippedArticle(url: "https://test.com", title: "Test", content: "Content", tags: ["tech", "swift"])
        #expect(article.tags == ["tech", "swift"])
    }
}

// MARK: - Export Format Tests

@Suite("WebClipper — Export Formats")
struct WebClipperExportFormatTests {
    @Test("All 3 formats exist")
    func allFormats() {
        #expect(TestExportFormat.allCases.count == 3)
    }

    @Test("File extensions correct")
    func fileExtensions() {
        #expect(TestExportFormat.markdown.fileExtension == "md")
        #expect(TestExportFormat.plainText.fileExtension == "txt")
        #expect(TestExportFormat.html.fileExtension == "html")
    }

    @Test("Display names user-friendly")
    func displayNames() {
        #expect(TestExportFormat.markdown.displayName == "Markdown")
        #expect(TestExportFormat.plainText.displayName == "Plain Text")
        #expect(TestExportFormat.html.displayName == "HTML")
    }
}

// MARK: - Search Tests

@Suite("WebClipper — Search Logic")
struct SearchLogicTests {
    private func searchArticles(articles: [TestClippedArticle], query: String) -> [TestClippedArticle] {
        guard !query.isEmpty else { return articles }
        let q = query.lowercased()
        return articles.filter {
            $0.title.lowercased().contains(q) ||
            $0.content.lowercased().contains(q) ||
            $0.tags.contains { $0.lowercased().contains(q) } ||
            ($0.siteName?.lowercased().contains(q) ?? false)
        }
    }

    @Test("Search by title")
    func searchTitle() {
        let articles = [
            TestClippedArticle(url: "u1", title: "Swift Programming", content: "Content"),
            TestClippedArticle(url: "u2", title: "Python Guide", content: "Content")
        ]
        let results = searchArticles(articles: articles, query: "swift")
        #expect(results.count == 1)
        #expect(results.first?.title == "Swift Programming")
    }

    @Test("Search by content")
    func searchContent() {
        let articles = [
            TestClippedArticle(url: "u1", title: "Title", content: "This article covers machine learning")
        ]
        let results = searchArticles(articles: articles, query: "machine learning")
        #expect(results.count == 1)
    }

    @Test("Search by tag")
    func searchTag() {
        let articles = [
            TestClippedArticle(url: "u1", title: "Title", content: "Content", tags: ["rust"])
        ]
        let results = searchArticles(articles: articles, query: "rust")
        #expect(results.count == 1)
    }

    @Test("Empty query returns all")
    func emptyQuery() {
        let articles = [
            TestClippedArticle(url: "u1", title: "A", content: "C1"),
            TestClippedArticle(url: "u2", title: "B", content: "C2")
        ]
        #expect(searchArticles(articles: articles, query: "").count == 2)
    }

    @Test("No match returns empty")
    func noMatch() {
        let articles = [
            TestClippedArticle(url: "u1", title: "Swift", content: "iOS")
        ]
        #expect(searchArticles(articles: articles, query: "kubernetes").isEmpty)
    }
}
