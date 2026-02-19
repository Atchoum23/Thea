import Foundation
import OSLog

// MARK: - Swiss Tax Estimator

/// Estimates Swiss federal + cantonal taxes based on income, deductions, and canton.
/// Supports all 26 cantons with simplified progressive rate tables.
/// Uses 2025 tax year rates as baseline.
@MainActor
@Observable
final class SwissTaxEstimator {
    static let shared = SwissTaxEstimator()
    private let logger = Logger(subsystem: "com.thea.app", category: "SwissTaxEstimator")

    private(set) var lastEstimate: SwissTaxResult?
    private(set) var deductions: [TaxDeduction] = []
    private(set) var quarterlyPayments: [QuarterlyPayment] = []

    private init() {
        loadDeductions()
        loadPayments()
    }

    // MARK: - Tax Estimation

    /// Estimate annual taxes for a given income in a specific canton.
    // periphery:ignore - Reserved: municipality parameter — kept for API compatibility
    func estimateAnnualTax(
        grossIncome: Double,
        canton: SwissCanton,
        municipality: String? = nil,
        filingStatus: FilingStatus = .single,
        children: Int = 0
    ) -> SwissTaxResult {
        // Social contributions (AHV/IV/EO/ALV)
        let ahvRate = 0.053 // Employee share 5.3%
        // periphery:ignore - Reserved: municipality parameter kept for API compatibility
        let alvRate = 0.011 // ALV 1.1%
        let socialContributions = grossIncome * (ahvRate + alvRate)

        // Standard deductions
        let professionalExpenses = min(grossIncome * 0.03, 4000) // 3% up to CHF 4,000
        let insurancePremium = filingStatus == .married ? 5200.0 : 2600.0 // Health insurance deduction
        let childDeduction = Double(children) * 6600 // CHF 6,600 per child (federal)
        let pillar3a = min(7056, grossIncome * 0.2) // Pillar 3a max CHF 7,056 (with BVG)

        // User-entered deductions
        let userDeductions = deductions.filter { $0.isActive }.reduce(0.0) { $0 + $1.amount }

        let totalDeductions = socialContributions + professionalExpenses + insurancePremium
            + childDeduction + pillar3a + userDeductions

        let taxableIncome = max(0, grossIncome - totalDeductions)

        // Federal tax
        let federalTax = calculateFederalTax(taxableIncome: taxableIncome, status: filingStatus)

        // Cantonal tax (base rate × cantonal multiplier)
        let cantonalBaseTax = calculateCantonalBaseTax(taxableIncome: taxableIncome, canton: canton, status: filingStatus)
        let cantonalMultiplier = canton.taxMultiplier
        let cantonalTax = cantonalBaseTax * cantonalMultiplier

        // Municipal tax (typically 40-130% of cantonal base)
        let municipalMultiplier = canton.defaultMunicipalMultiplier
        let municipalTax = cantonalBaseTax * municipalMultiplier

        // Church tax (optional, ~10% of cantonal)
        let churchTax = cantonalBaseTax * 0.10

        let totalTax = federalTax + cantonalTax + municipalTax + churchTax

        let estimate = SwissTaxResult(
            grossIncome: grossIncome,
            taxableIncome: taxableIncome,
            federalTax: federalTax,
            cantonalTax: cantonalTax,
            municipalTax: municipalTax,
            churchTax: churchTax,
            totalTax: totalTax,
            effectiveRate: grossIncome > 0 ? totalTax / grossIncome : 0,
            marginalRate: calculateMarginalRate(taxableIncome: taxableIncome, canton: canton, status: filingStatus),
            socialContributions: socialContributions,
            deductions: totalDeductions,
            canton: canton,
            filingStatus: filingStatus,
            children: children,
            quarterlyAmount: totalTax / 4
        )

        lastEstimate = estimate
        return estimate
    }

    // MARK: - Quarterly Planning

    /// Calculate quarterly payment schedule.
    func generateQuarterlySchedule(estimate: SwissTaxResult, year: Int = Calendar.current.component(.year, from: Date())) -> [QuarterlyPayment] {
        let calendar = Calendar.current
        let quarterlyAmount = estimate.quarterlyAmount

        let payments = (1...4).map { quarter -> QuarterlyPayment in
            var components = DateComponents()
            components.year = year
            components.month = quarter * 3
            components.day = 15

            let dueDate = calendar.date(from: components) ?? Date()
            let isPaid = quarterlyPayments.contains {
                $0.quarter == quarter && $0.year == year && $0.isPaid
            }

            return QuarterlyPayment(
                id: UUID(),
                quarter: quarter,
                year: year,
                amount: quarterlyAmount,
                dueDate: dueDate,
                isPaid: isPaid,
                paidDate: isPaid ? dueDate : nil,
                paidAmount: isPaid ? quarterlyAmount : nil
            )
        }

        return payments
    }

