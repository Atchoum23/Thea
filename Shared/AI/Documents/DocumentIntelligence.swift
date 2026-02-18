// DocumentIntelligence.swift
// AI-powered document understanding, extraction, and analysis

import Foundation
import OSLog
#if canImport(PDFKit)
    import PDFKit
#endif
#if canImport(NaturalLanguage)
    import NaturalLanguage
#endif

// MARK: - Document Intelligence

/// AI-powered document understanding and extraction
@MainActor
public final class DocumentIntelligence: ObservableObject {
    public static let shared = DocumentIntelligence()

    private let logger = Logger(subsystem: "com.thea.app", category: "DocumentIntelligence")

    // MARK: - Published State

    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastAnalysis: DocumentAnalysis?

    // MARK: - Initialization

    private init() {}

    // MARK: - Document Analysis

    /// Analyze a document and extract structured information
    public func analyze(documentData: Data, type: DocumentType) async throws -> DocumentAnalysis {
        isProcessing = true
        defer { isProcessing = false }

        switch type {
        case .pdf:
            return try await analyzePDF(data: documentData)
        case .plainText:
            return try await analyzeText(data: documentData)
        case .markdown:
            return try await analyzeMarkdown(data: documentData)
        case .html:
            return try await analyzeHTML(data: documentData)
        case .json:
            return try await analyzeJSON(data: documentData)
        case .csv:
            return try await analyzeCSV(data: documentData)
        }
    }

    // MARK: - PDF Analysis

    private func analyzePDF(data: Data) async throws -> DocumentAnalysis {
        #if canImport(PDFKit)
            guard let document = PDFDocument(data: data) else {
                throw DocumentError.invalidDocument("Failed to parse PDF")
            }

            var fullText = ""
            var pages: [DocumentPage] = []

            for i in 0 ..< document.pageCount {
                guard let page = document.page(at: i) else { continue }

                let pageText = page.string ?? ""
                fullText += pageText + "\n\n"

                pages.append(DocumentPage(
                    number: i + 1,
                    text: pageText,
                    bounds: page.bounds(for: .mediaBox)
                ))
            }

            // Extract metadata
            let metadata = extractPDFMetadata(document)

            // Analyze text content
            let textAnalysis = await analyzeTextContent(fullText)

            lastAnalysis = DocumentAnalysis(
                type: .pdf,
                pageCount: document.pageCount,
                text: fullText,
                pages: pages,
                metadata: metadata,
                entities: textAnalysis.entities,
                summary: textAnalysis.summary,
                keywords: textAnalysis.keywords,
                sentiment: textAnalysis.sentiment,
                language: textAnalysis.language
            )

            return lastAnalysis!
        #else
            throw DocumentError.featureNotAvailable("PDF support not available")
        #endif
    }

    #if canImport(PDFKit)
        private func extractPDFMetadata(_ document: PDFDocument) -> DocumentMetadata {
            let attributes = document.documentAttributes ?? [:]

            return DocumentMetadata(
                title: attributes[PDFDocumentAttribute.titleAttribute] as? String,
                author: attributes[PDFDocumentAttribute.authorAttribute] as? String,
                subject: attributes[PDFDocumentAttribute.subjectAttribute] as? String,
                keywords: (attributes[PDFDocumentAttribute.keywordsAttribute] as? String)?.components(separatedBy: ","),
                creator: attributes[PDFDocumentAttribute.creatorAttribute] as? String,
                producer: attributes[PDFDocumentAttribute.producerAttribute] as? String,
                creationDate: attributes[PDFDocumentAttribute.creationDateAttribute] as? Date,
                modificationDate: attributes[PDFDocumentAttribute.modificationDateAttribute] as? Date
            )
        }
    #endif

    // MARK: - Text Analysis

