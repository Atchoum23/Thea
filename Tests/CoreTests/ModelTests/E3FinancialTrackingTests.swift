import Foundation
import Testing

// MARK: - Transaction Import Tests

@Suite("TransactionImporter — CSV Parsing")
struct TransactionImporterCSVTests {
    @Test("Detect comma delimiter")
    func commaDelimiter() {
        let importer = TestTransactionImporter()
        let line = "Date,Amount,Description,Category"
        #expect(importer.detectDelimiter(line) == ",")
    }

    @Test("Detect semicolon delimiter (Swiss bank exports)")
    func semicolonDelimiter() {
        let importer = TestTransactionImporter()
        let line = "Datum;Betrag;Beschreibung;Kategorie"
        #expect(importer.detectDelimiter(line) == ";")
    }

    @Test("Detect tab delimiter")
    func tabDelimiter() {
        let importer = TestTransactionImporter()
        let line = "Date\tAmount\tDescription"
        #expect(importer.detectDelimiter(line) == "\t")
    }

    @Test("Parse quoted CSV fields")
    func quotedFields() {
        let importer = TestTransactionImporter()
        let row = "\"2024-01-15\",\"-125.50\",\"Migros, Genève\",\"Groceries\""
        let fields = importer.parseCSVRow(row, delimiter: ",")
        #expect(fields.count == 4)
        #expect(fields[0] == "2024-01-15")
        #expect(fields[1] == "-125.50")
        #expect(fields[2] == "Migros, Genève")
        #expect(fields[3] == "Groceries")
    }

    @Test("Parse date formats")
    func dateFormats() {
        let importer = TestTransactionImporter()

        #expect(importer.parseDate("15.01.2024") != nil) // dd.MM.yyyy
        #expect(importer.parseDate("2024-01-15") != nil) // yyyy-MM-dd
        #expect(importer.parseDate("01/15/2024") != nil) // MM/dd/yyyy
        #expect(importer.parseDate("15.01.24") != nil)   // dd.MM.yy
        #expect(importer.parseDate("invalid") == nil)
    }

    @Test("Detect column mapping from headers")
    func columnMapping() {
        let importer = TestTransactionImporter()

        let headers = ["buchungsdatum", "betrag", "buchungstext", "kategorie", "währung"]
        let mapping = importer.detectColumnMapping(headers)

        #expect(mapping.dateColumn == 0)
        #expect(mapping.amountColumn == 1)
        #expect(mapping.descriptionColumn == 2)
        #expect(mapping.categoryColumn == 3)
        #expect(mapping.currencyColumn == 4)
    }

    @Test("English header mapping")
    func englishHeaders() {
        let importer = TestTransactionImporter()

        let headers = ["date", "amount", "description"]
        let mapping = importer.detectColumnMapping(headers)

        #expect(mapping.dateColumn == 0)
        #expect(mapping.amountColumn == 1)
        #expect(mapping.descriptionColumn == 2)
    }
}

// MARK: - Category Detection Tests

@Suite("TransactionImporter — Category Detection")
struct CategoryDetectionTests {
    private let importer = TestTransactionImporter()

    @Test("Groceries detection")
    func groceries() {
        #expect(importer.categorize("Migros Genève", -85.30) == "Groceries")
        #expect(importer.categorize("COOP Pronto Basel", -12.50) == "Groceries")
        #expect(importer.categorize("Aldi Suisse Lausanne", -45.00) == "Groceries")
        #expect(importer.categorize("Denner AG", -22.00) == "Groceries")
    }

    @Test("Transport detection")
    func transport() {
        #expect(importer.categorize("SBB Billett", -35.00) == "Transport")
        #expect(importer.categorize("TPG Abonnement", -70.00) == "Transport")
        #expect(importer.categorize("Parkhaus City", -8.00) == "Transport")
        #expect(importer.categorize("Shell Tankstelle", -65.00) == "Transport")
    }

    @Test("Dining detection")
    func dining() {
        #expect(importer.categorize("Restaurant du Lac", -85.00) == "Dining")
        #expect(importer.categorize("McDonald's Zurich", -15.50) == "Dining")
        #expect(importer.categorize("Starbucks Coffee", -6.80) == "Dining")
    }

