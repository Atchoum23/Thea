//
//  AppUpdateService.swift
//  Thea
//
//  Manages app update notifications across devices via CloudKit.
//  When one Mac builds a new version, it posts a record to CloudKit.
//  Other devices receive a push notification with an "Update Now" button.
//

import CloudKit
import Combine
import Foundation
import OSLog
@preconcurrency import UserNotifications

#if canImport(AppKit)
    import AppKit
#endif

// MARK: - App Update Service

@MainActor
public final class AppUpdateService: ObservableObject {
    public static let shared = AppUpdateService()

    private let logger = Logger(subsystem: "app.thea", category: "AppUpdate")
    private let containerIdentifier = "iCloud.app.theathe"
    private let recordType = "AppUpdateNotification"
    private let subscriptionID = "app-update-notifications"

    // MARK: - Published State

    @Published public var availableUpdate: AppUpdateInfo?
    @Published public var isCheckingForUpdate = false
    @Published public var lastChecked: Date?
    @Published public var autoUpdateEnabled: Bool {
        didSet { UserDefaults.standard.set(autoUpdateEnabled, forKey: "thea.update.autoEnabled") }
    }
    @Published public var updateHistory: [AppUpdateInfo] = []

    // MARK: - Private

    private var _container: CKContainer?
    private var cloudKitAvailable: Bool?
    private var subscriptionSetUp = false
    // MARK: - CloudKit Access

    /// Ensures CloudKit is available and returns the container, or nil if unavailable
    private func getContainer() async -> CKContainer? {
        // Already determined unavailable
        if cloudKitAvailable == false {
            return nil
        }

        // Already initialized
        if let container = _container {
            return container
        }

        // Check account status first using default container (safe, won't crash)
        let defaultContainer = CKContainer.default()
        do {
            let status = try await defaultContainer.accountStatus()
            switch status {
            case .available:
                // Account available, safe to create custom container
                _container = CKContainer(identifier: containerIdentifier)
                cloudKitAvailable = true
                logger.info("CloudKit available, container initialized")
                return _container
            case .noAccount:
                logger.warning("CloudKit unavailable: No iCloud account signed in")
                cloudKitAvailable = false
                return nil
            case .restricted:
                logger.warning("CloudKit unavailable: iCloud restricted")
                cloudKitAvailable = false
                return nil
            case .couldNotDetermine:
                logger.warning("CloudKit unavailable: Could not determine account status")
                cloudKitAvailable = false
                return nil
            case .temporarilyUnavailable:
                logger.info("CloudKit temporarily unavailable, will retry later")
                // Don't set cloudKitAvailable = false, allow retry
                return nil
            @unknown default:
                logger.warning("CloudKit unavailable: Unknown status")
                cloudKitAvailable = false
                return nil
            }
        } catch {
            logger.error("Failed to check CloudKit account status: \(error.localizedDescription)")
            cloudKitAvailable = false
            return nil
        }
    }

    /// Returns the private database if CloudKit is available
    private func getPrivateDatabase() async -> CKDatabase? {
        await getContainer()?.privateCloudDatabase
    }

    // MARK: - Notification Category

    public static let updateCategoryID = "THEA_APP_UPDATE"
    public static let updateNowActionID = "UPDATE_NOW"
    public static let remindLaterActionID = "REMIND_LATER"

    // MARK: - Init

    private init() {
        autoUpdateEnabled = UserDefaults.standard.bool(forKey: "thea.update.autoEnabled")
        if !UserDefaults.standard.contains(key: "thea.update.autoEnabled") {
            autoUpdateEnabled = true
        }

        loadUpdateHistory()

        Task {
            await setupSubscription()
            await checkForUpdates()
        }
    }

    // MARK: - CloudKit Subscription

