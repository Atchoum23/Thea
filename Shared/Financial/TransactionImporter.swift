import Foundation
import OSLog

// MARK: - Transaction Importer

/// Imports financial transactions from CSV and OFX files with automatic category detection.
/// Supports Swiss bank exports (PostFinance, UBS, Credit Suisse, Raiffeisen) and generic formats.
@MainActor
@Observable
final class TransactionImporter {
    private let logger = Logger(subsystem: "ai.thea.app", category: "TransactionImporter")
    static let shared = TransactionImporter()

    private(set) var lastImportCount = 0
    private(set) var lastTransactionImportErrors: [TransactionImportError] = []

    private init() {}

    // MARK: - CSV Import

    /// Import transactions from a CSV file.
    /// Auto-detects delimiter (comma, semicolon, tab) and column mapping.
    func importCSV(from url: URL, accountId: UUID, currency: String = "CHF") throws -> [ImportedTransaction] {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw TransactionImportError.invalidEncoding
        }

        let delimiter = detectDelimiter(content)
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count >= 2 else {
            throw TransactionImportError.noDataRows
        }

        let headerLine = lines[0]
        let headers = parseCSVRow(headerLine, delimiter: delimiter).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let mapping = detectColumnMapping(headers)

        guard mapping.dateColumn != nil, mapping.amountColumn != nil else {
            throw TransactionImportError.missingRequiredColumns(missing: [
                mapping.dateColumn == nil ? "date" : nil,
                mapping.amountColumn == nil ? "amount" : nil
            ].compactMap { $0 })
        }

        var transactions: [ImportedTransaction] = []
        var errors: [TransactionImportError] = []

        for lineIndex in 1..<lines.count {
            let fields = parseCSVRow(lines[lineIndex], delimiter: delimiter)
            guard fields.count > 1 else { continue }

            do {
                let transaction = try parseTransaction(fields: fields, mapping: mapping, accountId: accountId, currency: currency)
                transactions.append(transaction)
            } catch {
                errors.append(.parseError(line: lineIndex + 1, detail: error.localizedDescription))
            }
        }

