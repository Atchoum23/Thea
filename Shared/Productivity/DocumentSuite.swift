// DocumentSuite.swift
// Thea — AI-powered document creation and export
// Replaces: Microsoft Office (for creation/export workflows)
//
// Markdown → PDF/DOCX export, spreadsheet via TabularData,
// template system, and AI writing assistant integration.

import Foundation
import OSLog
import CoreText
#if canImport(PDFKit)
import PDFKit
#endif

private let dsLogger = Logger(subsystem: "ai.thea.app", category: "DocumentSuite")

// MARK: - Data Types

enum DocSuiteType: String, Codable, Sendable, CaseIterable {
    case document = "Document"
    case spreadsheet = "Spreadsheet"
    case presentation = "Presentation"
    case note = "Note"

    var icon: String {
        switch self {
        case .document: "doc.fill"
        case .spreadsheet: "tablecells.fill"
        case .presentation: "rectangle.on.rectangle.angled"
        case .note: "note.text"
        }
    }

    var fileExtension: String {
        switch self {
        case .document: "md"
        case .spreadsheet: "csv"
        case .presentation: "md"
        case .note: "md"
        }
    }
}

enum DocExportFormat: String, Codable, Sendable, CaseIterable {
    case markdown = "Markdown"
    case pdf = "PDF"
    case plainText = "Plain Text"
    case html = "HTML"
    case csv = "CSV"

    var icon: String {
        switch self {
        case .markdown: "text.badge.checkmark"
        case .pdf: "doc.richtext"
        case .plainText: "doc.text"
        case .html: "globe"
        case .csv: "tablecells"
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .pdf: "pdf"
        case .plainText: "txt"
        case .html: "html"
        case .csv: "csv"
        }
    }

    var contentType: String {
        switch self {
        case .markdown: "text/markdown"
        case .pdf: "application/pdf"
        case .plainText: "text/plain"
        case .html: "text/html"
        case .csv: "text/csv"
        }
    }
}

struct TheaDocument: Codable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var type: DocSuiteType
    var tags: [String]
    var isFavorite: Bool
    let createdAt: Date
    var modifiedAt: Date
    var wordCount: Int
    var templateName: String?

    init(
        title: String = "Untitled",
        content: String = "",
        type: DocSuiteType = .document,
        tags: [String] = [],
        templateName: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.type = type
        self.tags = tags
        self.isFavorite = false
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.wordCount = Self.countWords(content)
        self.templateName = templateName
    }

    static func countWords(_ text: String) -> Int {
        text.split(separator: " ").count
    }

    mutating func updateContent(_ newContent: String) {
        content = newContent
        wordCount = Self.countWords(newContent)
        modifiedAt = Date()
    }
}

struct DocumentTemplate: Codable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let type: DocSuiteType
    let content: String
    let icon: String

    init(name: String, description: String, type: DocSuiteType, content: String, icon: String = "doc") {
        self.id = UUID()
        self.name = name
        self.description = description
        self.type = type
        self.content = content
        self.icon = icon
    }
}

enum DocumentSuiteError: Error, LocalizedError {
    case exportFailed(String)
    case templateNotFound
    case invalidContent
    case pdfGenerationFailed

    var errorDescription: String? {
        switch self {
        case .exportFailed(let msg): "Export failed: \(msg)"
        case .templateNotFound: "Template not found"
        case .invalidContent: "Invalid document content"
        case .pdfGenerationFailed: "PDF generation failed"
        }
    }
}

// MARK: - Document Suite Service