    @Test("Subscriptions detection")
    func subscriptions() {
        #expect(importer.categorize("Netflix Monthly", -15.90) == "Subscriptions")
        #expect(importer.categorize("Spotify Premium", -9.90) == "Subscriptions")
        #expect(importer.categorize("Apple Services", -4.99) == "Subscriptions")
        #expect(importer.categorize("Swisscom Mobile", -59.00) == "Subscriptions")
    }

    @Test("Insurance detection")
    func insurance() {
        #expect(importer.categorize("CSS Versicherung", -385.00) == "Insurance")
        #expect(importer.categorize("AXA Winterthur", -120.00) == "Insurance")
        #expect(importer.categorize("Helsana Prämie", -450.00) == "Insurance")
    }

    @Test("Income detection")
    func income() {
        #expect(importer.categorize("Salary Payment", 8500.00) == "Income")
        #expect(importer.categorize("Lohn Dezember", 7200.00) == "Income")
        #expect(importer.categorize("Dividend Payment", 150.00) == "Income")
    }

    @Test("Tax detection")
    func tax() {
        #expect(importer.categorize("Steuerverwaltung GE", -3500.00) == "Tax")
        #expect(importer.categorize("Administration fiscale", -2800.00) == "Tax")
    }

    @Test("Default category by amount direction")
    func defaultCategory() {
        #expect(importer.categorize("Unknown Payment", -50.00) == "Other")
        #expect(importer.categorize("Unknown Credit", 100.00) == "Income")
    }
}

// MARK: - Recurring Transaction Detection Tests

@Suite("TransactionImporter — Recurring Detection")
struct RecurringDetectionTests {
    @Test("Detect monthly recurring")
    func monthlyRecurring() {
        let importer = TestTransactionImporter()
        let transactions = (0..<6).map { month -> TestImportedTransaction in
            let date = Calendar.current.date(byAdding: .month, value: -month, to: Date())!
            return TestImportedTransaction(
                date: date,
                amount: -59.00,
                description: "Swisscom Mobile",
                category: "Subscriptions"
            )
        }

        let patterns = importer.detectRecurring(transactions)
        #expect(!patterns.isEmpty)
        #expect(patterns.first?.frequency == .monthly)
    }

    @Test("No recurring for single transaction")
    func singleTransaction() {
        let importer = TestTransactionImporter()
        let transactions = [TestImportedTransaction(
            date: Date(),
            amount: -100.00,
            description: "One-time purchase",
            category: "Other"
        )]

        let patterns = importer.detectRecurring(transactions)
        #expect(patterns.isEmpty)
    }

    @Test("Detect quarterly recurring")
    func quarterlyRecurring() {
        let importer = TestTransactionImporter()
        let transactions = (0..<4).map { quarter -> TestImportedTransaction in
            let date = Calendar.current.date(byAdding: .month, value: -quarter * 3, to: Date())!
            return TestImportedTransaction(
                date: date,
                amount: -385.00,
                description: "CSS Versicherung",
                category: "Insurance"
            )
        }

        let patterns = importer.detectRecurring(transactions)
        #expect(!patterns.isEmpty)
        if let first = patterns.first {
            #expect(first.frequency == .quarterly || first.frequency == .monthly)
            #expect(first.confidence > 0)
        }
    }
}

// MARK: - Swiss Tax Estimator Tests

@Suite("SwissTaxEstimator — Federal Tax")
struct FederalTaxTests {
    private let estimator = TestTaxEstimator()

    @Test("Zero income produces zero tax")
    func zeroIncome() {
        let tax = estimator.calculateFederalTax(0, status: .single)
        #expect(tax == 0)
    }

    @Test("Below threshold produces zero tax (single)")
    func belowThreshold() {
        let tax = estimator.calculateFederalTax(15000, status: .single)
        #expect(tax == 0)
    }

