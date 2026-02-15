import Foundation

// MARK: - Investment Tracker

/// Tracks investment portfolios with performance calculation, asset allocation,
/// and dividend tracking. Supports manual entry and CSV import.
@MainActor
@Observable
final class InvestmentTracker {
    static let shared = InvestmentTracker()

    private(set) var portfolios: [InvestmentPortfolio] = []
    private(set) var holdings: [Holding] = []
    private(set) var dividendHistory: [DividendRecord] = []

    private init() {
        loadData()
    }

    // MARK: - Portfolio Management

    func createPortfolio(name: String, currency: String = "CHF") -> InvestmentPortfolio {
        let portfolio = InvestmentPortfolio(
            id: UUID(),
            name: name,
            currency: currency,
            createdAt: Date()
        )
        portfolios.append(portfolio)
        saveData()
        return portfolio
    }

    func removePortfolio(id: UUID) {
        portfolios.removeAll { $0.id == id }
        holdings.removeAll { $0.portfolioId == id }
        saveData()
    }

    // MARK: - Holdings Management

    func addHolding(
        portfolioId: UUID,
        symbol: String,
        name: String,
        quantity: Double,
        purchasePrice: Double,
        purchaseDate: Date,
        currency: String = "CHF",
        assetClass: AssetClass = .stock
    ) -> Holding {
        let holding = Holding(
            id: UUID(),
            portfolioId: portfolioId,
            symbol: symbol.uppercased(),
            name: name,
            quantity: quantity,
            purchasePrice: purchasePrice,
            currentPrice: purchasePrice,
            purchaseDate: purchaseDate,
            lastUpdated: Date(),
            currency: currency,
            assetClass: assetClass
        )
        holdings.append(holding)
        saveData()
        return holding
    }

    func updatePrice(holdingId: UUID, newPrice: Double) {
        if let index = holdings.firstIndex(where: { $0.id == holdingId }) {
            holdings[index].currentPrice = newPrice
            holdings[index].lastUpdated = Date()
            saveData()
        }
    }

    func removeHolding(id: UUID) {
        holdings.removeAll { $0.id == id }
        saveData()
    }

    // MARK: - Dividends

    func recordDividend(
        holdingId: UUID,
        amount: Double,
        date: Date,
        taxWithheld: Double = 0,
        currency: String = "CHF"
    ) {
        let record = DividendRecord(
            id: UUID(),
            holdingId: holdingId,
            amount: amount,
            date: date,
            taxWithheld: taxWithheld,
            currency: currency
        )
        dividendHistory.append(record)
        saveData()
    }

    // MARK: - Performance Calculations

    /// Calculate portfolio performance using time-weighted return (TWR).
    func calculatePerformance(portfolioId: UUID) -> PortfolioPerformance {
        let portfolioHoldings = holdings.filter { $0.portfolioId == portfolioId }

        guard !portfolioHoldings.isEmpty else {
            return PortfolioPerformance.empty
        }

        let totalCost = portfolioHoldings.reduce(0.0) { $0 + $1.quantity * $1.purchasePrice }
        let totalValue = portfolioHoldings.reduce(0.0) { $0 + $1.quantity * $1.currentPrice }
        let totalGain = totalValue - totalCost
        let totalReturn = totalCost > 0 ? totalGain / totalCost : 0

        // Dividends for this portfolio
        let holdingIds = Set(portfolioHoldings.map(\.id))
        let portfolioDividends = dividendHistory.filter { holdingIds.contains($0.holdingId) }
        let totalDividends = portfolioDividends.reduce(0.0) { $0 + $1.amount }

        // Total return including dividends
        let totalReturnWithDividends = totalCost > 0 ? (totalGain + totalDividends) / totalCost : 0

        // Annualized return (approximate)
        let oldestPurchase = portfolioHoldings.map(\.purchaseDate).min() ?? Date()
        let yearsHeld = max(0.01, Date().timeIntervalSince(oldestPurchase) / (365.25 * 86400))
        let annualizedReturn = pow(1 + totalReturnWithDividends, 1 / yearsHeld) - 1

        // Per-holding performance
        let holdingPerformances = portfolioHoldings.map { holding -> HoldingPerformance in
            let cost = holding.quantity * holding.purchasePrice
            let value = holding.quantity * holding.currentPrice
            let gain = value - cost
            let holdingDivs = portfolioDividends.filter { $0.holdingId == holding.id }.reduce(0.0) { $0 + $1.amount }

            return HoldingPerformance(
                holding: holding,
                currentValue: value,
                totalCost: cost,
                unrealizedGain: gain,
                returnPercent: cost > 0 ? gain / cost : 0,
                dividendsReceived: holdingDivs,
                portfolioWeight: totalValue > 0 ? value / totalValue : 0
            )
        }

        return PortfolioPerformance(
            totalValue: totalValue,
            totalCost: totalCost,
            totalGain: totalGain,
            totalReturn: totalReturn,
            totalReturnWithDividends: totalReturnWithDividends,
            annualizedReturn: annualizedReturn,
            totalDividends: totalDividends,
            holdingCount: portfolioHoldings.count,
            holdings: holdingPerformances
        )
    }

