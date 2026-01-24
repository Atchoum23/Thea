import Foundation

import Combine

/// Analytics service for income tracking and forecasting
public actor IncomeAnalytics {
    public static let shared = IncomeAnalytics()

    private init() {}

    // MARK: - Income Analysis

    /// Analyzes income trends over a time period
    public func analyzeTrends(_ streams: [IncomeStream], period: AnalysisPeriod) async throws -> TrendAnalysis {
        let filteredStreams = filterByPeriod(streams, period: period)

        guard !filteredStreams.isEmpty else {
            throw AnalyticsError.insufficientData
        }

        let totalIncome = filteredStreams.reduce(into: 0.0) { $0 += $1.monthlyAmount }
        let averageIncome = totalIncome / Double(max(period.months, 1))

        let growth = calculateGrowthRate(filteredStreams, period: period)
        let volatility = calculateVolatility(filteredStreams)
        let diversification = calculateDiversificationScore(filteredStreams)

        return TrendAnalysis(
            period: period,
            totalIncome: totalIncome,
            averageMonthlyIncome: averageIncome,
            growthRate: growth,
            volatility: volatility,
            diversificationScore: diversification,
            topPerformers: getTopPerformers(filteredStreams, count: 3),
            insights: generateInsights(totalIncome, growth, volatility)
        )
    }

    /// Forecasts income for future periods
    public func forecastIncome(_ streams: [IncomeStream], months: Int) async throws -> IncomeForecast {
        guard !streams.isEmpty else {
            throw AnalyticsError.insufficientData
        }

        let currentMonthly = streams.reduce(into: 0.0) { $0 += $1.monthlyAmount }
        let historicalGrowth = calculateGrowthRate(streams, period: .year)

        var projections: [MonthlyProjection] = []
        var accumulatedIncome = 0.0

        for month in 1...months {
            let monthlyAmount = currentMonthly * pow(1 + (historicalGrowth / 100), Double(month))
            accumulatedIncome += monthlyAmount

            projections.append(MonthlyProjection(
                month: month,
                projectedIncome: monthlyAmount,
                accumulatedIncome: accumulatedIncome,
                confidence: calculateConfidence(month)
            ))
        }

        return IncomeForecast(
            projections: projections,
            totalProjected: accumulatedIncome,
            assumedGrowthRate: historicalGrowth,
            confidenceLevel: calculateOverallConfidence(months)
        )
    }

    /// Analyzes income diversification
    public func analyzeDiversification(_ streams: [IncomeStream]) async -> DiversificationReport {
        let totalIncome = streams.reduce(0.0) { $0 + $1.monthlyAmount }

        guard totalIncome > 0 else {
            return DiversificationReport(
                score: 0,
                streamCount: 0,
                concentrationRisk: 1.0,
                categoryBreakdown: [:],
                recommendations: ["Add income streams to improve diversification"]
            )
        }

        let categoryBreakdown = Dictionary(grouping: streams) { $0.category }
            .mapValues { categoryStreams in
                let categoryTotal = categoryStreams.reduce(0.0) { $0 + $1.monthlyAmount }
                return (categoryTotal / totalIncome) * 100
            }

        let maxCategoryPercentage = categoryBreakdown.values.max() ?? 0
        let score = calculateDiversificationScore(streams)

        var recommendations: [String] = []
        if maxCategoryPercentage > 70 {
            recommendations.append("Over 70% of income comes from one category - consider diversifying")
        }
        if streams.count < 3 {
            recommendations.append("Add more income streams to reduce risk")
        }
        if score < 50 {
            recommendations.append("Diversification score is low - spread income across more sources")
        }

        return DiversificationReport(
            score: score,
            streamCount: streams.count,
            concentrationRisk: maxCategoryPercentage / 100,
            categoryBreakdown: categoryBreakdown,
            recommendations: recommendations.isEmpty ? ["Diversification looks good!"] : recommendations
        )
    }

    /// Calculates tax estimates
    public func calculateTaxEstimate(_ streams: [IncomeStream], year: Int) async -> TaxEstimateReport {
        let totalAnnualIncome = streams.reduce(0.0) { $0 + ($1.monthlyAmount * 12) }

        let taxEstimate = TaxEstimate.calculate(grossIncome: totalAnnualIncome, year: year)

        let quarterlyPayment = taxEstimate.totalTax / 4

        return TaxEstimateReport(
            grossIncome: totalAnnualIncome,
            estimatedFederalTax: taxEstimate.federalTax,
            estimatedStateTax: taxEstimate.stateTax,
            estimatedSelfEmploymentTax: taxEstimate.selfEmploymentTax,
            totalTaxLiability: taxEstimate.totalTax,
            effectiveTaxRate: taxEstimate.effectiveRate,
            quarterlyPayment: quarterlyPayment,
            netIncome: totalAnnualIncome - taxEstimate.totalTax,
            recommendations: generateTaxRecommendations(taxEstimate)
        )
    }

    // MARK: - Private Helpers

    private func filterByPeriod(_ streams: [IncomeStream], period: AnalysisPeriod) -> [IncomeStream] {
        // Would filter based on actual date ranges
        // For now, return all streams
        streams
    }

    private func calculateGrowthRate(_ streams: [IncomeStream], period: AnalysisPeriod) -> Double {
        // Simplified growth calculation
        guard streams.count >= 2 else { return 0.0 }

        let sorted = streams.sorted { $0.startDate < $1.startDate }
        guard let firstStream = sorted.first, let lastStream = sorted.last else { return 0.0 }
        let first = firstStream.monthlyAmount
        let last = lastStream.monthlyAmount

        guard first > 0 else { return 0.0 }

        return ((last - first) / first) * 100
    }

    private func calculateVolatility(_ streams: [IncomeStream]) -> Double {
        guard streams.count > 1 else { return 0.0 }

        let incomes = streams.map { $0.monthlyAmount }
        let average = incomes.reduce(0, +) / Double(incomes.count)

        let squaredDifferences = incomes.map { pow($0 - average, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(incomes.count)
        let standardDeviation = sqrt(variance)

        // Return as percentage of average
        return (standardDeviation / average) * 100
    }

    private func calculateDiversificationScore(_ streams: [IncomeStream]) -> Double {
        guard !streams.isEmpty else { return 0 }

        let totalIncome = streams.reduce(0.0) { $0 + $1.monthlyAmount }
        guard totalIncome > 0 else { return 0 }

        // Calculate Herfindahl-Hirschman Index (HHI)
        let shares = streams.map { ($0.monthlyAmount / totalIncome) * 100 }
        let hhi = shares.reduce(0) { $0 + pow($1, 2) }

        // Convert to diversification score (0-100, higher is better)
        // HHI ranges from 1/n*10000 (perfectly diversified) to 10000 (monopoly)
        let maxHHI = 10_000.0
        return max(0, min(100, (1 - (hhi / maxHHI)) * 100))
    }

    private func getTopPerformers(_ streams: [IncomeStream], count: Int) -> [IncomeStream] {
        Array(streams.sorted { $0.monthlyAmount > $1.monthlyAmount }.prefix(count))
    }

    private func generateInsights(_ total: Double, _ growth: Double, _ volatility: Double) -> [String] {
        var insights: [String] = []

        if growth > 10 {
            insights.append("Strong income growth of \(String(format: "%.1f", growth))% detected")
        } else if growth < -5 {
            insights.append("Income declining by \(String(format: "%.1f", abs(growth)))% - review underperforming streams")
        }

        if volatility > 30 {
            insights.append("High income volatility (\(String(format: "%.1f", volatility))%) - consider stabilizing sources")
        } else if volatility < 10 {
            insights.append("Income is stable with low volatility")
        }

        if total > 100_000 {
            insights.append("Excellent total income performance")
        }

        return insights.isEmpty ? ["Continue monitoring income trends"] : insights
    }

    private func calculateConfidence(_ monthsAhead: Int) -> Double {
        // Confidence decreases with longer forecasts
        max(0.3, 1.0 - (Double(monthsAhead) * 0.05))
    }

    private func calculateOverallConfidence(_ months: Int) -> String {
        if months <= 3 { return "High" }
        if months <= 6 { return "Medium" }
        return "Low"
    }

    private func generateTaxRecommendations(_ estimate: TaxEstimate) -> [String] {
        var recommendations: [String] = []

        if estimate.selfEmploymentTax > 5_000 {
            recommendations.append("Consider S-Corp election to potentially reduce self-employment tax")
        }

        if estimate.totalTax > 20_000 {
            recommendations.append("Make quarterly estimated tax payments to avoid penalties")
        }

        if estimate.effectiveRate > 25 {
            recommendations.append("Review tax deductions and retirement contributions to lower tax burden")
        }

        recommendations.append("Consult with a tax professional for personalized advice")

        return recommendations
    }

    public enum AnalyticsError: Error, Sendable, LocalizedError {
        case insufficientData
        case invalidPeriod

        public var errorDescription: String? {
            switch self {
            case .insufficientData:
                return "Insufficient data for analysis"
            case .invalidPeriod:
                return "Invalid analysis period"
            }
        }
    }
}

// MARK: - Analysis Models

public enum AnalysisPeriod: Sendable {
    case month
    case quarter
    case year
    case custom(Int) // months

    var months: Int {
        switch self {
        case .month: return 1
        case .quarter: return 3
        case .year: return 12
        case .custom(let months): return months
        }
    }
}

public struct TrendAnalysis: Sendable {
    public let period: AnalysisPeriod
    public let totalIncome: Double
    public let averageMonthlyIncome: Double
    public let growthRate: Double
    public let volatility: Double
    public let diversificationScore: Double
    public let topPerformers: [IncomeStream]
    public let insights: [String]
}

public struct IncomeForecast: Sendable {
    public let projections: [MonthlyProjection]
    public let totalProjected: Double
    public let assumedGrowthRate: Double
    public let confidenceLevel: String
}

public struct MonthlyProjection: Sendable {
    public let month: Int
    public let projectedIncome: Double
    public let accumulatedIncome: Double
    public let confidence: Double
}

public struct DiversificationReport: Sendable {
    public let score: Double
    public let streamCount: Int
    public let concentrationRisk: Double
    public let categoryBreakdown: [IncomeCategory: Double]
    public let recommendations: [String]
}

public struct TaxEstimateReport: Sendable {
    public let grossIncome: Double
    public let estimatedFederalTax: Double
    public let estimatedStateTax: Double
    public let estimatedSelfEmploymentTax: Double
    public let totalTaxLiability: Double
    public let effectiveTaxRate: Double
    public let quarterlyPayment: Double
    public let netIncome: Double
    public let recommendations: [String]
}

// MARK: - Coordinator

@MainActor
public final class IncomeAnalyticsCoordinator: ObservableObject {
    @Published public var trendAnalysis: TrendAnalysis?
    @Published public var forecast: IncomeForecast?
    @Published public var diversification: DiversificationReport?
    @Published public var taxEstimate: TaxEstimateReport?
    @Published public var isAnalyzing = false

    private let analytics = IncomeAnalytics.shared

    public init() {}

    public func analyzeTrends(_ streams: [IncomeStream], period: AnalysisPeriod) async {
        isAnalyzing = true
        do {
            trendAnalysis = try await analytics.analyzeTrends(streams, period: period)
        } catch {
            print("Trend analysis failed: \(error)")
        }
        isAnalyzing = false
    }

    public func forecastIncome(_ streams: [IncomeStream], months: Int) async {
        isAnalyzing = true
        do {
            forecast = try await analytics.forecastIncome(streams, months: months)
        } catch {
            print("Income forecast failed: \(error)")
        }
        isAnalyzing = false
    }

    public func analyzeDiversification(_ streams: [IncomeStream]) async {
        isAnalyzing = true
        diversification = await analytics.analyzeDiversification(streams)
        isAnalyzing = false
    }

    public func calculateTaxes(_ streams: [IncomeStream], year: Int) async {
        isAnalyzing = true
        taxEstimate = await analytics.calculateTaxEstimate(streams, year: year)
        isAnalyzing = false
    }
}
