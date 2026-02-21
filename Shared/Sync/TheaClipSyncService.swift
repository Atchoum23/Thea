// TheaClipSyncService.swift
// Thea — Live iCloud sync for clipboard history and pinboards

import CloudKit
import Foundation
import os.log
@preconcurrency import SwiftData

private let syncLogger = Logger(subsystem: "ai.thea.app", category: "ClipSync")

/// Syncs TheaClipEntry and TheaClipPinboard across devices via CloudKit.
/// Uses the same CKContainer and zone as CloudKitService ("TheaZone").
@MainActor
final class TheaClipSyncService: ObservableObject {
    static let shared = TheaClipSyncService()

    private var modelContext: ModelContext?
    private var container: CKContainer?
    private var privateDatabase: CKDatabase?
    private let zoneID = CKRecordZone.ID(zoneName: "TheaZone", ownerName: CKCurrentUserDefaultName)

    // Change token for delta sync
    private let tokenKey = "TheaClipSyncChangeToken"
    private var changeToken: CKServerChangeToken?

    @Published var isSyncing = false

    private init() {}

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadChangeToken()

        // CLOUDKIT NSException FIX (2026-02-21): CKContainer(identifier:) and
        // CKContainer.default() throw an uncatchable ObjC NSException (SIGABRT)
        // when the iCloud container entitlement is absent — e.g. in ad-hoc signed
        // or unsigned DEBUG builds (CODE_SIGNING_ALLOWED=NO). Swift catch blocks
        // do NOT intercept ObjC exceptions; the crash is fatal. Pre-check the
        // TeamIdentifier via codesign to skip CloudKit init safely in such builds.
        guard Self.hasCloudKitContainerEntitlement() else {
            syncLogger.info("CloudKit entitlement absent — TheaClipSyncService disabled (unsigned/ad-hoc build)")
            return
        }

        // Reuse CloudKitService's container approach
        let containerID = "iCloud.app.theathe"
        if let containers = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.icloud-container-identifiers") as? [String],
           containers.contains(containerID)
        {
            container = CKContainer(identifier: containerID)
        } else {
            container = CKContainer.default()
        }
        privateDatabase = container?.privateCloudDatabase

        // Subscribe to remote clip changes
        Task { await setupSubscription() }