    private func analyzeText(data: Data) async throws -> DocumentAnalysis {
        guard let text = String(data: data, encoding: .utf8) else {
            throw DocumentError.invalidDocument("Failed to decode text")
        }

        let textAnalysis = await analyzeTextContent(text)

        return DocumentAnalysis(
            type: .plainText,
            pageCount: 1,
            text: text,
            pages: [DocumentPage(number: 1, text: text, bounds: .zero)],
            metadata: DocumentMetadata(),
            entities: textAnalysis.entities,
            summary: textAnalysis.summary,
            keywords: textAnalysis.keywords,
            sentiment: textAnalysis.sentiment,
            language: textAnalysis.language
        )
    }

    private func analyzeMarkdown(data: Data) async throws -> DocumentAnalysis {
        guard let text = String(data: data, encoding: .utf8) else {
            throw DocumentError.invalidDocument("Failed to decode markdown")
        }

        // Parse markdown structure
        let structure = parseMarkdownStructure(text)
        let textAnalysis = await analyzeTextContent(text)

        return DocumentAnalysis(
            type: .markdown,
            pageCount: 1,
            text: text,
            pages: [DocumentPage(number: 1, text: text, bounds: .zero)],
            metadata: DocumentMetadata(),
            entities: textAnalysis.entities,
            summary: textAnalysis.summary,
            keywords: textAnalysis.keywords,
            sentiment: textAnalysis.sentiment,
            language: textAnalysis.language,
            structure: structure
        )
    }

    private func analyzeHTML(data: Data) async throws -> DocumentAnalysis {
        guard let html = String(data: data, encoding: .utf8) else {
            throw DocumentError.invalidDocument("Failed to decode HTML")
        }

        // Strip HTML tags for text analysis
        let plainText = stripHTML(html)
        let textAnalysis = await analyzeTextContent(plainText)

        return DocumentAnalysis(
            type: .html,
            pageCount: 1,
            text: plainText,
            pages: [DocumentPage(number: 1, text: plainText, bounds: .zero)],
            metadata: extractHTMLMetadata(html),
            entities: textAnalysis.entities,
            summary: textAnalysis.summary,
            keywords: textAnalysis.keywords,
            sentiment: textAnalysis.sentiment,
            language: textAnalysis.language
        )
    }

    private func analyzeJSON(data: Data) async throws -> DocumentAnalysis {
        // Validate JSON
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            logger.error("Failed to parse JSON document: \(error.localizedDescription)")
            throw DocumentError.invalidDocument("Invalid JSON")
        }

        let text = String(data: data, encoding: .utf8) ?? ""

        // Analyze JSON structure
        let structure = analyzeJSONStructure(json)