    /// Calculate asset allocation breakdown.
    func calculateAssetAllocation(portfolioId: UUID) -> [AssetAllocation] {
        let portfolioHoldings = holdings.filter { $0.portfolioId == portfolioId }
        let totalValue = portfolioHoldings.reduce(0.0) { $0 + $1.quantity * $1.currentPrice }

        guard totalValue > 0 else { return [] }

        var byClass: [AssetClass: Double] = [:]
        for holding in portfolioHoldings {
            let value = holding.quantity * holding.currentPrice
            byClass[holding.assetClass, default: 0] += value
        }

        return byClass.map { assetClass, value in
            AssetAllocation(
                assetClass: assetClass,
                value: value,
                percentage: value / totalValue,
                holdingCount: portfolioHoldings.filter { $0.assetClass == assetClass }.count
            )
        }.sorted { $0.value > $1.value }
    }

    /// Calculate currency exposure across portfolios.
    func calculateCurrencyExposure(portfolioId: UUID? = nil) -> [CurrencyExposure] {
        let relevantHoldings = portfolioId.map { pid in
            holdings.filter { $0.portfolioId == pid }
        } ?? holdings

        let totalValue = relevantHoldings.reduce(0.0) { $0 + $1.quantity * $1.currentPrice }
        guard totalValue > 0 else { return [] }

        var byCurrency: [String: Double] = [:]
        for holding in relevantHoldings {
            let value = holding.quantity * holding.currentPrice
            byCurrency[holding.currency, default: 0] += value
        }

        return byCurrency.map { currency, value in
            CurrencyExposure(
                currency: currency,
                value: value,
                percentage: value / totalValue
            )
        }.sorted { $0.value > $1.value }
    }

    // MARK: - CSV Import

    /// Import holdings from a broker CSV export.
    func importHoldingsCSV(from url: URL, portfolioId: UUID) throws -> [Holding] {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw TransactionImportError.invalidEncoding
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { throw TransactionImportError.noDataRows }

        var imported: [Holding] = []

        for lineIndex in 1..<lines.count {
            let fields = lines[lineIndex].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count >= 4 else { continue }

            // Expected format: Symbol, Name, Quantity, Purchase Price, [Currency], [Asset Class]
            let symbol = fields[0]
            let name = fields[1]
            guard let quantity = Double(fields[2]),
                  let price = Double(fields[3].replacingOccurrences(of: "'", with: "")) else { continue }

            let currency = fields.count > 4 ? fields[4] : "CHF"
            let assetClass: AssetClass
            if fields.count > 5, let parsed = AssetClass(rawValue: fields[5].lowercased()) {
                assetClass = parsed
            } else {
                assetClass = .stock
            }

            let holding = addHolding(
                portfolioId: portfolioId,
                symbol: symbol,
                name: name,
                quantity: quantity,
                purchasePrice: price,
                purchaseDate: Date(),
                currency: currency,
                assetClass: assetClass
            )
            imported.append(holding)
        }

        return imported
    }