    @Test("Progressive brackets increase tax (single)")
    func progressiveSingle() {
        let tax50k = estimator.calculateFederalTax(50000, status: .single)
        let tax100k = estimator.calculateFederalTax(100000, status: .single)
        let tax200k = estimator.calculateFederalTax(200000, status: .single)

        #expect(tax50k > 0)
        #expect(tax100k > tax50k)
        #expect(tax200k > tax100k)
    }

    @Test("Married threshold higher than single")
    func marriedThreshold() {
        let singleTax = estimator.calculateFederalTax(25000, status: .single)
        let marriedTax = estimator.calculateFederalTax(25000, status: .married)
        #expect(marriedTax < singleTax)
    }

    @Test("High income has higher effective rate")
    func highIncomeRate() {
        let tax100k = estimator.calculateFederalTax(100000, status: .single)
        let tax500k = estimator.calculateFederalTax(500000, status: .single)

        let rate100k = tax100k / 100000
        let rate500k = tax500k / 500000
        #expect(rate500k > rate100k)
    }
}

@Suite("SwissTaxEstimator — Canton Multipliers")
struct CantonMultiplierTests {
    @Test("All 26 cantons have multipliers")
    func allCantons() {
        #expect(TestSwissCanton.allCases.count == 26)
        for canton in TestSwissCanton.allCases {
            #expect(canton.taxMultiplier > 0)
            #expect(!canton.displayName.isEmpty)
            #expect(!canton.rawValue.isEmpty)
        }
    }

    @Test("Zug has one of the lowest cantonal multipliers")
    func zugLowMultiplier() {
        let zugMultiplier = TestSwissCanton.zug.taxMultiplier
        // Zug should be in the bottom 5 cantons by cantonal tax multiplier
        let sortedMultipliers = TestSwissCanton.allCases.map(\.taxMultiplier).sorted()
        let zugRank = sortedMultipliers.firstIndex(of: zugMultiplier) ?? 0
        #expect(zugRank < 5, "Zug should be in bottom 5 cantons by tax multiplier")
        #expect(zugMultiplier < 1.0, "Zug multiplier should be below 1.0")
    }

    @Test("Canton raw values are 2-letter codes")
    func rawValueFormat() {
        for canton in TestSwissCanton.allCases {
            #expect(canton.rawValue.count == 2)
            #expect(canton.rawValue == canton.rawValue.uppercased())
        }
    }

    @Test("Display names are non-empty and unique")
    func displayNamesUnique() {
        let names = TestSwissCanton.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }
}

@Suite("SwissTaxEstimator — Full Estimate")
struct FullEstimateTests {
    @Test("Estimate with typical Geneva income")
    func genevaEstimate() {
        let estimator = TestTaxEstimator()
        let result = estimator.estimateFullTax(
            grossIncome: 120000,
            canton: .geneve,
            status: .single,
            children: 0
        )

        #expect(result.grossIncome == 120000)
        #expect(result.taxableIncome < result.grossIncome)
        #expect(result.federalTax > 0)
        #expect(result.cantonalTax > 0)
        #expect(result.totalTax > 0)
        #expect(result.effectiveRate > 0 && result.effectiveRate < 1)
        #expect(result.quarterlyAmount > 0)
        #expect(result.quarterlyAmount * 4 == result.totalTax)
    }

    @Test("Children reduce tax")
    func childrenReduceTax() {
        let estimator = TestTaxEstimator()
        let noChildren = estimator.estimateFullTax(
            grossIncome: 100000,
            canton: .zurich,
            status: .single,
            children: 0
        )
        let withChildren = estimator.estimateFullTax(
            grossIncome: 100000,
            canton: .zurich,
            status: .single,
            children: 2
        )

        #expect(withChildren.totalTax < noChildren.totalTax)
        #expect(withChildren.deductions > noChildren.deductions)
    }

    @Test("Married filing reduces tax")
    func marriedReducesTax() {
        let estimator = TestTaxEstimator()
        let single = estimator.estimateFullTax(
            grossIncome: 150000,
            canton: .bern,
            status: .single,
            children: 0
        )
        let married = estimator.estimateFullTax(
            grossIncome: 150000,
            canton: .bern,
            status: .married,
            children: 0
        )

        #expect(married.totalTax < single.totalTax)
    }

