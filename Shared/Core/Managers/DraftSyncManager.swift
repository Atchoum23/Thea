//
//  DraftSyncManager.swift
//  Thea
//
//  Manages input field draft persistence and cross-device synchronization.
//  Drafts are NEVER auto-deleted except on explicit user action (send/edit/delete).
//  Persists across app launches and syncs between devices.
//
//  Copyright 2026. All rights reserved.
//

import CloudKit
import Combine
import Foundation
import os.log

// MARK: - Draft Model

/// Represents a draft input that persists across sessions and devices
public struct InputDraft: Codable, Identifiable, Sendable {
    public let id: UUID
    public var conversationId: UUID?
    public var text: String
    public var attachments: [DraftAttachment]
    public var cursorPosition: Int?
    public var lastModified: Date
    public var deviceId: String

    public init(
        id: UUID = UUID(),
        conversationId: UUID? = nil,
        text: String = "",
        attachments: [DraftAttachment] = [],
        cursorPosition: Int? = nil,
        lastModified: Date = Date(),
        deviceId: String = ""
    ) {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.attachments = attachments
        self.cursorPosition = cursorPosition
        self.lastModified = lastModified
        self.deviceId = deviceId
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty
    }
}

/// Attachment in a draft
public struct DraftAttachment: Codable, Identifiable, Sendable {
    public let id: UUID
    public let type: AttachmentType
    public let localPath: String?
    public let cloudPath: String?
    public let fileName: String
    public let fileSize: Int64
    public let mimeType: String?

    public enum AttachmentType: String, Codable, Sendable {
        case image
        case file
        case audio
        case video
        case code
    }

    public init(
        id: UUID = UUID(),
        type: AttachmentType,
        localPath: String? = nil,
        cloudPath: String? = nil,
        fileName: String,
        fileSize: Int64,
        mimeType: String? = nil
    ) {
        self.id = id
        self.type = type
        self.localPath = localPath
        self.cloudPath = cloudPath
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
    }
}

// MARK: - Draft Sync Manager

