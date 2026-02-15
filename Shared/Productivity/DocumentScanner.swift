// DocumentScanner.swift
// Thea — Document scanning, OCR, and AI classification service
// Replaces: Adobe Scan, ScanSnap integration
//
// Features:
// - Vision framework OCR (on-device, no cloud)
// - AI-powered document classification (bill, legal, medical, insurance, tax, etc.)
// - Key information extraction (dates, amounts, sender, subject)
// - Document storage with search and tags
// - Export to PDF
//
// Privacy: All OCR processing is 100% on-device via Apple Vision framework.
// Document images and extracted text stored locally in Application Support.

import Foundation
import OSLog
import Vision
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif

private let dsLogger = Logger(subsystem: "ai.thea.app", category: "DocumentScanner")

// MARK: - Document Category

enum DocumentCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case bill = "Bill"
    case invoice = "Invoice"
    case receipt = "Receipt"
    case contract = "Contract"
    case legal = "Legal"
    case medical = "Medical"
    case insurance = "Insurance"
    case tax = "Tax"
    case bank = "Bank Statement"
    case identity = "Identity Document"
    case correspondence = "Correspondence"
    case government = "Government"
    case education = "Education"
    case employment = "Employment"
    case warranty = "Warranty"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bill: "doc.text.fill"
        case .invoice: "doc.richtext.fill"
        case .receipt: "receipt"
        case .contract: "signature"
        case .legal: "building.columns.fill"
        case .medical: "cross.case.fill"
        case .insurance: "shield.checkered"
        case .tax: "percent"
        case .bank: "banknote.fill"
        case .identity: "person.text.rectangle.fill"
        case .correspondence: "envelope.fill"
        case .government: "flag.fill"
        case .education: "graduationcap.fill"
        case .employment: "briefcase.fill"
        case .warranty: "checkmark.seal.fill"
        case .other: "doc.fill"
        }
    }

    var color: String {
        switch self {
        case .bill, .invoice: "blue"
        case .receipt: "green"
        case .contract, .legal: "purple"
        case .medical: "red"
        case .insurance: "orange"
        case .tax: "yellow"
        case .bank: "teal"
        case .identity: "indigo"
        case .correspondence: "gray"
        case .government: "brown"
        case .education: "mint"
        case .employment: "cyan"
        case .warranty: "pink"
        case .other: "secondary"
        }
    }
}

// MARK: - Scanned Document

struct ScannedDocument: Codable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var category: DocumentCategory
    var extractedText: String
    var summary: String
    var sender: String?
    var subject: String?
    var documentDate: Date?
    var amounts: [ExtractedAmount]
    var tags: [String]
    var isFavorite: Bool
    var imagePaths: [String]
    let createdAt: Date
    var modifiedAt: Date
    var ocrLanguage: String?
    var pageCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        category: DocumentCategory = .other,
        extractedText: String = "",
        summary: String = "",
        sender: String? = nil,
        subject: String? = nil,
        documentDate: Date? = nil,
        amounts: [ExtractedAmount] = [],
        tags: [String] = [],
        isFavorite: Bool = false,
        imagePaths: [String] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        ocrLanguage: String? = nil,
        pageCount: Int = 1
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.extractedText = extractedText
        self.summary = summary
        self.sender = sender
        self.subject = subject
        self.documentDate = documentDate
        self.amounts = amounts
        self.tags = tags
        self.isFavorite = isFavorite
        self.imagePaths = imagePaths
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.ocrLanguage = ocrLanguage
        self.pageCount = pageCount
    }
}

// MARK: - Extracted Amount

struct ExtractedAmount: Codable, Sendable, Identifiable {
    let id: UUID
    let value: Double
    let currency: String
    let label: String?

    init(id: UUID = UUID(), value: Double, currency: String = "CHF", label: String? = nil) {
        self.id = id
        self.value = value
        self.currency = currency
        self.label = label
    }

    var formatted: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = currency
        return fmt.string(from: NSNumber(value: value)) ?? "\(currency) \(value)"
    }
}

// MARK: - Document Scanner Error

enum DocumentScannerError: Error, LocalizedError, Sendable {
    case ocrFailed(String)
    case imageLoadFailed(String)
    case storageFailed(String)
    case exportFailed(String)
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .ocrFailed(let msg): "OCR failed: \(msg)"
        case .imageLoadFailed(let msg): "Could not load image: \(msg)"
        case .storageFailed(let msg): "Storage error: \(msg)"
        case .exportFailed(let msg): "Export failed: \(msg)"
        case .noTextFound: "No text could be extracted from the document"
        }
    }
}

