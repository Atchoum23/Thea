import Foundation

// MARK: - Income Stream

/// Represents an income stream
public struct IncomeStream: Sendable, Codable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var type: IncomeType
    public var category: IncomeCategory
    public var isActive: Bool
    public var monthlyAmount: Double // Estimated or actual
    public var currency: String
    public var startDate: Date
    public var endDate: Date?
    public var notes: String?
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        type: IncomeType,
        category: IncomeCategory,
        isActive: Bool = true,
        monthlyAmount: Double,
        currency: String = "USD",
        startDate: Date = Date(),
        endDate: Date? = nil,
        notes: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.category = category
        self.isActive = isActive
        self.monthlyAmount = monthlyAmount
        self.currency = currency
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.tags = tags
    }

    /// Annual projected income
    public var annualProjection: Double {
        monthlyAmount * 12.0
    }
}

// MARK: - Income Entry

/// Individual income transaction
public struct IncomeEntry: Sendable, Codable, Identifiable {
    public let id: UUID
    public var streamID: UUID
    public var amount: Double
    public var currency: String
    public var receivedDate: Date
    public var description: String?
    public var platformFee: Double? // For marketplaces
    public var taxWithheld: Double?
    public var invoiceNumber: String?

    public init(
        id: UUID = UUID(),
        streamID: UUID,
        amount: Double,
        currency: String = "USD",
        receivedDate: Date = Date(),
        description: String? = nil,
        platformFee: Double? = nil,
        taxWithheld: Double? = nil,
        invoiceNumber: String? = nil
    ) {
        self.id = id
        self.streamID = streamID
        self.amount = amount
        self.currency = currency
        self.receivedDate = receivedDate
        self.description = description
        self.platformFee = platformFee
        self.taxWithheld = taxWithheld
        self.invoiceNumber = invoiceNumber
    }

    /// Net amount after fees
    public var netAmount: Double {
        amount - (platformFee ?? 0) - (taxWithheld ?? 0)
    }
}

// MARK: - Gig Platform

/// Gig economy platform
public struct GigPlatform: Sendable, Codable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var category: GigCategory
    public var apiKey: String?
    public var isConnected: Bool
    public var lastSyncDate: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        category: GigCategory,
        apiKey: String? = nil,
        isConnected: Bool = false,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.apiKey = apiKey
        self.isConnected = isConnected
        self.lastSyncDate = lastSyncDate
    }

    // MARK: - Popular Platforms

    public static let upwork = GigPlatform(name: "Upwork", category: .freelancing)
    public static let fiverr = GigPlatform(name: "Fiverr", category: .freelancing)
    public static let uber = GigPlatform(name: "Uber", category: .rideshare)
    public static let doordash = GigPlatform(name: "DoorDash", category: .delivery)
    public static let airbnb = GigPlatform(name: "Airbnb", category: .rental)
    public static let etsy = GigPlatform(name: "Etsy", category: .ecommerce)
    public static let youtube = GigPlatform(name: "YouTube", category: .content)
    public static let patreon = GigPlatform(name: "Patreon", category: .content)
}

// MARK: - Income Report

/// Monthly/yearly income report
public struct IncomeReport: Sendable, Codable {
    public var period: DateInterval
    public var totalIncome: Double
    public var activeStreams: Int
    public var topStream: IncomeStream?
    public var streamBreakdown: [UUID: Double] // streamID -> amount
    public var categoryBreakdown: [IncomeCategory: Double]
    public var typeBreakdown: [IncomeType: Double]
    public var averageMonthlyIncome: Double
    public var growthRate: Double? // % compared to previous period

    public init(
        period: DateInterval,
        totalIncome: Double,
        activeStreams: Int,
        topStream: IncomeStream? = nil,
        streamBreakdown: [UUID: Double] = [:],
        categoryBreakdown: [IncomeCategory: Double] = [:],
        typeBreakdown: [IncomeType: Double] = [:],
        averageMonthlyIncome: Double,
        growthRate: Double? = nil
    ) {
        self.period = period
        self.totalIncome = totalIncome
        self.activeStreams = activeStreams
        self.topStream = topStream
        self.streamBreakdown = streamBreakdown
        self.categoryBreakdown = categoryBreakdown
        self.typeBreakdown = typeBreakdown
        self.averageMonthlyIncome = averageMonthlyIncome
        self.growthRate = growthRate
    }
}

// MARK: - Tax Estimate

/// Tax estimation for income
public struct TaxEstimate: Sendable, Codable {
    public var year: Int
    public var grossIncome: Double
    public var estimatedFederalTax: Double
    public var estimatedStateTax: Double
    public var estimatedSelfEmploymentTax: Double
    public var standardDeduction: Double
    public var quarterlyPaymentDue: Double

    public init(
        year: Int,
        grossIncome: Double,
        estimatedFederalTax: Double,
        estimatedStateTax: Double,
        estimatedSelfEmploymentTax: Double,
        standardDeduction: Double,
        quarterlyPaymentDue: Double
    ) {
        self.year = year
        self.grossIncome = grossIncome
        self.estimatedFederalTax = estimatedFederalTax
        self.estimatedStateTax = estimatedStateTax
        self.estimatedSelfEmploymentTax = estimatedSelfEmploymentTax
        self.standardDeduction = standardDeduction
        self.quarterlyPaymentDue = quarterlyPaymentDue
    }

