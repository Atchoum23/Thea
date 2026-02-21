//
//  CloudKitService.swift
//  Thea
//
//  CloudKit sync for conversations, settings, and user data
//

import CloudKit
import Combine
import Foundation
import os.log

// MARK: - CloudKit Service

/// Service for managing CloudKit sync across devices
@MainActor
public class CloudKitService: ObservableObject {
    public static let shared = CloudKitService()

    let logger = Logger(subsystem: "app.theathe", category: "CloudKitService")

    // MARK: - Published State

    @Published public internal(set) var syncStatus: CloudSyncStatus = .idle
    @Published public internal(set) var lastSyncDate: Date?
    @Published public private(set) var iCloudAvailable = false
    @Published public internal(set) var pendingChanges = 0
    @Published public var syncEnabled = true

    // MARK: - CloudKit Configuration

    private let containerIdentifier = "iCloud.app.theathe"
    private var container: CKContainer?
    var privateDatabase: CKDatabase?
    // periphery:ignore - Reserved: sharedDatabase property — reserved for future feature activation
    private var sharedDatabase: CKDatabase?
    // periphery:ignore - Reserved: publicDatabase property — reserved for future feature activation
    private var publicDatabase: CKDatabase?

// periphery:ignore - Reserved: sharedDatabase property reserved for future feature activation

// periphery:ignore - Reserved: publicDatabase property reserved for future feature activation

    // MARK: - Record Types

    enum RecordType: String {
        case conversation = "Conversation"
        case message = "Message"
        case settings = "Settings"
        case knowledge = "Knowledge"
        case project = "Project"
        case userProfile = "UserProfile"
        case messagingSettings = "MessagingSettings"  // P12: gateway channel config (no credentials)
    }

    // MARK: - Subscriptions

    var subscriptions: Set<CKSubscription.ID> = []

    // MARK: - Change Tokens (for Delta Sync)

    private let changeTokenKey = "CloudKitChangeTokens"
    private var changeTokens: [String: CKServerChangeToken] = [:]

    // MARK: - Initialization

    private init() {
        // Load initial sync state from SettingsManager
        syncEnabled = SettingsManager.shared.iCloudSyncEnabled

        // Observe settings changes (lightweight, non-blocking)
        setupSettingsObserver()

        // Defer all heavy CloudKit operations to avoid blocking view layout.
        // Container creation, change token loading, and subscription setup
        // all happen on the next run loop iteration.
        Task { [weak self] in
            guard let self else { return }

            // Initialize CloudKit container safely
            do {
                let ckContainer = try Self.createContainer(identifier: self.containerIdentifier)
                self.container = ckContainer
                self.privateDatabase = ckContainer.privateCloudDatabase
                self.sharedDatabase = ckContainer.sharedCloudDatabase
                self.publicDatabase = ckContainer.publicCloudDatabase
            } catch {
                self.iCloudAvailable = false
                self.syncStatus = .error("CloudKit container not configured")
            }

            // Load saved change tokens for delta sync
            self.loadChangeTokens()

            await self.checkiCloudStatus()
            await self.setupSubscriptions()

            // P12: Pull messaging settings on startup so preferences sync across devices
            await self.pullMessagingSettings()
        }
    }

    /// Create a CKContainer safely. Throws a Swift error (instead of crashing) when
    /// the iCloud container entitlement is absent — e.g. in ad-hoc signed builds.
    ///
    /// IMPORTANT: Both CKContainer(identifier:) AND CKContainer.default() throw an
    /// uncatchable ObjC NSException (SIGABRT) when entitlements are missing. Swift's
    /// try/catch does NOT intercept ObjC exceptions. We must pre-check the TeamIdentifier
    /// via codesign and throw a real Swift error that the caller's do/catch can handle.
    private static func createContainer(identifier: String) throws -> CKContainer {
        // TeamIdentifier pre-check: ad-hoc/unsigned builds have "TeamIdentifier=not set".
        // Properly signed builds have "TeamIdentifier=<10-char ID>".
        guard hasCloudKitContainerEntitlement() else {
            throw NSError(
                domain: "ai.thea.app.CloudKitService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "iCloud container entitlement absent (ad-hoc/unsigned build)"]
            )
        }
        // Entitlement confirmed present — safe to call CKContainer.
        guard let containers = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.icloud-container-identifiers") as? [String],
              containers.contains(identifier) else {
            // Identifier not in plist — fall back to default container (safe: entitlement confirmed)
            return CKContainer.default()
        }
        return CKContainer(identifier: identifier)
    }