        return DocumentAnalysis(
            type: .json,
            pageCount: 1,
            text: text,
            pages: [DocumentPage(number: 1, text: text, bounds: .zero)],
            metadata: DocumentMetadata(),
            entities: [],
            summary: "JSON document with \(structure.keyCount) keys",
            keywords: structure.topLevelKeys,
            sentiment: nil,
            language: nil,
            structure: structure.description
        )
    }

    private func analyzeCSV(data: Data) async throws -> DocumentAnalysis {
        guard let text = String(data: data, encoding: .utf8) else {
            throw DocumentError.invalidDocument("Failed to decode CSV")
        }

        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let headerLine = lines.first else {
            throw DocumentError.invalidDocument("Empty CSV")
        }

        let headers = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let rowCount = lines.count - 1

        return DocumentAnalysis(
            type: .csv,
            pageCount: 1,
            text: text,
            pages: [DocumentPage(number: 1, text: text, bounds: .zero)],
            metadata: DocumentMetadata(),
            entities: [],
            summary: "CSV with \(headers.count) columns and \(rowCount) rows",
            keywords: headers,
            sentiment: nil,
            language: nil,
            structure: DocumentStructure(
                headers: headers.map { DocumentHeader(level: 1, text: $0) },
                sections: [],
                lists: [],
                tables: [DocumentTable(rows: rowCount, columns: headers.count, headers: headers)]
            )
        )
    }

    // MARK: - Text Content Analysis

    private func analyzeTextContent(_ text: String) async -> TextAnalysisResult {
        var entities: [DocumentEntity] = []
        var keywords: [String] = []
        var sentiment: SentimentScore?
        var language: String?

        #if canImport(NaturalLanguage)
            // Detect language
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            if let dominantLanguage = recognizer.dominantLanguage {
                language = dominantLanguage.rawValue
            }

            // Extract named entities
            let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
            tagger.string = text

            let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
            tagger.enumerateTags(in: text.startIndex ..< text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
                if let tag {
                    let entity = String(text[range])
                    let entityType = DocumentEntityType(from: tag)
                    if entityType != .unknown {
                        entities.append(DocumentEntity(
                            text: entity,
                            type: entityType,
                            range: range
                        ))
                    }
                }
                return true
            }

            // Extract keywords using lexical analysis
            var wordFrequency: [String: Int] = [:]
            tagger.enumerateTags(in: text.startIndex ..< text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
                if let tag, tag == .noun || tag == .verb || tag == .adjective {
                    let word = String(text[range]).lowercased()
                    if word.count > 3 {
                        wordFrequency[word, default: 0] += 1
                    }
                }
                return true
            }
            keywords = wordFrequency.sorted { $0.value > $1.value }.prefix(20).map(\.key)

            // Sentiment analysis
            let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
            sentimentTagger.string = text
            let (sentimentTag, _) = sentimentTagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            if let scoreString = sentimentTag?.rawValue, let score = Double(scoreString) {
                sentiment = SentimentScore(
                    score: score,
                    label: score > 0.3 ? .positive : (score < -0.3 ? .negative : .neutral)
                )
            }
        #endif

        // Generate summary (simple extraction-based)
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 }

        let summary = sentences.prefix(3).joined(separator: ". ") + "."

        return TextAnalysisResult(
            entities: entities,
            keywords: keywords,
            sentiment: sentiment,
            language: language,
            summary: summary
        )
    }

    // MARK: - Helpers

    private func parseMarkdownStructure(_ text: String) -> DocumentStructure {
        var headers: [DocumentHeader] = []
        var lists: [DocumentList] = []
        var currentListItems: [String] = []

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            // Parse headers
            if line.hasPrefix("#") {
                let level = line.prefix { $0 == "#" }.count
                let headerText = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                headers.append(DocumentHeader(level: level, text: headerText))
            }

            // Parse lists
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") ||
                line.trimmingCharacters(in: .whitespaces).hasPrefix("* ")
            {
                let item = String(line.trimmingCharacters(in: .whitespaces).dropFirst(2))
                currentListItems.append(item)
            } else if !currentListItems.isEmpty {
                lists.append(DocumentList(items: currentListItems, ordered: false))
                currentListItems = []
            }
        }

        if !currentListItems.isEmpty {
            lists.append(DocumentList(items: currentListItems, ordered: false))
        }

        return DocumentStructure(headers: headers, sections: [], lists: lists, tables: [])
    }

    private func stripHTML(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractHTMLMetadata(_ html: String) -> DocumentMetadata {
        var title: String?
        var description: String?

        // Extract title
        if let titleMatch = html.range(of: "<title>([^<]+)</title>", options: .regularExpression) {
            let titleTag = String(html[titleMatch])
            title = titleTag.replacingOccurrences(of: "<title>", with: "").replacingOccurrences(of: "</title>", with: "")
        }

        // Extract meta description
        if let descMatch = html.range(of: "<meta[^>]*name=\"description\"[^>]*content=\"([^\"]+)\"", options: .regularExpression) {
            let descTag = String(html[descMatch])
            if let contentMatch = descTag.range(of: "content=\"([^\"]+)\"", options: .regularExpression) {
                description = String(descTag[contentMatch]).replacingOccurrences(of: "content=\"", with: "").replacingOccurrences(of: "\"", with: "")
            }
        }

        return DocumentMetadata(title: title, subject: description)
    }

    private func analyzeJSONStructure(_ json: Any) -> (keyCount: Int, topLevelKeys: [String], description: DocumentStructure) {
        var keyCount = 0
        var topLevelKeys: [String] = []

        if let dict = json as? [String: Any] {
            topLevelKeys = Array(dict.keys)
            keyCount = countKeys(in: dict)
        } else if let array = json as? [Any] {
            keyCount = array.count
            topLevelKeys = ["(Array with \(array.count) items)"]
        }

        return (keyCount, topLevelKeys, DocumentStructure(
            headers: topLevelKeys.map { DocumentHeader(level: 1, text: $0) },
            sections: [],
            lists: [],
            tables: []
        ))
    }

    private func countKeys(in dict: [String: Any]) -> Int {
        var count = dict.count
        for value in dict.values {
            if let nested = value as? [String: Any] {
                count += countKeys(in: nested)
            } else if let array = value as? [[String: Any]] {
                for item in array {
                    count += countKeys(in: item)
                }
            }
        }
        return count
    }
}

