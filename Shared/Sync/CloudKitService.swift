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
    private var sharedDatabase: CKDatabase?
    private var publicDatabase: CKDatabase?

    // MARK: - Zone

    /// All Thea records live in a custom zone for delta sync support
    static let theaZoneID = CKRecordZone.ID(zoneName: "TheaZone", ownerName: CKCurrentUserDefaultName)

    // MARK: - Record Types

    enum RecordType: String {
        case conversation = "Conversation"
        case message = "Message"
        case settings = "Settings"
        case knowledge = "Knowledge"
        case project = "Project"
        case userProfile = "UserProfile"
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

        // Observe conflict resolution from UI
        setupConflictResolutionObserver()

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
        }
    }

    /// Create a CKContainer, catching any assertion failures from misconfigured entitlements.
    private static func createContainer(identifier: String) throws -> CKContainer {
        // Use the default container instead of a named one if the identifier
        // isn't present in the app's entitlements.  CKContainer(identifier:)
        // will hit a `brk` instruction (crash) if the identifier is missing.
        // We verify by checking the entitlements key first.
        guard let containers = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.icloud-container-identifiers") as? [String],
              containers.contains(identifier) else {
            // Identifier not in Info.plist / entitlements — fall back to default container
            return CKContainer.default()
        }
        return CKContainer(identifier: identifier)
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

    /// Tracks pending token changes for batched saving
    private var hasUnsavedTokenChanges = false

    func setChangeToken(_ token: CKServerChangeToken?, for zoneID: CKRecordZone.ID) {
        changeTokens[zoneID.zoneName] = token
        // Batch token saves — defer to avoid N consecutive UserDefaults writes during multi-zone sync
        if !hasUnsavedTokenChanges {
            hasUnsavedTokenChanges = true
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.saveChangeTokens()
                self.hasUnsavedTokenChanges = false
            }
        }
    }

    private func setupConflictResolutionObserver() {
        NotificationCenter.default.addObserver(
            forName: .syncConflictResolved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let conflictId = notification.userInfo?["conflictId"] as? UUID
            Task { @MainActor [weak self] in
                self?.logger.info("Conflict resolved: \(conflictId?.uuidString ?? "unknown")")
            }
        }
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

        // Re-check iCloud status when account changes (sign in/out mid-session)
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkiCloudStatus()
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
}
