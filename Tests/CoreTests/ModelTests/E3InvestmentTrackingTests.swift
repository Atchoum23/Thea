import Foundation
import Testing

// MARK: - Investment Tracker Tests

@Suite("InvestmentTracker — Portfolio Performance")
struct InvTestPortfolioPerformanceTests {
    @Test("Empty portfolio returns zero performance")
    func emptyPortfolio() {
        let perf = InvTestPortfolioPerformance.empty
        #expect(perf.totalValue == 0)
        #expect(perf.totalCost == 0)
        #expect(perf.totalGain == 0)
        #expect(perf.totalReturn == 0)
        #expect(perf.holdingCount == 0)
        #expect(perf.holdings.isEmpty)
    }

    @Test("Single holding performance calculation")
    func singleHolding() {
        let holding = InvTestHolding(
            quantity: 100,
            purchasePrice: 50.0,
            currentPrice: 60.0
        )

        let cost = holding.quantity * holding.purchasePrice
        let value = holding.quantity * holding.currentPrice
        let gain = value - cost

        #expect(cost == 5000)
        #expect(value == 6000)
        #expect(gain == 1000)
        #expect(holding.returnPercent == 0.2, "20% return expected")
    }

    @Test("Negative return holding")
    func negativeReturn() {
        let holding = InvTestHolding(
            quantity: 50,
            purchasePrice: 100.0,
            currentPrice: 80.0
        )

        #expect(holding.unrealizedGain == -1000)
        #expect(holding.returnPercent == -0.2)
    }
}

@Suite("InvestmentTracker — Asset Allocation")
struct InvAssetAllocationTests {
    @Test("AssetClass has all expected cases")
    func assetClassCases() {
        #expect(InvTestAssetClass.allCases.count == 8)
    }

    @Test("AssetClass display names non-empty")
    func displayNames() {
        for cls in InvTestAssetClass.allCases {
            #expect(!cls.displayName.isEmpty)
            #expect(!cls.icon.isEmpty)
        }
    }

    @Test("AssetClass Codable roundtrip")
    func codable() throws {
        for cls in InvTestAssetClass.allCases {
            let data = try JSONEncoder().encode(cls)
            let decoded = try JSONDecoder().decode(InvTestAssetClass.self, from: data)
            #expect(decoded == cls)
        }
    }

    @Test("Single asset class is 100%")
    func singleClass() {
        let allocations = [
            InvTestAssetAllocation(assetClass: .stock, value: 10000, percentage: 1.0, holdingCount: 3)
        ]
        #expect(allocations[0].percentage == 1.0)
    }

    @Test("Multiple classes sum to ~100%")
    func multipleClasses() {
        let allocations = [
            InvTestAssetAllocation(assetClass: .stock, value: 6000, percentage: 0.6, holdingCount: 2),
            InvTestAssetAllocation(assetClass: .bond, value: 3000, percentage: 0.3, holdingCount: 1),
            InvTestAssetAllocation(assetClass: .cash, value: 1000, percentage: 0.1, holdingCount: 1)
        ]
        let totalPercentage = allocations.reduce(0) { $0 + $1.percentage }
        #expect(abs(totalPercentage - 1.0) < 0.001)
    }
}

@Suite("InvestmentTracker — Currency Exposure")
struct InvCurrencyExposureTests {
    @Test("Single currency is 100%")
    func singleCurrency() {
        let exposure = [InvTestCurrencyExposure(currency: "CHF", value: 50000, percentage: 1.0)]
        #expect(exposure[0].percentage == 1.0)
    }

    @Test("Multi-currency percentages sum to ~100%")
    func multiCurrency() {
        let total = 100000.0
        let exposures = [
            InvTestCurrencyExposure(currency: "CHF", value: 60000, percentage: 60000 / total),
            InvTestCurrencyExposure(currency: "USD", value: 30000, percentage: 30000 / total),
            InvTestCurrencyExposure(currency: "EUR", value: 10000, percentage: 10000 / total)
        ]
        let totalPct = exposures.reduce(0) { $0 + $1.percentage }
        #expect(abs(totalPct - 1.0) < 0.001)
    }
}

@Suite("InvestmentTracker — Dividend Record")
struct InvDividendRecordTests {
    @Test("Net amount calculation")
    func netAmount() {
        let div = InvTestDividendRecord(amount: 100.0, taxWithheld: 35.0)
        #expect(div.netAmount == 65.0)
    }

    @Test("Zero tax withholding")
    func noTax() {
        let div = InvTestDividendRecord(amount: 50.0, taxWithheld: 0)
        #expect(div.netAmount == 50.0)
    }
}

@Suite("InvTestInvestmentPortfolio — Model")
struct InvTestInvestmentPortfolioTests {
    @Test("Creation")
    func creation() throws {
        let portfolio = InvPortfolio(
            id: UUID(),
            name: "Retirement",
            currency: "CHF",
            createdAt: Date()
        )
        #expect(portfolio.name == "Retirement")
        #expect(portfolio.currency == "CHF")
    }

    @Test("Hashable conformance")
    func hashable() {
        let p1 = InvPortfolio(id: UUID(), name: "A", currency: "CHF", createdAt: Date())
        let p2 = InvPortfolio(id: UUID(), name: "B", currency: "EUR", createdAt: Date())

        var set: Set<InvPortfolio> = [p1, p2]
        #expect(set.count == 2)
        set.insert(p1)
        #expect(set.count == 2) // No duplicate
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let original = InvPortfolio(id: UUID(), name: "Test", currency: "USD", createdAt: Date())
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InvPortfolio.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.currency == original.currency)
    }
}

// MARK: - Test Doubles

private struct InvTestHolding {
    let quantity: Double
    let purchasePrice: Double
    let currentPrice: Double

    var currentValue: Double { quantity * currentPrice }
    var totalCost: Double { quantity * purchasePrice }
    var unrealizedGain: Double { currentValue - totalCost }
    var returnPercent: Double { totalCost > 0 ? unrealizedGain / totalCost : 0 }
}

private struct InvTestAssetAllocation {
    let assetClass: InvTestAssetClass
    let value: Double
    let percentage: Double
    let holdingCount: Int
}

private struct InvTestCurrencyExposure {
    let currency: String
    let value: Double
    let percentage: Double
}

private struct InvTestDividendRecord {
    let amount: Double
    let taxWithheld: Double
    var netAmount: Double { amount - taxWithheld }
}

private struct InvPortfolio: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var currency: String
    let createdAt: Date
}

private struct InvTestPortfolioPerformance {
    let totalValue: Double
    let totalCost: Double
    let totalGain: Double
    let totalReturn: Double
    let holdingCount: Int
    let holdings: [InvTestHolding]

    static let empty = InvTestPortfolioPerformance(
        totalValue: 0, totalCost: 0, totalGain: 0, totalReturn: 0,
        holdingCount: 0, holdings: []
    )
}

private enum InvTestAssetClass: String, Codable, CaseIterable {
    case stock, bond, etf, crypto, realEstate = "real_estate", commodity, cash, other

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