    private func setupSubscription() async {
        guard !subscriptionSetUp else { return }

        guard let database = await getPrivateDatabase() else {
            logger.debug("CloudKit not available - skipping subscription setup")
            return
        }

        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldBadge = false
        notificationInfo.alertLocalizationKey = "UPDATE_AVAILABLE"
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await database.save(subscription)
            subscriptionSetUp = true
            logger.info("App update CloudKit subscription created")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            subscriptionSetUp = true
            logger.debug("App update subscription already exists")
        } catch {
            logger.error("Failed to setup update subscription: \(error.localizedDescription)")
        }
    }

    // MARK: - Publish Update

    /// Call this after a successful build to notify other devices
    public func publishUpdate(
        version: String,
        build: String,
        commitHash: String,
        sourceDevice: String
    ) async throws {
        guard let database = await getPrivateDatabase() else {
            logger.debug("CloudKit not available - skipping update publish")
            return
        }

        let record = CKRecord(recordType: recordType)
        record["version"] = version as CKRecordValue
        record["build"] = build as CKRecordValue
        record["commitHash"] = commitHash as CKRecordValue
        record["sourceDevice"] = sourceDevice as CKRecordValue
        record["publishedAt"] = Date() as CKRecordValue
        record["platform"] = "macOS" as CKRecordValue
        record["deviceID"] = DeviceProfile.current().id as CKRecordValue

        do {
            _ = try await database.save(record)
            logger.info("Published update notification: v\(version) build \(build) from \(sourceDevice)")
        } catch {
            logger.error("Failed to publish update: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Check for Updates

    public func checkForUpdates() async {
        guard let database = await getPrivateDatabase() else {
            logger.debug("CloudKit not available - skipping update check")
            return
        }

        isCheckingForUpdate = true
        defer {
            isCheckingForUpdate = false
            lastChecked = Date()
        }

        let currentDeviceID = DeviceProfile.current().id
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"

        // Query for updates not from this device, sorted by newest first
        let predicate = NSPredicate(format: "deviceID != %@", currentDeviceID)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "publishedAt", ascending: false)]

        do {
            let results = try await database.records(matching: query, resultsLimit: 10)

            var latestUpdate: AppUpdateInfo?

            for (_, result) in results.matchResults {
                if case let .success(record) = result {
                    let info = AppUpdateInfo(from: record)

                    // Check if this is newer than what we have
                    if info.isNewer(thanVersion: currentVersion, build: currentBuild) {
                        if latestUpdate == nil || info.publishedAt > (latestUpdate?.publishedAt ?? .distantPast) {
                            latestUpdate = info
                        }
                    }
                }
            }

            if let update = latestUpdate {
                availableUpdate = update
                logger.info("Update available: v\(update.version) build \(update.build)")

                // Show notification if not already showing
                await showUpdateNotification(update)
            } else {
                availableUpdate = nil
                logger.debug("No updates available (current: v\(currentVersion) build \(currentBuild))")
            }
        } catch {
            logger.error("Failed to check for updates: \(error.localizedDescription)")
        }
    }

    // MARK: - Handle CloudKit Notification

    /// Called when a CloudKit push is received
    public func handleRemoteNotification() async {
        await checkForUpdates()
    }

    // MARK: - Show Local Notification

    private func showUpdateNotification(_ update: AppUpdateInfo) async {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Thea Update Available"
        content.body = "Version \(update.version) (build \(update.build)) is ready from \(update.sourceDevice)."
        content.categoryIdentifier = Self.updateCategoryID
        content.sound = .default
        content.userInfo = [
            "updateVersion": update.version,
            "updateBuild": update.build,
            "commitHash": update.commitHash,
            "sourceDevice": update.sourceDevice
        ]

        let request = UNNotificationRequest(
            identifier: "thea-update-\(update.commitHash)",
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await center.add(request)
            logger.info("Update notification displayed for v\(update.version)")
        } catch {
            logger.error("Failed to show update notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Perform Update

    /// Trigger the sync script to pull, build, and install the update
    public func performUpdate() async -> Bool {
        #if os(macOS)
        logger.info("Starting update...")

        let syncScript = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("bin/thea-sync.sh")

        guard FileManager.default.fileExists(atPath: syncScript.path) else {
            logger.error("Sync script not found at \(syncScript.path)")
            return false
        }

        let scriptPath = syncScript.path
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path

        // Run the process on a background thread to avoid blocking the main actor
        let result: (success: Bool, output: String, status: Int32) = await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath, "--build-install"]
            process.environment = [
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
                "HOME": homePath
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                return (process.terminationStatus == 0, output, process.terminationStatus)
            } catch {
                return (false, error.localizedDescription, -1)
            }
        }.value

        if result.success {
            logger.info("Update completed successfully")

            // Record in history before clearing
            if let update = availableUpdate {
                var info = update
                info.installedAt = Date()
                updateHistory.insert(info, at: 0)
                saveUpdateHistory()
            }

            availableUpdate = nil

            // Cleanup old CloudKit records
            await cleanupOldUpdateRecords()

            return true
        } else {
            logger.error("Update failed (exit \(result.status)): \(result.output)")
            return false
        }
        #else
        logger.warning("Auto-update is only supported on macOS")
        return false
        #endif
    }

    // MARK: - Handle Notification Action

    public func handleNotificationAction(_ actionID: String, userInfo: [AnyHashable: Any]) {
        switch actionID {
        case Self.updateNowActionID:
            Task {
                _ = await performUpdate()
            }
        case Self.remindLaterActionID:
            // Schedule a reminder in 1 hour
            Task {
                try? await Task.sleep(for: .seconds(3600))
                if let update = availableUpdate {
                    await showUpdateNotification(update)
                }
            }
        default:
            break
        }
    }

    // MARK: - Register Notification Category

    public static func registerNotificationCategory() {
        let updateAction = UNNotificationAction(
            identifier: updateNowActionID,
            title: "Update Now",
            options: [.foreground]
        )

        let remindAction = UNNotificationAction(
            identifier: remindLaterActionID,
            title: "Remind Later",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: updateCategoryID,
            actions: [updateAction, remindAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { existing in
            var categories = existing
            categories.insert(category)
            center.setNotificationCategories(categories)
        }
    }

    // MARK: - Cleanup

    private func cleanupOldUpdateRecords() async {
        guard let database = await getPrivateDatabase() else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = NSPredicate(format: "publishedAt < %@", cutoff as NSDate)
        let query = CKQuery(recordType: recordType, predicate: predicate)

        do {
            let results = try await database.records(matching: query)
            let recordIDs = results.matchResults.map { $0.0 }
            if !recordIDs.isEmpty {
                _ = try await database.modifyRecords(saving: [], deleting: recordIDs)
                logger.info("Cleaned up \(recordIDs.count) old update records")
            }
        } catch {
            logger.warning("Cleanup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - History Persistence

    private func loadUpdateHistory() {
        guard let data = UserDefaults.standard.data(forKey: "thea.update.history"),
              let history = try? JSONDecoder().decode([AppUpdateInfo].self, from: data)
        else { return }
        updateHistory = history
    }

    private func saveUpdateHistory() {
        // Keep only last 20
        let trimmed = Array(updateHistory.prefix(20))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: "thea.update.history")
        }
    }

    // MARK: - Dismiss Update

    public func dismissUpdate() {
        availableUpdate = nil
    }
}

// MARK: - App Update Info

public struct AppUpdateInfo: Codable, Identifiable, Sendable {
    public var id: String { commitHash }
    public let version: String
    public let build: String
    public let commitHash: String
    public let sourceDevice: String
    public let publishedAt: Date
    public let platform: String
    public var installedAt: Date?

    init(
        version: String,
        build: String,
        commitHash: String,
        sourceDevice: String,
        publishedAt: Date = Date(),
        platform: String = "macOS",
        installedAt: Date? = nil
    ) {
        self.version = version
        self.build = build
        self.commitHash = commitHash
        self.sourceDevice = sourceDevice
        self.publishedAt = publishedAt
        self.platform = platform
        self.installedAt = installedAt
    }

    init(from record: CKRecord) {
        version = record["version"] as? String ?? "Unknown"
        build = record["build"] as? String ?? "0"
        commitHash = record["commitHash"] as? String ?? UUID().uuidString
        sourceDevice = record["sourceDevice"] as? String ?? "Unknown"
        publishedAt = record["publishedAt"] as? Date ?? record.creationDate ?? Date()
        platform = record["platform"] as? String ?? "macOS"
        installedAt = nil
    }

    func isNewer(thanVersion currentVersion: String, build currentBuild: String) -> Bool {
        if version.compare(currentVersion, options: .numeric) == .orderedDescending {
            return true
        }
        if version == currentVersion,
           build.compare(currentBuild, options: .numeric) == .orderedDescending {
            return true
        }
        return false
    }
}

// MARK: - Notification Name

public extension Notification.Name {
    static let theaAppUpdateAvailable = Notification.Name("theaAppUpdateAvailable")
}

// MARK: - UserDefaults helper

private extension UserDefaults {
    func contains(key: String) -> Bool {
        object(forKey: key) != nil
    }
}