        lastImportCount = transactions.count
        lastTransactionImportErrors = errors
        return transactions
    }

    // MARK: - OFX Import

    /// Import transactions from an OFX/QFX file (Open Financial Exchange).
    func importOFX(from url: URL, accountId: UUID) throws -> [ImportedTransaction] {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw TransactionImportError.invalidEncoding
        }

        var transactions: [ImportedTransaction] = []
        let currency = extractOFXValue(content, tag: "CURDEF") ?? "CHF"

        // Parse STMTTRN blocks
        let transactionBlocks = content.components(separatedBy: "<STMTTRN>").dropFirst()

        for block in transactionBlocks {
            let endIndex = block.range(of: "</STMTTRN>")?.lowerBound ?? block.endIndex
            let txBlock = String(block[block.startIndex..<endIndex])

            let dateStr = extractOFXValue(txBlock, tag: "DTPOSTED")
            let amountStr = extractOFXValue(txBlock, tag: "TRNAMT")
            let name = extractOFXValue(txBlock, tag: "NAME") ?? extractOFXValue(txBlock, tag: "MEMO") ?? "Unknown"
            let trnType = extractOFXValue(txBlock, tag: "TRNTYPE") ?? "OTHER"
            let fitid = extractOFXValue(txBlock, tag: "FITID")

            guard let dateStr, let date = parseOFXDate(dateStr),
                  let amountStr, let amount = Double(amountStr) else {
                continue
            }

            let category = categorizeTransaction(description: name, amount: amount, type: trnType)

            transactions.append(ImportedTransaction(
                id: fitid.map { UUID(uuidString: $0) ?? UUID() } ?? UUID(),
                accountId: accountId,
                date: date,
                amount: amount,
                description: name,
                category: category,
                merchant: extractMerchant(from: name),
                currency: currency,
                isRecurring: false,
                tags: []
            ))
        }

        lastImportCount = transactions.count
        lastTransactionImportErrors = []
        return transactions
    }

    // MARK: - Category Detection

    // periphery:ignore - Reserved: type parameter — kept for API compatibility
    /// AI-ready category detection with rule-based fallback.
    func categorizeTransaction(description: String, amount: Double, type: String = "OTHER") -> String {
        let desc = description.lowercased()

// periphery:ignore - Reserved: type parameter kept for API compatibility

        // Groceries
        if matchesAny(desc, ["migros", "coop", "aldi", "lidl", "denner", "spar", "manor food", "volg", "supermarket", "grocery", "lebensmittel"]) {
            return "Groceries"
        }

        // Transport
        if matchesAny(desc, ["sbb", "tpg", "tl ", "cff", "bls", "zvv", "parking", "parkhaus", "shell", "bp ", "avia", "coop pronto", "uber", "taxi", "fuel", "benzin", "diesel", "autobahnvignette"]) {
            return "Transport"
        }

        // Dining
        if matchesAny(desc, ["restaurant", "mcdonald", "burger", "pizza", "starbucks", "cafe", "bistro", "takeaway", "eat.ch", "uber eats", "just eat"]) {
            return "Dining"
        }

        // Subscriptions
        if matchesAny(desc, ["netflix", "spotify", "apple", "google", "amazon prime", "disney", "youtube", "adobe", "microsoft", "dropbox", "icloud", "swisscom", "sunrise", "salt"]) {
            return "Subscriptions"
        }

        // Housing
        if matchesAny(desc, ["miete", "rent", "loyer", "nebenkosten", "charges", "hypothek", "mortgage", "immobilien"]) {
            return "Housing"
        }

        // Insurance
        if matchesAny(desc, ["versicherung", "assurance", "insurance", "css", "swica", "helsana", "concordia", "visana", "sanitas", "axa", "zurich", "mobiliar", "baloise"]) {
            return "Insurance"
        }

        // Health
        if matchesAny(desc, ["apotheke", "pharmacy", "pharmacie", "arzt", "doctor", "médecin", "hospital", "spital", "hôpital", "zahnarzt", "dentist"]) {
            return "Health"
        }

        // Utilities
        if matchesAny(desc, ["strom", "electricity", "électricité", "wasser", "water", "gas", "heizung", "services industriels", "sig "]) {
            return "Utilities"
        }

        // Income
        if amount > 0 && matchesAny(desc, ["salary", "lohn", "salaire", "gehalt", "bonus", "dividend", "interest", "zins", "intérêt"]) {
            return "Income"
        }

        // Transfer
        if matchesAny(desc, ["transfer", "überweisung", "virement", "twint"]) {
            return "Transfer"
        }

        // Tax
        if matchesAny(desc, ["steuer", "impôt", "tax", "steuerverwaltung", "administration fiscale"]) {
            return "Tax"
        }

        // Default by amount direction
        return amount > 0 ? "Income" : "Other"
    }

    // MARK: - Recurring Transaction Detection

    // periphery:ignore - Reserved: detectRecurring(in:) instance method — reserved for future feature activation
    /// Detect recurring transactions from a list.
    /// Groups by similar description + amount, checks interval consistency.
    func detectRecurring(in transactions: [ImportedTransaction]) -> [RecurringPattern] {
        // periphery:ignore - Reserved: detectRecurring(in:) instance method reserved for future feature activation
        var patterns: [RecurringPattern] = []

        // Group by category + approximate amount
        var groups: [String: [ImportedTransaction]] = [:]
        for tx in transactions {
            let key = "\(tx.category)_\(Int(abs(tx.amount) / 10) * 10)"
            groups[key, default: []].append(tx)
        }

        for (_, group) in groups where group.count >= 2 {
            let sorted = group.sorted { $0.date < $1.date }

            // Calculate intervals between consecutive transactions
            var intervals: [TimeInterval] = []
            for i in 1..<sorted.count {
                intervals.append(sorted[i].date.timeIntervalSince(sorted[i - 1].date))
            }

            guard !intervals.isEmpty else { continue }

            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            let dayInterval = avgInterval / 86400

            // Check if intervals are consistent (within 20%)
            let variance = intervals.map { abs($0 - avgInterval) / avgInterval }
            let maxVariance = variance.max() ?? 1.0

            guard maxVariance < 0.3 else { continue } // Allow 30% variance

            let frequency: RecurringFrequency
            if dayInterval < 10 { frequency = .weekly } else if dayInterval < 45 { frequency = .monthly } else if dayInterval < 100 { frequency = .quarterly } else { frequency = .annually }

            let avgAmount = sorted.map(\.amount).reduce(0, +) / Double(sorted.count)

            patterns.append(RecurringPattern(
                id: UUID(),
                description: sorted.last?.description ?? "",
                category: sorted.first?.category ?? "Other",
                averageAmount: avgAmount,
                frequency: frequency,
                lastDate: sorted.last?.date ?? Date(),
                nextExpectedDate: sorted.last.map { $0.date.addingTimeInterval(avgInterval) } ?? Date(),
                occurrenceCount: sorted.count,
                confidence: min(1.0, Double(sorted.count) / 6.0 * (1.0 - maxVariance))
            ))
        }

        return patterns.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Private Helpers

    private func detectDelimiter(_ content: String) -> Character {
        let firstLine = content.components(separatedBy: .newlines).first ?? ""
        let commaCount = firstLine.filter { $0 == "," }.count
        let semicolonCount = firstLine.filter { $0 == ";" }.count
        let tabCount = firstLine.filter { $0 == "\t" }.count

        if semicolonCount > commaCount && semicolonCount > tabCount { return ";" }
        if tabCount > commaCount { return "\t" }
        return ","
    }

    private func parseCSVRow(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == delimiter && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    private func detectColumnMapping(_ headers: [String]) -> ColumnMapping {
        var mapping = ColumnMapping()

        for (index, header) in headers.enumerated() {
            if matchesAny(header, ["date", "datum", "booking date", "buchungsdatum", "value date", "valutadatum"]) {
                mapping.dateColumn = index
            } else if matchesAny(header, ["amount", "betrag", "montant", "debit", "credit"]) {
                mapping.amountColumn = index
            } else if matchesAny(header, ["description", "beschreibung", "text", "details", "libellé", "buchungstext"]) {
                mapping.descriptionColumn = index
            } else if matchesAny(header, ["category", "kategorie", "catégorie"]) {
                mapping.categoryColumn = index
            } else if matchesAny(header, ["currency", "währung", "devise"]) {
                mapping.currencyColumn = index
            }
        }

        return mapping
    }

    private func parseTransaction(fields: [String], mapping: ColumnMapping, accountId: UUID, currency: String) throws -> ImportedTransaction {
        guard let dateCol = mapping.dateColumn, dateCol < fields.count else {
            throw TransactionImportError.missingField("date")
        }
        guard let amountCol = mapping.amountColumn, amountCol < fields.count else {
            throw TransactionImportError.missingField("amount")
        }

        let dateStr = fields[dateCol]
        guard let date = parseDate(dateStr) else {
            throw TransactionImportError.invalidDate(dateStr)
        }

        let amountStr = fields[amountCol]
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(amountStr) else {
            throw TransactionImportError.invalidAmount(fields[amountCol])
        }

        let description: String
        if let descCol = mapping.descriptionColumn, descCol < fields.count {
            description = fields[descCol]
        } else {
            description = fields.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
        }

        let txCurrency: String
        if let curCol = mapping.currencyColumn, curCol < fields.count, !fields[curCol].isEmpty {
            txCurrency = fields[curCol]
        } else {
            txCurrency = currency
        }

        let category: String
        if let catCol = mapping.categoryColumn, catCol < fields.count, !fields[catCol].isEmpty {
            category = fields[catCol]
        } else {
            category = categorizeTransaction(description: description, amount: amount)
        }

        return ImportedTransaction(
            id: UUID(),
            accountId: accountId,
            date: date,
            amount: amount,
            description: description,
            category: category,
            merchant: extractMerchant(from: description),
            currency: txCurrency,
            isRecurring: false,
            tags: []
        )
    }

    private func parseDate(_ str: String) -> Date? {
        let formatters: [String] = [
            "dd.MM.yyyy", "yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy",
            "dd.MM.yy", "yyyy-MM-dd'T'HH:mm:ss", "dd-MM-yyyy"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formatters {
            formatter.dateFormat = format
            if let date = formatter.date(from: str) { return date }
        }
        return nil
    }

    private func parseOFXDate(_ str: String) -> Date? {
        // OFX format: YYYYMMDDHHMMSS or YYYYMMDD
        let cleanStr = String(str.prefix(8))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: cleanStr)
    }

    private func extractOFXValue(_ content: String, tag: String) -> String? {
        // OFX uses <TAG>value format (no closing tag in SGML mode)
        let pattern = "<\(tag)>([^<\\n]+)"
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern)
        } catch {
            logger.error("Failed to compile OFX extraction regex: \(error)")
            return nil
        }
        guard let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }
        return String(content[range]).trimmingCharacters(in: .whitespaces)
    }

    private func extractMerchant(from description: String) -> String? {
        // Take first meaningful word(s) as merchant name
        let words = description.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let first = words.first, first.count > 2 else { return nil }
        let merchant = words.prefix(3).joined(separator: " ")
        return merchant.isEmpty ? nil : merchant
    }

    private func matchesAny(_ text: String, _ patterns: [String]) -> Bool {
        patterns.contains { text.contains($0) }
    }
}

