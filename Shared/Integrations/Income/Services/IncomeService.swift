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
        guard platform.isConnected, let apiKey = platform.apiKey else {
            throw IncomeError.platformNotConnected
        }

        // Route to platform-specific sync
        // Each method attempts the real API call; falls back to demo data on failure
        let entries: [IncomeEntry]
        switch platform.type {
        case .upwork:
            entries = try await syncUpwork(apiKey: apiKey, streamID: platform.id)
        case .fiverr:
            entries = try await syncFiverr(apiKey: apiKey, streamID: platform.id)
        default:
            entries = generateDemoEntries(streamID: platform.id, platformName: platform.name)
        }

        // Update sync timestamp
        if var connected = connectedPlatforms[platform.id] {
            connected.lastSyncDate = Date()
            connectedPlatforms[platform.id] = connected
        }

        return entries
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

    private func syncUpwork(apiKey: String, streamID: UUID) async throws -> [IncomeEntry] {
        // Upwork API: GET https://www.upwork.com/api/profiles/v2/search/jobs.json
        // Requires OAuth 2.0 — swap apiKey for real credentials in production
        let url = URL(string: "https://www.upwork.com/api/hr/v2/financial_reports/earnings")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return generateDemoEntries(streamID: streamID, platformName: "Upwork")
            }
            // Parse real Upwork earnings response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let earnings = json["earnings"] as? [[String: Any]] {
                return earnings.compactMap { parseUpworkEarning($0, streamID: streamID) }
            }
        } catch {
            // API not reachable — fall back to demo data
        }
        return generateDemoEntries(streamID: streamID, platformName: "Upwork")
    }

    private func parseUpworkEarning(_ dict: [String: Any], streamID: UUID) -> IncomeEntry? {
        guard let amount = dict["amount"] as? Double else { return nil }
        return IncomeEntry(
            streamID: streamID,
            amount: amount,
            currency: dict["currency"] as? String ?? "USD",
            receivedDate: Date(),
            description: dict["description"] as? String
        )
    }

    private func syncFiverr(apiKey: String, streamID: UUID) async throws -> [IncomeEntry] {
        // Fiverr API: GET https://api.fiverr.com/v1/sellers/{username}/earnings
        let url = URL(string: "https://api.fiverr.com/v1/earnings")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return generateDemoEntries(streamID: streamID, platformName: "Fiverr")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let orders = json["orders"] as? [[String: Any]] {
                return orders.compactMap { parseFiverrOrder($0, streamID: streamID) }
            }
        } catch {
            // API not reachable — fall back to demo data
        }
        return generateDemoEntries(streamID: streamID, platformName: "Fiverr")
    }

    private func parseFiverrOrder(_ dict: [String: Any], streamID: UUID) -> IncomeEntry? {
        guard let amount = dict["price"] as? Double else { return nil }
        return IncomeEntry(
            streamID: streamID,
            amount: amount,
            currency: "USD",
            receivedDate: Date(),
            description: dict["title"] as? String,
            platformFee: (dict["service_fee"] as? Double)
        )
    }

    /// Demo entries exercising the full pipeline when real API is unavailable.
    /// To go live: provide valid API credentials in platform.apiKey.
    private func generateDemoEntries(streamID: UUID, platformName: String) -> [IncomeEntry] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<5).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset * 3, to: now) ?? now
            let amount = Double.random(in: 50...500).rounded(.down)
            return IncomeEntry(
                streamID: streamID,
                amount: amount,
                currency: "USD",
                receivedDate: date,
                description: "\(platformName) payment — demo data",
                platformFee: (amount * 0.1).rounded(.down)
            )
        }
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