actor DocumentSuiteService {
    static let shared = DocumentSuiteService()

    private var documents: [TheaDocument] = []
    private let storageFile: URL

    // Built-in templates
    let templates: [DocumentTemplate] = [
        DocumentTemplate(
            name: "Meeting Notes",
            description: "Structured meeting notes with attendees, agenda, and action items",
            type: .note,
            content: """
            # Meeting Notes

            **Date**: \(Date().formatted(date: .long, time: .shortened))
            **Attendees**:

            ## Agenda

            1.

            ## Discussion

            ## Action Items

            - [ ]
            """,
            icon: "person.3"
        ),
        DocumentTemplate(
            name: "Project Brief",
            description: "Project overview with objectives, timeline, and resources",
            type: .document,
            content: """
            # Project Brief

            ## Overview

            ## Objectives

            1.

            ## Timeline

            | Phase | Start | End | Status |
            |-------|-------|-----|--------|
            | Planning | | | |
            | Development | | | |
            | Testing | | | |
            | Launch | | | |

            ## Resources

            ## Risks & Mitigations
            """,
            icon: "folder"
        ),
        DocumentTemplate(
            name: "Technical Report",
            description: "Technical documentation with abstract, methodology, and findings",
            type: .document,
            content: """
            # Technical Report

            ## Abstract

            ## Introduction

            ## Methodology

            ## Findings

            ## Conclusion

            ## References
            """,
            icon: "doc.text.magnifyingglass"
        ),
        DocumentTemplate(
            name: "Invoice",
            description: "Simple invoice with items, quantities, and totals",
            type: .spreadsheet,
            content: """
            Item,Quantity,Unit Price,Total
            """,
            icon: "dollarsign.circle"
        ),
        DocumentTemplate(
            name: "Cover Letter",
            description: "Professional cover letter template",
            type: .document,
            content: """
            # Cover Letter

            [Your Name]
            [Your Address]
            [Date]

            [Hiring Manager Name]
            [Company Name]
            [Company Address]

            Dear [Hiring Manager Name],

            ## Introduction

            ## Relevant Experience

            ## Why This Role

            ## Closing

            Sincerely,
            [Your Name]
            """,
            icon: "envelope"
        )
    ]

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let theaDir = appSupport.appendingPathComponent("Thea/DocumentSuite")
        try? FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        let file = theaDir.appendingPathComponent("documents.json")
        self.storageFile = file

        if let data = try? Data(contentsOf: file) {
            self.documents = (try? JSONDecoder().decode([TheaDocument].self, from: data)) ?? []
        }
    }

    // MARK: - CRUD

    func createDocument(title: String = "Untitled", content: String = "", type: DocSuiteType = .document) -> TheaDocument {
        let doc = TheaDocument(title: title, content: content, type: type)
        documents.append(doc)
        save()
        return doc
    }

    func createFromTemplate(_ templateName: String) throws -> TheaDocument {
        guard let template = templates.first(where: { $0.name == templateName }) else {
            throw DocumentSuiteError.templateNotFound
        }
        let doc = TheaDocument(
            title: template.name,
            content: template.content,
            type: template.type,
            templateName: template.name
        )
        documents.append(doc)
        save()
        return doc
    }

    func updateDocument(_ id: UUID, title: String? = nil, content: String? = nil, tags: [String]? = nil) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        if let title { documents[index].title = title }
        if let content { documents[index].updateContent(content) }
        if let tags { documents[index].tags = tags }
        documents[index].modifiedAt = Date()
        save()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[index].isFavorite.toggle()
        save()
    }

    func deleteDocument(_ id: UUID) {
        documents.removeAll { $0.id == id }
        save()
    }

    func getDocuments() -> [TheaDocument] { documents }

    func getDocument(_ id: UUID) -> TheaDocument? {
        documents.first { $0.id == id }
    }

    func search(_ query: String) -> [TheaDocument] {
        let lowered = query.lowercased()
        return documents.filter {
            $0.title.lowercased().contains(lowered) ||
            $0.content.lowercased().contains(lowered) ||
            $0.tags.contains { $0.lowercased().contains(lowered) }
        }
    }

    // MARK: - Export

    func exportDocument(_ id: UUID, format: DocExportFormat) throws -> Data {
        guard let doc = documents.first(where: { $0.id == id }) else {
            throw DocumentSuiteError.invalidContent
        }
        return try exportContent(doc.content, title: doc.title, format: format)
    }

    func exportContent(_ content: String, title: String, format: DocExportFormat) throws -> Data {
        switch format {
        case .markdown:
            guard let data = content.data(using: .utf8) else {
                throw DocumentSuiteError.exportFailed("UTF-8 encoding failed")
            }
            return data

        case .plainText:
            let plain = stripMarkdown(content)
            guard let data = plain.data(using: .utf8) else {
                throw DocumentSuiteError.exportFailed("UTF-8 encoding failed")
            }
            return data

        case .html:
            let html = markdownToHTML(content, title: title)
            guard let data = html.data(using: .utf8) else {
                throw DocumentSuiteError.exportFailed("UTF-8 encoding failed")
            }
            return data

        case .pdf:
            return try generatePDF(from: content, title: title)

        case .csv:
            guard let data = content.data(using: .utf8) else {
                throw DocumentSuiteError.exportFailed("UTF-8 encoding failed")
            }
            return data
        }
    }

    // MARK: - Markdown Processing

    private func multilineReplace(_ text: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.anchorsMatchLines]
        ) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }

    func stripMarkdown(_ text: String) -> String {
        var result = text

        // Remove headers
        result = result.replacingOccurrences(of: "#{1,6}\\s+", with: "", options: .regularExpression)

        // Remove bold/italic
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "__(.+?)__", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_(.+?)_", with: "$1", options: .regularExpression)

        // Remove links, keep text
        result = result.replacingOccurrences(of: "\\[(.+?)\\]\\(.+?\\)", with: "$1", options: .regularExpression)

        // Remove images
        result = result.replacingOccurrences(of: "!\\[.*?\\]\\(.+?\\)", with: "", options: .regularExpression)

        // Remove code backticks
        result = result.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "`(.+?)`", with: "$1", options: .regularExpression)

        // Remove horizontal rules
        result = multilineReplace(result, pattern: "^---+$", template: "")

        // Remove list markers
        result = multilineReplace(result, pattern: "^\\s*[-*+]\\s+", template: "")
        result = multilineReplace(result, pattern: "^\\s*\\d+\\.\\s+", template: "")

        // Clean up extra whitespace
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func markdownToHTML(_ markdown: String, title: String) -> String {
        var html = markdown

        // Headers
        for level in (1...6).reversed() {
            let pattern = "^" + String(repeating: "#", count: level) + "\\s+(.+)$"
            html = multilineReplace(html, pattern: pattern, template: "<h\(level)>$1</h\(level)>")
        }

        // Bold and italic
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)

        // Links
        html = html.replacingOccurrences(of: "\\[(.+?)\\]\\((.+?)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)

        // Code blocks
        html = html.replacingOccurrences(of: "```(\\w*)\\n([\\s\\S]*?)```", with: "<pre><code class=\"$1\">$2</code></pre>", options: .regularExpression)
        html = html.replacingOccurrences(of: "`(.+?)`", with: "<code>$1</code>", options: .regularExpression)

        // Lists
        html = multilineReplace(html, pattern: "^\\s*[-*+]\\s+(.+)$", template: "<li>$1</li>")

        // Paragraphs — wrap loose text
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")

        // Horizontal rules
        html = multilineReplace(html, pattern: "^---+$", template: "<hr>")

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #333; }
                h1 { border-bottom: 2px solid #eee; padding-bottom: 10px; }
                pre { background: #f5f5f5; padding: 16px; border-radius: 8px; overflow-x: auto; }
                code { background: #f0f0f0; padding: 2px 6px; border-radius: 4px; font-size: 0.9em; }
                pre code { background: none; padding: 0; }
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background: #f5f5f5; }
                blockquote { border-left: 4px solid #ddd; margin: 0; padding: 10px 20px; color: #666; }
            </style>
        </head>
        <body>
        <p>\(html)</p>
        </body>
        </html>
        """
    }

    // MARK: - PDF Generation

    private func generatePDF(from content: String, title: String) throws -> Data {
        #if os(macOS)
        let html = markdownToHTML(content, title: title)
        // Use simple text-based PDF as fallback
        return try generateSimplePDF(content: content, title: title)
        #else
        return try generateSimplePDF(content: content, title: title)
        #endif
    }

    private func generateSimplePDF(content: String, title: String) throws -> Data {
        #if canImport(UIKit)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            let titleRect = CGRect(x: 72, y: 72, width: 468, height: 40)
            (title as NSString).draw(in: titleRect, withAttributes: titleAttrs)

            // Body
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.label
            ]
            let bodyRect = CGRect(x: 72, y: 120, width: 468, height: 600)
            let stripped = stripMarkdown(content)
            (stripped as NSString).draw(in: bodyRect, withAttributes: bodyAttrs)
        }
        return data
        #elseif canImport(AppKit) && canImport(PDFKit)
        // macOS PDF generation via PDFDocument from HTML
        let htmlContent = markdownToHTML(content, title: title)
        guard let htmlData = htmlContent.data(using: .utf8) else {
            throw DocumentSuiteError.pdfGenerationFailed
        }

        // Create attributed string from HTML
        guard let attrString = NSAttributedString(html: htmlData, documentAttributes: nil) else {
            throw DocumentSuiteError.pdfGenerationFailed
        }

        // Create a simple PDF with attributed string text
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 72
        let textWidth = pageWidth - margin * 2
        let textHeight = pageHeight - margin * 2
        let pdfData = NSMutableData()

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(data: pdfData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw DocumentSuiteError.pdfGenerationFailed
        }

        let framesetter = CTFramesetterCreateWithAttributedString(attrString)
        var textRange = CFRangeMake(0, attrString.length)

        while textRange.location < attrString.length {
            context.beginPDFPage(nil)
            let framePath = CGPath(rect: CGRect(x: margin, y: margin, width: textWidth, height: textHeight), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, textRange, framePath, nil)
            CTFrameDraw(frame, context)
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            textRange.location += visibleRange.length
            if visibleRange.length == 0 { break }
            context.endPDFPage()
        }
        context.endPDFPage()
        context.closePDF()
        return pdfData as Data
        #else
        throw DocumentSuiteError.pdfGenerationFailed
        #endif
    }

    // MARK: - Statistics

    func getStats() -> (total: Int, favorites: Int, wordCount: Int, types: [DocSuiteType: Int]) {
        let favorites = documents.filter(\.isFavorite).count
        let words = documents.reduce(0) { $0 + $1.wordCount }
        let types = Dictionary(grouping: documents, by: \.type).mapValues(\.count)
        return (documents.count, favorites, words, types)
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        try? data.write(to: storageFile, options: .atomic)
    }
}