    @Test("Marginal rate is positive for typical income")
    func marginalRate() {
        let estimator = TestTaxEstimator()
        let result = estimator.estimateFullTax(
            grossIncome: 100000,
            canton: .vaud,
            status: .single,
            children: 0
        )

        #expect(result.marginalRate > 0)
        #expect(result.marginalRate > result.effectiveRate)
    }
}

// MARK: - Filing Status Tests

@Suite("TestFilingStatus — Properties")
struct TestFilingStatusTests {
    @Test("All cases")
    func allCases() {
        #expect(TestFilingStatus.allCases.count == 2)
        #expect(TestFilingStatus.single.rawValue == "Single")
        #expect(TestFilingStatus.married.rawValue == "Married")
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let data = try JSONEncoder().encode(TestFilingStatus.married)
        let decoded = try JSONDecoder().decode(TestFilingStatus.self, from: data)
        #expect(decoded == .married)
    }
}

// MARK: - Deduction Category Tests

@Suite("TestDeductionCategory — Properties")
struct TestDeductionCategoryTests {
    @Test("All 8 categories")
    func allCategories() {
        #expect(TestDeductionCategory.allCases.count == 8)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let values = TestDeductionCategory.allCases.map(\.rawValue)
        #expect(Set(values).count == values.count)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for cat in TestDeductionCategory.allCases {
            let data = try JSONEncoder().encode(cat)
            let decoded = try JSONDecoder().decode(TestDeductionCategory.self, from: data)
            #expect(decoded == cat)
        }
    }
}

// MARK: - Tax Deduction Tests

@Suite("TestTaxDeduction — Model")
struct TestTaxDeductionTests {
    @Test("Creation with defaults")
    func creation() {
        let d = TestTaxDeduction(name: "Pillar 3a", amount: 7056, category: .pillar3a)
        #expect(d.name == "Pillar 3a")
        #expect(d.amount == 7056)
        #expect(d.category == .pillar3a)
        #expect(d.isActive)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let d = TestTaxDeduction(name: "Charity", amount: 500, category: .charity, isActive: false)
        let data = try JSONEncoder().encode(d)
        let decoded = try JSONDecoder().decode(TestTaxDeduction.self, from: data)
        #expect(decoded.name == d.name)
        #expect(decoded.amount == d.amount)
        #expect(decoded.category == d.category)
        #expect(decoded.isActive == false)
    }
}

// MARK: - TransactionImportError Tests