    /// Total tax liability
    public var totalTax: Double {
        estimatedFederalTax + estimatedStateTax + estimatedSelfEmploymentTax
    }

    /// Effective tax rate
    public var effectiveTaxRate: Double {
        guard grossIncome > 0 else { return 0 }
        return (totalTax / grossIncome) * 100.0
    }

    /// Alias for estimatedFederalTax
    public var federalTax: Double {
        estimatedFederalTax
    }

    /// Alias for estimatedStateTax
    public var stateTax: Double {
        estimatedStateTax
    }

    /// Alias for estimatedSelfEmploymentTax
    public var selfEmploymentTax: Double {
        estimatedSelfEmploymentTax
    }

    /// Alias for effectiveTaxRate
    public var effectiveRate: Double {
        effectiveTaxRate
    }

    /// Calculate tax estimate for income
    public static func calculate(grossIncome: Double, year: Int = Calendar.current.component(.year, from: Date())) -> TaxEstimate {
        // Simplified 2024 US tax calculation (single filer)
        let standardDeduction = 14_600.0

        let taxableIncome = max(0, grossIncome - standardDeduction)

        // Federal tax brackets (2024, single)
        var federalTax = 0.0
        if taxableIncome > 578_125 {
            federalTax = 174_238.25 + (taxableIncome - 578_125) * 0.37
        } else if taxableIncome > 231_250 {
            federalTax = 52_832.75 + (taxableIncome - 231_250) * 0.35
        } else if taxableIncome > 182_100 {
            federalTax = 37_104.0 + (taxableIncome - 182_100) * 0.32
        } else if taxableIncome > 95_375 {
            federalTax = 16_290.0 + (taxableIncome - 95_375) * 0.24
        } else if taxableIncome > 44_725 {
            federalTax = 5_147.0 + (taxableIncome - 44_725) * 0.22
        } else if taxableIncome > 11_000 {
            federalTax = 1_100.0 + (taxableIncome - 11_000) * 0.12
        } else {
            federalTax = taxableIncome * 0.10
        }

        // State tax (average ~5%)
        let stateTax = taxableIncome * 0.05

        // Self-employment tax (15.3% on 92.35% of net income)
        let selfEmploymentTax = grossIncome * 0.9235 * 0.153

        let totalTax = federalTax + stateTax + selfEmploymentTax
        let quarterlyPayment = totalTax / 4.0

        return TaxEstimate(
            year: year,
            grossIncome: grossIncome,
            estimatedFederalTax: federalTax,
            estimatedStateTax: stateTax,
            estimatedSelfEmploymentTax: selfEmploymentTax,
            standardDeduction: standardDeduction,
            quarterlyPaymentDue: quarterlyPayment
        )
    }
}

// MARK: - Enums

public enum IncomeType: String, Sendable, Codable, CaseIterable, Hashable {
    case passive = "Passive"
    case active = "Active"
    case portfolio = "Portfolio"

    public var description: String {
        switch self {
        case .passive: return "Income generated with minimal effort"
        case .active: return "Income requiring active work"
        case .portfolio: return "Investment income"
        }
    }
}

public enum IncomeCategory: String, Sendable, Codable, CaseIterable, Hashable {
    case freelancing = "Freelancing"
    case consulting = "Consulting"
    case rental = "Rental Income"
    case investments = "Investments"
    case royalties = "Royalties"
    case ecommerce = "E-commerce"
    case content = "Content Creation"
    case affiliate = "Affiliate Marketing"
    case gig = "Gig Economy"
    case other = "Other"

    public var icon: String {
        switch self {
        case .freelancing: return "briefcase.fill"
        case .consulting: return "person.3.fill"
        case .rental: return "house.fill"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .royalties: return "music.note"
        case .ecommerce: return "cart.fill"
        case .content: return "video.fill"
        case .affiliate: return "link"
        case .gig: return "car.fill"
        case .other: return "dollarsign.circle.fill"
        }
    }
}

public enum GigCategory: String, Sendable, Codable, CaseIterable, Hashable {
    case freelancing = "Freelancing"
    case rideshare = "Rideshare"
    case delivery = "Delivery"
    case rental = "Rental"
    case ecommerce = "E-commerce"
    case content = "Content"
    case taskServices = "Task Services"

    public var platforms: [String] {
        switch self {
        case .freelancing: return ["Upwork", "Fiverr", "Toptal", "Freelancer"]
        case .rideshare: return ["Uber", "Lyft"]
        case .delivery: return ["DoorDash", "Uber Eats", "Instacart", "Postmates"]
        case .rental: return ["Airbnb", "VRBO", "Turo"]
        case .ecommerce: return ["Etsy", "eBay", "Amazon", "Shopify"]
        case .content: return ["YouTube", "Patreon", "Substack", "Twitch"]
        case .taskServices: return ["TaskRabbit", "Thumbtack", "Handy"]
        }
    }
}

// MARK: - Errors

public enum IncomeError: Error, LocalizedError, Sendable {
    case streamNotFound
    case invalidAmount
    case platformNotConnected
    case syncFailed(String)

    public var errorDescription: String? {
        switch self {
        case .streamNotFound:
            return "Income stream not found"
        case .invalidAmount:
            return "Invalid income amount"
        case .platformNotConnected:
            return "Platform not connected"
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        }
    }
}