    /// Mark a quarterly payment as paid.
    func markQuarterlyPaid(quarter: Int, year: Int, amount: Double) {
        let payment = QuarterlyPayment(
            id: UUID(),
            quarter: quarter,
            year: year,
            amount: amount,
            dueDate: Date(),
            isPaid: true,
            paidDate: Date(),
            paidAmount: amount
        )
        quarterlyPayments.append(payment)
        savePayments()
    }

    // MARK: - Deductions

    /// Add a tax deduction.
    func addDeduction(_ deduction: TaxDeduction) {
        deductions.append(deduction)
        saveDeductions()
    }

    /// Remove a deduction.
    // periphery:ignore - Reserved: removeDeduction(id:) instance method — reserved for future feature activation
    func removeDeduction(id: UUID) {
        deductions.removeAll { $0.id == id }
        saveDeductions()
    }

    // periphery:ignore - Reserved: removeDeduction(id:) instance method reserved for future feature activation
    /// Toggle deduction active state.
    func toggleDeduction(id: UUID) {
        if let index = deductions.firstIndex(where: { $0.id == id }) {
            deductions[index].isActive.toggle()
            saveDeductions()
        }
    }

    // MARK: - Federal Tax Calculation

    private func calculateFederalTax(taxableIncome: Double, status: FilingStatus) -> Double {
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
        var previousThreshold = 0.0

        for bracket in brackets {
            if taxableIncome <= previousThreshold { break }
            let taxableInBracket = min(taxableIncome, bracket.threshold) - previousThreshold
            if taxableInBracket > 0 {
                tax += taxableInBracket * bracket.rate
            }
            previousThreshold = bracket.threshold
        }

        return tax
    }

    // MARK: - Cantonal Tax Calculation

    // periphery:ignore - Reserved: canton parameter — kept for API compatibility
    private func calculateCantonalBaseTax(taxableIncome: Double, canton: SwissCanton, status: FilingStatus) -> Double {
        // Simplified cantonal base tax using a representative progressive schedule
        // Each canton has a multiplier applied to this base
        let brackets: [(threshold: Double, rate: Double)] = [
            // periphery:ignore - Reserved: canton parameter kept for API compatibility
            (20_000, 0.0),
            (40_000, 0.04),
            (60_000, 0.06),
            (80_000, 0.08),
            (100_000, 0.10),
            (150_000, 0.12),
            (200_000, 0.13),
            (300_000, 0.14),
            (Double.infinity, 0.15)
        ]

        var tax = 0.0
        var previousThreshold = 0.0

        for bracket in brackets {
            if taxableIncome <= previousThreshold { break }
            let taxableInBracket = min(taxableIncome, bracket.threshold) - previousThreshold
            if taxableInBracket > 0 {
                tax += taxableInBracket * bracket.rate
            }
            previousThreshold = bracket.threshold
        }

        // Married status gets ~1.8x lower effective rate
        if status == .married {
            tax *= 0.55
        }

        return tax
    }

    private func calculateMarginalRate(taxableIncome: Double, canton: SwissCanton, status: FilingStatus) -> Double {
        let increment = 1000.0
        let tax1 = calculateFederalTax(taxableIncome: taxableIncome, status: status)
            + calculateCantonalBaseTax(taxableIncome: taxableIncome, canton: canton, status: status) * (canton.taxMultiplier + canton.defaultMunicipalMultiplier + 0.10)
        let tax2 = calculateFederalTax(taxableIncome: taxableIncome + increment, status: status)
            + calculateCantonalBaseTax(taxableIncome: taxableIncome + increment, canton: canton, status: status) * (canton.taxMultiplier + canton.defaultMunicipalMultiplier + 0.10)
        return (tax2 - tax1) / increment
    }

    // MARK: - Persistence

    private func loadDeductions() {
        guard let data = UserDefaults.standard.data(forKey: "thea.tax.deductions") else { return }
        do {
            deductions = try JSONDecoder().decode([TaxDeduction].self, from: data)
        } catch {
            logger.debug("Could not load tax deductions: \(error.localizedDescription)")
        }
    }

    private func saveDeductions() {
        do {
            let data = try JSONEncoder().encode(deductions)
            UserDefaults.standard.set(data, forKey: "thea.tax.deductions")
        } catch {
            logger.debug("Could not save tax deductions: \(error.localizedDescription)")
        }
    }

    private func loadPayments() {
        guard let data = UserDefaults.standard.data(forKey: "thea.tax.payments") else { return }
        do {
            quarterlyPayments = try JSONDecoder().decode([QuarterlyPayment].self, from: data)
        } catch {
            logger.debug("Could not load quarterly payments: \(error.localizedDescription)")
        }
    }

    private func savePayments() {
        do {
            let data = try JSONEncoder().encode(quarterlyPayments)
            UserDefaults.standard.set(data, forKey: "thea.tax.payments")
        } catch {
            logger.debug("Could not save quarterly payments: \(error.localizedDescription)")
        }
    }
}

