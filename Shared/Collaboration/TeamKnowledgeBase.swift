//
//  TeamKnowledgeBase.swift
//  Thea
//
//  Shared memory and knowledge across team members via CloudKit.
//  Enables collaborative AI with shared context and learnings.
//
//  FEATURES:
//  - Share memories with team members
//  - Sync team knowledge via CloudKit public database
//  - Conflict resolution for concurrent edits
//  - Access control and privacy settings
//
//  CREATED: February 6, 2026
//

import Foundation
import OSLog
import CloudKit

// MARK: - Team Knowledge Base

/// Manages shared knowledge across team members
public actor TeamKnowledgeBase {
    public static let shared = TeamKnowledgeBase()

    private let logger = Logger(subsystem: "ai.thea.app", category: "TeamKnowledge")

    // MARK: - CloudKit Configuration

    private let containerIdentifier = "iCloud.app.theathe"
    private let recordType = "SharedKnowledge"

    private var container: CKContainer {
        CKContainer(identifier: containerIdentifier)
    }

    private var publicDatabase: CKDatabase {
        container.publicCloudDatabase
    }

    // MARK: - State

    /// Cached team knowledge
    private var teamKnowledge: [String: [SharedKnowledgeItem]] = [:]

    /// Last sync time per team
    private var lastSyncTime: [String: Date] = [:]

    /// Local pending changes
    private var pendingChanges: [SharedKnowledgeItem] = []

    // MARK: - Configuration

    public var configuration = Configuration()

    public struct Configuration: Sendable {
        /// Auto-sync interval (seconds)
        public var syncInterval: TimeInterval = 300 // 5 minutes

        /// Maximum items per team
        public var maxItemsPerTeam: Int = 1000

        /// Default visibility for shared items
        public var defaultVisibility: ItemVisibility = .teamOnly

        /// Enable conflict resolution
        public var enableConflictResolution: Bool = true

        public init() {}
    }

    // MARK: - Initialization

    private init() {
        Task {
            await loadLocalCache()
        }
    }

    // MARK: - Public API

    /// Share a memory with a team
    public func shareMemory(_ memory: SharedTheaMemory, toTeam teamId: String) async throws {
        logger.info("Sharing memory to team: \(teamId)")

        let item = SharedKnowledgeItem(
            id: UUID(),
            teamId: teamId,
            content: memory.content,
            category: memory.category,
            keywords: memory.keywords,
            sharedBy: getCurrentUserId(),
            sharedAt: Date(),
            visibility: configuration.defaultVisibility,
            version: 1
        )

        // Save to CloudKit
        try await saveToCloudKit(item)

        // Update local cache
        teamKnowledge[teamId, default: []].append(item)

        // Persist locally
        await saveLocalCache()

        logger.info("Memory shared successfully")
    }

    /// Fetch team knowledge
    public func fetchTeamKnowledge(teamId: String) async throws -> [SharedKnowledgeItem] {
        logger.info("Fetching knowledge for team: \(teamId)")

        // Check if we need to sync
        let shouldSync = shouldSyncTeam(teamId)

        if shouldSync {
            try await syncTeamKnowledge(teamId: teamId)
        }

        return teamKnowledge[teamId] ?? []
    }

    /// Sync team knowledge with CloudKit
    public func syncTeamKnowledge(teamId: String? = nil) async throws {
        let teams = teamId.map { [$0] } ?? Array(teamKnowledge.keys)

        for team in teams {
            try await syncTeam(team)
        }
    }

    /// Search team knowledge
    public func searchTeamKnowledge(teamId: String, query: String) async -> [SharedKnowledgeItem] {
        let items = teamKnowledge[teamId] ?? []

        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))

        return items.filter { item in
            // Check content
            let contentWords = Set(item.content.lowercased().split(separator: " ").map(String.init))
            if !queryWords.isDisjoint(with: contentWords) {
                return true
            }

            // Check keywords
            let keywordMatch = item.keywords.contains { keyword in
                queryWords.contains(keyword.lowercased())
            }

            return keywordMatch
        }
    }

    /// Update a shared knowledge item
    public func updateItem(_ item: SharedKnowledgeItem, content: String) async throws {
        var updatedItem = item
        updatedItem.content = content
        updatedItem.version += 1
        updatedItem.lastModified = Date()

        try await saveToCloudKit(updatedItem)

        // Update local cache
        if var teamItems = teamKnowledge[item.teamId] {
            if let index = teamItems.firstIndex(where: { $0.id == item.id }) {
                teamItems[index] = updatedItem
                teamKnowledge[item.teamId] = teamItems
            }
        }

        await saveLocalCache()
    }

    /// Delete a shared knowledge item
    public func deleteItem(_ item: SharedKnowledgeItem) async throws {
        // Only the creator can delete
        guard item.sharedBy == getCurrentUserId() else {
            throw TeamKnowledgeError.notAuthorized
        }

        try await deleteFromCloudKit(item)

        // Remove from local cache
        teamKnowledge[item.teamId]?.removeAll { $0.id == item.id }

        await saveLocalCache()
    }

    /// Get teams the user belongs to
    public func getUserTeams() async -> [String] {
        // This would integrate with team management
        // For now, return known teams from cache
        Array(teamKnowledge.keys)
    }

    // MARK: - Private CloudKit Operations

    private func saveToCloudKit(_ item: SharedKnowledgeItem) async throws {
        let record = CKRecord(recordType: recordType)
        record["id"] = item.id.uuidString
        record["teamId"] = item.teamId
        record["content"] = item.content
        record["category"] = item.category
        record["keywords"] = item.keywords
        record["sharedBy"] = item.sharedBy
        record["sharedAt"] = item.sharedAt
        record["visibility"] = item.visibility.rawValue
        record["version"] = item.version

        _ = try await publicDatabase.save(record)
    }

    private func deleteFromCloudKit(_ item: SharedKnowledgeItem) async throws {
        let recordID = CKRecord.ID(recordName: item.id.uuidString)
        try await publicDatabase.deleteRecord(withID: recordID)
    }

    private func syncTeam(_ teamId: String) async throws {
        let predicate = NSPredicate(format: "teamId == %@", teamId)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "sharedAt", ascending: false)]

        let results = try await publicDatabase.records(matching: query)

        var items: [SharedKnowledgeItem] = []

        for result in results.matchResults {
            if let record = try? result.1.get() {
                if let item = SharedKnowledgeItem(from: record) {
                    items.append(item)
                }
            }
        }

        // Handle conflicts if enabled
        if configuration.enableConflictResolution {
            items = resolveConflicts(remote: items, local: teamKnowledge[teamId] ?? [])
        }

        teamKnowledge[teamId] = items
        lastSyncTime[teamId] = Date()

        await saveLocalCache()
        logger.info("Synced \(items.count) items for team \(teamId)")
    }

    private func shouldSyncTeam(_ teamId: String) -> Bool {
        guard let lastSync = lastSyncTime[teamId] else { return true }
        return Date().timeIntervalSince(lastSync) > configuration.syncInterval
    }

    private func resolveConflicts(remote: [SharedKnowledgeItem], local: [SharedKnowledgeItem]) -> [SharedKnowledgeItem] {
        var merged: [UUID: SharedKnowledgeItem] = [:]

        // Add all remote items
        for item in remote {
            merged[item.id] = item
        }

        // Check local items for conflicts
        for item in local {
            if let existing = merged[item.id] {
                // Keep the one with higher version or more recent modification
                if item.version > existing.version ||
                    (item.version == existing.version && (item.lastModified ?? item.sharedAt) > (existing.lastModified ?? existing.sharedAt)) {
                    merged[item.id] = item
                }
            } else {
                // Local-only item, might be pending sync
                merged[item.id] = item
            }
        }

        return Array(merged.values).sorted { $0.sharedAt > $1.sharedAt }
    }

    private func getCurrentUserId() -> String {
        // This would use actual user authentication
        // For now, use device identifier
        #if os(macOS)
        return ProcessInfo.processInfo.hostName
        #else
        nonisolated(unsafe) let vendorId = UIDevice.current.identifierForVendor
        return vendorId?.uuidString ?? "unknown"
        #endif
    }

    // MARK: - Local Cache

    private let cacheKey = "TeamKnowledgeBase.cache"

    private func loadLocalCache() async {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode(TeamKnowledgeCache.self, from: data) {
            teamKnowledge = decoded.knowledge
            lastSyncTime = decoded.syncTimes
        }
    }

    private func saveLocalCache() async {
        let cache = TeamKnowledgeCache(knowledge: teamKnowledge, syncTimes: lastSyncTime)
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}