// MARK: - Document Scanner Service

@MainActor @Observable
final class DocumentScanner {
    static let shared = DocumentScanner()

    private(set) var documents: [ScannedDocument] = []
    private(set) var isProcessing = false

    private let storageDir: URL
    private let imagesDir: URL
    private let documentsFile: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("Thea/Documents", isDirectory: true)
        imagesDir = storageDir.appendingPathComponent("Images", isDirectory: true)
        documentsFile = storageDir.appendingPathComponent("scanned_documents.json")

        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        loadDocuments()
    }

    // MARK: - Persistence

    private func loadDocuments() {
        guard FileManager.default.fileExists(atPath: documentsFile.path) else {
            documents = []
            return
        }
        do {
            let data = try Data(contentsOf: documentsFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            documents = try decoder.decode([ScannedDocument].self, from: data)
            dsLogger.info("Loaded \(self.documents.count) scanned documents")
        } catch {
            dsLogger.error("Failed to load documents: \(error.localizedDescription)")
            documents = []
        }
    }

    private func saveDocuments() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(documents)
            try data.write(to: documentsFile, options: .atomic)
        } catch {
            dsLogger.error("Failed to save documents: \(error.localizedDescription)")
        }
    }

    // MARK: - OCR

    func performOCR(on imageData: Data, languages: [String]? = nil) async throws -> String {
        #if canImport(CoreImage)
        guard let ciImage = CIImage(data: imageData) else {
            throw DocumentScannerError.imageLoadFailed("Could not create image from data")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: DocumentScannerError.ocrFailed(error.localizedDescription))
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: DocumentScannerError.noTextFound)
                    return
                }
                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: DocumentScannerError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if let languages {
                request.recognitionLanguages = languages
            } else {
                request.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "it-IT", "ru-RU"]
            }

            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: DocumentScannerError.ocrFailed(error.localizedDescription))
            }
        }
        #else
        throw DocumentScannerError.ocrFailed("CoreImage not available on this platform")
        #endif
    }

    func performOCROnPDF(at url: URL) async throws -> (String, Int) {
        #if canImport(PDFKit)
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentScannerError.imageLoadFailed("Could not open PDF")
        }

        var allText = ""
        let pageCount = pdfDocument.pageCount

        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            // Try text extraction first (for digital PDFs)
            if let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                allText += pageText + "\n\n"
                continue
            }

            // Fall back to OCR for scanned PDFs
            let pageRect = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0
            let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

            #if canImport(AppKit)
            let image = NSImage(size: size)
            image.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: ctx)
            }
            image.unlockFocus()

            guard let tiffData = image.tiffRepresentation else { continue }
            let pageOCR = try await performOCR(on: tiffData)
            allText += pageOCR + "\n\n"
            #elseif canImport(UIKit)
            let renderer = UIGraphicsImageRenderer(size: size)
            let uiImage = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            guard let pngData = uiImage.pngData() else { continue }
            let pageOCR = try await performOCR(on: pngData)
            allText += pageOCR + "\n\n"
            #endif
        }

        if allText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DocumentScannerError.noTextFound
        }

        return (allText.trimmingCharacters(in: .whitespacesAndNewlines), pageCount)
        #else
        throw DocumentScannerError.ocrFailed("PDFKit not available")
        #endif
    }

    // MARK: - Classification

    func classifyDocument(_ text: String) -> DocumentCategory {
        let lower = text.lowercased()

        // Classification rules ordered by specificity
        let rules: [(DocumentCategory, [String])] = [
            (.tax, ["tax return", "steuererklärung", "déclaration d'impôt", "tax assessment", "steueramt",
                     "veranlagung", "impôt", "lohnausweis", "salary certificate", "withholding tax"]),
            (.medical, ["medical", "diagnosis", "prescription", "dr.", "hospital", "clinic", "patient",
                         "arzt", "klinik", "ordonnance", "médecin", "health insurance claim", "krankenkasse"]),
            (.insurance, ["insurance", "police", "versicherung", "assurance", "premium", "deductible",
                           "prämie", "franchise", "couverture", "coverage", "claim number"]),
            (.identity, ["passport", "identity card", "driving licence", "driver's license", "permis",
                          "ausweis", "aufenthaltsbewilligung", "residence permit", "visa"]),
            (.contract, ["contract", "agreement", "vertrag", "contrat", "hereby agree", "terms and conditions",
                          "effective date", "termination", "signature", "parties"]),
            (.legal, ["court", "tribunal", "judgment", "lawyer", "attorney", "gericht", "urteil",
                       "avocat", "anwalt", "legal notice", "summons"]),
            (.bank, ["bank statement", "account balance", "kontoauszug", "relevé", "iban",
                      "transaction", "credit", "debit", "bic", "swift"]),
            (.employment, ["employment", "arbeitsvertrag", "contrat de travail", "salary", "lohn",
                            "salaire", "employer", "arbeitgeber", "employeur", "termination notice"]),
            (.education, ["diploma", "certificate", "transcript", "grade", "university", "school",
                           "diplom", "diplôme", "zeugnis", "attestation"]),
            (.warranty, ["warranty", "garantie", "guaranteed", "return policy", "product registration"]),
            (.government, ["federal", "cantonal", "commune", "municipality", "bund", "kanton",
                            "commune", "official notice", "amtlich"]),
            (.invoice, ["invoice", "rechnung", "facture", "billing", "amount due", "payment due",
                          "reference number", "qr-bill", "einzahlungsschein"]),
            (.bill, ["bill", "utility", "electricity", "gas", "water", "internet", "mobile",
                      "subscription", "monthly", "abonnement"]),
            (.receipt, ["receipt", "quittung", "reçu", "total", "paid", "change", "thank you for your purchase",
                         "merci", "danke"]),
            (.correspondence, ["dear", "sincerely", "regards", "sehr geehrte", "cher", "chère",
                                "cordialement", "mit freundlichen grüssen"])
        ]

        for (category, keywords) in rules {
            let matchCount = keywords.filter { lower.contains($0) }.count
            if matchCount >= 2 {
                return category
            }
        }

        // Single keyword fallback with lower confidence
        for (category, keywords) in rules {
            if keywords.contains(where: { lower.contains($0) }) {
                return category
            }
        }

        return .other
    }

    // MARK: - Amount Extraction

    func extractAmounts(from text: String) -> [ExtractedAmount] {
        var results: [ExtractedAmount] = []

        // Currency patterns: CHF 1'234.56, EUR 1.234,56, $1,234.56, 1234.56 Fr.
        let patterns: [(String, String)] = [
            (#"CHF\s*([\d']+[.,]\d{2})"#, "CHF"),
            (#"([\d']+[.,]\d{2})\s*CHF"#, "CHF"),
            (#"EUR\s*([\d.,]+)"#, "EUR"),
            (#"([\d.,]+)\s*EUR"#, "EUR"),
            (#"€\s*([\d.,]+)"#, "EUR"),
            (#"USD\s*([\d.,]+)"#, "USD"),
            (#"\$\s*([\d,]+\.\d{2})"#, "USD"),
            (#"([\d']+[.,]\d{2})\s*Fr\."#, "CHF"),
            (#"RUB\s*([\d\s]+[.,]\d{2})"#, "RUB"),
            (#"([\d\s]+[.,]\d{2})\s*₽"#, "RUB"),
            (#"GBP\s*([\d.,]+)"#, "GBP"),
            (#"£\s*([\d.,]+)"#, "GBP")
        ]

        for (pattern, currency) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                guard match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: text) else { continue }
                var numStr = String(text[range])
                    .replacingOccurrences(of: "'", with: "")
                    .replacingOccurrences(of: " ", with: "")
                // Handle European decimal comma
                if currency == "EUR" || currency == "RUB" {
                    numStr = numStr.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                }
                if let value = Double(numStr), value > 0.01 && value < 10_000_000 {
                    // Extract context label (text around the amount)
                    let label = extractAmountLabel(text: text, matchRange: match.range)
                    results.append(ExtractedAmount(value: value, currency: currency, label: label))
                }
            }
        }

        // Deduplicate by value+currency
        var seen = Set<String>()
        return results.filter { amt in
            let key = "\(amt.currency)\(String(format: "%.2f", amt.value))"
            return seen.insert(key).inserted
        }
    }

    private func extractAmountLabel(text: String, matchRange: NSRange) -> String? {
        guard let range = Range(matchRange, in: text) else { return nil }
        let lineStart = text[..<range.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        let lineEnd = text[range.upperBound...].firstIndex(of: "\n") ?? text.endIndex
        let line = String(text[lineStart..<lineEnd]).trimmingCharacters(in: .whitespaces)
        // Remove the amount itself to get the label
        let cleaned = line.replacingOccurrences(of: String(text[range]), with: "").trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? nil : String(cleaned.prefix(80))
    }

    // MARK: - Date Extraction

    func extractDate(from text: String) -> Date? {
        let patterns: [(String, String)] = [
            (#"\b(\d{2})[./](\d{2})[./](\d{4})\b"#, "dd/MM/yyyy"),
            (#"\b(\d{4})-(\d{2})-(\d{2})\b"#, "yyyy-MM-dd"),
            (#"\b(\d{1,2})\.\s*(Januar|Februar|März|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember)\s+(\d{4})\b"#, "de"),
            (#"\b(\d{1,2})\s+(janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre)\s+(\d{4})\b"#, "fr"),
            (#"\b(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4})\b"#, "en")
        ]

        for (pattern, format) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range, in: text) else { continue }

            let dateStr = String(text[range])

            if format == "dd/MM/yyyy" || format == "yyyy-MM-dd" {
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "en_US_POSIX")
                // Normalize separators
                let normalized = dateStr.replacingOccurrences(of: ".", with: "/")
                fmt.dateFormat = format
                if let date = fmt.date(from: normalized) { return date }
            } else {
                // Named month patterns
                let fmt = DateFormatter()
                switch format {
                case "de": fmt.locale = Locale(identifier: "de_CH")
                case "fr": fmt.locale = Locale(identifier: "fr_CH")
                default: fmt.locale = Locale(identifier: "en_US")
                }
                fmt.dateFormat = "d MMMM yyyy"
                if let date = fmt.date(from: dateStr) { return date }
            }
        }

        return nil
    }

    // MARK: - Sender Extraction

    func extractSender(from text: String) -> String? {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        // Common sender patterns: first non-empty line, or after "From:"
        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix("from:") || lower.hasPrefix("von:") || lower.hasPrefix("de:") || lower.hasPrefix("expéditeur:") {
                let sender = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                if !sender.isEmpty { return String(sender.prefix(100)) }
            }
        }
        // Fallback: first non-empty, non-date line as sender (typically letterhead)
        for line in lines.prefix(5) {
            if !line.isEmpty && line.count > 3 && line.count < 100 {
                // Skip lines that look like dates or amounts
                let lower = line.lowercased()
                if lower.contains("chf") || lower.contains("eur") || lower.contains("total") { continue }
                if line.allSatisfy({ $0.isNumber || $0 == "." || $0 == "/" || $0 == "-" || $0 == " " }) { continue }
                return line
            }
        }
        return nil
    }

    // MARK: - Full Document Processing

    func processImage(data: Data, filename: String = "scan") async throws -> ScannedDocument {
        isProcessing = true
        defer { isProcessing = false }

        dsLogger.info("Processing image: \(filename)")

        // Perform OCR
        let extractedText = try await performOCR(on: data)

        // Save image
        let imageID = UUID().uuidString
        let imagePath = imagesDir.appendingPathComponent("\(imageID).png")
        try data.write(to: imagePath)

        // Classify and extract
        let category = classifyDocument(extractedText)
        let amounts = extractAmounts(from: extractedText)
        let docDate = extractDate(from: extractedText)
        let sender = extractSender(from: extractedText)

        // Generate summary (first 200 chars of meaningful text)
        let summaryText = extractedText
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .prefix(5)
            .joined(separator: " ")
        let summary = String(summaryText.prefix(200))

        // Generate title
        let title = generateTitle(category: category, sender: sender, date: docDate, filename: filename)

        // Auto-tag
        var tags = [category.rawValue.lowercased()]
        if let sender { tags.append(sender.lowercased().prefix(30).description) }
        if !amounts.isEmpty { tags.append("has-amounts") }

        let doc = ScannedDocument(
            title: title,
            category: category,
            extractedText: extractedText,
            summary: summary,
            sender: sender,
            documentDate: docDate,
            amounts: amounts,
            tags: tags,
            imagePaths: [imagePath.lastPathComponent],
            pageCount: 1
        )

        documents.insert(doc, at: 0)
        saveDocuments()

        dsLogger.info("Document processed: \(title) (\(category.rawValue))")
        return doc
    }

    func processPDF(at url: URL) async throws -> ScannedDocument {
        isProcessing = true
        defer { isProcessing = false }

        dsLogger.info("Processing PDF: \(url.lastPathComponent)")

        let (extractedText, pageCount) = try await performOCROnPDF(at: url)

        // Copy PDF to storage
        let pdfID = UUID().uuidString
        let pdfDest = imagesDir.appendingPathComponent("\(pdfID).pdf")
        try FileManager.default.copyItem(at: url, to: pdfDest)

        let category = classifyDocument(extractedText)
        let amounts = extractAmounts(from: extractedText)
        let docDate = extractDate(from: extractedText)
        let sender = extractSender(from: extractedText)

        let summaryText = extractedText
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .prefix(5)
            .joined(separator: " ")
        let summary = String(summaryText.prefix(200))

        let title = generateTitle(
            category: category,
            sender: sender,
            date: docDate,
            filename: url.deletingPathExtension().lastPathComponent
        )

        var tags = [category.rawValue.lowercased(), "pdf"]
        if let sender { tags.append(sender.lowercased().prefix(30).description) }
        if !amounts.isEmpty { tags.append("has-amounts") }

        let doc = ScannedDocument(
            title: title,
            category: category,
            extractedText: extractedText,
            summary: summary,
            sender: sender,
            documentDate: docDate,
            amounts: amounts,
            tags: tags,
            imagePaths: [pdfDest.lastPathComponent],
            pageCount: pageCount
        )

        documents.insert(doc, at: 0)
        saveDocuments()

        dsLogger.info("PDF processed: \(title) (\(pageCount) pages)")
        return doc
    }

    private func generateTitle(category: DocumentCategory, sender: String?, date: Date?, filename: String) -> String {
        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .medium
        dateFmt.timeStyle = .none

        var parts: [String] = [category.rawValue]
        if let sender { parts.append(String(sender.prefix(40))) }
        if let date { parts.append(dateFmt.string(from: date)) }
        if parts.count == 1 { parts.append(filename) }
        return parts.joined(separator: " — ")
    }

    // MARK: - CRUD

    func updateDocument(_ updated: ScannedDocument) {
        guard let index = documents.firstIndex(where: { $0.id == updated.id }) else { return }
        var doc = updated
        doc.modifiedAt = Date()
        documents[index] = doc
        saveDocuments()
    }

    func deleteDocument(_ id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        let doc = documents[index]
        // Clean up stored files
        for path in doc.imagePaths {
            let fileURL = imagesDir.appendingPathComponent(path)
            try? FileManager.default.removeItem(at: fileURL)
        }
        documents.remove(at: index)
        saveDocuments()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[index].isFavorite.toggle()
        documents[index].modifiedAt = Date()
        saveDocuments()
    }

    // MARK: - Search

    func search(query: String) -> [ScannedDocument] {
        let lower = query.lowercased()
        return documents.filter { doc in
            doc.title.lowercased().contains(lower) ||
            doc.extractedText.lowercased().contains(lower) ||
            doc.category.rawValue.lowercased().contains(lower) ||
            doc.tags.contains(where: { $0.contains(lower) }) ||
            (doc.sender?.lowercased().contains(lower) ?? false)
        }
    }

    func documentsForCategory(_ category: DocumentCategory) -> [ScannedDocument] {
        documents.filter { $0.category == category }
    }

    // MARK: - Export

    func exportAsText(_ document: ScannedDocument) -> String {
        var result = "# \(document.title)\n\n"
        result += "Category: \(document.category.rawValue)\n"
        if let sender = document.sender { result += "From: \(sender)\n" }
        if let date = document.documentDate {
            let fmt = DateFormatter()
            fmt.dateStyle = .long
            result += "Date: \(fmt.string(from: date))\n"
        }
        if !document.amounts.isEmpty {
            result += "Amounts:\n"
            for amt in document.amounts {
                result += "  - \(amt.formatted)"
                if let label = amt.label { result += " (\(label))" }
                result += "\n"
            }
        }
        result += "\n---\n\n"
        result += document.extractedText
        return result
    }

    // MARK: - Statistics

    var totalDocuments: Int { documents.count }
    var favoriteCount: Int { documents.filter(\.isFavorite).count }

    var categoryCounts: [(DocumentCategory, Int)] {
        var counts: [DocumentCategory: Int] = [:]
        for doc in documents { counts[doc.category, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }
    }

    func imageURL(for path: String) -> URL {
        imagesDir.appendingPathComponent(path)
    }
}