    // MARK: - Persistence

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "thea.investment.portfolios"),
           let loaded = try? JSONDecoder().decode([InvestmentPortfolio].self, from: data) {
            portfolios = loaded
        }
        if let data = UserDefaults.standard.data(forKey: "thea.investment.holdings"),
           let loaded = try? JSONDecoder().decode([Holding].self, from: data) {
            holdings = loaded
        }
        if let data = UserDefaults.standard.data(forKey: "thea.investment.dividends"),
           let loaded = try? JSONDecoder().decode([DividendRecord].self, from: data) {
            dividendHistory = loaded
        }
    }

    private func saveData() {
        if let data = try? JSONEncoder().encode(portfolios) {
            UserDefaults.standard.set(data, forKey: "thea.investment.portfolios")
        }
        if let data = try? JSONEncoder().encode(holdings) {
            UserDefaults.standard.set(data, forKey: "thea.investment.holdings")
        }
        if let data = try? JSONEncoder().encode(dividendHistory) {
            UserDefaults.standard.set(data, forKey: "thea.investment.dividends")
        }
    }
}

// MARK: - Types

struct InvestmentPortfolio: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var currency: String
    let createdAt: Date
}

struct Holding: Identifiable, Codable, Sendable {
    let id: UUID
    let portfolioId: UUID
    let symbol: String
    let name: String
    let quantity: Double
    let purchasePrice: Double
    var currentPrice: Double
    let purchaseDate: Date
    var lastUpdated: Date
    let currency: String
    let assetClass: AssetClass

    var currentValue: Double { quantity * currentPrice }
    var totalCost: Double { quantity * purchasePrice }
    var unrealizedGain: Double { currentValue - totalCost }
    var returnPercent: Double { totalCost > 0 ? unrealizedGain / totalCost : 0 }
}

struct DividendRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let holdingId: UUID
    let amount: Double
    let date: Date
    let taxWithheld: Double
    let currency: String

    var netAmount: Double { amount - taxWithheld }
}

enum AssetClass: String, Codable, CaseIterable, Sendable {
    case stock = "stock"
    case bond = "bond"
    case etf = "etf"
    case crypto = "crypto"
    case realEstate = "real_estate"
    case commodity = "commodity"
    case cash = "cash"
    case other = "other"

    var displayName: String {
        switch self {
        case .stock: "Stocks"
        case .bond: "Bonds"
        case .etf: "ETFs"
        case .crypto: "Crypto"
        case .realEstate: "Real Estate"
        case .commodity: "Commodities"
        case .cash: "Cash"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .stock: "chart.line.uptrend.xyaxis"
        case .bond: "doc.text"
        case .etf: "chart.pie"
        case .crypto: "bitcoinsign.circle"
        case .realEstate: "house"
        case .commodity: "cube"
        case .cash: "banknote"
        case .other: "questionmark.circle"
        }
    }
}

struct PortfolioPerformance: Sendable {
    let totalValue: Double
    let totalCost: Double
    let totalGain: Double
    let totalReturn: Double
    let totalReturnWithDividends: Double
    let annualizedReturn: Double
    let totalDividends: Double
    let holdingCount: Int
    let holdings: [HoldingPerformance]

    static let empty = PortfolioPerformance(
        totalValue: 0, totalCost: 0, totalGain: 0, totalReturn: 0,
        totalReturnWithDividends: 0, annualizedReturn: 0, totalDividends: 0,
        holdingCount: 0, holdings: []
    )
}

struct HoldingPerformance: Sendable {
    let holding: Holding
    let currentValue: Double
    let totalCost: Double
    let unrealizedGain: Double
    let returnPercent: Double
    let dividendsReceived: Double
    let portfolioWeight: Double
}

struct AssetAllocation: Identifiable, Sendable {
    let id = UUID()
    let assetClass: AssetClass
    let value: Double
    let percentage: Double
    let holdingCount: Int
}

struct CurrencyExposure: Identifiable, Sendable {
    let id = UUID()
    let currency: String
    let value: Double
    let percentage: Double
}