    /// Returns true when the process has a real Apple developer TeamIdentifier,
    /// meaning it was signed with proper CloudKit entitlements. Ad-hoc and
    /// unsigned builds report "TeamIdentifier=not set" and must skip CKContainer.
    /// Internal (not private) so other CloudKit services can reuse this check.
    nonisolated static func hasCloudKitContainerEntitlement() -> Bool {
        guard let execPath = Bundle.main.executablePath else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--display", "--verbose=4", execPath]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return false }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return !output.contains("TeamIdentifier=not set") &&
                   output.contains("TeamIdentifier=")
        } catch {
            return false
        }
    }

    // MARK: - Change Token Persistence

    private func loadChangeTokens() {
        guard let data = UserDefaults.standard.data(forKey: changeTokenKey) else { return }
        do {
            guard let tokens = try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSDictionary.self, NSString.self, CKServerChangeToken.self],
                from: data
            ) as? [String: CKServerChangeToken] else { return }
            changeTokens = tokens
        } catch {
            logger.error("Failed to load CloudKit change tokens: \(error.localizedDescription)")
        }
    }

    private func saveChangeTokens() {
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: changeTokens as NSDictionary,
                requiringSecureCoding: true
            )
            UserDefaults.standard.set(data, forKey: changeTokenKey)
        } catch {
            logger.error("Failed to save CloudKit change tokens: \(error.localizedDescription)")
        }
    }

    func getChangeToken(for zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        changeTokens[zoneID.zoneName]
    }

    func setChangeToken(_ token: CKServerChangeToken?, for zoneID: CKRecordZone.ID) {
        changeTokens[zoneID.zoneName] = token
        saveChangeTokens()
    }

    private func setupSettingsObserver() {
        // Watch for changes to iCloudSyncEnabled
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncEnabled = SettingsManager.shared.iCloudSyncEnabled
            }
        }
    }

    // MARK: - iCloud Status

    private func checkiCloudStatus() async {
        guard let container else {
            iCloudAvailable = false
            return
        }
        do {
            let status = try await container.accountStatus()
            iCloudAvailable = status == .available
        } catch {
            iCloudAvailable = false
        }
    }

    // MARK: - P12: Messaging Gateway Settings Sync

    /// Unique CKRecord ID for the messaging settings record (one per iCloud account).
    private let messagingSettingsRecordID = CKRecord.ID(
        recordName: "thea-messaging-settings",
        zoneID: .default
    )

    // periphery:ignore - Reserved: pushMessagingSettings() instance method — reserved for future feature activation
    /// Push non-sensitive messaging gateway settings to CloudKit.
    ///
    /// **Privacy guarantee**: Credentials (botToken, apiKey, webhookSecret, serverUrl) are NEVER
    /// written to CloudKit. Only the enabled/disabled state per platform and auto-respond
    /// configuration are synced. Sensitive credentials remain in Keychain only.
    @discardableResult
    func pushMessagingSettings() async -> Bool {
        guard syncEnabled, iCloudAvailable, let db = privateDatabase else {
            logger.debug("P12: Skipping messaging settings push (sync disabled or iCloud unavailable)")
            return false
        }

        // Collect which platforms are enabled (isEnabled flag only — no tokens)
        let enabledPlatforms = MessagingPlatform.allCases
            .filter { MessagingCredentialsStore.load(for: $0).isEnabled }
            .map(\.rawValue)

        // Collect auto-respond settings from OpenClawBridge
        let bridge = OpenClawBridge.shared
        let autoRespondEnabled = bridge.autoRespondEnabled
        let autoRespondChannels = Array(bridge.autoRespondChannels)
        let allowedSenders = Array(bridge.allowedSenders)

        do {
            // Fetch existing record if it exists (for proper save to avoid conflicts)
            let record: CKRecord
            do {
                record = try await db.record(for: messagingSettingsRecordID)
            } catch {
                record = CKRecord(recordType: RecordType.messagingSettings.rawValue,
                                  recordID: messagingSettingsRecordID)
            }

            record["enabledPlatforms"] = enabledPlatforms as CKRecordValue
            record["autoRespondEnabled"] = autoRespondEnabled as CKRecordValue
            record["autoRespondChannels"] = autoRespondChannels as CKRecordValue
            record["allowedSenders"] = allowedSenders as CKRecordValue
            record["lastUpdated"] = Date() as CKRecordValue
            // Explicitly NOT saving: botToken, apiKey, webhookSecret, serverUrl

            try await db.save(record)
            logger.info("P12: Pushed messaging settings — \(enabledPlatforms.count) platforms enabled")
            return true
        } catch {
            logger.error("P12: Failed to push messaging settings: \(error.localizedDescription)")
            return false
        }
    }

    /// Pull messaging gateway settings from CloudKit and apply if newer than local state.
    ///
    /// Conflict resolution: CloudKit record's `lastUpdated` vs local `UserDefaults` timestamp.
    /// If CloudKit is newer, settings are applied. Credentials in Keychain are never touched.
    @discardableResult
    func pullMessagingSettings() async -> Bool {
        guard syncEnabled, iCloudAvailable, let db = privateDatabase else {
            logger.debug("P12: Skipping messaging settings pull (sync disabled or iCloud unavailable)")
            return false
        }

        do {
            let record = try await db.record(for: messagingSettingsRecordID)

            // Conflict resolution: only apply if CloudKit is newer
            let cloudUpdated = record["lastUpdated"] as? Date ?? .distantPast
            let localUpdated = UserDefaults.standard.object(forKey: "messagingSettingsLastPushed") as? Date ?? .distantPast
            guard cloudUpdated > localUpdated else {
                logger.debug("P12: Local messaging settings are up to date (cloud: \(cloudUpdated), local: \(localUpdated))")
                return false
            }

            // Apply non-sensitive settings
            let enabledPlatforms = Set((record["enabledPlatforms"] as? [String]) ?? [])
            let autoRespondEnabled = (record["autoRespondEnabled"] as? Bool) ?? false
            let autoRespondChannels = Set((record["autoRespondChannels"] as? [String]) ?? [])
            let allowedSenders = Set((record["allowedSenders"] as? [String]) ?? [])

            // Apply platform enabled states (only enable/disable — never touch credentials)
            for platform in MessagingPlatform.allCases {
                var creds = MessagingCredentialsStore.load(for: platform)
                let shouldBeEnabled = enabledPlatforms.contains(platform.rawValue)
                if creds.isEnabled != shouldBeEnabled {
                    creds.isEnabled = shouldBeEnabled
                    MessagingCredentialsStore.save(creds, for: platform)
                }
            }

            // Apply OpenClawBridge settings
            let bridge = OpenClawBridge.shared
            bridge.autoRespondEnabled = autoRespondEnabled
            bridge.autoRespondChannels = autoRespondChannels
            bridge.allowedSenders = allowedSenders

            // Record local timestamp to avoid re-applying same data
            UserDefaults.standard.set(cloudUpdated, forKey: "messagingSettingsLastPushed")

            logger.info("P12: Applied messaging settings from CloudKit — \(enabledPlatforms.count) platforms, autoRespond=\(autoRespondEnabled)")
            return true
        } catch let error as CKError where error.code == .unknownItem {
            logger.debug("P12: No messaging settings record in CloudKit yet")
            return false
        } catch {
            logger.error("P12: Failed to pull messaging settings: \(error.localizedDescription)")
            return false
        }
    }
}
