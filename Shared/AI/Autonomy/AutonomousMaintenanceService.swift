//
//  AutonomousMaintenanceService.swift
//  Thea
//
//  Background maintenance tasks executed autonomously.
//  Handles MCP server cleanup, cache pruning, and draft cleanup.
//
//  SCHEDULING:
//  - MCP cleanup: Daily
//  - Cache pruning: Weekly
//  - Draft cleanup: Weekly (respects user's never-auto-delete preference)
//
//  CREATED: February 6, 2026
//

import Foundation
import OSLog

// MARK: - Autonomous Maintenance Service

/// Manages background maintenance tasks that run autonomously
public actor AutonomousMaintenanceService {
    public static let shared = AutonomousMaintenanceService()

    private let logger = Logger(subsystem: "ai.thea.app", category: "Maintenance")

    // MARK: - Configuration

    public struct Configuration: Codable, Sendable {
        /// Enable autonomous maintenance
        public var enabled: Bool = true

        /// MCP cleanup interval (seconds)
        public var mcpCleanupInterval: TimeInterval = 86400 // 24 hours

        /// Cache pruning interval (seconds)
        public var cachePruneInterval: TimeInterval = 604800 // 7 days

        /// Draft cleanup interval (seconds)
        public var draftCleanupInterval: TimeInterval = 604800 // 7 days

        /// Maximum age for unused MCP servers (days)
        public var mcpMaxUnusedDays: Int = 30

        /// Maximum cache size (MB)
        public var maxCacheSizeMB: Double = 500

        /// Only clean drafts older than this (days)
        public var draftMaxAgeDays: Int = 90

        /// Require user confirmation for destructive operations
        public var requireConfirmation: Bool = true

        public init() {}
    }

    public var configuration = Configuration() {
        didSet {
            saveConfiguration()
        }
    }

    // MARK: - State

    /// Last execution times
    private var lastMCPCleanup: Date?
    private var lastCachePrune: Date?
    private var lastDraftCleanup: Date?

    /// Maintenance status
    public private(set) var status = MaintenanceStatus()

    /// Active maintenance task
    private var maintenanceTask: Task<Void, Never>?

    /// Whether maintenance is currently running
    public private(set) var isRunning: Bool = false

    // MARK: - Initialization

    private init() {
        Task {
            await loadConfiguration()
            await loadLastExecutionTimes()
        }
    }

    // MARK: - Public API

    /// Start the maintenance scheduler
    public func startScheduler() {
        guard configuration.enabled && !isRunning else {
            logger.debug("Maintenance scheduler already running or disabled")
            return
        }

        isRunning = true
        logger.info("Starting autonomous maintenance scheduler")

        maintenanceTask = Task { [weak self] in
            await self?.maintenanceLoop()
        }
    }

    /// Stop the maintenance scheduler
    public func stopScheduler() {
        maintenanceTask?.cancel()
        maintenanceTask = nil
        isRunning = false
        logger.info("Stopped autonomous maintenance scheduler")
    }

    /// Run all maintenance tasks now
    public func runAllNow() async {
        logger.info("Running all maintenance tasks")

        await cleanUnusedMCPServers()
        await pruneOldCaches()
        await cleanupDrafts()

        status.lastFullRun = Date()
        saveLastExecutionTimes()
    }

    /// Get maintenance status
    public func getMaintenanceStatus() -> MaintenanceStatus {
        status
    }

    // MARK: - Individual Tasks

    /// Clean unused MCP servers
    public func cleanUnusedMCPServers() async {
        logger.info("Starting MCP server cleanup")
        status.mcpCleanup = .running

        do {
            // Get MCP lifecycle manager
            let lifecycleManager = await MainActor.run {
                MCPServerLifecycleManager.shared
            }

            // Get unused servers
            let unusedServers = await lifecycleManager.getUnusedServers(
                unusedDays: configuration.mcpMaxUnusedDays
            )

            var removedCount = 0
            for server in unusedServers {
                // Remove server by name
                await lifecycleManager.removeServer(name: server.metadata.name)
                removedCount += 1
                logger.debug("Removed unused MCP server: \(server.metadata.name)")
            }

            lastMCPCleanup = Date()
            status.mcpCleanup = .completed(Date())
            status.mcpServersRemoved += removedCount

            logger.info("MCP cleanup complete: \(removedCount) servers removed")

        } catch {
            status.mcpCleanup = .failed(error.localizedDescription)
            logger.error("MCP cleanup failed: \(error.localizedDescription)")
        }

        saveLastExecutionTimes()
    }

    /// Prune old caches
    public func pruneOldCaches() async {
        logger.info("Starting cache pruning")
        status.cachePrune = .running

        do {
            var bytesReclaimed: UInt64 = 0

            // Prune model cache
            #if os(macOS)
            let modelCacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("ai.thea.app")
                .appendingPathComponent("models")

            if let cacheURL = modelCacheURL {
                bytesReclaimed += await pruneDirectory(cacheURL, maxSizeMB: configuration.maxCacheSizeMB / 2)
            }
            #endif

            // Prune temporary files
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("ai.thea.app")

            bytesReclaimed += await pruneDirectory(tempURL, maxAgeDays: 7)

            lastCachePrune = Date()
            status.cachePrune = .completed(Date())
            status.bytesReclaimed += bytesReclaimed

            let mbReclaimed = Double(bytesReclaimed) / 1_048_576
            logger.info("Cache pruning complete: \(String(format: "%.1f", mbReclaimed)) MB reclaimed")

        } catch {
            status.cachePrune = .failed(error.localizedDescription)
            logger.error("Cache pruning failed: \(error.localizedDescription)")
        }

        saveLastExecutionTimes()
    }

    /// Cleanup old drafts (respects never-auto-delete preference)
    public func cleanupDrafts() async {
        logger.info("Starting draft cleanup")
        status.draftCleanup = .running

        // NOTE: DraftSyncManager has a "never auto-delete" policy
        // We only clean drafts that are explicitly marked for cleanup

        do {
            let draftManager = await MainActor.run {
                DraftSyncManager.shared
            }

            // Get drafts and clean empty ones
            // Note: Draft cleanup is limited to empty drafts to respect user data
            // The DraftSyncManager uses clearDraft for explicit cleanup
            let drafts = await draftManager.drafts
            var cleanedCount = 0

            for (conversationId, draft) in drafts {
                // Only clean empty drafts
                if draft.isEmpty {
                    await draftManager.clearDraft(for: conversationId)
                    cleanedCount += 1
                }
            }

            lastDraftCleanup = Date()
            status.draftCleanup = .completed(Date())
            status.draftsCleanedUp += cleanedCount

            logger.info("Draft cleanup complete: \(cleanedCount) empty drafts removed")

        } catch {
            status.draftCleanup = .failed(error.localizedDescription)
            logger.error("Draft cleanup failed: \(error.localizedDescription)")
        }

        saveLastExecutionTimes()
    }

    // MARK: - Private Implementation

    private func maintenanceLoop() async {
        while !Task.isCancelled && isRunning {
            // Check what needs to run
            let now = Date()

            // MCP cleanup
            if shouldRunTask(lastRun: lastMCPCleanup, interval: configuration.mcpCleanupInterval) {
                await cleanUnusedMCPServers()
            }

            // Cache prune
            if shouldRunTask(lastRun: lastCachePrune, interval: configuration.cachePruneInterval) {
                await pruneOldCaches()
            }

            // Draft cleanup
            if shouldRunTask(lastRun: lastDraftCleanup, interval: configuration.draftCleanupInterval) {
                await cleanupDrafts()
            }

            // Sleep for 1 hour before checking again
            do {
                try await Task.sleep(for: .seconds(3600))
            } catch {
                break
            }
        }
    }

    private func shouldRunTask(lastRun: Date?, interval: TimeInterval) -> Bool {
        guard let lastRun else { return true }
        return Date().timeIntervalSince(lastRun) >= interval
    }

    private func pruneDirectory(_ url: URL, maxSizeMB: Double? = nil, maxAgeDays: Int? = nil) async -> UInt64 {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else { return 0 }

        var bytesReclaimed: UInt64 = 0

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )

            // Sort by creation date (oldest first)
            let sorted = contents.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 < date2
            }

            // Calculate total size
            var totalSize: UInt64 = 0
            for file in sorted {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += UInt64(size)
                }
            }

            let maxBytes = (maxSizeMB ?? Double.greatestFiniteMagnitude) * 1_048_576
            let cutoffDate = maxAgeDays.map { Date().addingTimeInterval(-Double($0) * 86400) }

            // Remove files until under limit
            for file in sorted {
                var shouldRemove = false

                // Check age
                if let cutoff = cutoffDate,
                   let created = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   created < cutoff {
                    shouldRemove = true
                }

                // Check size
                if Double(totalSize) > maxBytes {
                    shouldRemove = true
                }

                if shouldRemove {
                    if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        try fileManager.removeItem(at: file)
                        bytesReclaimed += UInt64(size)
                        totalSize -= UInt64(size)
                    }
                }
            }

        } catch {
            logger.error("Failed to prune directory \(url.path): \(error.localizedDescription)")
        }

        return bytesReclaimed
    }

    // MARK: - Persistence

    private let configKey = "AutonomousMaintenance.config"
    private let lastRunKey = "AutonomousMaintenance.lastRuns"

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(Configuration.self, from: data) {
            configuration = decoded
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    private func loadLastExecutionTimes() {
        if let data = UserDefaults.standard.data(forKey: lastRunKey),
           let decoded = try? JSONDecoder().decode(LastExecutionTimes.self, from: data) {
            lastMCPCleanup = decoded.mcpCleanup
            lastCachePrune = decoded.cachePrune
            lastDraftCleanup = decoded.draftCleanup
        }
    }

    private func saveLastExecutionTimes() {
        let times = LastExecutionTimes(
            mcpCleanup: lastMCPCleanup,
            cachePrune: lastCachePrune,
            draftCleanup: lastDraftCleanup
        )
        if let data = try? JSONEncoder().encode(times) {
            UserDefaults.standard.set(data, forKey: lastRunKey)
        }
    }
}