// MARK: - Types

struct SwissTaxResult: Sendable {
    // periphery:ignore - Reserved: grossIncome property — reserved for future feature activation
    let grossIncome: Double
    // periphery:ignore - Reserved: taxableIncome property — reserved for future feature activation
    let taxableIncome: Double
    let federalTax: Double
    // periphery:ignore - Reserved: grossIncome property reserved for future feature activation
    // periphery:ignore - Reserved: taxableIncome property reserved for future feature activation
    let cantonalTax: Double
    let municipalTax: Double
    let churchTax: Double
    let totalTax: Double
    let effectiveRate: Double
    let marginalRate: Double
    let socialContributions: Double
    let deductions: Double
    let canton: SwissCanton
    // periphery:ignore - Reserved: filingStatus property — reserved for future feature activation
    let filingStatus: FilingStatus
    // periphery:ignore - Reserved: filingStatus property reserved for future feature activation
    // periphery:ignore - Reserved: children property reserved for future feature activation
    let children: Int
    let quarterlyAmount: Double
}

enum FilingStatus: String, Codable, CaseIterable, Sendable {
    case single = "Single"
    case married = "Married"
}

struct TaxDeduction: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var amount: Double
    var category: DeductionCategory
    var isActive: Bool

    init(id: UUID = UUID(), name: String, amount: Double, category: DeductionCategory, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.isActive = isActive
    }
}

enum DeductionCategory: String, Codable, CaseIterable, Sendable {
    case professional = "Professional Expenses"
    case insurance = "Insurance"
    case pillar3a = "Pillar 3a"
    case charity = "Charitable Donations"
    case childcare = "Childcare"
    case education = "Education"
    case medical = "Medical (Extraordinary)"
    case other = "Other"
}

struct QuarterlyPayment: Identifiable, Codable, Sendable {
    let id: UUID
    let quarter: Int
    let year: Int
    let amount: Double
    let dueDate: Date
    var isPaid: Bool
    var paidDate: Date?
    var paidAmount: Double?
}

// MARK: - Swiss Cantons

enum SwissCanton: String, CaseIterable, Codable, Sendable {
    case zurich = "ZH"
    case bern = "BE"
    case luzern = "LU"
    case uri = "UR"
    case schwyz = "SZ"
    case obwalden = "OW"
    case nidwalden = "NW"
    case glarus = "GL"
    case zug = "ZG"
    case fribourg = "FR"
    case solothurn = "SO"
    case baselStadt = "BS"
    case baselLand = "BL"
    case schaffhausen = "SH"
    case appenzellAR = "AR"
    case appenzellIR = "AI"
    case stGallen = "SG"
    case graubuenden = "GR"
    case aargau = "AG"
    case thurgau = "TG"
    case ticino = "TI"
    case vaud = "VD"
    case valais = "VS"
    case neuchatel = "NE"
    case geneve = "GE"
    case jura = "JU"

    var displayName: String {
        switch self {
        case .zurich: "Zürich"
        case .bern: "Bern"
        case .luzern: "Luzern"
        case .uri: "Uri"
        case .schwyz: "Schwyz"
        case .obwalden: "Obwalden"
        case .nidwalden: "Nidwalden"
        case .glarus: "Glarus"
        case .zug: "Zug"
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
        case .vaud: "Vaud"
        case .valais: "Valais"
        case .neuchatel: "Neuchâtel"
        case .geneve: "Genève"
        case .jura: "Jura"
        }
    }

    /// Cantonal tax multiplier (approximate 2025 values)
    var taxMultiplier: Double {
        switch self {
        case .zurich: 1.00
        case .bern: 1.54
        case .luzern: 1.60
        case .uri: 1.00
        case .schwyz: 1.50
        case .obwalden: 1.35
        case .nidwalden: 1.30
        case .glarus: 1.55
        case .zug: 0.82
        case .fribourg: 1.00
        case .solothurn: 1.16
        case .baselStadt: 1.00
        case .baselLand: 1.00
        case .schaffhausen: 1.15
        case .appenzellAR: 1.30
        case .appenzellIR: 1.10
        case .stGallen: 1.15
        case .graubuenden: 1.00
        case .aargau: 1.09
        case .thurgau: 1.17
        case .ticino: 1.00
        case .vaud: 1.535
        case .valais: 1.00
        case .neuchatel: 1.295
        case .geneve: 0.4476
        case .jura: 1.25
        }
    }

    /// Default municipal tax multiplier
    var defaultMunicipalMultiplier: Double {
        switch self {
        case .zurich: 1.19 // Zurich city
        case .bern: 1.54
        case .geneve: 0.455 // Geneva city
        case .vaud: 1.535 // Lausanne
        case .baselStadt: 0.0 // Combined
        case .zug: 0.60
        default: 1.0
        }
    }
}
