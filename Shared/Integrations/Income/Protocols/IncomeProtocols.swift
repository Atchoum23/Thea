import Foundation

// MARK: - Income Service Protocol

/// Protocol for income tracking service
public protocol IncomeServiceProtocol: Actor {
    /// Add new income stream
    func addStream(_ stream: IncomeStream) async throws

    /// Update income stream
    func updateStream(_ stream: IncomeStream) async throws

    /// Fetch all income streams
    func fetchStreams() async throws -> [IncomeStream]

    /// Add income entry
    func addEntry(_ entry: IncomeEntry) async throws

    /// Fetch entries for date range
    func fetchEntries(for dateRange: DateInterval) async throws -> [IncomeEntry]

    /// Generate income report
    func generateReport(for period: DateInterval) async throws -> IncomeReport

    /// Calculate tax estimate
    func calculateTaxEstimate(for year: Int) async throws -> TaxEstimate
}

// MARK: - Gig Platform Integration Protocol

/// Protocol for integrating with gig platforms
public protocol GigPlatformIntegrationProtocol: Actor {
    /// Connect to platform
    func connect(platform: GigPlatform, apiKey: String) async throws

    /// Disconnect from platform
    func disconnect(platform: GigPlatform) async throws

    /// Sync income data from platform
    func syncIncome(from platform: GigPlatform) async throws -> [IncomeEntry]

    /// Get platform status
    func getStatus(for platform: GigPlatform) async throws -> PlatformStatus
}

// MARK: - Supporting Types

public struct PlatformStatus: Sendable, Codable {
    public var isConnected: Bool
    public var lastSyncDate: Date?
    public var totalEarnings: Double
    public var pendingAmount: Double

    public init(
        isConnected: Bool,
        lastSyncDate: Date? = nil,
        totalEarnings: Double = 0,
        pendingAmount: Double = 0
    ) {
        self.isConnected = isConnected
        self.lastSyncDate = lastSyncDate
        self.totalEarnings = totalEarnings
        self.pendingAmount = pendingAmount
    }
}
