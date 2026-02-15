// PhysicalMailChannel.swift
// Thea — Physical mail scanning channel for MessagingHub
//
// Bridges scanned physical mail into the unified messaging system.
// Uses DocumentScanner's Vision framework OCR for text extraction,
// then creates UnifiedMessages from the extracted content.
//
// Input sources:
// - macOS: File import (PDF, images) — ScanSnap Home integration for auto-import
// - iOS: VisionKit VNDocumentCameraViewController for camera capture
// - Both: Drag-and-drop, share sheet
//
// Privacy: All OCR processing is 100% on-device via Apple Vision framework.

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

private let pmLogger = Logger(subsystem: "ai.thea.app", category: "PhysicalMailChannel")

// MARK: - Physical Mail Item

/// A piece of physical mail that has been scanned and processed.
struct PhysicalMailItem: Codable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let sender: String?
    let receivedDate: Date
    let scannedDate: Date
    let ocrText: String
    let category: MailCategory
    let urgency: MailUrgency
    let amounts: [ExtractedMailAmount]
    let dates: [Date]
    let actionRequired: Bool
    let actionDescription: String?
    let tags: [String]
    let imagePaths: [String]
    var isArchived: Bool
    var notes: String?

    init(
        title: String,
        sender: String? = nil,
        receivedDate: Date = Date(),
        ocrText: String,
        category: MailCategory = .other,
        urgency: MailUrgency = .normal,
        amounts: [ExtractedMailAmount] = [],
        dates: [Date] = [],
        actionRequired: Bool = false,
        actionDescription: String? = nil,
        tags: [String] = [],
        imagePaths: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.sender = sender
        self.receivedDate = receivedDate
        self.scannedDate = Date()
        self.ocrText = ocrText
        self.category = category
        self.urgency = urgency
        self.amounts = amounts
        self.dates = dates
        self.actionRequired = actionRequired
        self.actionDescription = actionDescription
        self.tags = tags
        self.imagePaths = imagePaths
        self.isArchived = false
        self.notes = nil
    }
}

/// Category of physical mail.
enum MailCategory: String, Codable, Sendable, CaseIterable {
    case bill
    case invoice
    case taxDocument
    case insurance
    case bankStatement
    case medical
    case legal
    case government
    case employment
    case personalLetter
    case advertisement
    case warranty
    case other

    var displayName: String {
        switch self {
        case .bill: "Bill"
        case .invoice: "Invoice"
        case .taxDocument: "Tax Document"
        case .insurance: "Insurance"
        case .bankStatement: "Bank Statement"
        case .medical: "Medical"
        case .legal: "Legal"
        case .government: "Government"
        case .employment: "Employment"
        case .personalLetter: "Personal Letter"
        case .advertisement: "Advertisement"
        case .warranty: "Warranty"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .bill: "banknote"
        case .invoice: "doc.text"
        case .taxDocument: "building.columns"
        case .insurance: "shield.lefthalf.filled"
        case .bankStatement: "chart.bar"
        case .medical: "cross.case"
        case .legal: "scale.3d"
        case .government: "building.2"
        case .employment: "briefcase"
        case .personalLetter: "envelope"
        case .advertisement: "megaphone"
        case .warranty: "checkmark.seal"
        case .other: "tray"
        }
    }
}

/// Urgency classification for physical mail.
enum MailUrgency: String, Codable, Sendable, CaseIterable, Comparable {
    case low
    case normal
    case high
    case critical

    static func < (lhs: MailUrgency, rhs: MailUrgency) -> Bool {
        lhs.numericValue < rhs.numericValue
    }

    var numericValue: Int {
        switch self {
        case .low: 0
        case .normal: 1
        case .high: 2
        case .critical: 3
        }
    }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .critical: "Critical"
        }
    }
}

/// An amount extracted from physical mail.
struct ExtractedMailAmount: Codable, Sendable, Identifiable {
    let id: UUID
    let value: Double
    let currency: String
    let label: String?

    init(value: Double, currency: String = "CHF", label: String? = nil) {
        self.id = UUID()
        self.value = value
        self.currency = currency
        self.label = label
    }

    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "\(currency) \(formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value))"
    }
}

// MARK: - Physical Mail Channel

/// Bridges physical mail scanning into MessagingHub.
@MainActor
final class PhysicalMailChannel: ObservableObject {
    static let shared = PhysicalMailChannel()

    // MARK: - Published State

