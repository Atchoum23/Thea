// ActivityTracker.swift
// Thea V2
//
// Activity tracking and synchronization system inspired by:
// - Trakt: Watch history, ratings, lists, sync
// - General usage patterns for AI assistants

import Foundation
import OSLog

// MARK: - Activity Tracker

/// Tracks user activity and interactions with Thea
@MainActor
public final class ActivityTracker: ObservableObject {
    public static let shared = ActivityTracker()

    private let logger = Logger(subsystem: "com.thea.v2", category: "ActivityTracker")

    @Published public private(set) var sessions: [ActivitySession] = []
    @Published public private(set) var interactions: [Interaction] = []
    @Published public private(set) var favorites: [FavoriteItem] = []
    @Published public private(set) var usageStatistics = UsageStatistics()
    @Published public private(set) var syncStatus: ActivitySyncStatus = .idle

    private var currentSession: ActivitySession?

    private var storagePath: URL {
        #if os(macOS)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".thea/activity")
        #else
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea/activity")
        #endif
    }

    private init() {
        Task {
            await loadData()
        }
    }

    // MARK: - Session Management

    /// Start a new activity session
    public func startSession(context: String? = nil) -> ActivitySession {
        let session = ActivitySession(
            id: UUID(),
            startTime: Date(),
            context: context
        )
        currentSession = session
        sessions.append(session)

        logger.info("Started session: \(session.id)")
        return session
    }

    /// End the current session
    public func endSession() {
        guard var session = currentSession else { return }

        session.endTime = Date()
        session.duration = session.endTime?.timeIntervalSince(session.startTime)

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }

        currentSession = nil
        logger.info("Ended session: \(session.id)")

