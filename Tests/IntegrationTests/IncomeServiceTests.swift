import Testing
import Foundation
@testable import Thea

/// Tests for income service
@Suite("Income Service Tests")
struct IncomeServiceTests {

    // MARK: - Stream Management Tests

    @Test("Add income stream")
    func testAddStream() async throws {
        let service = IncomeService()

        let stream = IncomeStream(
            name: "Freelance Design",
            type: .active,
            category: .freelancing,
            monthlyAmount: 2000
        )

        try await service.addStream(stream)

        let streams = try await service.fetchStreams()
        #expect(!streams.isEmpty)
        #expect(streams.first?.name == "Freelance Design")
    }

    @Test("Update income stream")
    func testUpdateStream() async throws {
        let service = IncomeService()

        var stream = IncomeStream(
            name: "Consulting",
            type: .active,
            category: .consulting,
            monthlyAmount: 3000
        )

        try await service.addStream(stream)

        stream.monthlyAmount = 3500
        try await service.updateStream(stream)

        let streams = try await service.fetchStreams()
        #expect(streams.first?.monthlyAmount == 3500)
    }

    @Test("Fetch streams sorted by amount")
    func testFetchStreamsSorted() async throws {
        let service = IncomeService()

        let stream1 = IncomeStream(name: "Stream 1", type: .active, category: .freelancing, monthlyAmount: 1000)
        let stream2 = IncomeStream(name: "Stream 2", type: .passive, category: .rental, monthlyAmount: 3000)
        let stream3 = IncomeStream(name: "Stream 3", type: .active, category: .consulting, monthlyAmount: 2000)

        try await service.addStream(stream1)
        try await service.addStream(stream2)
        try await service.addStream(stream3)

        let streams = try await service.fetchStreams()

        #expect(streams.count == 3)
        #expect(streams[0].monthlyAmount >= streams[1].monthlyAmount)
        #expect(streams[1].monthlyAmount >= streams[2].monthlyAmount)
    }

    // MARK: - Entry Management Tests

    @Test("Add income entry")
    func testAddEntry() async throws {
        let service = IncomeService()

        let stream = IncomeStream(name: "Test Stream", type: .active, category: .freelancing, monthlyAmount: 1000)
        try await service.addStream(stream)

        let entry = IncomeEntry(
            streamID: stream.id,
            amount: 500,
            receivedDate: Date()
        )

        try await service.addEntry(entry)

        let now = Date()
        let entries = try await service.fetchEntries(for: DateInterval(start: now.startOfDay, end: now.endOfDay))

        #expect(!entries.isEmpty)
        #expect(entries.first?.amount == 500)
    }

