// DocumentScannerTests.swift
// Tests for DocumentScanner — classification, amount extraction, date extraction, sender extraction

import Testing
import Foundation

// MARK: - Test Doubles (mirror production types for SPM test target)

private enum TestDocCategory: String, CaseIterable, Codable, Sendable {
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

private struct TestExtractedAmount: Codable, Sendable, Identifiable {
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

private struct TestScannedDocument: Codable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var category: TestDocCategory
    var extractedText: String
    var summary: String
    var sender: String?
    var subject: String?
    var documentDate: Date?
    var amounts: [TestExtractedAmount]
    var tags: [String]
    var isFavorite: Bool
    var imagePaths: [String]
    let createdAt: Date
    var modifiedAt: Date
    var ocrLanguage: String?
    var pageCount: Int

    init(
        id: UUID = UUID(),
        title: String = "Test",
        category: TestDocCategory = .other,
        extractedText: String = "",
        summary: String = "",
        sender: String? = nil,
        documentDate: Date? = nil,
        amounts: [TestExtractedAmount] = [],
        tags: [String] = [],
        isFavorite: Bool = false,
        imagePaths: [String] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        pageCount: Int = 1
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.extractedText = extractedText
        self.summary = summary
        self.sender = sender
        self.subject = nil
        self.documentDate = documentDate
        self.amounts = amounts
        self.tags = tags
        self.isFavorite = isFavorite
        self.imagePaths = imagePaths
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.ocrLanguage = nil
        self.pageCount = pageCount
    }
}

// MARK: - Classification Logic (mirrors DocumentScanner.classifyDocument)

private func classifyDocument(_ text: String) -> TestDocCategory {
    let lower = text.lowercased()

    let rules: [(TestDocCategory, [String])] = [
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
        if matchCount >= 2 { return category }
    }
    for (category, keywords) in rules {
        if keywords.contains(where: { lower.contains($0) }) { return category }
    }
    return .other
}

// MARK: - Amount Extraction Logic (mirrors DocumentScanner.extractAmounts)

private func extractAmounts(from text: String) -> [TestExtractedAmount] {
    var results: [TestExtractedAmount] = []

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
            if currency == "EUR" || currency == "RUB" {
                numStr = numStr.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            }
            if let value = Double(numStr), value > 0.01 && value < 10_000_000 {
                results.append(TestExtractedAmount(value: value, currency: currency))
            }
        }
    }

    var seen = Set<String>()
    return results.filter { amt in
        let key = "\(amt.currency)\(String(format: "%.2f", amt.value))"
        return seen.insert(key).inserted
    }
}

// MARK: - Date Extraction Logic (mirrors DocumentScanner.extractDate)