// MARK: - Types

struct ImportedTransaction: Identifiable, Codable, Sendable {
    let id: UUID
    let accountId: UUID
    let date: Date
    let amount: Double
    let description: String
    let category: String
    let merchant: String?
    let currency: String
    var isRecurring: Bool
    var tags: [String]
}

// periphery:ignore - Reserved: RecurringPattern type reserved for future feature activation
struct RecurringPattern: Identifiable, Sendable {
    let id: UUID
    let description: String
    let category: String
    let averageAmount: Double
    let frequency: RecurringFrequency
    let lastDate: Date
    let nextExpectedDate: Date
    let occurrenceCount: Int
    let confidence: Double
}

enum RecurringFrequency: String, Codable, Sendable {
    case weekly
    case monthly
    case quarterly
    case annually

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .annually: "Annually"
        }
    }
}

struct ColumnMapping {
    var dateColumn: Int?
    var amountColumn: Int?
    var descriptionColumn: Int?
    var categoryColumn: Int?
    var currencyColumn: Int?
}

enum TransactionImportError: LocalizedError, Sendable {
    case invalidEncoding
    case noDataRows
    case missingRequiredColumns(missing: [String])
    case missingField(String)
    case invalidDate(String)
    case invalidAmount(String)
    case parseError(line: Int, detail: String)
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidEncoding: "Could not decode file encoding"
        case .noDataRows: "File contains no data rows"
        case .missingRequiredColumns(let missing): "Missing required columns: \(missing.joined(separator: ", "))"
        case .missingField(let field): "Missing field: \(field)"
        case .invalidDate(let str): "Invalid date format: \(str)"
        case .invalidAmount(let str): "Invalid amount: \(str)"
        case .parseError(let line, let detail): "Error on line \(line): \(detail)"
        case .unsupportedFormat: "Unsupported file format"
        }
    }
}
