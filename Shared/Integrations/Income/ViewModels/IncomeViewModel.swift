import Foundation
import SwiftUI

/// View model for income dashboard
@MainActor
@Observable
public final class IncomeViewModel {

    // MARK: - Published State

    public var streams: [IncomeStream] = []
    public var recentEntries: [IncomeEntry] = []
    public var monthlyReport: IncomeReport?
    public var taxEstimate: TaxEstimate?
    public var connectedPlatforms: [GigPlatform] = []
    public var isLoading = false
    public var errorMessage: String?

    // MARK: - Dependencies

    private let incomeService: IncomeService
    private let gigIntegration: GigPlatformIntegration

    // MARK: - Initialization

    public init(
        incomeService: IncomeService = IncomeService(),
        gigIntegration: GigPlatformIntegration = GigPlatformIntegration()
    ) {
        self.incomeService = incomeService
        self.gigIntegration = gigIntegration
    }

    // MARK: - Data Loading

    public func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load streams
            streams = try await incomeService.fetchStreams()

            // Load monthly report
            let now = Date()
            let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now))!
            let monthEnd = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
            let monthRange = DateInterval(start: monthStart, end: monthEnd)

            monthlyReport = try await incomeService.generateReport(for: monthRange)

            // Load recent entries (last 30 days)
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
            let recentRange = DateInterval(start: thirtyDaysAgo, end: now)
            recentEntries = try await incomeService.fetchEntries(for: recentRange)

            // Load tax estimate
            let currentYear = Calendar.current.component(.year, from: now)
            taxEstimate = try await incomeService.calculateTaxEstimate(for: currentYear)

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func refreshData() async {
        await loadData()
    }

    // MARK: - Stream Management

    public func addStream(_ stream: IncomeStream) async {
        do {
            try await incomeService.addStream(stream)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateStream(_ stream: IncomeStream) async {
        do {
            try await incomeService.updateStream(stream)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Entry Management

    public func addEntry(streamID: UUID, amount: Double, receivedDate: Date, description: String?) async {
        let entry = IncomeEntry(
            streamID: streamID,
            amount: amount,
            receivedDate: receivedDate,
            description: description
        )

        do {
            try await incomeService.addEntry(entry)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Platform Integration

    public func connectPlatform(_ platform: GigPlatform, apiKey: String) async {
        do {
            try await gigIntegration.connect(platform: platform, apiKey: apiKey)
            connectedPlatforms.append(platform)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func syncPlatform(_ platform: GigPlatform) async {
        do {
            let entries = try await gigIntegration.syncIncome(from: platform)

            // Add synced entries
            for entry in entries {
                try await incomeService.addEntry(entry)
            }

            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed Properties

    public var totalMonthlyIncome: Double {
        streams.filter { $0.isActive }.reduce(0.0) { $0 + $1.monthlyAmount }
    }

    public var totalAnnualProjection: Double {
        totalMonthlyIncome * 12.0
    }

    public var activeStreamsCount: Int {
        streams.filter { $0.isActive }.count
    }

    public var passiveIncomePercentage: Double {
        let passiveIncome = streams.filter { $0.type == .passive && $0.isActive }.reduce(0.0) { $0 + $1.monthlyAmount }
        guard totalMonthlyIncome > 0 else { return 0 }
        return (passiveIncome / totalMonthlyIncome) * 100.0
    }

    public var topStream: IncomeStream? {
        streams.filter { $0.isActive }.max { $0.monthlyAmount < $1.monthlyAmount }
    }

    public var categoryBreakdown: [(IncomeCategory, Double)] {
        var breakdown: [IncomeCategory: Double] = [:]
        for stream in streams where stream.isActive {
            breakdown[stream.category, default: 0] += stream.monthlyAmount
        }
        return breakdown.sorted { $0.value > $1.value }
    }

    public var hasActiveStreams: Bool {
        activeStreamsCount > 0
    }
}