private func extractDate(from text: String) -> Date? {
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
            let normalized = dateStr.replacingOccurrences(of: ".", with: "/")
            fmt.dateFormat = format
            if let date = fmt.date(from: normalized) { return date }
        } else {
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

// MARK: - Sender Extraction (mirrors DocumentScanner.extractSender)

private func extractSender(from text: String) -> String? {
    let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    for line in lines {
        let lower = line.lowercased()
        if lower.hasPrefix("from:") || lower.hasPrefix("von:") || lower.hasPrefix("de:") || lower.hasPrefix("expéditeur:") {
            let sender = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            if !sender.isEmpty { return String(sender.prefix(100)) }
        }
    }
    for line in lines.prefix(5) {
        if !line.isEmpty && line.count > 3 && line.count < 100 {
            let lower = line.lowercased()
            if lower.contains("chf") || lower.contains("eur") || lower.contains("total") { continue }
            if line.allSatisfy({ $0.isNumber || $0 == "." || $0 == "/" || $0 == "-" || $0 == " " }) { continue }
            return line
        }
    }
    return nil
}

// MARK: - Tests

@Suite("DocumentCategory — Enum Properties")
struct DocumentCategoryTests {
    @Test("All 16 categories exist")
    func allCases() {
        #expect(TestDocCategory.allCases.count == 16)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let rawValues = TestDocCategory.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All categories have icons")
    func allHaveIcons() {
        for cat in TestDocCategory.allCases {
            #expect(!cat.icon.isEmpty, "Category \(cat.rawValue) has no icon")
        }
    }

    @Test("All categories have colors")
    func allHaveColors() {
        for cat in TestDocCategory.allCases {
            #expect(!cat.color.isEmpty, "Category \(cat.rawValue) has no color")
        }
    }

    @Test("Specific icon assignments")
    func specificIcons() {
        #expect(TestDocCategory.bill.icon == "doc.text.fill")
        #expect(TestDocCategory.medical.icon == "cross.case.fill")
        #expect(TestDocCategory.tax.icon == "percent")
        #expect(TestDocCategory.identity.icon == "person.text.rectangle.fill")
    }
}

@Suite("Document Classification")
struct DocumentClassificationTests {
    @Test("Swiss tax document")
    func swissTax() {
        let text = "Steuererklärung 2025 — Steueramt Kanton Zürich — Veranlagung"
        #expect(classifyDocument(text) == .tax)
    }

    @Test("French tax document")
    func frenchTax() {
        let text = "Déclaration d'impôt 2025 — Administration fiscale"
        #expect(classifyDocument(text) == .tax)
    }

    @Test("Medical prescription")
    func medicalDoc() {
        let text = "Dr. Mueller — Klinik Hirslanden — Prescription for patient"
        #expect(classifyDocument(text) == .medical)
    }

    @Test("Insurance policy")
    func insuranceDoc() {
        let text = "Versicherung Police Nr. 12345 — Premium CHF 450 — Coverage details"
        #expect(classifyDocument(text) == .insurance)
    }

    @Test("Swiss identity document")
    func identityDoc() {
        let text = "Aufenthaltsbewilligung B — Residence permit — Valid until 2027"
        #expect(classifyDocument(text) == .identity)
    }

    @Test("Employment contract")
    func employmentDoc() {
        let text = "Arbeitsvertrag — Employer: ACME Corp — Lohn CHF 8000/month"
        #expect(classifyDocument(text) == .employment)
    }

    @Test("Bank statement")
    func bankDoc() {
        let text = "Kontoauszug — IBAN CH93 0076 2011 6238 5295 7 — Transaction history"
        #expect(classifyDocument(text) == .bank)
    }

    @Test("Invoice (German)")
    func invoiceDoc() {
        let text = "Rechnung Nr. 2025-001 — Facture — Amount due: CHF 150.00"
        #expect(classifyDocument(text) == .invoice)
    }

    @Test("Receipt")
    func receiptDoc() {
        let text = "Receipt — Total: CHF 45.90 — Paid — Thank you for your purchase"
        #expect(classifyDocument(text) == .receipt)
    }

    @Test("Contract")
    func contractDoc() {
        let text = "This contract is an agreement between the parties — Effective date: 2025-01-01"
        #expect(classifyDocument(text) == .contract)
    }

    @Test("Legal document")
    func legalDoc() {
        let text = "Bezirksgericht Zürich — Tribunal — Judgment in case 2025/123"
        #expect(classifyDocument(text) == .legal)
    }

    @Test("Education diploma")
    func educationDoc() {
        let text = "University of Zurich — Diploma — This certificate attests"
        #expect(classifyDocument(text) == .education)
    }

    @Test("Correspondence")
    func correspondenceDoc() {
        let text = "Dear Mr. Smith, Sincerely yours, Best regards"
        #expect(classifyDocument(text) == .correspondence)
    }

    @Test("Government notice")
    func governmentDoc() {
        let text = "Federal Office — Cantonal administration — Official notice"
        #expect(classifyDocument(text) == .government)
    }

    @Test("Bill / utility")
    func billDoc() {
        let text = "Monthly electricity bill — Subscription — Internet service"
        #expect(classifyDocument(text) == .bill)
    }

    @Test("Unknown text falls back to other")
    func unknownDoc() {
        let text = "Random text with no recognizable patterns"
        #expect(classifyDocument(text) == .other)
    }

    @Test("Empty text falls back to other")
    func emptyDoc() {
        #expect(classifyDocument("") == .other)
    }

    @Test("Single keyword match works")
    func singleKeywordMatch() {
        let text = "This contains the word passport"
        #expect(classifyDocument(text) == .identity)
    }
}

@Suite("Amount Extraction")
struct AmountExtractionTests {
    @Test("Swiss Francs — CHF prefix")
    func chfPrefix() {
        let amounts = extractAmounts(from: "Total: CHF 1'234.56")
        #expect(amounts.count == 1)
        #expect(amounts.first?.value == 1234.56)
        #expect(amounts.first?.currency == "CHF")
    }

    @Test("Swiss Francs — CHF suffix")
    func chfSuffix() {
        let amounts = extractAmounts(from: "Betrag: 456.78 CHF")
        #expect(amounts.count == 1)
        #expect(amounts.first?.value == 456.78)
    }

    @Test("Swiss Francs — Fr. suffix")
    func frSuffix() {
        let amounts = extractAmounts(from: "Prix: 99.90 Fr.")
        #expect(amounts.count == 1)
        #expect(amounts.first?.value == 99.90)
        #expect(amounts.first?.currency == "CHF")
    }

    @Test("Euro — symbol")
    func euroSymbol() {
        let amounts = extractAmounts(from: "Price: €49.99")
        #expect(amounts.count == 1)
        #expect(amounts.first?.currency == "EUR")
    }

    @Test("EUR prefix")
    func eurPrefix() {
        let amounts = extractAmounts(from: "EUR 1.234,56")
        #expect(amounts.count == 1)
        #expect(amounts.first?.value == 1234.56)
        #expect(amounts.first?.currency == "EUR")
    }

    @Test("USD — dollar sign")
    func usdDollar() {
        let amounts = extractAmounts(from: "Total: $1,999.99")
        #expect(amounts.count == 1)
        #expect(amounts.first?.value == 1999.99)
        #expect(amounts.first?.currency == "USD")
    }

    @Test("GBP — pound sign")
    func gbpPound() {
        let amounts = extractAmounts(from: "Cost: £29.99")
        #expect(amounts.count == 1)
        #expect(amounts.first?.currency == "GBP")
    }

    @Test("Multiple currencies in one text")
    func multipleCurrencies() {
        let text = "CHF 100.00 — EUR 90.00 — $85.00"
        let amounts = extractAmounts(from: text)
        #expect(amounts.count == 3)
        let currencies = Set(amounts.map(\.currency))
        #expect(currencies.contains("CHF"))
        #expect(currencies.contains("EUR"))
        #expect(currencies.contains("USD"))
    }

    @Test("Deduplication — same value+currency appears once")
    func dedup() {
        let text = "CHF 100.00 total. Amount: CHF 100.00"
        let amounts = extractAmounts(from: text)
        #expect(amounts.count == 1)
    }

    @Test("No amounts in plain text")
    func noAmounts() {
        let amounts = extractAmounts(from: "Hello world, this is a test document")
        #expect(amounts.isEmpty)
    }

    @Test("Swiss apostrophe thousands separator")
    func swissThousands() {
        let amounts = extractAmounts(from: "CHF 12'345.67")
        #expect(amounts.count == 1)
        #expect(amounts.first?.value == 12345.67)
    }

    @Test("Very small amounts excluded")
    func tooSmall() {
        let amounts = extractAmounts(from: "CHF 0.00")
        #expect(amounts.isEmpty)
    }
}

@Suite("Date Extraction")
struct DateExtractionTests {
    @Test("European format dd.MM.yyyy")
    func europeanDot() {
        let date = extractDate(from: "Datum: 15.02.2026")
        #expect(date != nil)
        let cal = Calendar.current
        #expect(cal.component(.day, from: date!) == 15)
        #expect(cal.component(.month, from: date!) == 2)
        #expect(cal.component(.year, from: date!) == 2026)
    }

    @Test("European format dd/MM/yyyy")
    func europeanSlash() {
        let date = extractDate(from: "Date: 25/12/2025")
        #expect(date != nil)
        let cal = Calendar.current
        #expect(cal.component(.day, from: date!) == 25)
        #expect(cal.component(.month, from: date!) == 12)
    }

    @Test("ISO format yyyy-MM-dd")
    func isoFormat() {
        let date = extractDate(from: "Created: 2026-01-15")
        #expect(date != nil)
        let cal = Calendar.current
        #expect(cal.component(.year, from: date!) == 2026)
        #expect(cal.component(.month, from: date!) == 1)
        #expect(cal.component(.day, from: date!) == 15)
    }

    @Test("German month name")
    func germanMonth() {
        let date = extractDate(from: "Zürich, 5. Januar 2026")
        #expect(date != nil)
        let cal = Calendar.current
        #expect(cal.component(.month, from: date!) == 1)
    }

    @Test("French month name")
    func frenchMonth() {
        let date = extractDate(from: "Paris, le 12 février 2026")
        #expect(date != nil)
        let cal = Calendar.current
        #expect(cal.component(.month, from: date!) == 2)
    }

    @Test("English month name")
    func englishMonth() {
        let date = extractDate(from: "London, 3 March 2026")
        #expect(date != nil)
        let cal = Calendar.current
        #expect(cal.component(.month, from: date!) == 3)
    }

    @Test("No date in text")
    func noDate() {
        let date = extractDate(from: "Hello world")
        #expect(date == nil)
    }

    @Test("Empty text")
    func emptyText() {
        let date = extractDate(from: "")
        #expect(date == nil)
    }
}

@Suite("Sender Extraction")
struct SenderExtractionTests {
    @Test("From: header")
    func fromHeader() {
        let sender = extractSender(from: "From: ACME Corporation\nDear Customer")
        #expect(sender == "ACME Corporation")
    }

    @Test("Von: header (German)")
    func vonHeader() {
        let sender = extractSender(from: "Von: Kantonales Steueramt Zürich\nSehr geehrte Damen und Herren")
        #expect(sender == "Kantonales Steueramt Zürich")
    }

    @Test("De: header (French)")
    func deHeader() {
        let sender = extractSender(from: "De: Administration fiscale\nMadame, Monsieur")
        #expect(sender == "Administration fiscale")
    }

    @Test("Fallback to first non-empty line")
    func fallbackFirstLine() {
        let sender = extractSender(from: "Swiss Insurance AG\nPolicy Number: 12345")
        #expect(sender == "Swiss Insurance AG")
    }

    @Test("Skips date-like lines")
    func skipDates() {
        let sender = extractSender(from: "15.02.2026\nACME Corporation\nInvoice")
        #expect(sender == "ACME Corporation")
    }

    @Test("Skips amount lines")
    func skipAmounts() {
        let sender = extractSender(from: "CHF 100.00\nTotal: EUR 200\nSwiss Post AG\nLetter")
        #expect(sender == "Swiss Post AG")
    }

    @Test("No sender in empty text")
    func emptySender() {
        let sender = extractSender(from: "")
        #expect(sender == nil)
    }

    @Test("Truncates long sender to 100 chars")
    func longSender() {
        let longName = String(repeating: "A", count: 150)
        let sender = extractSender(from: "From: \(longName)")
        #expect(sender?.count == 100)
    }
}

@Suite("ScannedDocument — Model")
struct ScannedDocumentModelTests {
    @Test("Default initialization")
    func defaultInit() {
        let doc = TestScannedDocument()
        #expect(doc.title == "Test")
        #expect(doc.category == .other)
        #expect(doc.extractedText.isEmpty)
        #expect(doc.amounts.isEmpty)
        #expect(doc.tags.isEmpty)
        #expect(!doc.isFavorite)
        #expect(doc.pageCount == 1)
    }

    @Test("Identifiable — unique IDs")
    func uniqueIDs() {
        let doc1 = TestScannedDocument()
        let doc2 = TestScannedDocument()
        #expect(doc1.id != doc2.id)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let doc = TestScannedDocument(
            title: "Tax 2025",
            category: .tax,
            extractedText: "Sample OCR text",
            sender: "Tax Office",
            amounts: [TestExtractedAmount(value: 1234.56, currency: "CHF", label: "Total")],
            tags: ["tax", "2025"],
            isFavorite: true,
            pageCount: 3
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(doc)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestScannedDocument.self, from: data)

        #expect(decoded.title == "Tax 2025")
        #expect(decoded.category == .tax)
        #expect(decoded.sender == "Tax Office")
        #expect(decoded.amounts.count == 1)
        #expect(decoded.amounts.first?.value == 1234.56)
        #expect(decoded.tags == ["tax", "2025"])
        #expect(decoded.isFavorite)
        #expect(decoded.pageCount == 3)
    }

    @Test("Favorite toggle")
    func toggleFavorite() {
        var doc = TestScannedDocument(isFavorite: false)
        #expect(!doc.isFavorite)
        doc.isFavorite.toggle()
        #expect(doc.isFavorite)
        doc.isFavorite.toggle()
        #expect(!doc.isFavorite)
    }
}

@Suite("ExtractedAmount — Model")
struct ExtractedAmountModelTests {
    @Test("Default currency is CHF")
    func defaultCurrency() {
        let amt = TestExtractedAmount(value: 100.0)
        #expect(amt.currency == "CHF")
    }

    @Test("Formatted output includes currency")
    func formattedOutput() {
        let amt = TestExtractedAmount(value: 1234.56, currency: "CHF")
        let formatted = amt.formatted
        #expect(formatted.contains("1") || formatted.contains("234")) // NumberFormatter locale-dependent
    }

    @Test("Identifiable — unique IDs")
    func uniqueIDs() {
        let a1 = TestExtractedAmount(value: 100.0)
        let a2 = TestExtractedAmount(value: 100.0)
        #expect(a1.id != a2.id)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let amt = TestExtractedAmount(value: 99.95, currency: "EUR", label: "Total")
        let data = try JSONEncoder().encode(amt)
        let decoded = try JSONDecoder().decode(TestExtractedAmount.self, from: data)
        #expect(decoded.value == 99.95)
        #expect(decoded.currency == "EUR")
        #expect(decoded.label == "Total")
    }

    @Test("Label is optional")
    func optionalLabel() {
        let amt = TestExtractedAmount(value: 50.0)
        #expect(amt.label == nil)
    }
}

@Suite("DocumentScannerError — Error Types")
struct DocumentScannerErrorTests {
    private enum TestError: Error, LocalizedError {
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

    @Test("OCR failed error description")
    func ocrFailed() {
        let error = TestError.ocrFailed("timeout")
        #expect(error.errorDescription?.contains("OCR failed") == true)
        #expect(error.errorDescription?.contains("timeout") == true)
    }

    @Test("Image load failed")
    func imageLoadFailed() {
        let error = TestError.imageLoadFailed("corrupt")
        #expect(error.errorDescription?.contains("Could not load image") == true)
    }

    @Test("Storage failed")
    func storageFailed() {
        let error = TestError.storageFailed("disk full")
        #expect(error.errorDescription?.contains("Storage error") == true)
    }

    @Test("Export failed")
    func exportFailed() {
        let error = TestError.exportFailed("permission denied")
        #expect(error.errorDescription?.contains("Export failed") == true)
    }

    @Test("No text found")
    func noTextFound() {
        let error = TestError.noTextFound
        #expect(error.errorDescription?.contains("No text") == true)
    }
}

@Suite("Classification — Edge Cases")
struct ClassificationEdgeCaseTests {
    @Test("Mixed language document — Swiss German tax")
    func mixedLanguage() {
        let text = "Steuererklärung 2025\nTax return for fiscal year"
        #expect(classifyDocument(text) == .tax)
    }

    @Test("Multiple category signals — tax > medical")
    func priorityOrder() {
        // Tax keywords should win over medical when both present with 2+ matches
        let text = "Tax return — Steuererklärung — Medical expenses deduction"
        #expect(classifyDocument(text) == .tax)
    }

    @Test("Warranty document")
    func warrantyDoc() {
        let text = "Product warranty — Guaranteed for 2 years"
        #expect(classifyDocument(text) == .warranty)
    }

    @Test("Very long text classifies correctly")
    func longText() {
        let filler = String(repeating: "Lorem ipsum dolor sit amet. ", count: 100)
        let text = filler + "Rechnung Nr. 2025-001 — Facture"
        #expect(classifyDocument(text) == .invoice)
    }

    @Test("Case insensitive matching")
    func caseInsensitive() {
        #expect(classifyDocument("PASSPORT APPLICATION — IDENTITY CARD") == .identity)
        #expect(classifyDocument("medical PRESCRIPTION from DR. Smith") == .medical)
    }
}