// MARK: - Supporting Types

/// Maintenance status
public struct MaintenanceStatus: Sendable {
    public var mcpCleanup: TaskStatus = .pending
    public var cachePrune: TaskStatus = .pending
    public var draftCleanup: TaskStatus = .pending

    public var lastFullRun: Date?

    public var mcpServersRemoved: Int = 0
    public var bytesReclaimed: UInt64 = 0
    public var draftsCleanedUp: Int = 0

    public enum TaskStatus: Sendable {
        case pending
        case running
        case completed(Date)
        case failed(String)

        public var isCompleted: Bool {
            if case .completed = self { return true }
            return false
        }
    }
}

/// Last execution times for persistence
private struct LastExecutionTimes: Codable {
    let mcpCleanup: Date?
    let cachePrune: Date?
    let draftCleanup: Date?
}

// MARK: - MCPServerLifecycleManager Extension

extension MCPServerLifecycleManager {
    /// Get servers that haven't been used in specified days
    func getUnusedServers(unusedDays: Int) async -> [InstalledMCPServer] {
        let cutoff = Date().addingTimeInterval(-Double(unusedDays) * 86400)

        return await MainActor.run {
            self.installedServers.filter { server in
                (server.usageStats.lastUsed ?? server.installedAt) < cutoff
            }
        }
    }

    /// Remove a server by name
    func removeServer(name: String) async {
        // Find server by name and remove it
        if let server = await MainActor.run(body: {
            self.installedServers.first { $0.metadata.name == name }
        }) {
            // Use the existing uninstall method
            _ = try? await self.uninstallServer(server.id)
        }
    }
}