/// Manages draft persistence and cross-device synchronization
@MainActor
public final class DraftSyncManager: ObservableObject {
    public static let shared = DraftSyncManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "DraftSync")

    // MARK: - Published State

    /// Current draft for the active conversation (or global if no conversation)
    @Published public private(set) var currentDraft: InputDraft?

    /// All drafts indexed by conversation ID (nil key = global draft)
    @Published public private(set) var drafts: [UUID?: InputDraft] = [:]

    /// Whether sync is in progress
    @Published public private(set) var isSyncing: Bool = false

    /// Last sync error if any
    @Published public private(set) var lastSyncError: String?

    // MARK: - Configuration

    /// Sync delay in seconds (default 2 minutes as specified)
    @Published public var syncDelaySeconds: TimeInterval = 120.0

    /// Whether cross-device sync is enabled
    @Published public var crossDeviceSyncEnabled: Bool = true

    /// Whether to sync in real-time (0 delay) - use for live collaboration
    @Published public var liveSyncEnabled: Bool = false

    // MARK: - Private State

    private let defaults = UserDefaults.standard
    private let cloudKeyValueStore = NSUbiquitousKeyValueStore.default
    private var pendingSyncTask: Task<Void, Never>?
    private var syncDebounceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private let deviceId: String
    private let localStorageKey = "thea.drafts.local"
    private let cloudStorageKey = "thea.drafts.cloud"

    // MARK: - Initialization

    private init() {
        // Generate stable device ID
        if let existingId = defaults.string(forKey: "thea.deviceId") {
            deviceId = existingId
        } else {
            let newId = UUID().uuidString
            defaults.set(newId, forKey: "thea.deviceId")
            deviceId = newId
        }

        // Load local drafts
        loadLocalDrafts()

        // Setup cloud sync observation
        setupCloudSyncObserver()

        // Initial sync from cloud
        Task {
            await syncFromCloud()
        }

        logger.info("DraftSyncManager initialized with device ID: \(self.deviceId)")
    }

    // MARK: - Public API

    /// Get or create draft for a conversation
    public func getDraft(for conversationId: UUID?) -> InputDraft {
        if let existing = drafts[conversationId] {
            return existing
        }

        let newDraft = InputDraft(
            conversationId: conversationId,
            deviceId: deviceId
        )
        drafts[conversationId] = newDraft
        return newDraft
    }

    /// Update draft text - called on every keystroke (debounced internally)
    public func updateDraftText(_ text: String, for conversationId: UUID?) {
        var draft = getDraft(for: conversationId)
        draft.text = text
        draft.lastModified = Date()
        draft.deviceId = deviceId

        drafts[conversationId] = draft
        currentDraft = draft

        // Save locally immediately
        saveLocalDrafts()

        // Schedule cloud sync with debounce
        scheduleSyncToCloud()
    }

    /// Update draft cursor position
    public func updateCursorPosition(_ position: Int, for conversationId: UUID?) {
        guard var draft = drafts[conversationId] else { return }
        draft.cursorPosition = position
        draft.lastModified = Date()

        drafts[conversationId] = draft
        currentDraft = draft

        saveLocalDrafts()
        scheduleSyncToCloud()
    }

    /// Add attachment to draft
    public func addAttachment(_ attachment: DraftAttachment, to conversationId: UUID?) {
        var draft = getDraft(for: conversationId)
        draft.attachments.append(attachment)
        draft.lastModified = Date()
        draft.deviceId = deviceId

        drafts[conversationId] = draft
        currentDraft = draft

        saveLocalDrafts()
        scheduleSyncToCloud()
    }

    /// Remove attachment from draft
    public func removeAttachment(_ attachmentId: UUID, from conversationId: UUID?) {
        guard var draft = drafts[conversationId] else { return }
        draft.attachments.removeAll { $0.id == attachmentId }
        draft.lastModified = Date()

        drafts[conversationId] = draft
        currentDraft = draft

        saveLocalDrafts()
        scheduleSyncToCloud()
    }

    /// Clear draft - ONLY called on explicit user action (send/clear)
    public func clearDraft(for conversationId: UUID?) {
        drafts.removeValue(forKey: conversationId)

        if currentDraft?.conversationId == conversationId {
            currentDraft = nil
        }

        saveLocalDrafts()
        syncToCloudImmediately()
    }

    /// Set active conversation - loads its draft
    public func setActiveConversation(_ conversationId: UUID?) {
        currentDraft = getDraft(for: conversationId)
    }

    /// Force immediate sync (e.g., when app goes to background)
    public func forceSyncNow() async {
        await syncToCloud()
    }

    // MARK: - Local Persistence

    private func saveLocalDrafts() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            // Convert to array for storage (dictionaries with optional keys are tricky)
            let draftArray = drafts.map { key, value -> (String, InputDraft) in
                (key?.uuidString ?? "global", value)
            }
            let data = try encoder.encode(Dictionary(uniqueKeysWithValues: draftArray))
            defaults.set(data, forKey: localStorageKey)

            logger.debug("Saved \(self.drafts.count) drafts locally")
        } catch {
            logger.error("Failed to save drafts locally: \(error.localizedDescription)")
        }
    }

    private func loadLocalDrafts() {
        guard let data = defaults.data(forKey: localStorageKey) else {
            logger.debug("No local drafts found")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let draftDict = try decoder.decode([String: InputDraft].self, from: data)

            // Convert back to UUID? keys
            drafts = [:]
            for (key, value) in draftDict {
                let uuid: UUID? = key == "global" ? nil : UUID(uuidString: key)
                drafts[uuid] = value
            }

            logger.info("Loaded \(self.drafts.count) drafts from local storage")
        } catch {
            logger.error("Failed to load local drafts: \(error.localizedDescription)")
        }
    }

    // MARK: - Cloud Sync

    private func setupCloudSyncObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudKeyValueStore
        )

        // Start observing
        cloudKeyValueStore.synchronize()
    }

    @objc private func cloudStoreDidChange(_ _notification: Notification) {
        guard crossDeviceSyncEnabled else { return }

        Task { @MainActor in
            await syncFromCloud()
        }
    }

    private func scheduleSyncToCloud() {
        guard crossDeviceSyncEnabled else { return }

        // Cancel previous debounce
        syncDebounceTask?.cancel()

        let delay = liveSyncEnabled ? 0.5 : syncDelaySeconds

        syncDebounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            if !Task.isCancelled {
                await syncToCloud()
            }
        }
    }

    private func syncToCloudImmediately() {
        guard crossDeviceSyncEnabled else { return }

        syncDebounceTask?.cancel()
        Task {
            await syncToCloud()
        }
    }

    private func syncToCloud() async {
        guard crossDeviceSyncEnabled else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            // Convert drafts to cloud format
            var cloudDrafts: [String: Data] = [:]
            for (key, draft) in drafts {
                let keyString = key?.uuidString ?? "global"
                let draftData = try encoder.encode(draft)
                cloudDrafts[keyString] = draftData
            }

            // Store each draft separately to allow partial updates
            for (key, data) in cloudDrafts {
                cloudKeyValueStore.set(data, forKey: "\(cloudStorageKey).\(key)")
            }

            // Store list of draft keys
            cloudKeyValueStore.set(Array(cloudDrafts.keys), forKey: "\(cloudStorageKey).keys")

            cloudKeyValueStore.synchronize()

            lastSyncError = nil
            logger.debug("Synced \(cloudDrafts.count) drafts to cloud")
        } catch {
            lastSyncError = error.localizedDescription
            logger.error("Failed to sync drafts to cloud: \(error.localizedDescription)")
        }
    }

    private func syncFromCloud() async {
        guard crossDeviceSyncEnabled else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Get list of draft keys
            guard let keys = cloudKeyValueStore.array(forKey: "\(cloudStorageKey).keys") as? [String] else {
                logger.debug("No cloud drafts found")
                return
            }

            var cloudDrafts: [UUID?: InputDraft] = [:]

            for key in keys {
                guard let data = cloudKeyValueStore.data(forKey: "\(cloudStorageKey).\(key)") else {
                    continue
                }

                let draft = try decoder.decode(InputDraft.self, from: data)
                let uuid: UUID? = key == "global" ? nil : UUID(uuidString: key)
                cloudDrafts[uuid] = draft
            }

            // Merge cloud drafts with local - keep whichever is newer
            for (key, cloudDraft) in cloudDrafts {
                if let localDraft = drafts[key] {
                    // Keep newer version, but prefer local if same time
                    if cloudDraft.lastModified > localDraft.lastModified,
                       cloudDraft.deviceId != deviceId {
                        drafts[key] = cloudDraft
                        logger.debug("Updated draft from cloud: \(key?.uuidString ?? "global")")
                    }
                } else {
                    // No local draft, use cloud version
                    drafts[key] = cloudDraft
                    logger.debug("Added draft from cloud: \(key?.uuidString ?? "global")")
                }
            }

            // Update current draft if it changed
            if let current = currentDraft,
               let updated = drafts[current.conversationId],
               updated.lastModified > current.lastModified {
                currentDraft = updated
            }

            // Save merged state locally
            saveLocalDrafts()

            lastSyncError = nil
            logger.info("Synced \(cloudDrafts.count) drafts from cloud")
        } catch {
            lastSyncError = error.localizedDescription
            logger.error("Failed to sync drafts from cloud: \(error.localizedDescription)")
        }
    }

    // MARK: - App Lifecycle

    /// Call when app enters background
    public func appDidEnterBackground() {
        // Cancel debounce and sync immediately
        syncDebounceTask?.cancel()
        Task {
            await syncToCloud()
        }
    }

    /// Call when app will terminate
    public func appWillTerminate() {
        // Synchronous save
        saveLocalDrafts()

        // Best-effort cloud sync
        if crossDeviceSyncEnabled {
            cloudKeyValueStore.synchronize()
        }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// View modifier for draft persistence
public struct DraftPersistenceModifier: ViewModifier {
    let conversationId: UUID?
    @StateObject private var draftManager = DraftSyncManager.shared
    @Binding var text: String

    public func body(content: Content) -> some View {
        content
            .onAppear {
                // Load draft when view appears
                draftManager.setActiveConversation(conversationId)
                if let draft = draftManager.currentDraft {
                    text = draft.text
                }
            }
            .onChange(of: text) { _, newValue in
                // Save draft on every change
                draftManager.updateDraftText(newValue, for: conversationId)
            }
            .onReceive(draftManager.$currentDraft) { draft in
                // Update from cloud sync
                if let draft = draft,
                   draft.conversationId == conversationId,
                   draft.text != text {
                    text = draft.text
                }
            }
    }
}

public extension View {
    /// Persist input field content as a draft
    func persistDraft(for conversationId: UUID?, text: Binding<String>) -> some View {
        modifier(DraftPersistenceModifier(conversationId: conversationId, text: text))
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let draftDidUpdate = Notification.Name("thea.draft.didUpdate")
    static let draftDidSync = Notification.Name("thea.draft.didSync")
}