@Suite("TransactionImportError — Descriptions")
struct TransactionImportErrorTests {
    @Test("All errors have descriptions")
    func allDescriptions() {
        let errors: [TransactionImportError] = [
            .invalidEncoding,
            .noDataRows,
            .missingRequiredColumns(missing: ["date", "amount"]),
            .missingField("date"),
            .invalidDate("abc"),
            .invalidAmount("xyz"),
            .parseError(line: 5, detail: "bad format"),
            .unsupportedFormat
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Missing columns lists column names")
    func missingColumnsMessage() {
        let error = TransactionImportError.missingRequiredColumns(missing: ["date", "amount"])
        #expect(error.errorDescription!.contains("date"))
        #expect(error.errorDescription!.contains("amount"))
    }

    @Test("Parse error includes line number")
    func parseErrorLine() {
        let error = TransactionImportError.parseError(line: 42, detail: "bad format")
        #expect(error.errorDescription!.contains("42"))
    }
}

// MARK: - OFX Parsing Tests

@Suite("TransactionImporter — OFX Parsing")
struct OFXParsingTests {
    @Test("Extract OFX tag value")
    func extractTag() {
        let importer = TestTransactionImporter()
        let content = "<CURDEF>CHF\n<STMTTRN>\n<TRNTYPE>DEBIT\n<DTPOSTED>20240115\n<TRNAMT>-125.50\n<NAME>Migros"

        #expect(importer.extractOFXValue(content, tag: "CURDEF") == "CHF")
        #expect(importer.extractOFXValue(content, tag: "TRNTYPE") == "DEBIT")
        #expect(importer.extractOFXValue(content, tag: "TRNAMT") == "-125.50")
        #expect(importer.extractOFXValue(content, tag: "NAME") == "Migros")
    }

    @Test("Parse OFX date format")
    func parseOFXDate() {
        let importer = TestTransactionImporter()
        let date = importer.parseOFXDate("20240115120000")
        #expect(date != nil)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 15)
    }

    @Test("Missing OFX tag returns nil")
    func missingTag() {
        let importer = TestTransactionImporter()
        let content = "<CURDEF>CHF"
        #expect(importer.extractOFXValue(content, tag: "NOTHERE") == nil)
    }
}

// MARK: - Quarterly Payment Tests

@Suite("TestQuarterlyPayment — Model")
struct TestQuarterlyPaymentTests {
    @Test("Creation with all fields")
    func creation() {
        let payment = TestQuarterlyPayment(
            id: UUID(),
            quarter: 1,
            year: 2026,
            amount: 5000,
            dueDate: Date(),
            isPaid: false,
            paidDate: nil,
            paidAmount: nil
        )
        #expect(payment.quarter == 1)
        #expect(payment.year == 2026)
        #expect(payment.amount == 5000)
        #expect(!payment.isPaid)
        #expect(payment.paidDate == nil)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let payment = TestQuarterlyPayment(
            id: UUID(),
            quarter: 3,
            year: 2025,
            amount: 4500,
            dueDate: Date(),
            isPaid: true,
            paidDate: Date(),
            paidAmount: 4500
        )
        let data = try JSONEncoder().encode(payment)
        let decoded = try JSONDecoder().decode(TestQuarterlyPayment.self, from: data)
        #expect(decoded.quarter == payment.quarter)
        #expect(decoded.year == payment.year)
        #expect(decoded.isPaid == true)
    }
}

// MARK: - RecurringFrequency Tests

@Suite("RecurringFrequency — Properties")
struct RecurringFrequencyTests {
    @Test("All frequencies have display names")
    func displayNames() {
        let frequencies: [RecurringFrequency] = [.weekly, .monthly, .quarterly, .annually]
        for freq in frequencies {
            #expect(!freq.displayName.isEmpty)
        }
    }

    @Test("Display names are capitalized")
    func capitalized() {
        #expect(RecurringFrequency.weekly.displayName == "Weekly")
        #expect(RecurringFrequency.monthly.displayName == "Monthly")
        #expect(RecurringFrequency.quarterly.displayName == "Quarterly")
        #expect(RecurringFrequency.annually.displayName == "Annually")
    }
}

// MARK: - Test Doubles

private struct TestTransactionImporter {
    func detectDelimiter(_ line: String) -> Character {
        let commaCount = line.filter { $0 == "," }.count
        let semicolonCount = line.filter { $0 == ";" }.count
        let tabCount = line.filter { $0 == "\t" }.count
        if semicolonCount > commaCount && semicolonCount > tabCount { return ";" }
        if tabCount > commaCount { return "\t" }
        return ","
    }

    func parseCSVRow(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" { inQuotes.toggle() }
            else if char == delimiter && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else { current.append(char) }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    func parseDate(_ str: String) -> Date? {
        let formats = ["dd.MM.yyyy", "yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "dd.MM.yy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: str) { return date }
        }
        return nil
    }

    func detectColumnMapping(_ headers: [String]) -> TestColumnMapping {
        var mapping = TestColumnMapping()
        for (index, header) in headers.enumerated() {
            let h = header.lowercased()
            if ["date", "datum", "buchungsdatum"].contains(where: { h.contains($0) }) { mapping.dateColumn = index }
            else if ["amount", "betrag", "montant"].contains(where: { h.contains($0) }) { mapping.amountColumn = index }
            else if ["description", "beschreibung", "buchungstext", "text"].contains(where: { h.contains($0) }) { mapping.descriptionColumn = index }
            else if ["category", "kategorie", "catégorie"].contains(where: { h.contains($0) }) { mapping.categoryColumn = index }
            else if ["currency", "währung", "devise"].contains(where: { h.contains($0) }) { mapping.currencyColumn = index }
        }
        return mapping
    }