        syncLogger.info("TheaClipSyncService configured")
    }

    /// Returns true when the process has a real Apple developer TeamIdentifier,
    /// meaning it was signed with proper CloudKit entitlements. Ad-hoc and
    /// unsigned builds report "TeamIdentifier=not set" and must skip CKContainer.
    nonisolated private static func hasCloudKitContainerEntitlement() -> Bool {
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

    // MARK: - Push (Local → iCloud)

    /// Push a new or updated clip entry to iCloud
    func pushEntry(_ entry: TheaClipEntry) async {
        guard SettingsManager.shared.clipboardSyncEnabled,
              let db = privateDatabase else { return }

        let record = entryToRecord(entry)
        do {
            try await db.save(record)
            syncLogger.debug("Pushed clip entry \(entry.id) to iCloud")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Conflict: remote is newer — skip (pull will reconcile)
            syncLogger.debug("Clip entry \(entry.id) has remote conflict — will reconcile on pull")
        } catch {
            syncLogger.error("Failed to push clip entry: \(error.localizedDescription)")
        }
    }

    /// Push a pinboard to iCloud
    func pushPinboard(_ pinboard: TheaClipPinboard) async {
        guard SettingsManager.shared.clipboardSyncPinboards,
              let db = privateDatabase else { return }

        let record = pinboardToRecord(pinboard)
        do {
            try await db.save(record)
            syncLogger.debug("Pushed pinboard \(pinboard.id) to iCloud")
        } catch {
            syncLogger.error("Failed to push pinboard: \(error.localizedDescription)")
        }
    }

    /// Delete a clip entry from iCloud
    func deleteRemoteEntry(_ id: UUID) async {
        guard let db = privateDatabase else { return }
        let recordID = CKRecord.ID(recordName: "clip-\(id.uuidString)", zoneID: zoneID)
        do {
            try await db.deleteRecord(withID: recordID)
        } catch {
            syncLogger.error("Failed to delete remote clip: \(error.localizedDescription)")
        }
    }

    /// Delete a pinboard from iCloud
    func deleteRemotePinboard(_ id: UUID) async {
        guard let db = privateDatabase else { return }
        let recordID = CKRecord.ID(recordName: "pinboard-\(id.uuidString)", zoneID: zoneID)
        do {
            try await db.deleteRecord(withID: recordID)
        } catch {
            syncLogger.error("Failed to delete remote pinboard: \(error.localizedDescription)")
        }
    }

    // MARK: - Pull (iCloud → Local)

    /// Perform delta sync — fetch only changes since last token
    func pullChanges() async {
        guard SettingsManager.shared.clipboardSyncEnabled,
              let db = privateDatabase else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Ensure zone exists
        do {
            _ = try await db.save(CKRecordZone(zoneID: zoneID))
        } catch {
            // Zone likely already exists
        }

        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: changeToken
        )

        let operation = CKFetchRecordZoneChangesOperation()
        operation.configurationsByRecordZoneID = [zoneID: config]

        var changedRecords: [CKRecord] = []
        var deletedIDs: [CKRecord.ID] = []
        var newToken: CKServerChangeToken?

        operation.recordWasChangedBlock = { _, result in
            if case let .success(record) = result {
                changedRecords.append(record)
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedIDs.append(recordID)
        }

        operation.recordZoneFetchResultBlock = { _, result in
            if case let .success((token, _, _)) = result {
                newToken = token
            }
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case let .failure(error):
                        if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                            continuation.resume() // Will do full fetch next time
                        } else {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                db.add(operation)
            }
        } catch {
            syncLogger.error("Pull failed: \(error.localizedDescription)")
            return
        }

        // Save new token
        if let token = newToken {
            changeToken = token
            saveChangeToken()
        }

        // Process changes
        for record in changedRecords {
            processRemoteRecord(record)
        }

        for recordID in deletedIDs {
            processRemoteDeletion(recordID)
        }

        if !changedRecords.isEmpty || !deletedIDs.isEmpty {
            syncLogger.info("Pulled \(changedRecords.count) changes, \(deletedIDs.count) deletions")
            // Reload the manager's entries
            ClipboardHistoryManager.shared.loadRecentEntries()
            ClipboardHistoryManager.shared.loadPinboards()
        }
    }

    // MARK: - Record Processing

    private func processRemoteRecord(_ record: CKRecord) {
        guard let context = modelContext else { return }

        switch record.recordType {
        case "ClipEntry":
            let remoteID = UUID(uuidString: record.recordID.recordName.replacingOccurrences(of: "clip-", with: "")) ?? UUID()

            // Check if we already have this entry
            var descriptor = FetchDescriptor<TheaClipEntry>(
                predicate: #Predicate { $0.id == remoteID }
            )
            descriptor.fetchLimit = 1

            let existing: TheaClipEntry?
            do {
                existing = try context.fetch(descriptor).first
            } catch {
                syncLogger.error("❌ Failed to fetch clip entry: \(error.localizedDescription)")
                existing = nil
            }

            if let existing {
                let remoteDate = record["createdAt"] as? Date ?? Date.distantPast
                if remoteDate > existing.createdAt {
                    applyRecordToEntry(record, entry: existing)
                }
            } else {
                let entry = TheaClipEntry()
                entry.id = remoteID
                applyRecordToEntry(record, entry: entry)
                context.insert(entry)
            }

            do {
                try context.save()
            } catch {
                syncLogger.error("❌ Failed to save clip entry: \(error.localizedDescription)")
            }

        case "ClipPinboard":
            let remoteID = UUID(uuidString: record.recordID.recordName.replacingOccurrences(of: "pinboard-", with: "")) ?? UUID()

            var descriptor = FetchDescriptor<TheaClipPinboard>(
                predicate: #Predicate { $0.id == remoteID }
            )
            descriptor.fetchLimit = 1

            let existing: TheaClipPinboard?
            do {
                existing = try context.fetch(descriptor).first
            } catch {
                syncLogger.error("❌ Failed to fetch pinboard: \(error.localizedDescription)")
                existing = nil
            }

            if let existing {
                existing.name = record["name"] as? String ?? existing.name
                existing.icon = record["icon"] as? String ?? existing.icon
                existing.colorHex = record["colorHex"] as? String ?? existing.colorHex
                existing.sortOrder = record["sortOrder"] as? Int ?? existing.sortOrder
                existing.updatedAt = record["updatedAt"] as? Date ?? Date()
            } else {
                let pinboard = TheaClipPinboard(
                    id: remoteID,
                    name: record["name"] as? String ?? "Pinboard",
                    icon: record["icon"] as? String ?? "pin.fill",
                    colorHex: record["colorHex"] as? String ?? "#F5A623",
                    sortOrder: record["sortOrder"] as? Int ?? 0
                )
                context.insert(pinboard)
            }

            do {
                try context.save()
            } catch {
                syncLogger.error("❌ Failed to save pinboard: \(error.localizedDescription)")
            }

        default:
            break
        }
    }

    private func applyRecordToEntry(_ record: CKRecord, entry: TheaClipEntry) {
        entry.contentTypeRaw = record["contentType"] as? String ?? "text"
        entry.textContent = record["textContent"] as? String
        entry.htmlContent = record["htmlContent"] as? String
        entry.urlString = record["urlString"] as? String
        entry.sourceAppBundleID = record["sourceAppBundleID"] as? String
        entry.sourceAppName = record["sourceAppName"] as? String
        entry.characterCount = record["characterCount"] as? Int ?? 0
        entry.byteCount = record["byteCount"] as? Int ?? 0
        entry.createdAt = record["createdAt"] as? Date ?? Date()
        entry.lastAccessedAt = record["lastAccessedAt"] as? Date ?? Date()
        entry.accessCount = record["accessCount"] as? Int ?? 0
        entry.isPinned = record["isPinned"] as? Bool ?? false
        entry.isFavorite = record["isFavorite"] as? Bool ?? false
        entry.isSensitive = record["isSensitive"] as? Bool ?? false
        entry.tags = record["tags"] as? [String] ?? []
        entry.previewText = record["previewText"] as? String ?? ""
        // Note: imageData is NOT synced to save iCloud quota — images stay local
    }

    private func processRemoteDeletion(_ recordID: CKRecord.ID) {
        guard let context = modelContext else { return }
        let name = recordID.recordName

        do {
            if name.hasPrefix("clip-"), let uuid = UUID(uuidString: String(name.dropFirst(5))) {
                var descriptor = FetchDescriptor<TheaClipEntry>(
                    predicate: #Predicate { $0.id == uuid }
                )
                descriptor.fetchLimit = 1
                if let entry = try context.fetch(descriptor).first {
                    context.delete(entry)
                    try context.save()
                }
            } else if name.hasPrefix("pinboard-"), let uuid = UUID(uuidString: String(name.dropFirst(9))) {
                var descriptor = FetchDescriptor<TheaClipPinboard>(
                    predicate: #Predicate { $0.id == uuid }
                )
                descriptor.fetchLimit = 1
                if let pinboard = try context.fetch(descriptor).first {
                    context.delete(pinboard)
                    try context.save()
                }
            }
        } catch {
            syncLogger.error("❌ Failed to process remote deletion: \(error.localizedDescription)")
        }
    }

    // MARK: - Record Conversion

    private func entryToRecord(_ entry: TheaClipEntry) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "clip-\(entry.id.uuidString)", zoneID: zoneID)
        let record = CKRecord(recordType: "ClipEntry", recordID: recordID)
        record["contentType"] = entry.contentTypeRaw as CKRecordValue
        record["textContent"] = entry.textContent as CKRecordValue?
        record["htmlContent"] = entry.htmlContent as CKRecordValue?
        record["urlString"] = entry.urlString as CKRecordValue?
        record["sourceAppBundleID"] = entry.sourceAppBundleID as CKRecordValue?
        record["sourceAppName"] = entry.sourceAppName as CKRecordValue?
        record["characterCount"] = entry.characterCount as CKRecordValue
        record["byteCount"] = entry.byteCount as CKRecordValue
        record["createdAt"] = entry.createdAt as CKRecordValue
        record["lastAccessedAt"] = entry.lastAccessedAt as CKRecordValue
        record["accessCount"] = entry.accessCount as CKRecordValue
        record["isPinned"] = entry.isPinned as CKRecordValue
        record["isFavorite"] = entry.isFavorite as CKRecordValue
        record["isSensitive"] = entry.isSensitive as CKRecordValue
        record["tags"] = entry.tags as CKRecordValue
        record["previewText"] = entry.previewText as CKRecordValue
        // Note: imageData NOT synced (too large for iCloud quota)
        return record
    }

    private func pinboardToRecord(_ pinboard: TheaClipPinboard) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "pinboard-\(pinboard.id.uuidString)", zoneID: zoneID)
        let record = CKRecord(recordType: "ClipPinboard", recordID: recordID)
        record["name"] = pinboard.name as CKRecordValue
        record["icon"] = pinboard.icon as CKRecordValue
        record["colorHex"] = pinboard.colorHex as CKRecordValue
        record["sortOrder"] = pinboard.sortOrder as CKRecordValue
        record["createdAt"] = pinboard.createdAt as CKRecordValue
        record["updatedAt"] = pinboard.updatedAt as CKRecordValue
        return record
    }

    // MARK: - Subscription

    private func setupSubscription() async {
        guard let db = privateDatabase else { return }

        let subscriptionID = "clip-changes"
        let subscription = CKQuerySubscription(
            recordType: "ClipEntry",
            predicate: NSPredicate(value: true),
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            try await db.save(subscription)
            syncLogger.info("Subscribed to clip changes")
        } catch {
            // Subscription may already exist
        }

        // Also subscribe to pinboard changes
        let pinboardSub = CKQuerySubscription(
            recordType: "ClipPinboard",
            predicate: NSPredicate(value: true),
            subscriptionID: "pinboard-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        pinboardSub.notificationInfo = notificationInfo

        do {
            try await db.save(pinboardSub)
        } catch {
            // Already exists
        }
    }

    /// Called from AppDelegate when a remote notification arrives
    func handleRemoteNotification() async {
        await pullChanges()
    }

    // MARK: - Change Token Persistence

    private func loadChangeToken() {
        guard let data = UserDefaults.standard.data(forKey: tokenKey) else { return }
        // Missing token just triggers full sync on failure
        do {
            changeToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        } catch {
            syncLogger.debug("Could not decode change token, will do full sync: \(error.localizedDescription)")
        }
    }

    private func saveChangeToken() {
        guard let token = changeToken else { return }
        // Token will be re-fetched on next sync if save fails
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: tokenKey)
        } catch {
            syncLogger.debug("Could not save change token: \(error.localizedDescription)")
        }
    }
}