// MARK: - Document Types

public enum DocumentType: String, CaseIterable, Sendable {
    case pdf
    case plainText
    case markdown
    case html
    case json
    case csv
}

// MARK: - Document Error

public enum DocumentError: Error, LocalizedError {
    case invalidDocument(String)
    case featureNotAvailable(String)
    case analysisError(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidDocument(reason):
            "Invalid document: \(reason)"
        case let .featureNotAvailable(feature):
            "Feature not available: \(feature)"
        case let .analysisError(reason):
            "Analysis error: \(reason)"
        }
    }
}

// MARK: - Result Types

public struct DocumentAnalysis: Sendable {
    public let type: DocumentType
    public let pageCount: Int
    public let text: String
    public let pages: [DocumentPage]
    public let metadata: DocumentMetadata
    public let entities: [DocumentEntity]
    public let summary: String
    public let keywords: [String]
    public let sentiment: SentimentScore?
    public let language: String?
    public var structure: DocumentStructure?
}

public struct DocumentPage: Sendable {
    public let number: Int
    public let text: String
    public let bounds: CGRect
}

public struct DocumentMetadata: Sendable {
    public var title: String?
    public var author: String?
    public var subject: String?
    public var keywords: [String]?
    public var creator: String?
    public var producer: String?
    public var creationDate: Date?
    public var modificationDate: Date?

    public init(
        title: String? = nil,
        author: String? = nil,
        subject: String? = nil,
        keywords: [String]? = nil,
        creator: String? = nil,
        producer: String? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil
    ) {
        self.title = title
        self.author = author
        self.subject = subject
        self.keywords = keywords
        self.creator = creator
        self.producer = producer
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }
}

public struct DocumentEntity: Sendable {
    public let text: String
    public let type: DocumentEntityType
    public let range: Range<String.Index>
}

public enum DocumentEntityType: String, Sendable {
    case person
    case place
    case organization
    case unknown

    #if canImport(NaturalLanguage)
        init(from tag: NLTag) {
            switch tag {
            case .personalName: self = .person
            case .placeName: self = .place
            case .organizationName: self = .organization
            default: self = .unknown
            }
        }
    #endif
}

public struct SentimentScore: Sendable {
    public let score: Double
    public let label: SentimentLabel
}

public enum SentimentLabel: String, Sendable {
    case positive
    case negative
    case neutral
}

public struct DocumentStructure: Sendable {
    public let headers: [DocumentHeader]
    public let sections: [DocumentSection]
    public let lists: [DocumentList]
    public let tables: [DocumentTable]
}

public struct DocumentHeader: Sendable {
    public let level: Int
    public let text: String
}

public struct DocumentSection: Sendable {
    public let title: String
    public let content: String
}

public struct DocumentList: Sendable {
    public let items: [String]
    public let ordered: Bool
}

public struct DocumentTable: Sendable {
    public let rows: Int
    public let columns: Int
    public let headers: [String]
}

private struct TextAnalysisResult {
    let entities: [DocumentEntity]
    let keywords: [String]
    let sentiment: SentimentScore?
    let language: String?
    let summary: String
}