    @Published private(set) var mailItems: [PhysicalMailItem] = []
    @Published private(set) var scanCount = 0
    @Published private(set) var lastScanDate: Date?

    // MARK: - Configuration

    var enabled = true

    /// Folder to watch for auto-import (macOS ScanSnap integration)
    var watchFolderPath: String?

    // MARK: - Private

    private let storageURL: URL
    #if os(macOS)
    private var watchTask: Task<Void, Never>?
    #endif

    // MARK: - Init

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/PhysicalMail", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.storageURL = dir.appendingPathComponent("mail_items.json")
        loadItems()
    }

    // MARK: - Scanning

    /// Process an image (from camera or file) into a physical mail item.
    func processImage(_ imageData: Data, fileName: String? = nil) async -> PhysicalMailItem? {
        guard enabled else { return nil }

        // 1. Perform OCR
        let ocrText = await performOCR(on: imageData)
        guard !ocrText.isEmpty else {
            pmLogger.warning("OCR produced no text from image")
            return nil
        }

        // 2. Classify the mail
        let category = classifyMail(from: ocrText)
        let urgency = classifyUrgency(from: ocrText, category: category)

        // 3. Extract key information
        let sender = extractSender(from: ocrText)
        let amounts = extractAmounts(from: ocrText)
        let dates = extractDates(from: ocrText)
        let title = generateTitle(from: ocrText, category: category, sender: sender)
        let tags = generateTags(category: category, ocrText: ocrText)

        // 4. Determine action requirements
        let (actionRequired, actionDesc) = determineAction(category: category, amounts: amounts, dates: dates)

        // 5. Save image
        let imagePath = saveImage(imageData, fileName: fileName)

        // 6. Create mail item
        let item = PhysicalMailItem(
            title: title,
            sender: sender,
            ocrText: ocrText,
            category: category,
            urgency: urgency,
            amounts: amounts,
            dates: dates,
            actionRequired: actionRequired,
            actionDescription: actionDesc,
            tags: tags,
            imagePaths: imagePath.map { [$0] } ?? []
        )

        mailItems.insert(item, at: 0)
        scanCount += 1
        lastScanDate = Date()
        saveItems()

        // 7. Route to MessagingHub as a UnifiedMessage
        let message = createUnifiedMessage(from: item)
        await MessagingHub.shared.handleIncomingMessage(message)

        pmLogger.info("Processed physical mail: \(item.title) [\(category.rawValue)] — \(amounts.count) amounts found")
        return item
    }

    /// Process a PDF file into one or more physical mail items.
    func processPDF(at url: URL) async -> PhysicalMailItem? {
        guard enabled else { return nil }

        #if canImport(PDFKit)
        guard let document = PDFDocument(url: url) else {
            pmLogger.error("Failed to load PDF: \(url.lastPathComponent)")
            return nil
        }

        // Extract text from all pages
        var fullText = ""
        for pageIndex in 0..<min(document.pageCount, 20) {
            if let page = document.page(at: pageIndex), let text = page.string {
                fullText += text + "\n"
            }
        }

        // If digital text extraction failed, try OCR on rendered pages
        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).count < 50 {
            if let firstPage = document.page(at: 0) {
                let bounds = firstPage.bounds(for: .mediaBox)
                let scale: CGFloat = 2.0
                let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

                #if os(macOS)
                let image = NSImage(size: size)
                image.lockFocus()
                if let ctx = NSGraphicsContext.current?.cgContext {
                    ctx.scaleBy(x: scale, y: scale)
                    firstPage.draw(with: .mediaBox, to: ctx)
                }
                image.unlockFocus()
                if let tiffData = image.tiffRepresentation {
                    fullText = await performOCR(on: tiffData)
                }
                #elseif os(iOS)
                let renderer = UIGraphicsImageRenderer(size: size)
                let uiImage = renderer.image { ctx in
                    ctx.cgContext.scaleBy(x: scale, y: scale)
                    firstPage.draw(with: .mediaBox, to: ctx.cgContext)
                }
                if let pngData = uiImage.pngData() {
                    fullText = await performOCR(on: pngData)
                }
                #endif
            }
        }

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            pmLogger.warning("No text extracted from PDF: \(url.lastPathComponent)")
            return nil
        }

        let category = classifyMail(from: fullText)
        let urgency = classifyUrgency(from: fullText, category: category)
        let sender = extractSender(from: fullText)
        let amounts = extractAmounts(from: fullText)
        let dates = extractDates(from: fullText)
        let title = generateTitle(from: fullText, category: category, sender: sender)
        let tags = generateTags(category: category, ocrText: fullText)
        let (actionRequired, actionDesc) = determineAction(category: category, amounts: amounts, dates: dates)

        let item = PhysicalMailItem(
            title: title,
            sender: sender,
            ocrText: fullText,
            category: category,
            urgency: urgency,
            amounts: amounts,
            dates: dates,
            actionRequired: actionRequired,
            actionDescription: actionDesc,
            tags: tags,
            imagePaths: [url.path]
        )

        mailItems.insert(item, at: 0)
        scanCount += 1
        lastScanDate = Date()
        saveItems()

        let message = createUnifiedMessage(from: item)
        await MessagingHub.shared.handleIncomingMessage(message)

        pmLogger.info("Processed PDF mail: \(item.title) [\(category.rawValue)]")
        return item
        #else
        return nil
        #endif
    }

    // MARK: - OCR

    private func performOCR(on imageData: Data) async -> String {
        return await withCheckedContinuation { continuation in
            #if os(macOS)
            guard let nsImage = NSImage(data: imageData),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else {
                continuation.resume(returning: "")
                return
            }
            #elseif os(iOS)
            guard let uiImage = UIImage(data: imageData),
                  let cgImage = uiImage.cgImage
            else {
                continuation.resume(returning: "")
                return
            }
            #else
            continuation.resume(returning: "")
            return
            #endif

            #if os(macOS) || os(iOS)
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation]
                else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en", "de", "fr", "it", "ru"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                pmLogger.error("OCR failed: \(error.localizedDescription)")
                continuation.resume(returning: "")
            }
            #endif
        }
    }

    // MARK: - Classification

    /// Classify mail by content using keyword matching across multiple languages.
    func classifyMail(from text: String) -> MailCategory {
        let lower = text.lowercased()

        // Priority order: tax > medical > insurance > legal > government > bank > employment > bill > invoice > warranty > personal > advertisement

        let taxKeywords = ["steuererklärung", "steuer", "tax return", "impôt", "taxe", "veranlagung",
                          "steuerverwaltung", "finanzamt", "lohnausweis", "déclaration fiscale",
                          "pilier 3a", "säule 3a", "pillar 3a", "quellensteuer"]
        if taxKeywords.contains(where: { lower.contains($0) }) { return .taxDocument }

        let medicalKeywords = ["diagnose", "diagnosis", "patient", "doctor", "arzt", "médecin",
                              "hospital", "spital", "hôpital", "prescription", "rezept", "ordonnance",
                              "laboratoire", "labor", "krankenkasse", "assurance maladie", "health insurance"]
        if medicalKeywords.contains(where: { lower.contains($0) }) { return .medical }

        let insuranceKeywords = ["versicherung", "assurance", "insurance", "police", "policy",
                                "prämie", "premium", "prime", "schadenfall", "sinistre", "claim",
                                "deckung", "coverage", "couverture", "franchise"]
        if insuranceKeywords.contains(where: { lower.contains($0) }) { return .insurance }

        let legalKeywords = ["rechtsanwalt", "avocat", "attorney", "lawyer", "gericht", "tribunal",
                            "court", "vertrag", "contrat", "contract", "vollmacht", "procuration",
                            "notaire", "notar", "notary", "testament", "urteil", "jugement"]
        if legalKeywords.contains(where: { lower.contains($0) }) { return .legal }

        let govKeywords = ["gemeinde", "commune", "municipality", "canton", "kanton", "bundesamt",
                          "office fédéral", "federal office", "einwohnerkontrolle", "contrôle des habitants",
                          "bürgerrecht", "nationalité", "citizenship", "aufenthaltsbewilligung", "permis de séjour"]
        if govKeywords.contains(where: { lower.contains($0) }) { return .government }

        let bankKeywords = ["kontoauszug", "relevé de compte", "bank statement", "saldo", "balance",
                           "überweisung", "virement", "transfer", "kreditkarte", "carte de crédit",
                           "credit card", "zinsen", "intérêts", "interest", "hypothek", "hypothèque", "mortgage"]
        if bankKeywords.contains(where: { lower.contains($0) }) { return .bankStatement }

        let employmentKeywords = ["arbeitsvertrag", "contrat de travail", "employment contract",
                                 "lohnabrechnung", "fiche de paie", "pay slip", "kündigung",
                                 "résiliation", "termination", "arbeitszeugnis", "certificat de travail",
                                 "reference letter", "sozialversicherung", "avs", "ahv"]
        if employmentKeywords.contains(where: { lower.contains($0) }) { return .employment }

        let billKeywords = ["rechnung", "facture", "bill", "invoice", "zahlbar bis", "payable jusqu'au",
                           "due date", "fällig", "échéance", "einzahlungsschein", "bulletin de versement",
                           "qr-rechnung", "bvr", "esri", "betrag", "montant", "amount"]
        if billKeywords.contains(where: { lower.contains($0) }) { return .bill }

        let invoiceKeywords = ["offerte", "devis", "quote", "angebot", "proposal", "lieferschein",
                              "bon de livraison", "delivery note", "bestellung", "commande", "order"]
        if invoiceKeywords.contains(where: { lower.contains($0) }) { return .invoice }

        let warrantyKeywords = ["garantie", "warranty", "garantieschein", "bon de garantie",
                               "rückgaberecht", "droit de retour", "return policy"]
        if warrantyKeywords.contains(where: { lower.contains($0) }) { return .warranty }

        let personalKeywords = ["liebe", "dear", "cher", "herzlich", "cordialement", "sincerely",
                               "grüsse", "salutations", "greetings"]
        if personalKeywords.contains(where: { lower.contains($0) }) { return .personalLetter }

        let adKeywords = ["angebot", "offre", "offer", "rabatt", "réduction", "discount",
                         "gratis", "gratuit", "free", "aktion", "promotion", "sonderangebot",
                         "werbung", "publicité", "advertisement"]
        if adKeywords.contains(where: { lower.contains($0) }) { return .advertisement }

        return .other
    }

    /// Determine urgency based on content and category.
    func classifyUrgency(from text: String, category: MailCategory) -> MailUrgency {
        let lower = text.lowercased()

        // Critical: legal deadlines, final notices
        let criticalKeywords = ["letzte mahnung", "dernière sommation", "final notice",
                               "zwangsvollstreckung", "poursuites", "foreclosure",
                               "fristablauf", "expiration du délai", "deadline expired"]
        if criticalKeywords.contains(where: { lower.contains($0) }) { return .critical }

        // High: payment due, registration deadlines
        let highKeywords = ["mahnung", "rappel", "reminder", "zahlungsfrist", "délai de paiement",
                           "frist", "délai", "deadline", "dringend", "urgent", "sofort", "immédiatement"]
        if highKeywords.contains(where: { lower.contains($0) }) { return .high }

        // Category-based urgency
        switch category {
        case .legal, .government, .taxDocument:
            return .high
        case .bill, .medical, .insurance, .employment:
            return .normal
        case .advertisement:
            return .low
        default:
            return .normal
        }
    }

    // MARK: - Extraction

    /// Extract sender from OCR text.
    func extractSender(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return nil }

        // Look for "From:", "Von:", "De:" headers
        let fromPrefixes = ["from:", "von:", "de:", "absender:", "expéditeur:"]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            for prefix in fromPrefixes {
                if trimmed.hasPrefix(prefix) {
                    let sender = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    if !sender.isEmpty { return String(sender.prefix(100)) }
                }
            }
        }

        // Fallback: first non-date, non-amount line (likely letterhead)
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count >= 3, trimmed.count <= 80,
               !trimmed.contains("CHF"), !trimmed.contains("EUR"), !trimmed.contains("$"),
               !trimmed.first!.isNumber {
                return trimmed
            }
        }

        return nil
    }

    /// Extract currency amounts from text.
    func extractAmounts(from text: String) -> [ExtractedMailAmount] {
        var amounts: [ExtractedMailAmount] = []
        var seenValues: Set<Double> = []

        let patterns: [(String, String)] = [
            // CHF patterns
            (#"CHF\s*([\d']+\.?\d*)"#, "CHF"),
            (#"([\d']+\.?\d*)\s*CHF"#, "CHF"),
            (#"Fr\.\s*([\d']+\.?\d*)"#, "CHF"),
            // EUR patterns
            (#"EUR\s*([\d.]+,?\d*)"#, "EUR"),
            (#"€\s*([\d.]+,?\d*)"#, "EUR"),
            (#"([\d.]+,?\d*)\s*€"#, "EUR"),
            // USD patterns
            (#"\$\s*([\d,]+\.?\d*)"#, "USD"),
        ]

        for (pattern, currency) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)

            for match in matches {
                guard match.numberOfRanges >= 2,
                      let valueRange = Range(match.range(at: 1), in: text)
                else { continue }

                var valueStr = String(text[valueRange])
                // Handle Swiss apostrophe thousands separator
                valueStr = valueStr.replacingOccurrences(of: "'", with: "")
                // Handle European comma decimal
                if currency == "EUR" {
                    valueStr = valueStr.replacingOccurrences(of: ".", with: "")
                    valueStr = valueStr.replacingOccurrences(of: ",", with: ".")
                } else {
                    valueStr = valueStr.replacingOccurrences(of: ",", with: "")
                }

                if let value = Double(valueStr), value >= 1.0, !seenValues.contains(value) {
                    seenValues.insert(value)
                    amounts.append(ExtractedMailAmount(value: value, currency: currency))
                }
            }
        }

        return amounts.sorted { $0.value > $1.value }
    }

    /// Extract dates from text.
    func extractDates(from text: String) -> [Date] {
        var dates: [Date] = []

        let dateFormats = [
            "dd.MM.yyyy", "dd/MM/yyyy", "yyyy-MM-dd",
            "d. MMMM yyyy", "d MMMM yyyy", "dd MMMM yyyy",
        ]
        let locales = ["de_CH", "fr_CH", "en_US"]

        for format in dateFormats {
            for localeID in locales {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: localeID)

                // Find date-like patterns in text
                let datePattern: String
                switch format {
                case "dd.MM.yyyy":
                    datePattern = #"\b\d{1,2}\.\d{1,2}\.\d{4}\b"#
                case "dd/MM/yyyy":
                    datePattern = #"\b\d{1,2}/\d{1,2}/\d{4}\b"#
                case "yyyy-MM-dd":
                    datePattern = #"\b\d{4}-\d{1,2}-\d{1,2}\b"#
                default:
                    continue
                }

                guard let regex = try? NSRegularExpression(pattern: datePattern) else { continue }
                let range = NSRange(text.startIndex..., in: text)
                for match in regex.matches(in: text, range: range) {
                    guard let matchRange = Range(match.range, in: text) else { continue }
                    let dateStr = String(text[matchRange])
                    if let date = formatter.date(from: dateStr),
                       !dates.contains(where: { abs($0.timeIntervalSince(date)) < 86400 }) {
                        dates.append(date)
                    }
                }
            }
        }

        return dates.sorted()
    }

    // MARK: - Title Generation

    private func generateTitle(from text: String, category: MailCategory, sender: String?) -> String {
        if let sender = sender {
            return "\(category.displayName) from \(sender)"
        }

        let firstLine = text.components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            ?? "Scanned Mail"

        let truncated = firstLine.count > 60 ? String(firstLine.prefix(57)) + "..." : firstLine
        return truncated
    }

    private func generateTags(category: MailCategory, ocrText: String) -> [String] {
        var tags = [category.rawValue]

        let lower = ocrText.lowercased()
        if lower.contains("schweiz") || lower.contains("suisse") || lower.contains("switzerland") { tags.append("swiss") }
        if lower.contains("qr-rechnung") || lower.contains("qr-code") { tags.append("qr-bill") }
        if lower.contains("einschreiben") || lower.contains("recommandé") || lower.contains("registered") { tags.append("registered") }

        return tags
    }

    // MARK: - Action Determination

    private func determineAction(category: MailCategory, amounts: [ExtractedMailAmount], dates: [Date]) -> (Bool, String?) {
        switch category {
        case .bill, .invoice:
            if let amount = amounts.first {
                if let dueDate = dates.last {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    return (true, "Pay \(amount.formatted) by \(formatter.string(from: dueDate))")
                }
                return (true, "Pay \(amount.formatted)")
            }
            return (true, "Review and process payment")

        case .taxDocument:
            return (true, "File or process tax document")

        case .legal, .government:
            if let deadline = dates.last {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return (true, "Respond by \(formatter.string(from: deadline))")
            }
            return (true, "Review and respond")

        case .medical:
            return (true, "Review medical correspondence")

        case .insurance:
            return (amounts.isEmpty ? false : true, amounts.isEmpty ? nil : "Review insurance notice")

        case .advertisement:
            return (false, nil)

        default:
            return (false, nil)
        }
    }

    // MARK: - Image Storage

    private func saveImage(_ data: Data, fileName: String?) -> String? {
        let imagesDir = storageURL
            .deletingLastPathComponent()
            .appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        let name = fileName ?? "\(UUID().uuidString).png"
        let fileURL = imagesDir.appendingPathComponent(name)

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL.path
        } catch {
            pmLogger.error("Failed to save scan image: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Unified Message Bridge

    private func createUnifiedMessage(from item: PhysicalMailItem) -> UnifiedMessage {
        var content = "📬 \(item.title)"
        if let sender = item.sender {
            content += "\nFrom: \(sender)"
        }
        if !item.amounts.isEmpty {
            content += "\nAmounts: \(item.amounts.map(\.formatted).joined(separator: ", "))"
        }
        if let action = item.actionDescription {
            content += "\nAction: \(action)"
        }

        return UnifiedMessage(
            channelType: .physicalMail,
            channelID: "physical_mail",
            senderID: item.sender ?? "unknown",
            senderName: item.sender,
            content: content,
            attachments: item.imagePaths.map {
                UnifiedAttachment(type: .document, localPath: $0)
            },
            metadata: [
                "category": item.category.rawValue,
                "urgency": item.urgency.rawValue,
                "actionRequired": item.actionRequired ? "true" : "false",
            ]
        )
    }

    // MARK: - CRUD

    func archiveItem(_ itemID: UUID) {
        if let index = mailItems.firstIndex(where: { $0.id == itemID }) {
            mailItems[index].isArchived = true
            saveItems()
        }
    }

    func deleteItem(_ itemID: UUID) {
        mailItems.removeAll { $0.id == itemID }
        saveItems()
    }

    var activeItems: [PhysicalMailItem] {
        mailItems.filter { !$0.isArchived }
    }

    var archivedItems: [PhysicalMailItem] {
        mailItems.filter(\.isArchived)
    }

    var actionRequiredItems: [PhysicalMailItem] {
        activeItems.filter(\.actionRequired)
    }

    // MARK: - Search

    func search(_ query: String) -> [PhysicalMailItem] {
        guard !query.isEmpty else { return activeItems }
        let lower = query.lowercased()
        return activeItems.filter {
            $0.title.lowercased().contains(lower) ||
            $0.ocrText.lowercased().contains(lower) ||
            ($0.sender?.lowercased().contains(lower) ?? false) ||
            $0.tags.contains(where: { $0.lowercased().contains(lower) })
        }
    }

    // MARK: - Statistics

    var totalAmount: Double {
        activeItems.flatMap(\.amounts).reduce(0) { $0 + $1.value }
    }

    var categoryBreakdown: [MailCategory: Int] {
        Dictionary(grouping: activeItems, by: \.category).mapValues(\.count)
    }

    // MARK: - Persistence

    private func saveItems() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(mailItems) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }

    private func loadItems() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let items = try? decoder.decode([PhysicalMailItem].self, from: data) {
            self.mailItems = items
        }
    }

    #if os(macOS)
    // MARK: - ScanSnap Folder Watch (macOS)

    /// Start watching a folder for new scanned documents.
    func startWatchingFolder(_ path: String) {
        watchFolderPath = path
        watchTask?.cancel()
        watchTask = Task { [weak self] in
            guard let self else { return }
            var knownFiles: Set<String> = []

            // Initial scan
            let fm = FileManager.default
            if let contents = try? fm.contentsOfDirectory(atPath: path) {
                knownFiles = Set(contents)
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let contents = try? fm.contentsOfDirectory(atPath: path) else { continue }
                let newFiles = Set(contents).subtracting(knownFiles)
                for file in newFiles {
                    let filePath = (path as NSString).appendingPathComponent(file)
                    let url = URL(fileURLWithPath: filePath)
                    let ext = url.pathExtension.lowercased()
                    if ext == "pdf" {
                        _ = await self.processPDF(at: url)
                    } else if ["png", "jpg", "jpeg", "tiff", "heic"].contains(ext) {
                        if let data = try? Data(contentsOf: url) {
                            _ = await self.processImage(data, fileName: file)
                        }
                    }
                }
                knownFiles.formUnion(newFiles)
            }
        }
        pmLogger.info("Watching folder for scans: \(path)")
    }

    /// Stop watching the folder.
    func stopWatchingFolder() {
        watchTask?.cancel()
        watchTask = nil
        watchFolderPath = nil
    }
    #endif
}