    func categorize(_ description: String, _ amount: Double) -> String {
        let desc = description.lowercased()
        if matchesAny(desc, ["migros", "coop", "aldi", "lidl", "denner"]) { return "Groceries" }
        if matchesAny(desc, ["sbb", "tpg", "parkhaus", "shell", "benzin"]) { return "Transport" }
        if matchesAny(desc, ["restaurant", "mcdonald", "starbucks", "cafe"]) { return "Dining" }
        if matchesAny(desc, ["netflix", "spotify", "apple", "swisscom"]) { return "Subscriptions" }
        if matchesAny(desc, ["versicherung", "assurance", "css", "axa", "helsana"]) { return "Insurance" }
        if matchesAny(desc, ["steuerverwaltung", "administration fiscale"]) { return "Tax" }
        if amount > 0 && matchesAny(desc, ["salary", "lohn", "dividend"]) { return "Income" }
        return amount > 0 ? "Income" : "Other"
    }

    func detectRecurring(_ transactions: [TestImportedTransaction]) -> [TestRecurringPattern] {
        var groups: [String: [TestImportedTransaction]] = [:]
        for tx in transactions {
            let key = "\(tx.category)_\(Int(abs(tx.amount) / 10) * 10)"
            groups[key, default: []].append(tx)
        }

        var patterns: [TestRecurringPattern] = []
        for (_, group) in groups where group.count >= 2 {
            let sorted = group.sorted { $0.date < $1.date }
            var intervals: [TimeInterval] = []
            for i in 1..<sorted.count {
                intervals.append(sorted[i].date.timeIntervalSince(sorted[i - 1].date))
            }
            guard !intervals.isEmpty else { continue }
            let avg = intervals.reduce(0, +) / Double(intervals.count)
            let dayInterval = avg / 86400
            let frequency: RecurringFrequency
            if dayInterval < 10 { frequency = .weekly }
            else if dayInterval < 45 { frequency = .monthly }
            else if dayInterval < 100 { frequency = .quarterly }
            else { frequency = .annually }
            let variance = intervals.map { abs($0 - avg) / avg }
            let maxVar = variance.max() ?? 1.0
            guard maxVar < 0.3 else { continue }
            patterns.append(TestRecurringPattern(
                frequency: frequency,
                confidence: min(1.0, Double(sorted.count) / 6.0 * (1.0 - maxVar))
            ))
        }
        return patterns
    }

    func extractOFXValue(_ content: String, tag: String) -> String? {
        let pattern = "<\(tag)>([^<\\n]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else { return nil }
        return String(content[range]).trimmingCharacters(in: .whitespaces)
    }

    func parseOFXDate(_ str: String) -> Date? {
        let cleanStr = String(str.prefix(8))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: cleanStr)
    }

    private func matchesAny(_ text: String, _ patterns: [String]) -> Bool {
        patterns.contains { text.contains($0) }
    }
}

private struct TestColumnMapping {
    var dateColumn: Int?
    var amountColumn: Int?
    var descriptionColumn: Int?
    var categoryColumn: Int?
    var currencyColumn: Int?
}

private struct TestImportedTransaction {
    let date: Date
    let amount: Double
    let description: String
    let category: String
}

private struct TestRecurringPattern {
    let frequency: RecurringFrequency
    let confidence: Double
}

private struct TestTaxEstimator {
    func calculateFederalTax(_ taxableIncome: Double, status: TestFilingStatus) -> Double {
        let brackets: [(threshold: Double, rate: Double)]
        switch status {
        case .single:
            brackets = [
                (17_800, 0.0), (31_600, 0.0077), (41_400, 0.0088),
                (55_200, 0.0264), (72_500, 0.0297), (78_100, 0.0561),
                (103_600, 0.0624), (134_600, 0.0668), (176_000, 0.0890),
                (755_200, 0.1100), (Double.infinity, 0.1150)
            ]
        case .married:
            brackets = [
                (28_300, 0.0), (50_900, 0.01), (58_400, 0.02),
                (75_300, 0.03), (90_300, 0.04), (103_400, 0.05),
                (114_700, 0.06), (124_200, 0.07), (131_700, 0.08),
                (137_800, 0.09), (143_900, 0.10), (689_900, 0.11),
                (Double.infinity, 0.115)
            ]
        }
        var tax = 0.0
        var prev = 0.0
        for bracket in brackets {
            if taxableIncome <= prev { break }
            let inBracket = min(taxableIncome, bracket.threshold) - prev
            if inBracket > 0 { tax += inBracket * bracket.rate }
            prev = bracket.threshold
        }
        return tax
    }

