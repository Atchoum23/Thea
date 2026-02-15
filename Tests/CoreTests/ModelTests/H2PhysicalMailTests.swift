// H2PhysicalMailTests.swift
// Tests for H2 Physical Mail Channel types, classification, and extraction logic.
//
// Uses test doubles mirroring PhysicalMailChannel types for SPM test compatibility.

import Testing
import Foundation

// MARK: - Test Doubles

fileprivate enum TestMailCategory: String, CaseIterable, Sendable {
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

fileprivate enum TestMailUrgency: String, CaseIterable, Sendable, Comparable {
    case low
    case normal
    case high
    case critical

    static func < (lhs: TestMailUrgency, rhs: TestMailUrgency) -> Bool {
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
}

fileprivate struct TestExtractedAmount: Identifiable, Sendable {
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

fileprivate struct TestPhysicalMailItem: Identifiable, Sendable {
    let id: UUID
    let title: String
    let sender: String?
    let ocrText: String
    let category: TestMailCategory
    let urgency: TestMailUrgency
    let amounts: [TestExtractedAmount]
    let dates: [Date]
    let actionRequired: Bool
    let actionDescription: String?
    let tags: [String]
    var isArchived: Bool

    init(
        title: String,
        sender: String? = nil,
        ocrText: String = "",
        category: TestMailCategory = .other,
        urgency: TestMailUrgency = .normal,
        amounts: [TestExtractedAmount] = [],
        dates: [Date] = [],
        actionRequired: Bool = false,
        actionDescription: String? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.sender = sender
        self.ocrText = ocrText
        self.category = category
        self.urgency = urgency
        self.amounts = amounts
        self.dates = dates
        self.actionRequired = actionRequired
        self.actionDescription = actionDescription
        self.tags = tags
        self.isArchived = false
    }
}

// MARK: - Classification Logic (mirrors PhysicalMailChannel)

fileprivate enum TestMailClassifier {
    static func classifyMail(from text: String) -> TestMailCategory {
        let lower = text.lowercased()

        let taxKeywords = ["steuererklärung", "steuer", "tax return", "impôt", "taxe", "veranlagung",
                          "steuerverwaltung", "finanzamt", "lohnausweis", "déclaration fiscale",
                          "pilier 3a", "säule 3a", "quellensteuer"]
        if taxKeywords.contains(where: { lower.contains($0) }) { return .taxDocument }

        let medicalKeywords = ["diagnose", "diagnosis", "patient", "doctor", "arzt", "médecin",
                              "hospital", "spital", "hôpital", "prescription", "rezept", "ordonnance",
                              "krankenkasse", "assurance maladie"]
        if medicalKeywords.contains(where: { lower.contains($0) }) { return .medical }

        let insuranceKeywords = ["versicherung", "assurance", "insurance", "police", "policy",
                                "prämie", "premium", "prime", "schadenfall", "sinistre", "claim",
                                "franchise"]
        if insuranceKeywords.contains(where: { lower.contains($0) }) { return .insurance }

        // Employment BEFORE legal — "contrat de travail" should not match legal's "contrat"
        let employmentKeywords = ["arbeitsvertrag", "contrat de travail", "employment contract",
                                 "lohnabrechnung", "fiche de paie", "pay slip", "kündigung",
                                 "résiliation", "arbeitszeugnis", "certificat de travail"]
        if employmentKeywords.contains(where: { lower.contains($0) }) { return .employment }

        let legalKeywords = ["rechtsanwalt", "avocat", "attorney", "lawyer", "gericht", "tribunal",
                            "court", "vertrag", "contrat", "contract", "notaire", "notar", "testament"]
        if legalKeywords.contains(where: { lower.contains($0) }) { return .legal }

        let govKeywords = ["gemeinde", "commune", "municipality", "canton", "kanton", "bundesamt",
                          "office fédéral", "einwohnerkontrolle", "aufenthaltsbewilligung", "permis de séjour"]
        if govKeywords.contains(where: { lower.contains($0) }) { return .government }

        let bankKeywords = ["kontoauszug", "relevé de compte", "bank statement", "saldo", "balance",
                           "überweisung", "virement", "kreditkarte", "carte de crédit",
                           "credit card", "hypothek", "hypothèque", "mortgage"]
        if bankKeywords.contains(where: { lower.contains($0) }) { return .bankStatement }

        // Advertisement BEFORE invoice — "sonderangebot" contains "angebot"
        let adKeywords = ["sonderangebot", "rabatt", "réduction", "discount", "gratis", "gratuit", "free",
                         "aktion", "promotion", "werbung", "publicité"]
        if adKeywords.contains(where: { lower.contains($0) }) { return .advertisement }

        let billKeywords = ["rechnung", "facture", "bill", "zahlbar bis", "payable jusqu'au",
                           "due date", "fällig", "échéance", "einzahlungsschein",
                           "qr-rechnung", "betrag", "montant", "amount"]
        if billKeywords.contains(where: { lower.contains($0) }) { return .bill }

        let invoiceKeywords = ["offerte", "devis", "quote", "angebot", "lieferschein",
                              "bon de livraison", "delivery note", "bestellung", "commande"]
        if invoiceKeywords.contains(where: { lower.contains($0) }) { return .invoice }

        let warrantyKeywords = ["garantie", "warranty", "garantieschein", "rückgaberecht"]
        if warrantyKeywords.contains(where: { lower.contains($0) }) { return .warranty }

        let personalKeywords = ["liebe", "dear", "cher", "herzlich", "cordialement", "sincerely"]
        if personalKeywords.contains(where: { lower.contains($0) }) { return .personalLetter }

        return .other
    }

    static func classifyUrgency(from text: String, category: TestMailCategory) -> TestMailUrgency {
        let lower = text.lowercased()

        let criticalKeywords = ["letzte mahnung", "dernière sommation", "final notice",
                               "zwangsvollstreckung", "poursuites", "fristablauf"]
        if criticalKeywords.contains(where: { lower.contains($0) }) { return .critical }

        let highKeywords = ["mahnung", "rappel", "reminder", "zahlungsfrist", "délai de paiement",
                           "dringend", "urgent", "sofort", "immédiatement"]
        if highKeywords.contains(where: { lower.contains($0) }) { return .high }

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

    static func extractSender(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return nil }

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

    static func extractAmounts(from text: String) -> [TestExtractedAmount] {
        var amounts: [TestExtractedAmount] = []
        var seenValues: Set<Double> = []

        let patterns: [(String, String)] = [
            (#"CHF\s*([\d']+\.?\d*)"#, "CHF"),
            (#"([\d']+\.?\d*)\s*CHF"#, "CHF"),
            (#"Fr\.\s*([\d']+\.?\d*)"#, "CHF"),
            (#"EUR\s*([\d.]+,?\d*)"#, "EUR"),
            (#"€\s*([\d.]+,?\d*)"#, "EUR"),
            (#"([\d.]+,?\d*)\s*€"#, "EUR"),
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
                valueStr = valueStr.replacingOccurrences(of: "'", with: "")
                if currency == "EUR" {
                    valueStr = valueStr.replacingOccurrences(of: ".", with: "")
                    valueStr = valueStr.replacingOccurrences(of: ",", with: ".")
                } else {
                    valueStr = valueStr.replacingOccurrences(of: ",", with: "")
                }

                if let value = Double(valueStr), value >= 1.0, !seenValues.contains(value) {
                    seenValues.insert(value)
                    amounts.append(TestExtractedAmount(value: value, currency: currency))
                }
            }
        }

        return amounts.sorted { $0.value > $1.value }
    }

    static func extractDates(from text: String) -> [Date] {
        var dates: [Date] = []

        let dateFormats = ["dd.MM.yyyy", "dd/MM/yyyy", "yyyy-MM-dd"]
        let locales = ["de_CH", "fr_CH", "en_US"]

        for format in dateFormats {
            for localeID in locales {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: localeID)

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
}

// MARK: - Tests

@Suite("H2 PhysicalMail — MailCategory")
struct MailCategoryTests {
    @Test("All 13 categories exist")
    func allCases() {
        #expect(TestMailCategory.allCases.count == 13)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = TestMailCategory.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All have display names")
    func displayNames() {
        for cat in TestMailCategory.allCases {
            #expect(!cat.displayName.isEmpty)
        }
    }

    @Test("All have icons")
    func icons() {
        for cat in TestMailCategory.allCases {
            #expect(!cat.icon.isEmpty)
        }
    }

    @Test("Specific display names")
    func specificNames() {
        #expect(TestMailCategory.bill.displayName == "Bill")
        #expect(TestMailCategory.taxDocument.displayName == "Tax Document")
        #expect(TestMailCategory.bankStatement.displayName == "Bank Statement")
        #expect(TestMailCategory.personalLetter.displayName == "Personal Letter")
    }
}

@Suite("H2 PhysicalMail — MailUrgency")
struct MailUrgencyTests {
    @Test("All 4 urgency levels")
    func allCases() {
        #expect(TestMailUrgency.allCases.count == 4)
    }

    @Test("Comparable ordering")
    func ordering() {
        #expect(TestMailUrgency.low < TestMailUrgency.normal)
        #expect(TestMailUrgency.normal < TestMailUrgency.high)
        #expect(TestMailUrgency.high < TestMailUrgency.critical)
    }

    @Test("Numeric values ascending")
    func numericValues() {
        #expect(TestMailUrgency.low.numericValue == 0)
        #expect(TestMailUrgency.normal.numericValue == 1)
        #expect(TestMailUrgency.high.numericValue == 2)
        #expect(TestMailUrgency.critical.numericValue == 3)
    }
}

@Suite("H2 PhysicalMail — ExtractedAmount")
struct ExtractedAmountTests {
    @Test("Default currency is CHF")
    func defaultCurrency() {
        let amount = TestExtractedAmount(value: 100.0)
        #expect(amount.currency == "CHF")
    }

    @Test("Formatted output")
    func formatted() {
        let amount = TestExtractedAmount(value: 1234.56, currency: "CHF")
        #expect(amount.formatted.contains("CHF"))
        #expect(amount.formatted.contains("1"))
    }

    @Test("Custom currency")
    func customCurrency() {
        let amount = TestExtractedAmount(value: 50.0, currency: "EUR")
        #expect(amount.currency == "EUR")
        #expect(amount.formatted.contains("EUR"))
    }

    @Test("Unique IDs")
    func uniqueIDs() {
        let a1 = TestExtractedAmount(value: 100.0)
        let a2 = TestExtractedAmount(value: 100.0)
        #expect(a1.id != a2.id)
    }

    @Test("Label is optional")
    func optionalLabel() {
        let withLabel = TestExtractedAmount(value: 50.0, label: "Total")
        let withoutLabel = TestExtractedAmount(value: 50.0)
        #expect(withLabel.label == "Total")
        #expect(withoutLabel.label == nil)
    }
}

@Suite("H2 PhysicalMail — MailItem Model")
struct MailItemModelTests {
    @Test("Creation with defaults")
    func defaults() {
        let item = TestPhysicalMailItem(title: "Test Mail")
        #expect(item.title == "Test Mail")
        #expect(item.sender == nil)
        #expect(item.category == .other)
        #expect(item.urgency == .normal)
        #expect(item.amounts.isEmpty)
        #expect(item.dates.isEmpty)
        #expect(item.actionRequired == false)
        #expect(item.isArchived == false)
    }

    @Test("Full construction")
    func fullInit() {
        let item = TestPhysicalMailItem(
            title: "Tax Notice",
            sender: "Steuerverwaltung Zürich",
            ocrText: "Steuer 2025",
            category: .taxDocument,
            urgency: .high,
            amounts: [TestExtractedAmount(value: 5000.0)],
            actionRequired: true,
            actionDescription: "File tax return"
        )
        #expect(item.sender == "Steuerverwaltung Zürich")
        #expect(item.category == .taxDocument)
        #expect(item.urgency == .high)
        #expect(item.amounts.count == 1)
        #expect(item.actionRequired == true)
        #expect(item.actionDescription == "File tax return")
    }

    @Test("Archive toggle")
    func archiveToggle() {
        var item = TestPhysicalMailItem(title: "Mail")
        #expect(item.isArchived == false)
        item.isArchived = true
        #expect(item.isArchived == true)
    }

    @Test("Unique IDs")
    func uniqueIDs() {
        let item1 = TestPhysicalMailItem(title: "A")
        let item2 = TestPhysicalMailItem(title: "B")
        #expect(item1.id != item2.id)
    }
}

@Suite("H2 PhysicalMail — Classification")
struct MailClassificationTests {
    @Test("Swiss tax document (German)")
    func swissTaxDE() {
        let cat = TestMailClassifier.classifyMail(from: "Steuererklärung 2025\nKanton Zürich\nSteuerverwaltung")
        #expect(cat == .taxDocument)
    }

    @Test("Swiss tax document (French)")
    func swissTaxFR() {
        let cat = TestMailClassifier.classifyMail(from: "Déclaration fiscale 2025\nCanton de Vaud")
        #expect(cat == .taxDocument)
    }

    @Test("Medical letter (German)")
    func medicalDE() {
        let cat = TestMailClassifier.classifyMail(from: "Sehr geehrter Patient\nDiagnose: Grippe\nDr. Müller")
        #expect(cat == .medical)
    }

    @Test("Insurance (English)")
    func insuranceEN() {
        let cat = TestMailClassifier.classifyMail(from: "Your insurance policy renewal\nPremium: CHF 200")
        #expect(cat == .insurance)
    }

    @Test("Legal document")
    func legal() {
        let cat = TestMailClassifier.classifyMail(from: "Rechtsanwalt Dr. Weber\nVertrag Nr. 12345")
        #expect(cat == .legal)
    }

    @Test("Government (Swiss)")
    func government() {
        let cat = TestMailClassifier.classifyMail(from: "Gemeinde Horgen\nEinwohnerkontrolle")
        #expect(cat == .government)
    }

    @Test("Bank statement")
    func bank() {
        let cat = TestMailClassifier.classifyMail(from: "Kontoauszug\nSaldo per 31.12.2025: CHF 15'432.50")
        #expect(cat == .bankStatement)
    }

    @Test("Employment (French)")
    func employmentFR() {
        let cat = TestMailClassifier.classifyMail(from: "Contrat de travail\nFiche de paie — Janvier 2026")
        #expect(cat == .employment)
    }

    @Test("Bill (German)")
    func billDE() {
        let cat = TestMailClassifier.classifyMail(from: "Rechnung Nr. 2026-001\nBetrag: CHF 150.00\nZahlbar bis 28.02.2026")
        #expect(cat == .bill)
    }

    @Test("Invoice / quote")
    func invoice() {
        let cat = TestMailClassifier.classifyMail(from: "Offerte Nr. 5678\nAngebot gültig bis 15.03.2026")
        #expect(cat == .invoice)
    }

    @Test("Warranty")
    func warranty() {
        let cat = TestMailClassifier.classifyMail(from: "Garantieschein\nProdukt: MacBook Pro\nGarantie bis 2028")
        #expect(cat == .warranty)
    }

    @Test("Personal letter")
    func personal() {
        let cat = TestMailClassifier.classifyMail(from: "Liebe Alexis,\nWie geht es dir?\nHerzlich, Marie")
        #expect(cat == .personalLetter)
    }

    @Test("Advertisement")
    func advertisement() {
        let cat = TestMailClassifier.classifyMail(from: "SONDERANGEBOT!\n50% Rabatt auf alles\nNur diese Woche!")
        #expect(cat == .advertisement)
    }

    @Test("Unknown text → other")
    func unknown() {
        let cat = TestMailClassifier.classifyMail(from: "Lorem ipsum dolor sit amet")
        #expect(cat == .other)
    }

    @Test("Empty text → other")
    func empty() {
        let cat = TestMailClassifier.classifyMail(from: "")
        #expect(cat == .other)
    }

    @Test("Priority: tax over bill")
    func taxOverBill() {
        let cat = TestMailClassifier.classifyMail(from: "Rechnung der Steuerverwaltung\nSteuer-Betrag: CHF 5000")
        #expect(cat == .taxDocument)
    }

    @Test("Priority: medical over insurance")
    func medicalOverInsurance() {
        let cat = TestMailClassifier.classifyMail(from: "Krankenkasse — Diagnose bestätigt\nVersicherung übernimmt Kosten")
        #expect(cat == .medical)
    }
}

@Suite("H2 PhysicalMail — Urgency Classification")
struct UrgencyClassificationTests {
    @Test("Final notice → critical")
    func criticalGerman() {
        let urgency = TestMailClassifier.classifyUrgency(from: "Letzte Mahnung — sofortige Zahlung erforderlich", category: .bill)
        #expect(urgency == .critical)
    }

    @Test("Critical French")
    func criticalFrench() {
        let urgency = TestMailClassifier.classifyUrgency(from: "Dernière sommation avant poursuites", category: .bill)
        #expect(urgency == .critical)
    }

    @Test("Payment reminder → high")
    func highReminder() {
        let urgency = TestMailClassifier.classifyUrgency(from: "Mahnung: Zahlungsfrist überschritten", category: .bill)
        #expect(urgency == .high)
    }

    @Test("Urgent keyword → high")
    func urgentKeyword() {
        let urgency = TestMailClassifier.classifyUrgency(from: "Dringend: Bitte antworten Sie sofort", category: .other)
        #expect(urgency == .high)
    }

    @Test("Legal → high by category")
    func legalCategory() {
        let urgency = TestMailClassifier.classifyUrgency(from: "Gerichtsentscheid", category: .legal)
        #expect(urgency == .high)
    }

    @Test("Tax → high by category")
    func taxCategory() {
        let urgency = TestMailClassifier.classifyUrgency(from: "Steuerbescheid", category: .taxDocument)
        #expect(urgency == .high)
    }

    @Test("Advertisement → low")
    func adLow() {
        let urgency = TestMailClassifier.classifyUrgency(from: "New products available", category: .advertisement)
        #expect(urgency == .low)
    }

    @Test("Normal bill → normal")
    func normalBill() {
        let urgency = TestMailClassifier.classifyUrgency(from: "Regular monthly bill", category: .bill)
        #expect(urgency == .normal)
    }

    @Test("Personal letter → normal")
    func personalNormal() {
        let urgency = TestMailClassifier.classifyUrgency(from: "Dear friend", category: .personalLetter)
        #expect(urgency == .normal)
    }
}

@Suite("H2 PhysicalMail — Amount Extraction")
struct H2AmountExtractionTests {
    @Test("CHF prefix")
    func chfPrefix() {
        let amounts = TestMailClassifier.extractAmounts(from: "Total: CHF 150.00")
        #expect(amounts.count == 1)
        #expect(amounts.first?.value == 150.0)
        #expect(amounts.first?.currency == "CHF")
    }

    @Test("CHF suffix")
    func chfSuffix() {
        let amounts = TestMailClassifier.extractAmounts(from: "Betrag: 250.50 CHF")
        #expect(amounts.count == 1)
        #expect(amounts.first?.value == 250.50)
    }

    @Test("Swiss apostrophe thousands")
    func swissApostrophe() {
        let amounts = TestMailClassifier.extractAmounts(from: "CHF 12'345.67")
        #expect(amounts.count == 1)
        #expect(amounts.first?.value == 12345.67)
    }

    @Test("Fr. prefix")
    func frPrefix() {
        let amounts = TestMailClassifier.extractAmounts(from: "Fr. 99.90")
        #expect(amounts.count == 1)
        #expect(amounts.first?.value == 99.90)
        #expect(amounts.first?.currency == "CHF")
    }

    @Test("EUR with euro sign")
    func eurSign() {
        let amounts = TestMailClassifier.extractAmounts(from: "€ 75.50")
        #expect(amounts.count == 1)
        #expect(amounts.first?.currency == "EUR")
    }

    @Test("USD dollar sign")
    func usdDollar() {
        let amounts = TestMailClassifier.extractAmounts(from: "Total: $1,999.99")
        #expect(amounts.count == 1)
        #expect(amounts.first?.currency == "USD")
        #expect(amounts.first!.value == 1999.99)
    }

    @Test("Multiple amounts sorted descending")
    func multipleAmounts() {
        let amounts = TestMailClassifier.extractAmounts(from: "CHF 50.00\nCHF 200.00\nCHF 100.00")
        #expect(amounts.count == 3)
        #expect(amounts[0].value == 200.0)
        #expect(amounts[1].value == 100.0)
        #expect(amounts[2].value == 50.0)
    }

    @Test("Deduplication by value")
    func dedup() {
        let amounts = TestMailClassifier.extractAmounts(from: "CHF 100.00\n100.00 CHF")
        #expect(amounts.count == 1)
    }

    @Test("No amounts found")
    func noAmounts() {
        let amounts = TestMailClassifier.extractAmounts(from: "No monetary values here.")
        #expect(amounts.isEmpty)
    }

    @Test("Amounts below 1.0 excluded")
    func belowMinimum() {
        let amounts = TestMailClassifier.extractAmounts(from: "CHF 0.50")
        #expect(amounts.isEmpty)
    }
}

@Suite("H2 PhysicalMail — Date Extraction")
struct H2DateExtractionTests {
    @Test("European dot format")
    func europeanDot() {
        let dates = TestMailClassifier.extractDates(from: "Datum: 15.02.2026")
        #expect(dates.count == 1)
    }

    @Test("European slash format")
    func europeanSlash() {
        let dates = TestMailClassifier.extractDates(from: "Date: 15/02/2026")
        #expect(dates.count == 1)
    }

    @Test("ISO format")
    func isoFormat() {
        let dates = TestMailClassifier.extractDates(from: "Date: 2026-02-15")
        #expect(dates.count == 1)
    }

    @Test("Multiple dates sorted")
    func multipleDates() {
        let dates = TestMailClassifier.extractDates(from: "Frist: 01.03.2026\nErstellt: 15.02.2026")
        #expect(dates.count == 2)
        // Should be sorted ascending
        #expect(dates[0] < dates[1])
    }

    @Test("No dates")
    func noDates() {
        let dates = TestMailClassifier.extractDates(from: "No dates here")
        #expect(dates.isEmpty)
    }

    @Test("Dedup same-day dates")
    func dedupSameDay() {
        let dates = TestMailClassifier.extractDates(from: "15.02.2026\n15/02/2026")
        // Both are the same day, should be deduped
        #expect(dates.count == 1)
    }
}

@Suite("H2 PhysicalMail — Sender Extraction")
struct H2SenderExtractionTests {
    @Test("From header")
    func fromHeader() {
        let sender = TestMailClassifier.extractSender(from: "From: Swisscom AG\nRechnung Nr. 123")
        #expect(sender == "Swisscom AG")
    }

    @Test("Von header (German)")
    func vonHeader() {
        let sender = TestMailClassifier.extractSender(from: "Von: Migros Bank\nKontoauszug")
        #expect(sender == "Migros Bank")
    }

    @Test("De header (French)")
    func deHeader() {
        let sender = TestMailClassifier.extractSender(from: "De: La Poste Suisse\nEnvoi recommandé")
        #expect(sender == "La Poste Suisse")
    }

    @Test("Fallback to first line")
    func fallbackFirstLine() {
        let sender = TestMailClassifier.extractSender(from: "Helvetia Versicherung\nPolice Nr. 456")
        #expect(sender == "Helvetia Versicherung")
    }

    @Test("Skip numeric first line")
    func skipNumeric() {
        let sender = TestMailClassifier.extractSender(from: "12345\nAXA Winterthur\nPrämienrechnung")
        #expect(sender == "AXA Winterthur")
    }

    @Test("Skip amount-like first line")
    func skipAmount() {
        let sender = TestMailClassifier.extractSender(from: "CHF 500.00\nUBS AG\nMitteilung")
        #expect(sender == "UBS AG")
    }

    @Test("Empty text → nil")
    func emptyText() {
        let sender = TestMailClassifier.extractSender(from: "")
        #expect(sender == nil)
    }

    @Test("Long sender truncated to 100 chars")
    func longSender() {
        let longName = String(repeating: "A", count: 200)
        let sender = TestMailClassifier.extractSender(from: "From: \(longName)")
        #expect(sender != nil)
        #expect(sender!.count <= 100)
    }
}

@Suite("H2 PhysicalMail — Item Filtering")
struct ItemFilteringTests {
    @Test("Active items excludes archived")
    func activeExcludesArchived() {
        var items = [
            TestPhysicalMailItem(title: "A"),
            TestPhysicalMailItem(title: "B"),
        ]
        items[1].isArchived = true
        let active = items.filter { !$0.isArchived }
        #expect(active.count == 1)
        #expect(active[0].title == "A")
    }

    @Test("Action required filtering")
    func actionRequired() {
        let items = [
            TestPhysicalMailItem(title: "Bill", actionRequired: true),
            TestPhysicalMailItem(title: "Ad", actionRequired: false),
            TestPhysicalMailItem(title: "Tax", actionRequired: true),
        ]
        let actionItems = items.filter(\.actionRequired)
        #expect(actionItems.count == 2)
    }

    @Test("Category breakdown")
    func categoryBreakdown() {
        let items = [
            TestPhysicalMailItem(title: "A", category: .bill),
            TestPhysicalMailItem(title: "B", category: .bill),
            TestPhysicalMailItem(title: "C", category: .medical),
        ]
        let breakdown = Dictionary(grouping: items, by: \.category).mapValues(\.count)
        #expect(breakdown[.bill] == 2)
        #expect(breakdown[.medical] == 1)
    }

    @Test("Search by sender")
    func searchBySender() {
        let items = [
            TestPhysicalMailItem(title: "Bill", sender: "Swisscom"),
            TestPhysicalMailItem(title: "Tax", sender: "Steuerverwaltung"),
        ]
        let query = "swisscom"
        let results = items.filter { $0.sender?.lowercased().contains(query) ?? false }
        #expect(results.count == 1)
        #expect(results[0].title == "Bill")
    }

    @Test("Search by OCR text")
    func searchByOCR() {
        let items = [
            TestPhysicalMailItem(title: "A", ocrText: "Rechnung für Internet"),
            TestPhysicalMailItem(title: "B", ocrText: "Diagnose vom Arzt"),
        ]
        let query = "internet"
        let results = items.filter { $0.ocrText.lowercased().contains(query) }
        #expect(results.count == 1)
    }
}

@Suite("H2 PhysicalMail — Tags")
struct TagTests {
    @Test("Swiss tag detected")
    func swissTag() {
        let text = "Steuerverwaltung Schweiz"
        let lower = text.lowercased()
        var tags = ["taxDocument"]
        if lower.contains("schweiz") || lower.contains("suisse") || lower.contains("switzerland") {
            tags.append("swiss")
        }
        #expect(tags.contains("swiss"))
    }

    @Test("QR bill tag")
    func qrBillTag() {
        let text = "QR-Rechnung Nr. 12345"
        let lower = text.lowercased()
        var tags: [String] = []
        if lower.contains("qr-rechnung") || lower.contains("qr-code") {
            tags.append("qr-bill")
        }
        #expect(tags.contains("qr-bill"))
    }

    @Test("Registered mail tag")
    func registeredTag() {
        let text = "Einschreiben — Recommandé"
        let lower = text.lowercased()
        var tags: [String] = []
        if lower.contains("einschreiben") || lower.contains("recommandé") || lower.contains("registered") {
            tags.append("registered")
        }
        #expect(tags.contains("registered"))
    }
}