        Task {
            await saveData()
        }
    }

    // MARK: - Interaction Tracking

    /// Record an interaction
    public func recordInteraction(_ interaction: Interaction) {
        interactions.append(interaction)

        // Update current session
        if currentSession != nil {
            currentSession?.interactionCount += 1
        }

        // Update statistics
        updateStatistics(for: interaction)

        // Trim old interactions (keep last 1000)
        if interactions.count > 1000 {
            interactions = Array(interactions.suffix(1000))
        }

        logger.debug("Recorded interaction: \(interaction.type.rawValue)")
    }

    /// Record a query
    public func recordQuery(
        query: String,
        taskType: TaskType,
        model: String,
        tokensUsed: Int,
        responseTime: TimeInterval
    ) {
        let interaction = Interaction(
            id: UUID(),
            timestamp: Date(),
            type: .query,
            details: InteractionDetails(
                query: query,
                taskType: taskType.rawValue,
                model: model,
                tokensUsed: tokensUsed,
                responseTimeMs: Int(responseTime * 1000)
            )
        )
        recordInteraction(interaction)
    }

    /// Record a tool use
    public func recordToolUse(
        toolName: String,
        input: String,
        output: String,
        success: Bool
    ) {
        let interaction = Interaction(
            id: UUID(),
            timestamp: Date(),
            type: .toolUse,
            details: InteractionDetails(
                toolName: toolName,
                input: input,
                output: output,
                success: success
            )
        )
        recordInteraction(interaction)
    }

    // MARK: - Favorites

    /// Add to favorites
    public func addFavorite(_ item: FavoriteItem) {
        guard !favorites.contains(where: { $0.id == item.id }) else { return }
        favorites.append(item)

        Task {
            await saveData()
        }
    }

    /// Remove from favorites
    public func removeFavorite(_ item: FavoriteItem) {
        favorites.removeAll { $0.id == item.id }

        Task {
            await saveData()
        }
    }

    /// Check if item is favorited
    public func isFavorite(_ itemId: UUID) -> Bool {
        favorites.contains { $0.id == itemId }
    }

    // MARK: - Statistics

    private func updateStatistics(for interaction: Interaction) {
        usageStatistics.totalInteractions += 1

        switch interaction.type {
        case .query:
            usageStatistics.totalQueries += 1
            if let tokens = interaction.details.tokensUsed {
                usageStatistics.totalTokensUsed += tokens
            }
        case .toolUse:
            usageStatistics.totalToolUses += 1
        case .feedback:
            if interaction.details.rating != nil {
                usageStatistics.totalRatings += 1
            }
        default:
            break
        }

        // Update daily statistics
        let today = Calendar.current.startOfDay(for: Date())
        if usageStatistics.dailyStats[today] == nil {
            usageStatistics.dailyStats[today] = DailyStats()
        }
        usageStatistics.dailyStats[today]?.interactions += 1
    }

    /// Get statistics for a date range
    public func getStatistics(from startDate: Date, to endDate: Date) -> [Date: DailyStats] {
        usageStatistics.dailyStats.filter { date, _ in
            date >= startDate && date <= endDate
        }
    }

    // MARK: - Sync

    /// Sync activity to cloud (placeholder for future implementation)
    public func sync() async throws {
        syncStatus = .syncing

        // Simulate sync delay
        try await Task.sleep(nanoseconds: 1_000_000_000)

        syncStatus = .synced(lastSync: Date())
        logger.info("Activity synced")
    }

    // MARK: - Persistence

    private func loadData() async {
        guard FileManager.default.fileExists(atPath: storagePath.path) else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Load sessions
            let sessionsPath = storagePath.appendingPathComponent("sessions.json")
            if FileManager.default.fileExists(atPath: sessionsPath.path) {
                let data = try Data(contentsOf: sessionsPath)
                sessions = try decoder.decode([ActivitySession].self, from: data)
            }

            // Load favorites
            let favoritesPath = storagePath.appendingPathComponent("favorites.json")
            if FileManager.default.fileExists(atPath: favoritesPath.path) {
                let data = try Data(contentsOf: favoritesPath)
                favorites = try decoder.decode([FavoriteItem].self, from: data)
            }

            // Load statistics
            let statsPath = storagePath.appendingPathComponent("statistics.json")
            if FileManager.default.fileExists(atPath: statsPath.path) {
                let data = try Data(contentsOf: statsPath)
                usageStatistics = try decoder.decode(UsageStatistics.self, from: data)
            }

            logger.info("Loaded activity data")
        } catch {
            logger.error("Failed to load activity data: \(error.localizedDescription)")
        }
    }

    private func saveData() async {
        do {
            if !FileManager.default.fileExists(atPath: storagePath.path) {
                try FileManager.default.createDirectory(at: storagePath, withIntermediateDirectories: true)
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            // Save sessions
            let sessionsData = try encoder.encode(sessions)
            try sessionsData.write(to: storagePath.appendingPathComponent("sessions.json"))

            // Save favorites
            let favoritesData = try encoder.encode(favorites)
            try favoritesData.write(to: storagePath.appendingPathComponent("favorites.json"))

            // Save statistics
            let statsData = try encoder.encode(usageStatistics)
            try statsData.write(to: storagePath.appendingPathComponent("statistics.json"))

            logger.info("Saved activity data")
        } catch {
            logger.error("Failed to save activity data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Activity Session

/// A user session with Thea
public struct ActivitySession: Identifiable, Codable, Sendable {
    public let id: UUID
    public let startTime: Date
    public var endTime: Date?
    public var duration: TimeInterval?
    public var context: String?
    public var interactionCount: Int = 0

    public init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        duration: TimeInterval? = nil,
        context: String? = nil,
        interactionCount: Int = 0
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.context = context
        self.interactionCount = interactionCount
    }
}

// MARK: - Interaction

/// A single interaction with Thea
public struct Interaction: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: InteractionType
    public var details: InteractionDetails

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: InteractionType,
        details: InteractionDetails = InteractionDetails()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.details = details
    }
}

public enum InteractionType: String, Codable, Sendable {
    case query          // User asked a question
    case toolUse        // Agent used a tool
    case feedback       // User provided feedback
    case navigation     // User navigated UI
    case setting        // User changed a setting
    case error          // An error occurred
}

/// Flexible details container for different interaction types
public struct InteractionDetails: Codable, Sendable {
    // Query details
    public var query: String?
    public var taskType: String?
    public var model: String?
    public var tokensUsed: Int?
    public var responseTimeMs: Int?

    // Tool use details
    public var toolName: String?
    public var input: String?
    public var output: String?
    public var success: Bool?

    // Feedback details
    public var rating: Int?  // 1-5
    public var comment: String?

    // Error details
    public var errorCode: String?
    public var errorMessage: String?

    public init(
        query: String? = nil,
        taskType: String? = nil,
        model: String? = nil,
        tokensUsed: Int? = nil,
        responseTimeMs: Int? = nil,
        toolName: String? = nil,
        input: String? = nil,
        output: String? = nil,
        success: Bool? = nil,
        rating: Int? = nil,
        comment: String? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil
    ) {
        self.query = query
        self.taskType = taskType
        self.model = model
        self.tokensUsed = tokensUsed
        self.responseTimeMs = responseTimeMs
        self.toolName = toolName
        self.input = input
        self.output = output
        self.success = success
        self.rating = rating
        self.comment = comment
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

// MARK: - Favorite Item

/// A favorited item (prompt, response, conversation)
public struct FavoriteItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public var type: FavoriteType
    public var title: String
    public var content: String
    public var tags: [String]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        type: FavoriteType,
        title: String,
        content: String,
        tags: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.tags = tags
        self.createdAt = createdAt
    }
}

public enum FavoriteType: String, Codable, Sendable {
    case prompt
    case response
    case conversation
    case snippet
}

// MARK: - Usage Statistics

/// Aggregated usage statistics
public struct UsageStatistics: Codable, Sendable {
    public var totalInteractions: Int = 0
    public var totalQueries: Int = 0
    public var totalToolUses: Int = 0
    public var totalTokensUsed: Int = 0
    public var totalRatings: Int = 0
    public var dailyStats: [Date: DailyStats] = [:]

    public init() {}
}

/// Daily statistics breakdown
public struct DailyStats: Codable, Sendable {
    public var interactions: Int = 0
    public var queries: Int = 0
    public var tokensUsed: Int = 0

    public init() {}
}

// MARK: - Activity Sync Status

/// Sync status for activity tracking (prefixed to avoid conflict with CrossDeviceService.SyncStatus)
public enum ActivitySyncStatus: Sendable {
    case idle
    case syncing
    case synced(lastSync: Date)
    case error(String)
}