    func estimateFullTax(
        grossIncome: Double,
        canton: TestSwissCanton,
        status: TestFilingStatus,
        children: Int
    ) -> TestTaxResult {
        let ahvRate = 0.053
        let alvRate = 0.011
        let socialContributions = grossIncome * (ahvRate + alvRate)
        let professionalExpenses = min(grossIncome * 0.03, 4000)
        let insurancePremium = status == .married ? 5200.0 : 2600.0
        let childDeduction = Double(children) * 6600
        let pillar3a = min(7056, grossIncome * 0.2)
        let totalDeductions = socialContributions + professionalExpenses + insurancePremium + childDeduction + pillar3a
        let taxableIncome = max(0, grossIncome - totalDeductions)
        let federalTax = calculateFederalTax(taxableIncome, status: status)

        let cantonalBrackets: [(Double, Double)] = [
            (20_000, 0.0), (40_000, 0.04), (60_000, 0.06), (80_000, 0.08),
            (100_000, 0.10), (150_000, 0.12), (200_000, 0.13), (300_000, 0.14),
            (Double.infinity, 0.15)
        ]
        var cantonalBase = 0.0
        var prev = 0.0
        for bracket in cantonalBrackets {
            if taxableIncome <= prev { break }
            let inBracket = min(taxableIncome, bracket.0) - prev
            if inBracket > 0 { cantonalBase += inBracket * bracket.1 }
            prev = bracket.0
        }
        if status == .married { cantonalBase *= 0.55 }

        let cantonalTax = cantonalBase * canton.taxMultiplier
        let municipalTax = cantonalBase * canton.defaultMunicipalMultiplier
        let churchTax = cantonalBase * 0.10
        let totalTax = federalTax + cantonalTax + municipalTax + churchTax

        let increment = 1000.0
        let tax1 = federalTax + cantonalBase * (canton.taxMultiplier + canton.defaultMunicipalMultiplier + 0.10)
        var cantonalBase2 = 0.0
        prev = 0.0
        for bracket in cantonalBrackets {
            if (taxableIncome + increment) <= prev { break }
            let inBracket = min(taxableIncome + increment, bracket.0) - prev
            if inBracket > 0 { cantonalBase2 += inBracket * bracket.1 }
            prev = bracket.0
        }
        if status == .married { cantonalBase2 *= 0.55 }
        let tax2 = calculateFederalTax(taxableIncome + increment, status: status) +
            cantonalBase2 * (canton.taxMultiplier + canton.defaultMunicipalMultiplier + 0.10)
        let marginalRate = (tax2 - tax1) / increment

        return TestTaxResult(
            grossIncome: grossIncome,
            taxableIncome: taxableIncome,
            federalTax: federalTax,
            cantonalTax: cantonalTax,
            municipalTax: municipalTax,
            churchTax: churchTax,
            totalTax: totalTax,
            effectiveRate: grossIncome > 0 ? totalTax / grossIncome : 0,
            marginalRate: marginalRate,
            socialContributions: socialContributions,
            deductions: totalDeductions,
            quarterlyAmount: totalTax / 4
        )
    }
}

private struct TestTaxResult {
    let grossIncome: Double
    let taxableIncome: Double
    let federalTax: Double
    let cantonalTax: Double
    let municipalTax: Double
    let churchTax: Double
    let totalTax: Double
    let effectiveRate: Double
    let marginalRate: Double
    let socialContributions: Double
    let deductions: Double
    let quarterlyAmount: Double
}

// MARK: - Mirrored Production Enums for SPM Tests

