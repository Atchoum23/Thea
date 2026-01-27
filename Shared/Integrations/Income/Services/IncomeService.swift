import Foundation

// MARK: - Income Service

/// Service for tracking income streams
public actor IncomeService: IncomeServiceProtocol {
    // MARK: - Properties

    private var streams: [UUID: IncomeStream] = [:]
    private var entries: [UUID: IncomeEntry] = [:]
    private let gigIntegration: GigPlatformIntegration

    // MARK: - Initialization

    public init(gigIntegration: GigPlatformIntegration = GigPlatformIntegration()) {
        self.gigIntegration = gigIntegration
    }

    // MARK: - Stream Management

    public func addStream(_ stream: IncomeStream) async throws {
        streams[stream.id] = stream
    }

    public func updateStream(_ stream: IncomeStream) async throws {
        guard streams[stream.id] != nil else {
            throw IncomeError.streamNotFound
        }
        streams[stream.id] = stream
    }

    public func fetchStreams() async throws -> [IncomeStream] {
        Array(streams.values).sorted { $0.monthlyAmount > $1.monthlyAmount }
    }

    public func deleteStream(id: UUID) async throws {
        streams.removeValue(forKey: id)
    }

    // MARK: - Entry Management

    public func addEntry(_ entry: IncomeEntry) async throws {
        guard entry.amount > 0 else {
            throw IncomeError.invalidAmount
        }

        entries[entry.id] = entry
    }

    public func fetchEntries(for dateRange: DateInterval) async throws -> [IncomeEntry] {
        entries.values.filter { entry in
            dateRange.contains(entry.receivedDate)
        }.sorted { $0.receivedDate > $1.receivedDate }
    }

    // MARK: - Reporting

    public func generateReport(for period: DateInterval) async throws -> IncomeReport {
        let periodEntries = try await fetchEntries(for: period)

        var totalIncome = 0.0
        var streamBreakdown: [UUID: Double] = [:]
        var categoryBreakdown: [IncomeCategory: Double] = [:]
        var typeBreakdown: [IncomeType: Double] = [:]

        for entry in periodEntries {
            totalIncome += entry.netAmount

            // Stream breakdown
            streamBreakdown[entry.streamID, default: 0] += entry.netAmount

            // Category and type breakdown
            if let stream = streams[entry.streamID] {
                categoryBreakdown[stream.category, default: 0] += entry.netAmount
                typeBreakdown[stream.type, default: 0] += entry.netAmount
            }
        }

        // Find top stream
        let topStreamID = streamBreakdown.max { $0.value < $1.value }?.key
        let topStream = topStreamID.flatMap { streams[$0] }

        // Calculate average monthly
        let monthCount = max(1, Calendar.current.dateComponents([.month], from: period.start, to: period.end).month ?? 1)
        let averageMonthly = totalIncome / Double(monthCount)

        // Active streams count
        let activeStreams = streams.values.count { $0.isActive }

        return IncomeReport(
            period: period,
            totalIncome: totalIncome,
            activeStreams: activeStreams,
            topStream: topStream,
            streamBreakdown: streamBreakdown,
            categoryBreakdown: categoryBreakdown,
            typeBreakdown: typeBreakdown,
            averageMonthlyIncome: averageMonthly
        )
    }

    // MARK: - Tax Estimation

    public func calculateTaxEstimate(for year: Int) async throws -> TaxEstimate {
        guard let yearStart = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = Calendar.current.date(from: DateComponents(year: year, month: 12, day: 31))
        else {
            return TaxEstimate.calculate(grossIncome: 0, year: year)
        }
        let yearRange = DateInterval(start: yearStart, end: yearEnd)

        let yearEntries = try await fetchEntries(for: yearRange)
        let grossIncome = yearEntries.reduce(0.0) { $0 + $1.netAmount }

        return TaxEstimate.calculate(grossIncome: grossIncome, year: year)
    }

    // MARK: - Analytics

    public func getActiveStreamsCount() async -> Int {
        streams.values.count { $0.isActive }
    }

    public func getTotalMonthlyProjection() async -> Double {
        streams.values.filter(\.isActive).reduce(0.0) { $0 + $1.monthlyAmount }
    }

    public func getTopCategory() async -> IncomeCategory? {
        let categoryAmounts = streams.values.reduce(into: [IncomeCategory: Double]()) { result, stream in
            result[stream.category, default: 0] += stream.monthlyAmount
        }

        return categoryAmounts.max { $0.value < $1.value }?.key
    }
}

// MARK: - Gig Platform Integration

/// Service for integrating with gig platforms
public actor GigPlatformIntegration: GigPlatformIntegrationProtocol {
    // MARK: - Properties

    private var connectedPlatforms: [UUID: GigPlatform] = [:]

    // MARK: - Connection Management

    public init() {}

    public func connect(platform: GigPlatform, apiKey: String) async throws {
        var updatedPlatform = platform
        updatedPlatform.apiKey = apiKey
        updatedPlatform.isConnected = true
        updatedPlatform.lastSyncDate = Date()

        connectedPlatforms[platform.id] = updatedPlatform
    }

    public func disconnect(platform: GigPlatform) async throws {
        var updatedPlatform = platform
        updatedPlatform.isConnected = false
        updatedPlatform.apiKey = nil

        connectedPlatforms[platform.id] = updatedPlatform
    }

    // MARK: - Data Sync

    public func syncIncome(from platform: GigPlatform) async throws -> [IncomeEntry] {
        guard platform.isConnected, platform.apiKey != nil else {
            throw IncomeError.platformNotConnected
        }

        // In production, would make API calls to platform
        // For now, return mock data
        return []
    }

    public func getStatus(for platform: GigPlatform) async throws -> PlatformStatus {
        guard let connected = connectedPlatforms[platform.id] else {
            return PlatformStatus(isConnected: false)
        }

        return PlatformStatus(
            isConnected: connected.isConnected,
            lastSyncDate: connected.lastSyncDate,
            totalEarnings: 0,
            pendingAmount: 0
        )
    }

    // MARK: - Platform-Specific Sync

    private func syncUpwork(apiKey _: String) async throws -> [IncomeEntry] {
        // Would call Upwork API
        // GET /api/profiles/v2/search/jobs.json
        []
    }

    private func syncFiverr(apiKey _: String) async throws -> [IncomeEntry] {
        // Would call Fiverr API
        // GET /sellers/{username}/gigs
        []
    }

    private func syncUber(apiKey _: String) async throws -> [IncomeEntry] {
        // Would call Uber Driver API
        // GET /v1/partners/trips
        []
    }

    private func syncDoorDash(apiKey _: String) async throws -> [IncomeEntry] {
        // Would call DoorDash API
        // GET /drive/v2/deliveries
        []
    }
}