    @Test("Reject negative amount entry")
    func testRejectNegativeAmount() async throws {
        let service = IncomeService()

        let entry = IncomeEntry(
            streamID: UUID(),
            amount: -100,
            receivedDate: Date()
        )

        await #expect(throws: IncomeError.self) {
            try await service.addEntry(entry)
        }
    }

    @Test("Fetch entries for date range")
    func testFetchEntriesDateRange() async throws {
        let service = IncomeService()

        let streamID = UUID()
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let entry1 = IncomeEntry(streamID: streamID, amount: 100, receivedDate: today)
        let entry2 = IncomeEntry(streamID: streamID, amount: 200, receivedDate: yesterday)

        try await service.addEntry(entry1)
        try await service.addEntry(entry2)

        let todayRange = DateInterval(start: today.startOfDay, end: today.endOfDay)
        let todayEntries = try await service.fetchEntries(for: todayRange)

        #expect(todayEntries.count == 1)
        #expect(todayEntries.first?.amount == 100)
    }

    // MARK: - Report Generation Tests

    @Test("Generate income report")
    func testGenerateReport() async throws {
        let service = IncomeService()

        // Add stream
        let stream = IncomeStream(
            name: "Freelancing",
            type: .active,
            category: .freelancing,
            monthlyAmount: 2000
        )
        try await service.addStream(stream)

        // Add entries
        let now = Date()
        for i in 0..<5 {
            let entry = IncomeEntry(
                streamID: stream.id,
                amount: Double(100 * (i + 1)),
                receivedDate: Calendar.current.date(byAdding: .day, value: -i, to: now)!
            )
            try await service.addEntry(entry)
        }

        // Generate report
        let monthStart = now.startOfDay
        let monthEnd = Calendar.current.date(byAdding: .month, value: 1, to: monthStart)!
        let report = try await service.generateReport(for: DateInterval(start: monthStart, end: monthEnd))

        #expect(report.totalIncome > 0)
        #expect(report.activeStreams >= 1)
    }

    // MARK: - Tax Calculation Tests

    @Test("Calculate tax estimate")
    func testCalculateTaxEstimate() async throws {
        let service = IncomeService()

        // Add entries for current year
        let now = Date()
        let yearStart = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: now), month: 1, day: 1))!

        let stream = IncomeStream(name: "Test", type: .active, category: .freelancing, monthlyAmount: 5000)
        try await service.addStream(stream)

        for month in 1...12 {
            let monthDate = Calendar.current.date(byAdding: .month, value: month - 1, to: yearStart)!
            let entry = IncomeEntry(streamID: stream.id, amount: 5000, receivedDate: monthDate)
            try await service.addEntry(entry)
        }

        let currentYear = Calendar.current.component(.year, from: now)
        let taxEstimate = try await service.calculateTaxEstimate(for: currentYear)

        #expect(taxEstimate.grossIncome > 0)
        #expect(taxEstimate.totalTax > 0)
        #expect(taxEstimate.quarterlyPaymentDue > 0)
        #expect(taxEstimate.effectiveTaxRate > 0)
    }

    @Test("Tax calculation for different income levels")
    func testTaxCalculationLevels() {
        let lowIncome = TaxEstimate.calculate(grossIncome: 30000)
        #expect(lowIncome.effectiveTaxRate < 20)

        let mediumIncome = TaxEstimate.calculate(grossIncome: 80000)
        #expect(mediumIncome.effectiveTaxRate > lowIncome.effectiveTaxRate)

        let highIncome = TaxEstimate.calculate(grossIncome: 200000)
        #expect(highIncome.effectiveTaxRate > mediumIncome.effectiveTaxRate)
    }

    // MARK: - Analytics Tests

    @Test("Get active streams count")
    func testGetActiveStreamsCount() async throws {
        let service = IncomeService()

        let active1 = IncomeStream(name: "Active 1", type: .active, category: .freelancing, monthlyAmount: 1000, isActive: true)
        let active2 = IncomeStream(name: "Active 2", type: .passive, category: .rental, monthlyAmount: 2000, isActive: true)
        let inactive = IncomeStream(name: "Inactive", type: .active, category: .consulting, monthlyAmount: 1500, isActive: false)

        try await service.addStream(active1)
        try await service.addStream(active2)
        try await service.addStream(inactive)

        let count = await service.getActiveStreamsCount()
        #expect(count == 2)
    }

    @Test("Get total monthly projection")
    func testGetTotalMonthlyProjection() async throws {
        let service = IncomeService()

        let stream1 = IncomeStream(name: "Stream 1", type: .active, category: .freelancing, monthlyAmount: 1000, isActive: true)
        let stream2 = IncomeStream(name: "Stream 2", type: .passive, category: .rental, monthlyAmount: 1500, isActive: true)

        try await service.addStream(stream1)
        try await service.addStream(stream2)

        let total = await service.getTotalMonthlyProjection()
        #expect(total == 2500)
    }

    // MARK: - Platform Integration Tests

    @Test("Connect to gig platform")
    func testConnectPlatform() async throws {
        let integration = GigPlatformIntegration()
        let platform = GigPlatform.upwork

        try await integration.connect(platform: platform, apiKey: "test-key")

        let status = try await integration.getStatus(for: platform)
        #expect(status.isConnected)
    }

    @Test("Disconnect from platform")
    func testDisconnectPlatform() async throws {
        let integration = GigPlatformIntegration()
        var platform = GigPlatform.fiverr

        try await integration.connect(platform: platform, apiKey: "test-key")
        try await integration.disconnect(platform: platform)

        let status = try await integration.getStatus(for: platform)
        #expect(!status.isConnected)
    }
}