enum RecurringFrequency: String, Codable {
    case weekly, monthly, quarterly, annually

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .annually: "Annually"
        }
    }
}

enum TransactionImportError: LocalizedError {
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

enum TestSwissCanton: String, CaseIterable, Codable {
    case zurich = "ZH", bern = "BE", luzern = "LU", uri = "UR", schwyz = "SZ"
    case obwalden = "OW", nidwalden = "NW", glarus = "GL", zug = "ZG", fribourg = "FR"
    case solothurn = "SO", baselStadt = "BS", baselLand = "BL", schaffhausen = "SH"
    case appenzellAR = "AR", appenzellIR = "AI", stGallen = "SG", graubuenden = "GR"
    case aargau = "AG", thurgau = "TG", ticino = "TI", vaud = "VD", valais = "VS"
    case neuchatel = "NE", geneve = "GE", jura = "JU"

    var displayName: String {
        switch self {
        case .zurich: "Zürich"
        case .bern: "Bern"
        case .geneve: "Genève"
        case .zug: "Zug"
        case .vaud: "Vaud"
        case .luzern: "Luzern"
        case .uri: "Uri"
        case .schwyz: "Schwyz"
        case .obwalden: "Obwalden"
        case .nidwalden: "Nidwalden"
        case .glarus: "Glarus"
        case .fribourg: "Fribourg"
        case .solothurn: "Solothurn"
        case .baselStadt: "Basel-Stadt"
        case .baselLand: "Basel-Landschaft"
        case .schaffhausen: "Schaffhausen"
        case .appenzellAR: "Appenzell A.Rh."
        case .appenzellIR: "Appenzell I.Rh."
        case .stGallen: "St. Gallen"
        case .graubuenden: "Graubünden"
        case .aargau: "Aargau"
        case .thurgau: "Thurgau"
        case .ticino: "Ticino"
        case .valais: "Valais"
        case .neuchatel: "Neuchâtel"
        case .jura: "Jura"
        }
    }

    var taxMultiplier: Double {
        switch self {
        case .zug: 0.82
        case .geneve: 0.4476
        case .vaud: 1.535
        case .bern: 1.54
        case .zurich: 1.00
        case .schwyz: 0.90
        case .nidwalden: 0.89
        case .obwalden: 0.93
        case .appenzellIR: 0.94
        case .uri: 1.05
        case .luzern: 0.95
        case .glarus: 1.10
        case .fribourg: 1.32
        case .solothurn: 1.15
        case .baselStadt: 1.17
        case .baselLand: 1.20
        case .schaffhausen: 1.08
        case .appenzellAR: 1.12
        case .stGallen: 1.10
        case .graubuenden: 1.05
        case .aargau: 1.09
        case .thurgau: 1.04
        case .ticino: 1.00
        case .valais: 1.25
        case .neuchatel: 1.30
        case .jura: 1.40
        }
    }

    var defaultMunicipalMultiplier: Double {
        switch self {
        case .zurich: 1.19
        case .geneve: 0.455
        case .vaud: 1.535
        case .baselStadt: 0.0
        case .zug: 0.60
        default: 1.0
        }
    }
}

enum TestFilingStatus: String, Codable, CaseIterable {
    case single = "Single"
    case married = "Married"
}

enum TestDeductionCategory: String, Codable, CaseIterable {
    case professional = "Professional Expenses"
    case insurance = "Insurance"
    case pillar3a = "Pillar 3a"
    case charity = "Charitable Donations"
    case childcare = "Childcare"
    case education = "Education"
    case medical = "Medical (Extraordinary)"
    case other = "Other"
}

struct TestTaxDeduction: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: Double
    var category: TestDeductionCategory
    var isActive: Bool

    init(id: UUID = UUID(), name: String, amount: Double, category: TestDeductionCategory, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.isActive = isActive
    }
}

struct TestQuarterlyPayment: Identifiable, Codable {
    let id: UUID
    let quarter: Int
    let year: Int
    let amount: Double
    let dueDate: Date
    var isPaid: Bool
    var paidDate: Date?
    var paidAmount: Double?
}