// MARK: - Supporting Types

/// A shared knowledge item
public struct SharedKnowledgeItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public let teamId: String
    public var content: String
    public var category: String
    public var keywords: [String]
    public let sharedBy: String
    public let sharedAt: Date
    public var lastModified: Date?
    public var visibility: ItemVisibility
    public var version: Int

    public init(
        id: UUID = UUID(),
        teamId: String,
        content: String,
        category: String,
        keywords: [String] = [],
        sharedBy: String,
        sharedAt: Date = Date(),
        visibility: ItemVisibility = .teamOnly,
        version: Int = 1
    ) {
        self.id = id
        self.teamId = teamId
        self.content = content
        self.category = category
        self.keywords = keywords
        self.sharedBy = sharedBy
        self.sharedAt = sharedAt
        self.visibility = visibility
        self.version = version
    }

    init?(from record: CKRecord) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let teamId = record["teamId"] as? String,
              let content = record["content"] as? String,
              let sharedBy = record["sharedBy"] as? String,
              let sharedAt = record["sharedAt"] as? Date else {
            return nil
        }

        self.id = id
        self.teamId = teamId
        self.content = content
        self.category = record["category"] as? String ?? "general"
        self.keywords = record["keywords"] as? [String] ?? []
        self.sharedBy = sharedBy
        self.sharedAt = sharedAt
        self.visibility = ItemVisibility(rawValue: record["visibility"] as? String ?? "team") ?? .teamOnly
        self.version = record["version"] as? Int ?? 1
    }
}

/// Visibility level for shared items
public enum ItemVisibility: String, Codable, Sendable {
    case `private` = "private"
    case teamOnly = "team"
    case `public` = "public"
}

/// Reference to a memory for sharing
public struct SharedTheaMemory: Sendable {
    public let id: UUID
    public let content: String
    public let category: String
    public let keywords: [String]

    public init(id: UUID = UUID(), content: String, category: String, keywords: [String] = []) {
        self.id = id
        self.content = content
        self.category = category
        self.keywords = keywords
    }
}

/// Cache structure for persistence
private struct TeamKnowledgeCache: Codable {
    let knowledge: [String: [SharedKnowledgeItem]]
    let syncTimes: [String: Date]
}

/// Team knowledge errors
public enum TeamKnowledgeError: LocalizedError {
    case notAuthorized
    case syncFailed(String)
    case itemNotFound

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "You don't have permission to perform this action"
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        case .itemNotFound:
            return "Knowledge item not found"
        }
    }
}

#if os(iOS)
import UIKit
#endif
